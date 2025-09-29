<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user, adminStore } from '$lib/stores/auth';
  import { checkIsAdmin } from '$lib/roles';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;
  let saving = false;

  type Event = {
    id: string;
    nom: string;
    modalitat: string;
    tipus_competicio: string;
    estat_competicio: string;
  };

  type Category = {
    id: string;
    event_id: string;
    nom: string;
    distancia_caramboles: number;
    max_entrades: number;
    ordre_categoria: number;
    promig_minim: number | null;
    min_jugadors: number;
    max_jugadors: number;
  };

  let events: Event[] = [];
  let selectedEventId: string = '';
  let categories: Category[] = [];
  let successMessage: string | null = null;

  onMount(async () => {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        goto('/login');
        return;
      }

      const adm = await checkIsAdmin();
      if (!adm) {
        error = errText('Només els administradors poden accedir a aquesta pàgina.');
        return;
      }

      await loadEvents();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadEvents() {
    const { supabase } = await import('$lib/supabaseClient');
    const { data, error: eventsError } = await supabase
      .from('events')
      .select('id, nom, modalitat, tipus_competicio, estat_competicio')
      .in('tipus_competicio', ['lliga_social', 'handicap'])
      .order('nom');

    if (eventsError) throw eventsError;
    events = data || [];

    if (events.length > 0 && !selectedEventId) {
      selectedEventId = events[0].id;
      await loadCategories();
    }
  }

  async function loadCategories() {
    if (!selectedEventId) return;

    const { supabase } = await import('$lib/supabaseClient');
    const { data, error: categoriesError } = await supabase
      .from('categories')
      .select('*')
      .eq('event_id', selectedEventId)
      .order('ordre_categoria');

    if (categoriesError) throw categoriesError;
    categories = data || [];
  }

  async function handleEventChange() {
    if (selectedEventId) {
      await loadCategories();
    } else {
      categories = [];
    }
  }

  async function updatePromigMinim(categoryId: string, newPromig: number | null) {
    try {
      saving = true;
      successMessage = null;
      error = null;

      const { supabase } = await import('$lib/supabaseClient');
      const { error: updateError } = await supabase
        .from('categories')
        .update({ promig_minim: newPromig })
        .eq('id', categoryId);

      if (updateError) throw updateError;

      // Update local state
      categories = categories.map(cat =>
        cat.id === categoryId
          ? { ...cat, promig_minim: newPromig }
          : cat
      );

      successMessage = 'Promig mínim actualitzat correctament';
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }

  async function viewPromotions() {
    if (!selectedEventId) return;

    try {
      const { supabase } = await import('$lib/supabaseClient');
      const { data: promotions, error: promotionsError } = await supabase
        .rpc('get_eligible_promotions', { event_id_param: selectedEventId });

      if (promotionsError) throw promotionsError;

      console.log('Promocions elegibles:', promotions);

      if (promotions && promotions.length > 0) {
        const promotionsList = promotions
          .map(p => `${p.player_name} (${p.current_category_name} → ${p.target_category_name}) - Mitjana: ${p.current_average} ${p.meets_minimum ? '✅' : '❌'}`)
          .join('\n');

        alert(`Promocions elegibles:\n\n${promotionsList}`);
      } else {
        alert('No hi ha promocions elegibles per aquest esdeveniment');
      }
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function handlePromigInput(categoryId: string, event: Event & { currentTarget: HTMLInputElement }) {
    const input = event.currentTarget;
    const value = input.value === '' ? null : parseFloat(input.value);

    if (value !== null && (isNaN(value) || value < 0)) {
      input.value = categories.find(c => c.id === categoryId)?.promig_minim?.toString() || '';
      return;
    }

    updatePromigMinim(categoryId, value);
  }
</script>

<svelte:head>
  <title>Gestió Categories i Promocions</title>
</svelte:head>

<div class="max-w-6xl mx-auto p-4">
  <h1 class="text-2xl font-semibold mb-4">Gestió Categories i Promocions</h1>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
  {:else if $adminStore}
    {#if successMessage}
      <Banner type="success" message={successMessage} class="mb-4" />
    {/if}

    <!-- Selector d'esdeveniment -->
    <div class="mb-6">
      <label for="event-selector" class="block text-sm font-medium mb-2">Esdeveniment:</label>
      <select
        id="event-selector"
        bind:value={selectedEventId}
        on:change={handleEventChange}
        class="w-full max-w-md rounded-xl border px-3 py-2"
      >
        <option value="">Selecciona un esdeveniment...</option>
        {#each events as event}
          <option value={event.id}>
            {event.nom} ({event.modalitat} - {event.tipus_competicio})
          </option>
        {/each}
      </select>
    </div>

    {#if selectedEventId && categories.length > 0}
      <!-- Informació sobre promocions -->
      <div class="mb-6 bg-blue-50 border border-blue-200 rounded-xl p-4">
        <h2 class="font-semibold text-blue-800 mb-2">📈 Sistema de Promocions</h2>
        <p class="text-sm text-blue-700 mb-3">
          Els dos primers classificats de cada categoria tenen dret a pujar a la categoria superior
          la temporada següent si compleixen el promig mínim configurat.
          Si el promig mínim és nul (buit), no hi ha restriccions.
        </p>
        <button
          on:click={viewPromotions}
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700"
        >
          🔍 Veure promocions elegibles
        </button>
      </div>

      <!-- Taula de categories -->
      <div class="bg-white rounded-xl border overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-sm font-medium text-gray-900">Categoria</th>
              <th class="px-4 py-3 text-left text-sm font-medium text-gray-900">Ordre</th>
              <th class="px-4 py-3 text-left text-sm font-medium text-gray-900">Distància</th>
              <th class="px-4 py-3 text-left text-sm font-medium text-gray-900">Max Entrades</th>
              <th class="px-4 py-3 text-left text-sm font-medium text-gray-900">Jugadors (min-max)</th>
              <th class="px-4 py-3 text-left text-sm font-medium text-gray-900">Promig Mínim per Promoció</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            {#each categories as category}
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 font-medium text-gray-900">{category.nom}</td>
                <td class="px-4 py-3 text-gray-600">{category.ordre_categoria}ª</td>
                <td class="px-4 py-3 text-gray-600">{category.distancia_caramboles} caramboles</td>
                <td class="px-4 py-3 text-gray-600">{category.max_entrades} entrades</td>
                <td class="px-4 py-3 text-gray-600">{category.min_jugadors}-{category.max_jugadors}</td>
                <td class="px-4 py-3">
                  <div class="flex items-center space-x-2">
                    <input
                      type="number"
                      step="0.001"
                      min="0"
                      placeholder="Sense mínim"
                      value={category.promig_minim || ''}
                      on:blur={(e) => handlePromigInput(category.id, e)}
                      on:keydown={(e) => e.key === 'Enter' && handlePromigInput(category.id, e)}
                      class="w-24 px-2 py-1 text-sm border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                      disabled={saving}
                    />
                    {#if category.ordre_categoria === 1}
                      <span class="text-xs text-gray-500">(1ª categoria - no pot pujar)</span>
                    {:else if category.promig_minim}
                      <span class="text-xs text-green-600">✅ Mínim: {category.promig_minim}</span>
                    {:else}
                      <span class="text-xs text-gray-500">Sense restricció</span>
                    {/if}
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Explicació adicional -->
      <div class="mt-6 bg-gray-50 rounded-xl p-4">
        <h3 class="font-medium mb-2">ℹ️ Com funciona:</h3>
        <ul class="text-sm text-gray-700 space-y-1">
          <li><strong>Promig Mínim:</strong> Mitjana mínima requerida per poder pujar de categoria</li>
          <li><strong>Buit/Nul:</strong> Significa que no hi ha restricció de mitjana</li>
          <li><strong>1ª Categoria:</strong> No pot pujar més (és la categoria màxima)</li>
          <li><strong>Promoció automàtica:</strong> Es pot aplicar quan es crea una nova temporada</li>
        </ul>
      </div>
    {:else if selectedEventId}
      <div class="text-center py-8 text-gray-500">
        No hi ha categories configurades per aquest esdeveniment
      </div>
    {:else}
      <div class="text-center py-8 text-gray-500">
        Selecciona un esdeveniment per veure les seves categories
      </div>
    {/if}
  {/if}
</div>