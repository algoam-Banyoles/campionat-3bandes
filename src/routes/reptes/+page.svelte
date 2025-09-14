<script lang="ts">
    import { onMount } from 'svelte';
    import { user } from '$lib/stores/auth';
    import type { SupabaseClient } from '@supabase/supabase-js';
    import { acceptChallenge, refuseChallenge, scheduleChallenge } from '$lib/challenges';

  type Challenge = {
    id: string;
    reptador_id: string;
    reptat_id: string;
    estat: string;
    data_proposta: string;
    data_acceptacio: string | null;
    data_programada: string | null;
    reprogramacions: number | null;
    reptador_nom?: string;
    reptat_nom?: string;
  };

  type Resultat = {
    id: string;
    data_joc: string;
    caramboles_reptador: number;
    caramboles_reptat: number;
    reptador_nom: string;
    reptat_nom: string;
  };

  let loading = true;
  let error: string | null = null;
  let actius: Challenge[] = [];
  let recents: Resultat[] = [];
  let myPlayerId: string | null = null;
  let supabase: SupabaseClient;
  let dateDrafts: Record<string, string> = {};

  const fmtDate = (iso: string | null) => (iso ? new Date(iso).toLocaleString() : '—');
  const parseLocalToIso = (local: string) => {
    const d = new Date(local);
    return isNaN(d.getTime()) ? null : d.toISOString();
  };

  async function load() {
    try {
      loading = true;
      const mod = await import('$lib/supabaseClient');
      supabase = mod.supabase;

      const { data: auth } = await supabase.auth.getUser();
      if (auth?.user?.email) {
        const { data: player } = await supabase
          .from('players')
          .select('id')
          .eq('email', auth.user.email)
          .maybeSingle();
        myPlayerId = (player as any)?.id ?? null;
      }

      // Reptes actius
      const { data: ch, error: cErr } = await supabase
        .from('challenges')
        .select('id,reptador_id,reptat_id,estat,data_proposta,data_acceptacio,data_programada,reprogramacions')
        .in('estat', ['proposat', 'acceptat', 'programat', 'refusat'])
        .order('data_proposta', { ascending: true });
      if (cErr) throw cErr;
      actius = ch ?? [];

      const idsPendents = Array.from(
        new Set([
          ...actius.map((c) => c.reptador_id),
          ...actius.map((c) => c.reptat_id)
        ])
      );
      let nameById = new Map<string, string>();
      if (idsPendents.length) {
        const { data: players, error: pErr } = await supabase
          .from('players')
          .select('id,nom')
          .in('id', idsPendents);
        if (pErr) throw pErr;
        nameById = new Map(players?.map((p: any) => [p.id, p.nom]) ?? []);
      }
      actius = actius.map((c) => ({
        ...c,
        reptador_nom: nameById.get(c.reptador_id) ?? '—',
        reptat_nom: nameById.get(c.reptat_id) ?? '—'
      }));

      // Darrers resultats
      const { data: m, error: mErr } = await supabase
        .from('matches')
        .select('id,challenge_id,data_joc,caramboles_reptador,caramboles_reptat')
        .order('data_joc', { ascending: false })
        .limit(5);
      if (mErr) throw mErr;
      const matches = m ?? [];
      const chalIds = matches.map((mm: any) => mm.challenge_id);
      let chalMap = new Map<string, { reptador_id: string; reptat_id: string }>();
      if (chalIds.length) {
        const { data: challs, error: chErr } = await supabase
          .from('challenges')
          .select('id,reptador_id,reptat_id')
          .in('id', chalIds);
        if (chErr) throw chErr;
        chalMap = new Map(
          challs?.map((cc: any) => [cc.id, { reptador_id: cc.reptador_id, reptat_id: cc.reptat_id }]) ?? []
        );
        const idsRes = Array.from(
          new Set(
            challs?.flatMap((cc: any) => [cc.reptador_id, cc.reptat_id]) ?? []
          )
        );
        let namesRes = new Map<string, string>();
        if (idsRes.length) {
          const { data: pls, error: pErr2 } = await supabase
            .from('players')
            .select('id,nom')
            .in('id', idsRes);
          if (pErr2) throw pErr2;
          namesRes = new Map(pls?.map((p: any) => [p.id, p.nom]) ?? []);
        }
        recents = matches.map((mm: any) => {
          const chInfo = chalMap.get(mm.challenge_id);
          return {
            id: mm.id,
            data_joc: mm.data_joc,
            caramboles_reptador: mm.caramboles_reptador,
            caramboles_reptat: mm.caramboles_reptat,
            reptador_nom: chInfo ? namesRes.get(chInfo.reptador_id) ?? '—' : '—',
            reptat_nom: chInfo ? namesRes.get(chInfo.reptat_id) ?? '—' : '—'
          } as Resultat;
        });
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  }

  onMount(load);

  async function accept(ch: Challenge) {
    try {
      error = null;
      await acceptChallenge(supabase, ch.id);
      ch.estat = 'acceptat';
      ch.data_acceptacio = new Date().toISOString();
    } catch (e: any) {
      error = e?.message ?? 'Error acceptant repte';
    }
  }

  async function refuse(ch: Challenge) {
    try {
      error = null;
      await refuseChallenge(supabase, ch.id);
      ch.estat = 'refusat';
    } catch (e: any) {
      error = e?.message ?? 'Error refusant repte';
    }
  }

  async function propose(ch: Challenge) {
    const iso = parseLocalToIso(dateDrafts[ch.id]);
    if (!iso) {
      error = 'Data invàlida';
      return;
    }
    try {
      error = null;
      await scheduleChallenge(supabase, ch.id, iso);
      if (ch.data_programada) {
        ch.reprogramacions = (ch.reprogramacions ?? 0) + 1;
      }
      ch.data_programada = iso;
      dateDrafts[ch.id] = '';
    } catch (e: any) {
      error = e?.message ?? 'Error programant repte';
    }
  }
</script>

<h1 class="text-2xl font-semibold mb-4">Reptes</h1>

{#if loading}
  <p class="text-slate-500">Carregant reptes…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">{error}</div>
{:else}
  <section class="mb-6">
    <h2 class="text-xl font-semibold mb-2">Reptes actius</h2>
    {#if actius.length}
      <ul class="space-y-2">
        {#each actius as r}
          <li class="p-3 border rounded">
            <div class="font-medium">{r.reptador_nom} vs {r.reptat_nom}</div>
            <div class="text-sm text-slate-600 capitalize">Estat: {r.estat}</div>
            <div class="text-sm text-slate-600">
              Proposat: {fmtDate(r.data_proposta)}
              {#if r.data_acceptacio}
                • Acceptat: {fmtDate(r.data_acceptacio)}
              {/if}
              {#if r.data_programada}
                • Programat: {fmtDate(r.data_programada)}
              {/if}
            </div>
            <div class="text-sm text-slate-600">Reprogramacions: {r.reprogramacions ?? 0}</div>
            {#if myPlayerId === r.reptat_id && r.estat === 'proposat'}
              <div class="mt-2 flex gap-2">
                <button
                  class="rounded bg-green-600 text-white px-3 py-1"
                  on:click={() => accept(r)}
                >
                  Accepta
                </button>
                <button
                  class="rounded bg-red-600 text-white px-3 py-1"
                  on:click={() => refuse(r)}
                >
                  Refusa
                </button>
              </div>
            {/if}
            {#if r.estat !== 'refusat'}
              <div class="mt-2 flex gap-2 items-center">
                <input
                  type="datetime-local"
                  step="60"
                  class="border rounded px-2 py-1"
                  bind:value={dateDrafts[r.id]}
                />
                <button
                  class="rounded border px-3 py-1 text-sm"
                  on:click={() => propose(r)}
                >
                  Proposa data
                </button>
              </div>
            {/if}
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-slate-600">No hi ha reptes actius.</p>
    {/if}
  </section>

  <section class="mb-6">
    <h2 class="text-xl font-semibold mb-2">Darrers resultats</h2>
    {#if recents.length}
      <ul class="space-y-2">
        {#each recents as m}
          <li class="p-3 border rounded">
            <div class="font-medium">
              {m.reptador_nom} {m.caramboles_reptador} - {m.caramboles_reptat} {m.reptat_nom}
            </div>
            <div class="text-sm text-slate-600">{fmtDate(m.data_joc)}</div>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-slate-600">No hi ha resultats recents.</p>
    {/if}
  </section>
{/if}

{#if $user}
  <p class="mt-4">
    <a
      href="/reptes/nou"
      class="inline-block rounded bg-slate-900 text-white px-4 py-2 hover:bg-slate-700"
    >
      ➕ Nou repte
    </a>
  </p>
{:else}
  <p class="text-slate-500 mt-4">Inicia sessió per poder crear reptes.</p>
{/if}

{#if $user}
  <p class="mt-6">
    <a class="underline" href="/reptes/me">👉 Els meus reptes</a>
  </p>
{/if}
