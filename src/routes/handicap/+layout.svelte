<script lang="ts">
	import { onMount } from 'svelte';
	import { adminChecked } from '$lib/stores/adminAuth';
	import { effectiveIsAdmin } from '$lib/stores/viewMode';
	import { supabase } from '$lib/supabaseClient';

	// 'dev'    → cap event creat; només admins (per preparació inicial)
	// 'admin'  → event en planificació/inscripcions; només admins
	// 'public' → event en_curs/finalitzat; tots els socis autenticats
	type AccessLevel = 'loading' | 'dev' | 'admin' | 'public';

	let accessLevel: AccessLevel = 'loading';

	onMount(async () => {
		// 1. Buscar event actiu
		const { data: activeEv } = await supabase
			.from('events')
			.select('estat_competicio')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.maybeSingle();

		if (activeEv) {
			if (activeEv.estat_competicio === 'en_curs' || activeEv.estat_competicio === 'finalitzat') {
				accessLevel = 'public';
			} else {
				// planificacio, inscripcions → admin only
				accessLevel = 'admin';
			}
		} else {
			// Sense event actiu: buscar el més recent per si el torneig s'ha tancat
			const { data: recentEv } = await supabase
				.from('events')
				.select('estat_competicio')
				.eq('tipus_competicio', 'handicap')
				.order('data_inici', { ascending: false })
				.limit(1)
				.maybeSingle();

			if (recentEv && (recentEv.estat_competicio === 'en_curs' || recentEv.estat_competicio === 'finalitzat')) {
				// Torneig finalitzat (actiu=false) → accés públic per consultar historial
				accessLevel = 'public';
			} else {
				// Cap event o estat inicial → mode dev (admins only)
				accessLevel = 'dev';
			}
		}
	});

	$: loading = !$adminChecked || accessLevel === 'loading';

	// Guard de 3 nivells:
	//   'dev'    → cap event o estat inicial → només admins
	//   'admin'  → planificacio/inscripcions → només admins
	//   'public' → en_curs/finalitzat → tots (socis autenticats)
	$: canAccess = !loading && ($effectiveIsAdmin || accessLevel === 'public');

	$: showDevBanner = canAccess && accessLevel === 'dev' && $effectiveIsAdmin;
	$: showAdminBanner = canAccess && accessLevel === 'admin' && $effectiveIsAdmin;
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
{:else}
	<!-- accessLevel === 'dev' i no admin -->
	<div class="m-4 rounded border border-gray-300 bg-gray-50 p-8 text-center text-gray-600">
		<div class="text-4xl mb-3">⚖️</div>
		<h2 class="text-lg font-semibold mb-1">Campionat Hàndicap</h2>
		<p class="text-sm">El mòdul hàndicap no està disponible en aquest moment.</p>
	</div>
{/if}
