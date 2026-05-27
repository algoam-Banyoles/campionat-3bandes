<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import { adminChecked } from '$lib/stores/adminAuth';
	import { effectiveIsAdmin } from '$lib/stores/viewMode';
	import { loadSimulationState, type SimulationState } from '$lib/utils/handicap-simulation-state';
	import {
		simulateTournamentEnd,
		aggregateSimulations,
		type SimulationResult,
		type SimulationAggregate
	} from '$lib/utils/handicap-simulation';
	import HandicapSimulationChart from '$lib/components/handicap/HandicapSimulationChart.svelte';

	$: if ($adminChecked && !$effectiveIsAdmin) goto('/handicap');

	let loading = true;
	let error: string | null = null;
	let state: SimulationState | null = null;

	let numSims = 500;
	let running = false;
	let progress = 0; // 0..100
	let aggregate: SimulationAggregate | null = null;
	let durationMs = 0;
	let copyStatus = '';

	$: pendingMatches = state
		? state.matches.filter((m) => m.estat === 'pendent' || m.estat === 'programada').length
		: 0;
	$: bracketReady = state ? state.matches.length > 0 : false;
	$: isFinalitzat = state?.estatCompeticio === 'finalitzat';

	onMount(async () => {
		try {
			state = await loadSimulationState(supabase);
		} catch (e: any) {
			error = e?.message ?? String(e);
		} finally {
			loading = false;
		}
	});

	async function runSimulation() {
		if (!state || running) return;
		running = true;
		progress = 0;
		aggregate = null;
		copyStatus = '';

		const t0 = performance.now();
		const results: SimulationResult[] = [];
		const batchSize = 25;
		const total = numSims;

		try {
			for (let i = 0; i < total; i += batchSize) {
				const end = Math.min(i + batchSize, total);
				for (let j = i; j < end; j++) {
					results.push(simulateTournamentEnd(state));
				}
				progress = Math.round((end / total) * 100);
				// Cede el UI thread cada batch
				await new Promise((r) => setTimeout(r, 0));
			}
			aggregate = aggregateSimulations(results, state.config.data_fi);
			durationMs = Math.round(performance.now() - t0);
		} catch (e: any) {
			error = e?.message ?? String(e);
		} finally {
			running = false;
		}
	}

	async function copyResum() {
		if (!aggregate) return;
		const lines = [
			`Simulació Monte Carlo — torneig hàndicap`,
			`N=${aggregate.dates.length} simulacions (${aggregate.failedSims} fallades)`,
			`Mediana (P50): ${aggregate.p50}`,
			`Optimista (P10): ${aggregate.p10}`,
			`Pessimista (P90): ${aggregate.p90}`,
			`Mitjana: ${aggregate.mean} (±${aggregate.stdDevDays?.toFixed(1)} dies)`,
			`Rang: ${aggregate.minDate} a ${aggregate.maxDate}`,
			`% dins data fi prevista (${state?.config.data_fi}): ${(aggregate.withinDataFiPct! * 100).toFixed(1)}%`,
			`% reset match: ${(aggregate.resetMatchRate * 100).toFixed(1)}%`,
			`Duració: ${durationMs}ms`
		];
		try {
			await navigator.clipboard.writeText(lines.join('\n'));
			copyStatus = 'Copiat!';
			setTimeout(() => (copyStatus = ''), 2000);
		} catch {
			copyStatus = 'Error en copiar';
		}
	}

	function formatDateDM(s: string | null): string {
		if (!s) return '—';
		const [, m, d] = s.split('-');
		return `${d}/${m}`;
	}

	function formatDateLong(s: string | null): string {
		if (!s) return '—';
		const [y, m, d] = s.split('-');
		const dies = ['Diumenge', 'Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte'];
		const mesos = ['gener', 'febrer', 'març', 'abril', 'maig', 'juny', 'juliol', 'agost', 'setembre', 'octubre', 'novembre', 'desembre'];
		const date = new Date(parseInt(y), parseInt(m) - 1, parseInt(d));
		return `${dies[date.getDay()]} ${parseInt(d)} de ${mesos[parseInt(m) - 1]} de ${y}`;
	}
</script>

<svelte:head>
	<title>Simulació — Hàndicap</title>
</svelte:head>

<div class="hcap-page-root">
	<header class="page-mast">
		<div class="editorial-eyebrow">
			<a href="/handicap" class="back-link">← Hàndicap</a>
		</div>
		<h1 class="page-title">Simulació Monte Carlo</h1>
		<p class="page-lede">
			Predicció de la data de finalització del torneig a partir de N simulacions aleatòries.
			Es respecten les disponibilitats declarades de cada participant; quan dos jugadors han de jugar
			i tenen restriccions 100% incompatibles, es tira moneda per decidir quina disponibilitat preval
			puntualment.
		</p>
	</header>

	{#if loading}
		<div class="msg">Carregant estat del torneig...</div>
	{:else if error}
		<div class="msg err">Error: {error}</div>
	{:else if !state}
		<div class="msg">No hi ha cap torneig hàndicap actiu.</div>
	{:else if !bracketReady}
		<div class="msg">
			Cal generar el bracket abans de simular.
			<a href="/handicap/sorteig">Anar al sorteig →</a>
		</div>
	{:else if isFinalitzat}
		<div class="msg">
			El torneig ja està finalitzat. No té sentit simular dates de finalització.
		</div>
	{:else}
		<section class="block">
			<h2 class="block-title">Paràmetres</h2>
			<div class="param-grid">
				<div>
					<label for="numsims">Nombre de simulacions</label>
					<select id="numsims" bind:value={numSims} disabled={running}>
						<option value={100}>100 (ràpid)</option>
						<option value={250}>250</option>
						<option value={500}>500 (recomanat)</option>
						<option value={1000}>1000</option>
						<option value={2000}>2000 (lent)</option>
					</select>
				</div>
				<div>
					<div class="param-label">Partides pendents</div>
					<div class="param-value">{pendingMatches}</div>
				</div>
				<div>
					<div class="param-label">Període configurat</div>
					<div class="param-value">{state.config.data_inici} → {state.config.data_fi}</div>
				</div>
			</div>

			<div class="actions">
				<button class="btn-primary" disabled={running} on:click={runSimulation}>
					{#if running}
						Simulant... {progress}%
					{:else if aggregate}
						Re-simular
					{:else}
						Executar simulació
					{/if}
				</button>
				{#if aggregate}
					<button class="btn-secondary" on:click={copyResum} disabled={running}>
						{copyStatus || 'Copiar resum'}
					</button>
				{/if}
			</div>

			{#if running}
				<div class="progress">
					<div class="progress-bar" style="width: {progress}%"></div>
				</div>
			{/if}
		</section>

		{#if aggregate}
			<section class="block">
				<h2 class="block-title">Resultat</h2>

				<div class="kpis">
					<div class="kpi">
						<div class="kpi-label">Mediana (P50)</div>
						<div class="kpi-value primary">{formatDateDM(aggregate.p50)}</div>
						<div class="kpi-sub">{formatDateLong(aggregate.p50)}</div>
					</div>
					<div class="kpi">
						<div class="kpi-label">Optimista (P10)</div>
						<div class="kpi-value good">{formatDateDM(aggregate.p10)}</div>
						<div class="kpi-sub">{formatDateLong(aggregate.p10)}</div>
					</div>
					<div class="kpi">
						<div class="kpi-label">Pessimista (P90)</div>
						<div class="kpi-value warn">{formatDateDM(aggregate.p90)}</div>
						<div class="kpi-sub">{formatDateLong(aggregate.p90)}</div>
					</div>
					<div class="kpi">
						<div class="kpi-label">Mitjana</div>
						<div class="kpi-value">{formatDateDM(aggregate.mean)}</div>
						<div class="kpi-sub">±{aggregate.stdDevDays?.toFixed(1)} dies</div>
					</div>
					<div class="kpi">
						<div class="kpi-label">Dins data fi</div>
						<div class="kpi-value" class:warn={(aggregate.withinDataFiPct ?? 0) < 0.5}>
							{((aggregate.withinDataFiPct ?? 0) * 100).toFixed(1)}%
						</div>
						<div class="kpi-sub">de {aggregate.dates.length} sims</div>
					</div>
					<div class="kpi">
						<div class="kpi-label">Reset match (GF2)</div>
						<div class="kpi-value">{(aggregate.resetMatchRate * 100).toFixed(1)}%</div>
						<div class="kpi-sub">probabilitat</div>
					</div>
				</div>

				<HandicapSimulationChart
					dates={aggregate.dates}
					dataFi={state.config.data_fi}
					p10={aggregate.p10}
					p50={aggregate.p50}
					p90={aggregate.p90}
				/>

				{#if aggregate.failedSims > 0}
					<div class="msg warn-msg">
						⚠️ {aggregate.failedSims} simulacions no han pogut finalitzar dins els límits
						(disponibilitats massa restrictives o període insuficient).
					</div>
				{/if}

				<div class="meta">
					{aggregate.dates.length} simulacions executades en {durationMs}ms.
				</div>
			</section>
		{/if}
	{/if}
</div>

<style>
	.hcap-page-root {
		max-width: 56rem; margin: 0 auto; padding: 1rem;
		display: flex; flex-direction: column; gap: 1.25rem;
		font-family: var(--font-sans); color: var(--ink);
	}
	.page-mast { padding-bottom: 1rem; border-bottom: 2px solid var(--ink); }
	.editorial-eyebrow {
		font-size: 0.75rem; font-weight: 600;
		letter-spacing: 0.16em; text-transform: uppercase;
		color: var(--sec-handicap);
	}
	.back-link { color: var(--sec-handicap); text-decoration: none; }
	.back-link:hover { color: var(--ink); }
	.page-title {
		font-weight: 800; font-size: 2rem;
		letter-spacing: -0.025em; margin: 0; color: var(--ink);
	}
	.page-lede {
		margin-top: 0.5rem; color: var(--ink-2);
		font-size: 0.95rem; max-width: 50rem;
	}

	.block {
		background: var(--paper-elevated);
		border: 1px solid var(--rule);
		padding: 1rem 1.25rem;
		display: flex; flex-direction: column; gap: 1rem;
	}
	.block-title {
		font-size: 1.1rem; font-weight: 700;
		margin: 0; color: var(--ink);
		border-bottom: 1px solid var(--rule);
		padding-bottom: 0.5rem;
	}

	.param-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: 1rem;
	}
	.param-grid label {
		display: block;
		font-size: 0.85rem;
		color: var(--ink-2);
		margin-bottom: 0.35rem;
	}
	.param-grid select {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid var(--rule-strong);
		background: var(--paper);
		color: var(--ink);
		font-size: 0.95rem;
	}
	.param-label {
		font-size: 0.85rem;
		color: var(--ink-2);
	}
	.param-value {
		font-size: 1.05rem;
		font-weight: 600;
		color: var(--ink);
		margin-top: 0.35rem;
	}

	.actions { display: flex; gap: 0.75rem; flex-wrap: wrap; }
	.btn-primary {
		background: var(--sec-handicap);
		color: white;
		border: 1px solid var(--sec-handicap);
		padding: 0.6rem 1.1rem;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
	}
	.btn-primary:disabled {
		opacity: 0.6; cursor: not-allowed;
	}
	.btn-secondary {
		background: var(--paper);
		color: var(--ink);
		border: 1px solid var(--ink);
		padding: 0.6rem 1.1rem;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
	}
	.btn-secondary:disabled {
		opacity: 0.6; cursor: not-allowed;
	}

	.progress {
		width: 100%;
		height: 8px;
		background: var(--rule);
		overflow: hidden;
	}
	.progress-bar {
		height: 100%;
		background: var(--sec-handicap);
		transition: width 0.2s;
	}

	.kpis {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
		gap: 0.75rem;
	}
	.kpi {
		border: 1px solid var(--rule);
		padding: 0.75rem;
		background: var(--paper);
		display: flex; flex-direction: column; gap: 0.25rem;
	}
	.kpi-label {
		font-size: 0.75rem;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: var(--ink-2);
		font-weight: 600;
	}
	.kpi-value {
		font-size: 1.4rem;
		font-weight: 700;
		color: var(--ink);
		font-variant-numeric: tabular-nums;
	}
	.kpi-value.primary { color: var(--sec-handicap); }
	.kpi-value.good { color: var(--green); }
	.kpi-value.warn { color: var(--accent); }
	.kpi-sub {
		font-size: 0.75rem;
		color: var(--ink-2);
	}

	.msg {
		padding: 1rem;
		background: var(--paper-elevated);
		border: 1px solid var(--rule);
		color: var(--ink-2);
		text-align: center;
	}
	.msg.err { border-color: var(--accent); color: var(--accent); }
	.msg.warn-msg { border-color: var(--amber); color: var(--amber); }
	.msg a { color: var(--sec-handicap); text-decoration: underline; }

	.meta {
		font-size: 0.8rem;
		color: var(--ink-2);
		text-align: right;
	}
</style>
