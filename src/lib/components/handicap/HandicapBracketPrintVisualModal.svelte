<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase } from '$lib/supabaseClient';
	import { generateDoublEliminationBracket } from '$lib/utils/handicap-bracket-generator';
	import { preSchedulingForBracket, type ScheduledMatch } from '$lib/utils/handicap-pre-scheduler';
	import { computeDeadlines } from '$lib/utils/handicap-deadlines';
	import { printPortal } from '$lib/utils/print-portal';
	import { formatarNomJugadorParts } from '$lib/utils/playerUtils';

	let logoDataUrl = '';

	export let eventId: string | null = null;
	export let participantCount: number | null = null;
	export let eventNom: string = '';
	export let eventTemporada: string = '';
	export let onClose: () => void = () => {};

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
		estat: string;
		guanyador_participant_id?: string | null;
		distancia_jugador1?: number | null;
		distancia_jugador2?: number | null;
		caramboles1?: number | null;
		caramboles2?: number | null;
		entrades?: number | null;
		calendari_partida_id?: string | null;
		[key: string]: any;
	};

	type MatchResult = {
		estat: string;
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
		bracket: Bracket;
		ronda: number;
		slot1Name: string | null;
		slot2Name: string | null;
		winnerDest: string;
		loserDest: string;
		slot1Pos?: number;
		slot2Pos?: number;
		slot1Dist?: number | null;
		slot2Dist?: number | null;
		result?: MatchResult | null;
		schedule?: ScheduledMatch;
		[key: string]: any;
	};

	type PrintPage = {
		title: string;
		sectionLabel: string;
		columns: Array<{ rondaLabel: string; matches: MatchView[] }>;
	};

	type PageDef = PrintPage;

	let loading = true;
	let error: string | null = null;
	let hasRealBracket = false;
	let pages: PrintPage[] = [];
	const temporadaPretty = eventTemporada.trim();

	let inputCount = participantCount ?? 32;
	onMount(async () => {
		await loadAll();
	});

	async function regenerate() {
		if (eventId) return;
		await loadAll();
	}

	async function loadAll() {
		loading = true;
		error = null;
		hasRealBracket = false;
		try {
			let slots: Slot[];
			let matches: MatchRaw[];
			const nameMap = new Map<string, string>();
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

				const { data: partsData, error: pErr } = await supabase
					.from('handicap_participants')
					.select('id, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
					.eq('event_id', realEventId);
				if (pErr) throw pErr;
				for (const p of (partsData ?? []) as any[]) {
					const raw = p.socis;
					const s = Array.isArray(raw) ? raw[0] : raw;
					nameMap.set(p.id, formatarNomJugadorParts(s?.nom ?? '', s?.cognoms ?? ''));
				}

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
				// Propaga caramboles/entrades del calendari als matches.
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
				const fakes = Array.from({ length: inputCount }, (_, i) => ({
					id: `fake-${i + 1}`,
					seed: i + 1,
					distancia: 0
				}));
				const result = generateDoublEliminationBracket('preview', fakes);
				slots = result.slots.map(s => ({
					id: s.id, bracket_type: s.bracket_type, ronda: s.ronda, posicio: s.posicio
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

			matches = matches.filter(m => m.estat !== 'bye');
			if (matches.length === 0) {
				error = 'No hi ha cap partida amb què muntar el bracket.';
				loading = false;
				return;
			}

			if (!useRealData) {
				try {
					if (ev?.data_inici && ev?.data_fi) {
						const { data: cfg } = await supabase
							.from('handicap_config')
							.select('horaris_extra')
							.eq('event_id', ev.id)
							.maybeSingle();
						scheduleById = preSchedulingForBracket(slots, matches, {
							dataInici: new Date(ev.data_inici),
							dataFi: new Date(ev.data_fi),
							horesEstandard: ['18:00', '19:00'],
							horarisExtra: cfg?.horaris_extra ?? null,
							billars: 3,
							diesBloquejats: [new Date('2026-06-24')]
						});
					}
				} catch (e) {
					console.warn('Pre-scheduling no disponible:', e);
				}
			}

			const slotById = new Map<string, Slot>(slots.map(s => [s.id, s]));
			const matchBySlot = new Map<string, MatchRaw>();
			for (const m of matches) {
				matchBySlot.set(m.slot1_id, m);
				matchBySlot.set(m.slot2_id, m);
			}

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

			const codeByMatchId = new Map<string, string>();
			const counterByKey = new Map<string, number>();
			for (const e of enriched) {
				const key = `${e.bracket}-${e.ronda}`;
				const next = (counterByKey.get(key) ?? 0) + 1;
				counterByKey.set(key, next);
				const code = e.bracket === 'grand_final'
					? `GF${e.ronda}`
					: `${e.bracket === 'winners' ? 'W' : 'L'}${e.ronda}.${next}`;
				codeByMatchId.set(e.m.id, code);
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
					bracket: e.bracket,
					ronda: e.ronda,
					posicioMin: e.posicioMin,
					slot1Pos: s1?.posicio ?? 0,
					slot2Pos: s2?.posicio ?? 0,
					slot1Name: slotName(s1),
					slot2Name: slotName(s2),
					winnerDest: destinationCode(e.m.winner_slot_dest_id),
					loserDest: destinationCode(e.m.loser_slot_dest_id),
					schedule: scheduleById.get(e.m.id) ?? null,
					result: useRealData ? buildResult(e.m, s1, s2) : null
				};
			});

			pages = buildPages(matchViews);
			loading = false;
		} catch (e: any) {
			error = e.message || 'Error carregant el bracket';
			loading = false;
		}
	}

	// Construeix les pàgines del bracket visual:
	//   - Per cada bracket (winners, losers), agrupa per ronda.
	//   - Si la primera ronda té >8 matches, divideix tot el bracket en TOP / BOTTOM
	//     (top = primera meitat de matches per ronda; bottom = segona meitat).
	//   - La grand_final s'afegeix al final de la pàgina de winners (últim full).
	function buildPages(mvs: MatchView[]): PageDef[] {
		const out: PageDef[] = [];

		const winnersAll = mvs.filter(m => m.bracket === 'winners');
		const losersAll = mvs.filter(m => m.bracket === 'losers');
		const gfAll = mvs.filter(m => m.bracket === 'grand_final');

		const winnersByRonda = groupByRonda(winnersAll);
		const losersByRonda = groupByRonda(losersAll);

		const winnersPages = splitBracketPages('Bracket Principal', 'winners', winnersByRonda);
		const losersPages = splitBracketPages('Bracket Repesca', 'losers', losersByRonda);

		// Encolumnar Grand Final al final de l'últim full de winners
		if (gfAll.length > 0 && winnersPages.length > 0) {
			winnersPages[winnersPages.length - 1].columns.push({
				rondaLabel: 'Gran Final',
				matches: gfAll.sort((a, b) => a.ronda - b.ronda)
			});
		}

		return [...winnersPages, ...losersPages];
	}

	function groupByRonda(arr: MatchView[]): Array<[number, MatchView[]]> {
		const map = new Map<number, MatchView[]>();
		for (const m of arr) {
			if (!map.has(m.ronda)) map.set(m.ronda, []);
			map.get(m.ronda)!.push(m);
		}
		// Ordenar cada ronda per posicioMin
		for (const arr of map.values()) {
			arr.sort((a, b) => a.posicioMin - b.posicioMin);
		}
		return [...map.entries()].sort((a, b) => a[0] - b[0]);
	}

	// Màxim de caixes per columna per garantir que cada caixa quedi
	// igualment llegible (~32mm d'alt + gap). En A3 landscape l'alçada útil
	// permet 6-7 caixes per columna còmodament.
	const MAX_CELLS_PER_COLUMN = 6;

	function splitBracketPages(
		baseTitle: string,
		bracket: Bracket,
		rondesSorted: Array<[number, MatchView[]]>
	): PageDef[] {
		if (rondesSorted.length === 0) return [];
		const r1Count = rondesSorted[0][1].length;
		const nPages = Math.max(1, Math.ceil(r1Count / MAX_CELLS_PER_COLUMN));

		if (nPages === 1) {
			return [{
				title: baseTitle,
				sectionLabel: baseTitle,
				columns: rondesSorted.map(([r, matches]) => ({
					rondaLabel: rondaLabel(bracket, r),
					matches
				}))
			}];
		}

		const pages: PageDef[] = [];
		for (let p = 0; p < nPages; p++) {
			const cols: Array<{ rondaLabel: string; matches: MatchView[] }> = [];
			for (const [r, matches] of rondesSorted) {
				const perPage = Math.ceil(matches.length / nPages);
				const start = p * perPage;
				const end = Math.min(start + perPage, matches.length);
				const subset = matches.slice(start, end);
				if (subset.length > 0) {
					cols.push({ rondaLabel: rondaLabel(bracket, r), matches: subset });
				}
			}
			if (cols.length > 0) {
				pages.push({
					title: baseTitle,
					sectionLabel: `${baseTitle} — Secció ${p + 1}/${nPages}`,
					columns: cols
				});
			}
		}
		return pages;
	}

	function fmtDate(d: Date): string {
		const dd = String(d.getDate()).padStart(2, '0');
		const mm = String(d.getMonth() + 1).padStart(2, '0');
		return `${dd}/${mm}`;
	}

	function rondaLabel(bracket: Bracket, num: number): string {
		const prefix = bracket === 'winners' ? 'R' : 'L';
		return `${prefix}${num}`;
	}

	function doPrint() {
		const previewEl = document.querySelector('.print-portal .preview');
		if (!previewEl) {
			window.print();
			return;
		}

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
				width: 420mm; height: 287mm; /* buffer 10mm */
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
				border-bottom: 2px solid #1f1f1f; padding-bottom: 3mm; margin-bottom: 3mm; gap: 6mm; flex: none;
			}
			.page-head-left { display: flex; align-items: center; gap: 5mm; min-width: 0; }
			.page-logo {
				height: 16mm; width: 11mm; flex: none;
				object-fit: contain;
				display: inline-flex; align-items: center; justify-content: center;
			}
			.page-logo svg { width: 100%; height: 100%; display: block; }
			.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
			.page-title-main { font-weight: 800; font-size: 14pt; letter-spacing: 0.02em; line-height: 1.1; text-transform: uppercase; }
			.page-section { font-size: 10pt; color: #444; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
			.page-sub { font-size: 9pt; color: #555; text-align: right; }
			.bracket-flow { display: flex; flex: 1; gap: 4mm; min-height: 0; }
			.round-col { display: flex; flex-direction: column; flex: 1; min-width: 0; gap: 3mm; }
			.round-label {
				font-size: 9pt; font-weight: 700; text-transform: uppercase;
				letter-spacing: 0.06em; color: #1f1f1f;
				border-bottom: 1.5px solid #1f1f1f; padding-bottom: 1.5mm; text-align: center;
			}
			.round-matches { display: flex; flex-direction: column; flex: 1 1 auto; justify-content: space-around; min-height: 0; }
			.match-cell {
				border: 1.5px solid #1f1f1f;
				padding: 2mm;
				display: flex; flex-direction: column; gap: 1mm;
				font-size: 8.5pt;
				min-height: 32mm; height: 32mm;
				box-sizing: border-box;
			}
			.cell-head {
				display: flex; justify-content: space-between; align-items: baseline;
				font-size: 8pt; border-bottom: 1px solid #999;
				padding-bottom: 0.5mm; gap: 1.5mm;
			}
			.match-code { font-weight: 800; font-size: 10pt; letter-spacing: 0.04em; }
			.arrows { display: flex; gap: 1.5mm; flex-wrap: wrap; font-size: 7.5pt; color: #333; }
			.match-cell.bridge-boost .match-code { font-size: 11pt; }
			.match-cell.bridge-boost .arrows { font-size: 8.25pt; }
			.match-cell.bridge-boost .arrow-win { font-size: 8.25pt; }
			.match-cell.bridge-boost .arrow-win strong { font-size: 8.5pt; }
			.arrows strong { font-weight: 700; }
	.arrow-win { color: #1d6e3a; }
	.arrow-lose { color: #a30b1e; }
	.arrow-win strong, .arrow-lose strong { color: inherit; }
			.player-row, .entries-row { display: flex; align-items: center; gap: 1mm; font-size: 8pt; }
			.label { font-weight: 700; font-size: 7.25pt; color: #555; min-width: 4mm; }
			.kv { font-size: 7.25pt; color: #555; font-weight: 600; }
			.line { flex: 1; border-bottom: 1px solid #1f1f1f; height: 4.5mm; }
			.line.filled {
				display: flex; align-items: center;
				font-size: 8pt; font-weight: 700; color: #1f1f1f;
				padding: 0 1mm; line-height: 4.5mm; height: 4.5mm;
				white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
				min-width: 0;
			}
			.box { display: inline-block; border: 1px solid #1f1f1f; height: 4.5mm; width: 10mm; }
			.box.small { width: 7mm; }
			.box.filled-box {
				display: inline-flex; align-items: center; justify-content: center;
				font-size: 7.5pt; font-weight: 700; color: #1f1f1f; background: #f5f5f5;
			}
			.winner-row { font-weight: 800; }
			.winner-row .line.filled { font-weight: 800; }
			.winner-mark { color: #1d6e3a; font-weight: 800; margin-right: 0.4mm; }
			.loser-row { opacity: 0.55; }
			.schedule-row {
				display: flex; justify-content: space-between; align-items: baseline;
				gap: 1.5mm; margin-top: 0.6mm; padding-top: 0.6mm;
				border-top: 1px dashed #999;
				font-size: 6.5pt;
			}
			.sched-slot { font-weight: 700; color: #1f1f1f; }
			.sched-deadline { color: #a30b1e; font-weight: 600; }
		`;

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
<title>Bracket visual — ${(eventNom || 'Hàndicap').replace(/[<>&"]/g, '')}</title>
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

<div class="modal-overlay print-portal" use:printPortal on:click|self={onClose} role="presentation">
	<div class="modal-card" role="dialog" aria-modal="true">
		<div class="modal-head no-print">
			<h2 class="modal-title">Imprimir bracket VISUAL per a la pissarra</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="modal-toolbar no-print">
			<div class="toolbar-info">
				{#if loading}
					<span>Carregant bracket…</span>
				{:else if error}
					<span class="err">{error}</span>
				{:else}
					<span>{pages.length} fulls A3 landscape</span>
					<span class="hint">
						Al diàleg d'imprimir tria <strong>A3</strong> i orientació <strong>Apaisat / Horitzontal</strong>.
						Per a PDF: destinació <em>Guardar com a PDF</em>.
					</span>
				{/if}
				{#if !eventId && !hasRealBracket}
					<label class="count-label">
						Jugadors:
						<input type="number" min="2" max="128" bind:value={inputCount} class="count-input" />
					</label>
					<button type="button" class="btn-secondary" on:click={regenerate} disabled={loading || inputCount < 2}>
						Recalcular
					</button>
				{/if}
			</div>
			<div class="toolbar-actions">
				<button type="button" class="btn-secondary" on:click={onClose}>Tancar</button>
				<button type="button" class="btn-primary" on:click={doPrint} disabled={loading || !!error}>
					Imprimir / Desar PDF
				</button>
			</div>
		</div>

		{#if !loading && !error}
			<div class="print-warning no-print">
				⚠ <strong>Important:</strong> al diàleg d'imprimir, tria <strong>paper A3</strong> i orientació <strong>Apaisat / Horitzontal</strong>. Si el navegador imprimeix amb A4 vertical, el bracket sortirà tallat.
			</div>
			<div class="preview">
				{#each pages as page}
					<section class="print-page">
						<header class="page-head">
							<div class="page-head-left">
								<img
									src={logoDataUrl || `${base}/logo.png`}
									alt=""
									class="page-logo"
								/>
								<div class="page-head-titles">
									<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
									<div class="page-section">{page.sectionLabel}</div>
								</div>
							</div>
							{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
						</header>

						<div class="bracket-flow">
							{#each page.columns as col}
								<div class="round-col">
									<div class="round-label">{col.rondaLabel}</div>
									<div class="round-matches">
										{#each col.matches as mv}
											<div class="match-cell" class:played={!!mv.result} class:bridge-boost={mv.code === 'W4.2'}>
												<div class="cell-head">
													<span class="match-code">{mv.code}</span>
													<span class="arrows">
														<span class="arrow-win">↗W:<strong>{mv.winnerDest}</strong></span>
														{#if mv.loserDest !== '—'}
															<span class="arrow-lose">↘L:<strong>{mv.loserDest}</strong></span>
														{/if}
													</span>
												</div>
												<div
													class="player-row"
													class:winner-row={mv.result?.winnerSlot === 1}
													class:loser-row={!!mv.result && mv.result.winnerSlot === 2}
												>
													<span class="label">
														{#if mv.result?.winnerSlot === 1}<span class="winner-mark">▶</span>{/if}
														{mv.bracket === 'winners' && mv.ronda === 1 ? `#${mv.slot1Pos}` : '1'}
													</span>
													{#if mv.slot1Name}
														<span class="line filled">{mv.slot1Name}</span>
													{:else}
														<span class="line"></span>
													{/if}
													{#if mv.result}
														<span class="kv">D</span><span class="box small filled-box">{mv.result.distancia1 ?? ''}</span>
														<span class="kv">C</span><span class="box small filled-box">{mv.result.isWalkover ? 'WO' : (mv.result.caramboles1 ?? '')}</span>
													{:else}
														<span class="kv">D</span><span class="box small"></span>
														<span class="kv">C</span><span class="box small"></span>
													{/if}
												</div>
												<div
													class="player-row"
													class:winner-row={mv.result?.winnerSlot === 2}
													class:loser-row={!!mv.result && mv.result.winnerSlot === 1}
												>
													<span class="label">
														{#if mv.result?.winnerSlot === 2}<span class="winner-mark">▶</span>{/if}
														{mv.bracket === 'winners' && mv.ronda === 1 ? `#${mv.slot2Pos}` : '2'}
													</span>
													{#if mv.slot2Name}
														<span class="line filled">{mv.slot2Name}</span>
													{:else}
														<span class="line"></span>
													{/if}
													{#if mv.result}
														<span class="kv">D</span><span class="box small filled-box">{mv.result.distancia2 ?? ''}</span>
														<span class="kv">C</span><span class="box small filled-box">{mv.result.isWalkover ? 'WO' : (mv.result.caramboles2 ?? '')}</span>
													{:else}
														<span class="kv">D</span><span class="box small"></span>
														<span class="kv">C</span><span class="box small"></span>
													{/if}
												</div>
												<div class="entries-row">
													<span class="kv">Entrades</span>
													{#if mv.result}
														<span class="box filled-box">{mv.result.isWalkover ? 'WO' : (mv.result.entrades ?? '')}</span>
													{:else}
														<span class="box"></span>
													{/if}
												</div>
												{#if mv.schedule}
													<div class="schedule-row">
														<span class="sched-slot">{fmtDate(mv.schedule.dataProgramada)} · {mv.schedule.horaInici} · B{mv.schedule.taulaAssignada}</span>
														<span class="sched-deadline">màx: {fmtDate(mv.schedule.dataMaximaDisputa)}</span>
													</div>
												{/if}
											</div>
										{/each}
									</div>
								</div>
							{/each}
						</div>
					</section>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.modal-overlay {
		position: fixed; inset: 0; z-index: 100;
		background: rgba(0,0,0,0.6);
		display: flex; align-items: stretch; justify-content: center;
		padding: 1rem;
	}
	.modal-card {
		background: white; width: 100%; max-width: 1500px;
		max-height: 100%;
		display: flex; flex-direction: column;
	}
	.modal-head {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.75rem 1rem; border-bottom: 1px solid #ddd;
	}
	.modal-title { font-size: 1.05rem; font-weight: 700; margin: 0; }
	.close-btn { font-size: 1.5rem; background: transparent; border: none; cursor: pointer; }

	.modal-toolbar {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.5rem 1rem; border-bottom: 1px solid #eee;
		font-size: 0.875rem; color: #444;
		flex-wrap: wrap; gap: 0.5rem;
	}
	.toolbar-info { display: flex; gap: 0.85rem; align-items: center; flex-wrap: wrap; }
	.toolbar-actions { display: flex; gap: 0.5rem; }
	.btn-primary, .btn-secondary {
		padding: 0.4rem 0.85rem; cursor: pointer; font-size: 0.875rem; font-weight: 600;
		border-radius: 0; border: 1px solid #333;
	}
	.btn-primary { background: #1f1f1f; color: white; }
	.btn-secondary { background: white; color: #1f1f1f; }
	.btn-primary:disabled, .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }
	.err { color: #a30b1e; font-weight: 600; }
	.hint { color: #555; font-size: 0.8125rem; }
	.hint em { font-style: italic; font-weight: 600; color: #1f1f1f; }
	.count-label { display: inline-flex; align-items: center; gap: 0.35rem; font-weight: 600; }
	.count-input { width: 4.5rem; padding: 0.25rem 0.4rem; border: 1px solid #333; border-radius: 0; font-size: 0.875rem; }

	.preview { overflow: auto; flex: 1; padding: 1rem; background: #ececec; }
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
		width: 410mm; height: 287mm; /* buffer 10mm */
		padding: 5mm 4mm 3mm;
		margin: 0 auto 1rem auto;
		box-sizing: border-box;
		display: flex; flex-direction: column;
		page-break-after: always;
		break-after: page;
	}
	.print-page:last-child { page-break-after: auto; break-after: auto; }

	.page-head {
		display: flex; justify-content: space-between; align-items: center;
		border-bottom: 2px solid #1f1f1f; padding-bottom: 2mm; margin-bottom: 2.5mm;
		gap: 5mm; flex: none;
	}
	.page-head-left { display: flex; align-items: center; gap: 5mm; min-width: 0; }
	.page-logo {
		/* viewBox 1024×1536 → ratio 2:3 */
		height: 17mm; width: 11.5mm; flex: none;
		object-fit: contain;
		display: inline-flex; align-items: center; justify-content: center;
	}
	.page-logo :global(svg) {
		width: 100%; height: 100%; display: block;
	}
	.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
	.page-title-main { font-weight: 800; font-size: 15pt; letter-spacing: 0.02em; line-height: 1.1; text-transform: uppercase; }
	.page-section { font-size: 10.5pt; color: #444; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
	.page-sub { font-size: 9pt; color: #555; text-align: right; }

	.bracket-flow {
		display: flex;
		flex: 1;
		gap: 3mm;
		min-height: 0;
	}
	.round-col {
		display: flex; flex-direction: column;
		flex: 1; min-width: 0;
		gap: 2.5mm;
	}
	.round-label {
		font-size: 9.5pt; font-weight: 700; text-transform: uppercase;
		letter-spacing: 0.06em; color: #1f1f1f;
		border-bottom: 1.5px solid #1f1f1f;
		padding-bottom: 1mm;
		text-align: center;
	}
	.round-matches {
		display: flex; flex-direction: column;
		flex: 1 1 auto;
		justify-content: space-around;
		min-height: 0;
	}
	.match-cell {
		border: 1.5px solid #1f1f1f;
		padding: 1.75mm 2mm 1.5mm;
		display: flex; flex-direction: column; gap: 0.85mm;
		font-size: 8.5pt;
		min-height: 33.5mm; height: 33.5mm;
		box-sizing: border-box;
	}
	.cell-head {
		display: flex; justify-content: space-between; align-items: baseline;
		font-size: 8.25pt;
		border-bottom: 1px solid #999;
		padding-bottom: 0.75mm;
		gap: 1.5mm;
	}
	.match-code { font-weight: 800; font-size: 10.5pt; letter-spacing: 0.04em; }
	.arrows { display: flex; gap: 1.2mm; flex-wrap: wrap; font-size: 7.75pt; color: #333; }
	.match-cell.bridge-boost .match-code { font-size: 11pt; }
	.match-cell.bridge-boost .arrows { font-size: 8.25pt; }
	.match-cell.bridge-boost .arrow-win { font-size: 8.25pt; }
	.match-cell.bridge-boost .arrow-win strong { font-size: 8.5pt; }
	.arrows strong { font-weight: 700; }
	.arrow-win { color: #1d6e3a; }
	.arrow-lose { color: #a30b1e; }
	.arrow-win strong, .arrow-lose strong { color: inherit; }
	.player-row, .entries-row { display: flex; align-items: center; gap: 1mm; font-size: 8.25pt; }
	.schedule-row {
		display: flex; justify-content: space-between; align-items: baseline;
		gap: 1.5mm; margin-top: 0.5mm; padding-top: 0.5mm;
		border-top: 1px dashed #999;
		font-size: 6.75pt;
	}
	.sched-slot { font-weight: 700; color: #1f1f1f; }
	.sched-deadline { color: #a30b1e; font-weight: 600; }
	.label { font-weight: 700; font-size: 7.5pt; color: #555; min-width: 4mm; }
	.kv { font-size: 7.5pt; color: #555; font-weight: 600; }
	.line { flex: 1; border-bottom: 1px solid #1f1f1f; height: 4.75mm; }
	.line.filled {
		display: flex; align-items: center;
		font-size: 8.5pt; font-weight: 700; color: #1f1f1f;
		padding: 0 1mm; line-height: 4.75mm; height: 4.75mm;
		white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
		min-width: 0;
	}
	.box { display: inline-block; border: 1px solid #1f1f1f; height: 4.75mm; width: 10.5mm; }
	.box.small { width: 7.5mm; }
	.box.filled-box {
		display: inline-flex; align-items: center; justify-content: center;
		font-size: 8pt; font-weight: 700; color: #1f1f1f; background: #f5f5f5;
	}
	.winner-row { font-weight: 800; }
	.winner-row :global(.line.filled) { font-weight: 800; }
	.winner-mark { color: #1d6e3a; font-weight: 800; margin-right: 0.5mm; }
	.loser-row { opacity: 0.55; }

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
		.modal-overlay {
			display: block !important;
			position: static !important;
			background: white !important;
			padding: 0 !important;
		}
		.modal-card {
			display: block !important;
			max-width: none !important;
			max-height: none !important;
			width: auto !important;
			height: auto !important;
			box-shadow: none !important;
		}
		.preview {
			display: block !important;
			background: white !important;
			padding: 0 !important;
			overflow: visible !important;
			flex: none !important;
		}
		.print-page {
			margin: 0 !important;
			box-shadow: none !important;
		}
		.print-page:last-child { page-break-after: auto; break-after: auto; }
		@page { size: A3 landscape; margin: 5mm; }
		@page { size: 420mm 297mm; margin: 5mm; }
		:global(body) { background: white !important; margin: 0 !important; }
		:global(html) { background: white !important; }
	}
</style>
