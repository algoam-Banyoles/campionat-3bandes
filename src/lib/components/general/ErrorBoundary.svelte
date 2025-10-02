<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import type { AppError } from '../../errors/types';
	import { handleError } from '../../errors/handler';
	import { logError } from '../../errors/sentry';

	export let fallback: boolean = true;
	export let showReload: boolean = true;
	export let showDetails: boolean = false;
	export let customFallback: string | null = null;

	const dispatch = createEventDispatcher<{
		error: AppError;
		recovered: void;
	}>();

	let error: AppError | null = null;
	let detailsVisible = false;
	let retryCount = 0;
	let maxRetries = 3;

	// Gestionar errors globals no capturats
	function handleGlobalError(event: ErrorEvent) {
		const appError = handleError(event.error, 'UNKNOWN_ERROR', {
			page: window.location.pathname,
			action: 'global_error',
			data: {
				filename: event.filename,
				lineno: event.lineno,
				colno: event.colno
			}
		});

		setError(appError);
		event.preventDefault();
	}

	// Gestionar promises rejected no capturades
	function handleUnhandledRejection(event: PromiseRejectionEvent) {
		const appError = handleError(event.reason, 'UNKNOWN_ERROR', {
			page: window.location.pathname,
			action: 'unhandled_promise_rejection'
		});

		setError(appError);
		event.preventDefault();
	}

	function setError(appError: AppError) {
		error = appError;
		logError(appError);
		dispatch('error', appError);
	}

	function clearError() {
		error = null;
		retryCount = 0;
		dispatch('recovered');
	}

	function reloadPage() {
		window.location.reload();
	}

	function retryOperation() {
		if (retryCount < maxRetries) {
			retryCount++;
			clearError();
		}
	}

	function toggleDetails() {
		detailsVisible = !detailsVisible;
	}

	function goHome() {
		window.location.href = '/';
	}

	onMount(() => {
		// Registrar listeners per errors globals
		window.addEventListener('error', handleGlobalError);
		window.addEventListener('unhandledrejection', handleUnhandledRejection);

		return () => {
			window.removeEventListener('error', handleGlobalError);
			window.removeEventListener('unhandledrejection', handleUnhandledRejection);
		};
	});

	// Funció per ser cridada per components fills
	export function catchError(err: unknown, context?: string) {
		const appError = handleError(err, 'UNKNOWN_ERROR', {
			page: window.location.pathname,
			component: context,
			action: 'component_error'
		});
		setError(appError);
	}
</script>

{#if error && fallback}
	<!-- Error Boundary UI -->
	<div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
		<div class="sm:mx-auto sm:w-full sm:max-w-md">
			<div class="text-center">
				<div class="text-6xl mb-4">🚫</div>
				<h1 class="text-2xl font-bold text-gray-900 mb-2">
					Ooops! Alguna cosa ha anat malament
				</h1>
				<p class="text-gray-600 mb-6">
					{error.userMessage}
				</p>
			</div>
		</div>

		<div class="sm:mx-auto sm:w-full sm:max-w-md">
			<div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
				
				{#if customFallback}
					<!-- Contingut personalitzat -->
					<div class="prose prose-sm max-w-none">
						{@html customFallback}
					</div>
				{:else}
					<!-- Contingut per defecte -->
					<div class="space-y-4">
						<div class="bg-red-50 border border-red-200 rounded-md p-4">
							<div class="flex">
								<div class="flex-shrink-0">
									<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
										<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
									</svg>
								</div>
								<div class="ml-3">
									<h3 class="text-sm font-medium text-red-800">
										Error del sistema
									</h3>
									<div class="mt-2 text-sm text-red-700">
										<p>S'ha produït un error inesperat que ha impedit que l'aplicació funcioni correctament.</p>
									</div>
								</div>
							</div>
						</div>

						<!-- Informació de l'error -->
						<div class="bg-gray-50 rounded-md p-4">
							<h4 class="text-sm font-medium text-gray-900 mb-2">Què puc fer?</h4>
							<ul class="text-sm text-gray-600 space-y-1">
								<li>• Torna-ho a intentar - pot ser un error temporal</li>
								<li>• Recarrega la pàgina per reiniciar l'aplicació</li>
								<li>• Si el problema persisteix, contacta amb suport</li>
							</ul>
						</div>

						<!-- Detalls tècnics -->
						{#if showDetails}
							<div class="border-t pt-4">
								<button
									on:click={toggleDetails}
									class="text-sm text-gray-500 hover:text-gray-700 flex items-center"
								>
									{detailsVisible ? '🔼' : '🔽'} Detalls tècnics
								</button>
								
								{#if detailsVisible}
									<div class="mt-3 p-3 bg-gray-100 rounded-md text-xs font-mono space-y-2">
										<div><strong>Codi d'error:</strong> {error.code}</div>
										<div><strong>Severitat:</strong> {error.severity}</div>
										{#if error.context?.timestamp}
											<div><strong>Quan:</strong> {new Date(error.context.timestamp).toLocaleString('ca-ES')}</div>
										{/if}
										{#if error.context?.page}
											<div><strong>Pàgina:</strong> {error.context.page}</div>
										{/if}
										{#if error.context?.component}
											<div><strong>Component:</strong> {error.context.component}</div>
										{/if}
										{#if error.context?.action}
											<div><strong>Acció:</strong> {error.context.action}</div>
										{/if}
										{#if error.message && error.message !== error.userMessage}
											<div><strong>Missatge tècnic:</strong> {error.message}</div>
										{/if}
										{#if error.stack}
											<details>
												<summary class="cursor-pointer font-bold">Stack trace</summary>
												<pre class="mt-2 text-xs overflow-x-auto">{error.stack}</pre>
											</details>
										{/if}
									</div>
								{/if}
							</div>
						{/if}
					</div>
				{/if}
				
				<!-- Botons d'acció -->
				<div class="mt-6 flex flex-col space-y-3">
					{#if error.retryable && retryCount < maxRetries}
						<button
							on:click={retryOperation}
							class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
						>
							🔄 Tornar a intentar {retryCount > 0 ? `(${retryCount}/${maxRetries})` : ''}
						</button>
					{/if}
					
					{#if showReload}
						<button
							on:click={reloadPage}
							class="w-full flex justify-center py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
						>
							↻ Recarregar pàgina
						</button>
					{/if}
					
					<button
						on:click={goHome}
						class="w-full flex justify-center py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
					>
						🏠 Anar a l'inici
					</button>
					
					<button
						on:click={clearError}
						class="w-full flex justify-center py-2 px-4 text-sm font-medium text-gray-500 hover:text-gray-700 transition-colors"
					>
						Continuar malgrat l'error
					</button>
				</div>
				
				<!-- Informació de contacte -->
				<div class="mt-6 text-center">
					<p class="text-xs text-gray-500">
						Si el problema persisteix, contacta amb 
						<a href="mailto:suport@campionat3bandes.cat" class="text-indigo-600 hover:text-indigo-500">
							suport tècnic
						</a>
					</p>
				</div>
			</div>
		</div>
	</div>
{:else if !error}
	<!-- Render contingut normal si no hi ha error -->
	<slot />
{/if}