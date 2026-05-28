<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { CalendarEntry } from '$lib/utils/handicap-types';
	import type { TournamentConfig } from '$lib/utils/handicap-scheduler';
	import { parseLocalDate, formatDate } from '$lib/utils/handicap-scheduler';
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
	const DAY_LABELS: Record<number, string> = {
		1: 'Dilluns',
		2: 'Dimarts',
		3: 'Dimecres',
		4: 'Dijous',
		5: 'Divendres'
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
	function shortName(name: string): string {
		return formatarNomJugador(name);
	}
	function bracketLetter(b: 'winners' | 'losers' | 'grand_final'): string {
		return b === 'winners' ? 'W' : b === 'losers' ? 'L' : 'GF';
	}
	function bracketClass(b: 'winners' | 'losers' | 'grand_final'): string {
		return b === 'winners' ? 'is-winners' : b === 'losers' ? 'is-losers' : 'is-gf';
	}
	function deadlineCls(e: CalendarEntry): string {
		const st = deadlineStatus(e.dataMaximaDisputa, today, e.estat);
		if (st === 'passed') return 'hcap-deadline hcap-deadline-passed';
		if (st === 'soon') return 'hcap-deadline hcap-deadline-soon';
		if (st === 'safe') return 'hcap-deadline hcap-deadline-safe';
		return '';
	}

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

	// Construïm el conjunt de "files" (date × hora × billar) per mostrar.
	type CalRow = {
		date: Date;
		dateIso: string;
		dateLabel: string; // 'Dl 02/06'
		hora: string;
		billar: number;
		entry: CalendarEntry | null;
	};

	$: rows = (() => {
		const out: CalRow[] = [];
		for (let d = new Date(tournamentStart); d <= tournamentEnd; d.setDate(d.getDate() + 1)) {
			const dayCode = WEEKDAY_CODES[d.getDay()];
			if (!dayCode) continue; // cap setmana
			const iso = isoOf(d);
			if (bloquejatsSet.has(iso)) continue;
			const hores = getHoursForDay(dayCode);
			const dayShort = DAY_LABELS[d.getDay()].substring(0, 2);
			const dateLabel = `${dayShort} ${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
			for (const h of hores) {
				for (let b = 1; b <= NUM_BILLARS; b++) {
					const key = `${iso}|${h}|${b}`;
					out.push({
						date: new Date(d),
						dateIso: iso,
						dateLabel,
						hora: h,
						billar: b,
						entry: entryByKey.get(key) ?? null
					});
				}
			}
		}
		return out;
	})();

	// Filtres
	let filterMode: 'all' | 'occupied' | 'free' = 'all';
	$: filteredRows = rows.filter((r) => {
		if (filterMode === 'occupied') return !!r.entry;
		if (filterMode === 'free') return !r.entry;
		return true;
	});

	// Agrupació per dia (per pintar rowspans visuals)
	type DayGroup = {
		dateIso: string;
		dateLabel: string;
		rows: CalRow[];
	};
	$: dayGroups = (() => {
		const map = new Map<string, DayGroup>();
		for (const r of filteredRows) {
			let g = map.get(r.dateIso);
			if (!g) {
				g = { dateIso: r.dateIso, dateLabel: r.dateLabel, rows: [] };
				map.set(r.dateIso, g);
			}
			g.rows.push(r);
		}
		return [...map.values()];
	})();

	$: stats = {
		total: entries.length,
		played: entries.filter((e) => e.estat === 'jugada' || e.estat === 'walkover').length,
		scheduled: entries.filter((e) => e.estat === 'programada').length
	};

	function rondaLabel(b: 'winners' | 'losers' | 'grand_final', r: number): string {
		const letter = bracketLetter(b);
		return `${letter}${r}`;
	}
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
		<table class="cal-grid">
			<thead>
				<tr>
					<th class="col-day">Dia</th>
					<th class="col-hora">Hora</th>
					<th class="col-billar">Billar</th>
					<th class="col-code">Codi</th>
					<th class="col-players">Partida</th>
					<th class="col-dest">Destí</th>
					<th class="col-deadline">Data màx.</th>
				</tr>
			</thead>
			<tbody>
				{#each dayGroups as g}
					{#each g.rows as r, i}
						<tr
							class:row-free={!r.entry}
							class:row-occupied={!!r.entry}
							class:row-first={i === 0}
						>
							{#if i === 0}
								<td class="col-day" rowspan={g.rows.length}>
									<span class="day-label">{g.dateLabel}</span>
								</td>
							{/if}
							<td class="col-hora">{r.hora}</td>
							<td class="col-billar">B{r.billar}</td>
							{#if r.entry}
								<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
								<td
									class="col-code clickable {bracketClass(r.entry.bracket_type)}"
									on:click={() => dispatch('matchclick', r.entry!.id)}
								>
									<span class="match-code">{r.entry.matchCode ?? rondaLabel(r.entry.bracket_type, r.entry.ronda)}</span>
								</td>
								<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
								<td
									class="col-players clickable"
									on:click={() => dispatch('matchclick', r.entry!.id)}
								>
									<span class="player-pair">
										<span class="player">{shortName(r.entry.player1_name)}</span>
										<span class="vs">vs</span>
										<span class="player">{shortName(r.entry.player2_name)}</span>
									</span>
								</td>
								<td class="col-dest">
									{#if r.entry.winnerDest}
										<span class="arrow-win">↗ {r.entry.winnerDest}</span>
									{/if}
									{#if r.entry.loserDest}
										<span class="arrow-lose">↘ {r.entry.loserDest}</span>
									{/if}
								</td>
								<td class="col-deadline">
									{#if r.entry.dataMaximaDisputa}
										<span class={deadlineCls(r.entry)} title="Data màxima: {r.entry.dataMaximaDisputa}">{formatDeadlineShort(r.entry.dataMaximaDisputa)}</span>
									{/if}
								</td>
							{:else}
								<td colspan="4" class="col-empty">— Lliure —</td>
							{/if}
						</tr>
					{/each}
				{/each}
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
		border-radius: 0;
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
	.cal-grid {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8125rem;
		min-width: 720px;
	}
	.cal-grid th {
		text-align: left;
		font-weight: 700;
		font-size: 0.6875rem;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: var(--ink-3);
		background: var(--paper);
		border-bottom: 2px solid var(--rule-strong);
		padding: 0.5rem 0.625rem;
		position: sticky;
		top: 0;
		z-index: 1;
	}
	.cal-grid td {
		padding: 0.4rem 0.625rem;
		border-bottom: 1px solid var(--rule);
		vertical-align: middle;
	}
	.col-day {
		font-weight: 700;
		font-size: 0.8125rem;
		background: var(--paper);
		border-right: 2px solid var(--rule-strong);
		white-space: nowrap;
		width: 90px;
	}
	.col-hora { width: 64px; font-weight: 600; color: var(--ink-soft); }
	.col-billar { width: 56px; font-weight: 600; color: var(--ink-soft); }
	.col-code { width: 80px; font-weight: 800; letter-spacing: 0.04em; }
	.col-code.is-winners .match-code { color: var(--blue); }
	.col-code.is-losers .match-code { color: var(--amber); }
	.col-code.is-gf .match-code { color: var(--sec-handicap); }
	.col-players { font-weight: 500; }
	.col-dest { font-size: 0.6875rem; white-space: nowrap; }
	.col-deadline { width: 90px; text-align: right; }
	.col-empty {
		color: var(--ink-3);
		font-style: italic;
		text-align: center;
	}

	.row-free { background: var(--paper); }
	.row-free .col-empty { opacity: 0.6; }
	.row-occupied:hover { background: var(--paper); }

	.clickable { cursor: pointer; }
	.clickable:hover { background: rgba(0, 0, 0, 0.03); }

	.player-pair {
		display: inline-flex;
		align-items: baseline;
		gap: 0.4rem;
		flex-wrap: wrap;
	}
	.vs { font-size: 0.6875rem; color: var(--ink-3); }
	.arrow-win { color: var(--green); margin-right: 0.5rem; font-weight: 700; }
	.arrow-lose { color: var(--accent); font-weight: 700; }

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
