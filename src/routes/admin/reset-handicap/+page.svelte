<script lang="ts">
	import { enhance } from '$app/forms';

	let { data, form } = $props();

	let confirmingId = $state<string | null>(null);
	let confirmationText = $state('');
	let isSubmitting = $state(false);

	function startConfirm(id: string) {
		confirmingId = id;
		confirmationText = '';
	}
	function cancelConfirm() {
		confirmingId = null;
		confirmationText = '';
	}

	function estatLabel(estat: string | null): string {
		switch (estat) {
			case 'planificacio': return 'Planificació';
			case 'inscripcions': return 'Inscripcions';
			case 'en_curs': return 'En curs';
			case 'finalitzat': return 'Finalitzat';
			default: return estat ?? '—';
		}
	}
</script>

<svelte:head>
	<title>Reset hàndicap</title>
</svelte:head>

<div class="rh-root">
	<header class="rh-mast">
		<div class="editorial-eyebrow">Operació destructiva</div>
		<h1 class="rh-title">Reset hàndicap</h1>
		<p class="rh-sub">
			Esborra completament un event hàndicap i totes les seves dades (config, participants, bracket, partides, calendari).
			Els events finalitzats queden protegits com a històric i no es poden esborrar des d'aquí.
		</p>
	</header>

	<div class="bg-red-50 border-l-4 border-red-400 p-4 mb-6">
		<h3 class="text-sm font-semibold text-red-800 mb-1">ACCIÓ IRREVERSIBLE</h3>
		<p class="text-sm text-red-700">
			Esborra l'event seleccionat, la seva configuració hàndicap, els participants inscrits,
			tota l'estructura del bracket, les partides hàndicap i les corresponents entrades a
			<code>calendari_partides</code>. No es pot desfer.
		</p>
		<p class="text-sm text-red-700 mt-2">
			Els events <strong>finalitzats</strong> es preserven sempre com a històric (apareixen a la secció
			<em>"Torneigs anteriors"</em> del dashboard hàndicap).
		</p>
	</div>

	{#if form?.success}
		<div class="bg-green-50 border-l-4 border-green-400 p-4 mb-6">
			<h3 class="text-sm font-semibold text-green-800">Esborrat completat</h3>
			<p class="text-sm text-green-700">{form.message}</p>
			{#if form.result}
				<pre class="mt-2 bg-green-100 p-2 text-xs overflow-auto">{JSON.stringify(form.result, null, 2)}</pre>
			{/if}
		</div>
	{/if}

	{#if form?.error}
		<div class="bg-red-50 border-l-4 border-red-400 p-4 mb-6">
			<h3 class="text-sm font-semibold text-red-800">Error</h3>
			<p class="text-sm text-red-700">{form.error}</p>
		</div>
	{/if}

	{#if data.events.length === 0}
		<div class="rh-empty">
			<p>No hi ha cap event hàndicap a la base de dades.</p>
			<a href="/admin/events/nou" class="rh-link">Crear-ne un de nou →</a>
		</div>
	{:else}
		<div class="rh-list">
			{#each data.events as ev}
				{@const isFinalitzat = ev.estat_competicio === 'finalitzat'}
				{@const isConfirming = confirmingId === ev.id}
				<article class="rh-card" class:rh-card-protected={isFinalitzat}>
					<header class="rh-card-head">
						<h3 class="rh-card-title">{ev.nom}</h3>
						<div class="rh-card-meta">
							{#if ev.temporada}<span>{ev.temporada}</span>{/if}
							<span class="rh-estat" class:rh-estat-final={isFinalitzat}>{estatLabel(ev.estat_competicio)}</span>
						</div>
					</header>

					<dl class="rh-stats">
						<div><dt>Participants</dt><dd>{ev.participants}</dd></div>
						<div><dt>Partides</dt><dd>{ev.matches}</dd></div>
						<div><dt>Partides jugades</dt><dd>{ev.matches_jugats}</dd></div>
					</dl>

					{#if isFinalitzat}
						<div class="rh-protected-badge">
							🛡️ Històric protegit — no es pot esborrar
						</div>
					{:else if isConfirming}
						<form
							method="POST"
							action="?/deleteEvent"
							use:enhance={() => {
								isSubmitting = true;
								return async ({ update }) => {
									isSubmitting = false;
									await update();
									confirmingId = null;
									confirmationText = '';
								};
							}}
							class="rh-confirm"
						>
							<input type="hidden" name="event_id" value={ev.id} />
							<label for="confirmation-{ev.id}" class="rh-confirm-label">
								Escriu exactament <strong>ESBORRAR</strong> per confirmar:
							</label>
							<div class="rh-confirm-row">
								<input
									type="text"
									id="confirmation-{ev.id}"
									name="confirmation"
									bind:value={confirmationText}
									placeholder="ESBORRAR"
									autocomplete="off"
									required
								/>
								<button
									type="submit"
									class="rh-btn rh-btn-danger"
									disabled={confirmationText !== 'ESBORRAR' || isSubmitting}
								>
									{isSubmitting ? 'Esborrant…' : '🗑️ Confirmar esborrat'}
								</button>
								<button type="button" class="rh-btn rh-btn-secondary" onclick={cancelConfirm}>
									Cancel·lar
								</button>
							</div>
						</form>
					{:else}
						<button
							type="button"
							class="rh-btn rh-btn-danger"
							onclick={() => startConfirm(ev.id)}
						>
							🗑️ Esborrar event i totes les dades
						</button>
					{/if}
				</article>
			{/each}
		</div>
	{/if}

	<div class="rh-back">
		<a href="/admin">← Tornar al dashboard d'admin</a>
	</div>
</div>

<style>
	.rh-root {
		max-width: 880px;
		margin: 0 auto;
		padding: 1.75rem 1.25rem 4rem;
		font-family: var(--font-sans, sans-serif);
		color: var(--ink, #1a1814);
	}
	.rh-mast {
		margin-bottom: 1.5rem;
		padding-bottom: 1.1rem;
		border-bottom: 2px solid var(--accent, #a30b1e);
	}
	.editorial-eyebrow {
		font-size: 0.625rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.16em;
		color: var(--accent, #a30b1e);
	}
	.rh-title {
		margin: 0.4rem 0 0.4rem;
		font-size: clamp(1.75rem, 2.4vw, 2.4rem);
		font-weight: 800;
		letter-spacing: -0.022em;
		line-height: 1.1;
		color: var(--accent, #a30b1e);
	}
	.rh-sub {
		margin: 0;
		font-size: 0.9375rem;
		color: var(--ink-2, #4a443e);
		max-width: 62ch;
	}
	.rh-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	.rh-card {
		background: var(--paper-elevated, #fff);
		border: 1px solid var(--rule, #d6d2c8);
		padding: 1.1rem 1.25rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}
	.rh-card-protected {
		border-color: var(--rule, #d6d2c8);
		background: var(--paper, #fbfaf6);
	}
	.rh-card-head {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem 1rem;
		justify-content: space-between;
		align-items: baseline;
	}
	.rh-card-title {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 700;
		color: var(--ink, #1a1814);
	}
	.rh-card-meta {
		display: flex;
		gap: 0.75rem;
		font-size: 0.8125rem;
		color: var(--ink-2, #4a443e);
	}
	.rh-estat {
		text-transform: uppercase;
		letter-spacing: 0.08em;
		font-weight: 600;
		font-size: 0.75rem;
	}
	.rh-estat-final {
		color: var(--green, #15803d);
	}
	.rh-stats {
		display: flex;
		gap: 1.5rem;
		margin: 0;
		flex-wrap: wrap;
	}
	.rh-stats div { display: flex; flex-direction: column; gap: 0.1rem; }
	.rh-stats dt {
		font-size: 0.75rem;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: var(--ink-3, #6b6357);
	}
	.rh-stats dd {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 700;
		color: var(--ink, #1a1814);
	}
	.rh-protected-badge {
		font-size: 0.875rem;
		color: var(--green, #15803d);
		font-weight: 600;
		padding: 0.5rem 0.75rem;
		background: color-mix(in srgb, var(--green, #15803d) 8%, var(--paper-elevated, #fff));
		border: 1px solid var(--green, #15803d);
	}
	.rh-confirm {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 0.75rem;
		background: color-mix(in srgb, var(--accent, #a30b1e) 6%, var(--paper-elevated, #fff));
		border: 1px solid var(--accent, #a30b1e);
	}
	.rh-confirm-label {
		font-size: 0.875rem;
		color: var(--accent, #a30b1e);
	}
	.rh-confirm-row {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		align-items: center;
	}
	.rh-confirm-row input {
		flex: 1 1 200px;
		padding: 0.5rem 0.75rem;
		border: 1px solid var(--rule-strong, #b8b3a8);
		background: var(--paper-elevated, #fff);
		font-family: var(--font-sans, sans-serif);
		font-size: 0.9375rem;
	}
	.rh-btn {
		padding: 0.55rem 1rem;
		font-size: 0.875rem;
		font-weight: 600;
		border: 1px solid transparent;
		cursor: pointer;
		font-family: var(--font-sans, sans-serif);
	}
	.rh-btn-danger {
		background: var(--accent, #a30b1e);
		color: var(--paper, #fbfaf6);
		border-color: var(--accent, #a30b1e);
	}
	.rh-btn-danger:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	.rh-btn-secondary {
		background: var(--paper-elevated, #fff);
		color: var(--ink, #1a1814);
		border-color: var(--rule-strong, #b8b3a8);
	}
	.rh-empty {
		padding: 1.5rem;
		border: 1px dashed var(--rule, #d6d2c8);
		background: var(--paper, #fbfaf6);
		text-align: center;
		color: var(--ink-2, #4a443e);
	}
	.rh-link, .rh-back a {
		color: var(--blue, #1d4ed8);
		text-decoration: underline;
	}
	.rh-back {
		margin-top: 2rem;
		font-size: 0.875rem;
	}

	/* Tailwind overrides (coherent amb la resta del repo) */
	.rh-root :global(.bg-red-50),
	.rh-root :global(.bg-red-100) {
		background: color-mix(in srgb, var(--accent, #a30b1e) 8%, var(--paper-elevated, #fff)) !important;
		border-color: var(--accent, #a30b1e) !important;
	}
	.rh-root :global(.bg-green-50),
	.rh-root :global(.bg-green-100) {
		background: color-mix(in srgb, var(--green, #15803d) 8%, var(--paper-elevated, #fff)) !important;
		border-color: var(--green, #15803d) !important;
	}
	.rh-root :global(.text-red-700),
	.rh-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
	.rh-root :global(.text-green-700),
	.rh-root :global(.text-green-800) { color: var(--green, #15803d) !important; }
	.rh-root :global(.rounded),
	.rh-root :global(.rounded-md),
	.rh-root :global(.rounded-lg) { border-radius: 0 !important; }
	.rh-root :global(.shadow),
	.rh-root :global(.shadow-sm),
	.rh-root :global(.shadow-md) { box-shadow: none !important; }
</style>
