<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import PlayerRestrictionsEditor from '$lib/components/general/PlayerRestrictionsEditor.svelte';

  const dispatch = createEventDispatcher();

  export const eventId: string = '';
  export let inscriptions: any[] = [];
  export let socis: any[] = [];
  export let categories: any[] = [];

  let selectedInscription: any = null;
  let showModal = false;
  let loading = false;

  // Funcions d'ajuda
  function getSociInfo(inscription) {
    if (inscription.socis) {
      return {
        nom: inscription.socis.nom,
        cognoms: inscription.socis.cognoms,
        numero_soci: inscription.socis.numero_soci,
        email: inscription.socis.email
      };
    }

    const soci = socis.find(s => s.numero_soci === inscription.soci_numero);
    return soci || { nom: 'Desconegut', cognoms: '', numero_soci: inscription.soci_numero };
  }

  function getCategoryName(categoryId) {
    const category = categories.find(c => c.id === categoryId);
    return category?.nom || 'Sense categoria';
  }

  function formatDays(days) {
    if (!days || days.length === 0) return 'Tots els dies';

    const dayNames = {
      'dl': 'Dll',
      'dt': 'Dmt',
      'dc': 'Dmc',
      'dj': 'Djs',
      'dv': 'Dvs',
      'ds': 'Dss',
      'dg': 'Dmg'
    };

    return days.map(d => dayNames[d] || d).join(', ');
  }

  function formatHours(hours) {
    if (!hours || hours.length === 0) return 'Totes les hores';
    return hours.join(', ');
  }

  /**
   * Estat agregat d'un jugador: retirat, desqualificat o actiu.
   * Es deriva dels camps de la inscripció (no requereix cap query).
   */
  function getPlayerStatus(inscription: any): {
    code: 'disqualified' | 'withdrawn' | 'active';
    label: string;
    badgeClass: string;
    title: string;
  } {
    if (inscription.eliminat_per_incompareixences === true) {
      return {
        code: 'disqualified',
        label: 'DQF',
        badgeClass: 'bg-red-100 text-red-800',
        title: 'Desqualificat per incompareixences acumulades'
      };
    }
    if (inscription.estat_jugador === 'retirat') {
      return {
        code: 'withdrawn',
        label: 'Retirat',
        badgeClass: 'bg-orange-100 text-orange-800',
        title: inscription.motiu_retirada || 'Jugador retirat de la competició'
      };
    }
    return {
      code: 'active',
      label: 'Actiu',
      badgeClass: 'bg-green-100 text-green-800',
      title: 'Jugador en competició'
    };
  }

  function openRestrictionsModal(inscription) {
    selectedInscription = inscription;
    showModal = true;
  }

  function handleRestrictionsUpdated() {
    // Reload inscriptions to get updated data
    dispatch('restrictionsUpdated');
    showModal = false;
    selectedInscription = null;
  }

  function handleModalClose() {
    showModal = false;
    selectedInscription = null;
  }

  async function quickUpdateAvailability(inscriptionId, field, value) {
    loading = true;
    try {
      const { error } = await supabase
        .from('inscripcions')
        .update({ [field]: value })
        .eq('id', inscriptionId);

      if (error) throw error;

      dispatch('restrictionsUpdated');
    } catch (error) {
      console.error('Error updating availability:', error);
      alert('Error actualitzant disponibilitat: ' + error.message);
    } finally {
      loading = false;
    }
  }
</script>

<div class="space-y-6">
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
      <span class="mr-2">🚫</span>
      Gestió de Restriccions i Disponibilitats
    </h3>

    <p class="text-sm text-gray-600 mb-6">
      Configura les disponibilitats i restriccions de cada jugador inscrit per optimitzar la generació del calendari.
    </p>

    {#if inscriptions.length === 0}
      <div class="text-center py-8">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha jugadors inscrits</h3>
        <p class="mt-1 text-sm text-gray-500">Primer cal inscriure jugadors per gestionar les seves restriccions.</p>
      </div>
    {:else}
      <!-- Taula de restriccions -->
      <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
        <table class="min-w-full divide-y divide-gray-300">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                Jugador
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Estat
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Categoria
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Dies Preferits
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Hores Preferides
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Restriccions Especials
              </th>
              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                <span class="sr-only">Accions</span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            {#each inscriptions as inscription (inscription.id)}
              {@const sociInfo = getSociInfo(inscription)}
              {@const status = getPlayerStatus(inscription)}
              <tr class="hover:bg-gray-50" class:opacity-60={status.code !== 'active'}>
                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                  <div class="flex items-center">
                    <div>
                      <div class="font-medium text-gray-900" class:line-through={status.code !== 'active'}>
                        {sociInfo.nom} {sociInfo.cognoms}
                      </div>
                      <div class="text-gray-500">
                        Soci #{sociInfo.numero_soci}
                      </div>
                    </div>
                  </div>
                </td>
                <td class="whitespace-nowrap px-3 py-4 text-sm">
                  <span
                    class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {status.badgeClass}"
                    title={status.title}
                  >
                    {status.label}
                  </span>
                </td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    {getCategoryName(inscription.categoria_assignada_id)}
                  </span>
                </td>
                <td class="px-3 py-4 text-sm text-gray-500">
                  <div class="max-w-xs">
                    {formatDays(inscription.preferencies_dies)}
                  </div>
                </td>
                <td class="px-3 py-4 text-sm text-gray-500">
                  <div class="max-w-xs">
                    {formatHours(inscription.preferencies_hores)}
                  </div>
                </td>
                <td class="px-3 py-4 text-sm text-gray-500">
                  <div class="max-w-xs truncate" title={inscription.restriccions_especials || ''}>
                    {inscription.restriccions_especials || 'Cap restricció'}
                  </div>
                </td>
                <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                  <button
                    on:click={() => openRestrictionsModal(inscription)}
                    class="text-blue-600 hover:text-blue-900 disabled:text-gray-400 disabled:cursor-not-allowed"
                    disabled={loading || status.code !== 'active'}
                    title={status.code === 'active' ? 'Editar restriccions' : 'No es pot editar: ' + status.title}
                  >
                    Editar
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Resum estadístic -->
      {@const activeCount = inscriptions.filter(i => getPlayerStatus(i).code === 'active').length}
      {@const disqualifiedCount = inscriptions.filter(i => i.eliminat_per_incompareixences === true).length}
      {@const withdrawnCount = inscriptions.filter(i => i.estat_jugador === 'retirat' && !i.eliminat_per_incompareixences).length}
      {@const withRestrictionsCount = inscriptions.filter(i => i.preferencies_dies?.length > 0 || i.preferencies_hores?.length > 0 || i.restriccions_especials).length}
      {@const noCategoryCount = inscriptions.filter(i => !i.categoria_assignada_id).length}
      <div class="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-4">
            <dl>
              <dt class="text-xs font-medium text-gray-500 truncate">Total Inscrits</dt>
              <dd class="text-2xl font-semibold text-gray-900">{inscriptions.length}</dd>
            </dl>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-green-400">
          <div class="p-4">
            <dl>
              <dt class="text-xs font-medium text-gray-500 truncate">Actius</dt>
              <dd class="text-2xl font-semibold text-green-700">{activeCount}</dd>
            </dl>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-orange-400">
          <div class="p-4">
            <dl>
              <dt class="text-xs font-medium text-gray-500 truncate">Retirats</dt>
              <dd class="text-2xl font-semibold text-orange-700">{withdrawnCount}</dd>
            </dl>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-red-400">
          <div class="p-4">
            <dl>
              <dt class="text-xs font-medium text-gray-500 truncate">Desqualificats</dt>
              <dd class="text-2xl font-semibold text-red-700">{disqualifiedCount}</dd>
            </dl>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-blue-400">
          <div class="p-4">
            <dl>
              <dt class="text-xs font-medium text-gray-500 truncate">Amb Restriccions</dt>
              <dd class="text-2xl font-semibold text-blue-700">{withRestrictionsCount}</dd>
            </dl>
          </div>
        </div>
      </div>

      {#if noCategoryCount > 0}
        <div class="mt-3 bg-yellow-50 border border-yellow-200 rounded-lg p-3 flex items-start gap-2">
          <svg class="h-5 w-5 text-yellow-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"/>
          </svg>
          <p class="text-sm text-yellow-800">
            Hi ha <strong>{noCategoryCount}</strong> jugador{noCategoryCount === 1 ? '' : 's'} sense categoria assignada. Cal assignar-los abans de generar el calendari.
          </p>
        </div>
      {/if}
    {/if}
  </div>
</div>

<!-- Modal per editar restriccions -->
<PlayerRestrictionsEditor
  inscription={selectedInscription}
  isOpen={showModal}
  on:updated={handleRestrictionsUpdated}
  on:close={handleModalClose}
/>