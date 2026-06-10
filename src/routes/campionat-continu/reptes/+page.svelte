<script lang="ts">
    import { onMount } from 'svelte';
    import { user } from '$lib/stores/auth';
    import type { SupabaseClient } from '@supabase/supabase-js';
    import { acceptChallenge, refuseChallenge, scheduleChallenge } from '$lib/challenges';
    import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';


  type Challenge = {
    id: string;
    reptador_soci_numero: number;
    reptat_soci_numero: number;
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
  let mySociNumero: number | null = null;
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
        const { data: soci } = await supabase
          .from('socis')
          .select('numero_soci')
          .eq('email', auth.user.email)
          .maybeSingle();
        mySociNumero = soci?.numero_soci ?? null;
      }

      // Reptes actius
      const { data: ch, error: cErr } = await supabase
        .from('challenges')
        .select('id,reptador_soci_numero,reptat_soci_numero,estat,data_proposta,data_acceptacio,data_programada,reprogramacions')
        .in('estat', ['proposat', 'acceptat', 'programat', 'refusat'])
        .order('data_proposta', { ascending: true });
      if (cErr) throw cErr;
      actius = (ch ?? []) as any[];

      const sociNumerosPendents = Array.from(
        new Set<number>(
          actius
            .flatMap((c: any) => [c.reptador_soci_numero, c.reptat_soci_numero])
            .filter((n): n is number => n != null)
        )
      );
      let nameBySoci = new Map<number, string>();
      if (sociNumerosPendents.length) {
        const { data: sociRows, error: pErr } = await supabase
          .from('socis')
          .select('numero_soci, nom')
          .in('numero_soci', sociNumerosPendents);
        if (pErr) throw pErr;
        nameBySoci = new Map((sociRows ?? []).map((p: any) => [p.numero_soci, p.nom]));
      }
      actius = actius.map((c: any) => ({
        ...c,
        reptador_nom: nameBySoci.get(c.reptador_soci_numero) ?? '—',
        reptat_nom: nameBySoci.get(c.reptat_soci_numero) ?? '—'
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
      let chalMap = new Map<string, { reptador_soci_numero: number; reptat_soci_numero: number }>();
      if (chalIds.length) {
        const { data: challs, error: chErr } = await supabase
          .from('challenges')
          .select('id,reptador_soci_numero,reptat_soci_numero')
          .in('id', chalIds);
        if (chErr) throw chErr;
        chalMap = new Map(
          challs?.map((cc: any) => [cc.id, { reptador_soci_numero: cc.reptador_soci_numero, reptat_soci_numero: cc.reptat_soci_numero }]) ?? []
        );
        const sociIdsRes = Array.from(
          new Set<number>(
            (challs ?? [])
              .flatMap((cc: any) => [cc.reptador_soci_numero, cc.reptat_soci_numero])
              .filter((n: any): n is number => n != null)
          )
        );
        let namesRes = new Map<number, string>();
        if (sociIdsRes.length) {
          const { data: pls, error: pErr2 } = await supabase
            .from('socis')
            .select('numero_soci, nom')
            .in('numero_soci', sociIdsRes);
          if (pErr2) throw pErr2;
          namesRes = new Map((pls ?? []).map((p: any) => [p.numero_soci, p.nom]));
        }
        recents = matches.map((mm: any) => {
          const chInfo = chalMap.get(mm.challenge_id);
          return {
            id: mm.id,
            data_joc: mm.data_joc,
            caramboles_reptador: mm.caramboles_reptador,
            caramboles_reptat: mm.caramboles_reptat,
            reptador_nom: chInfo ? namesRes.get(chInfo.reptador_soci_numero) ?? '—' : '—',
            reptat_nom: chInfo ? namesRes.get(chInfo.reptat_soci_numero) ?? '—' : '—'
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

<div class="reptes-root">

<header class="page-mast">
  <div>
    <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Campionat continu</div>
    <h1 class="page-title">Reptes</h1>
  </div>
</header>

{#if loading}
  <div class="state-empty">Carregant reptes…</div>
{:else if error}
  <div class="state-empty error-state">{error}</div>
{:else}
  <section class="reptes-section">
    <h2 class="section-title">Reptes actius</h2>
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
                <div class="text-xs text-red-600 font-bold">ATENCIÓ: Termini d'acceptació vençut — pendent de penalització.</div>
              {/if}
              {#if isExpiredPlay(r)}
                <div class="text-xs text-red-600 font-bold">ATENCIÓ: Termini de joc vençut — pendent de penalització.</div>
              {/if}
            {#if mySociNumero === r.reptat_soci_numero && r.estat === 'proposat'}
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
            {#if r.estat !== 'refusat' && mySociNumero && (mySociNumero === r.reptador_soci_numero || mySociNumero === r.reptat_soci_numero)}
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

  <section class="reptes-section">
    <h2 class="section-title">Darrers resultats</h2>
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
  <div class="actions-bar">
    <a href="/campionat-continu/reptes/nou" class="btn-primary">
      + Nou repte
    </a>
    <a href="/campionat-continu/reptes/me" class="btn-secondary">
      Els meus reptes
    </a>
  </div>
{:else}
  <div class="state-empty">Inicia sessió per poder crear reptes.</div>
{/if}

</div>

<style>
  .reptes-root {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  /* Mast-head */
  .page-mast {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    gap: 1rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--ink);
  }
  .editorial-eyebrow {
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--sec-continu);
  }
  .page-title {
    font-weight: 800;
    font-size: 2rem;
    letter-spacing: -0.025em;
    line-height: 1.05;
    margin: 0;
    color: var(--ink);
  }

  /* Estats */
  .state-empty {
    padding: 1.25rem 1.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
  }
  .state-empty.error-state { color: var(--accent); border-color: var(--accent); }

  /* Seccions */
  .reptes-section {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.25rem 1.5rem;
  }
  .section-title {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.022em;
    margin: 0 0 1rem;
    padding-bottom: 0.65rem;
    border-bottom: 2px solid var(--ink);
    color: var(--ink);
  }
  /* Cards de repte i resultat — neutralitzar Tailwind antic dins de la secció */
  .reptes-section :global(li) {
    list-style: none;
    border: 1px solid var(--rule) !important;
    border-radius: 0 !important;
    padding: 1rem !important;
    background: var(--paper-elevated) !important;
  }
  .reptes-section :global(li + li) { margin-top: 0.5rem; }
  .reptes-section :global(ul) { padding-left: 0; }
  .reptes-section :global(.font-medium) {
    font-weight: 700 !important;
    color: var(--ink) !important;
    letter-spacing: -0.012em;
    font-size: 1rem;
  }
  .reptes-section :global(.font-semibold) {
    font-weight: 700 !important;
    color: var(--ink) !important;
  }
  .reptes-section :global(.text-slate-600),
  .reptes-section :global(.text-slate-500),
  .reptes-section :global(.text-slate-700) {
    color: var(--ink-2) !important;
  }
  .reptes-section :global(.text-red-600),
  .reptes-section :global(.text-red-700),
  .reptes-section :global(.text-red-800) {
    color: var(--accent) !important;
  }
  .reptes-section :global(input),
  .reptes-section :global(select) {
    background: var(--paper-elevated) !important;
    border-color: var(--rule-strong) !important;
    color: var(--ink) !important;
    border-radius: 0 !important;
    padding: 0.45rem 0.7rem !important;
    min-height: 40px;
  }
  .reptes-section :global(input:focus),
  .reptes-section :global(select:focus) {
    outline: 2px solid var(--ink) !important;
    border-color: var(--ink) !important;
  }
  /* Buttons dins de seccions: ink/green/red mapping */
  .reptes-section :global(button.bg-green-600),
  .reptes-section :global(button[class*="bg-green-"]) {
    background: var(--green) !important;
    color: white !important;
    border-radius: 0 !important;
    border: 1px solid var(--green) !important;
    font-weight: 600 !important;
  }
  .reptes-section :global(button.bg-red-600),
  .reptes-section :global(button[class*="bg-red-"]) {
    background: var(--accent) !important;
    color: white !important;
    border-radius: 0 !important;
    border: 1px solid var(--accent) !important;
    font-weight: 600 !important;
  }
  .reptes-section :global(button.bg-blue-600),
  .reptes-section :global(button[class*="bg-blue-"]) {
    background: var(--ink) !important;
    color: var(--paper) !important;
    border-radius: 0 !important;
    border: 1px solid var(--ink) !important;
    font-weight: 600 !important;
  }
  .reptes-section :global(button.rounded.border) {
    background: transparent !important;
    border: 1px solid var(--rule-strong) !important;
    color: var(--ink) !important;
    border-radius: 0 !important;
    font-weight: 600 !important;
  }
  /* Form contenidor dins resultat */
  .reptes-section :global(form.bg-slate-50) {
    background: var(--paper) !important;
    border: 1px solid var(--rule) !important;
    border-radius: 0 !important;
  }

  /* Actions bar (Nou repte / Els meus reptes) */
  .actions-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }
  .btn-primary, .btn-secondary {
    display: inline-flex;
    align-items: center;
    padding: 0.6rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    text-decoration: none;
    cursor: pointer;
    min-height: 44px;
  }
  .btn-primary {
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
  }
  .btn-primary:hover { opacity: 0.92; }
  .btn-secondary {
    background: transparent;
    color: var(--ink);
    border: 1px solid var(--rule-strong);
  }
  .btn-secondary:hover { border-color: var(--ink); }

  @media (max-width: 640px) {
    .page-title { font-size: 1.625rem; }
    .reptes-section { padding: 1rem 1.1rem; }
    .actions-bar { flex-direction: column; }
    .btn-primary, .btn-secondary { justify-content: center; width: 100%; }
  }
</style>
