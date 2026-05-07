<script lang="ts">
	import { enhance } from '$app/forms';
	import { page } from '$app/stores';
	import { afterNavigate } from '$app/navigation';
	
	let { form } = $props();
	
	let confirmationText = $state('');
	let isSubmitting = $state(false);
	
	afterNavigate(() => {
		if (form?.success) {
			confirmationText = '';
		}
	});
</script>

<svelte:head>
	<title>Reset del campionat</title>
</svelte:head>

<div class="rc-root">
	<header class="rc-mast">
		<div class="editorial-eyebrow">Operació destructiva</div>
		<h1 class="rc-title">Reset del campionat</h1>
		<p class="rc-sub">Esborra reptes, partides, rànquing i historial del campionat actual.</p>
	</header>

	<div class="rc-card">
		
		<div class="bg-red-50 border-l-4 border-red-400 p-4 mb-6">
			<div class="flex">
				<div class="flex-shrink-0">
					<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
						<path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
					</svg>
				</div>
				<div class="ml-3">
					<h3 class="text-sm font-medium text-red-800">ACCIÓ IRREVERSIBLE</h3>
					<div class="mt-2 text-sm text-red-700">
						<p>Aquesta acció eliminarà TOTES les dades del campionat actual, incloent:</p>
						<ul class="list-disc list-inside mt-2 space-y-1">
							<li>Tots els reptes (proposats, acceptats, jugats)</li>
							<li>Tots els partits i resultats</li>
							<li>Tot l'historial de posicions</li>
							<li>Totes les posicions del rànquing actual</li>
							<li>Totes les penalitzacions</li>
							<li>Tota la llista d'espera</li>
							<li>Tots els esdeveniments del club</li>
							<li>Tot l'historial de notificacions</li>
							<li>Totes les notificacions programades</li>
						</ul>
						<p class="mt-3 font-semibold">Es conservaran NOMÉS:</p>
						<ul class="list-disc list-inside mt-1 space-y-1">
							<li>Dades dels socis</li>
							<li>Mitjanes històriques</li>
							<li>Jugadors (però es reiniciarà el seu estat)</li>
						</ul>
					</div>
				</div>
			</div>
		</div>

		{#if form?.success}
			<div class="bg-green-50 border-l-4 border-green-400 p-4 mb-6">
				<div class="flex">
					<div class="flex-shrink-0">
						<svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
							<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
						</svg>
					</div>
					<div class="ml-3">
						<h3 class="text-sm font-medium text-green-800">Reset completat</h3>
						<div class="mt-2 text-sm text-green-700">
							<p>{form.message}</p>
							{#if form.result}
								<pre class="mt-2 bg-green-100 p-2 rounded text-xs overflow-auto">{JSON.stringify(form.result, null, 2)}</pre>
							{/if}
						</div>
					</div>
				</div>
			</div>
		{/if}

		{#if form?.error}
			<div class="bg-red-50 border-l-4 border-red-400 p-4 mb-6">
				<div class="flex">
					<div class="flex-shrink-0">
						<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
							<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
						</svg>
					</div>
					<div class="ml-3">
						<h3 class="text-sm font-medium text-red-800">Error</h3>
						<div class="mt-2 text-sm text-red-700">
							<p>{form.error}</p>
						</div>
					</div>
				</div>
			</div>
		{/if}

		<form method="POST" action="?/reset" use:enhance={({ submitter }) => {
			isSubmitting = true;
			return async ({ result, update }) => {
				isSubmitting = false;
				await update();
			};
		}}>
			<div class="mb-6">
				<label for="confirmation" class="block text-sm font-medium text-gray-700 mb-2">
					Per confirmar el reset, escriu exactament: <strong>RESET CAMPIONAT</strong>
				</label>
				<input 
					type="text" 
					id="confirmation" 
					name="confirmation" 
					bind:value={confirmationText}
					class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-red-500 focus:border-red-500"
					placeholder="Escriu: RESET CAMPIONAT"
					required
				/>
			</div>
			
			<div class="flex justify-between items-center">
				<a 
					href="/"
					class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 border border-transparent rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
				>
					Cancel·lar
				</a>
				
				<button 
					type="submit"
					disabled={confirmationText !== 'RESET CAMPIONAT' || isSubmitting}
					class="px-6 py-2 text-sm font-medium text-white bg-red-600 border border-transparent rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{#if isSubmitting}
						<svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Executant reset...
					{:else}
						🗑️ EXECUTAR RESET
					{/if}
				</button>
			</div>
		</form>
		
		<div class="mt-8 pt-6 border-t border-gray-200">
			<h3 class="text-lg font-medium text-gray-900 mb-3">Què passarà després del reset?</h3>
			<div class="text-sm text-gray-600 space-y-2">
				<p>1. <strong>Es crearà un nou esdeveniment de campionat</strong> marcat com a actiu</p>
				<p>2. <strong>Tots els jugadors es reiniciaran</strong> amb estat "actiu"</p>
				<p>3. <strong>El rànquing estarà buit</strong> - es podrà configurar un nou rànquing inicial</p>
				<p>4. <strong>No hi haurà cap repte actiu</strong> - es podrà començar de zero</p>
				<p>5. <strong>Es conservaran els socis i mitjanes històriques</strong> per mantenir l'historial</p>
			</div>
		</div>
	</div>
</div>

<style>
	.rc-root {
		max-width: 760px;
		margin: 0 auto;
		padding: 1.75rem 1.25rem 4rem;
		font-family: var(--font-sans, sans-serif);
		color: var(--ink, #1a1814);
	}
	.rc-mast {
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
	.rc-title {
		margin: 0.4rem 0 0.4rem;
		font-size: clamp(1.75rem, 2.4vw, 2.4rem);
		font-weight: 800;
		letter-spacing: -0.022em;
		line-height: 1.1;
		color: var(--accent, #a30b1e);
	}
	.rc-sub {
		margin: 0;
		font-size: 0.9375rem;
		color: var(--ink-2, #4a443e);
		max-width: 56ch;
	}
	.rc-card {
		background: var(--paper-elevated, #fff);
		border: 1px solid var(--accent, #a30b1e);
		padding: 1.5rem;
	}

	.rc-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
	.rc-root :global(.bg-red-50),
	.rc-root :global(.bg-red-100) { background: color-mix(in srgb, var(--accent, #a30b1e) 8%, var(--paper-elevated, #fff)) !important; border-color: var(--accent, #a30b1e) !important; }
	.rc-root :global(.bg-red-600),
	.rc-root :global(.bg-red-700) {
		background: var(--accent, #a30b1e) !important;
		color: var(--paper, #fbfaf6) !important;
	}
	.rc-root :global(.bg-yellow-50),
	.rc-root :global(.bg-yellow-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
	.rc-root :global(.text-red-400),
	.rc-root :global(.text-red-500),
	.rc-root :global(.text-red-600),
	.rc-root :global(.text-red-700),
	.rc-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
	.rc-root :global(.text-yellow-700),
	.rc-root :global(.text-yellow-800) { color: var(--amber, #b8860b) !important; }
	.rc-root :global(.text-gray-500),
	.rc-root :global(.text-gray-600),
	.rc-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
	.rc-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
	.rc-root :global(.border-gray-200),
	.rc-root :global(.border-red-400) { border-color: var(--accent, #a30b1e) !important; }
	.rc-root :global(.rounded),
	.rc-root :global(.rounded-md),
	.rc-root :global(.rounded-lg),
	.rc-root :global(.rounded-full) { border-radius: 0 !important; }
	.rc-root :global(.shadow),
	.rc-root :global(.shadow-sm),
	.rc-root :global(.shadow-md),
	.rc-root :global(.shadow-lg) { box-shadow: none !important; }
	.rc-root :global(input),
	.rc-root :global(textarea) {
		background: var(--paper-elevated, #fff) !important;
		border: 1px solid var(--rule-strong, #b8b3a8) !important;
		border-radius: 0 !important;
		font-family: var(--font-sans, sans-serif);
	}
</style>