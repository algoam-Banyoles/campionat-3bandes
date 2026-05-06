<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { refreshCalendarData, getEventsForDate } from '$lib/stores/calendar';
  import MyUpcomingMatchesWidget from '$lib/components/general/MyUpcomingMatchesWidget.svelte';

  let upcomingEvents: any[] = [];
  let loading = true;
  let cancelled = false;

  // Dynamic content variables
  let mainContent = { title: '', content: '' };
  let horarisContent = { title: '', content: '' };
  let normesObligatories = { title: '', content: '' };
  let prohibicions = { title: '', content: '' };
  let normesInscripcio = { title: '', content: '' };
  let normesAssignacio = { title: '', content: '' };
  let normesTemps = { title: '', content: '' };
  let normesRepetir = { title: '', content: '' };
  let serveisSoci = { title: '', content: '' };

  onMount(async () => {
    loading = true;
    try {
      // Paral·lelitzem les dues queries: són independents.
      await Promise.all([refreshCalendarData(), loadPageContent()]);
      if (cancelled) return;

      const today = new Date();
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const todayEvents = getEventsForDate(today);
      const tomorrowEvents = getEventsForDate(tomorrow);

      upcomingEvents = [
        ...todayEvents.map(e => ({ ...e, isToday: true })),
        ...tomorrowEvents.map(e => ({ ...e, isToday: false }))
      ];
    } catch (error) {
      console.error('❌ Error carregant esdeveniments:', error);
    } finally {
      if (!cancelled) loading = false;
    }
  });

  onDestroy(() => {
    cancelled = true;
  });

  async function loadPageContent() {
    try {
      const { data, error } = await supabase
        .from('page_content')
        .select('page_key, title, content')
        .in('page_key', [
          'home_main', 'horaris', 'normes_obligatories', 'prohibicions',
          'normes_inscripcio', 'normes_assignacio', 'normes_temps',
          'normes_repetir', 'serveis_soci'
        ]);

      if (error) throw error;

      data?.forEach((item) => {
        const content = { title: item.title || '', content: item.content || '' };
        switch (item.page_key) {
          case 'home_main': mainContent = content; break;
          case 'horaris': horarisContent = content; break;
          case 'normes_obligatories': normesObligatories = content; break;
          case 'prohibicions': prohibicions = content; break;
          case 'normes_inscripcio': normesInscripcio = content; break;
          case 'normes_assignacio': normesAssignacio = content; break;
          case 'normes_temps': normesTemps = content; break;
          case 'normes_repetir': normesRepetir = content; break;
          case 'serveis_soci': serveisSoci = content; break;
        }
      });
    } catch (error) {
      console.error('❌ Error carregant contingut de pàgina:', error);
    }
  }

  function formatTime(date: Date): string {
    return date.toLocaleTimeString('ca-ES', { hour: '2-digit', minute: '2-digit' });
  }

  function eventTagLabel(event: any): string {
    if (event.type === 'challenge') {
      const sub = event.subtype as string | undefined;
      if (sub?.startsWith('campionat-social')) return 'Social';
      if (sub?.startsWith('handicap')) return 'Hàndicap';
      return 'Continu';
    }
    return 'General';
  }
</script>


<div class="home stack-xl">
  <!-- ────────── Hero ────────── -->
  <header class="hero">
    <div class="editorial-eyebrow strong">Foment Martinenc · Secció Billar</div>
    <h1 class="display">
      {mainContent.title || 'Benvinguts a la Secció de Billar'}
    </h1>
    {#if mainContent.content}
      <div class="lede-cols prose prose-sm max-w-none">{@html mainContent.content}</div>
    {:else}
      <div class="lede-cols">
        <p>
          La Secció de Billar del Foment Martinenc és un espai dedicat a la pràctica i promoció
          del billar. Oferim instal·lacions modernes i un ambient familiar per a jugadors de
          tots els nivells.
        </p>
        <p>
          Per poder jugar — ja sigui de manera amistosa com als nostres campionats — cal ser
          soci del Foment Martinenc i de la secció. Contacta amb nosaltres per a més informació
          sobre com fer-te soci i començar a competir.
        </p>
      </div>
    {/if}
  </header>

  <!-- ────────── Les meves properes partides (només usuaris loggats amb soci) ────────── -->
  <MyUpcomingMatchesWidget limit={5} />

  <!-- ────────── Properes activitats ────────── -->
  <section>
    <div class="section-head">
      <h2>Properes activitats</h2>
      <a class="link" href="/general/calendari">Calendari complet →</a>
    </div>

    {#if loading}
      <div class="state-empty">Carregant activitats…</div>
    {:else if upcomingEvents.length === 0}
      <div class="state-empty">No hi ha activitats programades per avui ni demà. Consulta el calendari complet per veure pròximes activitats.</div>
    {:else}
      {@const todayList = upcomingEvents.filter(e => e.isToday)}
      {@const tomorrowList = upcomingEvents.filter(e => !e.isToday)}

      {#if todayList.length > 0}
        <article class="day-block">
          <div class="day-marker">
            Avui
            <span class="date tabular-nums">
              {new Date().toLocaleDateString('ca-ES', { weekday: 'long', day: 'numeric', month: 'long' })}
            </span>
          </div>
          <div class="events">
            {#each todayList as event}
              <div class="event-row">
                <div class="event-time tabular-nums">{formatTime(event.start)}</div>
                <div class="event-title">{event.title}</div>
                <div class="event-tag">{eventTagLabel(event)}</div>
              </div>
            {/each}
          </div>
        </article>
      {/if}

      {#if tomorrowList.length > 0}
        <article class="day-block">
          <div class="day-marker">
            Demà
            <span class="date tabular-nums">
              {(() => { const t = new Date(); t.setDate(t.getDate() + 1); return t.toLocaleDateString('ca-ES', { weekday: 'long', day: 'numeric', month: 'long' }); })()}
            </span>
          </div>
          <div class="events">
            {#each tomorrowList as event}
              <div class="event-row">
                <div class="event-time tabular-nums">{formatTime(event.start)}</div>
                <div class="event-title">{event.title}</div>
                <div class="event-tag">{eventTagLabel(event)}</div>
              </div>
            {/each}
          </div>
        </article>
      {/if}
    {/if}
  </section>

  <!-- ────────── Horari d'obertura ────────── -->
  <section>
    <div class="section-head">
      <h2>{horarisContent.title || "Horari d'obertura"}</h2>
      <span class="editorial-eyebrow">Subjecte als horaris del bar</span>
    </div>

    <div class="schedule-block">
      {#if horarisContent.content}
        <div class="schedule-cms prose prose-sm max-w-none">{@html horarisContent.content}</div>
      {:else}
        <div class="schedule-cols">
          <div>
            <div class="editorial-eyebrow" style="margin-bottom: 0.65rem;">Horari</div>
            <table class="schedule-table">
              <tbody>
                <tr>
                  <td class="day">Dilluns, dimecres, dijous, dissabte i diumenge</td>
                  <td class="hours tabular-nums">9:00 – 21:30</td>
                </tr>
                <tr>
                  <td class="day">Dimarts i divendres</td>
                  <td class="hours tabular-nums">10:30 – 21:30</td>
                </tr>
                <tr>
                  <td class="day muted">Agost i festius oficials</td>
                  <td class="hours muted">Tancat</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div>
            <div class="editorial-eyebrow" style="margin-bottom: 0.65rem;">Aclariments</div>
            <p class="schedule-note-body">
              L'horari d'atenció al públic del Foment és de <strong>dilluns a divendres de 9:00 a 13:00 i de 16:00 a 20:00</strong>.
              Les seccions poden tenir activitat fora d'aquest horari si el bar està obert.
              La secció romandrà tancada els dies de tancament oficial del Foment.
            </p>
          </div>
        </div>
      {/if}
    </div>
  </section>

  <!-- ────────── OBLIGATORI ────────── -->
  <section>
    <div class="rule-callout">
      <div class="editorial-eyebrow success" style="margin-bottom: 0.4rem;">Obligatori</div>
      <h2>{normesObligatories.title || 'Abans de cada partida'}</h2>
      {#if normesObligatories.content}
        <div class="prose prose-sm max-w-none rule-body">{@html normesObligatories.content}</div>
      {:else}
        <ul class="rule-list">
          <li>Netejar el <strong>billar i les boles</strong> amb el material que la Secció posa a disposició dels socis.</li>
        </ul>
      {/if}
    </div>
  </section>

  <!-- ────────── PROHIBIT ────────── -->
  <section>
    <div class="rule-callout danger">
      <div class="editorial-eyebrow danger" style="margin-bottom: 0.4rem;">Prohibit</div>
      <h2>{prohibicions.title || 'No es pot'}</h2>
      {#if prohibicions.content}
        <div class="prose prose-sm max-w-none rule-body">{@html prohibicions.content}</div>
      {:else}
        <ul class="rule-list">
          <li>Jugar a fantasia.</li>
          <li>Menjar mentre s'està jugant.</li>
          <li>Posar begudes sobre cap element del billar.</li>
          <li>Posar monedes per allargar el temps, encara que hi hagi billars lliures.</li>
        </ul>
      {/if}
    </div>
  </section>

  <!-- ────────── Normativa de joc (4 sub-blocs) ────────── -->
  <section>
    <div class="section-head">
      <h2>Normativa de joc</h2>
      <span class="editorial-eyebrow">Partides socials lliures</span>
    </div>

    <div class="rules-grid">
      <article class="rule-cell">
        <div class="editorial-eyebrow">Inscripció a partides</div>
        <h3>{normesInscripcio.title || 'Pissarra única'}</h3>
        {#if normesInscripcio.content}
          <div class="prose prose-sm max-w-none rule-body">{@html normesInscripcio.content}</div>
        {:else}
          <ul>
            <li>Apunta't a la pissarra única de <strong>Partides Socials</strong>.</li>
            <li>Els companys no cal que s'apuntin; si ho fan, que sigui al costat del primer jugador.</li>
          </ul>
        {/if}
      </article>

      <article class="rule-cell">
        <div class="editorial-eyebrow">Assignació de billar</div>
        <h3>{normesAssignacio.title || 'Quan hi hagi un lliure'}</h3>
        {#if normesAssignacio.content}
          <div class="prose prose-sm max-w-none rule-body">{@html normesAssignacio.content}</div>
        {:else}
          <ul>
            <li>Quan hi hagi un billar lliure, ratlla el teu nom i juga.</li>
            <li>Si vols un billar concret ocupat, passa el torn fins que s'alliberi.</li>
          </ul>
        {/if}
      </article>

      <article class="rule-cell">
        <div class="editorial-eyebrow">Temps de joc</div>
        <h3>{normesTemps.title || 'Màxim una hora'}</h3>
        {#if normesTemps.content}
          <div class="prose prose-sm max-w-none rule-body">{@html normesTemps.content}</div>
        {:else}
          <ul>
            <li><strong>Màxim 1 hora</strong> per partida (sol o en grup).</li>
            <li>Si hi ha algú esperant, cal alliberar el billar puntualment.</li>
          </ul>
        {/if}
      </article>

      <article class="rule-cell">
        <div class="editorial-eyebrow">Tornar a jugar</div>
        <h3>{normesRepetir.title || 'Només si no hi ha cua'}</h3>
        {#if normesRepetir.content}
          <div class="prose prose-sm max-w-none rule-body">{@html normesRepetir.content}</div>
        {:else}
          <ul>
            <li>Pots repetir només si no hi ha ningú apuntat i hi ha un billar lliure.</li>
          </ul>
        {/if}
      </article>
    </div>
  </section>

  <!-- ────────── Serveis al Soci ────────── -->
  {#if serveisSoci.title || serveisSoci.content}
    <section>
      <div class="section-head">
        <h2>{serveisSoci.title || 'Serveis al Soci'}</h2>
      </div>
      <div class="schedule-block">
        {#if serveisSoci.content}
          <div class="prose prose-sm max-w-none">{@html serveisSoci.content}</div>
        {:else}
          <p class="state-empty-inline">Contingut en preparació.</p>
        {/if}
      </div>
    </section>
  {/if}

  <!-- ────────── Accés ràpid ────────── -->
  <section>
    <h2 style="margin-bottom: 1.25rem;">Accés ràpid</h2>
    <div class="quick-access">
      <a class="qa-card" href="/campionats-socials" data-section="social">
        <div class="qa-num">02 · Socials</div>
        <div class="qa-title">Socials per categories</div>
        <div class="qa-sub">Classificació, calendari i resultats</div>
        <div class="qa-arrow">Veure classificació →</div>
      </a>
      <a class="qa-card" href="/campionat-continu/ranking" data-section="continu">
        <div class="qa-num">03 · Continu</div>
        <div class="qa-title">Rànquing permanent</div>
        <div class="qa-sub">Reptes directes, 20 posicions</div>
        <div class="qa-arrow">Veure el rànquing →</div>
      </a>
      <a class="qa-card" href="/handicap" data-section="handicap">
        <div class="qa-num">04 · Hàndicap</div>
        <div class="qa-title">Torneig d'eliminació</div>
        <div class="qa-sub">1 per temporada · Quadre actual</div>
        <div class="qa-arrow">Veure el quadre →</div>
      </a>
      <a class="qa-card" href="/general/calendari" data-section="general">
        <div class="qa-num">01 · Calendari</div>
        <div class="qa-title">Totes les activitats</div>
        <div class="qa-sub">Vista setmanal i mensual</div>
        <div class="qa-arrow">Obrir calendari →</div>
      </a>
    </div>
  </section>
</div>


<style>
  /* Estructura general */
  .home {
    max-width: 1100px;
    margin: 0 auto;
    padding-bottom: 3rem;
  }
  .stack-xl > :global(* + *) { margin-top: 3.5rem; }

  /* ── Hero ──────────────────────────────────────────── */
  .hero {
    padding: 2.5rem 0 1.75rem;
    border-bottom: 2px solid var(--ink);
  }
  .hero h1.display {
    font-family: var(--font-sans);
    font-weight: 800;
    font-size: 3.25rem;
    line-height: 1.02;
    letter-spacing: -0.035em;
    color: var(--ink);
    margin: 0.5rem 0 1.75rem;
    font-variation-settings: 'opsz' 32;
  }
  .hero .lede-cols {
    column-count: 2;
    column-gap: 2.75rem;
    font-size: 1rem;
    color: var(--ink-2);
    font-weight: 500;
    line-height: 1.6;
    max-width: 68ch;
  }
  .hero .lede-cols :global(p) {
    margin: 0 0 0.85rem;
    break-inside: avoid;
  }
  .hero .lede-cols :global(p:last-child) {
    margin-bottom: 0;
  }
  /* Neutralitza fons / colors heretats del CMS (mainContent.content). */
  .hero .lede-cols :global(*) {
    background-color: transparent !important;
    background-image: none !important;
    border-radius: 0 !important;
  }
  .hero .lede-cols :global([class*='text-blue-']),
  .hero .lede-cols :global([class*='text-gray-']),
  .hero .lede-cols :global([class*='text-yellow-']),
  .hero .lede-cols :global([class*='text-green-']),
  .hero .lede-cols :global([class*='text-red-']),
  .hero .lede-cols :global([class*='text-purple-']),
  .hero .lede-cols :global([class*='text-indigo-']),
  .hero .lede-cols :global([class*='text-orange-']) {
    color: var(--ink-2) !important;
  }
  .hero .lede-cols :global(strong) {
    color: var(--ink) !important;
    font-weight: 700;
  }
  .hero .lede-cols :global(a) {
    color: var(--blue);
    text-decoration: none;
    border-bottom: 1px solid var(--blue);
  }

  /* ── Section heads ─────────────────────────────────── */
  h2 {
    font-family: var(--font-sans);
    font-weight: 700;
    font-size: 1.75rem;
    line-height: 1.15;
    letter-spacing: -0.022em;
    color: var(--ink);
    margin: 0;
    font-variation-settings: 'opsz' 32;
  }
  h3 {
    font-family: var(--font-sans);
    font-weight: 700;
    font-size: 1.125rem;
    line-height: 1.3;
    letter-spacing: -0.014em;
    color: var(--ink);
    margin: 0;
  }
  .section-head {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 1rem;
    margin-bottom: 1.25rem;
    flex-wrap: wrap;
  }
  .section-head .link {
    color: var(--foment-blue, var(--blue));
    text-decoration: none;
    font-weight: 600;
    font-size: 0.9375rem;
    border-bottom: 1px solid var(--blue);
    padding-bottom: 2px;
    white-space: nowrap;
  }

  /* ── Properes activitats (day-block) ───────────────── */
  .day-block {
    display: grid;
    grid-template-columns: 9rem 1fr;
    gap: 2rem;
    padding: 1.5rem 0;
    border-top: 1px solid var(--rule);
  }
  .day-block:last-child {
    border-bottom: 1px solid var(--rule);
  }
  .day-marker {
    font-weight: 800;
    font-size: 1.125rem;
    letter-spacing: -0.014em;
    line-height: 1.2;
    color: var(--ink);
  }
  .day-marker .date {
    display: block;
    font-weight: 500;
    font-size: 0.8125rem;
    color: var(--ink-3);
    margin-top: 0.3rem;
    text-transform: capitalize;
  }
  .events {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }
  .event-row {
    display: grid;
    grid-template-columns: 4.5rem 1fr auto;
    gap: 1rem;
    align-items: baseline;
  }
  .event-time {
    font-weight: 700;
    font-size: 1rem;
    letter-spacing: -0.012em;
    color: var(--ink);
  }
  .event-title {
    font-weight: 500;
    font-size: 0.9375rem;
    color: var(--ink-2);
  }
  .event-tag {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    padding: 0.18rem 0.45rem;
    border: 1px solid var(--rule-strong);
  }

  /* ── Horari d'obertura (taula editorial) ─────────── */
  .schedule-block {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.75rem 2rem;
  }
  /* Layout 2-col: horari | aclariments (només cas fallback amb estructura explícita) */
  .schedule-cols {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2.5rem;
    align-items: start;
  }
  /* Cas CMS: contingut HTML lliure → CSS multicolumn perquè el browser distribueixi */
  .schedule-cms {
    column-count: 2;
    column-gap: 2.5rem;
  }
  .schedule-cms :global(p),
  .schedule-cms :global(div),
  .schedule-cms :global(table) {
    break-inside: avoid;
  }
  .schedule-cms :global(p:first-child) {
    margin-top: 0;
  }
  .schedule-note-body {
    font-size: 0.875rem;
    color: var(--ink-2);
    line-height: 1.55;
    margin: 0;
  }
  .schedule-note-body :global(strong),
  .schedule-note-body strong {
    color: var(--ink);
    font-weight: 700;
  }
  .schedule-table {
    width: 100%;
    border-collapse: collapse;
  }
  .schedule-table tr {
    border-bottom: 1px solid var(--rule);
  }
  .schedule-table tr:last-child {
    border-bottom: none;
  }
  .schedule-table td {
    padding: 0.7rem 0;
    font-weight: 500;
    font-size: 0.9375rem;
    color: var(--ink);
  }
  .schedule-table td.day {
    font-weight: 600;
    width: 60%;
  }
  .schedule-table td.hours {
    text-align: right;
    font-weight: 700;
    letter-spacing: -0.012em;
  }
  .schedule-table td.muted {
    color: var(--ink-3);
    font-weight: 500;
  }
  .schedule-table td.hours.muted {
    font-weight: 600;
  }
  /* (.schedule-note class era usada al template anterior; ara s'usa
     .schedule-note-body que es declara més amunt) */
  /* Mòbil: horari i aclariments apilats verticalment */
  @media (max-width: 900px) {
    .schedule-cols {
      grid-template-columns: 1fr;
      gap: 1.25rem;
    }
    .schedule-cms {
      column-count: 1;
    }
  }
  /* Neutralitza estils heretats del CMS (fons blaus, taronges, etc.) que xoquen
     amb l'estètica editorial. El contingut ve de page_content i pot tenir
     classes Tailwind antigues o styles inline incrustats. Reset total del fons
     per a tots els descendents — després els tractem editorialment. */
  .schedule-block :global(*) {
    background-color: transparent !important;
    background-image: none !important;
    border-radius: 0 !important;
  }
  /* Si dins del contingut hi ha un bloc divisori (div o aside) amb fons original,
     ara que ja l'hem neutralitzat el tractem com a callout editorial subtil. */
  .schedule-block :global(div[class*='bg-']),
  .schedule-block :global(aside[class*='bg-']),
  .schedule-block :global(div[style*='background']) {
    border-left: 3px solid var(--rule-strong) !important;
    padding: 0.85rem 1.1rem !important;
    margin: 1rem 0 0 !important;
    color: var(--ink-2) !important;
    font-size: 0.8125rem !important;
    line-height: 1.55 !important;
  }
  /* Text colors heretats (text-blue-X, etc.) → tinta editorial */
  .schedule-block :global([class*='text-blue-']),
  .schedule-block :global([class*='text-yellow-']),
  .schedule-block :global([class*='text-green-']),
  .schedule-block :global([class*='text-red-']),
  .schedule-block :global([class*='text-purple-']),
  .schedule-block :global([class*='text-indigo-']),
  .schedule-block :global([class*='text-orange-']) {
    color: var(--ink-2) !important;
  }
  .schedule-block :global(strong) {
    color: var(--ink) !important;
    font-weight: 700;
  }

  /* ── Rule callouts (Obligatori / Prohibit) ────────── */
  .rule-callout {
    padding: 1.5rem 1.85rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    border-top: 3px solid var(--green);
  }
  .rule-callout.danger {
    border-top-color: var(--accent);
  }
  .rule-callout h2 {
    margin-bottom: 1rem;
  }
  .rule-list,
  .rule-callout :global(ul) {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  .rule-list li,
  .rule-callout :global(li) {
    position: relative;
    padding-left: 1.25rem;
    font-size: 1rem;
    font-weight: 500;
    color: var(--ink);
    line-height: 1.55;
  }
  .rule-list li + li,
  .rule-callout :global(li + li) {
    margin-top: 0.65rem;
  }
  .rule-list li::before,
  .rule-callout :global(li)::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0.65rem;
    width: 6px;
    height: 6px;
    background: var(--green);
  }
  .rule-callout.danger .rule-list li::before,
  .rule-callout.danger :global(li)::before {
    background: var(--accent);
  }
  .rule-callout :global(strong) {
    color: var(--ink);
    font-weight: 700;
  }
  .rule-body :global(p) {
    margin: 0 0 0.8rem;
  }
  .rule-body :global(p:last-child) {
    margin-bottom: 0;
  }

  /* ── Normativa grid ─────────────────────────────────── */
  .rules-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 0;
    border: 1px solid var(--rule);
    background: var(--paper-elevated);
  }
  .rule-cell {
    padding: 1.6rem 1.85rem;
    border-right: 1px solid var(--rule);
    border-bottom: 1px solid var(--rule);
  }
  .rule-cell:nth-child(2n) {
    border-right: none;
  }
  .rule-cell:nth-last-child(-n+2) {
    border-bottom: none;
  }
  .rule-cell h3 {
    margin: 0.4rem 0 0.85rem;
  }
  .rule-cell ul {
    list-style: none;
    padding: 0;
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2);
  }
  .rule-cell li {
    position: relative;
    padding-left: 1rem;
    line-height: 1.55;
  }
  .rule-cell li + li {
    margin-top: 0.55rem;
  }
  .rule-cell li::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0.6rem;
    width: 4px;
    height: 4px;
    background: var(--ink-3);
  }
  .rule-cell strong,
  .rule-cell :global(strong) {
    color: var(--ink);
    font-weight: 700;
  }
  .rule-cell :global(ul) {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  /* ── Accés ràpid ────────────────────────────────────── */
  .quick-access {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 0;
    border: 1px solid var(--rule);
    background: var(--paper-elevated);
  }
  .qa-card {
    display: flex;
    flex-direction: column;
    padding: 1.85rem 1.6rem;
    border-right: 1px solid var(--rule);
    text-decoration: none;
    color: var(--ink);
    transition: background 0.15s ease;
    min-height: 175px;
  }
  .qa-card:last-child {
    border-right: none;
  }
  .qa-card:hover {
    background: var(--paper);
  }
  .qa-num {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .qa-title {
    font-weight: 800;
    font-size: 1.375rem;
    letter-spacing: -0.024em;
    line-height: 1.05;
    margin-top: 0.65rem;
  }
  .qa-sub {
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--ink-2);
    margin-top: 0.55rem;
  }
  .qa-arrow {
    margin-top: auto;
    padding-top: 1.1rem;
    font-weight: 600;
    font-size: 0.875rem;
    color: var(--blue);
  }
  .qa-card[data-section='social']    { border-top: 3px solid var(--sec-social); }
  .qa-card[data-section='continu']   { border-top: 3px solid var(--sec-continu); }
  .qa-card[data-section='handicap']  { border-top: 3px solid var(--sec-handicap); }
  .qa-card[data-section='general']   { border-top: 3px solid var(--sec-general); }

  /* ── Empty / loading states ────────────────────────── */
  .state-empty {
    padding: 1.5rem 1.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    font-size: 0.9375rem;
  }
  .state-empty-inline {
    margin: 0;
    color: var(--ink-3);
    font-size: 0.9375rem;
  }

  /* ── Responsiu ─────────────────────────────────────── */
  @media (max-width: 900px) {
    .hero {
      padding: 1.75rem 0 1.5rem;
    }
    .hero h1.display {
      font-size: 2.5rem;
      letter-spacing: -0.03em;
      margin-bottom: 1.25rem;
    }
    .hero .lede-cols {
      column-count: 1;
    }
    .day-block {
      grid-template-columns: 1fr;
      gap: 0.85rem;
    }
    .rules-grid {
      grid-template-columns: 1fr;
    }
    .rule-cell {
      border-right: none !important;
    }
    .rule-cell:not(:last-child) {
      border-bottom: 1px solid var(--rule);
    }
    .quick-access {
      grid-template-columns: 1fr 1fr;
    }
    .qa-card:nth-child(2n) {
      border-right: none;
    }
    .qa-card:nth-child(1),
    .qa-card:nth-child(2) {
      border-bottom: 1px solid var(--rule);
    }
  }

  @media (max-width: 640px) {
    .hero h1.display {
      font-size: 2.1rem;
    }
    h2 {
      font-size: 1.5rem;
    }
    .schedule-block {
      padding: 1.25rem 1.25rem;
    }
    .rule-callout {
      padding: 1.25rem 1.4rem;
    }
    .rule-cell {
      padding: 1.25rem 1.4rem;
    }
    .quick-access {
      grid-template-columns: 1fr;
    }
    .qa-card {
      border-right: none !important;
      border-bottom: 1px solid var(--rule);
      min-height: auto;
    }
    .qa-card:last-child {
      border-bottom: none;
    }
    .event-row {
      grid-template-columns: 4rem 1fr;
    }
    .event-tag {
      grid-column: 1 / -1;
      justify-self: flex-start;
    }
  }

  /* High-contrast compat */
  :global(.high-contrast) .schedule-block,
  :global(.high-contrast) .rule-callout,
  :global(.high-contrast) .rules-grid,
  :global(.high-contrast) .quick-access,
  :global(.high-contrast) .qa-card,
  :global(.high-contrast) .state-empty {
    background: #ffffff !important;
    border-color: #000000 !important;
  }
  :global(.high-contrast) .rule-callout {
    border-top-color: var(--accent) !important;
  }
  :global(.high-contrast) .rule-callout:not(.danger) {
    border-top-color: var(--green) !important;
  }
</style>
