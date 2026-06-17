/**
 * Generador de bracket d'eliminació doble per al campionat hàndicap.
 *
 * Estructura:
 *  - Winners bracket: k rondes (R1..Rk), Rk = Final guanyadors
 *  - Losers bracket: 2*(k-1) rondes
 *  - Grand Final: R1 (final) + R2 (reset, si el jugador del losers guanya R1)
 *
 * Seeding R1: seed i vs seed (size+1-i) — seed 1 vs seed N, seed 2 vs seed N-1...
 * Byes: les posicions > N s'assignen al jugador de menor importància (seeds alts),
 *       de manera que els millors seeds (1..byes) passen automàticament a R2.
 */

export interface ParticipantInput {
	/** handicap_participants.id */
	id: string;
	/** Seed 1-based (1 = millor) */
	seed: number;
	/** Caramboles objectiu */
	distancia: number;
}

export interface SlotInsert {
	id: string;
	event_id: string;
	bracket_type: 'winners' | 'losers' | 'grand_final';
	ronda: number;
	posicio: number;
	participant_id: string | null;
	is_bye: boolean;
	source_match_id: string | null;
}

export interface MatchInsert {
	id: string;
	event_id: string;
	slot1_id: string;
	slot2_id: string;
	winner_slot_dest_id: string | null;
	loser_slot_dest_id: string | null;
	estat: 'pendent' | 'bye';
	distancia_jugador1: number | null;
	distancia_jugador2: number | null;
	guanyador_participant_id: string | null;
	calendari_partida_id: null;
}

export interface BracketResult {
	slots: SlotInsert[];
	matches: MatchInsert[];
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function nextPow2(n: number): number {
	let p = 1;
	while (p < n) p *= 2;
	return p;
}

let _idGen: () => string = () => crypto.randomUUID();

/** Permet injectar un generador d'IDs determinístic als tests. */
export function setIdGenerator(fn: () => string): void {
	_idGen = fn;
}

export function resetIdGenerator(): void {
	_idGen = () => crypto.randomUUID();
}

// ── Creuament anti-revenja de les baixades al losers ──────────────────────────
//
// Problema clàssic del doble KO: si el perdedor d'una ronda del winners baixa al
// losers en l'ordre "natural", pot retrobar molt aviat (sovint a la mateixa ronda
// de baixada) un jugador a qui ja va guanyar/perdre al winners. La solució estàndard
// és permutar les baixades perquè cada perdedor s'enfronti a un supervivent del
// losers que prové d'una regió DISJUNTA del winners (mai s'han pogut creuar).
//
// `computeWbLoserDrops` calcula, per a cada partida del winners (ronda r, índex i),
// a quin slot del losers (lr, pos) cau el seu perdedor, garantint la disjunció a
// totes les rondes de baixada on és matemàticament possible. A l'última baixada
// (final del winners, regió = tot el quadre) el solapament és inevitable.

/**
 * Matching bipartit (algoritme de Kuhn): assigna a cada element de `left` un de
 * `right` tal que `ok(left[l], right[r])` sigui cert, maximitzant els aparellaments.
 * Retorna `assign[l] = r`. Els `left` no aparellats (quan no hi ha matching perfecte,
 * p. ex. rondes fondes amb solapament inevitable) reben un `right` lliure determinista.
 */
function matchDisjoint(
	left: Set<number>[],
	right: Set<number>[],
	ok: (a: Set<number>, b: Set<number>) => boolean
): number[] {
	const n = left.length;
	const matchRight = new Array<number>(n).fill(-1); // right index → left index
	const assign = new Array<number>(n).fill(-1); // left index → right index

	const tryAssign = (l: number, seen: boolean[]): boolean => {
		for (let r = 0; r < n; r++) {
			if (seen[r] || !ok(left[l], right[r])) continue;
			seen[r] = true;
			if (matchRight[r] === -1 || tryAssign(matchRight[r], seen)) {
				matchRight[r] = l;
				assign[l] = r;
				return true;
			}
		}
		return false;
	};

	for (let l = 0; l < n; l++) tryAssign(l, new Array<boolean>(n).fill(false));

	// Completar els no aparellats de forma determinista (solapament inevitable).
	const usedRight = new Set(assign.filter((r) => r !== -1));
	let freeRight = 0;
	for (let l = 0; l < n; l++) {
		if (assign[l] === -1) {
			while (usedRight.has(freeRight)) freeRight++;
			assign[l] = freeRight;
			usedRight.add(freeRight);
		}
	}
	return assign;
}

/**
 * Calcula el destí al losers del perdedor de cada partida del winners.
 * @param size  Mida del quadre (potència de 2)
 * @returns  Map amb clau `${r}:${i}` (ronda r del winners, partida i) → { lr, pos }
 */
export function computeWbLoserDrops(size: number): Map<string, { lr: number; pos: number }> {
	const map = new Map<string, { lr: number; pos: number }>();
	if (size < 2) return map;
	const k = Math.log2(size);
	const lRounds = 2 * (k - 1);

	// Bloc de posicions R1 (1..size) que cobreix la partida (r,i) del winners.
	const wbBlock = (r: number, i: number): Set<number> => {
		const span = Math.pow(2, r);
		const start = (i - 1) * span + 1;
		const s = new Set<number>();
		for (let p = start; p < start + span; p++) s.add(p);
		return s;
	};

	// W-R1 → L-R1 (slot i): perdedors de partides R1 diferents, mai s'han creuat.
	const m1 = size / 2;
	for (let i = 1; i <= m1; i++) map.set(`1:${i}`, { lr: 1, pos: i });
	if (lRounds === 0) return map;

	const reach = new Map<string, Set<number>>();
	const rkey = (lr: number, pos: number) => `${lr}:${pos}`;
	for (let i = 1; i <= m1; i++) reach.set(rkey(1, i), wbBlock(1, i));

	const disjoint = (a: Set<number>, b: Set<number>) => {
		for (const x of a) if (b.has(x)) return false;
		return true;
	};

	for (let lr = 1; lr <= lRounds; lr++) {
		const phase = Math.ceil(lr / 2);
		const numSlots = size / Math.pow(2, phase);
		const numMatches = numSlots / 2;

		// Rondes parelles = rondes de baixada del winners (r = lr/2 + 1).
		if (lr % 2 === 0) {
			const r = lr / 2 + 1;
			const numBlocks = size / Math.pow(2, r); // == numMatches
			const blocks: Set<number>[] = [];
			for (let i = 1; i <= numBlocks; i++) blocks.push(wbBlock(r, i));
			const survivor: Set<number>[] = [];
			for (let j = 1; j <= numMatches; j++) {
				survivor.push(reach.get(rkey(lr, 2 * j - 1)) ?? new Set<number>());
			}
			const assign = matchDisjoint(survivor, blocks, disjoint); // assign[j-1] = índex de bloc
			for (let j = 1; j <= numMatches; j++) {
				const bIdx = assign[j - 1];
				map.set(`${r}:${bIdx + 1}`, { lr, pos: 2 * j });
				reach.set(rkey(lr, 2 * j), blocks[bIdx]);
			}
		}

		// Propagar el guanyador de cada partida a la ronda següent (mateix routing
		// que el generador: lr senar → slot 2j-1, lr parell → slot j).
		if (lr < lRounds) {
			for (let j = 1; j <= numMatches; j++) {
				const a = reach.get(rkey(lr, 2 * j - 1)) ?? new Set<number>();
				const b = reach.get(rkey(lr, 2 * j)) ?? new Set<number>();
				const u = new Set<number>([...a, ...b]);
				const destPos = lr % 2 === 1 ? 2 * j - 1 : j;
				reach.set(rkey(lr + 1, destPos), u);
			}
		}
	}
	return map;
}

// ── Funció principal ──────────────────────────────────────────────────────────

export interface GenerateBracketOptions {
	/**
	 * Si és cert, el camp `seed` de cada participant es tracta com a POSICIÓ
	 * explícita a R1 del Winners bracket (1..size). Les posicions no assignades
	 * a cap participant esdevenen byes. Útil per a sorteig manual on l'admin
	 * decideix exactament a quina ranura va cada jugador.
	 *
	 * Per defecte (false), els seeds s'interpreten com a 1..N de millor a pitjor
	 * i s'emparellen segons l'algoritme estàndard (seed i vs seed size+1-i).
	 */
	useExplicitR1Positions?: boolean;
}

/**
 * Genera tots els slots i partides d'un torneig d'eliminació doble.
 *
 * @param eventId  UUID de l'event (handicap_participants.event_id)
 * @param participants  Array de participants amb seed i distancia assignats
 * @param options  Opcions de generació (vegeu GenerateBracketOptions)
 * @returns  Arrays de SlotInsert i MatchInsert llestos per inserir a la BD
 */
export function generateDoublEliminationBracket(
	eventId: string,
	participants: ParticipantInput[],
	options: GenerateBracketOptions = {}
): BracketResult {
	const n = participants.length;
	if (n < 2) throw new Error('Cal mínim 2 participants');

	const explicit = options.useExplicitR1Positions ?? false;

	// Participants ordenats per seed (1 = millor) [comportament estàndard]
	// En mode explícit, el seed és la POSICIÓ a R1 (1..size).
	const sorted = [...participants].sort((a, b) => a.seed - b.seed);

	const size = nextPow2(n);

	if (explicit) {
		// Validar que cada seed (=posició a R1) està dins del rang i no es repeteix.
		const seen = new Set<number>();
		for (const p of participants) {
			if (p.seed < 1 || p.seed > size) {
				throw new Error(`Posició invàlida ${p.seed} (rang vàlid 1..${size})`);
			}
			if (seen.has(p.seed)) {
				throw new Error(`Posició duplicada: ${p.seed}`);
			}
			seen.add(p.seed);
		}
	}

	const k = Math.log2(size); // rondes del winners bracket
	const lRounds = 2 * (k - 1); // rondes del losers bracket

	// Destí al losers del perdedor de cada partida del winners, amb creuament
	// anti-revenja (vegeu computeWbLoserDrops).
	const dropMap = computeWbLoserDrops(size);

	const slots: SlotInsert[] = [];
	const matches: MatchInsert[] = [];
	const slotMap = new Map<string, SlotInsert>();

	function key(bt: string, r: number, p: number): string {
		return `${bt}:${r}:${p}`;
	}

	function addSlot(
		bt: 'winners' | 'losers' | 'grand_final',
		r: number,
		p: number,
		participantId: string | null,
		isBye: boolean
	): SlotInsert {
		const slot: SlotInsert = {
			id: _idGen(),
			event_id: eventId,
			bracket_type: bt,
			ronda: r,
			posicio: p,
			participant_id: participantId,
			is_bye: isBye,
			source_match_id: null
		};
		slotMap.set(key(bt, r, p), slot);
		slots.push(slot);
		return slot;
	}

	function getSlot(bt: string, r: number, p: number): SlotInsert {
		const s = slotMap.get(key(bt, r, p));
		if (!s) throw new Error(`Slot no trobat: ${bt}:${r}:${p}`);
		return s;
	}

	function distanciaOf(participantId: string | null): number | null {
		if (!participantId) return null;
		return sorted.find((p) => p.id === participantId)?.distancia ?? null;
	}

	// ── 1. Slots del winners bracket ──────────────────────────────────────────

	if (explicit) {
		// Posicions explícites: el camp `seed` indica la posició a R1 (1..size).
		// Les posicions sense participant esdevenen byes.
		const byPos = new Map<number, ParticipantInput>(
			participants.map(p => [p.seed, p])
		);
		for (let pos = 1; pos <= size; pos++) {
			const p = byPos.get(pos) ?? null;
			addSlot('winners', 1, pos, p?.id ?? null, p === null);
		}
	} else {
		// W-R1: parelles (seed i) vs (seed size+1-i)
		for (let i = 1; i <= size / 2; i++) {
			const seed1 = i;
			const seed2 = size + 1 - i;
			const p1 = seed1 <= n ? sorted[seed1 - 1] : null;
			const p2 = seed2 <= n ? sorted[seed2 - 1] : null;
			addSlot('winners', 1, 2 * i - 1, p1?.id ?? null, p1 === null);
			addSlot('winners', 1, 2 * i, p2?.id ?? null, p2 === null);
		}
	}

	// W-R2 fins W-Rk (sense participants inicialment)
	for (let r = 2; r <= k; r++) {
		const numSlots = size / Math.pow(2, r - 1);
		for (let p = 1; p <= numSlots; p++) {
			addSlot('winners', r, p, null, false);
		}
	}

	// ── 2. Slots del losers bracket ───────────────────────────────────────────
	//
	// Mida per ronda del losers:
	//   lr=1,2 → phase=1 → size/2 slots
	//   lr=3,4 → phase=2 → size/4 slots
	//   lr=2j-1, 2j → phase=j → size/2^j slots
	for (let lr = 1; lr <= lRounds; lr++) {
		const phase = Math.ceil(lr / 2);
		const numSlots = size / Math.pow(2, phase);
		for (let p = 1; p <= numSlots; p++) {
			addSlot('losers', lr, p, null, false);
		}
	}

	// ── 3. Slots de la Gran Final ─────────────────────────────────────────────
	addSlot('grand_final', 1, 1, null, false); // guanyador winners bracket
	addSlot('grand_final', 1, 2, null, false); // guanyador losers bracket
	addSlot('grand_final', 2, 1, null, false); // guanyador GF-R1 (reset slot 1)
	addSlot('grand_final', 2, 2, null, false); // perdedor GF-R1 (reset slot 2)

	// ── 4. Partides del winners bracket ──────────────────────────────────────

	// W-R1 fins W-R(k-1)
	for (let r = 1; r <= k - 1; r++) {
		const numMatches = size / Math.pow(2, r);
		for (let i = 1; i <= numMatches; i++) {
			const s1 = getSlot('winners', r, 2 * i - 1);
			const s2 = getSlot('winners', r, 2 * i);
			const winDest = getSlot('winners', r + 1, i);

			// Destí del perdedor al losers bracket (creuament anti-revenja).
			const dd = dropMap.get(`${r}:${i}`)!;
			const loseDest = getSlot('losers', dd.lr, dd.pos);

			const match: MatchInsert = {
				id: _idGen(),
				event_id: eventId,
				slot1_id: s1.id,
				slot2_id: s2.id,
				winner_slot_dest_id: winDest.id,
				loser_slot_dest_id: loseDest.id,
				estat: 'pendent',
				distancia_jugador1: distanciaOf(s1.participant_id),
				distancia_jugador2: distanciaOf(s2.participant_id),
				guanyador_participant_id: null,
				calendari_partida_id: null
			};

			winDest.source_match_id = match.id;
			loseDest.source_match_id = match.id;
			matches.push(match);
		}
	}

	// W-Final (W-Rk)
	{
		const s1 = getSlot('winners', k, 1);
		const s2 = getSlot('winners', k, 2);
		const winDest = getSlot('grand_final', 1, 1);

		// W-Final loser:
		//   k=1 (2 jugadors): va directament a GF-R1-2
		//   k>1: baixa a l'última ronda del losers (dropMap; solapament inevitable aquí)
		const wfDrop = dropMap.get(`${k}:1`);
		const loseDest =
			lRounds === 0 || !wfDrop
				? getSlot('grand_final', 1, 2)
				: getSlot('losers', wfDrop.lr, wfDrop.pos);

		const match: MatchInsert = {
			id: _idGen(),
			event_id: eventId,
			slot1_id: s1.id,
			slot2_id: s2.id,
			winner_slot_dest_id: winDest.id,
			loser_slot_dest_id: loseDest.id,
			estat: 'pendent',
			distancia_jugador1: null,
			distancia_jugador2: null,
			guanyador_participant_id: null,
			calendari_partida_id: null
		};

		winDest.source_match_id = match.id;
		loseDest.source_match_id = match.id;
		matches.push(match);
	}

	// ── 5. Partides del losers bracket ───────────────────────────────────────
	//
	// Destí del guanyador per ronda lr:
	//   lr rondes senars (pures): winner → L-R(lr+1) slot 2i-1
	//   lr rondes parells (mixtes): winner → L-R(lr+1) slot i
	//   lr = lRounds (darrera ronda): winner → GF-R1-2
	for (let lr = 1; lr <= lRounds; lr++) {
		const phase = Math.ceil(lr / 2);
		const numSlots = size / Math.pow(2, phase);
		const numMatches = numSlots / 2;

		for (let i = 1; i <= numMatches; i++) {
			const s1 = getSlot('losers', lr, 2 * i - 1);
			const s2 = getSlot('losers', lr, 2 * i);

			let winDest: SlotInsert;
			if (lr === lRounds) {
				winDest = getSlot('grand_final', 1, 2);
			} else if (lr % 2 === 1) {
				// Ronda senar: winner → L-R(lr+1) slot 2i-1
				winDest = getSlot('losers', lr + 1, 2 * i - 1);
			} else {
				// Ronda parell: winner → L-R(lr+1) slot i
				winDest = getSlot('losers', lr + 1, i);
			}

			const match: MatchInsert = {
				id: _idGen(),
				event_id: eventId,
				slot1_id: s1.id,
				slot2_id: s2.id,
				winner_slot_dest_id: winDest.id,
				loser_slot_dest_id: null, // eliminat
				estat: 'pendent',
				distancia_jugador1: null,
				distancia_jugador2: null,
				guanyador_participant_id: null,
				calendari_partida_id: null
			};

			winDest.source_match_id = match.id;
			matches.push(match);
		}
	}

	// ── 6. Partides de la Gran Final ──────────────────────────────────────────

	// GF-R1
	{
		const s1 = getSlot('grand_final', 1, 1);
		const s2 = getSlot('grand_final', 1, 2);
		const winDest = getSlot('grand_final', 2, 1);
		const loseDest = getSlot('grand_final', 2, 2);

		const match: MatchInsert = {
			id: _idGen(),
			event_id: eventId,
			slot1_id: s1.id,
			slot2_id: s2.id,
			winner_slot_dest_id: winDest.id,
			loser_slot_dest_id: loseDest.id,
			estat: 'pendent',
			distancia_jugador1: null,
			distancia_jugador2: null,
			guanyador_participant_id: null,
			calendari_partida_id: null
		};

		winDest.source_match_id = match.id;
		loseDest.source_match_id = match.id;
		matches.push(match);
	}

	// GF-R2 (reset — només es juga si el jugador del losers guanya GF-R1)
	{
		const s1 = getSlot('grand_final', 2, 1);
		const s2 = getSlot('grand_final', 2, 2);

		const match: MatchInsert = {
			id: _idGen(),
			event_id: eventId,
			slot1_id: s1.id,
			slot2_id: s2.id,
			winner_slot_dest_id: null,
			loser_slot_dest_id: null,
			estat: 'pendent',
			distancia_jugador1: null,
			distancia_jugador2: null,
			guanyador_participant_id: null,
			calendari_partida_id: null
		};

		matches.push(match);
	}

	// ── 7. Processament de byes ───────────────────────────────────────────────
	processByes(slots, matches, sorted);

	return { slots, matches };
}

/**
 * Propaga els byes per tot el bracket.
 * Un slot amb is_bye=true significa que no hi ha jugador real en aquella posició.
 * Si una partida té un slot bye, s'auto-resol; si en té dos, propaga el bye endavant.
 */
function processByes(
	slots: SlotInsert[],
	matches: MatchInsert[],
	participants: ParticipantInput[]
): void {
	const slotById = new Map(slots.map((s) => [s.id, s]));

	// Múltiples passades fins que no hi hagi canvis (per a byes en cascada)
	let changed = true;
	while (changed) {
		changed = false;

		for (const match of matches) {
			if (match.estat !== 'pendent') continue;

			const s1 = slotById.get(match.slot1_id)!;
			const s2 = slotById.get(match.slot2_id)!;

			const s1settled = s1.is_bye || s1.participant_id !== null;
			const s2settled = s2.is_bye || s2.participant_id !== null;
			const s1pending = !s1.is_bye && s1.participant_id === null;
			const s2pending = !s2.is_bye && s2.participant_id === null;

			// Cas guaranteed-bye: un slot és bye i l'altre és pendent (rebrà un jugador real futur).
			// Pre-resoldre com a bye i re-cablar el destí perquè el match que alimentava el slot
			// pendent ara apunti directament al winner_slot_dest d'aquest match.
			if ((s1.is_bye && s2pending) || (s2.is_bye && s1pending)) {
				match.estat = 'bye';
				changed = true;
				match.guanyador_participant_id = null;

				const pendingSlot = s1pending ? s1 : s2;
				if (match.winner_slot_dest_id) {
					const winDest = slotById.get(match.winner_slot_dest_id)!;
					for (const m of matches) {
						if (m.loser_slot_dest_id === pendingSlot.id) {
							m.loser_slot_dest_id = winDest.id;
							winDest.source_match_id = m.id;
							break;
						}
					}
				}
				continue;
			}

			// Si ambdós slots són pendents, esperar
			if (!s1settled || !s2settled) continue;

			if (!s1.is_bye && !s2.is_bye) continue;

			match.estat = 'bye';
			changed = true;

			const winnerId: string | null =
				s1.is_bye && s2.is_bye
					? null // tots dos bye: no hi ha guanyador real
					: s1.is_bye
						? s2.participant_id
						: s1.participant_id;

			match.guanyador_participant_id = winnerId;
			match.distancia_jugador1 =
				s1.participant_id && !s1.is_bye
					? (participants.find((p) => p.id === s1.participant_id)?.distancia ?? null)
					: null;
			match.distancia_jugador2 =
				s2.participant_id && !s2.is_bye
					? (participants.find((p) => p.id === s2.participant_id)?.distancia ?? null)
					: null;

			// Avançar guanyador al slot destí (o propagar bye si no hi ha guanyador)
			if (match.winner_slot_dest_id) {
				const winSlot = slotById.get(match.winner_slot_dest_id)!;
				if (winnerId) {
					winSlot.participant_id = winnerId;
					winSlot.source_match_id = match.id;
				} else {
					// Ambdós byes: propagar bye endavant
					winSlot.is_bye = true;
					winSlot.source_match_id = match.id;
				}
			}

			// El perdedor del bracket guanyadors cau al losers: marcar aquell slot com a bye
			if (match.loser_slot_dest_id) {
				const loseSlot = slotById.get(match.loser_slot_dest_id)!;
				loseSlot.is_bye = true;
				loseSlot.source_match_id = match.id;
			}
		}
	}

	// Actualitzar distàncies de les partides normals (no bye) amb jugadors ja assignats
	for (const match of matches) {
		if (match.estat !== 'pendent') continue;
		const s1 = slotById.get(match.slot1_id)!;
		const s2 = slotById.get(match.slot2_id)!;
		if (s1.participant_id) {
			match.distancia_jugador1 =
				participants.find((p) => p.id === s1.participant_id)?.distancia ?? null;
		}
		if (s2.participant_id) {
			match.distancia_jugador2 =
				participants.find((p) => p.id === s2.participant_id)?.distancia ?? null;
		}
	}
}

// ── Utilitats d'exportació ────────────────────────────────────────────────────

/** Calcula el nombre de byes per a N participants. */
export function calcByes(n: number): number {
	return nextPow2(n) - n;
}

/** Retorna les parelles de la primera ronda del bracket guanyadors, en ordre. */
export function getR1Pairings(
	participants: ParticipantInput[]
): Array<{ seed1: ParticipantInput; seed2: ParticipantInput | null }> {
	const sorted = [...participants].sort((a, b) => a.seed - b.seed);
	const n = sorted.length;
	const size = nextPow2(n);
	const pairings: Array<{ seed1: ParticipantInput; seed2: ParticipantInput | null }> = [];
	for (let i = 1; i <= size / 2; i++) {
		const p1 = sorted[i - 1];
		const p2idx = size - i;
		const p2 = p2idx < n ? sorted[p2idx] : null;
		pairings.push({ seed1: p1, seed2: p2 });
	}
	return pairings;
}
