<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { notificationStore } from '$lib/stores/notifications';

	let testResults: string[] = [];
	let isLoading = false;

	function addResult(message: string, success: boolean = true) {
		const timestamp = new Date().toLocaleTimeString();
		const status = success ? '✅' : '❌';
		testResults = [...testResults, `${timestamp} ${status} ${message}`];
	}

	async function testNotificationSupport() {
		isLoading = true;
		addResult('Iniciant tests del sistema de notificacions...');

		// Test 1: Service Worker
		if ('serviceWorker' in navigator) {
			addResult('Support per Service Worker detectat');
		} else {
			addResult('Service Worker no suportat', false);
		}

		// Test 2: Push API
		if ('PushManager' in window) {
			addResult('Push API suportada');
		} else {
			addResult('Push API no suportada', false);
		}

		// Test 3: Notifications API
		if ('Notification' in window) {
			addResult('Notifications API suportada');
		} else {
			addResult('Notifications API no suportada', false);
		}

		// Test 4: Store initialization
		try {
			await notificationStore.initialize();
			addResult('Store de notificacions inicialitzat correctament');
		} catch (error) {
			addResult(`Error inicialitzant store: ${error}`, false);
		}

		// Test 5: Test notification
		if (Notification.permission === 'granted') {
			try {
				new Notification('Test de Notificació', {
					body: 'Si veus aquest missatge, les notificacions funcionen correctament!',
					icon: '/favicon.svg'
				});
				addResult('Notificació de test enviada');
			} catch (error) {
				addResult(`Error enviant notificació de test: ${error}`, false);
			}
		} else {
			addResult('Permisos de notificació no concedits - demana permisos primer');
		}

		isLoading = false;
	}

	async function requestPermissions() {
		try {
			await notificationStore.requestPermission();
			addResult('Permisos sol·licitats');
		} catch (error) {
			addResult(`Error sol·licitant permisos: ${error}`, false);
		}
	}

	function clearResults() {
		testResults = [];
	}
</script>

<svelte:head>
	<title>Test del Sistema de Notificacions - Campionat 3 Bandes</title>
</svelte:head>

<div class="container mx-auto px-4 py-8">
	<div class="max-w-4xl mx-auto">
		<div class="bg-white rounded-lg shadow-lg p-6">
			<h1 class="text-3xl font-bold text-gray-900 mb-6">
				🔧 Test del Sistema de Notificacions
			</h1>

			<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
				<!-- Controls -->
				<div class="space-y-4">
					<div class="bg-gray-50 p-4 rounded-lg">
						<h2 class="text-lg font-semibold mb-3">Controls de Test</h2>
						
						<div class="space-y-2">
							<button
								on:click={requestPermissions}
								class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
							>
								🔑 Sol·licitar Permisos
							</button>

							<button
								on:click={testNotificationSupport}
								disabled={isLoading}
								class="w-full bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
							>
								{#if isLoading}
									⏳ Executant Tests...
								{:else}
									🧪 Executar Tests
								{/if}
							</button>

							<button
								on:click={clearResults}
								class="w-full bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
							>
								🗑️ Netejar Resultats
							</button>
						</div>
					</div>

					<!-- Store State -->
					<div class="bg-gray-50 p-4 rounded-lg">
						<h2 class="text-lg font-semibold mb-3">Estat del Store</h2>
						<div class="space-y-2 text-sm">
							<div>
								<strong>Suport:</strong>
								<span class="ml-2 px-2 py-1 rounded text-xs {$notificationStore.supported ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
									{$notificationStore.supported ? 'Sí' : 'No'}
								</span>
							</div>
							<div>
								<strong>Permisos:</strong>
								<span class="ml-2 px-2 py-1 rounded text-xs 
									{$notificationStore.permission === 'granted' ? 'bg-green-100 text-green-800' : 
									 $notificationStore.permission === 'denied' ? 'bg-red-100 text-red-800' : 
									 'bg-yellow-100 text-yellow-800'}">
									{$notificationStore.permission || 'desconegut'}
								</span>
							</div>
							<div>
								<strong>Subscripció:</strong>
								<span class="ml-2 px-2 py-1 rounded text-xs {$notificationStore.subscription ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
									{$notificationStore.subscription ? 'Activa' : 'Inactiva'}
								</span>
							</div>
						</div>
					</div>
				</div>

				<!-- Results -->
				<div class="bg-gray-50 p-4 rounded-lg">
					<h2 class="text-lg font-semibold mb-3">Resultats dels Tests</h2>
					
					{#if testResults.length === 0}
						<p class="text-gray-500 text-sm">No s'han executat tests encara.</p>
					{:else}
						<div class="space-y-1 max-h-96 overflow-y-auto">
							{#each testResults as result}
								<div class="text-xs font-mono bg-white p-2 rounded border">
									{result}
								</div>
							{/each}
						</div>
					{/if}
				</div>
			</div>

			<!-- Documentation -->
			<div class="mt-8 p-4 bg-blue-50 rounded-lg">
				<h2 class="text-lg font-semibold text-blue-900 mb-3">ℹ️ Informació</h2>
				<div class="text-sm text-blue-800 space-y-2">
					<p>
						Aquesta pàgina permet provar el sistema de notificacions push implementat.
					</p>
					<ul class="list-disc list-inside space-y-1">
						<li>Primer, sol·licita els permisos de notificació</li>
						<li>Després, executa els tests per verificar la funcionalitat</li>
						<li>Si tot funciona, rebràs una notificació de test</li>
					</ul>
					<p class="mt-3">
						<strong>Nota:</strong> Les notificacions push només funcionen en HTTPS o localhost.
					</p>
				</div>
			</div>
		</div>
	</div>
</div>