<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/authStore';

  type Challenge = {
    id: string;
    reptador_id: string;
    reptat_id: string;
    estat: string;
    data_proposta: string;
    data_programada: string | null;
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
  let pendents: Challenge[] = [];
  let recents: Resultat[] = [];

  const fmtDate = (iso: string) => new Date(iso).toLocaleDateString();

  onMount(async () => {
    try {
      const { supabase } = await import('$lib/supabaseClient');

      // Reptes pendents
      const { data: ch, error: cErr } = await supabase
        .from('challenges')
        .select('id,reptador_id,reptat_id,estat,data_proposta,data_programada')
        .neq('estat', 'jugat')
        .order('data_proposta', { ascending: true });
      if (cErr) throw cErr;
      pendents = ch ?? [];

      const idsPendents = Array.from(
        new Set([
          ...pendents.map((c) => c.reptador_id),
          ...pendents.map((c) => c.reptat_id)
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
      pendents = pendents.map((c) => ({
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
  });
</script>

<h1 class="text-2xl font-semibold mb-4">Reptes</h1>

{#if loading}
  <p class="text-slate-500">Carregant reptes…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">{error}</div>
{:else}
  <section class="mb-6">
    <h2 class="text-xl font-semibold mb-2">Reptes pendents</h2>
    {#if pendents.length}
      <ul class="space-y-2">
        {#each pendents as r}
          <li class="p-3 border rounded">
            <div class="font-medium">{r.reptador_nom} vs {r.reptat_nom}</div>
            <div class="text-sm text-slate-600 capitalize">{r.estat}</div>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-slate-600">No hi ha reptes pendents.</p>
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

<p class="mt-6">
  <a class="underline" href="/reptes/me">👉 Els meus reptes</a>
</p>
