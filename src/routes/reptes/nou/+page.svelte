<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { getSettings } from '$lib/settings';

  type RankedPlayer = { posicio: number; player_id: string; nom: string };

  let loading = true;
  let err: string | null = null;
  let ok: string | null = null;

  let myPlayerId: string | null = null;
  let myPos: number | null = null;
  let eventId: string | null = null;

  let allRank: RankedPlayer[] = [];
  let reptables: RankedPlayer[] = [];

  let selectedOpponent: string | null = null;
  let notes: string = '';

  onMount(async () => {
    try {
      loading = true; err = null; ok = null;
      const settings = await getSettings();

      // 1) Sessió i player_id
      const { data: s } = await supabase.auth.getSession();
      const email = s?.session?.user?.email ?? null;
      if (!email) { err = 'Has d’iniciar sessió.'; return; }

      const qPlayer = await supabase.from('players').select('id').eq('email', email).maybeSingle();
      if (qPlayer.error) throw qPlayer.error;
      if (!qPlayer.data) { err = 'El teu email no està vinculat a cap jugador.'; return; }
      myPlayerId = qPlayer.data.id;

      // 2) Event actiu
      const qEvent = await supabase.from('events').select('id').eq('actiu', true).order('creat_el', { ascending: false }).limit(1).maybeSingle();
      if (qEvent.error) throw qEvent.error;
      if (!qEvent.data) { err = 'No hi ha cap esdeveniment actiu.'; return; }
      eventId = qEvent.data.id;

      // 3) Rànquing complet i meva posició
      const qRank = await supabase
        .from('ranking_positions')
        .select('posicio, player_id, players!inner(nom)')
        .eq('event_id', eventId)
        .order('posicio', { ascending: true });
      if (qRank.error) throw qRank.error;
      allRank = (qRank.data ?? []).map((r: any) => ({
        posicio: r.posicio, player_id: r.player_id, nom: r.players?.nom ?? '—'
      }));

      const mine = allRank.find(r => r.player_id === myPlayerId) ?? null;
      if (!mine) { err = 'No formes part del rànquing actual.'; return; }
      myPos = mine.posicio;

      // 4) Filtre bàsic: només fins a 2 posicions per sobre
      reptables = allRank.filter(r => r.posicio < myPos! && r.posicio >= myPos! - 2);

      // (Pròxims passos: filtrar també per cooldown i si tenen ja un repte actiu)
    } catch (e: any) {
      err = e?.message ?? 'Error carregant dades';
    } finally {
      loading = false;
    }
  });

  async function creaRepte() {
    try {
      err = null; ok = null;
      if (!eventId || !myPlayerId || !selectedOpponent) { err = 'Cal triar oponent.'; return; }

      // Simplificat: creem repte proposat (estat per defecte al backend)
      const { error } = await supabase.from('challenges').insert({
        event_id: eventId,
        reptador_id: myPlayerId,
        reptat_id: selectedOpponent,
        tipus: 'normal',
        observacions: notes || null
      });
      if (error) throw error;
      ok = 'Repte creat correctament.';
      selectedOpponent = null; notes = '';
    } catch (e:any) {
      const msg = String(e?.message || '').toLowerCase();
      if (msg.includes('policy') || msg.includes('row-level security') || msg.includes('permission')) {
        err = 'No tens permisos per crear el repte.';
      } else {
        err = e?.message ?? 'No s’ha pogut crear el repte';
      }
    }
  }
</script>

<svelte:head><title>Nou repte</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Nou repte</h1>

{#if loading}
  <div class="rounded border p-3 animate-pulse text-slate-600">Carregant…</div>
{:else}
  {#if err}<div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{err}</div>{/if}
  {#if ok}<div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{ok}</div>{/if}

  {#if myPos}
    <div class="rounded-2xl border bg-white p-4 shadow-sm mb-4">
      <div class="text-sm text-slate-600">La teva posició: <strong>#{myPos}</strong></div>
    </div>
  {/if}

  <div class="rounded-2xl border bg-white p-4 shadow-sm max-w-xl">
    <div class="grid gap-3">
      <label class="grid gap-1">
        <span class="text-sm text-slate-700">Tria oponent (posicions permeses)</span>
        <select class="rounded-xl border px-3 py-2" bind:value={selectedOpponent}>
          <option value="" disabled selected>— Selecciona jugador —</option>
          {#each reptables as r}
            <option value={r.player_id}>#{r.posicio} — {r.nom}</option>
          {/each}
        </select>
      </label>

      <label class="grid gap-1">
        <span class="text-sm text-slate-700">Observacions (opcional)</span>
        <textarea class="rounded-xl border px-3 py-2" rows="3" bind:value={notes}></textarea>
      </label>

      <div class="flex items-center gap-3 pt-1">
        <button class="rounded-2xl bg-slate-900 text-white px-4 py-2 disabled:opacity-60"
                on:click|preventDefault={creaRepte}
                disabled={!selectedOpponent}>
          Crear repte
        </button>
        <a href="/reptes" class="text-sm underline text-slate-600">Torna</a>
      </div>
    </div>
  </div>
{/if}

<!-- Nota: més endavant afegirem el filtratge per cooldown i repte actiu; de moment limitem per posició. -->
