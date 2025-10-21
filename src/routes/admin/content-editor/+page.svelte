<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { goto } from '$app/navigation';
  import { isAdmin, adminChecked } from '$lib/stores/adminAuth';

  let loading = true;
  let saving = false;
  let error: string | null = null;
  let success: string | null = null;
  let selectedPage = 'home_main';
  let title = '';
  let content = '';
  let lastUpdated: Date | null = null;

  const pages = [
    { key: 'home_main', label: 'Contingut Principal' },
    { key: 'horaris', label: 'Horaris d\'obertura' },
    { key: 'normes_obligatories', label: 'Normes Obligatòries' },
    { key: 'prohibicions', label: 'Prohibicions' },
    { key: 'normes_inscripcio', label: 'Inscripció a les partides' },
    { key: 'normes_assignacio', label: 'Assignació de taula' },
    { key: 'normes_temps', label: 'Temps de joc' },
    { key: 'normes_repetir', label: 'Tornar a jugar' },
    { key: 'serveis_soci', label: 'Serveis al Soci' }
  ];

  onMount(async () => {
    await loadContent();
  });

  $: if ($adminChecked && !$isAdmin) {
    goto('/admin');
  }

  async function handlePageChange() {
    await loadContent();
  }

  async function loadContent() {
    loading = true;
    error = null;
    success = null;
    try {
      const { data, error: loadError } = await supabase
        .from('page_content')
        .select('*')
        .eq('page_key', selectedPage)
        .single();
      if (loadError) throw loadError;
      if (data) {
        title = data.title || '';
        content = data.content || '';
        lastUpdated = data.updated_at ? new Date(data.updated_at) : null;
      }
    } catch (e: any) {
      console.error('Error loading content:', e);
      error = 'Error carregant el contingut: ' + e.message;
    } finally {
      loading = false;
    }
  }

  async function saveContent() {
    if (!$isAdmin) {
      error = 'No tens permisos per guardar canvis';
      return;
    }
    saving = true;
    error = null;
    success = null;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      const { error: saveError } = await supabase
        .from('page_content')
        .update({ title, content, updated_by: user?.id })
        .eq('page_key', selectedPage);
      if (saveError) throw saveError;
      success = 'Contingut guardat correctament!';
      lastUpdated = new Date();
      setTimeout(() => { success = null; }, 3000);
    } catch (e: any) {
      console.error('Error saving content:', e);
      error = 'Error guardant el contingut: ' + e.message;
    } finally {
      saving = false;
    }
  }
</script>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="mb-6">
      <a href="/admin" class="text-blue-600 hover:text-blue-800 flex items-center gap-2 mb-4">
        ← Tornar a l'administració
      </a>
      <h1 class="text-3xl font-bold text-gray-900">Editor de Contingut</h1>
      {#if lastUpdated}
        <p class="text-sm text-gray-500 mt-2">
          Última actualització: {lastUpdated.toLocaleString('ca-ES')}
        </p>
      {/if}
    </div>

    {#if !$adminChecked}
      <div class="flex justify-center items-center h-64">
        <div class="text-gray-500">Verificant permisos...</div>
      </div>
    {:else if !$isAdmin}
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <p class="text-red-800 font-medium">⛔ No tens permisos per accedir a aquesta pàgina</p>
      </div>
    {:else if loading}
      <div class="flex justify-center items-center h-64">
        <div class="text-gray-500">Carregant...</div>
      </div>
    {:else}
      {#if error}
        <div class="mb-4 bg-red-50 border border-red-200 rounded-lg p-4">
          <p class="text-red-800">{error}</p>
        </div>
      {/if}
      {#if success}
        <div class="mb-4 bg-green-50 border border-green-200 rounded-lg p-4">
          <p class="text-green-800">✓ {success}</p>
        </div>
      {/if}

      <div class="mb-4">
        <label for="pageSelect" class="block text-sm font-medium text-gray-700 mb-2">
          Selecciona la secció a editar:
        </label>
        <select
          id="pageSelect"
          bind:value={selectedPage}
          on:change={handlePageChange}
          class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        >
          {#each pages as page}
            <option value={page.key}>{page.label}</option>
          {/each}
        </select>
      </div>

      <div class="bg-white rounded-lg shadow-sm border border-gray-200">
        <div class="p-6 space-y-6">
          <div>
            <label for="title" class="block text-sm font-medium text-gray-700 mb-2">Títol</label>
            <input id="title" type="text" bind:value={title}
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Títol..."/>
          </div>
          <div>
            <label for="content" class="block text-sm font-medium text-gray-700 mb-2">Contingut (HTML)</label>
            <textarea id="content" bind:value={content} rows="20"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono text-sm"
              placeholder="Contingut en HTML..."></textarea>
            <p class="mt-2 text-sm text-gray-500">
              Pots utilitzar HTML: &lt;h2&gt;, &lt;p&gt;, &lt;ul&gt;, &lt;li&gt;, &lt;strong&gt;, &lt;em&gt;, etc.
            </p>
          </div>
          <div class="flex gap-3 pt-4 border-t border-gray-200">
            <button on:click={saveContent} disabled={saving}
              class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed font-medium">
              {saving ? 'Guardant...' : 'Guardar canvis'}
            </button>
            <a href="/" target="_blank" class="px-6 py-2 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 font-medium">
              Veure pàgina real
            </a>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>
