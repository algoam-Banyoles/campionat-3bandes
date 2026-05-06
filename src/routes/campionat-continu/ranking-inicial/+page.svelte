<script lang="ts">
	import CrearRanquingInicial from '$lib/components/admin/CrearRanquingInicial.svelte';
	import { goto } from '$app/navigation';
	import { adminChecked, isAdmin } from '$lib/stores/adminAuth';

	// Guard: només admins.
	$: if ($adminChecked && !$isAdmin) {
		goto('/campionat-continu/ranking');
	}
</script>

<svelte:head>
	<title>Crear Rànquing Inicial</title>
</svelte:head>

<div class="ri-root">
	<header class="ri-mast">
		<button class="ri-back" on:click={() => goto('/campionat-continu/ranking')}>
			← Tornar a la classificació
		</button>
		<div class="editorial-eyebrow">Foment Martinenc · Secció billar</div>
		<h1 class="ri-title">Crear rànquing inicial</h1>
		<p class="ri-sub">
			Configura el rànquing inicial del campionat continu seleccionant 20 jugadors
			a partir de les seves mitjanes històriques.
		</p>
	</header>

	<div class="ri-body">
		<CrearRanquingInicial />
	</div>
</div>

<style>
	.ri-root {
		max-width: 1180px;
		margin: 0 auto;
		padding: 1.75rem 1.25rem 4rem;
		font-family: var(--font-sans, sans-serif);
		color: var(--ink, #1a1814);
	}
	.ri-mast {
		margin-bottom: 1.75rem;
		padding-bottom: 1.1rem;
		border-bottom: 2px solid var(--ink, #1a1814);
	}
	.ri-back {
		display: inline-block;
		background: transparent;
		border: none;
		padding: 0;
		color: var(--ink-2, #4a443e);
		font-family: var(--font-sans, sans-serif);
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		margin-bottom: 0.5rem;
	}
	.ri-back:hover { color: var(--ink, #1a1814); }
	.editorial-eyebrow {
		font-size: 0.625rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.16em;
		color: var(--ink-3, #807a72);
	}
	.ri-title {
		margin: 0.4rem 0 0.4rem;
		font-size: clamp(1.75rem, 2.4vw, 2.4rem);
		font-weight: 800;
		letter-spacing: -0.022em;
		line-height: 1.1;
	}
	.ri-sub {
		margin: 0;
		font-size: 0.9375rem;
		color: var(--ink-2, #4a443e);
		max-width: 56ch;
	}

	.ri-body :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
	.ri-body :global(.bg-gray-50),
	.ri-body :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
	.ri-body :global(.shadow),
	.ri-body :global(.shadow-sm),
	.ri-body :global(.shadow-md) { box-shadow: none !important; }
	.ri-body :global(.rounded),
	.ri-body :global(.rounded-sm),
	.ri-body :global(.rounded-md),
	.ri-body :global(.rounded-lg),
	.ri-body :global(.rounded-xl),
	.ri-body :global(.rounded-2xl),
	.ri-body :global(.rounded-full) { border-radius: 0 !important; }
	.ri-body :global(.border-gray-200),
	.ri-body :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
</style>