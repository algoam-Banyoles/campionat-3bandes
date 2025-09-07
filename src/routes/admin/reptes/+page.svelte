<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/authStore';
  import { isAdmin } from '$lib/isAdmin';

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
  let busy: string | null = null;

  onMount(async () => {
    // només admins
    if (!$user) { goto('/login'); return; }
    const ok = await isAdmin();
    if (!ok) { goto('/'); return; }
    await load();
  });

  async function load() {
    try {
      loading = true;
      error = null;
      const { supabase } = await import('$lib/supabaseClient');

      const { data: ch, error: e1 } = await supabase
        .from('challenges')
        .select('id,event_id,tipus,reptador_id,reptat_id,estat,dates_proposades,data_proposta,data_acceptacio,pos_reptador,pos_reptat')
        .order('data_proposta', { ascending: false });

      if (e1) throw e1;

      const ids = Array.from(
        new Set([...(ch?.map(c => c.reptador_id) ?? []), ...(ch?.map(c => c.reptat_id) ?? [])])
      );

      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', ids);

      if (e2) throw e2;
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

  function fmt(d?: string | null) {
    if (!d) return '—';
    try { return new Date(d).toLocaleString(); } catch { return d; }
  }

  async function adminSetState(id: string, state: 'acceptat'|'refusat'|'anullat'|'caducat') {
    try {
      busy = id;
      const { supabase } = await import('$lib/supabaseClient');
      const { error: err } = await supabase.rpc('admin_update_challenge_state', {
        p_challenge: id, p_new_state: state
      });
      if (err) throw err;
      await load();
    } catch (e: any) {
      alert(e?.message ?? 'No s’ha pogut actualitzar l’estat');
    } finally {
      busy = null;
    }
  }

  async function adminNoShow(id: string, noShowPlayerId: string) {
    try {
      busy = id;
      const { supabase } = await import('$lib/supabaseClient');
      const { error: err } = await supabase.rpc('admin_apply_no_show', {
        p_challenge: id, p_no_show_player: noShowPlayerId
      });
      if (err) throw err;
      await load();
    } catch (e: any) {
      alert(e?.message ?? 'No s’ha pogut aplicar la incompareixença');
    } finally {
      busy = null;
    }
  }

  async function adminDisagreement(eventId: string, a: string, b: string) {
    try {
      busy = `${a}-${b}`;
      const { supabase } = await import('$lib/supabaseClient');
      const { error: err } = await supabase.rpc('admin_apply_disagreement', {
        p_event: eventId, p_player_a: a, p_player_b: b
      });
      if (err) throw err;
      await load();
    } catch (e: any) {
      alert(e?.message ?? 'No s’ha pogut aplicar el desacord de dates');
    } finally {
      busy = null;
    }
  }
</script>

<svelte:head><title>Admin · Reptes</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Reptes (Administració)</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else if error}
  <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3">{error}</div>
{:else if rows.length === 0}
  <p class="text-slate-600">No hi ha reptes.</p>
{:else}
  <div class="space-y-3">
    {#each rows as r}
      <div class="rounded border p-3">
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs rounded bg-slate-800 text-white px-2 py-0.5">{r.tipus}</span>
          <span class="text-xs rounded bg-slate-100 px-2 py-0.5 capitalize">{r.estat.replace('_',' ')}</span>
          <span class="text-xs text-slate-500 ml-auto">Proposat: {fmt(r.data_proposta)}</span>
          {#if r.data_acceptacio}<span class="text-xs text-slate-500">Acceptat: {fmt(r.data_acceptacio)}</span>{/if}
        </div>

        <div class="mt-2 text-sm">
          <div><strong>Reptador:</strong> #{r.pos_reptador ?? '—'} — {r.reptador_nom}</div>
          <div><strong>Reptat:</strong> #{r.pos_reptat ?? '—'} — {r.reptat_nom}</div>
          {#if r.dates_proposades?.length}
            <div class="mt-2"><strong>Dates:</strong> {r.dates_proposades.map(fmt).join(' · ')}</div>
          {/if}
        </div>

        <div class="mt-3 flex flex-wrap gap-2">
          <!-- canvis d'estat -->
          <button class="rounded bg-green-600 text-white px-3 py-1 disabled:opacity-60"
            on:click={() => adminSetState(r.id, 'acceptat')}
            disabled={busy === r.id}>
            {busy === r.id ? '…' : 'Accepta'}
          </button>
          <button class="rounded bg-yellow-600 text-white px-3 py-1 disabled:opacity-60"
            on:click={() => adminSetState(r.id, 'caducat')}
            disabled={busy === r.id}>
            {busy === r.id ? '…' : 'Caduca'}
          </button>
          <button class="rounded bg-red-600 text-white px-3 py-1 disabled:opacity-60"
            on:click={() => adminSetState(r.id, 'refusat')}
            disabled={busy === r.id}>
            {busy === r.id ? '…' : 'Refusa'}
          </button>
          <button class="rounded bg-slate-600 text-white px-3 py-1 disabled:opacity-60"
            on:click={() => adminSetState(r.id, 'anullat')}
            disabled={busy === r.id}>
            {busy === r.id ? '…' : 'Anul·la'}
          </button>

          <!-- penalitzacions -->
          <button class="rounded bg-fuchsia-700 text-white px-3 py-1 disabled:opacity-60"
            on:click={() => adminNoShow(r.id, r.reptat_id)}
            disabled={busy === r.id}>
            {busy === r.id ? '…' : 'No-show reptat'}
          </button>
          <button class="rounded bg-fuchsia-700 text-white px-3 py-1 disabled:opacity-60"
            on:click={() => adminNoShow(r.id, r.reptador_id)}
            disabled={busy === r.id}>
            {busy === r.id ? '…' : 'No-show reptador'}
          </button>
          <button class="rounded bg-orange-700 text-white px-3 py-1 disabled:opacity-60"
            on:click={() => adminDisagreement(r.event_id, r.reptador_id, r.reptat_id)}
            disabled={busy === `${r.reptador_id}-${r.reptat_id}`}>
            {busy === `${r.reptador_id}-${r.reptat_id}` ? '…' : 'Desacord dates (-1 cadascú)'}
          </button>
        </div>
      </div>
    {/each}
  </div>
{/if}
