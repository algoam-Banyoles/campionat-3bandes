<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/authStore';

  type Challenge = {
    id: string;
    event_id: string;
    tipus: 'normal' | 'access';
    reptador_id: string;
    reptat_id: string;
    estat: 'proposat' | 'acceptat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
    dates_proposades: string[];
    data_proposta: string;
    data_acceptacio: string | null;
    pos_reptador: number | null;
    pos_reptat: number | null;
    reptador_nom?: string;
    reptat_nom?: string;
  };

  let loading = true;
  let error: string | null = null;
  let rows: Challenge[] = [];
  let myPlayerId: string | null = null;
  let actionBusy: string | null = null; // id del repte en acció

  onMount(async () => {
    await load();
  });

  async function load() {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        error = 'Has d’iniciar sessió per veure els teus reptes.';
        loading = false;
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      // 1) Quin és el meu player_id?
      const { data: p, error: e1 } = await supabase
        .from('players')
        .select('id')
        .eq('email', u.email)
        .maybeSingle();

      if (e1) throw e1;
      if (!p) {
        error = 'El teu email no està vinculat a cap jugador.';
        loading = false;
        return;
      }
      myPlayerId = p.id;

      // 2) Reptes on hi sóc (com reptador o reptat)
      const { data: ch, error: e2 } = await supabase
        .from('challenges')
        .select('id,event_id,tipus,reptador_id,reptat_id,estat,dates_proposades,data_proposta,data_acceptacio,pos_reptador,pos_reptat')
        .or(`reptador_id.eq.${myPlayerId},reptat_id.eq.${myPlayerId}`)
        .order('data_proposta', { ascending: false });

      if (e2) throw e2;

      const ids = Array.from(
        new Set([...(ch?.map(c => c.reptador_id) ?? []), ...(ch?.map(c => c.reptat_id) ?? [])])
      );

      // 3) Diccionari id->nom per mostrar noms
      const { data: players, error: e3 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', ids);

      if (e3) throw e3;
      const nameById = new Map<string, string>(players?.map(p => [p.id, p.nom]) ?? []);

      rows = (ch ?? []).map(c => ({
        ...c,
        reptador_nom: nameById.get(c.reptador_id) ?? '—',
        reptat_nom: nameById.get(c.reptat_id) ?? '—'
      }));
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  }

  function fmt(d: string) {
    try { return new Date(d).toLocaleString(); } catch { return d; }
  }

  function canRespond(r: Challenge) {
    return myPlayerId && r.reptat_id === myPlayerId && r.estat === 'proposat';
  }

  async function respond(r: Challenge, accept: boolean) {
    try {
      actionBusy = r.id;
      const { supabase } = await import('$lib/supabaseClient');
      const { error: err } = await supabase
        .from('challenges')
        .update({ estat: accept ? 'acceptat' : 'refusat' })
        .eq('id', r.id);
      if (err) throw err;
      await load(); // refresca
    } catch (e: any) {
      alert(e?.message ?? 'No s’ha pogut actualitzar el repte');
    } finally {
      actionBusy = null;
    }
  }
</script>

<svelte:head>
  <title>Els meus reptes</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Els meus reptes</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else if error}
  <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3">{error}</div>
{:else if rows.length === 0}
  <p class="text-slate-600">No tens reptes registrats.</p>
{:else}
  <div class="space-y-3">
    {#each rows as r}
      <div class="rounded border p-3">
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs rounded bg-slate-800 text-white px-2 py-0.5">{r.tipus}</span>
          <span class="text-xs rounded bg-slate-100 px-2 py-0.5 capitalize">{r.estat.replace('_',' ')}</span>
          <span class="text-xs text-slate-500 ml-auto">Proposat: {fmt(r.data_proposta)}</span>
        </div>

        <div class="mt-2 text-sm">
          <div><strong>Reptador:</strong> #{r.pos_reptador ?? '—'} — {r.reptador_nom}</div>
          <div><strong>Reptat:</strong> #{r.pos_reptat ?? '—'} — {r.reptat_nom}</div>
        </div>

        {#if r.dates_proposades?.length}
          <div class="mt-2 text-sm">
            <strong>Dates proposades:</strong>
            <ul class="list-disc ml-6">
              {#each r.dates_proposades as d}<li>{fmt(d)}</li>{/each}
            </ul>
          </div>
        {/if}

        {#if canRespond(r)}
          <div class="mt-3 flex gap-2">
            <button
              class="rounded bg-green-600 text-white px-3 py-1 disabled:opacity-60"
              on:click={() => respond(r, true)}
              disabled={actionBusy === r.id}
            >
              {actionBusy === r.id ? 'Processant…' : 'Accepta'}
            </button>
            <button
              class="rounded bg-red-600 text-white px-3 py-1 disabled:opacity-60"
              on:click={() => respond(r, false)}
              disabled={actionBusy === r.id}
            >
              {actionBusy === r.id ? 'Processant…' : 'Refusa'}
            </button>
          </div>
        {/if}
      </div>
    {/each}
  </div>
{/if}
