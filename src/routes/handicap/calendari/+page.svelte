<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { buildMatchCodeMap, buildSlotSourceMap } from '$lib/utils/handicap-types';
	import { formatarNomJugadorParts } from '$lib/utils/playerUtils';

	let loading = true;
	let error: string | null = null;
	let eventNom = '';
	let eventTemporada = '';

	$: temporadaPretty = (eventTemporada || '').replace('-', '/');

	type CalRow = {
		date: Date;
		hora: string;
		billar: number;
		code: string | null;
		bracket: 'winners' | 'losers' | 'grand_final' | null;
		winnerDest: string | null;
		loserDest: string | null;
		player1: string | null;
		player2: string | null;
		estat: string | null;
		/** True quan els 2 jugadors són reals. False = data orientativa. */
		playersResolved: boolean;
		/** Si és un dia festiu (cap partida programable). */
		festiu?: boolean;
	};
	let rows: CalRow[] = [];
	let columns: 1 | 2 = 2;

	// Dies marcats com a festius (no programables). Coherent amb el
	// pre-scheduler i els modals d'impressió.
	const FESTIUS = new Set(['2026-06-24']);

	function ymd(d: Date): string {
		const y = d.getFullYear();
		const m = String(d.getMonth() + 1).padStart(2, '0');
		const dd = String(d.getDate()).padStart(2, '0');
		return `${y}-${m}-${dd}`;
	}
	function diaNom(d: Date): string {
		return ['Diumenge', 'Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte'][d.getDay()];
	}
	function dateLabel(d: Date): string {
		const dd = String(d.getDate()).padStart(2, '0');
		const mm = String(d.getMonth() + 1).padStart(2, '0');
		return `${dd}/${mm}`;
	}

	onMount(async () => {
		try {
			const { data: ev, error: evErr } = await supabase
				.from('events')
				.select('id, nom, temporada, data_inici, data_fi')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.limit(1)
				.maybeSingle();

			if (evErr || !ev) {
				error = 'No hi ha cap torneig hàndicap actiu.';
				loading = false;
				return;
			}

			eventNom = ev.nom ?? '';
			eventTemporada = ev.temporada ?? '';

			const { data: cfg } = await supabase
				.from('handicap_config')
				.select('horaris_extra')
				.eq('event_id', ev.id)
				.maybeSingle();
			const horarisExtra: any = cfg?.horaris_extra ?? null;

			const { data: rawMatches, error: mErr } = await supabase
				.from('handicap_matches')
				.select('id, estat, slot1_id, slot2_id, calendari_partida_id, winner_slot_dest_id, loser_slot_dest_id')
				.eq('event_id', ev.id)
				.neq('estat', 'bye');

			if (mErr || !rawMatches) {
				error = mErr?.message ?? 'Error carregant partides.';
				loading = false;
				return;
			}

			const slotIds = rawMatches.flatMap((m: any) => [m.slot1_id, m.slot2_id]);
			const calIds = rawMatches.filter((m: any) => m.calendari_partida_id).map((m: any) => m.calendari_partida_id as string);

			const [{ data: slots }, { data: cals }] = await Promise.all([
				supabase
					.from('handicap_bracket_slots')
					.select('id, bracket_type, ronda, posicio, participant_id')
					.in('id', slotIds),
				calIds.length > 0
					? supabase.from('calendari_partides').select('id, data_programada, hora_inici, taula_assignada').in('id', calIds)
					: Promise.resolve({ data: [] as any[] })
			]);

			const slotMap = new Map((slots ?? []).map((s: any) => [s.id, s]));
			const calMap = new Map((cals ?? []).map((c: any) => [c.id, c]));

			const partIds = [...new Set((slots ?? []).filter((s: any) => s.participant_id).map((s: any) => s.participant_id as string))];
			const nameMap = new Map<string, string>();
			if (partIds.length > 0) {
				const { data: parts } = await supabase
					.from('handicap_participants')
					.select('id, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
					.in('id', partIds);
				for (const p of parts ?? []) {
					const s = Array.isArray((p as any).socis) ? (p as any).socis[0] : (p as any).socis;
					const nom = s ? (formatarNomJugadorParts(s.nom, s.cognoms) || '?') : '?';
					nameMap.set((p as any).id, nom);
				}
			}

			// Codis de match (W1.1, L2.3, GF1) usant matchPos = ceil(posicio / 2)
			const codeInputs = rawMatches.map((m: any) => {
				const s1: any = slotMap.get(m.slot1_id);
				return {
					id: m.id as string,
					bracket_type: (s1?.bracket_type ?? 'winners') as string,
					ronda: (s1?.ronda ?? 1) as number,
					matchPos: s1 ? Math.ceil((s1.posicio as number) / 2) : 0
				};
			});
			const codeMap = buildMatchCodeMap(codeInputs);

			// Mapa slot_id → origen (Guanyador/Perdedor de match X) per a slots pendents
			const slotSourceMap = buildSlotSourceMap(
				rawMatches.map((m: any) => ({
					id: m.id as string,
					winner_slot_dest_id: m.winner_slot_dest_id as string | null,
					loser_slot_dest_id: m.loser_slot_dest_id as string | null
				})),
				codeMap
			);
			const sourceLabel = (slotId: string): string | null => {
				const src = slotSourceMap.get(slotId);
				return src ? `${src.role} ${src.code}` : null;
			};

			// Mapa slot_id → match (per resoldre winner/loser dest)
			const matchBySlot = new Map<string, any>();
			for (const m of rawMatches) {
				matchBySlot.set(m.slot1_id, m);
				matchBySlot.set(m.slot2_id, m);
			}
			const destCode = (slotId: string | null): string | null => {
				if (!slotId) return null;
				const m = matchBySlot.get(slotId);
				if (!m) return null;
				return codeMap.get(m.id) ?? null;
			};

			// Mapa slotKey (data|hora|billar) → info de match programat
			type MatchInfo = {
				code: string;
				bracket: 'winners' | 'losers' | 'grand_final';
				winnerDest: string | null;
				loserDest: string | null;
				player1: string | null;
				player2: string | null;
				estat: string;
				playersResolved: boolean;
			};
			const matchAtSlot = new Map<string, MatchInfo>();
			const scheduledDates = new Set<string>();
			for (const m of rawMatches as any[]) {
				const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) : null;
				if (!cal || !cal.data_programada || !cal.hora_inici || !cal.taula_assignada) continue;
				const s1: any = slotMap.get(m.slot1_id);
				const s2: any = slotMap.get(m.slot2_id);
				if (!s1 || !s2) continue;
				const dKey = (cal.data_programada as string).substring(0, 10);
				const hKey = (cal.hora_inici as string).substring(0, 5);
				const bKey = cal.taula_assignada as number;
				const key = `${dKey}|${hKey}|${bKey}`;
				scheduledDates.add(dKey);
				const p1 = s1.participant_id ? (nameMap.get(s1.participant_id) ?? null) : sourceLabel(s1.id);
				const p2 = s2.participant_id ? (nameMap.get(s2.participant_id) ?? null) : sourceLabel(s2.id);
				const resolved = !!(s1.participant_id && s2.participant_id);
				matchAtSlot.set(key, {
					code: codeMap.get(m.id) ?? '?',
					bracket: (s1.bracket_type ?? 'winners') as MatchInfo['bracket'],
					winnerDest: destCode(m.winner_slot_dest_id),
					loserDest: destCode(m.loser_slot_dest_id),
					player1: p1,
					player2: p2,
					estat: m.estat as string,
					playersResolved: resolved
				});
			}

			const sortedDates = [...scheduledDates].sort();
			// El rang del calendari abasta des de data_inici fins a data_fi
			// de l'event (no només l'interval de partides programades), perquè
			// es vegin els dies disponibles per a partides futures.
			const evStart = ev.data_inici ? new Date(ev.data_inici as string) : (sortedDates[0] ? new Date(sortedDates[0]) : new Date());
			const evEnd = ev.data_fi ? new Date(ev.data_fi as string) : (sortedDates[sortedDates.length - 1] ? new Date(sortedDates[sortedDates.length - 1]) : new Date());
			const lastSched = sortedDates[sortedDates.length - 1] ? new Date(sortedDates[sortedDates.length - 1]) : evStart;
			const firstSched = sortedDates[0] ? new Date(sortedDates[0]) : evStart;
			const minDate = firstSched < evStart ? firstSched : evStart;
			const maxDate = lastSched > evEnd ? lastSched : evEnd;
			const dies = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];
			const diesActius = ['dl', 'dt', 'dc', 'dj', 'dv'];

			const tmp: CalRow[] = [];
			for (let d = new Date(minDate); d <= maxDate; d.setDate(d.getDate() + 1)) {
				const codi = dies[d.getDay()];
				if (!diesActius.includes(codi)) continue;
				// Festiu: una sola fila marcada (no genera slots de billar).
				if (FESTIUS.has(ymd(d))) {
					tmp.push({
						date: new Date(d),
						hora: '',
						billar: 0,
						code: null,
						bracket: null,
						winnerDest: null,
						loserDest: null,
						player1: null,
						player2: null,
						estat: null,
						playersResolved: true,
						festiu: true
					});
					continue;
				}
				const hores = ['18:00', '19:00'];
				if (horarisExtra && Array.isArray(horarisExtra.dies) && horarisExtra.dies.includes(codi) && horarisExtra.franja) {
					hores.unshift(horarisExtra.franja);
				}
				for (const h of hores) {
					for (let b = 1; b <= 3; b++) {
						const key = `${ymd(d)}|${h}|${b}`;
						const mi = matchAtSlot.get(key) ?? null;
						tmp.push({
							date: new Date(d),
							hora: h,
							billar: b,
							code: mi?.code ?? null,
							bracket: mi?.bracket ?? null,
							winnerDest: mi?.winnerDest ?? null,
							loserDest: mi?.loserDest ?? null,
							player1: mi?.player1 ?? null,
							player2: mi?.player2 ?? null,
							estat: mi?.estat ?? null,
							playersResolved: mi?.playersResolved ?? true
						});
					}
				}
			}
			rows = tmp;
		} catch (e: any) {
			error = e?.message ?? String(e);
		} finally {
			loading = false;
		}
	});

	// Agrupació per dia → hora per als rowspans
	type GroupHour = { hora: string; items: CalRow[] };
	type GroupDay = { date: Date; total: number; hours: GroupHour[] };
	$: groupedDays = (() => {
		const byDay = new Map<string, GroupDay>();
		for (const r of rows) {
			const key = ymd(r.date);
			let gd = byDay.get(key);
			if (!gd) {
				gd = { date: r.date, total: 0, hours: [] };
				byDay.set(key, gd);
			}
			let gh = gd.hours.find((h) => h.hora === r.hora);
			if (!gh) {
				gh = { hora: r.hora, items: [] };
				gd.hours.push(gh);
			}
			gh.items.push(r);
			gd.total++;
		}
		return [...byDay.values()].sort((a, b) => a.date.getTime() - b.date.getTime());
	})();

	$: splitDays = (() => {
		if (columns === 1) return [groupedDays];
		const total = groupedDays.reduce((a, g) => a + g.total, 0);
		const target = total / 2;
		const left: GroupDay[] = [];
		const right: GroupDay[] = [];
		let acc = 0;
		for (const g of groupedDays) {
			if (acc < target) {
				left.push(g);
				acc += g.total;
			} else {
				right.push(g);
			}
		}
		return [left, right];
	})();

	function codeColorClass(bracket: CalRow['bracket']): string {
		if (!bracket) return '';
		return bracket === 'winners' ? 'code-w' : bracket === 'losers' ? 'code-l' : 'code-gf';
	}

	$: scheduledCount = rows.filter((r) => r.code !== null).length;
	$: tentativeCount = rows.filter((r) => r.code !== null && !r.playersResolved).length;
</script>

<svelte:head>
	<title>Calendari — Hàndicap</title>
</svelte:head>

<div class="hcap-root">
	<header class="page-mast">
		<div>
			<div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">
				<a href="/handicap" class="back-link">← Hàndicap</a>
			</div>
			<h1 class="page-title">Calendari de partides</h1>
			{#if eventNom}
				<p class="page-sub">{eventNom}{temporadaPretty ? ` · ${temporadaPretty}` : ''}</p>
			{/if}
		</div>
		<div class="stat-chip">
			<span class="stat-num">{scheduledCount}</span>
			<span class="stat-lbl">partid{scheduledCount === 1 ? 'a' : 'es'}</span>
		</div>
	</header>

	{#if loading}
		<p class="muted">Carregant...</p>
	{:else if error}
		<div class="alert-error">{error}</div>
	{:else if rows.length === 0}
		<div class="empty">Encara no hi ha cap partida programada.</div>
	{:else}
		{#if tentativeCount > 0}
			<div class="disclaimer">
				<strong>Atenció:</strong> {tentativeCount} partid{tentativeCount === 1 ? 'a' : 'es'} amb data
				<em>orientativa</em>. Quan encara no es coneixen els dos contrincants, la data i el billar
				assignats poden canviar i es concretaran quan es defineixin els jugadors a partir dels
				resultats de les rondes anteriors. Aquestes files es marquen amb <span class="tentative-mark">·</span>
				i el text en cursiva.
			</div>
		{/if}

		<div class="toolbar">
			<label class="col-label">
				Format:
				<select bind:value={columns} class="col-select">
					<option value={2}>2 columnes</option>
					<option value={1}>1 columna</option>
				</select>
			</label>
		</div>

		<div class="two-cols" class:single={columns === 1}>
			{#each splitDays as colDays}
				<div class="col">
					<table class="cal-table">
						<thead>
							<tr>
								<th>Dia</th>
								<th>Hora</th>
								<th>B</th>
								<th>Match</th>
								<th>Destí</th>
								<th>Jugador 1</th>
								<th>Jugador 2</th>
							</tr>
						</thead>
						<tbody>
							{#each colDays as gd}
								{#if gd.hours[0]?.items[0]?.festiu}
									<tr class="festiu-row">
										<td class="day-cell">
											<div class="d-num">{dateLabel(gd.date)}</div>
											<div class="d-name">{diaNom(gd.date)}</div>
										</td>
										<td class="festiu-cell" colspan="6">FESTIU</td>
									</tr>
								{:else}
								{#each gd.hours as gh, hIdx}
									{#each gh.items as it, iIdx}
										<tr
											class:played={it.estat === 'jugada' || it.estat === 'walkover'}
											class:tentative={it.code !== null && !it.playersResolved}
											title={it.code !== null && !it.playersResolved
												? 'Data orientativa: es concretarà quan es defineixin els dos jugadors'
												: null}
										>
											{#if hIdx === 0 && iIdx === 0}
												<td class="day-cell" rowspan={gd.total}>
													<div class="d-num">{dateLabel(gd.date)}</div>
													<div class="d-name">{diaNom(gd.date)}</div>
												</td>
											{/if}
											{#if iIdx === 0}
												<td class="hour-cell" rowspan={gh.items.length}>{gh.hora}</td>
											{/if}
											<td class="billar-cell">B{it.billar}</td>
											<td class="code-cell {codeColorClass(it.bracket)}">
												{it.code ?? ''}
												{#if it.code !== null && !it.playersResolved}
													<span class="tentative-mark" aria-label="Data orientativa">·</span>
												{/if}
											</td>
											<td class="dest-cell">
												{#if it.winnerDest}<div class="arrow-win">↗G: <strong>{it.winnerDest}</strong></div>{/if}
												{#if it.loserDest}<div class="arrow-lose">↘P: <strong>{it.loserDest}</strong></div>{/if}
											</td>
											<td class="player-cell">{it.player1 ?? ''}</td>
											<td class="player-cell">{it.player2 ?? ''}</td>
										</tr>
									{/each}
								{/each}
								{/if}
							{/each}
						</tbody>
					</table>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.hcap-root {
		max-width: 80rem;
		margin: 0 auto;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
		font-family: var(--font-sans);
		color: var(--ink);
	}
	.page-mast {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		gap: 1rem;
		padding-bottom: 1rem;
		border-bottom: 2px solid var(--ink);
	}
	.editorial-eyebrow {
		font-size: 0.75rem;
		font-weight: 600;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		color: var(--sec-handicap);
	}
	.back-link { color: var(--sec-handicap); text-decoration: none; }
	.back-link:hover { text-decoration: underline; }
	.page-title {
		font-weight: 800;
		font-size: 2rem;
		letter-spacing: -0.025em;
		line-height: 1.05;
		margin: 0;
		color: var(--ink);
	}
	.page-sub { font-size: 0.9rem; color: var(--ink-2); margin: 0.25rem 0 0; }
	.stat-chip { display: flex; flex-direction: column; align-items: flex-end; gap: 0.1rem; }
	.stat-num { font-size: 2rem; font-weight: 800; line-height: 1; color: var(--sec-handicap); }
	.stat-lbl { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--ink-2); }
	.muted { color: var(--ink-2); }
	.alert-error {
		border: 1px solid var(--accent);
		background: var(--paper-elevated);
		padding: 0.75rem 1rem;
		color: var(--accent);
	}
	.empty {
		border: 1px dashed var(--rule);
		padding: 2rem;
		text-align: center;
		color: var(--ink-2);
		background: var(--paper-elevated);
	}

	.toolbar { display: flex; justify-content: flex-end; }
	.col-label { display: inline-flex; align-items: center; gap: 0.4rem; font-size: 0.85rem; font-weight: 600; color: var(--ink-2); }
	.col-select { padding: 0.25rem 0.5rem; border: 1px solid var(--ink); background: white; font-size: 0.85rem; }

	.two-cols { display: flex; gap: 1rem; align-items: flex-start; }
	.two-cols.single { display: block; }
	.col { flex: 1; min-width: 0; }

	.cal-table { width: 100%; border-collapse: collapse; font-size: 0.85rem; background: white; }
	.cal-table th, .cal-table td {
		border: 1px solid #333;
		padding: 0.3rem 0.4rem;
		text-align: center;
		vertical-align: middle;
	}
	.cal-table th {
		background: #e8e8e8;
		font-weight: 700;
		font-size: 0.7rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		padding: 0.4rem 0.3rem;
	}
	.day-cell {
		background: #f5f5f5;
		font-weight: 700;
		border-right: 2px solid #333;
		white-space: nowrap;
		min-width: 3.5rem;
	}
	.day-cell .d-num { font-size: 1rem; font-weight: 800; }
	.day-cell .d-name { font-size: 0.7rem; color: #555; font-weight: 600; }
	.hour-cell {
		background: #fafafa;
		font-weight: 700;
		border-right: 2px solid #333;
		min-width: 3rem;
	}
	.billar-cell { font-weight: 700; font-size: 0.8rem; background: #fcfcfc; width: 2rem; }
	.code-cell { font-weight: 800; font-size: 0.8rem; width: 3rem; white-space: nowrap; }
	.code-w { color: #1d6e3a; }
	.code-l { color: #a30b1e; }
	.code-gf { color: #6b3eb8; }
	.dest-cell {
		font-size: 0.7rem;
		font-weight: 600;
		min-width: 4rem;
		text-align: left;
		line-height: 1.25;
		padding: 0.25rem 0.4rem;
	}
	.dest-cell .arrow-win, .dest-cell .arrow-lose { display: block; }
	.dest-cell strong { font-weight: 800; }
	.arrow-win { color: #1d6e3a; }
	.arrow-lose { color: #a30b1e; }
	.player-cell { font-size: 0.8rem; min-width: 7rem; text-align: left; padding: 0.25rem 0.5rem; }

	tr.played .player-cell, tr.played .code-cell { opacity: 0.6; }

	.festiu-cell {
		background: #fff7e6;
		border: 1px solid #d97706 !important;
		color: #b85c00;
		font-weight: 800;
		font-size: 0.85rem;
		letter-spacing: 0.18em;
		text-align: center;
		padding: 0.5rem 0.4rem;
	}
	tr.festiu-row .day-cell {
		background: #fff7e6;
	}

	tr.tentative .player-cell {
		font-style: italic;
		color: var(--ink-2, #555);
	}
	.tentative-mark {
		display: inline-block;
		margin-left: 0.25rem;
		color: #b85c00;
		font-weight: 900;
		font-size: 1.1em;
		line-height: 1;
	}
	.disclaimer {
		border: 1px solid #d97706;
		border-left: 4px solid #d97706;
		background: #fffaf0;
		padding: 0.75rem 1rem;
		font-size: 0.85rem;
		line-height: 1.45;
		color: #1f1f1f;
	}
	.disclaimer em { font-style: italic; }

	@media (max-width: 900px) {
		.two-cols { flex-direction: column; }
	}
</style>
