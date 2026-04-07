<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { user, adminStore } from '$lib/stores/auth';
  import { checkIsAdmin } from '$lib/roles';
  import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import CalendarGenerator from '$lib/components/admin/CalendarGenerator.svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;
  let saving = false;
  let successMessage: string | null = null;

  let event: any = null;
  let categories: any[] = [];
  let inscriptions: any[] = [];

  const eventId = $page.params.id;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'ranking_continu': 'Rànquing Continu',
    'lliga_social': 'Campionat Social',
    'handicap': 'Hàndicap',
    'eliminatories': 'Eliminatòries'
  };

  const formatTypes = {
    'lliga': 'Campionat',
    'eliminatoria_simple': 'Eliminatòria Simple',
    'eliminatoria_doble': 'Eliminatòria Doble'
  };

  const statusNames = {
    'planificacio': 'Planificació',
    'inscripcions': 'Inscripcions Obertes',
    'pendent_validacio': 'Pendent Validació',
    'validat': 'Validat',
    'en_curs': 'En Curs',
    'finalitzat': 'Finalitzat'
  };

  onMount(async () => {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        goto('/login');
        return;
      }

      // Use reactive admin check
      if (!$adminChecked || !$isAdmin) {
        goto('/admin');
        return;
      }

      await loadEvent();
      await loadInscriptions();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadEvent() {


    // Load event with categories
    const { data: eventData, error: eventError } = await supabase
      .from('events')
      .select(`
        *,
        categories (
          *
        )
      `)
      .eq('id', eventId)
      .single();

    if (eventError) throw eventError;

    event = eventData;
    categories = eventData.categories?.sort((a, b) => a.ordre_categoria - b.ordre_categoria) || [];

    // Format dates for input fields
    if (event.data_inici) {
      event.data_inici = new Date(event.data_inici).toISOString().split('T')[0];
    }
    if (event.data_fi) {
      event.data_fi = new Date(event.data_fi).toISOString().split('T')[0];
    }
  }

  async function loadInscriptions() {
    if (!event || event.tipus_competicio !== 'lliga_social') {
      return;
    }



    // Primer carregar inscripcions simples
    const { data: inscData, error: inscError } = await supabase
      .from('inscripcions')
      .select(`
        *,
        socis (
          numero_soci,
          nom,
          cognoms
        )
      `)
      .eq('event_id', eventId);

    if (inscError) {
      console.error('Error carregant inscripcions:', inscError);
      throw inscError;
    }

    // Fase 5c-S2c-2: ja no necessitem el lookup a `players` perquè
    // `player_id` no s'usa downstream — només es desa al state. Filtrem
    // les inscripcions vàlides per categoria assignada directament.
    inscriptions = (inscData || [])
      .filter((i: any) => i.soci_numero && i.categoria_assignada_id);
  }

  async function updateEvent() {
    try {
      saving = true;
      error = null;
      successMessage = null;

      // Validation
      if (!event.nom.trim()) {
        error = 'El nom de l\'event és obligatori';
        return;
      }

      if (!event.temporada.trim()) {
        error = 'La temporada és obligatòria';
        return;
      }

      // Validate dates if provided
      if (event.data_inici && event.data_fi) {
        if (new Date(event.data_inici) >= new Date(event.data_fi)) {
          error = 'La data de fi ha de ser posterior a la data d\'inici';
          return;
        }
      }

  

      // Update event
      const { error: updateError } = await supabase
        .from('events')
        .update({
          nom: event.nom.trim(),
          temporada: event.temporada.trim(),
          modalitat: event.modalitat,
          tipus_competicio: event.tipus_competicio,
          format_joc: event.format_joc,
          data_inici: event.data_inici || null,
          data_fi: event.data_fi || null,
          estat_competicio: event.estat_competicio,
          max_participants: event.max_participants,
          quota_inscripcio: event.quota_inscripcio,
          actiu: event.actiu
        })
        .eq('id', eventId);

      if (updateError) throw updateError;

      // Update categories
      for (const category of categories) {
        const { error: catError } = await supabase
          .from('categories')
          .update({
            nom: category.nom,
            distancia_caramboles: category.distancia_caramboles,
            max_entrades: category.max_entrades,
            min_jugadors: category.min_jugadors,
            max_jugadors: category.max_jugadors,
            promig_minim: category.promig_minim
          })
          .eq('id', category.id);

        if (catError) throw catError;
      }

      successMessage = 'Event actualitzat correctament';
      setTimeout(() => successMessage = null, 3000);

      // Recarregar inscripcions si és campionat social
      if (event.tipus_competicio === 'lliga_social') {
        await loadInscriptions();
      }

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }

  function generateCategoryName(order) {
    return `${order}a`;
  }

  async function addCategory() {
    if (!categories || categories.length === 0) {
      categories = [];
    }

    const nextOrder = Math.max(...categories.map(c => c.ordre_categoria), 0) + 1;
    const lastDistance = categories[categories.length - 1]?.distancia_caramboles || 10;
    const newDistance = Math.max(1, lastDistance - 5);

    // Generar nom intel·ligent considerant distància de caramboles
    const categoryName = generateCategoryName(nextOrder);

    const newCategory = {
      id: null, // Will be created when saving
      event_id: eventId,
      nom: categoryName,
      distancia_caramboles: newDistance,
      max_entrades: 50,
      ordre_categoria: nextOrder,
      min_jugadors: 8,
      max_jugadors: 12,
      promig_minim: null,
      isNew: true
    };

    categories = [...categories, newCategory];
  }

  async function removeCategory(index: number) {
    const category = categories[index];

    if (!category.isNew && category.id) {
      try {
        // Check if category has any classifications
    
        const { data: classifications } = await supabase
          .from('classificacions')
          .select('id')
          .eq('categoria_id', category.id)
          .limit(1);

        if (classifications && classifications.length > 0) {
          error = 'No es pot eliminar una categoria amb jugadors assignats';
          return;
        }

        // Delete from database
        const { error: deleteError } = await supabase
          .from('categories')
          .delete()
          .eq('id', category.id);

        if (deleteError) throw deleteError;
      } catch (e) {
        error = formatSupabaseError(e);
        return;
      }
    }

    // Remove from local array
    categories = categories.filter((_, i) => i !== index);

    // Reorder categories and regenerate names
    categories = categories.map((cat, i) => {
      const newOrder = i + 1;
      const newName = cat.nom.includes('Categoria') ?
        generateCategoryName(newOrder) :
        cat.nom;

      return {
        ...cat,
        ordre_categoria: newOrder,
        nom: newName
      };
    });
  }

  async function saveNewCategories() {
    try {
  

      const newCategories = categories.filter(cat => cat.isNew);

      if (newCategories.length > 0) {
        const categoriesToInsert = newCategories.map(cat => ({
          event_id: eventId,
          nom: cat.nom,
          distancia_caramboles: cat.distancia_caramboles,
          max_entrades: cat.max_entrades,
          ordre_categoria: cat.ordre_categoria,
          min_jugadors: cat.min_jugadors,
          max_jugadors: cat.max_jugadors,
          promig_minim: cat.promig_minim
        }));

        const { data: insertedCategories, error: insertError } = await supabase
          .from('categories')
          .insert(categoriesToInsert)
          .select();

        if (insertError) throw insertError;

        // Update local categories with new IDs
        let insertIndex = 0;
        categories = categories.map(cat => {
          if (cat.isNew) {
            return { ...insertedCategories[insertIndex++], isNew: false };
          }
          return cat;
        });
      }
    } catch (e) {
      throw e;
    }
  }

  async function handleSubmit() {
    try {
      await saveNewCategories();
      await updateEvent();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function handleCalendarError(event) {
    error = event.detail.message;
  }

  function handleCalendarCreated(event) {
    successMessage = `Calendari creat amb ${event.detail.matches} partits programats`;
    setTimeout(() => successMessage = null, 5000);
  }
</script>

<svelte:head>
  <title>{event?.nom || 'Editar Event'} - Administració</title>
</svelte:head>

<div class="max-w-4xl mx-auto p-4">
  <div class="mb-6">
    <div class="flex items-center space-x-4">
      <a href="/admin/events" class="text-gray-600 hover:text-gray-900">
        ← Tornar a Events
      </a>
    </div>
    <h1 class="text-2xl font-semibold text-gray-900 mt-4">
      {#if loading}
        Carregant...
      {:else if event}
        Editar: {event.nom}
      {:else}
        Event no trobat
      {/if}
    </h1>
  </div>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} class="mb-6" />
    <div class="text-center">
      <a href="/admin/events" class="text-blue-600 hover:text-blue-800">
        ← Tornar al llistat d'events
      </a>
    </div>
  {:else if !event}
    <div class="text-center py-12">
      <h3 class="text-lg font-medium text-gray-900">Event no trobat</h3>
      <p class="text-gray-600 mt-2">L'event que cerques no existeix o ha estat eliminat</p>
      <div class="mt-6">
        <a href="/admin/events" class="text-blue-600 hover:text-blue-800">
          ← Tornar al llistat d'events
        </a>
      </div>
    </div>
  {:else}
    {#if successMessage}
      <Banner type="success" message={successMessage} class="mb-6" />
    {/if}

    <form on:submit|preventDefault={handleSubmit} class="space-y-8">
      <!-- Informació Bàsica -->
      <div class="bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Informació Bàsica</h3>

          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label for="nom" class="block text-sm font-medium text-gray-700">Nom de l'Event *</label>
              <input
                type="text"
                id="nom"
                bind:value={event.nom}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                required
              />
            </div>

            <div>
              <label for="temporada" class="block text-sm font-medium text-gray-700">Temporada *</label>
              <input
                type="text"
                id="temporada"
                bind:value={event.temporada}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                required
              />
            </div>

            <div>
              <label for="modalitat" class="block text-sm font-medium text-gray-700">Modalitat *</label>
              <select
                id="modalitat"
                bind:value={event.modalitat}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              >
                {#each Object.entries(modalityNames) as [value, label]}
                  <option {value}>{label}</option>
                {/each}
              </select>
            </div>

            <div>
              <label for="tipus_competicio" class="block text-sm font-medium text-gray-700">Tipus de Competició *</label>
              <select
                id="tipus_competicio"
                bind:value={event.tipus_competicio}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              >
                {#each Object.entries(competitionTypes) as [value, label]}
                  <option {value}>{label}</option>
                {/each}
              </select>
            </div>

            <div>
              <label for="format_joc" class="block text-sm font-medium text-gray-700">Format de Joc</label>
              <select
                id="format_joc"
                bind:value={event.format_joc}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              >
                {#each Object.entries(formatTypes) as [value, label]}
                  <option {value}>{label}</option>
                {/each}
              </select>
            </div>

            <div>
              <label for="estat_competicio" class="block text-sm font-medium text-gray-700">Estat</label>
              <select
                id="estat_competicio"
                bind:value={event.estat_competicio}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              >
                {#each Object.entries(statusNames) as [value, label]}
                  <option {value}>{label}</option>
                {/each}
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Dates i Configuració -->
      <div class="bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Dates i Configuració</h3>

          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label for="data_inici" class="block text-sm font-medium text-gray-700">Data d'Inici</label>
              <input
                type="date"
                id="data_inici"
                bind:value={event.data_inici}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <div>
              <label for="data_fi" class="block text-sm font-medium text-gray-700">Data de Fi</label>
              <input
                type="date"
                id="data_fi"
                bind:value={event.data_fi}
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <div>
              <label for="max_participants" class="block text-sm font-medium text-gray-700">Màxim Participants</label>
              <input
                type="number"
                id="max_participants"
                bind:value={event.max_participants}
                min="1"
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <div>
              <label for="quota_inscripcio" class="block text-sm font-medium text-gray-700">Quota d'Inscripció (€)</label>
              <input
                type="number"
                id="quota_inscripcio"
                bind:value={event.quota_inscripcio}
                min="0"
                step="0.01"
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>

          <div class="mt-4">
            <div class="flex items-center">
              <input
                type="checkbox"
                id="actiu"
                bind:checked={event.actiu}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label for="actiu" class="ml-2 block text-sm text-gray-900">
                Event actiu (visible per als usuaris)
              </label>
            </div>
          </div>
        </div>
      </div>

      <!-- Categories -->
      <div class="bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Categories</h3>
            <button
              type="button"
              on:click={addCategory}
              class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Afegir Categoria
            </button>
          </div>

          {#if categories.length === 0}
            <div class="text-center py-8 text-gray-500">
              <p>No hi ha categories definides</p>
            </div>
          {:else}
            <div class="space-y-4">
              {#each categories as category, index}
                <div class="border border-gray-200 rounded-lg p-4">
                  <div class="flex justify-between items-start mb-3">
                    <h4 class="font-medium text-gray-900">
                      Categoria {category.ordre_categoria}
                      {#if category.isNew}
                        <span class="ml-2 px-2 py-1 text-xs bg-green-100 text-green-800 rounded">Nova</span>
                      {/if}
                    </h4>
                    <button
                      type="button"
                      on:click={() => removeCategory(index)}
                      class="text-red-600 hover:text-red-800 text-sm"
                    >
                      Eliminar
                    </button>
                  </div>

                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    <div>
                      <label for="category-nom-{index}" class="block text-sm font-medium text-gray-700">Nom</label>
                      <input
                        id="category-nom-{index}"
                        type="text"
                        bind:value={category.nom}
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                      />
                    </div>

                    <div>
                      <label for="category-distancia-{index}" class="block text-sm font-medium text-gray-700">Distància (caramboles)</label>
                      <input
                        id="category-distancia-{index}"
                        type="number"
                        bind:value={category.distancia_caramboles}
                        min="1"
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                      />
                    </div>

                    <div>
                      <label for="category-max-entrades-{index}" class="block text-sm font-medium text-gray-700">Màxim Entrades</label>
                      <input
                        id="category-max-entrades-{index}"
                        type="number"
                        bind:value={category.max_entrades}
                        min="1"
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                      />
                    </div>

                    <div>
                      <label for="category-min-jugadors-{index}" class="block text-sm font-medium text-gray-700">Min. Jugadors</label>
                      <input
                        id="category-min-jugadors-{index}"
                        type="number"
                        bind:value={category.min_jugadors}
                        min="1"
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                      />
                    </div>

                    <div>
                      <label for="category-max-jugadors-{index}" class="block text-sm font-medium text-gray-700">Max. Jugadors</label>
                      <input
                        id="category-max-jugadors-{index}"
                        type="number"
                        bind:value={category.max_jugadors}
                        min="1"
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                      />
                    </div>

                    <div>
                      <label for="category-promig-minim-{index}" class="block text-sm font-medium text-gray-700">Promig Mínim Promoció</label>
                      <input
                        id="category-promig-minim-{index}"
                        type="number"
                        bind:value={category.promig_minim}
                        step="0.001"
                        min="0"
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                        placeholder="Opcional"
                      />
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      </div>

      <!-- Generador de Calendaris (només per campionats socials) -->
      {#if event.tipus_competicio === 'lliga_social' && categories.length > 0 && inscriptions.length > 0}
        <CalendarGenerator
          {eventId}
          {categories}
          {inscriptions}
          on:error={handleCalendarError}
          on:calendarCreated={handleCalendarCreated}
        />
      {:else if event.tipus_competicio === 'lliga_social'}
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <div class="flex items-start">
            <svg class="w-5 h-5 text-yellow-400 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 19.5c.77.833 1.732 2.5 3.732 2.5z"/>
            </svg>
            <div>
              <h3 class="text-sm font-medium text-yellow-800">Generador de Calendaris No Disponible</h3>
              <p class="text-sm text-yellow-700 mt-1">
                Per generar el calendari necessites:
                {#if categories.length === 0}• Definir com a mínim una categoria{/if}
                {#if inscriptions.length === 0}• Tenir inscripcions aprovades{/if}
              </p>
            </div>
          </div>
        </div>
      {/if}

      <!-- Submit Button -->
      <div class="flex justify-end space-x-3">
        <a
          href="/admin/events"
          class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          Cancel·lar
        </a>

        <a
          href="/campionats-socials/{event.id}"
          target="_blank"
          class="bg-gray-600 py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white hover:bg-gray-700"
        >
          Veure Event
        </a>

        <button
          type="submit"
          disabled={saving}
          class="ml-3 inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50"
        >
          {#if saving}
            <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Guardant...
          {:else}
            Guardar Canvis
          {/if}
        </button>
      </div>
    </form>
  {/if}
</div>