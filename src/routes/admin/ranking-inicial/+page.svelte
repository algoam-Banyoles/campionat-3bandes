<script lang="ts">
	import CrearRanquingInicial from '$lib/components/CrearRanquingInicial.svelte';
	import { goto } from '$app/navigation';
</script>

<svelte:head>
	<title>Crear Rànquing Inicial - Campionat 3 Bandes</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
	<!-- Navegació -->
	<div class="bg-white shadow">
		<div class="max-w-6xl mx-auto px-6 py-4">
			<button
				class="flex items-center text-blue-600 hover:text-blue-800"
				on:click={() => goto('/admin')}
			>
				<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
				</svg>
				Tornar a Administració
			</button>
		</div>
	</div>

	<!-- Component principal -->
	<div class="py-8">
		<CrearRanquingInicial />
	</div>
</div>