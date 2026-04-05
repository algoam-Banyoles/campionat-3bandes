<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { CalendarEntry } from '$lib/utils/handicap-types';
	import type { TournamentConfig } from '$lib/utils/handicap-scheduler';
	import { parseLocalDate, formatDate } from '$lib/utils/handicap-scheduler';

	export let entries: CalendarEntry[] = [];
	export let config: TournamentConfig;

	const dispatch = createEventDispatcher<{ matchclick: string }>();

	// ── Constants ─────────────────────────────────────────────────────────────

	const WEEKDAY_CODES: Record<number, string> = { 1: 'dl', 2: 'dt', 3: 'dc', 4: 'dj', 5: 'dv' };
	const DAY_LABELS: Record<number, string> = {
		1: 'Dilluns',
		2: 'Dimarts',
		3: 'Dimecres',
		4: 'Dijous',
		5: 'Divendres'
	};
	const DAY_SHORT: Record<number, string> = { 1: 'Dl', 2: 'Dt', 3: 'Dc', 4: 'Dj', 5: 'Dv' };
	const STANDARD_HOURS = ['18:00', '19:00'];
	const NUM_TAULES = 3;

	const BRACKET_LABELS: Record<string, string> = { winners: 'W', losers: 'L', grand_final: 'GF' };
	const ESTAT_BG: Record<string, string> = {
		programada: 'bg-blue-50 border-blue-200 hover:bg-blue-100',
		jugada: 'bg-green-50 border-green-200 hover:bg-green-100',
		walkover: 'bg-amber-50 border-amber-200 hover:bg-amber-100'
	};

	// ── Dates del torneig ─────────────────────────────────────────────────────

	const tournamentStart = parseLocalDate(config.data_inici);
	const tournamentEnd = parseLocalDate(config.data_fi);

	function mondayOf(date: Date): Date {
		const d = new Date(date);
		const day = d.getDay();
		d.setDate(d.getDate() + (day === 0 ? -6 : 1 - day));
		return d;
	}

	let weekStart = mondayOf(tournamentStart);

	$: canPrev = weekStart > mondayOf(tournamentStart);
	$: canNext = (() => {
		const next = new Date(weekStart);
		next.setDate(next.getDate() + 7);
		return next <= tournamentEnd;
	})();

	function prevWeek() {
		if (!canPrev) return;
		const d = new Date(weekStart);
		d.setDate(d.getDate() - 7);
		weekStart = d;
	}

	function nextWeek() {
		if (!canNext) return;
		const d = new Date(weekStart);
		d.setDate(d.getDate() + 7);
		weekStart = d;
	}

	// ── Dies i hores de la setmana ─────────────────────────────────────────────

	$: weekDays = Array.from({ length: 5 }, (_, i) => {
		const d = new Date(weekStart);
		d.setDate(d.getDate() + i);
		return d;
	}).filter((d) => d >= tournamentStart && d <= tournamentEnd);

	function getHoursForDay(dayCode: string): string[] {
		const hours: string[] = [];
		if (config.horaris_extra?.franja && config.horaris_extra.dies.includes(dayCode)) {
			hours.push(config.horaris_extra.franja);
		}
		hours.push(...STANDARD_HOURS);
		return hours;
	}

	$: allHours = (() => {
		const hset = new Set<string>();
		for (const d of weekDays) {
			const dc = WEEKDAY_CODES[d.getDay()];
			if (dc) getHoursForDay(dc).forEach((h) => hset.add(h));
		}
		return [...hset].sort();
	})();

	// ── Mapa d'entrades per (data, hora, taula) ───────────────────────────────

	$: entryMap = new Map<string, CalendarEntry>(
		entries.map((e) => [`${e.data_programada}|${e.hora_inici}|${e.taula_assignada}`, e])
	);

	function getEntry(data: string, hora: string, taula: number): CalendarEntry | null {
		return entryMap.get(`${data}|${hora}|${taula}`) ?? null;
	}

	// ── Estadística de la setmana ─────────────────────────────────────────────

	$: weekEntries = (() => {
		const weekDates = new Set(weekDays.map((d) => formatDate(d)));
		return entries.filter((e) => weekDates.has(e.data_programada));
	})();

	$: weekStats = {
		total: weekEntries.length,
		played: weekEntries.filter((e) => e.estat === 'jugada' || e.estat === 'walkover').length,
		scheduled: weekEntries.filter((e) => e.estat === 'programada').length
	};

	function shortName(name: string): string {
		const parts = name.trim().split(' ');
		if (parts.length === 1) return parts[0];
		return `${parts[0]} ${parts[parts.length - 1][0]}.`;
	}
</script>

<div class="rounded-lg border border-gray-200 bg-white shadow-sm">
	<!-- Capçalera amb navegació i stats de la setmana -->
	<div class="flex items-center justify-between border-b border-gray-100 px-4 py-3">
		<button
			type="button"
			on:click={prevWeek}
			disabled={!canPrev}
			class="rounded px-3 py-1 text-sm text-gray-600 hover:bg-gray-100 disabled:opacity-30"
		>
			← Ant.
		</button>
		<div class="text-center">
			<span class="text-sm font-medium text-gray-700">
				Setmana del {formatDate(weekStart)}
			</span>
			{#if weekStats.total > 0}
				<div class="mt-0.5 flex justify-center gap-3 text-xs text-gray-500">
					<span><span class="font-medium text-green-600">{weekStats.played}</span> jugades</span>
					<span><span class="font-medium text-blue-600">{weekStats.scheduled}</span> programades</span>
				</div>
			{/if}
		</div>
		<button
			type="button"
			on:click={nextWeek}
			disabled={!canNext}
			class="rounded px-3 py-1 text-sm text-gray-600 hover:bg-gray-100 disabled:opacity-30"
		>
			Seg. →
		</button>
	</div>

	{#if weekDays.length === 0}
		<p class="p-8 text-center text-sm text-gray-500">
			Cap dia del torneig en aquesta setmana.
		</p>
	{:else}
		<div class="overflow-x-auto">
			<table class="w-full text-sm">
				<thead>
					<tr class="border-b border-gray-100 bg-gray-50">
						<th class="w-16 px-3 py-2 text-left text-xs font-medium text-gray-500">Hora</th>
						{#each weekDays as day}
							{@const dayCode = WEEKDAY_CODES[day.getDay()]}
							<th class="px-2 py-2 text-center text-xs font-medium text-gray-500">
								<div>{DAY_LABELS[day.getDay()]}</div>
								<div class="text-gray-400">{day.getDate()}/{day.getMonth() + 1}</div>
							</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each allHours as hora}
						<tr class="border-b border-gray-50">
							<td
								class="px-3 py-2 align-top text-xs font-semibold text-gray-500"
							>
								{hora}
							</td>
							{#each weekDays as day}
								{@const dayCode = WEEKDAY_CODES[day.getDay()]}
								{@const data = formatDate(day)}
								{@const dayHours = getHoursForDay(dayCode)}
								<td class="px-1 py-1 align-top">
									{#if dayHours.includes(hora)}
										<div class="space-y-1">
											{#each Array.from({ length: NUM_TAULES }, (_, i) => i + 1) as taula}
												{@const entry = getEntry(data, hora, taula)}
												{#if entry}
													<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
													<div
														class="cursor-pointer rounded border p-1.5 text-xs transition-colors {ESTAT_BG[
															entry.estat
														] ?? 'bg-gray-50 border-gray-200 hover:bg-gray-100'}"
														on:click={() => dispatch('matchclick', entry.id)}
														title="{entry.player1_name} vs {entry.player2_name}"
													>
														<div class="flex items-center gap-1 mb-0.5">
															<span
																class="rounded px-1 py-0 text-[9px] font-bold
																{entry.bracket_type === 'winners'
																	? 'bg-blue-100 text-blue-700'
																	: entry.bracket_type === 'losers'
																		? 'bg-orange-100 text-orange-700'
																		: 'bg-purple-100 text-purple-700'}"
															>
																{BRACKET_LABELS[entry.bracket_type]} R{entry.ronda}
															</span>
															<span class="text-[9px] text-gray-400">T{taula}</span>
														</div>
														<div class="font-medium text-gray-800 leading-tight">
															{shortName(entry.player1_name)}
														</div>
														<div class="text-gray-500 leading-tight">
															vs {shortName(entry.player2_name)}
														</div>
													</div>
												{:else}
													<div
														class="rounded border border-dashed border-gray-100 px-1 py-1 text-center text-[9px] text-gray-300"
													>
														T{taula}
													</div>
												{/if}
											{/each}
										</div>
									{:else}
										<div class="py-2 text-center text-xs text-gray-200">—</div>
									{/if}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		<!-- Llegenda -->
		<div class="flex flex-wrap gap-3 border-t border-gray-50 px-4 py-2 text-xs text-gray-500">
			<span class="flex items-center gap-1">
				<span class="inline-block h-3 w-3 rounded border border-blue-200 bg-blue-50"></span>Programada
			</span>
			<span class="flex items-center gap-1">
				<span class="inline-block h-3 w-3 rounded border border-green-200 bg-green-50"></span>Jugada
			</span>
			<span class="flex items-center gap-1">
				<span class="inline-block h-3 w-3 rounded border border-dashed border-gray-200"></span>Lliure
			</span>
		</div>
	{/if}
</div>
