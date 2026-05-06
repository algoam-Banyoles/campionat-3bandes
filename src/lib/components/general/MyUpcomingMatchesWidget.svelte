<script lang="ts">
  /**
   * Widget de properes partides de l'usuari loggat.
   *
   * Llista les pròximes partides programades on l'usuari és jugador 1 o 2,
   * a través de tot el `calendari_partides` (sense filtrar per event_id) i
   * fins a un nombre màxim configurable. Pensat per posar a la home després
   * del hero, només visible quan hi ha partides futures programades.
   *
   * Si no n'hi ha cap, el widget no es renderitza.
   */
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { mySociNumero } from '$lib/stores/mySoci';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  export let limit = 5;

  type Match = {
    id: string;
    data_programada: string | null;
    hora_inici: string | null;
    taula_assignada: number | null;
    jugador1_soci_numero: number;
    jugador2_soci_numero: number;
    event_id: string | null;
    categoria_id: string | null;
    j1_nom?: string | null;
    j1_cognoms?: string | null;
    j2_nom?: string | null;
    j2_cognoms?: string | null;
    event_nom?: string | null;
    categoria_nom?: string | null;
  };

  let matches: Match[] = [];
  let loading = false;

  $: if ($mySociNumero != null) {
    loadMatches($mySociNumero);
  } else {
    matches = [];
  }

  async function loadMatches(soci: number) {
    loading = true;
    try {
      const todayIso = new Date().toISOString().slice(0, 10);
      const { data, error } = await supabase
        .from('calendari_partides')
        .select(
          'id, data_programada, hora_inici, taula_assignada, jugador1_soci_numero, jugador2_soci_numero, event_id, categoria_id, estat'
        )
        .or(`jugador1_soci_numero.eq.${soci},jugador2_soci_numero.eq.${soci}`)
        .gte('data_programada', todayIso)
        .neq('estat', 'jugada')
        .neq('estat', 'anullada')
        .order('data_programada', { ascending: true })
        .order('hora_inici', { ascending: true })
        .limit(limit);

      if (error) {
        console.warn('MyUpcomingMatchesWidget:', error);
        matches = [];
        return;
      }

      const rows = (data ?? []) as Match[];
      if (rows.length === 0) {
        matches = [];
        return;
      }

      // Resol noms de jugadors, events i categories en una sola tirada cadascun
      const sociIds = new Set<number>();
      const eventIds = new Set<string>();
      const categoryIds = new Set<string>();
      for (const m of rows) {
        sociIds.add(m.jugador1_soci_numero);
        sociIds.add(m.jugador2_soci_numero);
        if (m.event_id) eventIds.add(m.event_id);
        if (m.categoria_id) categoryIds.add(m.categoria_id);
      }

      const [{ data: socis }, { data: events }, { data: cats }] = await Promise.all([
        supabase.from('socis').select('numero_soci, nom, cognoms').in('numero_soci', Array.from(sociIds)),
        eventIds.size
          ? supabase.from('events').select('id, nom').in('id', Array.from(eventIds))
          : Promise.resolve({ data: [] as any[] }),
        categoryIds.size
          ? supabase.from('categories').select('id, nom').in('id', Array.from(categoryIds))
          : Promise.resolve({ data: [] as any[] })
      ]);

      const sociMap = new Map<number, { nom: string; cognoms: string }>();
      (socis ?? []).forEach((s: any) => sociMap.set(s.numero_soci, { nom: s.nom, cognoms: s.cognoms }));
      const eventMap = new Map<string, string>();
      (events ?? []).forEach((e: any) => eventMap.set(e.id, e.nom));
      const catMap = new Map<string, string>();
      (cats ?? []).forEach((c: any) => catMap.set(c.id, c.nom));

      matches = rows.map((m) => ({
        ...m,
        j1_nom: sociMap.get(m.jugador1_soci_numero)?.nom ?? null,
        j1_cognoms: sociMap.get(m.jugador1_soci_numero)?.cognoms ?? null,
        j2_nom: sociMap.get(m.jugador2_soci_numero)?.nom ?? null,
        j2_cognoms: sociMap.get(m.jugador2_soci_numero)?.cognoms ?? null,
        event_nom: m.event_id ? eventMap.get(m.event_id) ?? null : null,
        categoria_nom: m.categoria_id ? catMap.get(m.categoria_id) ?? null : null
      }));
    } finally {
      loading = false;
    }
  }

  function formatDate(d: string | null): string {
    if (!d) return '—';
    const dt = new Date(d);
    if (isNaN(dt.getTime())) return d;
    return dt.toLocaleDateString('ca-ES', {
      weekday: 'short',
      day: '2-digit',
      month: 'short'
    });
  }

  function opponentName(m: Match, soci: number): string {
    const isPlayer1 = m.jugador1_soci_numero === soci;
    const opNom = isPlayer1 ? m.j2_nom : m.j1_nom;
    const opCog = isPlayer1 ? m.j2_cognoms : m.j1_cognoms;
    return formatarNomJugador(`${opNom ?? ''} ${opCog ?? ''}`.trim());
  }
</script>

{#if $mySociNumero != null && matches.length > 0}
  <section class="ump-section">
    <header class="ump-head">
      <div class="editorial-eyebrow">Per a tu</div>
      <h2 class="ump-title">Les teves properes partides</h2>
    </header>
    <ol class="ump-list">
      {#each matches as m (m.id)}
        <li class="ump-row">
          <div class="ump-date">
            <div class="ump-date-day tabular-nums">{formatDate(m.data_programada)}</div>
            {#if m.hora_inici}
              <div class="ump-date-hour tabular-nums">{m.hora_inici}</div>
            {/if}
          </div>
          <div class="ump-info">
            <div class="ump-opponent">
              vs <strong>{opponentName(m, $mySociNumero)}</strong>
            </div>
            <div class="ump-meta">
              {#if m.event_nom}{m.event_nom}{/if}
              {#if m.categoria_nom}<span class="muted"> · {m.categoria_nom}</span>{/if}
              {#if m.taula_assignada}<span class="muted"> · Billar {m.taula_assignada}</span>{/if}
            </div>
          </div>
        </li>
      {/each}
    </ol>
  </section>
{/if}

<style>
  .ump-section {
    margin-top: 2rem;
    padding: 1.25rem 1.4rem;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    border-left: 3px solid var(--ink, #1a1814);
    font-family: var(--font-sans, sans-serif);
  }
  .ump-head { margin-bottom: 0.85rem; }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .ump-title {
    margin: 0.3rem 0 0;
    font-size: 1.125rem;
    font-weight: 800;
    letter-spacing: -0.012em;
    color: var(--ink, #1a1814);
  }
  .ump-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .ump-row {
    display: flex;
    align-items: flex-start;
    gap: 0.85rem;
    padding: 0.7rem 0;
    border-bottom: 1px solid var(--rule, #e6e3dc);
  }
  .ump-row:last-child { border-bottom: none; }
  .ump-date {
    min-width: 5.5rem;
    flex-shrink: 0;
  }
  .ump-date-day {
    font-size: 0.8125rem;
    font-weight: 700;
    color: var(--ink, #1a1814);
    text-transform: capitalize;
  }
  .ump-date-hour {
    font-size: 0.75rem;
    color: var(--ink-3, #807a72);
  }
  .ump-info { flex: 1; min-width: 0; }
  .ump-opponent {
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
  }
  .ump-opponent strong { color: var(--ink, #1a1814); }
  .ump-meta {
    margin-top: 0.2rem;
    font-size: 0.8125rem;
    color: var(--ink-3, #807a72);
  }
  .muted { color: var(--ink-3, #807a72); }
  .tabular-nums { font-variant-numeric: tabular-nums; }
</style>
