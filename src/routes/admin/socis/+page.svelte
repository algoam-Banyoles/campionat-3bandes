<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';

  let loading = false;
  let error: string | null = null;
  let socis: any[] = [];
  let downloading = false;

  onMount(async () => {
    await loadSocis();
  });

  async function loadSocis() {
    try {
      loading = true;
      error = null;

      const { data, error: supabaseError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms, de_baixa')
        .order('numero_soci');

      if (supabaseError) {
        throw supabaseError;
      }

      socis = data || [];
    } catch (e: any) {
      error = formatSupabaseError(e);
      socis = [];
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(nom: string, cognoms: string): string {
    if (!nom || !cognoms) return 'NOM INCOMPLET';

    // Obtenir primera inicial del nom
    const inicialNom = nom.charAt(0).toUpperCase();

    // Obtenir primer cognom (dividir per espais i agafar el primer) i posar-lo en majúscules
    const primerCognom = cognoms.split(' ')[0].toUpperCase();

    return `${inicialNom}. ${primerCognom}`;
  }

  async function downloadCSV() {
    try {
      downloading = true;

      // Capçalera del CSV
      const headers = ['Número Soci', 'Nom'];

      // Convertir dades a format CSV
      const rows = socis.map(soci => [
        soci.numero_soci,
        formatPlayerName(soci.nom, soci.cognoms || '')
      ]);

      // Combinar capçalera i files
      const csvContent = [headers, ...rows]
        .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
        .join('\n');

      // Crear i descarregar l'arxiu
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');

      if (link.download !== undefined) {
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `llistat_socis_${new Date().toISOString().split('T')[0]}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    } catch (e: any) {
      error = formatSupabaseError(e);
    } finally {
      downloading = false;
    }
  }
</script>

<svelte:head>
  <title>Socis - Administració</title>
</svelte:head>

<div class="max-w-6xl mx-auto p-4">
  <div class="mb-6">
    <h1 class="text-2xl font-semibold text-gray-900">Socis</h1>
    <p class="mt-2 text-gray-600">Llistat de jugadors i informació bàsica.</p>
  </div>

  <!-- Actions -->
  <div class="mb-6 flex items-center justify-between">
    <div class="flex items-center space-x-4">
      <button
        on:click={loadSocis}
        disabled={loading}
        class="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50"
      >
        {#if loading}
          <div class="flex items-center space-x-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
            <span>Carregant...</span>
          </div>
        {:else}
          Actualitzar
        {/if}
      </button>

      <button
        on:click={downloadCSV}
        disabled={downloading || socis.length === 0}
        class="bg-green-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-green-700 disabled:opacity-50"
      >
        {#if downloading}
          <div class="flex items-center space-x-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
            <span>Descarregant...</span>
          </div>
        {:else}
          📥 Descarregar CSV
        {/if}
      </button>
    </div>

    <div class="text-sm text-gray-600">
      Total socis: <span class="font-medium">{socis.length}</span>
      <span class="ml-2">
        (Actius: {socis.filter(s => !s.de_baixa).length}, De baixa: {socis.filter(s => s.de_baixa).length})
      </span>
    </div>
  </div>

  <!-- Error display -->
  {#if error}
    <div class="mb-6 bg-red-50 border border-red-200 rounded-lg p-4">
      <p class="text-red-700">{error}</p>
    </div>
  {/if}

  <!-- Preview of data -->
  {#if !loading && socis.length > 0}
    <div class="bg-white shadow rounded-lg overflow-hidden">
      <div class="bg-gray-50 px-6 py-4 border-b">
        <h2 class="text-lg font-medium text-gray-900">Vista Prèvia del Llistat</h2>
        <p class="text-sm text-gray-600 mt-1">Format: Número Soci | Inicial + Primer Cognom en Majúscules</p>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Número Soci
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Nom Formatat
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Nom Complet (Referència)
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Estat
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each socis.slice(0, 20) as soci}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {soci.numero_soci}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">
                  {formatPlayerName(soci.nom, soci.cognoms || '')}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {soci.nom} {soci.cognoms || ''}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {soci.de_baixa ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'}">
                    {soci.de_baixa ? 'De baixa' : 'Actiu'}
                  </span>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      {#if socis.length > 20}
        <div class="bg-gray-50 px-6 py-3 border-t">
          <p class="text-sm text-gray-600">
            Mostrant els primers 20 registres de {socis.length} total. Descarrega el CSV per veure'ls tots.
          </p>
        </div>
      {/if}
    </div>
  {:else if !loading && socis.length === 0}
    <div class="text-center py-12">
      <p class="text-gray-500">No s'han trobat socis.</p>
    </div>
  {/if}

  <!-- Loading state -->
  {#if loading}
    <div class="flex justify-center py-12">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
    </div>
  {/if}
</div>
