<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase } from '$lib/supabaseClient';
	import { generateDoublEliminationBracket } from '$lib/utils/handicap-bracket-generator';
	import { preSchedulingForBracket, type ScheduledMatch } from '$lib/utils/handicap-pre-scheduler';
	import { computeDeadlines } from '$lib/utils/handicap-deadlines';
	import { printPortal } from '$lib/utils/print-portal';
	import { loadLogoDataUrl } from '$lib/utils/load-logo';
	import { formatarNomJugadorParts } from '$lib/utils/playerUtils';

	let logoDataUrl = '';

	// Dos modes:
	//   - eventId definit       → bracket REAL: carrega slots/matches de la BBDD.
	//   - participantCount > 0  → bracket EN BLANC: genera l'estructura al vol per a N
	//     jugadors (sorteig manual). El bracket no es persisteix.
	export let eventId: string | null = null;
	export let participantCount: number | null = null;
	export let eventNom: string = '';
	export let eventTemporada: string = '';
	export let onClose: () => void = () => {};

	// '2025-2026' → '2025/2026'
	$: temporadaPretty = (eventTemporada || '').replace('-', '/');

	type Bracket = 'winners' | 'losers' | 'grand_final';
	type Slot = {
		id: string;
		bracket_type: Bracket;
		ronda: number;
		posicio: number;
		participant_id?: string | null;
		is_bye?: boolean;
	};
	type MatchRaw = {
		id: string;
		slot1_id: string;
		slot2_id: string;
		winner_slot_dest_id: string | null;
		loser_slot_dest_id: string | null;
		estat?: string;
		guanyador_participant_id?: string | null;
		distancia_jugador1?: number | null;
		distancia_jugador2?: number | null;
		caramboles1?: number | null;
		caramboles2?: number | null;
		entrades?: number | null;
	};
	type MatchResult = {
		estat: 'jugada' | 'walkover';
		isWalkover: boolean;
		caramboles1: number | null;
		caramboles2: number | null;
		entrades: number | null;
		distancia1: number | null;
		distancia2: number | null;
		winnerSlot: 1 | 2 | null;
	};
	type MatchView = {
		id: string;
		code: string;
		matchPos: number;
		bracket: Bracket;
		ronda: number;
		slot1Pos: number;
		slot2Pos: number;
		slot1Name: string | null;
		slot2Name: string | null;
		slot1Dist: number | null;
		slot2Dist: number | null;
		winnerDest: string;
		loserDest: string;
		schedule?: ScheduledMatch | null;
		result?: MatchResult | null;
	};

	let loading = true;
	let error: string | null = null;
	let hasRealBracket = false;

	let winnersPages: Array<Array<[number, MatchView[]]>> = [];
	let losersPages: Array<Array<[number, MatchView[]]>> = [];
	let totalMatches = 0;
	let allViews: MatchView[] = [];

	// Dimensions (mm) per a la disposicio VISUAL en arbre a A3 apaisat.
	const V_CELL_W = 68;
	const V_CELL_H = 28;
	const V_SLOT = 32;
	const V_COL_GAP = 13;
	const V_COL_GAP_WIN = 28; // gap horitzontal mes ample per als fulls de guanyadors
	const V_HEADER_H = 7;
	// Àrea útil (mm) d'un full A3 APAÏSAT (capçalera i marges descomptats).
	const V_LAND_W = 388;
	const V_LAND_H = 232;
	// Per mantenir els textos llegibles, cada full visual mostra un tram curt
	// de rondes i un màxim de sis partides de la ronda més densa.
	const V_MAX_ROUNDS_PER_SHEET = 4;
	const V_MAX_CELLS_PER_SHEET = 8;
	// Tram curt (mm) que surt cap a la dreta quan el guanyador avança a un
	// match que es a l'altre full (p. ex. W4.2 -> W5.1 a la pagina 2).
	const V_STUB_LEN = 7;
	const V_STUB_LABEL_W = 24;

	// Per al mode "blanc": l'usuari pot ajustar el nombre de jugadors sense tancar el modal.
	let inputCount = participantCount ?? 32;

	onMount(async () => {
		logoDataUrl = await loadLogoDataUrl();
		await loadAll();
	});

	async function regenerate() {
		if (eventId) return;
		await loadAll();
	}

	async function loadAll() {
		loading = true;
		try {
			let slots: Slot[];
			let matches: MatchRaw[];
			// Quan el sorteig està fet, omplim aquest mapa amb el nom formatat
			// de cada participant; també mantenim el calendari real per substituir
			// la pre-programació estructural.
			const nameMap = new Map<string, string>();
			const distMap = new Map<string, number | null>();
			let scheduleById = new Map<string, ScheduledMatch>();
			let useRealData = false;

			// Detectar si hi ha un event hàndicap actiu amb sorteig ja generat.
			const { data: ev } = await supabase
				.from('events')
				.select('id, data_inici, data_fi')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.limit(1)
				.maybeSingle();

			let realEventId: string | null = eventId;
			if (!realEventId && ev?.id) {
				const { count } = await supabase
					.from('handicap_bracket_slots')
					.select('id', { count: 'exact', head: true })
					.eq('event_id', ev.id);
				if ((count ?? 0) > 0) {
					realEventId = ev.id;
				}
			}

			if (realEventId) {
				const { data: slotsData, error: sErr } = await supabase
					.from('handicap_bracket_slots')
					.select('id, bracket_type, ronda, posicio, participant_id, is_bye')
					.eq('event_id', realEventId);
				if (sErr) throw sErr;

				const { data: matchesData, error: mErr } = await supabase
					.from('handicap_matches')
					.select('id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id, estat, guanyador_participant_id, distancia_jugador1, distancia_jugador2, calendari_partida_id')
					.eq('event_id', realEventId);
				if (mErr) throw mErr;

				slots = (slotsData ?? []) as Slot[];
				matches = (matchesData ?? []).map((m: any) => ({
					id: m.id,
					slot1_id: m.slot1_id,
					slot2_id: m.slot2_id,
					winner_slot_dest_id: m.winner_slot_dest_id,
					loser_slot_dest_id: m.loser_slot_dest_id,
					estat: m.estat,
					guanyador_participant_id: m.guanyador_participant_id ?? null,
					distancia_jugador1: m.distancia_jugador1 ?? null,
					distancia_jugador2: m.distancia_jugador2 ?? null
				}));

				// Carrega noms reals dels participants (FK directa via soci_numero).
				const { data: partsData, error: pErr } = await supabase
					.from('handicap_participants')
					.select('id, distancia, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
					.eq('event_id', realEventId);
				if (pErr) throw pErr;
				for (const p of (partsData ?? []) as any[]) {
					const raw = p.socis;
					const s = Array.isArray(raw) ? raw[0] : raw;
					nameMap.set(p.id, formatarNomJugadorParts(s?.nom ?? '', s?.cognoms ?? ''));
					distMap.set(p.id, (p.distancia ?? null) as number | null);
				}

				// Calendari real (només per a matches que tenen calendari_partida_id).
				const calIds = (matchesData ?? [])
					.map((m: any) => m.calendari_partida_id)
					.filter((id: string | null): id is string => !!id);
				let calMap = new Map<string, { data_programada: string | null; hora_inici: string | null; taula_assignada: number | null; caramboles_jugador1: number | null; caramboles_jugador2: number | null; entrades: number | null }>();
				if (calIds.length > 0) {
					const { data: calData, error: cErr } = await supabase
						.from('calendari_partides')
						.select('id, data_programada, hora_inici, taula_assignada, caramboles_jugador1, caramboles_jugador2, entrades')
						.in('id', calIds);
					if (cErr) throw cErr;
					for (const c of (calData ?? []) as any[]) {
						calMap.set(c.id, {
							data_programada: c.data_programada,
							hora_inici: c.hora_inici,
							taula_assignada: c.taula_assignada,
							caramboles_jugador1: c.caramboles_jugador1 ?? null,
							caramboles_jugador2: c.caramboles_jugador2 ?? null,
							entrades: c.entrades ?? null
						});
					}
				}
				// Propaga caramboles/entrades del calendari als matches (per a la cel·la del bracket).
				{
					const matchById = new Map(matches.map(mm => [mm.id, mm]));
					for (const m of (matchesData ?? []) as any[]) {
						const mm = matchById.get(m.id);
						if (!mm || !m.calendari_partida_id) continue;
						const cp = calMap.get(m.calendari_partida_id);
						if (!cp) continue;
						mm.caramboles1 = cp.caramboles_jugador1;
						mm.caramboles2 = cp.caramboles_jugador2;
						mm.entrades = cp.entrades;
					}
				}
				// Construïm scheduleById a partir del calendari real.
				for (const m of (matchesData ?? []) as any[]) {
					if (!m.calendari_partida_id) continue;
					const cp = calMap.get(m.calendari_partida_id);
					if (!cp || !cp.data_programada || !cp.hora_inici || cp.taula_assignada == null) continue;
					scheduleById.set(m.id, {
						matchId: m.id,
						dataProgramada: new Date(cp.data_programada),
						horaInici: (cp.hora_inici as string).substring(0, 5),
						taulaAssignada: cp.taula_assignada as number,
						dataMaximaDisputa: new Date(cp.data_programada) // placeholder, recalculat avall
					});
				}

				// Recalcular deadlines round-level (mateixa lògica que /handicap/quadre).
				// La dataMaximaDisputa = primer dia de la ronda que segueix a aquest
				// match − 1, perquè tots els matches d'una mateixa ronda comparteixin
				// la mateixa deadline.
				{
					const slotById = new Map(slots.map((s) => [s.id, s]));
					const deadlineInputs = matches.map((m) => {
						const s1 = slotById.get(m.slot1_id);
						const sched = scheduleById.get(m.id);
						const isoDay = sched ? `${sched.dataProgramada.getFullYear()}-${String(sched.dataProgramada.getMonth() + 1).padStart(2, '0')}-${String(sched.dataProgramada.getDate()).padStart(2, '0')}` : null;
						return {
							id: m.id,
							slot1_id: m.slot1_id,
							slot2_id: m.slot2_id,
							winner_slot_dest_id: m.winner_slot_dest_id,
							loser_slot_dest_id: m.loser_slot_dest_id,
							data_programada: isoDay,
							bracket_type: (s1?.bracket_type ?? 'winners') as 'winners' | 'losers' | 'grand_final',
							ronda: s1?.ronda ?? 1
						};
					});
					const dataFi = ev?.data_fi
						? (ev.data_fi as string).substring(0, 10)
						: null;
					const deadlines = computeDeadlines(deadlineInputs, dataFi);
					for (const [matchId, sched] of scheduleById) {
						const dl = deadlines.get(matchId);
						if (dl) sched.dataMaximaDisputa = new Date(dl + 'T12:00:00');
					}
				}

				useRealData = true;
				hasRealBracket = true;
			} else if (inputCount && inputCount >= 2) {
				// Mode BLANC: genera estructura amb participants ficticis (només per dibuixar
				// el bracket). Seeds seqüencials, distancia=0, sense persistir res.
				const fakes = Array.from({ length: inputCount }, (_, i) => ({
					id: `fake-${i + 1}`,
					seed: i + 1,
					distancia: 0
				}));
				const result = generateDoublEliminationBracket('preview', fakes);
				slots = result.slots.map(s => ({
					id: s.id,
					bracket_type: s.bracket_type,
					ronda: s.ronda,
					posicio: s.posicio
				}));
				matches = result.matches.map(m => ({
					id: m.id,
					slot1_id: m.slot1_id,
					slot2_id: m.slot2_id,
					winner_slot_dest_id: m.winner_slot_dest_id,
					loser_slot_dest_id: m.loser_slot_dest_id,
					estat: m.estat
				}));
			} else {
				error = 'Cal un torneig generat o un nombre de participants ≥ 2.';
				loading = false;
				return;
			}

			// Excloure partides "bye" del bracket en blanc (no s'hi escriu res).
			matches = matches.filter(m => m.estat !== 'bye');

			if (matches.length === 0) {
				error = 'No hi ha cap partida amb què muntar el bracket.';
				loading = false;
				return;
			}

			// Si no estem amb dades reals, calcular pre-programació estructural
			// (dia/hora/billar/deadline per cada match) si tenim un event hàndicap
			// actiu amb dates.
			if (!useRealData) {
				try {
					if (ev?.data_inici && ev?.data_fi) {
						const { data: cfg } = await supabase
							.from('handicap_config')
							.select('horaris_extra')
							.eq('event_id', ev.id)
							.maybeSingle();
						scheduleById = preSchedulingForBracket(
							slots,
							matches,
							{
								dataInici: new Date(ev.data_inici),
								dataFi: new Date(ev.data_fi),
								horesEstandard: ['18:00', '19:00'],
								horarisExtra: cfg?.horaris_extra ?? null,
								billars: 3,
								diesBloquejats: [new Date('2026-06-24')]
							}
						);
					}
				} catch (e) {
					// Si la pre-programació falla, continuem sense (cells sense slot).
					console.warn('Pre-scheduling no disponible:', e);
				}
			}

			const slotById = new Map<string, Slot>(slots.map(s => [s.id, s]));
			const matchBySlot = new Map<string, MatchRaw>();
			for (const m of matches) {
				matchBySlot.set(m.slot1_id, m);
				matchBySlot.set(m.slot2_id, m);
			}

			// Ordenar matches per bracket → ronda → primera posició
			const order: Record<Bracket, number> = { winners: 0, losers: 1, grand_final: 2 };
			const enriched = matches.map(m => {
				const s1 = slotById.get(m.slot1_id);
				const s2 = slotById.get(m.slot2_id);
				const bracket = (s1?.bracket_type ?? 'winners') as Bracket;
				const ronda = s1?.ronda ?? 0;
				const posicioMin = Math.min(s1?.posicio ?? 9999, s2?.posicio ?? 9999);
				return { m, bracket, ronda, posicioMin };
			}).sort((a, b) => {
				if (a.bracket !== b.bracket) return order[a.bracket] - order[b.bracket];
				if (a.ronda !== b.ronda) return a.ronda - b.ronda;
				return a.posicioMin - b.posicioMin;
			});

			// Codis seqüencials dins de cada (bracket, ronda)
			const codeByMatchId = new Map<string, string>();
			const counterByKey = new Map<string, number>();
			const matchPosByMatchId = new Map<string, number>();
			for (const e of enriched) {
				const key = `${e.bracket}-${e.ronda}`;
				const next = (counterByKey.get(key) ?? 0) + 1;
				counterByKey.set(key, next);
				const code = e.bracket === 'grand_final'
					? `GF${e.ronda}`
					: `${e.bracket === 'winners' ? 'W' : 'L'}${e.ronda}.${next}`;
				codeByMatchId.set(e.m.id, code);
				matchPosByMatchId.set(e.m.id, next);
			}

			const destinationCode = (slotId: string | null): string => {
				if (!slotId) return '—';
				const m = matchBySlot.get(slotId);
				if (!m) return '—';
				return codeByMatchId.get(m.id) ?? '—';
			};

			const slotName = (s: Slot | undefined): string | null => {
				if (!s) return null;
				if (s.is_bye) return 'BYE';
				if (s.participant_id) {
					return nameMap.get(s.participant_id) ?? null;
				}
				return null;
			};

			// Distancia (caramboles objectiu) d'un jugador: es coneix tan aviat com
			// el jugador esta assignat, independentment que el rival estigui per
			// definir o que la partida encara no s'hagi jugat.
			const slotDist = (s: Slot | undefined, perMatch: number | null | undefined): number | null => {
				if (!s || s.is_bye || !s.participant_id) return null;
				return (perMatch ?? distMap.get(s.participant_id)) ?? null;
			};

			const buildResult = (raw: MatchRaw, s1: Slot | undefined, s2: Slot | undefined): MatchResult | null => {
				const estat = raw.estat;
				if (estat !== 'jugada' && estat !== 'walkover') return null;
				const winnerId = raw.guanyador_participant_id ?? null;
				if (!winnerId) return null;
				let winnerSlot: 1 | 2 | null = null;
				if (s1?.participant_id && s1.participant_id === winnerId) winnerSlot = 1;
				else if (s2?.participant_id && s2.participant_id === winnerId) winnerSlot = 2;
				return {
					estat,
					isWalkover: estat === 'walkover',
					caramboles1: raw.caramboles1 ?? null,
					caramboles2: raw.caramboles2 ?? null,
					entrades: raw.entrades ?? null,
					distancia1: raw.distancia_jugador1 ?? null,
					distancia2: raw.distancia_jugador2 ?? null,
					winnerSlot
				};
			};

			const matchViews: MatchView[] = enriched.map(e => {
				const s1 = slotById.get(e.m.slot1_id);
				const s2 = slotById.get(e.m.slot2_id);
				return {
					id: e.m.id,
					code: codeByMatchId.get(e.m.id) ?? '?',
					matchPos: matchPosByMatchId.get(e.m.id) ?? 1,
					bracket: e.bracket,
					ronda: e.ronda,
					slot1Pos: s1?.posicio ?? 0,
					slot2Pos: s2?.posicio ?? 0,
					slot1Name: slotName(s1),
					slot2Name: slotName(s2),
					slot1Dist: slotDist(s1, e.m.distancia_jugador1),
					slot2Dist: slotDist(s2, e.m.distancia_jugador2),
					winnerDest: destinationCode(e.m.winner_slot_dest_id),
					loserDest: destinationCode(e.m.loser_slot_dest_id),
					schedule: scheduleById.get(e.m.id) ?? null,
					result: useRealData ? buildResult(e.m, s1, s2) : null
				};
			});

			allViews = matchViews;
			totalMatches = matchViews.length;

			// Agrupar per bracket (Grand Final s'afegeix al final de winners en l'última pàgina)
			const winnersByRonda = new Map<number, MatchView[]>();
			const losersByRonda = new Map<number, MatchView[]>();
			const gfList: MatchView[] = [];

			for (const mv of matchViews) {
				if (mv.bracket === 'winners') {
					if (!winnersByRonda.has(mv.ronda)) winnersByRonda.set(mv.ronda, []);
					winnersByRonda.get(mv.ronda)!.push(mv);
				} else if (mv.bracket === 'losers') {
					if (!losersByRonda.has(mv.ronda)) losersByRonda.set(mv.ronda, []);
					losersByRonda.get(mv.ronda)!.push(mv);
				} else {
					gfList.push(mv);
				}
			}

			const winnersSorted: Array<[number, MatchView[]]> = [...winnersByRonda.entries()].sort((a, b) => a[0] - b[0]);
			const losersSorted: Array<[number, MatchView[]]> = [...losersByRonda.entries()].sort((a, b) => a[0] - b[0]);

			// Afegir Grand Final com a "ronda" extra al final del bracket Winners
			if (gfList.length > 0) {
				winnersSorted.push([99, gfList]);
			}

			const totalWin = winnersSorted.reduce((acc, [, arr]) => acc + arr.length, 0);
			const totalLos = losersSorted.reduce((acc, [, arr]) => acc + arr.length, 0);

			// Decisió auto: >16 matches en un bracket → 2 fulls
			winnersPages = splitInPages(winnersSorted, totalWin);
			losersPages = splitInPages(losersSorted, totalLos);

			loading = false;
		} catch (e: any) {
			error = e.message || 'Error carregant el bracket';
			loading = false;
		}
	}

	// Divideix un bracket en N pàgines. Cap ronda es parteix entre fulls
	// (les rondes són atòmiques). El criteri d'acceptació és l'alçada
	// estimada de cada ronda dins de `.rounds` (que té overflow:hidden i
	// limita l'alçada a ~257mm a A3 landscape).
	//
	// Una ronda ocupa: títol (≈8mm) + 2mm + ceil(N/5) × 35mm. Després,
	// gap entre rondes = 4mm. Amb una W2 de 8 matches que necessita 2 files
	// (80mm) + 4 rondes d'1 fila (45mm × 4 = 180mm) + 4 gaps = 276mm, per
	// això un MAX_RONDES_PER_PAGE = 5 fallava (GF queda retallat). Limitem
	// pel total estimat en mm.
	const MAX_MATCHES_PER_PAGE = 18;
	const COLS_PER_ROW = 5;
	const PAGE_AVAILABLE_MM = 210; // conservador: marge per a cel·les amb
	// contingut variable (schedule + deadline + noms llargs poden créixer +5mm).
	function rondaHeightMm(matchCount: number): number {
		const gridRows = Math.max(1, Math.ceil(matchCount / COLS_PER_ROW));
		return 8 + 2 + gridRows * 35; // títol + intern-gap + files
	}
	function splitInPages(
		rondesSorted: Array<[number, MatchView[]]>,
		total: number
	): Array<Array<[number, MatchView[]]>> {
		if (rondesSorted.length === 0) return [];
		const pages: Array<Array<[number, MatchView[]]>> = [];
		let current: Array<[number, MatchView[]]> = [];
		let accMatches = 0;
		let accHeight = 0;
		for (const entry of rondesSorted) {
			const h = rondaHeightMm(entry[1].length);
			const additional = current.length === 0 ? h : h + 4; // 4mm gap
			const wouldExceedMatches = accMatches + entry[1].length > MAX_MATCHES_PER_PAGE;
			const wouldExceedHeight = accHeight + additional > PAGE_AVAILABLE_MM;
			if (current.length > 0 && (wouldExceedMatches || wouldExceedHeight)) {
				pages.push(current);
				current = [];
				accMatches = 0;
				accHeight = 0;
			}
			current.push(entry);
			accMatches += entry[1].length;
			accHeight += current.length === 1 ? h : h + 4;
		}
		if (current.length > 0) pages.push(current);
		return pages;
	}

	function fmtDate(d: Date): string {
		const dd = String(d.getDate()).padStart(2, '0');
		const mm = String(d.getMonth() + 1).padStart(2, '0');
		return `${dd}/${mm}`;
	}


	// ── Disposició VISUAL en arbre (per a impressió A3) ──────────────────────
	function treeRoundLabel(kind: 'winners' | 'losers', r: number, rounds: number[], isGf = false, gfR = 0): string {
		if (isGf) return gfR === 1 ? 'Gran Final' : 'Reset';
		if (kind === 'winners') return r === rounds[rounds.length - 1] ? 'Final principal' : `Principal R${r}`;
		return r === rounds[rounds.length - 1] ? 'Final repesca' : `Repesca R${r}`;
	}

	type TreeCell = { mv: MatchView; x: number; top: number };
	type TreeCol = { x: number; label: string };
	type TreeLine = { x1: number; y1: number; x2: number; y2: number };
	type TreeSheet = { columns: TreeCol[]; cells: TreeCell[]; lines: TreeLine[]; stubs: Array<{ x: number; y: number; label: string }>; notes: Array<{ x: number; y: number; label: string }>; naturalW: number; naturalH: number; scale: number; suffix: string };

	// Linies de connector entre cel.les d'un MATEIX full (agrupant per la
	// destinacio de guanyador; les que creuen de full no es dibuixen).
	function buildSheetLines(
		cells: TreeCell[],
		posByCode: Map<string, { x: number; right: number; centerY: number }>
	): { lines: TreeLine[]; stubs: Array<{ x: number; y: number; label: string }>; notes: Array<{ x: number; y: number; label: string }> } {
		const lines: TreeLine[] = [];
		const stubs: Array<{ x: number; y: number; label: string }> = [];
		const notes: Array<{ x: number; y: number; label: string }> = [];
		const sourcesByTarget = new Map<string, TreeCell[]>();
		for (const c of cells) {
			const tgt = c.mv.winnerDest;
			if (!tgt || tgt === '—') continue;
			const sp = posByCode.get(c.mv.code);
			if (!sp) continue;
			if (posByCode.has(tgt)) {
				if (!sourcesByTarget.has(tgt)) sourcesByTarget.set(tgt, []);
				sourcesByTarget.get(tgt)!.push(c);
				// GF1 -> GF2 (reset): nomes es juga si J1 (campio del quadre de
				// guanyadors) perd; si J1 guanya, ja es campio.
				if (c.mv.bracket === 'grand_final' && c.mv.ronda === 1) {
					notes.push({ x: sp.right, y: sp.centerY, label: 'si J1 perd' });
				}
			} else {
				// Desti en un altre full: tram curt + etiqueta cap a la dreta.
				lines.push({ x1: sp.right, y1: sp.centerY, x2: sp.right + V_STUB_LEN, y2: sp.centerY });
				stubs.push({ x: sp.right + V_STUB_LEN, y: sp.centerY, label: tgt });
			}
		}
		for (const [target, srcs] of sourcesByTarget) {
			const tp = posByCode.get(target)!;
			const sorted = srcs
				.map((c) => posByCode.get(c.mv.code))
				.filter((pp): pp is { x: number; right: number; centerY: number } => !!pp)
				.sort((a, b) => a.centerY - b.centerY);
			if (sorted.length === 0) continue;
			const srcRight = sorted[0].right;
			const midX = srcRight + (tp.x - srcRight) / 2;
			if (sorted.length >= 2) {
				const y1 = sorted[0].centerY;
				const y2 = sorted[sorted.length - 1].centerY;
				for (const sp of sorted) lines.push({ x1: sp.right, y1: sp.centerY, x2: midX, y2: sp.centerY });
				lines.push({ x1: midX, y1, x2: midX, y2 });
				lines.push({ x1: midX, y1: tp.centerY, x2: tp.x, y2: tp.centerY });
			} else {
				const sp = sorted[0];
				if (Math.abs(sp.centerY - tp.centerY) < 0.5) {
					lines.push({ x1: sp.right, y1: sp.centerY, x2: tp.x, y2: tp.centerY });
				} else {
					lines.push({ x1: sp.right, y1: sp.centerY, x2: midX, y2: sp.centerY });
					lines.push({ x1: midX, y1: sp.centerY, x2: midX, y2: tp.centerY });
					lines.push({ x1: midX, y1: tp.centerY, x2: tp.x, y2: tp.centerY });
				}
			}
		}
		return { lines, stubs, notes };
	}

	// Empaqueta un subconjunt de cel.les en un full A3 apaisat: desplaca
	// verticalment (yShift) i calcula posicions, linies i escala d'ajust.
	function packSheet(
		src: Array<{ mv: MatchView; x: number; topFull: number }>,
		columns: TreeCol[],
		yShift: number,
		suffix: string
	): TreeSheet | null {
		if (src.length === 0) return null;
		const cells: TreeCell[] = src.map((c) => ({ mv: c.mv, x: c.x, top: c.topFull - yShift }));
		const posByCode = new Map<string, { x: number; right: number; centerY: number }>();
		for (const c of cells) posByCode.set(c.mv.code, { x: c.x, right: c.x + V_CELL_W, centerY: c.top + V_CELL_H / 2 });
		const { lines, stubs, notes } = buildSheetLines(cells, posByCode);
		const usedCols = columns.filter((col) => cells.some((c) => c.x === col.x));
		const colsRight = usedCols.length > 0 ? Math.max(...usedCols.map((col) => col.x + V_CELL_W)) : V_CELL_W;
		const stubsRight = stubs.length > 0 ? Math.max(...stubs.map((st) => st.x + V_STUB_LABEL_W)) : 0;
		const naturalW = Math.max(colsRight, stubsRight);
		const naturalH = Math.max(V_HEADER_H + V_SLOT, ...cells.map((c) => c.top + V_CELL_H)) + 2;
		const scale = Math.min(1, V_LAND_W / naturalW, V_LAND_H / naturalH);
		return { columns: usedCols, cells, lines, stubs, notes, naturalW, naturalH, scale, suffix };
	}

	type RoundDef = { label: string; matches: MatchView[] };

	// Col·loca verticalment les partides d'un full centrant cada partida respecte
	// les seves partides d'origen (les que hi aboquen via winnerDest) presents al
	// full, i empaqueta el resultat. La primera columna s'espaia seqüencialment;
	// cap a la dreta es fa la mitjana dels centres dels orígens, amb una passada
	// que empeny avall per evitar solapaments. Així les línies connectores quadren.
	function packCentered(columns: TreeCol[], colMatches: MatchView[][], suffix: string): TreeSheet | null {
		const cells: Array<{ mv: MatchView; x: number; topFull: number }> = [];
		const MIN_SPACING = V_CELL_H + 4;
		for (let ci = 0; ci < columns.length; ci++) {
			const x = columns[ci].x;
			const ms = colMatches[ci];
			let cursor = -Infinity;
			for (let mi = 0; mi < ms.length; mi++) {
				const mv = ms[mi];
				let center: number;
				if (ci === 0) {
					center = V_HEADER_H + V_CELL_H / 2 + mi * V_SLOT;
				} else {
					const srcCenters = cells
						.filter((c) => c.mv.winnerDest === mv.code)
						.map((c) => c.topFull + V_CELL_H / 2);
					center = srcCenters.length
						? srcCenters.reduce((a, b) => a + b, 0) / srcCenters.length
						: cursor === -Infinity
							? V_HEADER_H + V_CELL_H / 2
							: cursor + MIN_SPACING;
					if (cursor !== -Infinity && center < cursor + MIN_SPACING) {
						center = cursor + MIN_SPACING;
					}
				}
				cells.push({ mv, x, topFull: center - V_CELL_H / 2 });
				cursor = center;
			}
		}
		return packSheet(cells, columns, 0, suffix);
	}

	function buildSheets(views: MatchView[], kind: 'winners' | 'losers'): TreeSheet[] {
		if (!views || views.length === 0) return [];
		const main = views.filter((v) => v.bracket === (kind === 'winners' ? 'winners' : 'losers'));
		const gf = kind === 'winners' ? views.filter((v) => v.bracket === 'grand_final') : [];
		if (main.length === 0 && gf.length === 0) return [];

		const mainRounds = [...new Set(main.map((v) => v.ronda))].sort((a, b) => a - b);
		const gfRounds = [...new Set(gf.map((v) => v.ronda))].sort((a, b) => a - b);
		const colGap = kind === 'winners' ? V_COL_GAP_WIN : V_COL_GAP;
		const sheets: TreeSheet[] = [];
		const roundDefs: RoundDef[] = [
			...mainRounds.map((r) => ({
				label: treeRoundLabel(kind, r, mainRounds),
				matches: main.filter((v) => v.ronda === r).sort((a, b) => a.matchPos - b.matchPos)
			})),
			...gfRounds.map((r) => ({
				label: treeRoundLabel(kind, 0, [], true, r),
				matches: gf.filter((v) => v.ronda === r).sort((a, b) => a.matchPos - b.matchPos)
			}))
		];
		if (roundDefs.length === 0) return [];

		const mkCols = (defs: RoundDef[]): TreeCol[] =>
			defs.map((rd, ci) => ({ x: ci * (V_CELL_W + colGap), label: rd.label }));

		// ── Winners: paginació PER BRANQUES (sub-arbres) ──────────────────────
		// Cada full és una branca COMPLETA (de R1 fins on convergeix) i un full
		// final recull les rondes de convergència (semis/final) + Gran Final.
		// Així les dues partides d'origen de cada partida són SEMPRE al mateix
		// full i les línies queden alineades, sense talls a mig arbre.
		if (kind === 'winners') {
			const r1Count = roundDefs[0].matches.length;
			let groups = 1;
			while (Math.ceil(r1Count / groups) > V_MAX_CELLS_PER_SHEET) groups *= 2;

			if (groups > 1) {
				// Rondes que es reparteixen netament entre branques (count % groups === 0)
				// formen les branques; la resta (convergència) va al full final.
				const branchDefs: RoundDef[] = [];
				const convDefs: RoundDef[] = [];
				let inConv = false;
				for (const rd of roundDefs) {
					if (!inConv && rd.matches.length >= groups && rd.matches.length % groups === 0) {
						branchDefs.push(rd);
					} else {
						inConv = true;
						convDefs.push(rd);
					}
				}
				for (let g = 0; g < groups; g++) {
					const cols = mkCols(branchDefs);
					const colMatches = branchDefs.map((rd) => {
						const per = rd.matches.length / groups;
						return rd.matches.slice(g * per, (g + 1) * per);
					});
					const sheet = packCentered(cols, colMatches, `· branca ${g + 1}/${groups}`);
					if (sheet) sheets.push(sheet);
				}
				for (let i = 0; i < convDefs.length; i += V_MAX_ROUNDS_PER_SHEET) {
					const chunk = convDefs.slice(i, i + V_MAX_ROUNDS_PER_SHEET);
					const suffix = convDefs.length > V_MAX_ROUNDS_PER_SHEET
						? `· finals ${Math.floor(i / V_MAX_ROUNDS_PER_SHEET) + 1}`
						: '· finals';
					const sheet = packCentered(mkCols(chunk), chunk.map((rd) => rd.matches), suffix);
					if (sheet) sheets.push(sheet);
				}
				return sheets;
			}

			// groups === 1: el bracket cap en un full (o partit per rondes si n'hi ha moltes).
			for (let i = 0; i < roundDefs.length; i += V_MAX_ROUNDS_PER_SHEET) {
				const chunk = roundDefs.slice(i, i + V_MAX_ROUNDS_PER_SHEET);
				const suffix = roundDefs.length > V_MAX_ROUNDS_PER_SHEET
					? `· bloc ${Math.floor(i / V_MAX_ROUNDS_PER_SHEET) + 1}`
					: '';
				const sheet = packCentered(mkCols(chunk), chunk.map((rd) => rd.matches), suffix);
				if (sheet) sheets.push(sheet);
			}
			return sheets;
		}

		// ── Losers: blocs de rondes + bandes verticals (amb centrat per orígens) ──
		const roundChunks: RoundDef[][] = [];
		for (let i = 0; i < roundDefs.length; i += V_MAX_ROUNDS_PER_SHEET) {
			roundChunks.push(roundDefs.slice(i, i + V_MAX_ROUNDS_PER_SHEET));
		}
		for (let chunkIndex = 0; chunkIndex < roundChunks.length; chunkIndex++) {
			const chunk = roundChunks[chunkIndex];
			const densestRound = Math.max(...chunk.map((r) => r.matches.length));
			const verticalPages = Math.max(1, Math.ceil(densestRound / V_MAX_CELLS_PER_SHEET));

			for (let pageIndex = 0; pageIndex < verticalPages; pageIndex++) {
				const columns: TreeCol[] = [];
				const colMatches: MatchView[][] = [];
				for (let colIndex = 0; colIndex < chunk.length; colIndex++) {
					const round = chunk[colIndex];
					const x = colIndex * (V_CELL_W + colGap);
					const perPage = Math.ceil(round.matches.length / verticalPages);
					const pageMatches = round.matches.slice(pageIndex * perPage, (pageIndex + 1) * perPage);
					if (pageMatches.length === 0) continue;
					columns.push({ x, label: round.label });
					colMatches.push(pageMatches);
				}
				const chunkSuffix = roundChunks.length > 1 ? `· bloc ${chunkIndex + 1}/${roundChunks.length}` : '';
				const pageSuffix = verticalPages > 1 ? ` · tram ${pageIndex + 1}/${verticalPages}` : '';
				const sheet = packCentered(columns, colMatches, `${chunkSuffix}${pageSuffix}`);
				if (sheet) sheets.push(sheet);
			}
		}
		return sheets;
	}

	$: visualSheets = [
		...buildSheets(allViews.filter((v) => v.bracket !== 'losers'), 'winners').map((sh) => ({ ...sh, section: 'Bracket Principal' })),
		...buildSheets(allViews.filter((v) => v.bracket === 'losers'), 'losers').map((sh) => ({ ...sh, section: 'Bracket Repesca' }))
	];
	$: visualFulls = visualSheets.length;

	function doPrint() {
		// Obrir una finestra nova amb HTML i CSS independents. Així evitem que
		// l'app principal interfereixi i el navegador respecta el @page correctament.
		const previewEl = document.querySelector('.print-portal .print-preview');
		if (!previewEl) {
			window.print();
			return;
		}

		// URL absoluta del logo (amb origin + base de SvelteKit, perquè a GitHub
		// Pages el path arrel pot tenir un prefix).
		const logoUrl = `${window.location.origin}${base}/logo-billar.svg`;
		const innerHTML = previewEl.innerHTML.replace(
			/src="[^"]*logo-billar\.svg"/g,
			`src="${logoUrl}"`
		);

		const w = window.open('', '_blank', 'width=1100,height=800');
		if (!w) {
			alert("No s'ha pogut obrir la finestra d'impressió. Permet finestres emergents per a aquest lloc.");
			return;
		}

		const css = String.raw`
			@page { size: A3 landscape; margin: 5mm; }
			@page { size: 420mm 297mm; margin: 5mm; }
			* { box-sizing: border-box; }
			html, body { margin: 0; padding: 0; background: white; font-family: 'Helvetica Neue', Arial, sans-serif; color: #1f1f1f; }
			.print-page {
				background: white;
				width: 420mm; height: 287mm; /* buffer 10mm per evitar tall en impressora */
				padding: 8mm 10mm;
				margin: 0;
				box-sizing: border-box;
				display: flex; flex-direction: column;
				page-break-after: always;
				break-after: page;
			}
			.print-page:last-child { page-break-after: auto; break-after: auto; }
			.page-head {
				display: flex; justify-content: space-between; align-items: center;
				border-bottom: 2px solid #1f1f1f; padding-bottom: 4mm; margin-bottom: 4mm; gap: 6mm;
			}
			.page-head-left { display: flex; align-items: center; gap: 5mm; min-width: 0; }
			.page-logo {
				height: 18mm; width: 12mm; flex: none;
				object-fit: contain;
				display: inline-flex; align-items: center; justify-content: center;
			}
			.page-logo svg { width: 100%; height: 100%; display: block; }
			.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
			.page-title-main { font-weight: 800; font-size: 16pt; letter-spacing: 0.02em; line-height: 1.1; text-transform: uppercase; }
			.page-section { font-size: 11pt; color: #444; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
			.page-sub { font-size: 10pt; color: #555; text-align: right; }
			.rounds { display: flex; flex-direction: column; gap: 4mm; flex: 1; overflow: hidden; }
			.round-section { display: flex; flex-direction: column; gap: 2mm; page-break-inside: avoid; break-inside: avoid; }
			.round-title {
				font-size: 10pt; font-weight: 700; letter-spacing: 0.05em;
				text-transform: uppercase; color: #1f1f1f;
				border-left: 4px solid #1f1f1f; padding-left: 3mm; margin: 0;
			}
			.match-grid {
				display: grid;
				grid-template-columns: repeat(auto-fill, minmax(70mm, 1fr));
				gap: 3mm;
			}
			.match-cell {
				border: 1.5px solid #1f1f1f;
				padding: 2mm 2.5mm;
				display: flex; flex-direction: column; gap: 1.5mm;
				min-height: 32mm; font-size: 9pt;
				page-break-inside: avoid;
				break-inside: avoid;
			}
			.round-section {
				page-break-inside: avoid;
				break-inside: avoid;
			}
			.cell-head {
				display: flex; justify-content: space-between; align-items: baseline;
				font-size: 8.5pt; border-bottom: 1px solid #999; padding-bottom: 1mm;
			}
			.match-code { font-weight: 800; font-size: 11pt; letter-spacing: 0.04em; }
			.arrows { display: flex; gap: 3mm; flex-wrap: wrap; font-size: 8pt; color: #333; }
			.arrows strong { font-weight: 700; }
			.arrow-win { color: #1d6e3a; }
			.arrow-lose { color: #a30b1e; }
			.arrow-win strong, .arrow-lose strong { color: inherit; }
			.player-row, .entries-row { display: flex; align-items: center; gap: 1mm; font-size: 8pt; }
			.label { font-weight: 700; font-size: 7.5pt; text-transform: uppercase; color: #555; min-width: 5mm; }
			.kv { font-size: 7.5pt; color: #555; font-weight: 600; }
			.line { flex: 1; border-bottom: 1px solid #1f1f1f; height: 5mm; }
			.line.filled {
				display: flex; align-items: center;
				font-size: 9pt; font-weight: 700; color: #1f1f1f;
				padding: 0 1mm; line-height: 5mm; height: 5mm;
				white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
			}
			.box { display: inline-block; border: 1px solid #1f1f1f; height: 5mm; width: 14mm; }
			.box.small { width: 9mm; }
			.box.filled-box {
				display: inline-flex; align-items: center; justify-content: center;
				font-size: 8.5pt; font-weight: 700; color: #1f1f1f; background: #f5f5f5;
			}
			.winner-row { font-weight: 800; }
			.winner-row .line.filled { font-weight: 800; }
			.winner-mark { color: #1d6e3a; font-weight: 800; margin-right: 0.6mm; }
			.loser-row { opacity: 0.55; }
			.schedule-row {
				display: flex; justify-content: space-between; align-items: baseline;
				gap: 2mm; margin-top: 1mm; padding-top: 1mm;
				border-top: 1px dashed #999;
				font-size: 7.5pt;
			}
			.sched-slot { font-weight: 700; color: #1f1f1f; }
			.sched-deadline { color: #a30b1e; font-weight: 600; }
			.tree-wrap { position: relative; overflow: hidden; margin: 0; }
			.tree-canvas { position: relative; transform-origin: 0 0; }
			.tree-svg { position: absolute; left: 0; top: 0; z-index: 0; pointer-events: none; }
			.col-head { position: absolute; top: 0; height: 6mm; display: flex; align-items: center; font-size: 11pt; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; color: #1f1f1f; border-left: 3px solid #1f1f1f; padding-left: 1.5mm; }
			.stub-label { position: absolute; font-size: 9pt; font-weight: 700; color: #1f1f1f; white-space: nowrap; display: flex; align-items: center; }
			.cond-label { position: absolute; font-size: 7.5pt; font-style: italic; font-weight: 600; color: #1f1f1f; white-space: nowrap; }
			.match-cell.vcell { position: absolute; min-height: 0; overflow: visible; background: white; z-index: 1; gap: 1mm; }
			.match-cell.vcell .match-code { font-size: 13pt; }
			.match-cell.vcell .cell-head { font-size: 9.5pt; }
			.match-cell.vcell .arrows { font-size: 9pt; }
			.match-cell.vcell .player-row, .match-cell.vcell .entries-row { font-size: 10pt; }
			.match-cell.vcell .label, .match-cell.vcell .kv { font-size: 9pt; }
			.match-cell.vcell .line.filled { font-size: 11pt; }
			.match-cell.vcell .box.filled-box { font-size: 10pt; }
			.match-cell.vcell .schedule-row { font-size: 9pt; }
		`;

		// Concatenem `<script>` separat perquè el parser de Svelte
		// no es pensi que volem un bloc d'script real al component.
		const scriptOpen = '<' + 'script>';
		const scriptClose = '<' + '/script>';
		const printScript = scriptOpen +
			"window.addEventListener('load', function () {" +
			"  var imgs = Array.from(document.images);" +
			"  var ready = imgs.length === 0 ? Promise.resolve() :" +
			"    Promise.all(imgs.map(function (img) {" +
			"      return img.complete ? null : new Promise(function (r) { img.onload = img.onerror = r; });" +
			"    }));" +
			"  ready.then(function () { setTimeout(function () { window.print(); }, 100); });" +
			"});" +
			scriptClose;

		const html = `<!DOCTYPE html>
<html lang="ca">
<head>
<meta charset="utf-8" />
<title>Bracket — ${(eventNom || 'Hàndicap').replace(/[<>&"]/g, '')}</title>
<style>${css}</style>
</head>
<body>
${innerHTML}
${printScript}
</body>
</html>`;

		w.document.open();
		w.document.write(html);
		w.document.close();
	}
</script>

<div class="print-modal-overlay print-portal" use:printPortal on:click|self={onClose} role="presentation">
	<div class="print-modal-card" role="dialog" aria-modal="true">
		<div class="print-modal-head no-print">
			<h2 class="print-modal-title">Imprimir bracket per a la pissarra</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="print-modal-toolbar no-print">
			<div class="toolbar-info">
				{#if loading}
					<span>Carregant bracket…</span>
				{:else if error}
					<span class="err">{error}</span>
				{:else}
					<span>
						{totalMatches} partides · {visualFulls} fulls A3
						({winnersPages.length} principal + {losersPages.length} repesca)
					</span>
					<span class="hint">
						Al diàleg d'imprimir tria <strong>A3</strong> i orientació <strong>Apaisat / Horitzontal</strong>.
						Per a PDF: destinació <em>Guardar com a PDF</em>.
					</span>
				{/if}
				{#if !eventId && !hasRealBracket}
					<label class="count-label">
						Jugadors:
						<input
							type="number"
							min="2"
							max="128"
							bind:value={inputCount}
							class="count-input"
						/>
					</label>
					<button type="button" class="btn-secondary" on:click={regenerate} disabled={loading || inputCount < 2}>
						Recalcular
					</button>
				{/if}
			</div>
			<div class="toolbar-actions">
				<button type="button" class="btn-secondary" on:click={onClose}>Tancar</button>
				<button
					type="button"
					class="btn-primary"
					on:click={doPrint}
					disabled={loading || !!error}
					title="Al diàleg d'imprimir, tria 'Guardar com a PDF' per descarregar el bracket"
				>
					Imprimir / Desar PDF
				</button>
			</div>
		</div>

		{#if !loading && !error}
			<div class="print-warning no-print">
				⚠ <strong>Important:</strong> al diàleg d'imprimir, tria <strong>paper A3</strong> i orientació <strong>Apaisat / Horitzontal</strong>. Si el navegador imprimeix amb A4 vertical, el bracket sortirà tallat.
			</div>
			<div class="print-preview">
				{#each visualSheets as sheet}
					{#if sheet}
						<section class="print-page">
							<header class="page-head">
								<div class="page-head-left">
									<img src={logoDataUrl || `${base}/logo.png`} alt="" class="page-logo" />
									<div class="page-head-titles">
										<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
										<div class="page-section">{sheet.section} {sheet.suffix}</div>
									</div>
								</div>
								{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
							</header>
							<div class="tree-wrap" style="width:{sheet.naturalW * sheet.scale}mm; height:{sheet.naturalH * sheet.scale}mm;">
								<div class="tree-canvas" style="width:{sheet.naturalW}mm; height:{sheet.naturalH}mm; transform: scale({sheet.scale});">
									<svg class="tree-svg" width="{sheet.naturalW}mm" height="{sheet.naturalH}mm" viewBox="0 0 {sheet.naturalW} {sheet.naturalH}" preserveAspectRatio="none">
										{#each sheet.lines as l}
											<line x1={l.x1} y1={l.y1} x2={l.x2} y2={l.y2} stroke="#1f1f1f" stroke-width="0.3" />
										{/each}
									</svg>
									{#each sheet.columns as col}
										<div class="col-head" style="left:{col.x}mm; width:{V_CELL_W}mm;">{col.label}</div>
									{/each}
									{#each sheet.stubs as st}
										<div class="stub-label" style="left:{st.x + 1}mm; top:{st.y - 2}mm;">&rarr; {st.label}</div>
									{/each}
									{#each sheet.notes as nt}
										<div class="cond-label" style="left:{nt.x + 1}mm; top:{nt.y - 4.5}mm;">{nt.label}</div>
									{/each}
									{#each sheet.cells as cell}
										<div class="match-cell vcell" class:played={!!cell.mv.result} style="left:{cell.x}mm; top:{cell.top}mm; width:{V_CELL_W}mm; height:{V_CELL_H}mm;">
											<div class="cell-head">
												<span class="match-code">{cell.mv.code}</span>
												<span class="arrows">
													<span class="arrow-win">↗W <strong>{cell.mv.winnerDest}</strong></span>
													{#if cell.mv.loserDest !== '—'}<span class="arrow-lose">↘L <strong>{cell.mv.loserDest}</strong></span>{/if}
												</span>
											</div>
											<div class="player-row" class:winner-row={cell.mv.result?.winnerSlot === 1} class:loser-row={!!cell.mv.result && cell.mv.result.winnerSlot === 2}>
												<span class="label">{#if cell.mv.result?.winnerSlot === 1}<span class="winner-mark">▶</span>{/if}{cell.mv.bracket === 'winners' && cell.mv.ronda === 1 ? `#${cell.mv.slot1Pos}` : 'J1'}</span>
												{#if cell.mv.slot1Name}<span class="line filled">{cell.mv.slot1Name}</span>{:else}<span class="line"></span>{/if}
												{#if cell.mv.result}<span class="kv">D</span><span class="box small filled-box">{cell.mv.result.distancia1 ?? cell.mv.slot1Dist ?? ''}</span><span class="kv">C</span><span class="box small filled-box">{cell.mv.result.isWalkover ? 'WO' : (cell.mv.result.caramboles1 ?? '')}</span>{:else}<span class="kv">D</span>{#if cell.mv.slot1Dist != null}<span class="box small filled-box">{cell.mv.slot1Dist}</span>{:else}<span class="box small"></span>{/if}<span class="kv">C</span><span class="box small"></span>{/if}
											</div>
											<div class="player-row" class:winner-row={cell.mv.result?.winnerSlot === 2} class:loser-row={!!cell.mv.result && cell.mv.result.winnerSlot === 1}>
												<span class="label">{#if cell.mv.result?.winnerSlot === 2}<span class="winner-mark">▶</span>{/if}{cell.mv.bracket === 'winners' && cell.mv.ronda === 1 ? `#${cell.mv.slot2Pos}` : 'J2'}</span>
												{#if cell.mv.slot2Name}<span class="line filled">{cell.mv.slot2Name}</span>{:else}<span class="line"></span>{/if}
												{#if cell.mv.result}<span class="kv">D</span><span class="box small filled-box">{cell.mv.result.distancia2 ?? cell.mv.slot2Dist ?? ''}</span><span class="kv">C</span><span class="box small filled-box">{cell.mv.result.isWalkover ? 'WO' : (cell.mv.result.caramboles2 ?? '')}</span>{:else}<span class="kv">D</span>{#if cell.mv.slot2Dist != null}<span class="box small filled-box">{cell.mv.slot2Dist}</span>{:else}<span class="box small"></span>{/if}<span class="kv">C</span><span class="box small"></span>{/if}
											</div>
											<div class="entries-row"><span class="kv">Ent</span>{#if cell.mv.result}<span class="box filled-box">{cell.mv.result.isWalkover ? 'WO' : (cell.mv.result.entrades ?? '')}</span>{:else}<span class="box"></span>{/if}</div>
											{#if cell.mv.schedule}<div class="schedule-row"><span class="sched-slot">{fmtDate(cell.mv.schedule.dataProgramada)} · {cell.mv.schedule.horaInici} · B{cell.mv.schedule.taulaAssignada}</span><span class="sched-deadline">màx: {fmtDate(cell.mv.schedule.dataMaximaDisputa)}</span></div>{/if}
										</div>
									{/each}
								</div>
							</div>
						</section>
					{/if}
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.print-modal-overlay {
		position: fixed; inset: 0; z-index: 100;
		background: rgba(0,0,0,0.6);
		display: flex; align-items: stretch; justify-content: center;
		padding: 1rem;
	}
	.print-modal-card {
		background: white; width: 100%; max-width: 1400px;
		max-height: 100%;
		display: flex; flex-direction: column;
	}
	.print-modal-head {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #ddd;
	}
	.print-modal-title { font-size: 1.05rem; font-weight: 700; margin: 0; }
	.close-btn {
		font-size: 1.5rem; background: transparent; border: none; cursor: pointer;
	}
	.print-modal-toolbar {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.5rem 1rem; border-bottom: 1px solid #eee;
		font-size: 0.875rem; color: #444;
	}
	.toolbar-info { display: flex; gap: 0.85rem; align-items: center; flex-wrap: wrap; }
	.toolbar-actions { display: flex; gap: 0.5rem; }
	.count-label { display: inline-flex; align-items: center; gap: 0.35rem; font-weight: 600; }
	.count-input {
		width: 4.5rem; padding: 0.25rem 0.4rem;
		border: 1px solid #333; border-radius: 0;
		font-size: 0.875rem;
	}
	.hint { color: #555; font-size: 0.8125rem; }
	.hint em { font-style: italic; font-weight: 600; color: #1f1f1f; }
	.btn-primary, .btn-secondary {
		padding: 0.4rem 0.85rem; cursor: pointer; font-size: 0.875rem; font-weight: 600;
		border-radius: 0; border: 1px solid #333;
	}
	.btn-primary { background: #1f1f1f; color: white; }
	.btn-secondary { background: white; color: #1f1f1f; }
	.err { color: #a30b1e; font-weight: 600; }

	.print-preview { overflow: auto; flex: 1; padding: 1rem; background: #ececec; }
	.print-warning {
		padding: 0.65rem 1rem;
		background: #fff3cd;
		border-bottom: 1px solid #f0d68c;
		color: #6b4f00;
		font-size: 0.875rem;
		line-height: 1.4;
	}
	.print-warning strong { color: #4d3700; }

	.print-page {
		background: white;
		width: 420mm; height: 287mm; /* A3 landscape — buffer 10mm */
		padding: 8mm 10mm;
		margin: 0 auto 1rem auto;
		box-sizing: border-box;
		display: flex; flex-direction: column;
		page-break-after: always;
		break-after: page;
	}
	.print-page:last-child { page-break-after: auto; break-after: auto; }

	.page-head {
		display: flex; justify-content: space-between; align-items: center;
		border-bottom: 2px solid #1f1f1f; padding-bottom: 4mm; margin-bottom: 4mm;
		gap: 6mm;
	}
	.page-head-left {
		display: flex; align-items: center; gap: 5mm; min-width: 0;
	}
	.page-logo {
		/* viewBox 1024×1536 → ratio 2:3. Fixem width i height per evitar
		   deformacions en alguns navegadors (Chrome i Edge al print). */
		height: 18mm; width: 12mm; flex: none;
		object-fit: contain;
		display: inline-flex; align-items: center; justify-content: center;
	}
	.page-logo :global(svg) {
		width: 100%; height: 100%; display: block;
	}
	.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
	.page-title-main {
		font-weight: 800; font-size: 16pt;
		letter-spacing: 0.02em; line-height: 1.1;
		text-transform: uppercase;
	}
	.page-section {
		font-size: 11pt; color: #444; font-weight: 600;
		letter-spacing: 0.04em; text-transform: uppercase;
	}
	.page-sub { font-size: 10pt; color: #555; text-align: right; }

	.match-cell {
		border: 1.5px solid #1f1f1f;
		padding: 2mm 2.5mm;
		display: flex; flex-direction: column; gap: 1.5mm;
		min-height: 32mm;
		font-size: 9pt;
		page-break-inside: avoid;
		break-inside: avoid;
	}
	.cell-head {
		display: flex; justify-content: space-between; align-items: baseline;
		font-size: 8.5pt;
		border-bottom: 1px solid #999;
		padding-bottom: 1mm;
	}
	.match-code { font-weight: 800; font-size: 11pt; letter-spacing: 0.04em; }
	.arrows {
		display: flex; gap: 3mm; flex-wrap: wrap; font-size: 8pt; color: #333;
	}
	.arrows strong { font-weight: 700; }
	.arrow-win { color: #1d6e3a; }
	.arrow-lose { color: #a30b1e; }
	.arrow-win strong, .arrow-lose strong { color: inherit; }

	.player-row, .entries-row {
		display: flex; align-items: center; gap: 1mm;
		font-size: 8pt;
	}
	.schedule-row {
		display: flex; justify-content: space-between; align-items: baseline;
		gap: 2mm; margin-top: 1mm; padding-top: 1mm;
		border-top: 1px dashed #999;
		font-size: 7.5pt;
	}
	.sched-slot { font-weight: 700; color: #1f1f1f; }
	.sched-deadline { color: #a30b1e; font-weight: 600; }
	.label {
		font-weight: 700; font-size: 7.5pt; text-transform: uppercase;
		color: #555; min-width: 5mm;
	}
	.kv { font-size: 7.5pt; color: #555; font-weight: 600; }
	.line {
		flex: 1; border-bottom: 1px solid #1f1f1f; height: 5mm;
	}
	.line.filled {
		display: flex; align-items: center;
		font-size: 9pt; font-weight: 700; color: #1f1f1f;
		padding: 0 1mm; line-height: 5mm; height: 5mm;
		white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
	}
	.box {
		display: inline-block;
		border: 1px solid #1f1f1f;
		height: 5mm; width: 14mm;
	}
	.box.small { width: 9mm; }
	.box.filled-box {
		display: inline-flex; align-items: center; justify-content: center;
		font-size: 8.5pt; font-weight: 700; color: #1f1f1f;
		background: #f5f5f5;
	}
	.winner-row { font-weight: 800; }
	.winner-row :global(.line.filled) { font-weight: 800; }
	.winner-mark { color: #1d6e3a; font-weight: 800; margin-right: 0.6mm; }
	.loser-row { opacity: 0.55; }
	.tree-wrap { position: relative; overflow: hidden; margin: 0; }
	.tree-canvas { position: relative; transform-origin: 0 0; }
	.tree-svg { position: absolute; left: 0; top: 0; z-index: 0; pointer-events: none; }
	.col-head { position: absolute; top: 0; height: 6mm; display: flex; align-items: center; font-size: 11pt; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; color: #1f1f1f; border-left: 3px solid #1f1f1f; padding-left: 1.5mm; }
	.stub-label { position: absolute; font-size: 9pt; font-weight: 700; color: #1f1f1f; white-space: nowrap; display: flex; align-items: center; }
	.cond-label { position: absolute; font-size: 7.5pt; font-style: italic; font-weight: 600; color: #1f1f1f; white-space: nowrap; }
	.match-cell.vcell { position: absolute; min-height: 0; overflow: visible; background: white; z-index: 1; gap: 1mm; }
	.match-cell.vcell .match-code { font-size: 13pt; }
	.match-cell.vcell .cell-head { font-size: 9.5pt; }
	.match-cell.vcell .arrows { font-size: 9pt; }
	.match-cell.vcell .player-row, .match-cell.vcell .entries-row { font-size: 10pt; }
	.match-cell.vcell .label, .match-cell.vcell .kv { font-size: 9pt; }
	.match-cell.vcell .line.filled { font-size: 11pt; }
	.match-cell.vcell .box.filled-box { font-size: 10pt; }
	.match-cell.vcell .schedule-row { font-size: 9pt; }

	@media print {
		:global(body > *:not(.print-portal)) { display: none !important; }
		:global(.print-portal) {
			display: block !important;
			position: static !important;
			background: white !important;
			padding: 0 !important;
			inset: auto !important;
			z-index: auto !important;
			width: auto !important;
			height: auto !important;
			max-width: none !important;
			max-height: none !important;
			overflow: visible !important;
		}
		.no-print { display: none !important; }
		.print-modal-overlay {
			display: block !important;
			position: static !important;
			background: white !important;
			padding: 0 !important;
		}
		.print-modal-card {
			display: block !important;
			max-width: none !important;
			max-height: none !important;
			width: auto !important;
			height: auto !important;
			box-shadow: none !important;
		}
		.print-preview {
			display: block !important;
			background: white !important;
			padding: 0 !important;
			overflow: visible !important;
			flex: none !important;
		}
		.print-page {
			margin: 0 !important;
			page-break-after: always;
			break-after: page;
			box-shadow: none !important;
		}
		.print-page:last-child { page-break-after: auto; break-after: auto; }
		/* Marge físic 5mm: alguns navegadors no respecten margin:0 i afegeixen
		   marges propis que retallen el contingut. Amb 5mm explícit ho controlem. */
		@page { size: A3 landscape; margin: 5mm; }
		@page { size: 420mm 297mm; margin: 5mm; }
		:global(body) { background: white !important; margin: 0 !important; }
		:global(html) { background: white !important; }
	}
</style>
