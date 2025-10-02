<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user, adminStore } from '$lib/stores/auth';
  import { checkIsAdmin } from '$lib/roles';
  import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
  import Banner from '$lib/components/general/Banner.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';

  let loading = false;
  let error: string | null = null;
  let saving = false;

  // Form data
  let formData = {
    nom: '',
    temporada: new Date().getFullYear() + '-' + (new Date().getFullYear() + 1),
    modalitat: 'tres_bandes',
    tipus_competicio: 'lliga_social',
    format_joc: 'lliga',
    data_inici: '',
    data_fi: '',
    estat_competicio: 'planificacio',
    max_participants: null,
    quota_inscripcio: null,
    actiu: true
  };

  // Category configuration - start with no categories (will be created dynamically)
  let categories = [];

  // Option to create categories now or later
  let createCategoriesNow = false;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'lliga_social': 'Campionat Social',
    'handicap': 'Hàndicap',
    'eliminatories': 'Eliminatòries'
  };

  const formatTypes = {
    'lliga': 'Campionat',
    'eliminatoria_simple': 'Eliminatòria Simple',
    'eliminatoria_doble': 'Eliminatòria Doble'
  };

  // Default distances based on modality and category
  const defaultDistances = {
    'tres_bandes': [20, 15, 10],
    'lliure': [60, 50, 40],
    'banda': [50, 40, 30]
  };

  // Default entry limits based on modality
  const defaultEntries = {
    'tres_bandes': 50,
    'lliure': { 1: 40, 2: 50, 3: 50 }, // 1st category has 40, others 50
    'banda': 50
  };

  onMount(async () => {
    const u = $user;
    if (!u?.email) {
      goto('/login');
      return;
    }

    // Check admin status using new store system
    if (!$adminChecked || !$isAdmin) {
      goto('/admin');
      return;
    }

    // Set default season
    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth();

    // Season runs from September to September
    if (currentMonth >= 8) { // September or later
      formData.temporada = currentYear + '-' + (currentYear + 1);
    } else {
      formData.temporada = (currentYear - 1) + '-' + currentYear;
    }

    updateCategoriesForModality();
  });

  function updateCategoriesForModality() {
    const distances = defaultDistances[formData.modalitat];

    categories = categories.map((cat, index) => ({
      ...cat,
      distancia_caramboles: distances[index] || distances[distances.length - 1],
      max_entrades: typeof defaultEntries[formData.modalitat] === 'object'
        ? defaultEntries[formData.modalitat][cat.ordre_categoria] || 50
        : defaultEntries[formData.modalitat]
    }));
  }

  function createDefaultCategories() {
    const distances = getDefaultDistances();
    categories = distances.map((distance, index) => ({
      nom: `${index + 1}a Categoria`,
      distancia_caramboles: distance,
      max_entrades: 50,
      ordre_categoria: index + 1,
      min_jugadors: 8,
      max_jugadors: 12,
      promig_minim: null
    }));
  }

  function generateCategoryName(distance, order, existingCategories) {
    // Comprovar si ja existeix una categoria amb aquesta distància
    const categoriesWithSameDistance = existingCategories.filter(
      cat => cat.distancia_caramboles === distance
    );

    // Determinar el número de categoria basat en l'ordre
    const categoryNumber = order;
    const baseName = `${categoryNumber}a Categoria`;

    // Si no hi ha cap categoria amb aquesta distància, usar nom base
    if (categoriesWithSameDistance.length === 0) {
      return baseName;
    }

    // Si ja existeix una categoria amb aquesta distància, afegir suffix A/B/C...
    const suffix = String.fromCharCode(65 + categoriesWithSameDistance.length); // A=65, B=66, C=67...
    return `${categoryNumber}a ${suffix}`;
  }

  function addCategory() {
    const nextOrder = categories.length > 0 ? Math.max(...categories.map(c => c.ordre_categoria)) + 1 : 1;
    const lastDistance = categories.length > 0 ? categories[categories.length - 1]?.distancia_caramboles || 10 : getDefaultDistances()[0];
    const newDistance = Math.max(1, lastDistance - 5);

    // Generar nom intel·ligent considerant distància de caramboles
    const categoryName = generateCategoryName(newDistance, nextOrder, categories);

    categories = [...categories, {
      nom: categoryName,
      distancia_caramboles: newDistance,
      max_entrades: 50,
      ordre_categoria: nextOrder,
      min_jugadors: 8,
      max_jugadors: 12,
      promig_minim: null
    }];
  }

  function getDefaultDistances() {
    const defaults = {
      'tres_bandes': [20, 15, 10],
      'lliure': [60, 50, 40],
      'banda': [50, 40, 30]
    };
    return defaults[formData.modalitat];
  }

  function removeCategory(index: number) {
    if (categories.length > 1) {
      categories = categories.filter((_, i) => i !== index);
      // Reorder categories and regenerate names
      categories = categories.map((cat, i) => {
        const newOrder = i + 1;
        const newName = generateCategoryName(cat.distancia_caramboles, newOrder, categories.slice(0, i));

        return {
          ...cat,
          ordre_categoria: newOrder,
          nom: newName
        };
      });
    }
  }

  async function handleSubmit() {
    try {
      saving = true;
      error = null;

      // Validation
      if (!formData.nom.trim()) {
        error = 'El nom de l\'event és obligatori';
        return;
      }

      if (!formData.temporada.trim()) {
        error = 'La temporada és obligatòria';
        return;
      }

      if (createCategoriesNow && categories.length === 0) {
        error = 'Si vols crear categories ara, cal definir almenys una categoria';
        return;
      }

      // Validate dates if provided
      if (formData.data_inici && formData.data_fi) {
        if (new Date(formData.data_inici) >= new Date(formData.data_fi)) {
          error = 'La data de fi ha de ser posterior a la data d\'inici';
          return;
        }
      }

      const { supabase } = await import('$lib/supabaseClient');

      // Create event
      const { data: event, error: eventError } = await supabase
        .from('events')
        .insert([{
          nom: formData.nom.trim(),
          temporada: formData.temporada.trim(),
          modalitat: formData.modalitat,
          tipus_competicio: formData.tipus_competicio,
          format_joc: formData.format_joc,
          data_inici: formData.data_inici || null,
          data_fi: formData.data_fi || null,
          estat_competicio: formData.estat_competicio,
          max_participants: formData.max_participants,
          quota_inscripcio: formData.quota_inscripcio,
          actiu: formData.actiu
        }])
        .select()
        .single();

      if (eventError) throw eventError;

      // Create categories only if specified
      if (createCategoriesNow && categories.length > 0) {
        const categoriesData = categories.map(cat => ({
          event_id: event.id,
          nom: cat.nom,
          distancia_caramboles: cat.distancia_caramboles,
          max_entrades: cat.max_entrades,
          ordre_categoria: cat.ordre_categoria,
          min_jugadors: cat.min_jugadors,
          max_jugadors: cat.max_jugadors,
          promig_minim: cat.promig_minim
        }));

        const { error: categoriesError } = await supabase
          .from('categories')
          .insert(categoriesData);

        if (categoriesError) throw categoriesError;
      }

      // Redirect to event details
      goto(`/admin/events/${event.id}`);

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head>
  <title>Nou Event - Administració</title>
</svelte:head>

<div class="max-w-4xl mx-auto p-4">
  <div class="mb-6">
    <div class="flex items-center space-x-4">
      <a
        href="/admin/events"
        class="text-gray-600 hover:text-gray-900"
      >
        ← Tornar a Events
      </a>
    </div>
    <h1 class="text-2xl font-semibold text-gray-900 mt-4">Crear Nou Event</h1>
    <p class="text-gray-600 mt-1">Configura un nou campionat o competició</p>
  </div>

  {#if error}
    <Banner type="error" message={error} class="mb-6" />
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
              bind:value={formData.nom}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              placeholder="Ex: Campionat Social 3 Bandes"
              required
            />
          </div>

          <div>
            <label for="temporada" class="block text-sm font-medium text-gray-700">Temporada *</label>
            <input
              type="text"
              id="temporada"
              bind:value={formData.temporada}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              placeholder="Ex: 2024-2025"
              required
            />
          </div>

          <div>
            <label for="modalitat" class="block text-sm font-medium text-gray-700">Modalitat *</label>
            <select
              id="modalitat"
              bind:value={formData.modalitat}
              on:change={updateCategoriesForModality}
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
              bind:value={formData.tipus_competicio}
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
              bind:value={formData.format_joc}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
            >
              {#each Object.entries(formatTypes) as [value, label]}
                <option {value}>{label}</option>
              {/each}
            </select>
          </div>

          <div>
            <label for="estat_competicio" class="block text-sm font-medium text-gray-700">Estat Inicial</label>
            <select
              id="estat_competicio"
              bind:value={formData.estat_competicio}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="planificacio">Planificació</option>
              <option value="inscripcions">Inscripcions Obertes</option>
              <option value="pendent_validacio">Pendent Validació</option>
              <option value="validat">Validat</option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <!-- Dates i Limits -->
    <div class="bg-white shadow sm:rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Dates i Configuració</h3>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <div>
            <label for="data_inici" class="block text-sm font-medium text-gray-700">Data d'Inici</label>
            <input
              type="date"
              id="data_inici"
              bind:value={formData.data_inici}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div>
            <label for="data_fi" class="block text-sm font-medium text-gray-700">Data de Fi</label>
            <input
              type="date"
              id="data_fi"
              bind:value={formData.data_fi}
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div>
            <label for="max_participants" class="block text-sm font-medium text-gray-700">Màxim Participants</label>
            <input
              type="number"
              id="max_participants"
              bind:value={formData.max_participants}
              min="1"
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              placeholder="Deixa buit per sense límit"
            />
          </div>

          <div>
            <label for="quota_inscripcio" class="block text-sm font-medium text-gray-700">Quota d'Inscripció (€)</label>
            <input
              type="number"
              id="quota_inscripcio"
              bind:value={formData.quota_inscripcio}
              min="0"
              step="0.01"
              class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              placeholder="0.00"
            />
          </div>
        </div>

        <div class="mt-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="actiu"
              bind:checked={formData.actiu}
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
        </div>

        <div class="mb-6">
          <div class="flex items-center space-x-4 mb-4">
            <label class="flex items-center">
              <input
                type="radio"
                bind:group={createCategoriesNow}
                value={false}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300"
              />
              <span class="ml-2 text-sm text-gray-700">Crear categories més tard (segons inscripcions)</span>
            </label>
            <label class="flex items-center">
              <input
                type="radio"
                bind:group={createCategoriesNow}
                value={true}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300"
              />
              <span class="ml-2 text-sm text-gray-700">Crear categories ara</span>
            </label>
          </div>

          {#if createCategoriesNow}
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
              <div class="flex items-start">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm text-blue-700">
                    <strong>Recomanació:</strong> És millor crear les categories després de rebre les inscripcions per ajustar el número segons els participants.
                  </p>
                </div>
              </div>
            </div>

            <div class="flex justify-between items-center mb-4">
              <h4 class="font-medium text-gray-900">Configuració de Categories</h4>
              <div class="space-x-2">
                <button
                  type="button"
                  on:click={createDefaultCategories}
                  class="inline-flex items-center px-3 py-2 border border-blue-300 shadow-sm text-sm leading-4 font-medium rounded-md text-blue-700 bg-blue-50 hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Crear Categories Per Defecte
                </button>
                <button
                  type="button"
                  on:click={addCategory}
                  class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                  Afegir Categoria
                </button>
              </div>
            </div>
          {:else}
            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
              <div class="flex items-start">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm text-green-700">
                    <strong>Perfecte!</strong> Les categories es crearan automàticament segons el nombre d'inscrits i les seves mitjanes històriques.
                  </p>
                </div>
              </div>
            </div>
          {/if}
        </div>

        <div class="space-y-4">
          {#each categories as category, index}
            <div class="border border-gray-200 rounded-lg p-4">
              <div class="flex justify-between items-start mb-3">
                <h4 class="font-medium text-gray-900">Categoria {category.ordre_categoria}</h4>
                {#if categories.length > 1}
                  <button
                    type="button"
                    on:click={() => removeCategory(index)}
                    class="text-red-600 hover:text-red-800 text-sm"
                  >
                    Eliminar
                  </button>
                {/if}
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
                  <label for="new-category-distancia-{index}" class="block text-sm font-medium text-gray-700">Distància (caramboles)</label>
                  <input
                    id="new-category-distancia-{index}"
                    type="number"
                    bind:value={category.distancia_caramboles}
                    min="1"
                    class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                  />
                </div>

                <div>
                  <label for="new-category-max-entrades-{index}" class="block text-sm font-medium text-gray-700">Màxim Entrades</label>
                  <input
                    id="new-category-max-entrades-{index}"
                    type="number"
                    bind:value={category.max_entrades}
                    min="1"
                    class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                  />
                </div>

                <div>
                  <label for="new-category-min-jugadors-{index}" class="block text-sm font-medium text-gray-700">Min. Jugadors</label>
                  <input
                    id="new-category-min-jugadors-{index}"
                    type="number"
                    bind:value={category.min_jugadors}
                    min="1"
                    class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                  />
                </div>

                <div>
                  <label for="new-category-max-jugadors-{index}" class="block text-sm font-medium text-gray-700">Max. Jugadors</label>
                  <input
                    id="new-category-max-jugadors-{index}"
                    type="number"
                    bind:value={category.max_jugadors}
                    min="1"
                    class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
                  />
                </div>

                <div>
                  <label for="new-category-promig-minim-{index}" class="block text-sm font-medium text-gray-700">Promig Mínim Promoció</label>
                  <input
                    id="new-category-promig-minim-{index}"
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
      </div>
    </div>

    <!-- Submit Button -->
    <div class="flex justify-end space-x-3">
      <a
        href="/admin/events"
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
          Creant...
        {:else}
          Crear Event
        {/if}
      </button>
    </div>
  </form>
</div>