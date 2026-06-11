<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
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

  // Inicialització gestionada per l'efecte reactiu $: if (eventId) més avall.

  $: if (eventId && eventId.trim() !== '') {
    loadInscriptions();
  } else if (eventId === '') {
    inscriptions = [];
  }



  let loadInscriptionsCounter = 0;

  async function loadInscriptions() {
    const myReq = ++loadInscriptionsCounter;
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
      if (myReq !== loadInscriptionsCounter) return; // stale response

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
  $: sortedCategories = [...finalCategories].sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));
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

<div class="players-root">
  {#if loading}
    <div class="state-empty">Carregant jugadors…</div>
  {:else if error}
    <div class="state-empty error-state">{error}</div>
  {:else if inscriptions.length === 0}
    <div class="state-empty">
      <div class="state-title">No hi ha jugadors inscrits</div>
      <div class="state-sub">Els jugadors apareixeran aquí quan es facin les inscripcions.</div>
    </div>
  {:else}
    {#if finalCategories.length === 0 && inscriptions.length > 0}
      <article class="cat-block loading-block">
        <header class="cat-block-head">
          <div>
            <div class="editorial-eyebrow" style="margin-bottom: 0.3rem;">Carregant categories</div>
            <h3 class="cat-name">Tots els jugadors inscrits</h3>
          </div>
          <div class="cat-count tabular-nums">{inscriptions.length} jugadors</div>
        </header>
        <div class="players-list players-list-scroll">
          {#each inscriptions as inscription (inscription.id)}
            {@const soci = inscription.socis}
            {@const nomComplet = soci ? `${soci.nom} ${soci.cognoms}` : `Soci #${inscription.soci_numero}`}
            {@const nomFormatat = formatarNomJugador(nomComplet)}
            {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
            <div class="player-row">
              <span class="avatar">{inicialNom}</span>
              <span class="player-name">{nomFormatat}</span>
            </div>
          {/each}
        </div>
      </article>
    {:else}
      <div class="players-grid">
        {#each sortedCategories as category (category.id)}
          {@const playersInCategory = getPlayersInCategory(category.id)}
          {#if playersInCategory.length > 0}
            <article class="cat-block">
              <header class="cat-block-head">
                <div>
                  <div class="editorial-eyebrow" style="margin-bottom: 0.3rem;">Categoria</div>
                  <h3 class="cat-name">{category.nom}</h3>
                  <div class="cat-meta">
                    <span class="tabular-nums">{category.distancia_caramboles}</span> caramboles
                  </div>
                </div>
                <div class="cat-count tabular-nums">{playersInCategory.length}</div>
              </header>
              <div class="players-list">
                {#each playersInCategory as inscription (inscription.id)}
                  {@const soci = inscription.socis}
                  {@const nomCompletJugador = soci ? `${soci.nom} ${soci.cognoms}` : `Soci #${inscription.soci_numero}`}
                  {@const nomFormatat = formatarNomJugador(nomCompletJugador)}
                  {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
                  {@const isWithdrawn = inscription.estat_jugador === 'retirat'}
                  {@const isDisqualified = inscription.eliminat_per_incompareixences === true}
                  <div class="player-row" class:retired={isWithdrawn}>
                    <span class="avatar">{inicialNom}</span>
                    <span class="player-name">{nomFormatat}</span>
                    {#if isWithdrawn}
                      <span class="retired-badge">{isDisqualified ? 'DQF' : 'R'}</span>
                    {/if}
                    {#if canWithdraw && !isWithdrawn}
                      <button
                        type="button"
                        on:click={() => openWithdrawalDialog(inscription)}
                        class="withdraw-btn"
                        title="Retirar del campionat"
                        aria-label="Retirar {nomFormatat} del campionat"
                      >×</button>
                    {/if}
                  </div>
                {/each}
              </div>
            </article>
          {/if}
        {/each}

        {#if playersWithoutCategory.length > 0}
          <article class="cat-block cat-block-warn">
            <header class="cat-block-head">
              <div>
                <div class="editorial-eyebrow warn" style="margin-bottom: 0.3rem;">Pendent assignació</div>
                <h3 class="cat-name">Sense categoria</h3>
              </div>
              <div class="cat-count tabular-nums">{playersWithoutCategory.length}</div>
            </header>
            <div class="players-list">
              {#each playersWithoutCategory as inscription (inscription.id)}
                {@const soci = inscription.socis}
                {@const nomCompletSenseCategoria = soci ? `${soci.nom} ${soci.cognoms}` : `Soci #${inscription.soci_numero}`}
                {@const nomFormatat = formatarNomJugador(nomCompletSenseCategoria)}
                {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
                {@const isWithdrawn = inscription.estat_jugador === 'retirat'}
                {@const isDisqualified = inscription.eliminat_per_incompareixences === true}
                <div class="player-row" class:retired={isWithdrawn}>
                  <span class="avatar avatar-warn">{inicialNom}</span>
                  <span class="player-name">{nomFormatat}</span>
                  {#if isWithdrawn}
                    <span class="retired-badge">{isDisqualified ? 'DQF' : 'Retirat'}</span>
                  {/if}
                  {#if canWithdraw && !isWithdrawn}
                    <button
                      type="button"
                      on:click={() => openWithdrawalDialog(inscription)}
                      class="withdraw-btn"
                      title="Retirar del campionat"
                      aria-label="Retirar {nomFormatat} del campionat"
                    >×</button>
                  {/if}
                </div>
              {/each}
            </div>
          </article>
        {/if}
      </div>
    {/if}
  {/if}
</div>

{#if withdrawalDialogOpen && selectedInscriptionForWithdrawal}
  <div class="modal-root">
    <div class="modal-overlay" on:click={closeWithdrawalDialog} role="presentation"></div>
    <div class="modal-card" role="dialog" aria-modal="true">
      <div class="modal-head">
        <h3 class="modal-title">Retirar jugador del campionat</h3>
      </div>
      <div class="modal-body">
        <div class="match-info">
          <div class="match-info-eyebrow">Jugador</div>
          <div class="match-info-player">
            {selectedInscriptionForWithdrawal.socis?.nom ?? ''} {selectedInscriptionForWithdrawal.socis?.cognoms ?? ''}
          </div>
        </div>

        <p class="modal-note">
          El jugador es marcarà com a <strong>retirat</strong>. Les seves partides pendents s'anul·laran;
          les ja jugades es conservaran a la classificació.
        </p>

        <div class="form-field">
          <label for="players-grid-withdrawal-reason">Motiu de la retirada *</label>
          <textarea
            id="players-grid-withdrawal-reason"
            bind:value={withdrawalReason}
            rows="3"
            class="filter-input"
            placeholder="Ex: Problemes de salut, manca de temps, etc."
          ></textarea>
        </div>

        <div class="modal-actions">
          <button
            type="button"
            on:click={closeWithdrawalDialog}
            disabled={processingWithdrawal}
            class="btn-secondary"
          >
            Cancel·lar
          </button>
          <button
            type="button"
            on:click={withdrawPlayer}
            disabled={processingWithdrawal || !withdrawalReason.trim()}
            class="btn-primary btn-danger"
          >
            {processingWithdrawal ? 'Retirant…' : 'Confirmar retirada'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .players-root {
    width: 100%;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  /* Estats */
  .state-empty {
    padding: 1.75rem 2rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
  }
  .state-empty.error-state { color: var(--accent); border-color: var(--accent); }
  .state-title { font-weight: 700; font-size: 1.0625rem; color: var(--ink); }
  .state-sub { margin-top: 0.4rem; font-size: 0.875rem; color: var(--ink-3); }

  /* Grid de cards de categoria */
  .players-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap: 1rem;
  }
  .cat-block {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    display: flex;
    flex-direction: column;
  }
  .cat-block-warn { border-top: 3px solid var(--amber); }
  .cat-block-head {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 0.85rem 1rem;
    border-bottom: 2px solid var(--ink);
  }
  .cat-name {
    font-weight: 800;
    font-size: 1.125rem;
    letter-spacing: -0.018em;
    margin: 0;
    line-height: 1.15;
  }
  .cat-meta {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    color: var(--ink-3);
    font-weight: 500;
  }
  .cat-count {
    font-weight: 800;
    font-size: 1.5rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    line-height: 1;
  }

  /* Llista de jugadors */
  .players-list {
    display: flex;
    flex-direction: column;
    padding: 0.4rem 0;
  }
  .players-list-scroll {
    max-height: 24rem;
    overflow-y: auto;
  }
  .player-row {
    display: flex;
    align-items: center;
    gap: 0.55rem;
    padding: 0.5rem 1rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.875rem;
  }
  .player-row:last-child { border-bottom: none; }
  .player-row.retired { opacity: 0.55; }
  .player-row.retired .player-name { text-decoration: line-through; }
  .avatar {
    width: 1.75rem;
    height: 1.75rem;
    border-radius: 50%;
    background: var(--paper);
    border: 1px solid var(--rule-strong);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 0.8125rem;
    color: var(--ink-2);
    flex-shrink: 0;
  }
  .avatar.avatar-warn {
    background: rgba(163, 107, 28, 0.1);
    border-color: var(--amber);
    color: var(--amber);
  }
  .player-name {
    flex: 1;
    min-width: 0;
    font-weight: 600;
    color: var(--ink);
    letter-spacing: -0.012em;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .retired-badge {
    flex-shrink: 0;
    padding: 0.1rem 0.35rem;
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--accent);
    border: 1px solid var(--accent);
  }
  .withdraw-btn {
    flex-shrink: 0;
    background: transparent;
    border: 1px solid var(--rule-strong);
    color: var(--ink-3);
    width: 1.6rem;
    height: 1.6rem;
    font-size: 1rem;
    line-height: 1;
    cursor: pointer;
    padding: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }
  .withdraw-btn:hover {
    color: var(--accent);
    border-color: var(--accent);
  }

  /* Modal */
  .modal-root {
    position: fixed;
    inset: 0;
    z-index: 50;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
  }
  .modal-overlay {
    position: absolute;
    inset: 0;
    background: rgba(26, 24, 20, 0.55);
  }
  .modal-card {
    position: relative;
    z-index: 10;
    max-width: 28rem;
    width: 100%;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.18);
    max-height: 90vh;
    overflow-y: auto;
  }
  .modal-head {
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
  }
  .modal-title {
    font-weight: 800;
    font-size: 1.125rem;
    letter-spacing: -0.022em;
    margin: 0;
  }
  .modal-body {
    padding: 1.25rem 1.5rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .match-info {
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 0.85rem 1rem;
  }
  .match-info-eyebrow {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin-bottom: 0.4rem;
  }
  .match-info-player {
    font-weight: 700;
    font-size: 1rem;
    color: var(--ink);
  }
  .modal-note {
    margin: 0;
    font-size: 0.875rem;
    color: var(--ink-2);
    line-height: 1.55;
  }
  .modal-note strong { color: var(--ink); font-weight: 700; }
  .form-field { display: flex; flex-direction: column; gap: 0.4rem; }
  .form-field label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ink-2);
  }
  .filter-input {
    width: 100%;
    padding: 0.55rem 0.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 500;
    resize: vertical;
  }
  .filter-input:focus {
    outline: 2px solid var(--ink);
    outline-offset: 1px;
    border-color: var(--ink);
  }
  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    padding-top: 0.85rem;
    border-top: 1px solid var(--rule);
  }
  .btn-secondary {
    padding: 0.55rem 1rem;
    background: transparent;
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .btn-secondary:hover { border-color: var(--ink); }
  .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary {
    padding: 0.55rem 1rem;
    background: var(--ink);
    border: 1px solid var(--ink);
    color: var(--paper);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .btn-primary:hover { opacity: 0.92; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary.btn-danger {
    background: var(--accent);
    border-color: var(--accent);
  }

  /* Responsive */
  @media (max-width: 640px) {
    .players-grid { grid-template-columns: 1fr; }
  }
</style>
