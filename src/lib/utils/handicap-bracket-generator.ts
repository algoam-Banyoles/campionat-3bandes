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

// ── Funció principal ──────────────────────────────────────────────────────────

/**
 * Genera tots els slots i partides d'un torneig d'eliminació doble.
 *
 * @param eventId  UUID de l'event (handicap_participants.event_id)
 * @param participants  Array de participants amb seed i distancia assignats
 * @returns  Arrays de SlotInsert i MatchInsert llestos per inserir a la BD
 */
export function generateDoublEliminationBracket(
	eventId: string,
	participants: ParticipantInput[]
): BracketResult {
	const n = participants.length;
	if (n < 2) throw new Error('Cal mínim 2 participants');

	// Participants ordenats per seed (1 = millor)
	const sorted = [...participants].sort((a, b) => a.seed - b.seed);

	const size = nextPow2(n);
	const k = Math.log2(size); // rondes del winners bracket
	const lRounds = 2 * (k - 1); // rondes del losers bracket

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

	// W-R1: parelles (seed i) vs (seed size+1-i)
	for (let i = 1; i <= size / 2; i++) {
		const seed1 = i;
		const seed2 = size + 1 - i;
		const p1 = seed1 <= n ? sorted[seed1 - 1] : null;
		const p2 = seed2 <= n ? sorted[seed2 - 1] : null;
		addSlot('winners', 1, 2 * i - 1, p1?.id ?? null, p1 === null);
		addSlot('winners', 1, 2 * i, p2?.id ?? null, p2 === null);
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

			// Destí del perdedor al losers bracket:
			//   W-R1 match i → L-R1 slot i
			//   W-R(j+1) match i → L-R(2j) slot 2i  (per j=1..k-2)
			let loseDest: SlotInsert;
			if (r === 1) {
				loseDest = getSlot('losers', 1, i);
			} else {
				const lr = 2 * (r - 1);
				loseDest = getSlot('losers', lr, 2 * i);
			}

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
		//   k>1: va a L-R(2k-2) slot 2 (darrer slot del darrer round losers)
		const loseDest =
			lRounds === 0 ? getSlot('grand_final', 1, 2) : getSlot('losers', lRounds, 2);

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
