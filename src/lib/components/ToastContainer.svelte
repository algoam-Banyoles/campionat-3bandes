<script lang="ts">
	import { toastStore } from '../stores/toastStore';
	import ErrorToast from './ErrorToast.svelte';

	export let position: 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left' | 'top-center' = 'top-right';
	export let maxToasts: number = 5;

	$: toasts = $toastStore.toasts.slice(-maxToasts); // Només mostrar els últims N toasts

	function handleToastClose(toastId: string) {
		toastStore.removeToast(toastId);
	}

	function handleToastRetry(toastId: string) {
		// Emetre event per què el component pare pugui manejar el retry
		toastStore.removeToast(toastId);
	}

	function handleToastAction(toastId: string, action: string) {
		// Emetre event per què el component pare pugui manejar l'acció
		toastStore.removeToast(toastId);
	}
</script>

<!-- Contenidor de toasts -->
<div class="fixed inset-0 pointer-events-none z-50">
	{#each toasts as toast (toast.id)}
		<div class="pointer-events-auto">
			<ErrorToast
				error={toast.error || null}
				message={toast.message || null}
				severity={toast.severity}
				autoClose={toast.autoClose}
				duration={toast.duration}
				{position}
				showDetails={toast.error?.severity === 'error'}
				on:close={() => handleToastClose(toast.id)}
				on:retry={() => handleToastRetry(toast.id)}
				on:action={(event) => handleToastAction(toast.id, event.detail)}
			/>
		</div>
	{/each}
</div>