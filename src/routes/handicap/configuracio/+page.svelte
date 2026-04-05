<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import { formatSupabaseError } from '$lib/ui/alerts';
	import Banner from '$lib/components/general/Banner.svelte';
	import HandicapScheduleConfig from '$lib/components/handicap/HandicapScheduleConfig.svelte';
	import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
	$: if ($adminChecked && !$isAdmin) goto('/handicap');

	let loading = true;
	let saving = false;
	let savingAccess = false;
	let error: string | null = null;
	let success: string | null = null;
	let event: any = null;
	let config: any = null;
	let participantsCount = 0;
	let matchesCount = 0;
	let playedMatchesCount = 0;
	let bracketExists = false;

	// Editable config
	let sistema_puntuacio: 'distancia' | 'percentatge' = 'distancia';
	let limit_entrades: number = 50;
	let distancies: Array<{ nom: string; distancia: number }> = [];

	// Schedule config (managed by HandicapScheduleConfig component)
	let horaris_extra_enabled = false;
	let horaris_extra_franja = '17:00';
	let horaris_extra_dies: string[] = [];
	let data_inici = '';
	let data_fi = '';
	let blockedPeriods: Array<{ start: string; end: string; description: string }> = [];

	// Warnings
	let warnings: string[] = [];

	// Original sistema for change detection
	let originalSistema: string = 'distancia';

	// localStorage key for blocked periods (same pattern as CalendarGenerator)
	$: storageKey = event ? `handicapConfig_${event.id}` : '';

	function loadLocalConfig() {
		if (!storageKey) return;
		try {
			const saved = localStorage.getItem(storageKey);
			if (saved) {
				const parsed = JSON.parse(saved);
				if (parsed.blockedPeriods) blockedPeriods = parsed.blockedPeriods;
			}
		} catch { /* ignore */ }
	}

	function saveLocalConfig() {
		if (!storageKey) return;
		try {
			localStorage.setItem(storageKey, JSON.stringify({ blockedPeriods }));
		} catch { /* ignore */ }
	}

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		error = null;

		try {
			// Find active handicap event
			const { data: events, error: evErr } = await supabase
				.from('events')
				.select('*')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.order('creat_el', { ascending: false })
				.limit(1);

			if (evErr) throw evErr;

			if (!events || events.length === 0) {
				event = null;
				config = null;
				loading = false;
				return;
			}

			event = events[0];
			data_inici = event.data_inici || '';
			data_fi = event.data_fi || '';

			// Load config
			const { data: cfgData, error: cfgErr } = await supabase
				.from('handicap_config')
				.select('*')
				.eq('event_id', event.id)
				.single();

			if (cfgErr && cfgErr.code !== 'PGRST116') throw cfgErr;
			config = cfgData;

			if (config) {
				sistema_puntuacio = config.sistema_puntuacio;
				originalSistema = config.sistema_puntuacio;
				limit_entrades = config.limit_entrades || 50;
				distancies = Array.isArray(config.distancies_per_categoria)
					? [...config.distancies_per_categoria]
					: [];
				if (config.horaris_extra) {
					horaris_extra_enabled = true;
					horaris_extra_franja = config.horaris_extra.franja || '17:00';
					horaris_extra_dies = [...(config.horaris_extra.dies || [])];
				}
				blockedPeriods = Array.isArray(config.blocked_periods) ? [...config.blocked_periods] : [];
			}

			// Load stats
			const { count: pCount } = await supabase
				.from('handicap_participants')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', event.id);
			participantsCount = pCount || 0;

			const { count: mCount } = await supabase
				.from('handicap_matches')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', event.id);
			matchesCount = mCount || 0;

			const { count: pMatchCount } = await supabase
				.from('handicap_matches')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', event.id)
				.eq('estat', 'jugada');
			playedMatchesCount = pMatchCount || 0;

			const { count: bCount } = await supabase
				.from('handicap_bracket_slots')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', event.id);
			bracketExists = (bCount || 0) > 0;
		} catch (e) {
			error = formatSupabaseError(e);
		} finally {
			loading = false;
		}
	}

	function addDistanciaGrup() {
		distancies = [...distancies, { nom: '', distancia: 10 }];
	}

	function removeDistanciaGrup(index: number) {
		if (distancies.length > 1) {
			distancies = distancies.filter((_, i) => i !== index);
		}
	}

	// Reactive warnings
	$: {
		const w: string[] = [];

		if (distancies.length === 0) {
			w.push('No hi ha grups de distancia definits.');
		}
		if (!data_inici) {
			w.push("No s'ha definit la data d'inici.");
		}
		if (!data_fi) {
			w.push("No s'ha definit la data de fi.");
		}
		if (horaris_extra_enabled && horaris_extra_dies.length === 0) {
			w.push("Franja extra habilitada pero sense dies seleccionats.");
		}
		if (participantsCount > 0 && distancies.length > 0) {
			// Check if any existing distance was reduced (soft warning)
			const origDist = config?.distancies_per_categoria || [];
			for (const orig of origDist) {
				const current = distancies.find(d => d.nom === orig.nom);
				if (current && current.distancia < orig.distancia) {
					w.push(`La distancia del grup "${orig.nom}" s'ha reduit de ${orig.distancia} a ${current.distancia}. Hi ha ${participantsCount} participants inscrits.`);
					break;
				}
			}
		}

		warnings = w;
	}

	$: sistemaCanviat = config && sistema_puntuacio !== originalSistema;
	$: sistemaBloquejat = sistemaCanviat && playedMatchesCount > 0;

	// Access level derivat de l'estat de l'event
	$: accessLevel =
		!event ? 'dev' :
		event.estat_competicio === 'en_curs' || event.estat_competicio === 'finalitzat' ? 'public' :
		'admin';

	$: accessLabel =
		accessLevel === 'public' ? 'Obert als socis' :
		accessLevel === 'admin' ? 'Només administradors' :
		'Sense event actiu';

	async function openToPublic() {
		if (!event) return;
		savingAccess = true;
		const { error: err } = await supabase
			.from('events')
			.update({ estat_competicio: 'en_curs' })
			.eq('id', event.id);
		if (err) { error = err.message; } else { await loadData(); success = 'Torneig obert als socis.'; }
		savingAccess = false;
	}

	async function closeToPublic() {
		if (!event) return;
		savingAccess = true;
		const { error: err } = await supabase
			.from('events')
			.update({ estat_competicio: 'inscripcions' })
			.eq('id', event.id);
		if (err) { error = err.message; } else { await loadData(); success = 'Accés tancat. Torneig en mode inscripcions.'; }
		savingAccess = false;
	}

	async function handleSave() {
		saving = true;
		error = null;
		success = null;

		try {
			// Validations
			const validDistancies = distancies.filter(d => d.nom.trim() && d.distancia > 0);
			if (validDistancies.length === 0) {
				error = 'Cal definir almenys un grup de distancia.';
				return;
			}

			if (sistema_puntuacio === 'percentatge' && (!limit_entrades || limit_entrades < 1)) {
				error = "El sistema percentatge requereix un limit d'entrades valid (> 0).";
				return;
			}

			if (data_inici && data_fi && new Date(data_inici) >= new Date(data_fi)) {
				error = "La data de fi ha de ser posterior a la d'inici.";
				return;
			}

			if (sistemaBloquejat) {
				error = `No es pot canviar el sistema de puntuacio: ja s'han jugat ${playedMatchesCount} partides.`;
				return;
			}

			// Build config data
			const configData: any = {
				sistema_puntuacio,
				limit_entrades: sistema_puntuacio === 'percentatge' ? limit_entrades : null,
				distancies_per_categoria: validDistancies
			};

			if (horaris_extra_enabled && horaris_extra_dies.length > 0) {
				configData.horaris_extra = {
					franja: horaris_extra_franja,
					dies: horaris_extra_dies
				};
			} else {
				configData.horaris_extra = null;
			}

			// Store blocked periods in config (no separate table needed)
			if (blockedPeriods.length > 0) {
				configData.blocked_periods = blockedPeriods;
			}

			// Save config
			if (config) {
				const { error: updErr } = await supabase
					.from('handicap_config')
					.update(configData)
					.eq('id', config.id);
				if (updErr) throw updErr;
			} else {
				configData.event_id = event.id;
				const { error: insErr } = await supabase
					.from('handicap_config')
					.insert(configData);
				if (insErr) throw insErr;
			}

			// Save event dates
			const { error: evErr } = await supabase
				.from('events')
				.update({
					data_inici: data_inici || null,
					data_fi: data_fi || null
				})
				.eq('id', event.id);
			if (evErr) throw evErr;

			success = 'Configuracio desada correctament.';
			await loadData();
		} catch (e) {
			error = formatSupabaseError(e);
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>Configuracio Handicap</title>
</svelte:head>

<div class="mx-auto max-w-3xl p-4">
	<div class="mb-4 flex items-center space-x-4">
		<a href="/handicap" class="text-gray-600 hover:text-gray-900">&#8592; Dashboard</a>
	</div>

	<h1 class="mb-6 text-2xl font-bold text-gray-900">Configuracio del Torneig Handicap</h1>

	{#if error}
		<Banner type="error" message={error} class="mb-4" />
	{/if}
	{#if success}
		<div class="mb-4 rounded border border-green-300 bg-green-50 p-3 text-sm text-green-800">{success}</div>
	{/if}

	{#if loading}
		<div class="rounded border border-blue-200 bg-blue-50 p-4 text-blue-800">Carregant...</div>
	{:else if !event}
		<div class="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center">
			<p class="mb-4 text-gray-600">No hi ha cap torneig handicap actiu.</p>
			<a
				href="/admin/events/nou"
				class="inline-flex items-center rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700"
			>
				Crear Torneig Handicap
			</a>
		</div>
	{:else}
		<!-- Event info + stats -->
		<div class="mb-6 rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
			<div class="flex items-center justify-between">
				<div>
					<h2 class="text-lg font-semibold text-gray-900">{event.nom}</h2>
					<p class="text-sm text-gray-600">Temporada {event.temporada} &middot; {event.estat_competicio}</p>
				</div>
				<span class="rounded-full bg-purple-100 px-3 py-1 text-xs font-medium text-purple-800">Handicap</span>
			</div>

			<div class="mt-4 grid grid-cols-4 gap-3">
				<div class="rounded border border-gray-200 p-3 text-center">
					<div class="text-2xl font-bold text-gray-900">{participantsCount}</div>
					<div class="text-xs text-gray-500">Inscrits</div>
				</div>
				<div class="rounded border border-gray-200 p-3 text-center">
					<div class="text-2xl font-bold text-gray-900">{matchesCount}</div>
					<div class="text-xs text-gray-500">Partides</div>
				</div>
				<div class="rounded border border-gray-200 p-3 text-center">
					<div class="text-2xl font-bold text-green-600">{playedMatchesCount}</div>
					<div class="text-xs text-gray-500">Jugades</div>
				</div>
				<div class="rounded border border-gray-200 p-3 text-center">
					<div class="text-2xl font-bold {bracketExists ? 'text-green-600' : 'text-gray-400'}">
						{bracketExists ? 'Si' : 'No'}
					</div>
					<div class="text-xs text-gray-500">Bracket</div>
				</div>
			</div>
		</div>

		<!-- Warnings -->
		{#if warnings.length > 0}
			<div class="mb-4 rounded border border-yellow-300 bg-yellow-50 p-3">
				<h4 class="mb-1 text-sm font-semibold text-yellow-800">Avisos de configuracio</h4>
				<ul class="list-inside list-disc text-xs text-yellow-700">
					{#each warnings as w}
						<li>{w}</li>
					{/each}
				</ul>
			</div>
		{/if}

		{#if !config}
			<div class="mb-4 rounded border border-yellow-300 bg-yellow-50 p-3 text-sm text-yellow-800">
				No s'ha trobat la configuracio per aquest torneig. Defineix-la a continuacio.
			</div>
		{/if}

		<form on:submit|preventDefault={handleSave} class="space-y-6">
			<!-- Sistema de puntuacio -->
			<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
				<h3 class="mb-4 text-base font-semibold text-gray-900">Sistema de Puntuacio</h3>

				{#if sistemaBloquejat}
					<div class="mb-3 rounded border border-red-200 bg-red-50 p-2 text-xs text-red-700">
						No es pot canviar el sistema: ja s'han jugat {playedMatchesCount} partides.
					</div>
				{/if}

				<div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
					<div>
						<label for="cfg_sistema" class="block text-sm font-medium text-gray-700">Sistema *</label>
						<select
							id="cfg_sistema"
							bind:value={sistema_puntuacio}
							disabled={sistemaBloquejat}
							class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 {sistemaBloquejat ? 'bg-gray-100 cursor-not-allowed' : ''}"
						>
							<option value="distancia">Distancia (primer a arribar)</option>
							<option value="percentatge">Percentatge (amb limit d'entrades)</option>
						</select>
						{#if sistemaCanviat && !sistemaBloquejat}
							<p class="mt-1 text-xs text-yellow-600">El sistema ha canviat. Es desara al confirmar.</p>
						{/if}
					</div>

					{#if sistema_puntuacio === 'percentatge'}
						<div>
							<label for="cfg_limit" class="block text-sm font-medium text-gray-700">Limit d'Entrades *</label>
							<input
								type="number"
								id="cfg_limit"
								bind:value={limit_entrades}
								min="1"
								class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
							/>
						</div>
					{/if}
				</div>
			</div>

			<!-- Distancies per grup -->
			<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
				<div class="mb-3 flex items-center justify-between">
					<h3 class="text-base font-semibold text-gray-900">Distancies per Grup de Nivell</h3>
					<button
						type="button"
						on:click={addDistanciaGrup}
						class="rounded border border-gray-300 bg-white px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
					>
						+ Afegir grup
					</button>
				</div>

				<div class="space-y-2">
					{#each distancies as grup, index}
						<div class="flex items-center gap-3">
							<input
								type="text"
								bind:value={grup.nom}
								placeholder="Nom (ex: 1a)"
								class="w-32 rounded-md border-gray-300 text-sm shadow-sm focus:border-blue-500 focus:ring-blue-500"
							/>
							<input
								type="number"
								bind:value={grup.distancia}
								min="1"
								placeholder="Caramboles"
								class="w-28 rounded-md border-gray-300 text-sm shadow-sm focus:border-blue-500 focus:ring-blue-500"
							/>
							<span class="text-sm text-gray-500">caramboles</span>
							{#if distancies.length > 1}
								<button
									type="button"
									on:click={() => removeDistanciaGrup(index)}
									class="text-sm text-red-500 hover:text-red-700"
								>
									Eliminar
								</button>
							{/if}
						</div>
					{/each}
				</div>
			</div>

			<!-- Schedule config component -->
			<HandicapScheduleConfig
				bind:horaris_extra_enabled
				bind:horaris_extra_franja
				bind:horaris_extra_dies
				bind:data_inici
				bind:data_fi
				bind:blockedPeriods
				{participantsCount}
			/>

					<!-- Accés al torneig -->
		<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
			<h3 class="mb-3 text-base font-semibold text-gray-900">Control d'Accés dels Socis</h3>
			<div class="flex items-center justify-between gap-4">
				<div>
					<div class="text-sm text-gray-700">
						Estat actual:
						<span class="ml-1 font-semibold {accessLevel === 'public' ? 'text-green-700' : 'text-amber-700'}">
							{accessLevel === 'public' ? '🟢' : '🔒'} {accessLabel}
						</span>
					</div>
					<p class="mt-1 text-xs text-gray-500">
						{#if accessLevel === 'public'}
							Tots els socis autenticats poden veure el quadre, partides i estadístiques.
						{:else if accessLevel === 'admin'}
							Només els administradors accedeixen al mòdul hàndicap. Els socis veuen "En preparació".
						{:else}
							Cap event hàndicap actiu. Crea'n un des d'Admin → Events.
						{/if}
					</p>
				</div>
				{#if event && event.estat_competicio !== 'finalitzat'}
					{#if accessLevel !== 'public'}
						<button
							type="button"
							on:click={openToPublic}
							disabled={savingAccess}
							class="shrink-0 rounded-md bg-green-600 px-4 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50"
						>
							{savingAccess ? '...' : '🔓 Obrir als socis'}
						</button>
					{:else if playedMatchesCount === 0}
						<button
							type="button"
							on:click={closeToPublic}
							disabled={savingAccess}
							class="shrink-0 rounded-md bg-amber-600 px-4 py-2 text-sm font-semibold text-white hover:bg-amber-700 disabled:opacity-50"
						>
							{savingAccess ? '...' : '🔒 Tancar als socis'}
						</button>
					{:else}
						<span class="shrink-0 rounded-md bg-gray-100 px-4 py-2 text-xs text-gray-500">
							Partides en curs — no es pot tancar
						</span>
					{/if}
				{/if}
			</div>
		</div>

		<!-- Save button -->
			<div class="flex justify-end">
				<button
					type="submit"
					disabled={saving}
					class="inline-flex items-center rounded-md border border-transparent bg-purple-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-purple-700 disabled:opacity-50"
				>
					{#if saving}
						Desant...
					{:else}
						Desar Configuracio
					{/if}
				</button>
			</div>
		</form>
	{/if}
</div>
