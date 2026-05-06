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

<div class="ce-root">
  <header class="ce-mast">
    <a href="/admin" class="ce-back">← Tornar a l'administració</a>
    <div class="editorial-eyebrow">Continguts</div>
    <h1 class="ce-title">Editor de pàgina principal</h1>
    {#if lastUpdated}
      <p class="ce-sub">Última actualització: {lastUpdated.toLocaleString('ca-ES')}</p>
    {/if}
  </header>

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

<style>
  .ce-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .ce-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .ce-back {
    display: inline-block;
    color: var(--ink-2, #4a443e);
    text-decoration: none;
    font-size: 0.875rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }
  .ce-back:hover { color: var(--ink, #1a1814); }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .ce-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .ce-sub {
    margin: 0;
    font-size: 0.875rem;
    color: var(--ink-3, #807a72);
  }

  .ce-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .ce-root :global(.bg-gray-50),
  .ce-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .ce-root :global(.bg-blue-50),
  .ce-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .ce-root :global(.bg-blue-600),
  .ce-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .ce-root :global(.text-gray-500),
  .ce-root :global(.text-gray-600),
  .ce-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .ce-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .ce-root :global(.text-blue-600),
  .ce-root :global(.text-blue-800) { color: var(--ink, #1a1814) !important; }
  .ce-root :global(.border-gray-200),
  .ce-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .ce-root :global(.rounded),
  .ce-root :global(.rounded-md),
  .ce-root :global(.rounded-lg),
  .ce-root :global(.rounded-xl) { border-radius: 0 !important; }
  .ce-root :global(.shadow),
  .ce-root :global(.shadow-sm),
  .ce-root :global(.shadow-md) { box-shadow: none !important; }
  .ce-root :global(input),
  .ce-root :global(textarea),
  .ce-root :global(select) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .ce-root :global(input:focus),
  .ce-root :global(textarea:focus),
  .ce-root :global(select:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
</style>
