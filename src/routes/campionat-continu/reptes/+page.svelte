<script lang="ts">
    import { onMount } from 'svelte';
    import { user } from '$lib/stores/auth';
    import type { SupabaseClient } from '@supabase/supabase-js';
    import { acceptChallenge, refuseChallenge, scheduleChallenge } from '$lib/challenges';
    import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';


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
  let resultDrafts: Record<string, {
    data_joc: string;
    caramboles_reptador: number | '';
    caramboles_reptat: number | '';
    entrades?: number | '';
    tiebreak_reptador?: number | '';
    tiebreak_reptat?: number | '';
  }> = {};
  async function submitResult(ch: Challenge) {
    try {
      error = null;
      const draft = resultDrafts[ch.id];
      if (!draft || !draft.data_joc || draft.caramboles_reptador === '' || draft.caramboles_reptat === '') {
        error = 'Cal omplir tots els camps.';
        return;
      }
      const mod = await import('$lib/supabaseClient');
      const supabase = mod.supabase;
      // Desa el resultat com a provisional (pendent de validació)
      const { error: err } = await supabase.from('matches').insert({
        challenge_id: ch.id,
        data_joc: draft.data_joc,
        caramboles_reptador: draft.caramboles_reptador,
        caramboles_reptat: draft.caramboles_reptat,
        entrades: draft.entrades ?? null,
        tiebreak_reptador: draft.tiebreak_reptador ?? null,
        tiebreak_reptat: draft.tiebreak_reptat ?? null,
        validat: false // camp que indica si la Junta ha validat
      });
      if (err) {
        error = err.message;
        return;
      }
      resultDrafts[ch.id] = {
        data_joc: '',
        caramboles_reptador: '',
        caramboles_reptat: '',
        entrades: '',
        tiebreak_reptador: '',
        tiebreak_reptat: ''
      };
      await load();
    } catch (e: any) {
      error = e?.message ?? 'Error enviant resultat';
    }
  }
  const REPRO_LIMIT = 3;
  let reproLimit = REPRO_LIMIT;
  const DEFAULT_ACCEPT_DAYS = 7;
  const DEFAULT_PLAY_DAYS = 7;
  let acceptDeadlineDays = DEFAULT_ACCEPT_DAYS;
  let playDeadlineDays = DEFAULT_PLAY_DAYS;

  const fmtDate = (iso: string | null) => (iso ? new Date(iso).toLocaleString() : '—');
  const parseLocalToIso = (local: string) => {
    const d = new Date(local);
    return isNaN(d.getTime()) ? null : d.toISOString();
  };
  const challengeStateLabel = (state: string): string => CHALLENGE_STATE_LABEL[state] ?? state;

  function addDays(date: Date, days: number) {
    const d = new Date(date);
    d.setDate(d.getDate() + days);
    return d;
  }

  function isExpiredAccept(r: Challenge) {
    if (r.estat !== 'proposat') return false;
    const deadline = addDays(new Date(r.data_proposta), acceptDeadlineDays ?? DEFAULT_ACCEPT_DAYS);
    return new Date() > deadline;
  }

  function isExpiredPlay(r: Challenge) {
    if (!['acceptat', 'programat'].includes(r.estat)) return false;
    const base = r.data_programada ?? r.data_proposta;
    const deadline = addDays(new Date(base), playDeadlineDays ?? DEFAULT_PLAY_DAYS);
    return new Date() > deadline;
  }

  async function load() {
    try {
      loading = true;
      const mod = await import('$lib/supabaseClient');
      supabase = mod.supabase;

      const { data: settingsRow, error: settingsErr } = await supabase
        .from('app_settings')
        .select('dies_acceptar_repte, dies_jugar_despres_acceptar')
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (!settingsErr && settingsRow) {
        acceptDeadlineDays = settingsRow.dies_acceptar_repte ?? DEFAULT_ACCEPT_DAYS;
        playDeadlineDays = settingsRow.dies_jugar_despres_acceptar ?? DEFAULT_PLAY_DAYS;
      } else {
        acceptDeadlineDays = DEFAULT_ACCEPT_DAYS;
        playDeadlineDays = DEFAULT_PLAY_DAYS;
      }

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
          .select('id, socis!inner(nom)')
          .in('id', idsPendents);
        if (pErr) throw pErr;
        nameById = new Map(players?.map((p: any) => [p.id, p.socis?.nom]) ?? []);
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
            .select('id, socis!inner(nom)')
            .in('id', idsRes);
          if (pErr2) throw pErr2;
          namesRes = new Map(pls?.map((p: any) => [p.id, p.socis?.nom]) ?? []);
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
      await load(); // Refresca la llista de reptes
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
            <div class="text-sm text-slate-600">Estat: {challengeStateLabel(r.estat)}</div>
            <div class="text-sm text-slate-600">
              {CHALLENGE_STATE_LABEL.proposat}: {fmtDate(r.data_proposta)}
              {#if r.data_acceptacio}
                • {CHALLENGE_STATE_LABEL.acceptat}: {fmtDate(r.data_acceptacio)}
              {/if}
              {#if r.data_programada}
                • {CHALLENGE_STATE_LABEL.programat}: {fmtDate(r.data_programada)}
              {/if}
            </div>
            <div class="text-sm text-slate-600">Reprogramacions: {r.reprogramacions ?? 0} / {reproLimit}</div>
              {#if isExpiredAccept(r)}
                <div class="text-xs text-red-600 font-bold">ATENCIÓ: Repte caducat per no acceptar a temps. Penalització automàtica aplicada.</div>
              {/if}
              {#if isExpiredPlay(r)}
                <div class="text-xs text-red-600 font-bold">ATENCIÓ: Repte caducat per no jugar a temps. Penalització automàtica aplicada.</div>
              {/if}
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
            {#if r.estat !== 'refusat' && myPlayerId && (myPlayerId === r.reptador_id || myPlayerId === r.reptat_id)}
              {#if !(r.reprogramacions != null && r.reprogramacions >= reproLimit)}
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
              {#if r.estat === 'programat'}
                {#if !resultDrafts[r.id]}
                  {@html (() => { resultDrafts[r.id] = { data_joc: '', caramboles_reptador: '', caramboles_reptat: '', entrades: '', tiebreak_reptador: '', tiebreak_reptat: '' }; return ''; })()}
                {/if}
                <form class="mt-2 flex flex-col gap-2 p-3 border rounded bg-slate-50" on:submit|preventDefault={() => submitResult(r)}>
                  <div class="font-semibold mb-2">Data Partida</div>
                  <div class="mb-2">
                    <label class="block text-sm mb-1" for={`data_joc_${r.id}`}>Data</label>
                    <input id={`data_joc_${r.id}`} type="date" class="border rounded px-2 py-1 w-40" bind:value={resultDrafts[r.id].data_joc} required />
                  </div>
                  <div class="mb-2">
                    <label class="block text-sm mb-1" for={`caramboles_reptador_${r.id}`}>Caramboles</label>
                    <div class="flex gap-2">
                      <div class="flex flex-col">
                        <span class="text-xs text-slate-600">{r.reptador_nom}</span>
                        <input id={`caramboles_reptador_${r.id}`} type="number" min="0" class="border rounded px-2 py-1 w-24" bind:value={resultDrafts[r.id].caramboles_reptador} required />
                      </div>
                      <div class="flex flex-col">
                        <span class="text-xs text-slate-600">{r.reptat_nom}</span>
                        <input id={`caramboles_reptat_${r.id}`} type="number" min="0" class="border rounded px-2 py-1 w-24" bind:value={resultDrafts[r.id].caramboles_reptat} required />
                      </div>
                    </div>
                  </div>
                  <div class="mb-2">
                    <label class="block text-sm mb-1" for={`entrades_${r.id}`}>Entrades</label>
                    <input id={`entrades_${r.id}`} type="number" min="0" class="border rounded px-2 py-1 w-24" bind:value={resultDrafts[r.id].entrades} />
                  </div>
                  {#if Number(resultDrafts[r.id].caramboles_reptador) === Number(resultDrafts[r.id].caramboles_reptat) && resultDrafts[r.id].caramboles_reptador !== ''}
                    <div class="mb-2">
                      <label class="block text-sm mb-1" for={`tiebreak_reptador_${r.id}`}>Tiebreak</label>
                      <div class="flex gap-2">
                        <div class="flex flex-col">
                          <span class="text-xs text-slate-600">{r.reptador_nom}</span>
                          <input id={`tiebreak_reptador_${r.id}`} type="number" min="0" class="border rounded px-2 py-1 w-24" bind:value={resultDrafts[r.id].tiebreak_reptador} />
                        </div>
                        <div class="flex flex-col">
                          <span class="text-xs text-slate-600">{r.reptat_nom}</span>
                          <input id={`tiebreak_reptat_${r.id}`} type="number" min="0" class="border rounded px-2 py-1 w-24" bind:value={resultDrafts[r.id].tiebreak_reptat} />
                        </div>
                      </div>
                    </div>
                  {/if}
                  {#if error}
                    <div class="text-red-600 text-sm mb-2">{error}</div>
                  {/if}
                  <button
                    class="rounded bg-blue-600 text-white px-3 py-1 self-start mt-2"
                    type="submit"
                    disabled={
                      !resultDrafts[r.id].data_joc ||
                      resultDrafts[r.id].caramboles_reptador === '' ||
                      resultDrafts[r.id].caramboles_reptat === ''
                    }
                  >
                    Envia resultat
                  </button>
                </form>
              {/if}
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
  <div class="mt-6 flex flex-wrap gap-3">
    <a
      href="/campionat-continu/reptes/nou"
      class="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white font-medium px-4 py-2 rounded-lg transition-colors"
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
      </svg>
      <span>Nou repte</span>
    </a>
    <a
      href="/campionat-continu/reptes/me"
      class="inline-flex items-center gap-2 bg-slate-100 hover:bg-slate-200 text-slate-800 font-medium px-4 py-2 rounded-lg border border-slate-300 transition-colors"
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
      </svg>
      <span>Els meus reptes</span>
    </a>
  </div>
{:else}
  <p class="text-slate-500 mt-4">Inicia sessió per poder crear reptes.</p>
{/if}
