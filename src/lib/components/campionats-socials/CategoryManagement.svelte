<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let categories: any[] = [];
  export let inscriptions: any[] = [];

  let newCategoryName = '';
  let newCategoryDistance = 50;
  let newCategoryMaxEntries = 50;
  let newCategoryMinPlayers = 8;
  let newCategoryMaxPlayers = 12;
  let creating = false;
  let showCreateForm = false;

  async function createCategory() {
    if (!newCategoryName.trim()) {
      alert('El nom de la categoria és obligatori');
      return;
    }

    creating = true;
    try {
      // Calculate the next order number
      const nextOrder = categories.length > 0 ? Math.max(...categories.map(c => c.ordre_categoria || 0)) + 1 : 1;

      const { data, error } = await supabase
        .from('categories')
        .insert([{
          event_id: eventId,
          nom: newCategoryName.trim(),
          distancia_caramboles: newCategoryDistance,
          max_entrades: newCategoryMaxEntries,
          ordre_categoria: nextOrder,
          min_jugadors: newCategoryMinPlayers,
          max_jugadors: newCategoryMaxPlayers
        }])
        .select();

      if (error) throw error;

      console.log('Category created:', data);

      // Reset form
      newCategoryName = '';
      newCategoryDistance = 50;
      newCategoryMaxEntries = 50;
      newCategoryMinPlayers = 8;
      newCategoryMaxPlayers = 12;
      showCreateForm = false;

      dispatch('categoryCreated');
    } catch (error) {
      console.error('Error creating category:', error);
      alert('Error creant la categoria: ' + error.message);
    } finally {
      creating = false;
    }
  }

  async function deleteCategory(categoryId: string, categoryName: string) {
    // Check if any players are assigned to this category
    const playersInCategory = inscriptions.filter(i => i.categoria_assignada_id === categoryId);

    if (playersInCategory.length > 0) {
      if (!confirm(`La categoria "${categoryName}" té ${playersInCategory.length} jugadors assignats. Si l'elimines, aquests jugadors quedaran sense categoria. Vols continuar?`)) {
        return;
      }
    } else {
      if (!confirm(`Estàs segur que vols eliminar la categoria "${categoryName}"?`)) {
        return;
      }
    }

    try {
      // First, remove category assignments from inscriptions
      if (playersInCategory.length > 0) {
        const { error: updateError } = await supabase
          .from('inscripcions')
          .update({ categoria_assignada_id: null })
          .eq('categoria_assignada_id', categoryId);

        if (updateError) throw updateError;
      }

      // Then delete the category
      const { error } = await supabase
        .from('categories')
        .delete()
        .eq('id', categoryId);

      if (error) throw error;

      dispatch('categoryDeleted');
    } catch (error) {
      console.error('Error deleting category:', error);
      alert('Error eliminant la categoria: ' + error.message);
    }
  }

  async function updateCategoryOrder(categoryId: string, newOrder: number) {
    try {
      const { error } = await supabase
        .from('categories')
        .update({ ordre_categoria: newOrder })
        .eq('id', categoryId);

      if (error) throw error;

      dispatch('categoryUpdated');
    } catch (error) {
      console.error('Error updating category order:', error);
      alert('Error actualitzant l\'ordre: ' + error.message);
    }
  }

  function moveCategory(categoryId: string, direction: 'up' | 'down') {
    const currentCategory = categories.find(c => c.id === categoryId);
    if (!currentCategory) return;

    const currentOrder = currentCategory.ordre_categoria || 0;
    const targetOrder = direction === 'up' ? currentOrder - 1 : currentOrder + 1;

    // Find category with target order
    const targetCategory = categories.find(c => (c.ordre_categoria || 0) === targetOrder);

    if (targetCategory) {
      // Swap orders
      updateCategoryOrder(categoryId, targetOrder);
      updateCategoryOrder(targetCategory.id, currentOrder);
    }
  }

  function getPlayersInCategory(categoryId: string) {
    return inscriptions.filter(i => i.categoria_assignada_id === categoryId);
  }
</script>

<div class="space-y-6">
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="flex items-center justify-between mb-4">
      <h3 class="text-lg font-medium text-gray-900 flex items-center">
        <span class="mr-2">📂</span>
        Gestió Individual de Categories
      </h3>
      <button
        on:click={() => showCreateForm = !showCreateForm}
        class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
      >
        {#if showCreateForm}
          Cancel·lar
        {:else}
          ➕ Nova Categoria
        {/if}
      </button>
    </div>

    <!-- Create new category form -->
    {#if showCreateForm}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
        <h4 class="font-medium text-blue-900 mb-4">Crear Nova Categoria</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div>
            <label for="new-category-name" class="block text-sm font-medium text-gray-700 mb-1">Nom de la categoria</label>
            <input
              id="new-category-name"
              type="text"
              bind:value={newCategoryName}
              placeholder="Ex: 1a, 2a, Promoció..."
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label for="new-category-distance" class="block text-sm font-medium text-gray-700 mb-1">Distància (caramboles)</label>
            <input
              id="new-category-distance"
              type="number"
              bind:value={newCategoryDistance}
              min="30"
              max="100"
              step="5"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label for="new-category-max-entries" class="block text-sm font-medium text-gray-700 mb-1">Màxim entrades</label>
            <input
              id="new-category-max-entries"
              type="number"
              bind:value={newCategoryMaxEntries}
              min="20"
              max="100"
              step="5"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label for="new-category-min-players" class="block text-sm font-medium text-gray-700 mb-1">Mínim jugadors</label>
            <input
              id="new-category-min-players"
              type="number"
              bind:value={newCategoryMinPlayers}
              min="4"
              max="20"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label for="new-category-max-players" class="block text-sm font-medium text-gray-700 mb-1">Màxim jugadors</label>
            <input
              id="new-category-max-players"
              type="number"
              bind:value={newCategoryMaxPlayers}
              min="6"
              max="30"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div class="flex items-end">
            <button
              on:click={createCategory}
              disabled={creating}
              class="w-full px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 disabled:bg-gray-400"
            >
              {creating ? 'Creant...' : 'Crear Categoria'}
            </button>
          </div>
        </div>
      </div>
    {/if}

    <!-- Categories list -->
    {#if categories.length === 0}
      <div class="text-center py-8">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14-7H5m14 14H5"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha categories</h3>
        <p class="mt-1 text-sm text-gray-500">Crea la primera categoria per començar.</p>
      </div>
    {:else}
      <div class="space-y-3">
        {#each categories.sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0)) as category, index (category.id)}
          {@const playersInCategory = getPlayersInCategory(category.id)}
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
            <div class="flex items-center justify-between">
              <div class="flex-1">
                <div class="flex items-center space-x-4">
                  <div>
                    <h4 class="font-medium text-gray-900">{category.nom}</h4>
                    <div class="text-sm text-gray-500">
                      {category.distancia_caramboles} caramboles •
                      {category.min_jugadors}-{category.max_jugadors} jugadors •
                      Màx. {category.max_entrades} entrades
                    </div>
                  </div>
                  <div class="text-sm">
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      {playersInCategory.length} inscrits
                    </span>
                  </div>
                </div>
              </div>

              <div class="flex items-center space-x-2">
                <!-- Move up/down buttons -->
                <div class="flex flex-col">
                  <button
                    on:click={() => moveCategory(category.id, 'up')}
                    disabled={index === 0}
                    class="p-1 text-gray-400 hover:text-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
                    title="Moure amunt"
                    aria-label="Moure categoria amunt"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
                    </svg>
                  </button>
                  <button
                    on:click={() => moveCategory(category.id, 'down')}
                    disabled={index === categories.length - 1}
                    class="p-1 text-gray-400 hover:text-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
                    title="Moure avall"
                    aria-label="Moure categoria avall"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                    </svg>
                  </button>
                </div>

                <!-- Delete button -->
                <button
                  on:click={() => deleteCategory(category.id, category.nom)}
                  class="p-2 text-red-600 hover:text-red-900 hover:bg-red-50 rounded"
                  title="Eliminar categoria"
                  aria-label="Eliminar categoria"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Show players in category if any -->
            {#if playersInCategory.length > 0}
              <div class="mt-3 pt-3 border-t border-gray-200">
                <div class="text-xs text-gray-500 mb-2">Jugadors assignats:</div>
                <div class="flex flex-wrap gap-1">
                  {#each playersInCategory as inscription}
                    {@const sociInfo = inscription.socis || { nom: 'Desconegut', cognoms: '' }}
                    <span class="inline-flex items-center px-2 py-1 rounded text-xs bg-white border border-gray-200 text-gray-700">
                      {sociInfo.nom} {sociInfo.cognoms}
                    </span>
                  {/each}
                </div>
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>