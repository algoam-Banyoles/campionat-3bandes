<script lang="ts">
	import type { BranchMatchInput } from '$lib/utils/handicap-types';

	/**
	 * Indicador visual d'equilibri de branques del bracket guanyadors.
	 *
	 * Definició de branca:
	 *  - numR1 = partides de W-R1 (no bye)
	 *  - Per a un match a (ronda=r, matchPos=p):
	 *      matchesInRound = numR1 / 2^(r-1)
	 *      Si matchesInRound <= 1 → 'final' (s'omet)
	 *      Si p <= ceil(matchesInRound / 2) → Branca A (meitat superior)
	 *      Altrament → Branca B (meitat inferior)
	 *
	 * Avís si |maxRondaJugada(A) - maxRondaJugada(B)| > 1
	 */
	export let matches: BranchMatchInput[];

	// ── Lògica de branques ────────────────────────────────────────────────────

	$: wNonBye = matches.filter((m) => m.bracket_type === 'winners' && m.estat !== 'bye');
	$: numR1 = wNonBye.filter((m) => m.ronda === 1).length;

	function getBranch(ronda: number, matchPos: number): 'A' | 'B' | 'final' {
		if (numR1 <= 1) return 'final';
		const matchesInRound = numR1 / Math.pow(2, ronda - 1);
		if (matchesInRound <= 1) return 'final';
		return matchPos <= Math.ceil(matchesInRound / 2) ? 'A' : 'B';
	}

	interface RoundStats {
		ronda: number;
		total: number;
		played: number;
		scheduled: number;
	}
	interface BranchInfo {
		total: number;
		played: number;
		scheduled: number;
		maxPlayedRound: number;
		rounds: RoundStats[];
	}

	$: branchStats = (() => {
		const aMap = new Map<number, RoundStats>();
		const bMap = new Map<number, RoundStats>();
		let aTotal = 0,
			aPlayed = 0,
			aScheduled = 0,
			aMax = 0;
		let bTotal = 0,
			bPlayed = 0,
			bScheduled = 0,
			bMax = 0;

		for (const m of wNonBye) {
			const branch = getBranch(m.ronda, m.matchPos);
			if (branch === 'final') continue;

			const isPlayed = m.estat === 'jugada' || m.estat === 'walkover';
			const isScheduled = m.estat === 'programada';

			if (branch === 'A') {
				aTotal++;
				if (isPlayed) {
					aPlayed++;
					aMax = Math.max(aMax, m.ronda);
				}
				if (isScheduled) aScheduled++;
				if (!aMap.has(m.ronda)) aMap.set(m.ronda, { ronda: m.ronda, total: 0, played: 0, scheduled: 0 });
				const r = aMap.get(m.ronda)!;
				r.total++;
				if (isPlayed) r.played++;
				if (isScheduled) r.scheduled++;
			} else {
				bTotal++;
				if (isPlayed) {
					bPlayed++;
					bMax = Math.max(bMax, m.ronda);
				}
				if (isScheduled) bScheduled++;
				if (!bMap.has(m.ronda)) bMap.set(m.ronda, { ronda: m.ronda, total: 0, played: 0, scheduled: 0 });
				const r = bMap.get(m.ronda)!;
				r.total++;
				if (isPlayed) r.played++;
				if (isScheduled) r.scheduled++;
			}
		}

		const a: BranchInfo = {
			total: aTotal,
			played: aPlayed,
			scheduled: aScheduled,
			maxPlayedRound: aMax,
			rounds: [...aMap.values()].sort((x, y) => x.ronda - y.ronda)
		};
		const b: BranchInfo = {
			total: bTotal,
			played: bPlayed,
			scheduled: bScheduled,
			maxPlayedRound: bMax,
			rounds: [...bMap.values()].sort((x, y) => x.ronda - y.ronda)
		};
		return { a, b };
	})();

	$: imbalance = Math.abs(branchStats.a.maxPlayedRound - branchStats.b.maxPlayedRound);
	$: aIsAhead = branchStats.a.maxPlayedRound > branchStats.b.maxPlayedRound;
	$: hasData = branchStats.a.total > 0 || branchStats.b.total > 0;
	$: hasAnyPlayed = branchStats.a.played > 0 || branchStats.b.played > 0;

	function pct(played: number, total: number): number {
		if (total === 0) return 0;
		return Math.round((played / total) * 100);
	}

	function roundLabel(ronda: number): string {
		return ronda === 0 ? 'Cap' : `R${ronda}`;
	}
</script>

{#if hasData}
	<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
		<div class="mb-3 flex items-center justify-between">
			<h3 class="text-sm font-semibold text-gray-700">Equilibri de branques (Winners)</h3>
			{#if imbalance > 1 && hasAnyPlayed}
				<span class="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">
					⚠ Branca {aIsAhead ? 'A' : 'B'} va {imbalance} rondes per davant
				</span>
			{:else if imbalance === 1 && hasAnyPlayed}
				<span class="rounded-full bg-yellow-50 px-2 py-0.5 text-xs text-yellow-600">
					Branca {aIsAhead ? 'A' : 'B'} lleugerament per davant
				</span>
			{:else if hasAnyPlayed}
				<span class="rounded-full bg-green-50 px-2 py-0.5 text-xs text-green-600">
					Branques equilibrades
				</span>
			{/if}
		</div>

		<div class="space-y-3">
			{#each [{ label: 'A (meitat superior)', info: branchStats.a }, { label: 'B (meitat inferior)', info: branchStats.b }] as branch}
				<div>
					<div class="mb-1 flex items-center justify-between text-xs text-gray-600">
						<span class="font-medium">Branca {branch.label}</span>
						<span class="text-gray-500">
							{branch.info.played}/{branch.info.total} jugades
							{#if branch.info.scheduled > 0}
								· {branch.info.scheduled} programades
							{/if}
							· fins {roundLabel(branch.info.maxPlayedRound)}
						</span>
					</div>
					<!-- Barra de progrés per ronda -->
					<div class="flex gap-0.5">
						{#each branch.info.rounds as r}
							{@const allPlayed = r.played === r.total}
							{@const somePlayed = r.played > 0 && r.played < r.total}
							{@const someScheduled = r.scheduled > 0}
							<div
								class="flex flex-1 flex-col gap-0.5"
								title="R{r.ronda}: {r.played}/{r.total} jugades, {r.scheduled} programades"
							>
								<div class="h-4 overflow-hidden rounded-sm bg-gray-100">
									<div
										class="h-full transition-all {allPlayed
											? 'bg-green-500'
											: somePlayed
												? 'bg-green-300'
												: someScheduled
													? 'bg-blue-300'
													: 'bg-gray-100'}"
										style="width: {pct(r.played, r.total)}%"
									></div>
								</div>
								<div class="text-center text-[10px] text-gray-400">R{r.ronda}</div>
							</div>
						{/each}
					</div>
					<!-- Llegenda de rondes detallada -->
					<div class="mt-1 flex flex-wrap gap-2">
						{#each branch.info.rounds as r}
							<span
								class="rounded px-1.5 py-0.5 text-[10px] font-medium
								{r.played === r.total
									? 'bg-green-100 text-green-700'
									: r.played > 0
										? 'bg-yellow-50 text-yellow-700'
										: r.scheduled > 0
											? 'bg-blue-50 text-blue-600'
											: 'bg-gray-50 text-gray-500'}"
							>
								R{r.ronda}: {r.played}/{r.total}
								{#if r.scheduled > 0 && r.played < r.total}
									<span class="text-blue-500">(+{r.scheduled}★)</span>
								{/if}
							</span>
						{/each}
					</div>
				</div>
			{/each}
		</div>

		<!-- Llegenda colors -->
		<div class="mt-3 flex flex-wrap gap-3 border-t border-gray-50 pt-2 text-[10px] text-gray-400">
			<span class="flex items-center gap-1"><span class="inline-block h-2 w-4 rounded-sm bg-green-500"></span>Totes jugades</span>
			<span class="flex items-center gap-1"><span class="inline-block h-2 w-4 rounded-sm bg-green-300"></span>Parcialment jugades</span>
			<span class="flex items-center gap-1"><span class="inline-block h-2 w-4 rounded-sm bg-blue-300"></span>Programades</span>
			<span class="flex items-center gap-1"><span class="inline-block h-2 w-4 rounded-sm bg-gray-100 border"></span>Pendents</span>
		</div>
	</div>
{/if}
