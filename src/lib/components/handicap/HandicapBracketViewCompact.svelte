<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { MatchView } from '$lib/utils/handicap-types';
	import { buildMatchCodeMap, buildLoserDestCodeMap } from '$lib/utils/handicap-types';
	import { formatarNomJugador } from '$lib/utils/playerUtils';
	import {
		deadlineStatus,
		formatDeadlineShort,
		todayLocalIso,
		type DeadlineStatus
	} from '$lib/utils/handicap-deadlines';

	const dispatch = createEventDispatcher<{ matchclick: MatchView }>();

	export let matchViews: MatchView[] = [];
	export let filter: 'all' | 'winners' | 'losers' | 'grand_final' = 'all';
	export let searchTerm: string = '';
	export let sistemaPuntuacio: string = 'distancia';
	export let championParticipantId: string | null = null;

	$: matchCodeMap = buildMatchCodeMap(matchViews);
	$: loserDestCodeMap = buildLoserDestCodeMap(matchViews, matchCodeMap);

	const today = todayLocalIso();

	function pct(c: number | null, d: number | null): string {
		if (!c || !d) return '—';
		return `${Math.round((c / d) * 100)}%`;
	}

	function fmtDateShort(iso: string | null | undefined): string {
		if (!iso) return '';
		const part = iso.substring(0, 10);
		const [, m, d] = part.split('-');
		return d && m ? `${d}/${m}` : part;
	}

	function fmtDataHora(dh: string | null | undefined): string {
		if (!dh) return '';
		const [date, time] = dh.split(' ');
		if (!date || !time) return '';
		const [, mm, dd] = date.split('-');
		return `${dd}/${mm} · ${time}`;
	}

	function deadlinePillClass(m: MatchView): string {
		const st: DeadlineStatus = deadlineStatus(m.dataMaximaDisputa, today, m.estat);
		if (st === 'passed') return 'hcap-deadline hcap-deadline-passed';
		if (st === 'soon') return 'hcap-deadline hcap-deadline-soon';
		if (st === 'safe') return 'hcap-deadline hcap-deadline-safe';
		return '';
	}

	function destinationCode(m: MatchView, which: 'winner' | 'loser'): string {
		const destId = which === 'winner' ? m.winner_slot_dest_id : m.loser_slot_dest_id;
		if (!destId) return '—';
		// Cerca el match que conté aquest slot
		const dest = matchViews.find((mv) => mv.slot1.id === destId || mv.slot2.id === destId);
		if (!dest) return '—';
		return matchCodeMap.get(dest.id) ?? '—';
	}

	function playerLabel(m: MatchView, which: 1 | 2): string {
		const p = which === 1 ? m.player1 : m.player2;
		if (!p) return 'Per determinar';
		const display = p.shortName ?? p.name ?? '';
		return display ? formatarNomJugador(display) : 'Per determinar';
	}

	function isWinner(m: MatchView, which: 1 | 2): boolean {
		if (!m.guanyador_participant_id) return false;
		const target = which === 1 ? m.player1?.id : m.player2?.id;
		return !!target && target === m.guanyador_participant_id;
	}

	function isChampionMatch(m: MatchView): boolean {
		if (!championParticipantId) return false;
		return (
			m.player1?.id === championParticipantId || m.player2?.id === championParticipantId
		) && (m.estat === 'jugada' || m.estat === 'walkover');
	}

	function searchHit(m: MatchView): boolean {
		if (!searchTerm.trim()) return false;
		const t = searchTerm.toLowerCase();
		return playerLabel(m, 1).toLowerCase().includes(t)
			|| playerLabel(m, 2).toLowerCase().includes(t);
	}

	function rondaLabel(bracket: 'winners' | 'losers' | 'grand_final', r: number): string {
		if (bracket === 'grand_final') return r === 1 ? 'Gran Final' : 'Reset';
		const prefix = bracket === 'winners' ? 'Principal' : 'Repesca';
		return `${prefix} — Ronda ${r}`;
	}

	$: showWinners = filter === 'all' || filter === 'winners';
	$: showLosers = filter === 'all' || filter === 'losers';
	$: showGF = filter === 'all' || filter === 'grand_final';

	$: groupedWinners = (() => {
		const ms = matchViews.filter((m) => m.bracket_type === 'winners' && m.estat !== 'bye');
		const rondes = [...new Set(ms.map((m) => m.ronda))].sort((a, b) => a - b);
		return rondes.map((r) => ({
			ronda: r,
			items: ms.filter((m) => m.ronda === r).sort((a, b) => a.matchPos - b.matchPos)
		}));
	})();

	$: groupedLosers = (() => {
		const ms = matchViews.filter((m) => m.bracket_type === 'losers' && m.estat !== 'bye');
		const rondes = [...new Set(ms.map((m) => m.ronda))].sort((a, b) => a - b);
		return rondes.map((r) => ({
			ronda: r,
			items: ms.filter((m) => m.ronda === r).sort((a, b) => a.matchPos - b.matchPos)
		}));
	})();

	$: groupedGF = (() => {
		const ms = matchViews.filter((m) => m.bracket_type === 'grand_final' && m.estat !== 'bye');
		const rondes = [...new Set(ms.map((m) => m.ronda))].sort((a, b) => a - b);
		return rondes.map((r) => ({
			ronda: r,
			items: ms.filter((m) => m.ronda === r).sort((a, b) => a.matchPos - b.matchPos)
		}));
	})();
</script>

<div class="hcap-compact-root">
	{#if showWinners && groupedWinners.length > 0}
		<section class="bracket-section">
			<h3 class="section-title">Bracket de Guanyadors</h3>
			{#each groupedWinners as group}
				<div class="round-block">
					<h4 class="round-title">{rondaLabel('winners', group.ronda)}</h4>
					<div class="match-grid">
						{#each group.items as m}
							<button
								type="button"
								class="match-cell"
								class:is-played={m.estat === 'jugada' || m.estat === 'walkover'}
								class:is-pending={m.estat === 'pendent'}
								class:is-scheduled={m.estat === 'programada'}
								class:is-champion={isChampionMatch(m)}
								class:is-hit={searchHit(m)}
								on:click={() => dispatch('matchclick', m)}
							>
								<div class="cell-head">
									<span class="match-code">{matchCodeMap.get(m.id) ?? '?'}</span>
									<span class="arrows">
										<span class="arrow-win" title="Guanyador va a">↗ {destinationCode(m, 'winner')}</span>
										{#if m.loser_slot_dest_id}
											<span class="arrow-lose" title="Perdedor va a">↘ {destinationCode(m, 'loser')}</span>
										{/if}
									</span>
								</div>
								<div class="player-row" class:winner={isWinner(m, 1)}>
									<span class="player-name">{playerLabel(m, 1)}</span>
									{#if m.estat === 'jugada' && m.caramboles1 !== null}
										<span class="score">
											{m.caramboles1}{#if m.distancia_jugador1}<span class="dist">/{m.distancia_jugador1}</span>{/if}
											{#if sistemaPuntuacio === 'percentatge' && m.distancia_jugador1}
												<span class="pct">{pct(m.caramboles1, m.distancia_jugador1)}</span>
											{/if}
										</span>
									{:else if m.distancia_jugador1}
										<span class="dist-tag">{m.distancia_jugador1}c</span>
									{/if}
								</div>
								<div class="player-row" class:winner={isWinner(m, 2)}>
									<span class="player-name">{playerLabel(m, 2)}</span>
									{#if m.estat === 'jugada' && m.caramboles2 !== null}
										<span class="score">
											{m.caramboles2}{#if m.distancia_jugador2}<span class="dist">/{m.distancia_jugador2}</span>{/if}
											{#if sistemaPuntuacio === 'percentatge' && m.distancia_jugador2}
												<span class="pct">{pct(m.caramboles2, m.distancia_jugador2)}</span>
											{/if}
										</span>
									{:else if m.distancia_jugador2}
										<span class="dist-tag">{m.distancia_jugador2}c</span>
									{/if}
								</div>
								<div class="cell-foot">
									<span class="sched">{m.data_hora ? fmtDataHora(m.data_hora) : '—'}{m.taula ? ` · B${m.taula}` : ''}</span>
									{#if m.dataMaximaDisputa}
										<span class={deadlinePillClass(m)} title="Data màxima: {m.dataMaximaDisputa}">màx {formatDeadlineShort(m.dataMaximaDisputa)}</span>
									{/if}
								</div>
							</button>
						{/each}
					</div>
				</div>
			{/each}
		</section>
	{/if}

	{#if showLosers && groupedLosers.length > 0}
		<section class="bracket-section">
			<h3 class="section-title">Bracket de Repesca</h3>
			{#each groupedLosers as group}
				<div class="round-block">
					<h4 class="round-title">{rondaLabel('losers', group.ronda)}</h4>
					<div class="match-grid">
						{#each group.items as m}
							<button
								type="button"
								class="match-cell losers"
								class:is-played={m.estat === 'jugada' || m.estat === 'walkover'}
								class:is-pending={m.estat === 'pendent'}
								class:is-scheduled={m.estat === 'programada'}
								class:is-champion={isChampionMatch(m)}
								class:is-hit={searchHit(m)}
								on:click={() => dispatch('matchclick', m)}
							>
								<div class="cell-head">
									<span class="match-code">{matchCodeMap.get(m.id) ?? '?'}</span>
									<span class="arrows">
										<span class="arrow-win" title="Guanyador va a">↗ {destinationCode(m, 'winner')}</span>
									</span>
								</div>
								<div class="player-row" class:winner={isWinner(m, 1)}>
									<span class="player-name">{playerLabel(m, 1)}</span>
									{#if m.estat === 'jugada' && m.caramboles1 !== null}
										<span class="score">
											{m.caramboles1}{#if m.distancia_jugador1}<span class="dist">/{m.distancia_jugador1}</span>{/if}
										</span>
									{:else if m.distancia_jugador1}
										<span class="dist-tag">{m.distancia_jugador1}c</span>
									{/if}
								</div>
								<div class="player-row" class:winner={isWinner(m, 2)}>
									<span class="player-name">{playerLabel(m, 2)}</span>
									{#if m.estat === 'jugada' && m.caramboles2 !== null}
										<span class="score">
											{m.caramboles2}{#if m.distancia_jugador2}<span class="dist">/{m.distancia_jugador2}</span>{/if}
										</span>
									{:else if m.distancia_jugador2}
										<span class="dist-tag">{m.distancia_jugador2}c</span>
									{/if}
								</div>
								<div class="cell-foot">
									<span class="sched">{m.data_hora ? fmtDataHora(m.data_hora) : '—'}{m.taula ? ` · B${m.taula}` : ''}</span>
									{#if m.dataMaximaDisputa}
										<span class={deadlinePillClass(m)} title="Data màxima: {m.dataMaximaDisputa}">màx {formatDeadlineShort(m.dataMaximaDisputa)}</span>
									{/if}
								</div>
							</button>
						{/each}
					</div>
				</div>
			{/each}
		</section>
	{/if}

	{#if showGF && groupedGF.length > 0}
		<section class="bracket-section">
			<h3 class="section-title">Gran Final</h3>
			{#each groupedGF as group}
				<div class="round-block">
					<h4 class="round-title">{rondaLabel('grand_final', group.ronda)}</h4>
					<div class="match-grid">
						{#each group.items as m}
							<button
								type="button"
								class="match-cell gf"
								class:is-played={m.estat === 'jugada' || m.estat === 'walkover'}
								class:is-pending={m.estat === 'pendent'}
								class:is-scheduled={m.estat === 'programada'}
								class:is-champion={isChampionMatch(m)}
								class:is-hit={searchHit(m)}
								on:click={() => dispatch('matchclick', m)}
							>
								<div class="cell-head">
									<span class="match-code">{matchCodeMap.get(m.id) ?? '?'}</span>
									{#if m.winner_slot_dest_id}
										<span class="arrows">
											<span class="arrow-win">↗ {destinationCode(m, 'winner')}</span>
										</span>
									{/if}
								</div>
								<div class="player-row" class:winner={isWinner(m, 1)}>
									<span class="player-name">{playerLabel(m, 1)}</span>
									{#if m.estat === 'jugada' && m.caramboles1 !== null}
										<span class="score">{m.caramboles1}{#if m.distancia_jugador1}<span class="dist">/{m.distancia_jugador1}</span>{/if}</span>
									{:else if m.distancia_jugador1}
										<span class="dist-tag">{m.distancia_jugador1}c</span>
									{/if}
								</div>
								<div class="player-row" class:winner={isWinner(m, 2)}>
									<span class="player-name">{playerLabel(m, 2)}</span>
									{#if m.estat === 'jugada' && m.caramboles2 !== null}
										<span class="score">{m.caramboles2}{#if m.distancia_jugador2}<span class="dist">/{m.distancia_jugador2}</span>{/if}</span>
									{:else if m.distancia_jugador2}
										<span class="dist-tag">{m.distancia_jugador2}c</span>
									{/if}
								</div>
								<div class="cell-foot">
									<span class="sched">{m.data_hora ? fmtDataHora(m.data_hora) : '—'}{m.taula ? ` · B${m.taula}` : ''}</span>
									{#if m.dataMaximaDisputa}
										<span class={deadlinePillClass(m)} title="Data màxima: {m.dataMaximaDisputa}">màx {formatDeadlineShort(m.dataMaximaDisputa)}</span>
									{/if}
								</div>
							</button>
						{/each}
					</div>
				</div>
			{/each}
		</section>
	{/if}
</div>

<style>
	.hcap-compact-root {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		font-family: var(--font-sans);
		color: var(--ink);
	}
	.bracket-section {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}
	.section-title {
		font-size: 0.6875rem;
		font-weight: 600;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		color: var(--ink-3);
		margin: 0;
	}
	.round-block {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}
	.round-title {
		font-size: 0.75rem;
		font-weight: 700;
		letter-spacing: 0.04em;
		text-transform: uppercase;
		color: var(--ink);
		margin: 0;
		padding-left: 0.5rem;
		border-left: 3px solid var(--ink);
	}
	.match-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
		gap: 0.5rem;
	}
	.match-cell {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		padding: 0.5rem;
		border: 1.5px solid var(--rule-strong);
		background: var(--paper-elevated);
		text-align: left;
		cursor: pointer;
		font-family: var(--font-sans);
		color: var(--ink);
		transition: border-color 0.15s ease, background 0.15s ease;
	}
	.match-cell:hover {
		border-color: var(--ink);
		background: var(--paper);
	}
	.match-cell.losers { border-color: var(--amber); }
	.match-cell.gf { border-color: var(--sec-handicap); }
	.match-cell.is-pending { border-style: dashed; }
	.match-cell.is-played {
		background: var(--paper);
	}
	.match-cell.is-scheduled { background: var(--paper-elevated); }
	.match-cell.is-champion {
		box-shadow: 0 0 0 2px var(--blue) inset;
	}
	.match-cell.is-hit {
		box-shadow: 0 0 0 2px var(--amber) inset;
	}
	.cell-head {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: 0.5rem;
		border-bottom: 1px solid var(--rule);
		padding-bottom: 0.25rem;
	}
	.match-code {
		font-weight: 800;
		font-size: 0.875rem;
		letter-spacing: 0.04em;
	}
	.arrows {
		display: inline-flex;
		gap: 0.5rem;
		font-size: 0.6875rem;
		font-weight: 600;
	}
	.arrow-win { color: var(--green); }
	.arrow-lose { color: var(--accent); }
	.player-row {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: 0.5rem;
		font-size: 0.75rem;
	}
	.player-row.winner { font-weight: 700; }
	.player-row.winner .player-name { color: var(--green); }
	.player-name {
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.score {
		font-weight: 700;
		font-size: 0.75rem;
		white-space: nowrap;
	}
	.score .dist { font-weight: 400; color: var(--ink-soft); }
	.score .pct { font-weight: 400; color: var(--ink-3); margin-left: 0.25rem; }
	.dist-tag {
		font-size: 0.6875rem;
		color: var(--ink-soft);
	}
	.cell-foot {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: 0.5rem;
		border-top: 1px dashed var(--rule);
		padding-top: 0.25rem;
		font-size: 0.6875rem;
		color: var(--ink-soft);
	}
	.sched {
		font-weight: 600;
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	/* Pill de data màxima — mateixos colors que la versió visual */
	:global(.hcap-compact-root .hcap-deadline) {
		display: inline-block;
		font-size: 9px;
		font-weight: 700;
		line-height: 1;
		letter-spacing: 0.02em;
		padding: 1px 4px;
		border: 1px solid currentColor;
		border-radius: 2px;
		white-space: nowrap;
		flex: none;
	}
	:global(.hcap-compact-root .hcap-deadline-safe) {
		color: var(--ink-soft);
		opacity: 0.7;
	}
	:global(.hcap-compact-root .hcap-deadline-soon) {
		color: var(--amber);
		background: rgba(255, 176, 0, 0.08);
	}
	:global(.hcap-compact-root .hcap-deadline-passed) {
		color: var(--accent);
		background: rgba(217, 25, 25, 0.08);
		font-weight: 800;
	}
</style>
