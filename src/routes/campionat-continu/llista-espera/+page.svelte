<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import Banner from '$lib/components/general/Banner.svelte';
  import { get } from 'svelte/store';
  import { mySociNumero as mySociStore } from '$lib/stores/mySoci';

  type Row = {
    ordre: number;
    soci_numero: number;
    nom: string;
    data_inscripcio: string;
  };

let loading = true;
  let error: string | null = null;
  let rows: Row[] = [];
  let mySociNumero: number | null = null;
  let player20: { soci_numero: number; nom: string } | null = null;
  let countdown = '';
  let timer: ReturnType<typeof setInterval> | null = null;

  onMount(async () => {
    try {
      const { supabase } = await import('$lib/supabaseClient');

      // Usuari actual — usem el store centralitzat
      mySociNumero = get(mySociStore);
      if (mySociNumero == null) {
        await new Promise<void>((resolve) => {
          const u = mySociStore.subscribe((v) => {
            if (v != null) { mySociNumero = v; u(); resolve(); }
          });
          setTimeout(() => { u(); resolve(); }, 2000);
        });
      }

      // Event actiu
      const { data: ev } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .eq('tipus_competicio', 'ranking_continu')
        .order('data_inici', { ascending: false })
        .limit(1)
        .maybeSingle();
      const eventId = (ev as any)?.id as string | null;

      // Llista d'espera
      const { data, error: err } = await supabase.rpc('get_waiting_list');
      if (err) error = err.message;
      else rows = data ?? [];

      // Jugador posicio 20 (per reptar)
      if (eventId) {
        const { data: p20 } = await supabase
          .from('ranking_positions')
          .select('soci_numero, socis!ranking_positions_soci_numero_fkey(nom, cognoms)')
          .eq('event_id', eventId)
          .eq('posicio', 20)
          .maybeSingle();
        if (p20) {
          const soci: any = Array.isArray((p20 as any).socis) ? (p20 as any).socis[0] : (p20 as any).socis;
          const fullName = soci
            ? `${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim()
            : '';
          player20 = { soci_numero: (p20 as any).soci_numero, nom: fullName };
        }
      }

      // Configurar countdown si soc el primer de la llista
      if (rows.length > 0 && mySociNumero === rows[0].soci_numero) {
        setupCountdown(rows[0].data_inscripcio);
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });

  onDestroy(() => {
    if (timer) clearInterval(timer);
  });

  function setupCountdown(dataInscripcio: string) {
    const updateCountdown = () => {
      const inscripcio = new Date(dataInscripcio);
      const deadline = new Date(inscripcio.getTime() + 15 * 24 * 60 * 60 * 1000); // +15 dies
      const now = new Date();
      const remaining = deadline.getTime() - now.getTime();

      if (remaining <= 0) {
        countdown = 'Temps expirat';
        if (timer) clearInterval(timer);
        return;
      }

      const dies = Math.floor(remaining / (1000 * 60 * 60 * 24));
      const hores = Math.floor((remaining % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
      const minuts = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));
      
      countdown = `${dies}d ${hores}h ${minuts}m`;
    };

    updateCountdown(); // Actualitza immediatament
    timer = setInterval(updateCountdown, 60000); // Cada minut
  }

  function reptar() {
    if (player20) goto(`/campionat-continu/reptes/nou?access=1&opponent_soci=${player20.soci_numero}`);
  }
</script>

<svelte:head>
  <title>Llista d'espera — Campionat Continu</title>
</svelte:head>

<div class="wait-root">

<header class="page-mast">
  <div>
    <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Campionat continu</div>
    <h1 class="page-title">Llista d'espera</h1>
  </div>
</header>

{#if rows.length && mySociNumero === rows[0].soci_numero}
  <div class="info-callout">
    <div class="callout-text">
      Tens <strong class="tabular-nums">{countdown}</strong> per reptar la posició 20{player20 ? ` — ${player20.nom}` : ''}.
    </div>
    {#if player20}
      <button class="btn-primary" on:click={reptar}>
        Reptar posició 20 →
      </button>
    {/if}
  </div>
{/if}

{#if loading}
  <div class="state-empty">Carregant llista d'espera…</div>
{:else if error}
  <div class="state-empty error-state">{error}</div>
{:else if rows.length === 0}
  <div class="state-empty">No hi ha ningú en llista d'espera.</div>
{:else}
  <div class="wait-table-wrap">
    <table class="wait-table">
      <thead>
        <tr>
          <th class="col-pos">Ordre</th>
          <th class="col-left">Jugador</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr>
            <td class="col-pos"><span class="pos-num tabular-nums">{r.ordre.toString().padStart(2, '0')}</span></td>
            <td class="col-left"><span class="player-name">{r.nom}</span></td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}

</div>

<style>
  .wait-root {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .page-mast {
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--ink);
  }
  .editorial-eyebrow {
    font-size: 0.75rem; font-weight: 600;
    letter-spacing: 0.16em; text-transform: uppercase;
    color: var(--sec-continu);
  }
  .page-title {
    font-weight: 800; font-size: 2rem;
    letter-spacing: -0.025em; line-height: 1.05;
    margin: 0; color: var(--ink);
  }

  .info-callout {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    border-left: 3px solid var(--blue);
    padding: 1rem 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }
  .callout-text { color: var(--ink); font-size: 0.9375rem; }
  .callout-text strong { color: var(--ink); font-weight: 700; }

  .btn-primary {
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
    padding: 0.55rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .btn-primary:hover { opacity: 0.92; }

  .state-empty {
    padding: 1.5rem 1.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
  }
  .state-empty.error-state { color: var(--accent); border-color: var(--accent); }

  .wait-table-wrap {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    overflow-x: auto;
  }
  .wait-table {
    width: 100%;
    border-collapse: collapse;
  }
  .wait-table th {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    padding: 0.85rem;
    border-bottom: 1px solid var(--rule);
    background: var(--paper);
    text-align: left;
  }
  .wait-table th.col-pos { width: 5rem; padding-left: 1.25rem; }
  .wait-table td {
    padding: 0.85rem;
    border-bottom: 1px solid var(--rule);
    color: var(--ink);
  }
  .wait-table td.col-pos { padding-left: 1.25rem; }
  .wait-table tr:last-child td { border-bottom: none; }
  .wait-table tr:hover { background: var(--paper); }
  .pos-num {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.02em;
    color: var(--ink);
  }
  .player-name {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
    font-size: 1rem;
  }
</style>
