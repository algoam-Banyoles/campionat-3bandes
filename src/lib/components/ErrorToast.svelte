<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import type { AppError, ErrorSeverity } from '../errors/types';
	import { getErrorMessage } from '../errors/messages';
	
	export let error: AppError | null = null;
	export let message: string | null = null;
	export let severity: ErrorSeverity = 'error';
	export let autoClose: boolean = true;
	export let duration: number = 5000; // 5 segons per defecte
	export let showDetails: boolean = false;
	export let position: 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left' | 'top-center' = 'top-right';

	const dispatch = createEventDispatcher<{
		close: void;
		retry: void;
		action: string;
	}>();

	let visible = false;
	let timeoutId: NodeJS.Timeout;
	let detailsVisible = false;

	// Configuració d'estils per severitat
	const severityStyles = {
		error: {
			bg: 'bg-red-50 border-red-200',
			text: 'text-red-800',
			icon: '🔴',
			border: 'border-l-red-500'
		},
		warning: {
			bg: 'bg-yellow-50 border-yellow-200',
			text: 'text-yellow-800',
			icon: '⚠️',
			border: 'border-l-yellow-500'
		},
		info: {
			bg: 'bg-blue-50 border-blue-200',
			text: 'text-blue-800',
			icon: 'ℹ️',
			border: 'border-l-blue-500'
		},
		success: {
			bg: 'bg-green-50 border-green-200',
			text: 'text-green-800',
			icon: '✅',
			border: 'border-l-green-500'
		}
	};

	// Configuració de posicions
	const positionStyles = {
		'top-right': 'top-4 right-4',
		'top-left': 'top-4 left-4',
		'bottom-right': 'bottom-4 right-4',
		'bottom-left': 'bottom-4 left-4',
		'top-center': 'top-4 left-1/2 transform -translate-x-1/2'
	};

	$: currentError = error || (message ? { 
		code: 'CUSTOM_MESSAGE' as any,
		message: message,
		userMessage: message,
		severity: severity,
		context: undefined,
		retryable: false
	} as AppError : null);

	$: if (currentError) {
		showToast();
	}

	function showToast() {
		visible = true;
		
		if (autoClose && severity !== 'error') {
			clearTimeout(timeoutId);
			timeoutId = setTimeout(closeToast, duration);
		}
	}

	function closeToast() {
		visible = false;
		clearTimeout(timeoutId);
		setTimeout(() => {
			dispatch('close');
		}, 300); // Esperar animació
	}

	function handleRetry() {
		dispatch('retry');
		closeToast();
	}

	function handleAction(actionType: string) {
		dispatch('action', actionType);
		closeToast();
	}

	function toggleDetails() {
		detailsVisible = !detailsVisible;
	}

	onMount(() => {
		return () => clearTimeout(timeoutId);
	});
</script>

{#if visible && currentError}
	<div
		class="fixed z-50 max-w-md w-full transition-all duration-300 ease-in-out transform {visible ? 'translate-x-0 opacity-100' : 'translate-x-full opacity-0'} {positionStyles[position]}"
		role="alert"
		aria-live="polite"
	>
		<div class="border-l-4 p-4 rounded-lg shadow-lg {severityStyles[currentError.severity].bg} {severityStyles[currentError.severity].border}">
			<!-- Capçalera del toast -->
			<div class="flex items-start">
				<div class="flex-shrink-0 mr-3 text-lg">
					{severityStyles[currentError.severity].icon}
				</div>
				
				<div class="flex-1 min-w-0">
					<!-- Missatge principal -->
					<p class="text-sm font-medium {severityStyles[currentError.severity].text}">
						{currentError.userMessage}
					</p>
					
					<!-- Suggeriment si hi ha -->
					{#if error && error.code && getErrorMessage(error.code as any, error.context?.component).suggestion}
						<p class="text-xs mt-1 {severityStyles[currentError.severity].text} opacity-75">
							{getErrorMessage(error.code as any, error.context?.component).suggestion}
						</p>
					{/if}
					
					<!-- Context adicional per errors crítics -->
					{#if currentError.severity === 'error' && currentError.context?.action}
						<p class="text-xs mt-1 {severityStyles[currentError.severity].text} opacity-60">
							Acció: {currentError.context.action}
						</p>
					{/if}
				</div>
				
				<!-- Botó tancar -->
				<button
					on:click={closeToast}
					class="ml-2 flex-shrink-0 text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
					aria-label="Tancar notificació"
				>
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
					</svg>
				</button>
			</div>
			
			<!-- Botons d'acció -->
			{#if currentError.retryable || error}
				<div class="mt-3 flex flex-wrap gap-2">
					{#if currentError.retryable}
						<button
							on:click={handleRetry}
							class="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
						>
							🔄 Tornar a intentar
						</button>
					{/if}
					
					{#if error && error.code && getErrorMessage(error.code as any, error.context?.component).action}
						<button
							on:click={() => handleAction(getErrorMessage(error.code as any, error.context?.component).action || 'action')}
							class="inline-flex items-center px-3 py-1 border border-gray-300 text-xs font-medium rounded-md {severityStyles[currentError.severity].text} bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
						>
							{getErrorMessage(error.code as any, error.context?.component).action}
						</button>
					{/if}
					
					{#if showDetails && error}
						<button
							on:click={toggleDetails}
							class="inline-flex items-center px-2 py-1 text-xs {severityStyles[currentError.severity].text} opacity-60 hover:opacity-80 transition-opacity"
						>
							{detailsVisible ? '🔼' : '🔽'} Detalls
						</button>
					{/if}
				</div>
			{/if}
			
			<!-- Detalls tècnics (només si es demana) -->
			{#if detailsVisible && error}
				<div class="mt-3 p-2 bg-gray-100 rounded text-xs font-mono">
					<div><strong>Codi:</strong> {error.code}</div>
					{#if error.context?.timestamp}
						<div><strong>Timestamp:</strong> {new Date(error.context.timestamp).toLocaleString('ca-ES')}</div>
					{/if}
					{#if error.context?.page}
						<div><strong>Pàgina:</strong> {error.context.page}</div>
					{/if}
					{#if error.message && error.message !== error.userMessage}
						<div><strong>Missatge tècnic:</strong> {error.message}</div>
					{/if}
				</div>
			{/if}
			
			<!-- Barra de progrés per auto-close -->
			{#if autoClose && severity !== 'error' && visible}
				<div class="absolute bottom-0 left-0 h-1 bg-gray-200 w-full rounded-b-lg overflow-hidden">
					<div 
						class="h-full bg-gray-400 transition-all ease-linear"
						style="width: 100%; animation: progress-bar {duration}ms linear forwards;"
					></div>
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	@keyframes progress-bar {
		from {
			width: 100%;
		}
		to {
			width: 0%;
		}
	}
</style>