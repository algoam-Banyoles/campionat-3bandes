<script lang="ts">
	import { onMount } from 'svelte';
	import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
	import { user } from '$lib/stores/auth';
	import { supabase } from '$lib/supabaseClient';

	// 'dev'    → cap event creat; només admins (per preparació inicial)
	// 'admin'  → event en planificació/inscripcions; només admins
	// 'public' → event en_curs/finalitzat; tots els socis autenticats
	type AccessLevel = 'loading' | 'dev' | 'admin' | 'public';

	let accessLevel: AccessLevel = 'loading';

	onMount(async () => {
		const { data: ev } = await supabase
			.from('events')
			.select('estat_competicio')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.maybeSingle();

		if (!ev) {
			accessLevel = 'dev';
		} else if (ev.estat_competicio === 'en_curs' || ev.estat_competicio === 'finalitzat') {
			accessLevel = 'public';
		} else {
			// planificacio, inscripcions → admin only
			accessLevel = 'admin';
		}
	});

	$: loading = !$adminChecked || accessLevel === 'loading';

	// Admins always have access; public users need 'public' level
	$: canAccess =
		!loading && ($isAdmin || accessLevel === 'public') && !!$user;

	$: showDevBanner = canAccess && accessLevel === 'dev' && $isAdmin;
	$: showAdminBanner = canAccess && accessLevel === 'admin' && $isAdmin;
</script>

{#if loading}
	<div class="m-4 rounded border border-blue-300 bg-blue-50 p-4 text-blue-800 text-sm">
		Carregant...
	</div>
{:else if canAccess}
	{#if showDevBanner}
		<div class="sticky top-0 z-50 bg-orange-500 px-4 py-1.5 text-center text-xs font-semibold text-white">
			⚠️ MODE DESENVOLUPAMENT — Cap event hàndicap actiu. Accés restringit a administradors.
		</div>
	{:else if showAdminBanner}
		<div class="sticky top-0 z-50 bg-amber-500 px-4 py-1.5 text-center text-xs font-semibold text-white">
			🔒 EN PREPARACIÓ — El torneig no és públic encara. Visible només per administradors.
			<a href="/handicap/configuracio" class="ml-2 underline opacity-90 hover:opacity-100">Obrir als socis →</a>
		</div>
	{/if}
	<slot />
{:else if !$user}
	<div class="m-4 rounded border border-amber-300 bg-amber-50 p-4 text-amber-800">
		Cal iniciar sessió per accedir al mòdul Hàndicap. —
		<a href="/general/login" class="underline">Iniciar sessió</a>
	</div>
{:else if accessLevel === 'dev'}
	<div class="m-4 rounded border border-gray-300 bg-gray-50 p-8 text-center text-gray-600">
		<div class="text-4xl mb-3">⚖️</div>
		<h2 class="text-lg font-semibold mb-1">Campionat Hàndicap</h2>
		<p class="text-sm">El mòdul hàndicap no està disponible en aquest moment.</p>
	</div>
{:else}
	<!-- accessLevel === 'admin' i l'usuari no és admin -->
	<div class="m-4 rounded border border-purple-200 bg-purple-50 p-8 text-center">
		<div class="text-4xl mb-3">⚖️</div>
		<h2 class="text-lg font-semibold text-purple-900 mb-1">Campionat Hàndicap</h2>
		<p class="text-sm text-purple-700">El torneig està en preparació. Aviat estarà disponible per a tots els socis.</p>
	</div>
{/if}
