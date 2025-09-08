<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/authStore';

  type Player = { id: string; nom: string; posicio: number | null };

  let loading = true;
  let error: string | null = null;
  let okMsg: string | null = null;

  let eventActiuId: string | null = null;
  let jo: Player | null = null;
  let reptables: Player[] = [];
  let reptat_id = '';
  let d1 = '';
  let d2 = '';
  let d3 = '';
  let observacions = '';
  let busy = false;

  const toISO = (d: string) => {
    if (!d) return null;
    const date = new Date(d);
    return isNaN(date.getTime()) ? null : date.toISOString();
  };

  onMount(load);

  async function load() {
    try {
      loading = true;
      error = null;
      okMsg = null;

      const u = $user;
      if (!u?.email) {
        error = 'Has d’iniciar sessió per crear un repte.';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      // event actiu
      const { data: ev, error: eEv } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();
      if (eEv) throw eEv;
      if (!ev) {
        error = 'No s’ha trobat cap event actiu.';
        return;
      }
      eventActiuId = ev.id;

      // jugador actual
      const { data: me, error: eMe } = await supabase
        .from('players')
        .select('id, nom')
        .eq('email', u.email)
        .maybeSingle();
      if (eMe) throw eMe;
      if (!me) {
        error = 'El teu correu no està vinculat a cap jugador.';
        return;
      }

      // rànquing per obtenir posicions
      const { data: rp, error: eRank } = await supabase
        .from('ranking_positions')
        .select('player_id, posicio, players(id, nom)')
        .eq('event_id', ev.id)
        .order('posicio', { ascending: true });
      if (eRank) throw eRank;

      const posById = new Map(rp?.map(r => [r.player_id, r.posicio]));

      jo = { id: me.id, nom: me.nom, posicio: posById.get(me.id) ?? null };
      reptables = (rp ?? [])
        .map(r => ({
          id: r.player_id,
          nom: (r as any).players?.nom ?? '—',
          posicio: r.posicio
        }))
        .filter(p => p.id !== me.id);
    } catch (e: any) {
      error = e?.message ?? 'Error carregant la pàgina';
    } finally {
      loading = false;
    }
  }

  async function createChallenge() {
    error = null;
    okMsg = null;
    try {
      if (!eventActiuId) throw new Error('No hi ha event actiu.');
      if (!jo) throw new Error('No s’ha pogut determinar el jugador reptador.');
      if (!reptat_id) throw new Error('Has de seleccionar un jugador reptat.');
      if (reptat_id === jo.id) throw new Error('No et pots reptar a tu mateix.');

      const { supabase } = await import('$lib/supabaseClient');

      const dates = [d1, d2, d3].map(toISO).filter(Boolean) as string[];

      const payload = {
        event_id: eventActiuId,
        tipus: 'normal',
        reptador_id: jo.id,
        reptat_id,
        estat: 'proposat',
        dates_proposades: dates,
        data_proposta: new Date().toISOString(),
        data_acceptacio: null,
        observacions: observacions || null,
        pos_reptador: jo.posicio,
        pos_reptat:
          reptables.find(p => p.id === reptat_id)?.posicio ?? null
      };

      busy = true;
      const { error: eIns } = await supabase.from('challenges').insert(payload);
      if (eIns) throw eIns;

      okMsg = 'Repte creat correctament.';
      reptat_id = '';
      d1 = d2 = d3 = '';
      observacions = '';
    } catch (e: any) {
      error = e?.message ?? 'No s’ha pogut crear el repte';
    } finally {
      busy = false;
    }
  }
</script>

<svelte:head>
  <title>Nou repte</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Crear un nou repte</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else}
  {#if error}
    <div class="mb-3 rounded border border-red-300 bg-red-50 p-3 text-red-700">
      {error}
    </div>
  {/if}
  {#if okMsg}
    <div class="mb-3 rounded border border-green-300 bg-green-50 p-3 text-green-700">
      {okMsg}
    </div>
  {/if}

  {#if jo}
    <form class="space-y-4 max-w-xl" on:submit|preventDefault={createChallenge}>
      <div>
        <label for="reptador" class="block text-sm mb-1">Reptador</label>
        <input
          id="reptador"
          class="w-full rounded border px-3 py-2 bg-slate-50"
          value={jo.posicio ? `#${jo.posicio} — ${jo.nom}` : jo.nom}
          disabled
        />
      </div>

      <div>
        <label for="reptat" class="block text-sm mb-1">Jugador reptat</label>
        <select
          id="reptat"
          class="w-full rounded border px-3 py-2"
          bind:value={reptat_id}
          required
        >
          <option value="" disabled selected>— Selecciona —</option>
          {#each reptables as r}
            <option value={r.id}>
              {r.posicio ? `#${r.posicio} — ${r.nom}` : r.nom}
            </option>
          {/each}
        </select>
      </div>

      <fieldset class="border rounded p-3">
        <legend class="text-sm px-1">Dates proposades (fins a 3)</legend>
        <div class="grid sm:grid-cols-3 gap-2">
          <div>
            <label for="d1" class="block text-sm mb-1">Data 1</label>
            <input
              id="d1"
              type="datetime-local"
              class="w-full rounded border px-2 py-1"
              bind:value={d1}
            />
          </div>
          <div>
            <label for="d2" class="block text-sm mb-1">Data 2</label>
            <input
              id="d2"
              type="datetime-local"
              class="w-full rounded border px-2 py-1"
              bind:value={d2}
            />
          </div>
          <div>
            <label for="d3" class="block text-sm mb-1">Data 3</label>
            <input
              id="d3"
              type="datetime-local"
              class="w-full rounded border px-2 py-1"
              bind:value={d3}
            />
          </div>
        </div>
        <p class="text-xs text-slate-500 mt-2">
          Pots proposar fins a tres dates.
        </p>
      </fieldset>

      <div>
        <label for="obs" class="block text-sm mb-1">Observacions</label>
        <textarea
          id="obs"
          class="w-full rounded border px-3 py-2"
          rows="3"
          bind:value={observacions}
        ></textarea>
      </div>

      <div class="flex gap-2">
        <button
          class="rounded bg-slate-900 text-white px-4 py-2 disabled:opacity-60"
          type="submit"
          disabled={busy}
        >
          {busy ? 'Creant…' : 'Crear repte'}
        </button>
        <a class="rounded border px-4 py-2" href="/reptes">Cancel·lar</a>
      </div>
    </form>
  {/if}
{/if}

