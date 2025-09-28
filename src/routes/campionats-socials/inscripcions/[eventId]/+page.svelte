<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { user } from '$lib/stores/auth';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';

  let loading = true;
  let saving = false;
  let error: string | null = null;
  let successMessage: string | null = null;

  let event: any = null;
  let player: any = null;
  let existingInscription: any = null;

  const eventId = $page.params.eventId;

  // Form data
  let formData = {
    preferencies_dies: [],
    preferencies_hores: [],
    restriccions_especials: '',
    observacions: ''
  };

  const daysOfWeek = [
    { value: 'dl', label: 'Dilluns' },
    { value: 'dt', label: 'Dimarts' },
    { value: 'dc', label: 'Dimecres' },
    { value: 'dj', label: 'Dijous' },
    { value: 'dv', label: 'Divendres' }
  ];

  const timeSlots = [
    { value: '18:00', label: '18:00h' },
    { value: '19:00', label: '19:00h' }
  ];

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  onMount(async () => {
    const u = $user;
    if (!u?.email) {
      goto('/login');
      return;
    }

    try {
      loading = true;
      await Promise.all([loadEvent(), loadPlayer()]);
      if (player) {
        await checkExistingInscription();
      }
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadEvent() {
    const { supabase } = await import('$lib/supabaseClient');

    const { data, error: eventError } = await supabase
      .from('events')
      .select(`
        *,
        categories (
          id,
          nom,
          distancia_caramboles,
          ordre_categoria,
          min_jugadors,
          max_jugadors,
          promig_minim
        )
      `)
      .eq('id', eventId)
      .single();

    if (eventError) throw eventError;

    event = data;

    // Check if inscriptions are open
    if (!event.actiu || !['inscripcions', 'pendent_validacio'].includes(event.estat_competicio)) {
      error = 'Les inscripcions per aquest event no estan obertes';
    }
  }

  async function loadPlayer() {
    if (!$user?.email) return;

    const { supabase } = await import('$lib/supabaseClient');

    // Get soci info
    const { data: soci, error: sociError } = await supabase
      .from('socis')
      .select('*')
      .eq('email', $user.email)
      .single();

    if (sociError) {
      error = 'No ets soci del club. Contacta amb l\'administració per inscriure\'t.';
      return;
    }

    if (soci.de_baixa) {
      error = 'El teu soci està de baixa. Contacta amb l\'administració.';
      return;
    }

    // Get player's best average from the last two seasons from mitjanes_historiques
    const currentYear = new Date().getFullYear();
    const lastTwoSeasons = [
      `${currentYear-1}-${currentYear}`,
      `${currentYear-2}-${currentYear-1}`
    ];

    const { data: mitjanesList } = await supabase
      .from('mitjanes_historiques')
      .select('mitjana, temporada')
      .eq('numero_soci', soci.numero_soci)
      .in('temporada', lastTwoSeasons);

    // Get the best average from the last two seasons
    const bestMitjana = mitjanesList?.length > 0
      ? Math.max(...mitjanesList.map(m => m.mitjana))
      : null;

    player = {
      id: soci.numero_soci,
      nom: `${soci.nom} ${soci.cognoms}`,
      email: soci.email,
      numero_soci: soci.numero_soci,
      mitjana: bestMitjana,
      estat: 'actiu'
    };
  }

  async function checkExistingInscription() {
    if (!player) return;

    const { supabase } = await import('$lib/supabaseClient');

    const { data, error: inscriptionError } = await supabase
      .from('inscripcions')
      .select(`
        *,
        categoria_assignada:categories (
          nom,
          ordre_categoria
        )
      `)
      .eq('event_id', eventId)
      .eq('soci_numero', player.id)
      .single();

    if (inscriptionError && inscriptionError.code !== 'PGRST116') {
      throw inscriptionError;
    }

    if (data) {
      existingInscription = data;
      // Populate form with existing data
      formData = {
        preferencies_dies: data.preferencies_dies || [],
        preferencies_hores: data.preferencies_hores || [],
        restriccions_especials: data.restriccions_especials || '',
        observacions: data.observacions || ''
      };
    }
  }

  async function handleSubmit() {
    try {
      saving = true;
      error = null;

      if (!player) {
        error = 'No s\'ha pogut identificar el teu perfil de jugador';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      const inscriptionData = {
        event_id: eventId,
        soci_numero: player.id,
        preferencies_dies: formData.preferencies_dies,
        preferencies_hores: formData.preferencies_hores,
        restriccions_especials: formData.restriccions_especials.trim() || null,
        observacions: formData.observacions.trim() || null,
        pagat: false, // Will be updated by admin
        confirmat: false, // Will be confirmed by admin
        data_inscripcio: new Date().toISOString()
      };

      if (existingInscription) {
        // Update existing inscription
        const { error: updateError } = await supabase
          .from('inscripcions')
          .update(inscriptionData)
          .eq('id', existingInscription.id);

        if (updateError) throw updateError;
        successMessage = 'Inscripció actualitzada correctament';
      } else {
        // Create new inscription
        const { error: insertError } = await supabase
          .from('inscripcions')
          .insert([inscriptionData]);

        if (insertError) throw insertError;
        successMessage = 'Inscripció creada correctament';
      }

      // Redirect after 2 seconds
      setTimeout(() => {
        goto('/inscripcions');
      }, 2000);

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }

  function handleDayChange(dayValue: string, checked: boolean) {
    if (checked) {
      formData.preferencies_dies = [...formData.preferencies_dies, dayValue];
    } else {
      formData.preferencies_dies = formData.preferencies_dies.filter(d => d !== dayValue);
    }
  }

  function handleTimeChange(timeValue: string, checked: boolean) {
    if (checked) {
      formData.preferencies_hores = [...formData.preferencies_hores, timeValue];
    } else {
      formData.preferencies_hores = formData.preferencies_hores.filter(t => t !== timeValue);
    }
  }

  function getRecommendedCategory() {
    if (!event?.categories || !player?.mitjana) return null;

    // Simple category assignment based on average
    // This should be replaced with more sophisticated logic
    const sortedCategories = event.categories.sort((a, b) => a.ordre_categoria - b.ordre_categoria);

    if (player.mitjana >= 1.5) return sortedCategories[0]; // 1st category
    if (player.mitjana >= 1.0) return sortedCategories[1] || sortedCategories[0]; // 2nd category
    return sortedCategories[2] || sortedCategories[sortedCategories.length - 1]; // 3rd or last category
  }
</script>

<svelte:head>
  <title>Inscripció: {event?.nom || 'Event'} - Campionat 3 Bandes</title>
</svelte:head>

<div class="max-w-3xl mx-auto p-4">
  <div class="mb-6">
    <a href="/inscripcions" class="text-gray-600 hover:text-gray-900 text-sm">
      ← Tornar a inscripcions
    </a>
    <h1 class="text-2xl font-semibold text-gray-900 mt-4">
      {#if existingInscription}
        Actualitzar Inscripció
      {:else}
        Nova Inscripció
      {/if}
    </h1>
  </div>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} class="mb-6" />
    <div class="text-center">
      <a href="/inscripcions" class="text-blue-600 hover:text-blue-800">
        ← Tornar a inscripcions
      </a>
    </div>
  {:else if !event}
    <div class="text-center py-12">
      <h3 class="text-lg font-medium text-gray-900">Event no trobat</h3>
      <p class="text-gray-600 mt-2">L'event que cerques no existeix</p>
      <div class="mt-6">
        <a href="/inscripcions" class="text-blue-600 hover:text-blue-800">
          ← Tornar a inscripcions
        </a>
      </div>
    </div>
  {:else}
    {#if successMessage}
      <Banner type="success" message={successMessage} class="mb-6" />
    {/if}

    <!-- Event Info -->
    <div class="bg-white shadow sm:rounded-lg mb-6">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900">
          {event.nom}
        </h3>
        <div class="mt-2 max-w-xl text-sm text-gray-500">
          <p>{modalityNames[event.modalitat]} • {event.temporada}</p>
          {#if event.data_inici && event.data_fi}
            <p class="mt-1">
              📅 {new Date(event.data_inici).toLocaleDateString('ca-ES')} - {new Date(event.data_fi).toLocaleDateString('ca-ES')}
            </p>
          {/if}
          {#if event.quota_inscripcio > 0}
            <p class="mt-1">
              💰 Quota d'inscripció: <strong>{event.quota_inscripcio}€</strong>
            </p>
          {/if}
          {#if event.categories && event.categories.length > 0}
            <div class="mt-3">
              <p class="text-sm font-medium text-gray-700 mb-2">Categories disponibles:</p>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {#each event.categories as category}
                  <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                    <span class="text-sm">{category.nom}</span>
                    <span class="text-xs text-gray-500">{category.distancia_caramboles} caramboles</span>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Existing Inscription Status -->
    {#if existingInscription}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-blue-800">
              Ja estàs inscrit a aquest event
            </h3>
            <div class="mt-2 text-sm text-blue-700">
              <p>Estat: <span class="font-medium">{existingInscription.confirmat ? 'Confirmat' : 'Pendent confirmació'}</span></p>
              {#if event.quota_inscripcio > 0}
                <p>Pagament: <span class="font-medium">{existingInscription.pagat ? 'Pagat' : 'Pendent pagament'}</span></p>
              {/if}
              {#if existingInscription.categoria_assignada}
                <p>Categoria assignada: <span class="font-medium">{existingInscription.categoria_assignada.nom}</span></p>
              {/if}
            </div>
            <div class="mt-3">
              <p class="text-xs text-blue-600">
                Pots actualitzar les teves preferències utilitzant el formulari de sota
              </p>
            </div>
          </div>
        </div>
      </div>
    {/if}

    <!-- Player Info & Category Recommendation -->
    {#if player}
      <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-6">
        <h3 class="text-sm font-medium text-gray-800 mb-2">Informació del Jugador</h3>
        <div class="text-sm text-gray-600">
          <p><strong>Nom:</strong> {player.nom}</p>
          <p><strong>Número de soci:</strong> {player.numero_soci}</p>
          {#if player.mitjana}
            <p><strong>Mitjana actual:</strong> {player.mitjana.toFixed(3)}</p>
            {@const recommendedCategory = getRecommendedCategory()}
            {#if recommendedCategory}
              <p class="mt-2 text-blue-600">
                <strong>Categoria recomanada:</strong> {recommendedCategory.nom}
                <span class="text-xs text-gray-500">
                  ({recommendedCategory.distancia_caramboles} caramboles)
                </span>
              </p>
            {/if}
          {:else}
            <p class="text-yellow-600"><strong>Mitjana:</strong> Sense mitjana històrica (categoria assignada per la junta)</p>
          {/if}
        </div>
      </div>
    {/if}

    <!-- Inscription Form -->
    <form on:submit|preventDefault={handleSubmit} class="space-y-6">
      <!-- Time Preferences -->
      <div class="bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
            Preferències de Joc
          </h3>

          <!-- Days of the week -->
          <div class="mb-6">
            <label class="text-base font-medium text-gray-900">Dies de la setmana que pots jugar</label>
            <p class="text-sm leading-5 text-gray-500">Selecciona els dies que pots i vols jugar. Si no selecciones cap dia, podràs jugar qualsevol dia.</p>
            <fieldset class="mt-4">
              <div class="space-y-4">
                {#each daysOfWeek as day}
                  <div class="flex items-center">
                    <input
                      id="day-{day.value}"
                      name="preferencies_dies"
                      type="checkbox"
                      checked={formData.preferencies_dies.includes(day.value)}
                      on:change={(e) => handleDayChange(day.value, e.target.checked)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                    <label for="day-{day.value}" class="ml-3 block text-sm font-medium text-gray-700">
                      {day.label}
                    </label>
                  </div>
                {/each}
              </div>
            </fieldset>
          </div>

          <!-- Time slots -->
          <div class="mb-6">
            <label class="text-base font-medium text-gray-900">Hores que pots jugar</label>
            <p class="text-sm leading-5 text-gray-500">Tria les franges horàries que pots i vols jugar. Si no selecciones cap hora, podràs jugar a qualsevol hora disponible.</p>
            <fieldset class="mt-4">
              <div class="space-y-4">
                {#each timeSlots as slot}
                  <div class="flex items-center">
                    <input
                      id="time-{slot.value}"
                      name="preferencies_hores"
                      type="checkbox"
                      checked={formData.preferencies_hores.includes(slot.value)}
                      on:change={(e) => handleTimeChange(slot.value, e.target.checked)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                    <label for="time-{slot.value}" class="ml-3 block text-sm font-medium text-gray-700">
                      {slot.label}
                    </label>
                  </div>
                {/each}
              </div>
            </fieldset>
          </div>

          <!-- Special restrictions -->
          <div class="mb-6">
            <label for="restriccions_especials" class="block text-sm font-medium text-gray-700">
              Restriccions Especials
            </label>
            <p class="mt-1 text-sm text-gray-500">
              Indica qualsevol limitació específica (viatges, horaris de feina, etc.)
            </p>
            <textarea
              id="restriccions_especials"
              name="restriccions_especials"
              rows="3"
              bind:value={formData.restriccions_especials}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              placeholder="Exemple: No puc jugar els dijous al vespre per feina..."
            ></textarea>
          </div>

          <!-- Additional observations -->
          <div>
            <label for="observacions" class="block text-sm font-medium text-gray-700">
              Observacions Addicionals
            </label>
            <p class="mt-1 text-sm text-gray-500">
              Qualsevol altra informació que vulguis fer arribar a la junta
            </p>
            <textarea
              id="observacions"
              name="observacions"
              rows="3"
              bind:value={formData.observacions}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              placeholder="Exemple: Primera vegada que participo, prefereixo rivals d'un nivell similar..."
            ></textarea>
          </div>
        </div>
      </div>

      <!-- Important Notes -->
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-yellow-800">
              Informació Important
            </h3>
            <div class="mt-2 text-sm text-yellow-700">
              <ul class="list-disc list-inside space-y-1">
                <li>La categoria s'assignarà segons la teva mitjana històrica</li>
                <li>Les preferències són orientatives - pot ser necessari ajustar-les per organització</li>
                <li>La junta validarà la inscripció abans de confirmar-la</li>
                {#if event.quota_inscripcio > 0}
                  <li>El pagament de {event.quota_inscripcio}€ és necessari per confirmar la inscripció</li>
                {/if}
                <li>Rebràs el calendari de partides un cop validada la inscripció</li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <!-- Submit Button -->
      <div class="flex justify-end space-x-3">
        <a
          href="/inscripcions"
          class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          Cancel·lar
        </a>
        <button
          type="submit"
          disabled={saving}
          class="ml-3 inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
        >
          {#if saving}
            <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {existingInscription ? 'Actualitzant...' : 'Inscrivint...'}
          {:else}
            {existingInscription ? 'Actualitzar Inscripció' : 'Confirmar Inscripció'}
          {/if}
        </button>
      </div>
    </form>
  {/if}
</div>