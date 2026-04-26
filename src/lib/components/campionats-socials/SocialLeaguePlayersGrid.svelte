<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';
  import { formatarNomJugador } from '$lib/utils/playerUtils';
  import { showSuccess, showError } from '$lib/stores/toastStore';

  export let eventId: string = '';
  export let categories: any[] = [];
  export let isAdmin: boolean = false;
  export let event: any = null;

  let inscriptions: any[] = [];
  let loadedCategories: any[] = [];
  let loading = false;
  let error: string | null = null;

  // Estat de la modal de retirada
  let withdrawalDialogOpen = false;
  let selectedInscriptionForWithdrawal: any = null;
  let withdrawalReason = '';
  let processingWithdrawal = false;

  // Quan el campionat és en curs, l'admin pot retirar jugadors (anul·la partides
  // pendents, conserva les jugades). Per a campionats en preparació la gestió
  // d'inscripcions es fa des del DragDrop, així que el botó queda ocult.
  $: canWithdraw = isAdmin && (
    event?.estat_competicio === 'en_curs' ||
    event?.estat_competicio === 'en_progres' ||
    event?.estat_competicio === 'actiu' ||
    event?.estat_competicio === 'ongoing' ||
    event?.estat_competicio === 'pendent_validacio' ||
    event?.estat_competicio === 'validat'
  );

  function openWithdrawalDialog(inscription: any) {
    selectedInscriptionForWithdrawal = inscription;
    withdrawalReason = '';
    withdrawalDialogOpen = true;
  }

  function closeWithdrawalDialog() {
    withdrawalDialogOpen = false;
    selectedInscriptionForWithdrawal = null;
    withdrawalReason = '';
  }

  async function withdrawPlayer() {
    if (!selectedInscriptionForWithdrawal || !withdrawalReason.trim()) return;

    try {
      processingWithdrawal = true;

      const { data: rpcData, error: rpcError } = await supabase.rpc('retire_player_from_league', {
        p_event_id: eventId,
        p_soci_numero: selectedInscriptionForWithdrawal.soci_numero,
        p_motiu_retirada: withdrawalReason.trim(),
        p_per_incompareixences: false
      });

      if (rpcError) throw rpcError;
      if (rpcData && rpcData.success === false) {
        throw new Error(rpcData.error || 'Error retirant el jugador');
      }

      const cancelled = rpcData?.pending_matches_cancelled ?? 0;
      const nom = `${selectedInscriptionForWithdrawal.socis?.nom ?? ''} ${selectedInscriptionForWithdrawal.socis?.cognoms ?? ''}`.trim();
      showSuccess(`${nom || 'Jugador'} retirat correctament. ${cancelled} partid${cancelled === 1 ? 'a' : 'es'} pendent${cancelled === 1 ? '' : 's'} anul·lad${cancelled === 1 ? 'a' : 'es'}.`);

      closeWithdrawalDialog();
      await loadInscriptions();
    } catch (e: any) {
      showError(`No s'ha pogut retirar el jugador: ${e?.message ?? 'error desconegut'}`);
    } finally {
      processingWithdrawal = false;
    }
  }

  onMount(() => {
    if (eventId && eventId.trim() !== '') {
      loadInscriptions();
    }
  });

  $: if (eventId && eventId.trim() !== '') {
    loadInscriptions();
  } else if (eventId === '') {
    inscriptions = [];
  }



  async function loadInscriptions() {
    loading = true;
    error = null;

    try {
      console.log('🔍 SocialLeaguePlayersGrid: Loading inscriptions with RPC function for event:', eventId);
      
      // Carregar categories de l'esdeveniment si no es passen per prop
      if (categories.length === 0) {
        console.log('🔍 Loading categories for event with RPC:', eventId);
        const { data: categoriesData, error: categoriesError } = await supabase
          .rpc('get_categories_for_event', {
            p_event_id: eventId
          });
        
        if (categoriesError) {
          console.error('❌ Error loading categories with RPC:', categoriesError);
        } else if (categoriesData) {
          loadedCategories = categoriesData;
          console.log('✅ Loaded categories with RPC:', loadedCategories.length, loadedCategories.map(c => c.nom));
        } else {
          console.log('⚠️ No categories found');
        }
      } else {
        loadedCategories = categories;
        console.log('✅ Using categories from props:', loadedCategories.length);
      }
      
      // Utilitzar la funció RPC que permet accés públic (anònim i autenticat)
      const { data: inscriptionsData, error: inscriptionsError } = await supabase
        .rpc('get_inscripcions_with_socis', {
          p_event_id: eventId
        });

      if (inscriptionsError) {
        console.error('❌ Error loading inscriptions with RPC:', inscriptionsError);
        throw inscriptionsError;
      }

      console.log('✅ Loaded inscriptions via RPC:', inscriptionsData?.length || 0);

      let finalData: any[] = [];

      if (inscriptionsData && inscriptionsData.length > 0) {
        finalData = inscriptionsData.map(item => ({
          id: item.id,
          soci_numero: item.soci_numero,
          categoria_assignada_id: item.categoria_assignada_id,
          data_inscripcio: item.data_inscripcio,
          pagat: item.pagat,
          confirmat: item.confirmat,
          created_at: item.created_at,
          estat_jugador: item.estat_jugador,
          data_retirada: item.data_retirada,
          motiu_retirada: item.motiu_retirada,
          eliminat_per_incompareixences: item.eliminat_per_incompareixences,
          socis: {
            numero_soci: item.soci_numero,
            nom: item.nom,
            cognoms: item.cognoms,
            email: item.email,
            de_baixa: item.de_baixa
          }
        }));
      } else {
        // Fallback: consulta directa sense filtre confirmat (per campionats on confirmat no està marcat)
        console.log('ℹ️ RPC returned empty, trying direct query without confirmat filter...');
        const { data: directData, error: directError } = await supabase
          .from('inscripcions')
          .select(`
            id,
            soci_numero,
            categoria_assignada_id,
            data_inscripcio,
            pagat,
            confirmat,
            created_at,
            estat_jugador,
            data_retirada,
            motiu_retirada,
            eliminat_per_incompareixences,
            socis!inscripcions_soci_numero_fkey(numero_soci, nom, cognoms, email, de_baixa)
          `)
          .eq('event_id', eventId);

        if (directError) {
          console.error('❌ Error with direct query:', directError);
        } else if (directData && directData.length > 0) {
          console.log('✅ Loaded inscriptions via direct query:', directData.length);
          finalData = directData.filter((item: any) => item.socis && !item.socis.de_baixa);
        } else {
          console.log('ℹ️ No inscriptions found for event');
        }
      }

      inscriptions = finalData;
      
      console.log('✅ Final inscriptions processed:', inscriptions.length);
    } catch (e) {
      console.error('❌ Error loading inscriptions:', e);
      error = 'Error carregant les inscripcions';
    } finally {
      loading = false;
    }
  }

  function getPlayersInCategory(categoryId: string) {
    return inscriptions.filter(i => i.categoria_assignada_id === categoryId);
  }

  function getPlayersWithoutCategory() {
    return inscriptions.filter(i => !i.categoria_assignada_id);
  }

  // Utilitzar les categories carregades o les rebudes per prop
  $: finalCategories = loadedCategories.length > 0 ? loadedCategories : categories;
  $: sortedCategories = finalCategories.sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));
  $: playersWithoutCategory = getPlayersWithoutCategory();
  
  // Debug per veure què està passant
  $: {
    console.log('🔍 DEBUG SocialLeaguePlayersGrid:');
    console.log('  - Total inscriptions:', inscriptions.length);
    console.log('  - Categories received from prop:', categories.length, categories.map(c => c?.nom));
    console.log('  - Categories loaded directly:', loadedCategories.length, loadedCategories.map(c => c?.nom));
    console.log('  - Final categories used:', finalCategories.length, finalCategories.map(c => c?.nom));
    console.log('  - Players without category:', playersWithoutCategory.length);
    if (inscriptions.length > 0 && finalCategories.length > 0) {
      finalCategories.forEach(cat => {
        const playersInCat = getPlayersInCategory(cat.id);
        console.log(`  - ${cat.nom}: ${playersInCat.length} jugadors`);
      });
    }
  }
</script>

<div class="space-y-6">
  {#if loading}
    <div class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant jugadors...</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
      <p class="text-red-600">{error}</p>
    </div>
  {:else if inscriptions.length === 0}
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha jugadors inscrits</h3>
      <p class="mt-1 text-sm text-gray-500">Els jugadors apareixeran aquí quan es facin les inscripcions.</p>
    </div>
  {:else}
    <!-- Si les categories encara es carreguen, mostrar tots els jugadors temporalment -->
    {#if finalCategories.length === 0 && inscriptions.length > 0}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="text-center mb-4 pb-3 border-b border-blue-200">
          <h3 class="text-lg font-bold text-gray-900">📋 Tots els Jugadors Inscrits</h3>
          <p class="text-sm text-blue-600 font-medium">
            Carregant categories...
          </p>
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mt-2">
            {inscriptions.length} jugadors
          </span>
        </div>

        <div class="space-y-2 max-h-96 overflow-y-auto">
          {#each inscriptions as inscription (inscription.id)}
            {@const soci = inscription.socis}
            {@const nomComplet = soci ? `${soci.nom} ${soci.cognoms}` : `Soci #${inscription.soci_numero}`}
            {@const nomFormatat = formatarNomJugador(nomComplet)}
            {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
            <div class="flex items-center justify-between py-1">
              <div class="flex items-center">
                <div class="w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center text-sm font-bold mr-3">
                  {inicialNom}
                </div>
                <span class="text-sm font-medium text-gray-900">
                  {nomFormatat}
                </span>
              </div>
            </div>
          {/each}
        </div>
      </div>
    {:else}
    <!-- Categories compactes amb jugadors -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      {#each sortedCategories as category (category.id)}
        {@const playersInCategory = getPlayersInCategory(category.id)}
        {#if playersInCategory.length > 0}
          <div class="bg-white border-2 border-gray-200 rounded-lg p-3 hover:shadow-lg transition-shadow">
            <!-- Capçalera de categoria -->
            <div class="text-center mb-3 pb-2 border-b border-gray-200">
              <h3 class="text-sm font-bold text-gray-900 truncate">{category.nom}</h3>
              <p class="text-xs text-blue-600 font-medium">
                {category.distancia_caramboles} car. • {playersInCategory.length} jug.
              </p>
            </div>

            <!-- Llista de jugadors compacta -->
            <div class="space-y-2">
              {#each playersInCategory as inscription (inscription.id)}
                {@const soci = inscription.socis}
                {@const nomCompletJugador = soci ? `${soci.nom} ${soci.cognoms}` : `Soci #${inscription.soci_numero}`}
                {@const nomFormatat = formatarNomJugador(nomCompletJugador)}
                {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
                {@const isWithdrawn = inscription.estat_jugador === 'retirat'}
                {@const isDisqualified = inscription.eliminat_per_incompareixences === true}
                <div class="flex items-center py-1" class:opacity-60={isWithdrawn}>
                  <div class="flex items-center gap-1 flex-1 min-w-0">
                    <div class="w-6 h-6 text-white rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0" class:bg-blue-500={!isWithdrawn} class:bg-gray-400={isWithdrawn}>
                      {inicialNom}
                    </div>
                    <span class="text-xs truncate" class:text-gray-900={!isWithdrawn} class:text-gray-500={isWithdrawn} class:line-through={isWithdrawn}>
                      {nomFormatat}
                    </span>
                    {#if isWithdrawn}
                      <span class="text-[10px] text-red-600 font-bold flex-shrink-0">{isDisqualified ? 'DQF' : 'R'}</span>
                    {/if}
                  </div>
                  {#if canWithdraw && !isWithdrawn}
                    <button
                      type="button"
                      on:click={() => openWithdrawalDialog(inscription)}
                      class="ml-1 flex-shrink-0 text-orange-600 hover:text-orange-800 hover:bg-orange-50 rounded p-1 transition-colors"
                      title="Retirar del campionat"
                      aria-label="Retirar {nomFormatat} del campionat"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7a4 4 0 11-8 0 4 4 0 018 0zM9 14a6 6 0 00-6 6v1h12v-1a6 6 0 00-6-6zM21 12h-6"></path>
                      </svg>
                    </button>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}
      {/each}

      <!-- Jugadors sense categoria (si n'hi ha) -->
      {#if playersWithoutCategory.length > 0}
        <div class="bg-yellow-50 border-2 border-yellow-300 rounded-lg p-4">
          <div class="text-center mb-4 pb-3 border-b border-yellow-300">
            <h3 class="text-lg font-bold text-gray-900">⚠️ Sense Categoria</h3>
            <p class="text-sm text-orange-600 font-medium">
              Pendent assignació
            </p>
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-200 text-yellow-800 mt-2">
              {playersWithoutCategory.length} jugadors
            </span>
          </div>

          <div class="space-y-2">
            {#each playersWithoutCategory as inscription (inscription.id)}
              {@const soci = inscription.socis}
              {@const nomCompletSenseCategoria = soci ? `${soci.nom} ${soci.cognoms}` : `Soci #${inscription.soci_numero}`}
              {@const nomFormatat = formatarNomJugador(nomCompletSenseCategoria)}
              {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
              {@const isWithdrawn = inscription.estat_jugador === 'retirat'}
              {@const isDisqualified = inscription.eliminat_per_incompareixences === true}
              <div class="flex items-center justify-between py-1" class:opacity-60={isWithdrawn}>
                <div class="flex items-center gap-2 min-w-0">
                  <div class="w-8 h-8 text-white rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0" class:bg-yellow-500={!isWithdrawn} class:bg-gray-400={isWithdrawn}>
                    {inicialNom}
                  </div>
                  <span class="text-sm font-medium truncate" class:text-gray-900={!isWithdrawn} class:text-gray-500={isWithdrawn} class:line-through={isWithdrawn}>
                    {nomFormatat}
                  </span>
                  {#if isWithdrawn}
                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800 flex-shrink-0">
                      {isDisqualified ? 'DQF' : 'Retirat'}
                    </span>
                  {/if}
                </div>
                {#if canWithdraw && !isWithdrawn}
                  <button
                    type="button"
                    on:click={() => openWithdrawalDialog(inscription)}
                    class="ml-2 flex-shrink-0 text-orange-600 hover:text-orange-800 hover:bg-orange-50 rounded p-1 transition-colors"
                    title="Retirar del campionat"
                    aria-label="Retirar {nomFormatat} del campionat"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7a4 4 0 11-8 0 4 4 0 018 0zM9 14a6 6 0 00-6 6v1h12v-1a6 6 0 00-6-6zM21 12h-6"></path>
                    </svg>
                  </button>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
    {/if}
  {/if}
</div>

{#if withdrawalDialogOpen && selectedInscriptionForWithdrawal}
  <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg p-6 max-w-md w-full shadow-xl">
      <h3 class="text-lg font-medium text-gray-900 mb-4">
        Retirar jugador del campionat
      </h3>

      <div class="mb-4">
        <p class="text-sm text-gray-700 mb-2">
          <strong>Jugador:</strong>
          {selectedInscriptionForWithdrawal.socis?.nom ?? ''} {selectedInscriptionForWithdrawal.socis?.cognoms ?? ''}
        </p>
        <p class="text-sm text-gray-600">
          El jugador es marcarà com a <strong>retirat</strong>. Les seves partides pendents s'anul·laran;
          les ja jugades es conservaran a la classificació.
        </p>
      </div>

      <div class="mb-4">
        <label for="players-grid-withdrawal-reason" class="block text-sm font-medium text-gray-700 mb-2">
          Motiu de la retirada *
        </label>
        <textarea
          id="players-grid-withdrawal-reason"
          bind:value={withdrawalReason}
          rows="3"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-orange-500 focus:border-orange-500"
          placeholder="Ex: Problemes de salut, manca de temps, etc."
        ></textarea>
      </div>

      <div class="flex justify-end space-x-3">
        <button
          type="button"
          on:click={closeWithdrawalDialog}
          disabled={processingWithdrawal}
          class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
        >
          Cancel·lar
        </button>
        <button
          type="button"
          on:click={withdrawPlayer}
          disabled={processingWithdrawal || !withdrawalReason.trim()}
          class="px-4 py-2 text-sm font-medium text-white bg-orange-600 border border-transparent rounded-md hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {processingWithdrawal ? 'Retirant...' : 'Confirmar retirada'}
        </button>
      </div>
    </div>
  </div>
{/if}
