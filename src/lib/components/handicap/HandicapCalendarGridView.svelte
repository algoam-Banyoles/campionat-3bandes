<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { CalendarEntry } from '$lib/utils/handicap-types';
	import type { TournamentConfig } from '$lib/utils/handicap-scheduler';
	import { parseLocalDate } from '$lib/utils/handicap-scheduler';
	import { formatarNomJugador } from '$lib/utils/playerUtils';
	import {
		deadlineStatus,
		formatDeadlineShort,
		todayLocalIso
	} from '$lib/utils/handicap-deadlines';

	export let entries: CalendarEntry[] = [];
	export let config: TournamentConfig;
	/** Dies en què no es programen partides (festius). */
	export let diesBloquejats: Date[] = [];

	const dispatch = createEventDispatcher<{ matchclick: string }>();

	const WEEKDAY_CODES: Record<number, string> = { 1: 'dl', 2: 'dt', 3: 'dc', 4: 'dj', 5: 'dv' };
	const DAY_NAMES: Record<number, string> = {
		0: 'Diumenge',
		1: 'Dilluns',
		2: 'Dimarts',
		3: 'Dimecres',
		4: 'Dijous',
		5: 'Divendres',
		6: 'Dissabte'
	};
	const STANDARD_HOURS = ['18:00', '19:00'];
	const NUM_BILLARS = 3;

	const today = todayLocalIso();

	function pad(n: number): string {
		return String(n).padStart(2, '0');
	}
	function isoOf(d: Date): string {
		return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
	}
	function dateLabel(d: Date): string {
		return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
	}
	function shortName(name: string): string {
		return formatarNomJugador(name);
	}
	function bracketClass(b: 'winners' | 'losers' | 'grand_final' | null | undefined): string {
		if (b === 'winners') return 'code-w';
		if (b === 'losers') return 'code-l';
		if (b === 'grand_final') return 'code-gf';
		return '';
	}
	function deadlineCls(e: CalendarEntry): string {
		const st = deadlineStatus(e.dataMaximaDisputa, today, e.estat);
		if (st === 'passed') return 'hcap-deadline hcap-deadline-passed';
		if (st === 'soon') return 'hcap-deadline hcap-deadline-soon';
		if (st === 'safe') return 'hcap-deadline hcap-deadline-safe';
		return '';
	}

	/** La partida està programada però algun jugador encara no s'ha
	 *  resolt: la data és orientativa, s'ha de confirmar. */
	function isTentative(e: CalendarEntry): boolean {
		return e.playersResolved === false;
	}
	const TENTATIVE_TITLE = 'Data orientativa, a confirmar quan es determinin els jugadors';

	$: entryByKey = new Map<string, CalendarEntry>(
		entries.map((e) => [`${e.data_programada}|${e.hora_inici}|${e.taula_assignada}`, e])
	);

	const tournamentStart = parseLocalDate(config.data_inici);
	const tournamentEnd = parseLocalDate(config.data_fi);
	const bloquejatsSet = new Set(diesBloquejats.map(isoOf));

	function getHoursForDay(dayCode: string): string[] {
		const hours: string[] = [];
		if (config.horaris_extra?.franja && config.horaris_extra.dies.includes(dayCode)) {
			hours.push(config.horaris_extra.franja);
		}
		hours.push(...STANDARD_HOURS);
		return hours;
	}

	type CalRow = {
		billar: number;
		entry: CalendarEntry | null;
	};
	type GroupHour = { hora: string; items: CalRow[] };
	type GroupDay = { date: Date; dateIso: string; total: number; hours: GroupHour[] };

	// Filtres
	let filterMode: 'all' | 'occupied' | 'free' = 'all';

	$: groupedDays = (() => {
		const days: GroupDay[] = [];
		for (let d = new Date(tournamentStart); d <= tournamentEnd; d.setDate(d.getDate() + 1)) {
			const dayCode = WEEKDAY_CODES[d.getDay()];
			if (!dayCode) continue;
			const dIso = isoOf(d);
			if (bloquejatsSet.has(dIso)) continue;
			const hores = getHoursForDay(dayCode);
			const groupHours: GroupHour[] = [];
			let dayTotal = 0;
			for (const h of hores) {
				const items: CalRow[] = [];
				for (let b = 1; b <= NUM_BILLARS; b++) {
					const key = `${dIso}|${h}|${b}`;
					const entry = entryByKey.get(key) ?? null;
					if (filterMode === 'occupied' && !entry) continue;
					if (filterMode === 'free' && entry) continue;
					items.push({ billar: b, entry });
				}
				if (items.length > 0) {
					groupHours.push({ hora: h, items });
					dayTotal += items.length;
				}
			}
			if (dayTotal > 0) {
				days.push({ date: new Date(d), dateIso: dIso, total: dayTotal, hours: groupHours });
			}
		}
		return days;
	})();

	$: stats = {
		total: entries.length,
		played: entries.filter((e) => e.estat === 'jugada' || e.estat === 'walkover').length,
		scheduled: entries.filter((e) => e.estat === 'programada').length
	};
</script>

<div class="hcap-grid-root">
	<!-- Capçalera amb filtres i stats -->
	<div class="grid-head">
		<div class="filters">
			<button
				type="button"
				class:active={filterMode === 'all'}
				on:click={() => (filterMode = 'all')}
			>Tots</button>
			<button
				type="button"
				class:active={filterMode === 'occupied'}
				on:click={() => (filterMode = 'occupied')}
			>Ocupats</button>
			<button
				type="button"
				class:active={filterMode === 'free'}
				on:click={() => (filterMode = 'free')}
			>Lliures</button>
		</div>
		<div class="stats">
			<span class="stat-played">{stats.played} jugades</span>
			<span class="stat-scheduled">{stats.scheduled} programades</span>
			<span class="stat-total">{stats.total} totals</span>
		</div>
	</div>

	<div class="grid-scroll">
		<table class="cal-table">
			<thead>
				<tr>
					<th class="col-day">Dia</th>
					<th class="col-hora">Hora</th>
					<th class="col-billar">B</th>
					<th class="col-code">Match</th>
					<th class="col-dest">Destí</th>
					<th class="col-player">Jugador 1</th>
					<th class="col-player">Jugador 2</th>
					<th class="col-deadline">Data màx.</th>
				</tr>
			</thead>
			<tbody>
				{#each groupedDays as gd}
					{#each gd.hours as gh, hIdx}
						{#each gh.items as it, iIdx}
							<tr
								class:row-occupied={!!it.entry}
								class:row-free={!it.entry}
								class:row-tentative={!!it.entry && isTentative(it.entry)}
								class:row-day-first={hIdx === 0 && iIdx === 0}
								class:row-hour-first={iIdx === 0}
							>
								{#if hIdx === 0 && iIdx === 0}
									<td class="day-cell" rowspan={gd.total}>
										<span class="d-num">{dateLabel(gd.date)}</span>
										<span class="d-name">{DAY_NAMES[gd.date.getDay()]}</span>
									</td>
								{/if}
								{#if iIdx === 0}
									<td class="hour-cell" rowspan={gh.items.length}>{gh.hora}</td>
								{/if}
								<td class="billar-cell">B{it.billar}</td>
								{#if it.entry}
									<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
									<td
										class="code-cell {bracketClass(it.entry.bracket_type)}"
										title={isTentative(it.entry) ? TENTATIVE_TITLE : ''}
										on:click={() => dispatch('matchclick', it.entry.id)}
									>{it.entry.matchCode ?? ''}{#if isTentative(it.entry)} <span class="tentative-mark">*</span>{/if}</td>
									<td class="dest-cell">
										{#if it.entry.winnerDest}
											<span class="arrow-win">↗G: <strong>{it.entry.winnerDest}</strong></span>
										{/if}
										{#if it.entry.loserDest}
											<span class="arrow-lose">↘P: <strong>{it.entry.loserDest}</strong></span>
										{/if}
									</td>
									<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
									<td
										class="player-cell"
										on:click={() => dispatch('matchclick', it.entry.id)}
									>{shortName(it.entry.player1_name)}</td>
									<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
									<td
										class="player-cell"
										on:click={() => dispatch('matchclick', it.entry.id)}
									>{shortName(it.entry.player2_name)}</td>
									<td class="deadline-cell">
										{#if it.entry.dataMaximaDisputa}
											<span class={deadlineCls(it.entry)} title="Data màxima: {it.entry.dataMaximaDisputa}">{formatDeadlineShort(it.entry.dataMaximaDisputa)}</span>
										{/if}
									</td>
								{:else}
									<td class="empty-cell" colspan="5">— Lliure —</td>
								{/if}
							</tr>
						{/each}
					{/each}
				{/each}
				{#if groupedDays.length === 0}
					<tr>
						<td colspan="8" class="empty-message">No hi ha cap slot que coincideixi amb el filtre.</td>
					</tr>
				{/if}
			</tbody>
		</table>
	</div>
</div>

<style>
	.hcap-grid-root {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		font-family: var(--font-sans);
		color: var(--ink);
		background: var(--paper-elevated);
		border: 1px solid var(--rule);
	}
	.grid-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.625rem 0.75rem;
		border-bottom: 1px solid var(--rule);
		gap: 0.75rem;
		flex-wrap: wrap;
	}
	.filters {
		display: inline-flex;
		gap: 0.25rem;
		border: 1px solid var(--rule-strong);
		padding: 2px;
	}
	.filters button {
		padding: 0.25rem 0.625rem;
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--ink-3);
		background: transparent;
		border: none;
		cursor: pointer;
		font-family: inherit;
	}
	.filters button:hover { background: var(--paper); }
	.filters button.active {
		background: var(--ink);
		color: var(--paper-elevated);
	}
	.stats {
		display: inline-flex;
		gap: 0.75rem;
		font-size: 0.75rem;
		color: var(--ink-soft);
	}
	.stat-played { color: var(--green); font-weight: 700; }
	.stat-scheduled { color: var(--blue); font-weight: 700; }

	.grid-scroll {
		overflow-x: auto;
		-webkit-overflow-scrolling: touch;
	}
	.cal-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8125rem;
		min-width: 880px;
	}
	.cal-table th, .cal-table td {
		border: 1px solid var(--rule-strong);
		padding: 0.4rem 0.6rem;
		text-align: center;
		vertical-align: middle;
	}
	.cal-table th {
		background: var(--paper);
		font-weight: 700;
		font-size: 0.6875rem;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: var(--ink-3);
		padding: 0.5rem 0.6rem;
		position: sticky;
		top: 0;
		z-index: 1;
		border-bottom: 2px solid var(--rule-strong);
	}
	.day-cell {
		background: var(--paper);
		font-weight: 700;
		border-right: 2px solid var(--rule-strong);
		white-space: nowrap;
		width: 110px;
	}
	.day-cell .d-num { display: block; font-size: 1.125rem; font-weight: 800; color: var(--ink); }
	.day-cell .d-name { display: block; font-size: 0.75rem; color: var(--ink-soft); font-weight: 600; }
	.hour-cell {
		background: var(--paper);
		font-weight: 700;
		font-size: 0.9375rem;
		border-right: 2px solid var(--rule-strong);
		width: 70px;
	}
	.billar-cell {
		background: var(--paper-elevated);
		font-weight: 700;
		font-size: 0.8125rem;
		color: var(--ink-soft);
		width: 50px;
	}
	.code-cell {
		font-weight: 800;
		font-size: 0.875rem;
		letter-spacing: 0.04em;
		width: 78px;
		cursor: pointer;
	}
	.code-cell:hover { background: rgba(0, 0, 0, 0.04); }
	.code-w { color: var(--blue); }
	.code-l { color: var(--amber); }
	.code-gf { color: var(--sec-handicap); }
	.dest-cell {
		font-size: 0.6875rem;
		font-weight: 600;
		text-align: left;
		white-space: nowrap;
		min-width: 100px;
	}
	.dest-cell .arrow-win, .dest-cell .arrow-lose { display: block; line-height: 1.25; }
	.dest-cell .arrow-win { color: var(--green); }
	.dest-cell .arrow-lose { color: var(--accent); }
	.dest-cell strong { font-weight: 800; }
	.player-cell {
		text-align: left;
		font-weight: 500;
		min-width: 160px;
		max-width: 240px;
		cursor: pointer;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.player-cell:hover { background: rgba(0, 0, 0, 0.04); }
	.deadline-cell {
		width: 80px;
		font-weight: 700;
	}
	.empty-cell {
		color: var(--ink-3);
		font-style: italic;
		text-align: center;
		background: var(--paper);
	}
	.empty-message {
		padding: 2rem;
		text-align: center;
		color: var(--ink-soft);
		font-style: italic;
	}

	.row-free .billar-cell { background: var(--paper); }

	/* Files amb data orientativa (jugadors no resolts): contingut en cursiva
	   i marca * darrere del codi. */
	.row-tentative .code-cell,
	.row-tentative .player-cell,
	.row-tentative .dest-cell {
		font-style: italic;
		color: var(--ink-soft);
	}
	.tentative-mark {
		font-weight: 800;
		color: var(--amber);
		margin-left: 1px;
	}

	:global(.hcap-grid-root .hcap-deadline) {
		display: inline-block;
		font-size: 10px;
		font-weight: 700;
		line-height: 1;
		letter-spacing: 0.02em;
		padding: 2px 5px;
		border: 1px solid currentColor;
		border-radius: 2px;
		white-space: nowrap;
	}
	:global(.hcap-grid-root .hcap-deadline-safe) {
		color: var(--ink-soft);
		opacity: 0.7;
	}
	:global(.hcap-grid-root .hcap-deadline-soon) {
		color: var(--amber);
		background: rgba(255, 176, 0, 0.08);
	}
	:global(.hcap-grid-root .hcap-deadline-passed) {
		color: var(--accent);
		background: rgba(217, 25, 25, 0.08);
		font-weight: 800;
	}
</style>
