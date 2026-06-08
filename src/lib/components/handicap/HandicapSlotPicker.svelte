<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type {
		ParticipantAvailability,
		TournamentConfig,
		OccupiedSlot
	} from '$lib/utils/handicap-scheduler';
	import { parseLocalDate, formatDate } from '$lib/utils/handicap-scheduler';

	// Poden ser null quan la partida és una pre-reserva (algun jugador encara
	// no està definit). En aquest cas el jugador absent es tracta com a
	// "sense restriccions" (disponible a tot arreu) per permetre l'assignació
	// manual orientativa.
	export let avail1: ParticipantAvailability | null = null;
	export let avail2: ParticipantAvailability | null = null;
	export let config: TournamentConfig;

	const EMPTY_AVAIL: ParticipantAvailability = {
		participant_id: '',
		preferencies_dies: [],
		preferencies_hores: []
	};
	$: a1 = avail1 ?? EMPTY_AVAIL;
	$: a2 = avail2 ?? EMPTY_AVAIL;
	export let occupiedSlots: OccupiedSlot[] = [];
	/** Slot actual assignat a la partida (es marca en blau; no es considera "ocupat"). */
	export let currentSlot: { data: string; hora: string; taula: number } | null = null;

	const dispatch = createEventDispatcher<{
		select: { data: string; hora: string; taula: number };
		cancel: void;
	}>();

	// ── Constants ─────────────────────────────────────────────────────────────
	const WEEKDAY_CODES: Record<number, string> = { 1: 'dl', 2: 'dt', 3: 'dc', 4: 'dj', 5: 'dv' };
	const DAY_LABELS: Record<number, string> = {
		1: 'Dilluns',
		2: 'Dimarts',
		3: 'Dimecres',
		4: 'Dijous',
		5: 'Divendres'
	};
	const STANDARD_HOURS = ['18:00', '19:00'];
	const NUM_TAULES = 3;

	// ── Dates ─────────────────────────────────────────────────────────────────
	const tournamentStart = parseLocalDate(config.data_inici);
	const tournamentEnd = parseLocalDate(config.data_fi);

	function mondayOf(date: Date): Date {
		const d = new Date(date);
		const day = d.getDay();
		const diff = day === 0 ? -6 : 1 - day;
		d.setDate(d.getDate() + diff);
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

	// ── Slots ocupats (excloent el slot actual de la partida) ─────────────────
	$: filteredOccupied = occupiedSlots.filter(
		(s) =>
			!currentSlot ||
			!(
				s.data === currentSlot.data &&
				s.hora === currentSlot.hora &&
				s.taula === currentSlot.taula
			)
	);
	$: occupiedSet = new Set(
		filteredOccupied.map((s) => `${s.data}|${s.hora}|${s.taula}`)
	);

	// Jugadors ocupats per (data, hora) en QUALSEVOL taula. Un slot està
	// "ocupat per jugador" quan algun dels dos participants del match que
	// volem programar (avail1/avail2) ja juga en aquesta franja horària.
	$: playerBusyAt = (() => {
		const map = new Map<string, Set<string>>();
		for (const s of filteredOccupied) {
			if (!s.participantIds || s.participantIds.length === 0) continue;
			const key = `${s.data}|${s.hora}`;
			let set = map.get(key);
			if (!set) { set = new Set(); map.set(key, set); }
			for (const pid of s.participantIds) set.add(pid);
		}
		return map;
	})();
	function isPlayerBusy(data: string, hora: string): boolean {
		const set = playerBusyAt.get(`${data}|${hora}`);
		if (!set) return false;
		return (
			(!!a1.participant_id && set.has(a1.participant_id)) ||
			(!!a2.participant_id && set.has(a2.participant_id))
		);
	}

	// ── Dies de la setmana actual (filtrats per rang del torneig) ─────────────
	$: weekDays = Array.from({ length: 5 }, (_, i) => {
		const d = new Date(weekStart);
		d.setDate(d.getDate() + i);
		return d;
	}).filter((d) => d >= tournamentStart && d <= tournamentEnd);

	// ── Hores disponibles ─────────────────────────────────────────────────────
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

	// ── Disponibilitat ────────────────────────────────────────────────────────
	function isPlayerAvail(avail: ParticipantAvailability, dayCode: string, hora: string): boolean {
		const diaOk =
			avail.preferencies_dies.length === 0 || avail.preferencies_dies.includes(dayCode);
		const horaOk =
			avail.preferencies_hores.length === 0 || avail.preferencies_hores.includes(hora);
		return diaOk && horaOk;
	}

	type SlotStatus = 'current' | 'occupied' | 'both' | 'one' | 'none';

	function slotStatus(data: string, dayCode: string, hora: string, taula: number): SlotStatus {
		if (
			currentSlot &&
			currentSlot.data === data &&
			currentSlot.hora === hora &&
			currentSlot.taula === taula
		)
			return 'current';
		// Ocupat: el billar ja és pres O un dels jugadors ja juga en una altra
		// taula en aquesta mateixa franja horària.
		if (occupiedSet.has(`${data}|${hora}|${taula}`)) return 'occupied';
		if (isPlayerBusy(data, hora)) return 'occupied';
		const p1 = isPlayerAvail(a1, dayCode, hora);
		const p2 = isPlayerAvail(a2, dayCode, hora);
		if (p1 && p2) return 'both';
		if (p1 || p2) return 'one';
		return 'none';
	}

	const STATUS_CLASSES: Record<SlotStatus, string> = {
		current: 'bg-blue-500 text-white ring-2 ring-blue-300 hover:bg-blue-600 cursor-pointer',
		occupied: 'bg-red-200 text-red-400 cursor-not-allowed',
		both: 'bg-green-500 text-white hover:bg-green-600 cursor-pointer',
		one: 'bg-yellow-400 text-white hover:bg-yellow-500 cursor-pointer',
		none: 'bg-gray-200 text-gray-500 hover:bg-gray-300 cursor-pointer'
	};

	const STATUS_TITLES: Record<SlotStatus, string> = {
		current: 'Slot actual (clic per reconfirmar)',
		occupied: 'Ocupat',
		both: 'Ambdós jugadors disponibles',
		one: 'Un jugador no disponible (assignació forçada)',
		none: 'Cap jugador disponible (assignació forçada)'
	};

	function selectSlot(data: string, hora: string, taula: number, status: SlotStatus) {
		if (status === 'occupied') return;
		dispatch('select', { data, hora, taula });
	}
</script>

<div class="hcap-component-root rounded-lg border border-gray-200 bg-white shadow-sm">
	<!-- Capçalera amb navegació setmanal -->
	<div class="flex items-center justify-between border-b border-gray-100 px-4 py-3">
		<button
			type="button"
			on:click={prevWeek}
			disabled={!canPrev}
			class="rounded px-3 py-1 text-sm text-gray-600 hover:bg-gray-100 disabled:opacity-30"
		>
			← Ant.
		</button>
		<span class="text-sm font-medium text-gray-700">
			Setmana del {formatDate(weekStart)}
		</span>
		<button
			type="button"
			on:click={nextWeek}
			disabled={!canNext}
			class="rounded px-3 py-1 text-sm text-gray-600 hover:bg-gray-100 disabled:opacity-30"
		>
			Seg. →
		</button>
	</div>

	<!-- Llegenda -->
	<div
		class="flex flex-wrap gap-3 border-b border-gray-50 px-4 py-2 text-xs text-gray-500"
	>
		<span class="flex items-center gap-1">
			<span class="inline-block h-3 w-3 rounded bg-green-500"></span>Ambdós disponibles
		</span>
		<span class="flex items-center gap-1">
			<span class="inline-block h-3 w-3 rounded bg-yellow-400"></span>Un no disponible
		</span>
		<span class="flex items-center gap-1">
			<span class="inline-block h-3 w-3 rounded bg-gray-200"></span>Cap disponible
		</span>
		<span class="flex items-center gap-1">
			<span class="inline-block h-3 w-3 rounded bg-red-200"></span>Ocupat
		</span>
		{#if currentSlot}
			<span class="flex items-center gap-1">
				<span class="inline-block h-3 w-3 rounded bg-blue-500"></span>Slot actual
			</span>
		{/if}
	</div>

	{#if weekDays.length === 0}
		<p class="p-6 text-center text-sm text-gray-500">
			Cap dia disponible en aquesta setmana (fora del període del torneig).
		</p>
	{:else}
		<!-- Graella -->
		<div class="overflow-x-auto">
			<table class="w-full text-sm">
				<thead>
					<tr class="border-b border-gray-100 bg-gray-50">
						<th class="w-32 px-3 py-2 text-left text-xs text-gray-500">Dia</th>
						{#each allHours as hora}
							<th class="px-3 py-2 text-center text-xs text-gray-500">{hora}</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each weekDays as day}
						{@const dayCode = WEEKDAY_CODES[day.getDay()]}
						{@const data = formatDate(day)}
						{@const dayHours = getHoursForDay(dayCode)}
						<tr class="border-b border-gray-50 hover:bg-gray-50/50">
							<td class="px-3 py-2 text-xs font-medium text-gray-700">
								{DAY_LABELS[day.getDay()]}
								<span class="text-gray-400">{day.getDate()}/{day.getMonth() + 1}</span>
							</td>
							{#each allHours as hora}
								<td class="px-2 py-2 text-center">
									{#if dayHours.includes(hora)}
										<div class="flex justify-center gap-1">
											{#each Array.from({ length: NUM_TAULES }, (_, i) => i + 1) as taula}
												{@const st = slotStatus(data, dayCode, hora, taula)}
												<button
													type="button"
													on:click={() => selectSlot(data, hora, taula, st)}
													disabled={st === 'occupied'}
													title="T{taula} — {STATUS_TITLES[st]}"
													class="h-7 w-7 rounded text-xs font-bold transition-colors {STATUS_CLASSES[st]}"
												>
													T{taula}
												</button>
											{/each}
										</div>
									{:else}
										<span class="text-gray-200">—</span>
									{/if}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}

	<div class="flex justify-end border-t border-gray-100 px-4 py-3">
		<button
			type="button"
			on:click={() => dispatch('cancel')}
			class="rounded border border-gray-300 bg-white px-4 py-1.5 text-sm text-gray-700 hover:bg-gray-50"
		>
			Cancel·lar
		</button>
	</div>
</div>

<style>
	.hcap-component-root {
		background: var(--paper-elevated) !important;
		border: 1px solid var(--rule) !important;
		border-radius: 0 !important;
		box-shadow: none !important;
	}
	.hcap-component-root :global(.bg-white) { background: var(--paper-elevated) !important; }
	.hcap-component-root :global(.bg-gray-50),
	.hcap-component-root :global(.bg-gray-100),
	.hcap-component-root :global(.bg-gray-200) { background: var(--paper) !important; }

	.hcap-component-root :global(.bg-blue-500) { background: var(--blue) !important; color: white !important; }
	.hcap-component-root :global(.bg-blue-600) { background: var(--blue) !important; color: white !important; }
	.hcap-component-root :global(.bg-blue-300),
	.hcap-component-root :global(.ring-blue-300) { --tw-ring-color: var(--blue) !important; }

	.hcap-component-root :global(.bg-green-500) { background: var(--green) !important; color: white !important; }
	.hcap-component-root :global(.bg-green-600) { background: var(--green) !important; color: white !important; }

	.hcap-component-root :global(.bg-yellow-400) { background: var(--amber) !important; color: white !important; }
	.hcap-component-root :global(.bg-yellow-500) { background: var(--amber) !important; color: white !important; }

	.hcap-component-root :global(.bg-red-200) {
		background: color-mix(in srgb, var(--accent) 20%, var(--paper)) !important;
		color: var(--accent) !important;
	}

	.hcap-component-root :global(.text-red-400) { color: var(--accent) !important; }
	.hcap-component-root :global(.text-gray-200) { color: var(--rule) !important; }
	.hcap-component-root :global(.text-gray-400),
	.hcap-component-root :global(.text-gray-500),
	.hcap-component-root :global(.text-gray-600) { color: var(--ink-soft) !important; }
	.hcap-component-root :global(.text-gray-700) { color: var(--ink) !important; }

	.hcap-component-root :global(.border-gray-100),
	.hcap-component-root :global(.border-gray-200),
	.hcap-component-root :global(.border-gray-300),
	.hcap-component-root :global(.border-gray-50) { border-color: var(--rule) !important; }

	.hcap-component-root :global(button) {
		font-family: var(--font-sans);
		border-radius: 0 !important;
	}
	.hcap-component-root :global(.rounded),
	.hcap-component-root :global(.rounded-sm),
	.hcap-component-root :global(.rounded-md),
	.hcap-component-root :global(.rounded-lg) { border-radius: 0 !important; }
	.hcap-component-root :global(.shadow-sm),
	.hcap-component-root :global(.shadow),
	.hcap-component-root :global(.shadow-md) { box-shadow: none !important; }
</style>
