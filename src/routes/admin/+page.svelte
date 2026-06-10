<script lang="ts">
    import { onMount } from 'svelte';
    import { goto, invalidateAll, invalidate } from '$app/navigation';
    import { user } from '$lib/stores/auth';
    import { adminChecked } from '$lib/stores/adminAuth';
    import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { supabase } from '$lib/supabaseClient';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';
  import { runDeadlines, type RunDeadlinesResult } from '$lib/deadlinesService';
  import { authFetch } from '$lib/utils/http';
  import { showConfirm } from '$lib/stores/confirmDialogStore';

  let loading = true;
  let error: string | null = null;

  let challenge_id = '';
  let tipus: 'incompareixenca' | 'desacord_dates' = 'incompareixenca';
  let penaltyBusy = false;
  let penaltyOk: string | null = null;
  let penaltyErr: string | null = null;

  let preBusy = false;
  let preOk: string | null = null;
  let preErr: string | null = null;

  let inactBusy = false;
  let inactOk: string | null = null;
  let inactErr: string | null = null;

  let resetBusy = false;
  let resetOk: string | null = null;
  let resetErr: string | null = null;

  let captureBusy = false;
  let captureOk: string | null = null;
  let captureErr: string | null = null;

  let deadlinesBusy = false;
  let deadlinesRes: RunDeadlinesResult | null = null;
  let deadlinesErr: string | null = null;

  type Change = {
    creat_el: string;
    soci_numero: number;
    posicio_anterior: number | null;
    posicio_nova: number | null;
    motiu: string | null;
  };

  let recent: Change[] = [];
  let recentPlayers: Record<number, string> = {};
  let histLoading = false;
  let histErr: string | null = null;


  onMount(async () => {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        // si no hi ha sessió, cap a login
        goto('/login');
        return;
      }

      await loadRecent();

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  // Reactively check admin status
  $: {
    if ($adminChecked && !$effectiveIsAdmin && $user?.email) {
      error = errText('Només els administradors poden accedir a aquesta pàgina.');
    } else if ($adminChecked && $effectiveIsAdmin) {
      error = null;
    }
  }

  async function applyPenalty() {
    try {
      penaltyBusy = true;
      penaltyOk = null;
      penaltyErr = null;
      const res = await authFetch('/campionat-continu/reptes/penalitzacions', {
        method: 'POST',
        body: JSON.stringify({ challenge_id, tipus })
      });
      const js = await res.json();
      if (!res.ok || !js.ok) throw new Error(js.error || 'Error aplicant penalització');
      penaltyOk = 'Penalització aplicada';
      challenge_id = '';
      tipus = 'incompareixenca';
    } catch (e) {
      penaltyErr = formatSupabaseError(e);
    } finally {
      penaltyBusy = false;
    }
  }

  async function execPreInactivity() {
    try {
      preBusy = true;
      preOk = null;
      preErr = null;
      const { data: events, error: eventsError } = await supabase.from('events').select('id');
      if (eventsError) throw eventsError;
      for (const event of events) {
        const { error } = await supabase.rpc('apply_pre_inactivity', {
          p_event: event.id
        });
        if (error) throw error;
      }
      preOk = 'Pre-inactivitat executada per a tots els esdeveniments.';
    } catch (e) {
      preErr = formatSupabaseError(e);
    } finally {
      preBusy = false;
    }
  }

  async function execInactivity() {
    try {
      inactBusy = true;
      inactOk = null;
      inactErr = null;
      const { data: events, error: eventsError } = await supabase.from('events').select('id');
      if (eventsError) throw eventsError;
      for (const event of events) {
        const { error } = await supabase.rpc('apply_inactivity', {
          p_event: event.id
        });
        if (error) throw error;
      }
      inactOk = 'Inactivitat executada per a tots els esdeveniments.';
    } catch (e) {
      inactErr = formatSupabaseError(e);
    } finally {
      inactBusy = false;
    }
  }


  async function processDeadlines() {
    try {
      deadlinesBusy = true;
      deadlinesErr = null;
      deadlinesRes = null;
      const res = await runDeadlines(supabase, $user?.email ?? null);
      deadlinesRes = res;
      await Promise.all([invalidate('/reptes'), invalidate('/campionat-continu/gestio-reptes')]);
    } catch (e) {
      deadlinesErr = formatSupabaseError(e);
    } finally {
      deadlinesBusy = false;
    }
  }
  async function captureInitialRanking() {
    try {
      captureBusy = true;
      captureOk = null;
      captureErr = null;
      const { error } = await supabase.rpc('capture_initial_ranking', {
        p_event: null
      });
      if (error) throw error;
      captureOk = 'Rànquing actual desat com a estat inicial';
    } catch (e) {
      captureErr = formatSupabaseError(e);
    } finally {
      captureBusy = false;
    }
  }

  async function resetChampionship() {
    const ok = await showConfirm({
      title: 'Reset del campionat',
      message: 'Aquesta acció eliminarà reptes, partides i historial del campionat actual i en crearà un de nou. No es pot desfer.\n\nEstàs segur que vols continuar?',
      severity: 'danger',
      confirmLabel: 'Sí, reset complet'
    });
    if (!ok) return;
    try {
      resetBusy = true;
      resetOk = null;
      resetErr = null;
      // Usar la nova funció admin_reset_championship directament
      const { data: result, error } = await supabase.rpc('admin_reset_championship');
      
      if (error) {
        throw new Error(`Error executant el reset: ${error.message}`);
      }
      
      if (result) {
        const evId = result.new_event_id;
        const deleted = result.deleted_records ?? {};
        resetOk = `✅ Reset completat — event: ${evId} — esborrats: ${deleted.challenges || 0} reptes, ${deleted.matches || 0} partides, ${deleted.history_position_changes || 0} històric. Base de dades buida i preparada.`;
      } else {
        resetOk = 'Reset del campionat completat correctament';
      }
      await loadRecent();
      await Promise.all([
        invalidate('/reptes'),
        invalidate('/campionat-continu/gestio-reptes'),
        invalidate('/campionat-continu/ranking'),
        invalidate('/llista-espera'),
        invalidateAll()
      ]);
    } catch (e) {
      resetErr = e instanceof Error ? e.message : formatSupabaseError(e);
    } finally {
      resetBusy = false;
    }
  }

  async function loadRecent() {
    try {
      histLoading = true;
      histErr = null;
      const { data: ev, error: eEv } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .order('creat_el', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (eEv) throw eEv;
      const eventId = ev?.id;
      if (!eventId) return;
      const { data: rows, error: eHist } = await supabase
        .from('history_position_changes')
        .select('creat_el, soci_numero, posicio_anterior, posicio_nova, motiu')
        .eq('event_id', eventId)
        .order('creat_el', { ascending: false })
        .limit(10);
      if (eHist) throw eHist;
      recent = (rows ?? []) as unknown as Change[];
      const nums = Array.from(new Set(recent.map((r) => r.soci_numero)));
      if (nums.length > 0) {
        const { data: pl, error: ePl } = await supabase
          .from('socis')
          .select('numero_soci, nom')
          .in('numero_soci', nums);
        if (ePl) throw ePl;
        for (const p of pl ?? []) {
          recentPlayers[p.numero_soci] = p.nom;
        }
      }
    } catch (e) {
      histErr = formatSupabaseError(e);
    } finally {
      histLoading = false;
    }
  }
</script>

<svelte:head>
  <title>Administració</title>
</svelte:head>

<div class="admin-root">
  <header class="mast-head">
    <div class="editorial-eyebrow">Foment Martinenc · Secció billar</div>
    <h1 class="page-title">Administració</h1>
    <p class="page-sub">
      Eines de gestió del club. Les funcions específiques de cada modalitat
      (socials, continu, hàndicap) ara viuen dins el seu propi mòdul.
    </p>
  </header>

  {#if loading}
    <p class="muted">Carregant…</p>
  {:else if error}
    <Banner type="error" message={error} />
  {:else if $effectiveIsAdmin}

    <!-- ── SECCIÓ: GESTIÓ DEL CLUB (cross-cutting) ──────────────── -->
    <section class="ad-section">
      <div class="ad-section-head">
        <div class="editorial-eyebrow">01</div>
        <h2 class="ad-section-title">Gestió del club</h2>
      </div>
      <div class="ad-grid">
        <a href="/admin/socis" class="ad-card">
          <div class="ad-card-eyebrow">Cens</div>
          <h3 class="ad-card-title">Socis</h3>
          <p class="ad-card-body">Alta, baixa i modificació de socis del club.</p>
        </a>

        <a href="/admin/events" class="ad-card">
          <div class="ad-card-eyebrow">Calendari general</div>
          <h3 class="ad-card-title">Events i competicions</h3>
          <p class="ad-card-body">Crear i gestionar el cicle de vida de campionats: socials, continu i hàndicap.</p>
        </a>

        <a href="/admin/categories" class="ad-card">
          <div class="ad-card-eyebrow">Configuració</div>
          <h3 class="ad-card-title">Categories i promocions</h3>
          <p class="ad-card-body">Configura categories dels socials i mitjanes mínimes de promoció.</p>
        </a>

        <a href="/admin/content-editor" class="ad-card">
          <div class="ad-card-eyebrow">Continguts</div>
          <h3 class="ad-card-title">Editor de pàgina principal</h3>
          <p class="ad-card-body">Horaris d'obertura, normativa i serveis al soci.</p>
        </a>
      </div>
    </section>

    <!-- ── SECCIÓ: OPERACIONS DEL RÀNQUING CONTINU ─────────────── -->
    <section class="ad-section">
      <div class="ad-section-head">
        <div class="editorial-eyebrow">02</div>
        <h2 class="ad-section-title">Operacions del rànquing continu</h2>
        <p class="ad-section-sub">Paràmetres, accions diàries i operacions destructives sobre el campionat continu.</p>
      </div>
      <div class="ad-grid">
        <!-- Paràmetres -->
        <a href="/admin/configuracio" class="ad-card">
          <div class="ad-card-eyebrow">Configuració</div>
          <h3 class="ad-card-title">Paràmetres del rànquing continu</h3>
          <p class="ad-card-body">Caramboles, entrades, terminis, cooldowns i inactivitat.</p>
        </a>

        <a href="/campionat-continu/gestio-llista-espera" class="ad-card">
          <div class="ad-card-eyebrow">Operacions</div>
          <h3 class="ad-card-title">Llistes d'espera</h3>
          <p class="ad-card-body">Gestió de llistes d'espera del rànquing continu quan hi ha places limitades.</p>
        </a>

        <a href="/admin/audit-log" class="ad-card">
          <div class="ad-card-eyebrow">Traçabilitat</div>
          <h3 class="ad-card-title">Registre d'auditoria</h3>
          <p class="ad-card-body">Histori de canvis al rànquing, reptes i estats dels jugadors.</p>
        </a>

        <!-- Widget: penalitzacions -->
        <div class="ad-card ad-card-widget">
          <div class="ad-card-eyebrow">Acció puntual</div>
          <h3 class="ad-card-title">Penalitzacions</h3>
          {#if penaltyOk}<Banner type="success" message={penaltyOk} class="mb-2" />{/if}
          {#if penaltyErr}<Banner type="error" message={penaltyErr} class="mb-2" />{/if}
          <form class="ad-form" on:submit|preventDefault={applyPenalty}>
            <input
              class="ad-input"
              placeholder="ID repte"
              bind:value={challenge_id}
            />
            <select class="ad-input" bind:value={tipus}>
              <option value="incompareixenca">Incompareixença</option>
              <option value="desacord_dates">Desacord de dates</option>
            </select>
            <button type="submit" class="ad-btn ad-btn-primary" disabled={penaltyBusy}>
              {penaltyBusy ? 'Aplicant…' : 'Aplica penalització'}
            </button>
          </form>
        </div>

        <!-- Widget: inactivitat -->
        <div class="ad-card ad-card-widget">
          <div class="ad-card-eyebrow">Acció massiva</div>
          <h3 class="ad-card-title">Inactivitat</h3>
          {#if preOk}<Banner type="success" message={preOk} class="mb-2" />{/if}
          {#if preErr}<Banner type="error" message={preErr} class="mb-2" />{/if}
          <button class="ad-btn ad-btn-secondary" on:click={execPreInactivity} disabled={preBusy}>
            {preBusy ? 'Executant…' : 'Pre-inactivitat (21 dies)'}
          </button>
          {#if inactOk}<Banner type="success" message={inactOk} class="mt-2 mb-2" />{/if}
          {#if inactErr}<Banner type="error" message={inactErr} class="mt-2 mb-2" />{/if}
          <button class="ad-btn ad-btn-secondary mt-2" on:click={execInactivity} disabled={inactBusy}>
            {inactBusy ? 'Executant…' : 'Inactivitat (42 dies)'}
          </button>
        </div>

        <!-- Widget: terminis reptes -->
        <div class="ad-card ad-card-widget">
          <div class="ad-card-eyebrow">Acció massiva</div>
          <h3 class="ad-card-title">Terminis de reptes</h3>
          {#if deadlinesRes}
            <div class="ad-stats">
              <p>Reptes processats: <strong>{deadlinesRes.challengesProcessed}</strong></p>
              <p>Inactivitats processades: <strong>{deadlinesRes.inactivityProcessed}</strong></p>
              {#if deadlinesRes.raw.length > 0}
                <details class="ad-details">
                  <summary>Detall complet</summary>
                  <pre>{JSON.stringify(deadlinesRes.raw, null, 2)}</pre>
                </details>
              {/if}
            </div>
          {/if}
          {#if deadlinesErr}<Banner type="error" message={deadlinesErr} class="mb-2" />{/if}
          <button class="ad-btn ad-btn-primary" on:click={processDeadlines} disabled={deadlinesBusy}>
            {deadlinesBusy ? 'Processant…' : 'Processar terminis'}
          </button>
        </div>

        <!-- Widget: moviments recents -->
        <div class="ad-card ad-card-widget">
          <div class="ad-card-eyebrow">Informació</div>
          <h3 class="ad-card-title">Moviments recents</h3>
          {#if histErr}<Banner type="error" message={histErr} class="mb-2" />{/if}
          {#if histLoading}
            <Loader />
          {:else if recent.length > 0}
            <ul class="ad-list">
              {#each recent as r}
                <li>
                  <span class="tabular-nums">{new Date(r.creat_el).toLocaleDateString()}</span> ·
                  <span class="tabular-nums">{r.posicio_anterior ?? '—'}→{r.posicio_nova ?? '—'}</span> ·
                  {recentPlayers[r.soci_numero] ?? 'Jugador desconegut'}
                  {#if r.motiu}· <span class="muted">{r.motiu.slice(0, 30)}</span>{/if}
                </li>
              {/each}
            </ul>
            <a href="/campionat-continu/historial-canvis-ranking" class="ad-link">Veure tots els canvis →</a>
          {:else}
            <p class="muted">Cap moviment recent.</p>
          {/if}
        </div>

        <!-- Reset rànquing (capture + reset) -->
        <div class="ad-card ad-card-widget ad-card-danger">
          <div class="ad-card-eyebrow ad-card-eyebrow-danger">Operació destructiva</div>
          <h3 class="ad-card-title">Estat inicial i reset del rànquing</h3>
          {#if captureOk}<Banner type="success" message={captureOk} class="mb-2" />{/if}
          {#if captureErr}<Banner type="error" message={captureErr} class="mb-2" />{/if}
          {#if resetOk}<Banner type="success" message={resetOk} class="mb-2" />{/if}
          {#if resetErr}<Banner type="error" message={resetErr} class="mb-2" />{/if}
          <button class="ad-btn ad-btn-secondary" on:click={captureInitialRanking} disabled={captureBusy}>
            {captureBusy ? 'Desant…' : 'Desa rànquing actual com a estat inicial'}
          </button>
          <p class="ad-card-note">A partir d'ara, el botó <em>Reset</em> restaurarà aquest estat.</p>
          <button class="ad-btn ad-btn-danger mt-2" on:click={resetChampionship} disabled={resetBusy}>
            {resetBusy ? 'Resetant…' : 'Reset rànquing continu'}
          </button>
        </div>

        <!-- Reset complet del campionat -->
        <a href="/admin/reset-campionat" class="ad-card ad-card-danger">
          <div class="ad-card-eyebrow ad-card-eyebrow-danger">Operació destructiva</div>
          <h3 class="ad-card-title">Reset complet del campionat</h3>
          <p class="ad-card-body">
            Esborra reptes, partides, rànquing i historial del campionat actual.
            Es preserven socis i mitjanes històriques. Crea un nou esdeveniment.
          </p>
          <p class="ad-card-warn">No es pot desfer.</p>
        </a>

        <!-- Reset hàndicap -->
        <a href="/admin/reset-handicap" class="ad-card ad-card-danger">
          <div class="ad-card-eyebrow ad-card-eyebrow-danger">Operació destructiva</div>
          <h3 class="ad-card-title">Reset hàndicap</h3>
          <p class="ad-card-body">
            Esborra un event hàndicap i totes les seves dades (config, participants,
            bracket, partides). Els tornejos finalitzats queden protegits com a històric.
          </p>
          <p class="ad-card-warn">No es pot desfer.</p>
        </a>
      </div>
    </section>

  {/if}
</div>

<style>
  .admin-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  .mast-head {
    margin-bottom: 2rem;
    padding-bottom: 1.25rem;
    border-bottom: 2px solid var(--ink);
  }
  .page-title {
    margin: 0.4rem 0 0.5rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .page-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2);
    max-width: 56ch;
  }

  .ad-section { margin-top: 2.25rem; }
  .ad-section-head {
    margin-bottom: 1rem;
    padding-bottom: 0.65rem;
    border-bottom: 1px solid var(--rule-strong);
  }
  .ad-section-title {
    margin: 0.3rem 0 0;
    font-size: 1.25rem;
    font-weight: 800;
    letter-spacing: -0.018em;
  }
  .ad-section-sub {
    margin: 0.5rem 0 0;
    font-size: 0.8125rem;
    color: var(--ink-3);
  }

  .ad-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 1rem;
  }

  .ad-card {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    padding: 1rem 1.1rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink);
    text-decoration: none;
    transition: border-color 0.15s ease, background 0.15s ease;
  }
  a.ad-card:hover {
    border-color: var(--ink);
    background: var(--paper);
  }
  .ad-card-widget { gap: 0.5rem; }

  .ad-card-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .ad-card-title {
    margin: 0;
    font-size: 1rem;
    font-weight: 700;
    letter-spacing: -0.005em;
  }
  .ad-card-body {
    margin: 0.15rem 0 0;
    font-size: 0.875rem;
    color: var(--ink-2);
    line-height: 1.45;
  }
  .ad-card-note {
    margin: 0.4rem 0 0;
    font-size: 0.75rem;
    color: var(--ink-3);
  }
  .ad-card-warn {
    margin: 0.4rem 0 0;
    font-size: 0.75rem;
    color: var(--accent);
    font-weight: 600;
  }

  .ad-card-danger {
    border: 1px solid var(--accent);
    background: var(--paper);
  }
  .ad-card-eyebrow-danger { color: var(--accent); }

  /* Widgets interns: form, inputs, botons */
  .ad-form {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  .ad-input {
    width: 100%;
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--rule-strong);
    background: var(--paper-elevated);
    font-family: var(--font-sans);
    font-size: 0.875rem;
    color: var(--ink);
  }
  .ad-input:focus {
    outline: 2px solid var(--ink);
    outline-offset: -1px;
  }
  .ad-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.55rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    text-decoration: none;
    min-height: 40px;
  }
  .ad-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .ad-btn-primary {
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
  }
  .ad-btn-primary:hover:not(:disabled) { opacity: 0.9; }
  .ad-btn-secondary {
    background: var(--paper-elevated);
    color: var(--ink);
    border: 1px solid var(--rule-strong);
  }
  .ad-btn-secondary:hover:not(:disabled) { border-color: var(--ink); }
  .ad-btn-danger {
    background: var(--accent);
    color: var(--paper);
    border: 1px solid var(--accent);
  }
  .ad-btn-danger:hover:not(:disabled) { opacity: 0.9; }

  .ad-stats { font-size: 0.875rem; }
  .ad-stats p { margin: 0.15rem 0; }
  .ad-details {
    margin-top: 0.4rem;
    font-size: 0.75rem;
  }
  .ad-details summary {
    cursor: pointer;
    color: var(--ink-3);
    font-weight: 600;
  }
  .ad-details pre {
    margin: 0.4rem 0 0;
    max-height: 12rem;
    overflow: auto;
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 0.5rem;
    font-size: 0.6875rem;
  }

  .ad-list {
    margin: 0.25rem 0 0.5rem;
    padding: 0;
    list-style: none;
    font-size: 0.8125rem;
    color: var(--ink-2);
  }
  .ad-list li { padding: 0.2rem 0; border-bottom: 1px solid var(--rule); }
  .ad-list li:last-child { border-bottom: none; }
  .ad-link {
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink);
    text-decoration: none;
    border-bottom: 1px solid var(--ink);
  }
  .ad-link:hover { color: var(--accent); border-color: var(--accent); }

  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .muted { color: var(--ink-3); font-size: 0.875rem; }
  /* (.tabular-nums, .mb-2, .mt-2 ja les proporciona Tailwind) */
</style>
