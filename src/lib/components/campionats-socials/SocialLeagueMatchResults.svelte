<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { onMount } from 'svelte';
  import SociFoto from '$lib/components/admin/SociFoto.svelte';

  export let eventId: string = '';
  export let categories: any[] = [];

  let matches: any[] = [];
  let unprogrammedMatches: any[] = [];
  let allMatches: any[] = []; // All matches for total count
  let loadedCategories: any[] = []; // Categories loaded directly
  let loading = false;
  let error: string | null = null;
  let selectedCategories: Set<string> = new Set(); // Multiple category selection
  let searchPlayer = ''; // Search text for player filter
  let showOnlyMyResults = false;
  let myPlayerData: any = null;

  // Admin edit functionality
  let editingMatch: any = null;
  let editForm = {
    caramboles_reptador: 0,
    caramboles_reptat: 0,
    entrades_reptador: 0,
    entrades_reptat: 0
  };
  let updateError: string | null = null;
  let updateSuccess: string | null = null;
  let saving = false;
  // Flux de reversió d'incompareixença: quan l'admin clica "substituir per resultat real",
  // el formulari del modal s'usa per recollir caramboles+entrades i `saveMatchResult` deriva
  // cap a la RPC `revertir_incompareixenca` en lloc de fer un UPDATE directe.
  let substituintIncompareixenca = false;

  $: editingHasIncompareixenca = !!(
    editingMatch && (editingMatch.incompareixenca_jugador1 || editingMatch.incompareixenca_jugador2)
  );

  onMount(() => {
    if (eventId) {
      loadMatches();
      loadCategories();
    }
  });

  $: if (eventId) {
    loadMatches();
    loadCategories();
  }

  // Load player data for logged-in user (Fase 5c-S2c-2: directe via socis.email)
  async function loadMyPlayerData() {
    if (!$user) {
      myPlayerData = null;
      return;
    }

    try {
      const { data: sociData, error: sociError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .eq('email', $user.email)
        .maybeSingle();

      if (sociError || !sociData) {
        console.log('No soci data found for user email:', $user.email);
        myPlayerData = null;
      } else {
        // Fase 5c-S3: ja no cal el camp `id` (player_id). Els filtres
        // comparen per soci_numero directament.
        myPlayerData = {
          numero_soci: sociData.numero_soci,
          nom: `${sociData.nom ?? ''} ${sociData.cognoms ?? ''}`.trim()
        };
      }
    } catch (e) {
      console.error('Error loading player data:', e);
      myPlayerData = null;
    }
  }

  // React to user changes
  $: if ($user) {
    console.log('🔍 User detected in results, loading player data:', $user.id);
    loadMyPlayerData();
  } else {
    console.log('🔍 No user in results');
    myPlayerData = null;
    showOnlyMyResults = false;
  }

  // Debug myPlayerData changes
  $: console.log('🎯 Results - myPlayerData:', myPlayerData, 'showOnlyMyResults:', showOnlyMyResults);

  async function loadCategories() {
    try {
      const { data, error: categoriesError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', eventId)
        .order('ordre_categoria', { ascending: true });

      if (categoriesError) throw categoriesError;
      loadedCategories = data || [];
    } catch (e) {
      console.error('Error loading categories:', e);
    }
  }

  async function loadMatches() {
    loading = true;
    error = null;

    try {
      const { data: inscriptionsData, error: inscriptionsError } = await supabase
        .rpc('get_inscripcions_with_socis', {
          p_event_id: eventId
        });

      if (inscriptionsError) throw inscriptionsError;

      const withdrawnNumbers = new Set(
        (inscriptionsData || [])
          .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
          .map((item: any) => item.soci_numero)
          .filter((numero: any) => typeof numero === 'number')
      );

      // Programmed and completed matches
      const { data, error: matchesError } = await supabase
        .rpc('get_match_results_public', {
          p_event_id: eventId
        });

      if (matchesError) throw matchesError;
      matches = (data || []).filter((match: any) => {
        if (withdrawnNumbers.size === 0) return true;
        return !withdrawnNumbers.has(match.jugador1_numero_soci) && !withdrawnNumbers.has(match.jugador2_numero_soci);
      });

      // Load ALL matches for total count
      const { data: allMatchesData, error: allMatchesError } = await supabase
        .from('calendari_partides')
        .select('id, estat, caramboles_jugador1, caramboles_jugador2, data_programada')
        .eq('event_id', eventId);

      if (allMatchesError) throw allMatchesError;
      allMatches = allMatchesData || [];

      // Unprogrammed matches (estat = 'pendent_programar')
      const { data: unprogrammed, error: unprogrammedError } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .eq('estat', 'pendent_programar')
        .is('caramboles_jugador1', null)
        .is('caramboles_jugador2', null);
      if (unprogrammedError) throw unprogrammedError;
      unprogrammedMatches = unprogrammed || [];
    } catch (e) {
      console.error('Error loading matches:', e);
      error = 'Error carregant els resultats';
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(nom: string, cognoms: string, numeroSoci?: number) {
    if (!nom && !cognoms) return 'Jugador desconegut';

    // Format: inicial(s) del nom + primer cognom
    // Example: "Joan Pere" "García López" -> "J.P. García"

    let inicials = '';
    if (nom) {
      const noms = nom.trim().split(/\s+/);
      inicials = noms.map(n => n.charAt(0).toUpperCase() + '.').join('');
    }

    const primerCognom = cognoms ? cognoms.trim().split(/\s+/)[0] : '';

    if (inicials && primerCognom) {
      return `${inicials} ${primerCognom}`;
    } else if (inicials) {
      return inicials;
    } else if (primerCognom) {
      return primerCognom;
    }

    return 'Jugador desconegut';
  }

  function getMatchStatus(match: any) {
    // Una partida està completada si té resultats registrats
    if (match.caramboles_reptador !== null && match.caramboles_reptat !== null) {
      return 'completed';
    }
    if (match.data_programada && new Date(match.data_programada) < new Date()) return 'pending';
    return 'scheduled';
  }

  // Funció per verificar si una partida està completada
  function isMatchCompleted(match: any) {
    return match.caramboles_reptador !== null &&
           match.caramboles_reptat !== null;
  }

  function getStatusColor(status: string) {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'pending': return 'bg-red-100 text-red-800';
      case 'scheduled': return 'bg-blue-100 text-blue-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }

  function getStatusText(status: string) {
    switch (status) {
      case 'completed': return 'Completada';
      case 'pending': return 'Pendent resultat';
      case 'scheduled': return 'Programada';
      default: return 'Desconegut';
    }
  }

  function getMatchWinner(match: any) {
    if (!isMatchCompleted(match)) {
      return null;
    }

    // Incompareixença: el que es presenta guanya, l'altre perd
    if (match.incompareixenca_jugador1 && !match.incompareixenca_jugador2) return 2;
    if (match.incompareixenca_jugador2 && !match.incompareixenca_jugador1) return 1;

    if (match.caramboles_reptador > match.caramboles_reptat) return 1;
    if (match.caramboles_reptat > match.caramboles_reptador) return 2;
    return 0; // tie
  }

  // Calcular mitjana d'un jugador en una partida
  function calcularMitjana(caramboles: number, entrades: number): string {
    if (!entrades || entrades === 0) return '0.000';
    return (caramboles / entrades).toFixed(3);
  }

  function formatMatchDate(dateStr: string) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('ca-ES', {
      weekday: 'short',
      day: 'numeric',
      month: 'short'
    });
  }

  function formatMatchTime(timeStr: string) {
    if (!timeStr) return '';
    return timeStr.substring(0, 5); // HH:MM
  }

  // Toggle category selection
  function toggleCategory(categoryId: string) {
    if (selectedCategories.has(categoryId)) {
      selectedCategories.delete(categoryId);
    } else {
      selectedCategories.add(categoryId);
    }
    selectedCategories = selectedCategories; // Trigger reactivity
  }

  // Filter matches based on selected categories and player search
  $: filteredMatches = matches.filter(match => {
    // Only show completed matches (with results)
    if (!isMatchCompleted(match)) {
      return false;
    }

    // Filter "Les meves dades" per jugador logat (Fase 5c-S2c-2: matching
    // per soci_numero ja que `myPlayerData.id === numero_soci`).
    if (showOnlyMyResults && myPlayerData) {
      const myNum = myPlayerData.numero_soci;
      const isMyMatch =
        match.jugador1_numero_soci === myNum ||
        match.jugador2_numero_soci === myNum;
      if (!isMyMatch) return false;
    }

    // Filter by category (if any selected)
    if (selectedCategories.size > 0 && !selectedCategories.has(match.categoria_id)) {
      return false;
    }

    // Filter by player name
    if (searchPlayer.trim() !== '') {
      const searchLower = searchPlayer.toLowerCase();
      const player1Name = formatPlayerName(match.jugador1_nom, match.jugador1_cognoms, match.jugador1_numero_soci).toLowerCase();
      const player2Name = formatPlayerName(match.jugador2_nom, match.jugador2_cognoms, match.jugador2_numero_soci).toLowerCase();

      if (!player1Name.includes(searchLower) && !player2Name.includes(searchLower)) {
        return false;
      }
    }

    return true;
  });

  // Group matches by status for summary
  $: matchesByStatus = {
    completed: matches.filter(m => getMatchStatus(m) === 'completed').length,
    pending: matches.filter(m => getMatchStatus(m) === 'pending').length,
    scheduled: matches.filter(m => getMatchStatus(m) === 'scheduled').length
  };

  // Use loaded categories if available, otherwise use prop
  $: finalCategories = loadedCategories.length > 0 ? loadedCategories : categories;

  // Sort categories by order
  $: sortedCategories = finalCategories.sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));

  // Admin functions
  function startEditingMatch(match: any) {
    editingMatch = match;
    editForm = {
      caramboles_reptador: match.caramboles_reptador ?? 0,
      caramboles_reptat: match.caramboles_reptat ?? 0,
      entrades_reptador: match.entrades_reptador ?? match.entrades ?? 0,
      entrades_reptat: match.entrades_reptat ?? match.entrades ?? 0
    };
    substituintIncompareixenca = false;
    updateError = null;
    updateSuccess = null;
  }

  function cancelEdit() {
    editingMatch = null;
    substituintIncompareixenca = false;
    updateError = null;
    updateSuccess = null;
  }

  // Revertir incompareixença i deixar la partida pendent (sense resultat).
  async function revertirIncompareixencaAPendent() {
    if (!editingMatch) return;
    if (saving) return;
    if (!confirm('Es treurà la incompareixença i la partida tornarà a estat pendent. Continuar?')) return;

    saving = true;
    updateError = null;
    updateSuccess = null;
    try {
      const { error: rpcErr } = await supabase.rpc('revertir_incompareixenca', {
        p_partida_id: editingMatch.id,
        p_mode: 'pendent'
      });
      if (rpcErr) {
        updateError = `Error: ${rpcErr.message || rpcErr.code}`;
        return;
      }
      updateSuccess = 'Incompareixença revertida. La partida ha tornat a pendent.';
      await loadMatches();
      setTimeout(() => cancelEdit(), 1500);
    } catch (e: any) {
      updateError = e.message || 'Error revertint la incompareixença';
    } finally {
      saving = false;
    }
  }

  // Activar el mode "substitució per resultat real": l'admin omple el formulari
  // i en clicar "Guardar" s'enviarà via RPC en lloc d'un UPDATE directe.
  function iniciarSubstitucioResultat() {
    if (!editingMatch) return;
    substituintIncompareixenca = true;
    // Pre-omplir el formulari amb zeros perquè els valors actuals (caramboles=0,
    // entrades=max_entrades del jugador absent) no tenen sentit com a resultat real.
    editForm = {
      caramboles_reptador: 0,
      caramboles_reptat: 0,
      entrades_reptador: 0,
      entrades_reptat: 0
    };
    updateError = null;
    updateSuccess = null;
  }

  function cancelarSubstitucio() {
    substituintIncompareixenca = false;
    updateError = null;
  }

  async function aplicarRevertResultat() {
    if (!editingMatch) return;
    if (saving) return;

    const c1 = editForm.caramboles_reptador;
    const c2 = editForm.caramboles_reptat;
    const e1 = editForm.entrades_reptador;
    const e2 = editForm.entrades_reptat;
    if (c1 == null || c2 == null || !e1 || !e2 || e1 < 1 || e2 < 1) {
      updateError = 'Cal omplir caramboles i entrades (>0) dels dos jugadors.';
      return;
    }

    saving = true;
    updateError = null;
    updateSuccess = null;
    try {
      const { error: rpcErr } = await supabase.rpc('revertir_incompareixenca', {
        p_partida_id: editingMatch.id,
        p_mode: 'resultat',
        p_caramboles_jugador1: c1,
        p_caramboles_jugador2: c2,
        p_entrades_jugador1: e1,
        p_entrades_jugador2: e2
      });
      if (rpcErr) {
        updateError = `Error: ${rpcErr.message || rpcErr.code}`;
        return;
      }
      updateSuccess = 'Incompareixença substituïda pel resultat real.';
      await loadMatches();
      setTimeout(() => cancelEdit(), 1500);
    } catch (e: any) {
      updateError = e.message || 'Error aplicant el resultat';
    } finally {
      saving = false;
    }
  }

  async function saveMatchResult() {
    if (!editingMatch) return;

    // Si l'admin està substituint una incompareixença per un resultat real,
    // derivem cap a la RPC dedicada que reverteix la incompareixença a l'inrevés.
    if (substituintIncompareixenca) {
      await aplicarRevertResultat();
      return;
    }

    try {
      if (saving) return;
      saving = true;

      updateError = null;
      updateSuccess = null;

      // Punts segons resultat: vencedor 2pts, perdedor 0; empat 1-1.
      const c1 = editForm.caramboles_reptador;
      const c2 = editForm.caramboles_reptat;
      let punts_j1 = 0;
      let punts_j2 = 0;
      if (c1 > c2) punts_j1 = 2;
      else if (c2 > c1) punts_j2 = 2;
      else { punts_j1 = 1; punts_j2 = 1; }

      const { data, error: updateErr } = await supabase
        .from('calendari_partides')
        .update({
          caramboles_jugador1: c1,
          caramboles_jugador2: c2,
          entrades_jugador1: editForm.entrades_reptador,
          entrades_jugador2: editForm.entrades_reptat,
          entrades: Math.max(editForm.entrades_reptador ?? 0, editForm.entrades_reptat ?? 0),
          punts_jugador1: punts_j1,
          punts_jugador2: punts_j2,
          estat: 'jugada',
          data_joc: editingMatch.data_joc ?? new Date().toISOString()
        })
        .eq('id', editingMatch.id)
        .select();

      if (updateErr) {
        console.error('Error updating match:', updateErr);
        console.error('Error details:', JSON.stringify(updateErr, null, 2));
        updateError = `Error: ${updateErr.message || updateErr.code || JSON.stringify(updateErr)}`;
        return;
      }

      if (!data || data.length === 0) {
        console.warn('Update returned no data');
        updateError = 'No s\'ha pogut actualitzar la partida. Comprova els permisos RLS.';
        return;
      }

      updateSuccess = 'Resultat actualitzat correctament';
      console.log('✅ Match updated successfully:', data);

      // Reload matches to show updated data
      await loadMatches();

      // Close modal after a short delay
      setTimeout(() => {
        cancelEdit();
      }, 1500);

    } catch (e: any) {
      console.error('Exception updating match:', e);
      console.error('Exception details:', JSON.stringify(e, null, 2));
      updateError = e.message || 'Error actualitzant el resultat';
    } finally {
      saving = false;
    }
  }
</script>

<div class="results-root">
  <!-- Filtres editorials -->
  <div class="results-filters">
    <fieldset class="filter-group">
      <legend class="filter-legend">
        Categories {selectedCategories.size > 0 ? `· ${selectedCategories.size} seleccionades` : ''}
      </legend>
      <div class="cat-pills">
        {#each sortedCategories as category}
          <button
            on:click={() => toggleCategory(category.id)}
            class="cat-pill"
            class:active={selectedCategories.has(category.id)}
          >
            {category.nom}
          </button>
        {/each}
        {#if selectedCategories.size > 0}
          <button
            on:click={() => selectedCategories = new Set()}
            class="cat-pill cat-pill-clear"
          >
            Netejar filtres
          </button>
        {/if}
      </div>
    </fieldset>

    <div class="filter-row-bottom">
      <div class="filter-search-block">
        <label for="player-search" class="filter-legend">Cerca per jugador</label>
        <div class="search-wrap">
          <input
            id="player-search"
            type="text"
            bind:value={searchPlayer}
            placeholder="Nom o cognoms…"
            class="filter-input"
            disabled={showOnlyMyResults}
          />
          {#if searchPlayer}
            <button
              on:click={() => searchPlayer = ''}
              class="search-clear"
              aria-label="Netejar cerca de jugador"
            >×</button>
          {/if}
        </div>
      </div>

      {#if myPlayerData}
        <label class="my-results-toggle">
          <input
            type="checkbox"
            bind:checked={showOnlyMyResults}
          />
          <span>Només els meus resultats</span>
        </label>
      {/if}
    </div>
  </div>

  {#if loading}
    <div class="state-empty">Carregant resultats…</div>
  {:else if error}
    <div class="state-empty error-state">{error}</div>
  {:else if filteredMatches.length === 0}
    <div class="state-empty">
      <div class="state-title">
        {selectedCategories.size > 0 || searchPlayer !== '' ? 'No hi ha partides amb aquests filtres' : 'No hi ha resultats de partides'}
      </div>
      <div class="state-sub">
        {selectedCategories.size > 0 || searchPlayer !== '' ? 'Prova a canviar els filtres de categoria o cerca de jugador.' : "Encara no s'han jugat partides en aquest campionat."}
      </div>
    </div>
  {:else}
    <!-- Llista de partides — taula editorial -->
    <div class="results-table-wrap">
      <table class="results-table">
        <thead>
          <tr>
            <th class="col-left">Categoria</th>
            <th class="col-left">Jugadors</th>
            <th class="col-num">Caramboles</th>
            <th class="col-num">Mitjanes</th>
            <th class="col-num">Entrades</th>
            {#if $effectiveIsAdmin}
              <th class="col-num">Accions</th>
            {/if}
          </tr>
        </thead>
        <tbody>
          {#each filteredMatches as match (match.id)}
            {@const status = getMatchStatus(match)}
            {@const winner = getMatchWinner(match)}
            <tr>
              <td>
                <div class="cat-cell">
                  <span class="cat-label">{match.categoria_nom || 'Sense categoria'}</span>
                  {#if match.categoria_distancia}
                    <span class="cat-distance">{match.categoria_distancia} caramboles</span>
                  {/if}
                </div>
              </td>
              <td>
                <div class="players-cell">
                  <div class="player-row" class:player-winner={winner === 1}>
                    <SociFoto numeroSoci={match.jugador1_numero_soci} size="xs" alt="{match.jugador1_nom} {match.jugador1_cognoms}" />
                    <span class="player-name">{formatPlayerName(match.jugador1_nom, match.jugador1_cognoms, match.jugador1_numero_soci)}</span>
                    {#if match.incompareixenca_jugador1}
                      <span class="badge-noshow">No presentat</span>
                    {/if}
                  </div>
                  <div class="vs-sep">vs</div>
                  <div class="player-row" class:player-winner={winner === 2}>
                    <SociFoto numeroSoci={match.jugador2_numero_soci} size="xs" alt="{match.jugador2_nom} {match.jugador2_cognoms}" />
                    <span class="player-name">{formatPlayerName(match.jugador2_nom, match.jugador2_cognoms, match.jugador2_numero_soci)}</span>
                    {#if match.incompareixenca_jugador2}
                      <span class="badge-noshow">No presentat</span>
                    {/if}
                  </div>
                </div>
              </td>
              <td class="col-num">
                {#if status === 'completed'}
                  <div class="num-stack tabular-nums">
                    <div class="num-line" class:winner={winner === 1}>{match.caramboles_reptador ?? 0}</div>
                    <div class="num-sep">–</div>
                    <div class="num-line" class:winner={winner === 2}>{match.caramboles_reptat ?? 0}</div>
                  </div>
                {:else}
                  <span class="muted">—</span>
                {/if}
              </td>
              <td class="col-num">
                {#if status === 'completed' && match.entrades}
                  <div class="num-stack tabular-nums">
                    <div class="num-line num-secondary" class:winner={winner === 1}>{calcularMitjana(match.caramboles_reptador, match.entrades)}</div>
                    <div class="num-sep">–</div>
                    <div class="num-line num-secondary" class:winner={winner === 2}>{calcularMitjana(match.caramboles_reptat, match.entrades)}</div>
                  </div>
                {:else}
                  <span class="muted">—</span>
                {/if}
              </td>
              <td class="col-num">
                {#if status === 'completed'}
                  <span class="tabular-nums">{match.entrades ?? '—'}</span>
                {:else}
                  <span class="muted">—</span>
                {/if}
              </td>
              {#if $effectiveIsAdmin}
                <td class="col-num">
                  {#if status === 'completed'}
                    <button
                      on:click={() => startEditingMatch(match)}
                      class="action-link link-blue"
                    >
                      Editar
                    </button>
                  {:else}
                    <span class="muted">—</span>
                  {/if}
                </td>
              {/if}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <!-- Resum stats editorial -->
    <section class="results-summary">
      <div class="editorial-eyebrow" style="margin-bottom: 0.65rem;">Resum de partides</div>
      <div class="results-summary-strip">
        <div>
          <div class="cls-stat-num tabular-nums">{allMatches.length}</div>
          <div class="cls-stat-lbl">Total partides</div>
        </div>
        <div>
          <div class="cls-stat-num tabular-nums">{matchesByStatus.completed}</div>
          <div class="cls-stat-lbl">Partides jugades</div>
        </div>
      </div>
    </section>

  {/if}
</div>

<!-- Edit Modal (Admin only) -->
{#if editingMatch && $effectiveIsAdmin}
  <div class="modal-root">
    <div
      class="modal-overlay"
      aria-label="Tanca modal d'edició de resultats"
      on:click={cancelEdit}
      on:keydown={(e) => e.key === 'Escape' && cancelEdit()}
      role="button"
      tabindex="-1"
    ></div>
    <div class="modal-card" role="dialog" aria-modal="true" tabindex="-1" on:click|stopPropagation on:keydown|stopPropagation>
      <div class="modal-head">
        <h2 class="modal-title">Editar resultat</h2>
        <button type="button" aria-label="Tancar editar resultat" on:click={cancelEdit} class="modal-close">×</button>
      </div>

      <form on:submit|preventDefault={saveMatchResult} class="modal-body">
        <!-- Match info -->
        <div class="match-info">
          <div class="match-info-eyebrow">Partida</div>
          <div class="match-info-player">
            {formatPlayerName(editingMatch.jugador1_nom, editingMatch.jugador1_cognoms, editingMatch.jugador1_numero_soci)}
          </div>
          <div class="match-info-sep">vs</div>
          <div class="match-info-player">
            {formatPlayerName(editingMatch.jugador2_nom, editingMatch.jugador2_cognoms, editingMatch.jugador2_numero_soci)}
          </div>
        </div>

        {#if updateError}
          <div class="msg msg-error">{updateError}</div>
        {/if}
        {#if updateSuccess}
          <div class="msg msg-success">{updateSuccess}</div>
        {/if}

        {#if editingHasIncompareixenca}
          <div class="incompar-banner">
            <strong>⚠ Incompareixença registrada</strong> —
            {#if editingMatch.incompareixenca_jugador1 && editingMatch.incompareixenca_jugador2}
              cap dels dos jugadors es va presentar.
            {:else if editingMatch.incompareixenca_jugador1}
              no s'ha presentat el jugador 1.
            {:else}
              no s'ha presentat el jugador 2.
            {/if}
            {#if !substituintIncompareixenca}
              <div class="incompar-actions">
                <button type="button" class="btn-secondary" on:click={revertirIncompareixencaAPendent} disabled={saving}>
                  Treure i deixar pendent
                </button>
                <button type="button" class="btn-primary" on:click={iniciarSubstitucioResultat} disabled={saving}>
                  Substituir per resultat real
                </button>
              </div>
            {:else}
              <div class="incompar-substituting">
                Introdueix el resultat real i clica <em>Guardar</em>. La incompareixença es revertirà automàticament.
                <button type="button" class="link-btn" on:click={cancelarSubstitucio}>Cancel·la substitució</button>
              </div>
            {/if}
          </div>
        {/if}

        <div class="form-fields" class:hidden={editingHasIncompareixenca && !substituintIncompareixenca}>
          <div class="form-field">
            <label for="caramboles_reptador">
              Caramboles {formatPlayerName(editingMatch.jugador1_nom, editingMatch.jugador1_cognoms, editingMatch.jugador1_numero_soci)}
            </label>
            <input
              id="caramboles_reptador"
              type="number"
              min="0"
              bind:value={editForm.caramboles_reptador}
              required
              class="filter-input"
            />
          </div>

          <div class="form-field">
            <label for="caramboles_reptat">
              Caramboles {formatPlayerName(editingMatch.jugador2_nom, editingMatch.jugador2_cognoms, editingMatch.jugador2_numero_soci)}
            </label>
            <input
              id="caramboles_reptat"
              type="number"
              min="0"
              bind:value={editForm.caramboles_reptat}
              required
              class="filter-input"
            />
          </div>

          <div class="form-field">
            <label for="entrades_reptador">
              Entrades {formatPlayerName(editingMatch.jugador1_nom, editingMatch.jugador1_cognoms, editingMatch.jugador1_numero_soci)}
            </label>
            <input
              id="entrades_reptador"
              type="number"
              min="1"
              bind:value={editForm.entrades_reptador}
              required
              class="filter-input"
            />
          </div>

          <div class="form-field">
            <label for="entrades_reptat">
              Entrades {formatPlayerName(editingMatch.jugador2_nom, editingMatch.jugador2_cognoms, editingMatch.jugador2_numero_soci)}
            </label>
            <input
              id="entrades_reptat"
              type="number"
              min="1"
              bind:value={editForm.entrades_reptat}
              required
              class="filter-input"
            />
          </div>

          <!-- Calculated averages preview -->
          <div class="averages-preview">
            <div class="editorial-eyebrow">Mitjanes calculades</div>
            <div class="averages-grid">
              <div>
                <div class="averages-num tabular-nums">{calcularMitjana(editForm.caramboles_reptador, editForm.entrades_reptador)}</div>
                <div class="averages-lbl">Jugador 1</div>
              </div>
              <div>
                <div class="averages-num tabular-nums">{calcularMitjana(editForm.caramboles_reptat, editForm.entrades_reptat)}</div>
                <div class="averages-lbl">Jugador 2</div>
              </div>
            </div>
          </div>
        </div>

        <div class="modal-actions">
          <button type="button" on:click={cancelEdit} class="btn-secondary">Cancel·lar</button>
          {#if !editingHasIncompareixenca || substituintIncompareixenca}
            <button type="submit" class="btn-primary" disabled={saving}>
              {saving ? 'Guardant…' : 'Guardar'}
            </button>
          {/if}
        </div>
      </form>
    </div>
  </div>
{/if}

<style>
  .results-root {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  /* ── Filtres ──────────────────────────────────────── */
  .results-filters {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.25rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .filter-group { border: none; padding: 0; margin: 0; }
  .filter-legend {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--ink-3);
    margin-bottom: 0.55rem;
    display: block;
  }
  .cat-pills { display: flex; flex-wrap: wrap; gap: 0.4rem; }
  .cat-pill {
    background: transparent;
    border: 1px solid var(--rule-strong);
    color: var(--ink-2);
    padding: 0.45rem 0.85rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.8125rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
  }
  .cat-pill:hover { color: var(--ink); border-color: var(--ink); }
  .cat-pill.active {
    background: var(--ink);
    color: var(--paper);
    border-color: var(--ink);
  }
  .cat-pill.cat-pill-clear {
    color: var(--accent);
    border-color: var(--accent);
  }
  .cat-pill.cat-pill-clear:hover {
    background: var(--accent);
    color: white;
  }

  .filter-row-bottom {
    display: flex;
    gap: 1.5rem;
    align-items: flex-end;
    flex-wrap: wrap;
  }
  .filter-search-block { flex: 1; max-width: 28rem; }
  .filter-input {
    width: 100%;
    padding: 0.55rem 0.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 500;
    min-height: 44px;
  }
  .filter-input:focus {
    outline: 2px solid var(--ink);
    outline-offset: 1px;
    border-color: var(--ink);
  }
  .filter-input:disabled { opacity: 0.5; cursor: not-allowed; }
  .search-wrap { position: relative; }
  .search-clear {
    position: absolute;
    right: 0.5rem;
    top: 50%;
    transform: translateY(-50%);
    background: transparent;
    border: none;
    color: var(--ink-3);
    font-size: 1.25rem;
    width: 1.75rem;
    height: 1.75rem;
    cursor: pointer;
  }
  .search-clear:hover { color: var(--ink); }
  .my-results-toggle {
    display: inline-flex;
    align-items: center;
    gap: 0.55rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--ink-2);
    cursor: pointer;
    min-height: 44px;
  }
  .my-results-toggle input { width: 1.1rem; height: 1.1rem; accent-color: var(--ink); }
  .my-results-toggle:hover { color: var(--ink); }

  /* ── Estats ──────────────────────────────────────── */
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

  /* ── Taula resultats ─────────────────────────────── */
  .results-table-wrap {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    overflow-x: auto;
  }
  .results-table { width: 100%; border-collapse: collapse; }
  .results-table th {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    padding: 0.85rem;
    border-bottom: 1px solid var(--rule);
    white-space: nowrap;
    background: var(--paper);
  }
  .results-table th.col-left { text-align: left; }
  .results-table th.col-num { text-align: right; }
  .results-table td {
    padding: 0.85rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.9375rem;
    color: var(--ink);
    vertical-align: middle;
  }
  .results-table td.col-num { text-align: right; }
  .results-table tr:last-child td { border-bottom: none; }
  .results-table tr:hover { background: var(--paper); }

  .cat-cell { display: flex; flex-direction: column; gap: 0.2rem; }
  .cat-label {
    display: inline-block;
    padding: 0.18rem 0.55rem;
    border: 1px solid var(--rule-strong);
    font-weight: 700;
    font-size: 0.75rem;
    color: var(--ink);
    letter-spacing: -0.005em;
    align-self: flex-start;
  }
  .cat-distance {
    font-size: 0.6875rem;
    font-weight: 600;
    color: var(--ink-3);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .players-cell { display: flex; flex-direction: column; line-height: 1.3; }
  .player-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.15rem 0;
  }
  .player-row .player-name {
    font-weight: 500;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .player-row.player-winner .player-name {
    font-weight: 700;
    color: var(--green);
  }
  .vs-sep {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    padding-left: 2.4rem;
    margin: 0.15rem 0;
  }
  .badge-noshow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--accent);
    border: 1px solid var(--accent);
    padding: 0.12rem 0.4rem;
  }

  .num-stack {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    line-height: 1.3;
  }
  .num-line {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .num-line.num-secondary { font-weight: 600; font-size: 0.875rem; color: var(--ink-2); }
  .num-line.winner { color: var(--green); font-weight: 800; }
  .num-sep {
    font-size: 0.6875rem;
    color: var(--ink-3);
    margin: 0.12rem 0;
  }
  .muted { color: var(--ink-3); }

  .action-link {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.8125rem;
    border-bottom: 1px solid currentColor;
    padding-bottom: 1px;
  }
  .action-link.link-blue { color: var(--blue); }
  .action-link:hover { opacity: 0.8; }

  /* ── Resum ─────────────────────────────────────────── */
  .results-summary {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.25rem 1.5rem 0;
  }
  .results-summary-strip {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }
  .results-summary-strip > div {
    padding: 1rem 0 1.25rem;
    border-right: 1px solid var(--rule);
    padding-left: 1.25rem;
  }
  .results-summary-strip > div:first-child { padding-left: 0; }
  .results-summary-strip > div:last-child { border-right: none; }
  .cls-stat-num {
    font-weight: 800;
    font-size: 1.5rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    line-height: 1;
  }
  .cls-stat-lbl {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin-top: 0.4rem;
  }

  /* ── Modal d'edició ──────────────────────────────── */
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
    position: sticky;
    top: 0;
    background: var(--paper-elevated);
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .modal-title {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.022em;
    margin: 0;
  }
  .modal-close {
    background: transparent;
    border: none;
    color: var(--ink-3);
    font-size: 1.5rem;
    width: 2rem;
    height: 2rem;
    cursor: pointer;
  }
  .modal-close:hover { color: var(--ink); }
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
    font-size: 0.95rem;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .match-info-sep {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin: 0.15rem 0;
  }

  .msg {
    padding: 0.65rem 0.85rem;
    font-size: 0.875rem;
    border-left: 3px solid;
  }
  .msg-error { color: var(--accent); border-color: var(--accent); background: rgba(163, 11, 30, 0.05); }
  .msg-success { color: var(--green); border-color: var(--green); background: rgba(45, 110, 62, 0.05); }

  .incompar-banner {
    border-left: 3px solid var(--amber, #b6841c);
    background: rgba(182, 132, 28, 0.06);
    padding: 0.75rem 0.85rem;
    font-size: 0.875rem;
    color: var(--ink);
  }
  .incompar-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 0.6rem;
  }
  .incompar-substituting {
    margin-top: 0.4rem;
    font-size: 0.8125rem;
    color: var(--ink-2);
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
  }
  .link-btn {
    background: none;
    border: none;
    padding: 0;
    color: var(--ink);
    text-decoration: underline;
    font-size: inherit;
    cursor: pointer;
  }
  .hidden { display: none !important; }

  .form-fields { display: flex; flex-direction: column; gap: 0.85rem; }
  .form-field { display: flex; flex-direction: column; gap: 0.35rem; }
  .form-field label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ink-2);
    letter-spacing: -0.005em;
  }

  .averages-preview {
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 0.85rem 1rem;
  }
  .averages-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
    margin-top: 0.55rem;
  }
  .averages-num {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.022em;
    color: var(--ink);
  }
  .averages-lbl {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    margin-top: 0.2rem;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 0.5rem;
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

  /* Responsive */
  @media (max-width: 768px) {
    .results-filters { padding: 1rem; }
    .filter-row-bottom { flex-direction: column; align-items: stretch; gap: 1rem; }
    .filter-search-block { max-width: none; }

    /* Reformatar la taula com a fitxes en mòbil — la versió taula és massa
       densa quan tens 5 columnes amb stacks de 3 línies cadascuna. */
    .results-table-wrap { background: transparent; border: none; }
    .results-table,
    .results-table thead,
    .results-table tbody,
    .results-table tr,
    .results-table th,
    .results-table td {
      display: block;
    }
    .results-table thead { display: none; }
    .results-table tr {
      background: var(--paper-elevated);
      border: 1px solid var(--rule);
      margin-bottom: 0.75rem;
      padding: 0.85rem 1rem;
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 0.5rem 0.75rem;
      align-items: start;
    }
    .results-table tr:hover { background: var(--paper-elevated); }
    .results-table td {
      padding: 0;
      border: none;
    }
    .results-table td.col-num { text-align: right; }

    /* Categoria petita a la part superior */
    .results-table td:nth-child(1) {
      grid-column: 1 / -1;
      padding-bottom: 0.4rem;
      border-bottom: 1px solid var(--rule);
      margin-bottom: 0.4rem;
    }
    /* Jugadors ocupen la columna esquerra principal */
    .results-table td:nth-child(2) {
      grid-column: 1;
      grid-row: 2 / span 3;
    }
    /* Caramboles (3a col) a la dreta */
    .results-table td:nth-child(3) {
      grid-column: 2;
      grid-row: 2;
    }
    /* Mitjanes (4a col) a la dreta sota caramboles */
    .results-table td:nth-child(4) {
      grid-column: 2;
      grid-row: 3;
      padding-top: 0.35rem;
      border-top: 1px dashed var(--rule);
    }
    /* Entrades + Accions per sota */
    .results-table td:nth-child(5),
    .results-table td:nth-child(6) {
      grid-column: 1 / -1;
      padding-top: 0.4rem;
      border-top: 1px solid var(--rule);
      display: flex;
      justify-content: space-between;
      align-items: baseline;
    }
    .results-table td:nth-child(5)::before {
      content: 'Entrades:';
      font-size: 0.625rem;
      font-weight: 600;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--ink-3);
      margin-right: 0.5rem;
    }
    .results-table td:nth-child(6)::before {
      content: 'Accions:';
      font-size: 0.625rem;
      font-weight: 600;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--ink-3);
    }

    /* Stacks compactes a mobile */
    .num-stack { gap: 0; }
    .num-line { font-size: 0.9375rem; }
    .num-line.num-secondary { font-size: 0.8125rem; }
    .num-sep { font-size: 0.625rem; margin: 0.05rem 0; }

    .vs-sep { padding-left: 0; margin: 0.25rem 0; }
    .player-row { gap: 0.4rem; }
    .player-row .player-name { font-size: 0.875rem; }
  }

  @media (max-width: 480px) {
    .cat-pills { gap: 0.3rem; }
    .cat-pill { padding: 0.4rem 0.65rem; font-size: 0.75rem; min-height: 36px; }
  }
</style>
