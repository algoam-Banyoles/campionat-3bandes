<script lang="ts">

        import { onMount } from 'svelte';
        import { goto } from '$app/navigation';
        import { user } from '$lib/stores/auth';
      import { supabase } from '$lib/supabaseClient';
      import { adminChecked } from '$lib/stores/adminAuth';
      import { effectiveIsAdmin } from '$lib/stores/viewMode';
      import Banner from '$lib/components/general/Banner.svelte';

      // Guard: només admins en vista admin (respecta el toggle viewMode).
      $: if ($adminChecked && !$effectiveIsAdmin) {
        goto('/campionat-continu/reptes');
      }
      import Loader from '$lib/components/general/Loader.svelte';
      import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';
      import { authFetch } from '$lib/utils/http';
      import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';
      import { refreshActiveChallenges, activeChallenges, invalidateChallengeCaches } from '$lib/stores/challengeStore';
      import { performanceMonitor } from '$lib/monitoring/performance';
  type ChallengeRow = {
    id: string;
    event_id: string;
    tipus: 'normal' | 'access';
    reptador_soci_numero: number;
    reptat_soci_numero: number;
    estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
    dates_proposades: string[];
    data_proposta: string;
    data_programada: string | null;
    reprogram_count: number;
    pos_reptador: number | null;
    pos_reptat: number | null;
    reptador_nom?: string;
    reptat_nom?: string;
  };

  let loading = true;
  let error: string | null = null;
  let okMsg: string | null = null;
  let rows: ChallengeRow[] = [];
  let busy: string | null = null; // id en acció
  const REPRO_LIMIT = 3;
  let reproLimit = REPRO_LIMIT;

  const challengeStateLabel = (state: string): string =>
    CHALLENGE_STATE_LABEL[state] ?? state.replace('_', ' ');

  
  onMount(load);

  function toLocalInput(iso: string | null) {
    if (!iso) return '';
    const d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }


  async function load() {
    try {
      loading = true;
      error = null;
      okMsg = null;

      // Usar el store optimitzat per obtenir challenges
      await refreshActiveChallenges();
      
      // Per l'admin, obtenir tots els challenges, no només els actius
      const { data: ch, error: e1 } = await supabase
        .from('challenges')
        .select(
          `id,event_id,tipus,reptador_soci_numero,reptat_soci_numero,estat,dates_proposades,data_proposta,data_programada,reprogram_count,pos_reptador,pos_reptat`
        )
        .order('data_proposta', { ascending: false })
        .limit(100); // Limitar per rendiment

      if (e1) throw e1;

      const nums = Array.from(
        new Set([...(ch?.map((c: any) => c.reptador_soci_numero) ?? []), ...(ch?.map((c: any) => c.reptat_soci_numero) ?? [])])
      );

      const { data: socisData, error: e2 } = await supabase
        .from('socis')
        .select('numero_soci,nom')
        .in('numero_soci', nums);
      if (e2) throw e2;

      const nameByNum = new Map(socisData?.map((p) => [p.numero_soci, p.nom]) ?? []);

      rows = ((ch ?? []) as unknown as ChallengeRow[]).map((c) => ({
        ...c,
        reptador_nom: nameByNum.get(c.reptador_soci_numero) ?? '—',
        reptat_nom: nameByNum.get(c.reptat_soci_numero) ?? '—'
      }));
      } catch (e) {
        error = formatSupabaseError(e);
      } finally {
      loading = false;
    }
  }

  function fmt(d: string | null) {
    if (!d) return '—';
    const t = new Date(d);
    return isNaN(t.getTime()) ? d : t.toLocaleString();
  }

  function estatClass(e: ChallengeRow['estat']) {
    switch (e) {
      case 'proposat':
        return 'bg-gray-200 text-gray-800';
      case 'acceptat':
        return 'bg-yellow-200 text-yellow-800';
      case 'programat':
        return 'bg-blue-200 text-blue-800';
      case 'jugat':
        return 'bg-green-200 text-green-800';
      case 'anullat':
        return 'bg-red-200 text-red-800';
      case 'refusat':
        return 'bg-orange-200 text-orange-800';
      default:
        return 'bg-slate-200 text-slate-800';
    }
  }

  // --- Lògica de permisos d'acció segons l'estat ---
  function programInfo(r: ChallengeRow) {
    if (r.estat === 'proposat') return { allowed: true };
    if (['acceptat', 'programat'].includes(r.estat)) {
      if (!$effectiveIsAdmin && r.estat === 'programat' && r.reprogram_count >= reproLimit) {
        return { allowed: false, reason: 'límit de reprogramació assolit' };
      }
      return { allowed: true };
    }
    return { allowed: false, reason: 'estat no permet programar' };
  }

  function canRefuse(r: ChallengeRow) {
    return r.estat === 'proposat';
  }
  function canSetResult(r: ChallengeRow) {
    return r.estat === 'acceptat' || r.estat === 'programat';
  }
  function isFrozen(r: ChallengeRow) {
    return ['anullat', 'jugat', 'refusat', 'caducat'].includes(r.estat);
  }

  async function acceptNoDate(r: ChallengeRow) {
    try {
      busy = r.id;
      error = null;
      okMsg = null;
        const res = await authFetch('/campionat-continu/reptes/accepta', {
          method: 'POST',
          body: JSON.stringify({ id: r.id, data_iso: null })
        });
      const out = await res.json();
      if (!out.ok) throw new Error(out.error || 'No s\u2019ha pogut acceptar');
      okMsg = okText('Repte acceptat.');
      await load();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      busy = null;
    }
  }

  async function refuse(r: ChallengeRow) {
    if (!canRefuse(r)) return;
    try {
      busy = r.id;
      error = null;
      okMsg = null;
      const { data, error: e } = await supabase
        .from('challenges')
        .update({ estat: 'refusat' })
        .eq('id', r.id)
        .eq('estat', 'proposat')
        .select('id');
      if (e) throw e;
      if (!data || data.length === 0) throw new Error('Estat no permès');
      okMsg = okText('Repte refusat.');
      
      // Invalidar caches i recarregar
      invalidateChallengeCaches();
      await load();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      busy = null;
    }
  }

  async function penalitza(r: ChallengeRow) {
    try {
      busy = r.id;
      error = null;
      okMsg = null;
      const { error: e } = await supabase.rpc('apply_challenge_penalty', {
        p_challenge: r.id,
        p_tipus: 'incompareixenca'
      });
      if (e) throw e;
      okMsg = okText('Penalització aplicada.');
      
      // Invalidar caches i recarregar
      invalidateChallengeCaches();
      await load();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      busy = null;
    }
  }

</script>

<svelte:head><title>Gestió de reptes</title></svelte:head>

<div class="gr-root">
  <header class="gr-mast">
    <div class="editorial-eyebrow">Rànquing continu · Administració</div>
    <h1 class="gr-title">Gestió de reptes</h1>
    <p class="gr-sub">Filtrar, programar, registrar resultats i aplicar penalitzacions als reptes.</p>
  </header>

{#if loading}
  <Loader />
{:else}
    {#if error}
      <Banner type="error" message={error} class="mb-3" />
    {/if}
    {#if okMsg}
      <Banner type="success" message={okMsg} class="mb-3" />
    {/if}

  <div class="overflow-auto rounded border">
    <table class="min-w-full text-sm">
      <thead class="bg-slate-100 text-slate-700">
        <tr>
          <th class="px-3 py-2 text-left">Data prop.</th>
          <th class="px-3 py-2 text-left">Data progr.</th>
          <th class="px-3 py-2 text-left">Tipus</th>
          <th class="px-3 py-2 text-left">Reptador</th>
          <th class="px-3 py-2 text-left">Reptat</th>
          <th class="px-3 py-2 text-left">Estat</th>
          <th class="px-3 py-2 text-left">Reprog.</th>
          <th class="px-3 py-2 text-left">Accions</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t align-top">
            <td class="px-3 py-2">{fmt(r.data_proposta)}</td>
            <td class="px-3 py-2">{fmt(r.data_programada)}</td>
            <td class="px-3 py-2">
              <span class="rounded bg-slate-800 text-white text-xs px-2 py-0.5">{r.tipus}</span>
            </td>
            <td class="px-3 py-2">#{r.pos_reptador ?? '—'} — {r.reptador_nom}</td>
            <td class="px-3 py-2">#{r.pos_reptat ?? '—'} — {r.reptat_nom}</td>
            <td class="px-3 py-2">
              <span class={`text-xs rounded px-2 py-0.5 ${estatClass(r.estat)}`}>{challengeStateLabel(r.estat)}</span>
            </td>
            <td class="px-3 py-2">{r.reprogram_count} / {reproLimit}</td>
            <td class="px-3 py-2">
              {#if isFrozen(r)}
                <span class="text-slate-500 text-xs">Sense accions</span>
              {:else}
                {@const p = programInfo(r)}
                <div class="flex flex-wrap items-center gap-2">
                  {#if r.estat === 'proposat'}
                    <button
                      class="rounded bg-green-700 text-white px-3 py-1 text-xs disabled:opacity-60"
                      disabled={busy === r.id}
                      on:click={() => acceptNoDate(r)}
                    >Accepta</button>
                    <a
                      class="inline-block rounded bg-indigo-700 text-white px-3 py-1 text-xs"
                      class:pointer-events-none={busy === r.id || !p.allowed}
                      class:opacity-60={busy === r.id || !p.allowed}
                      href={p.allowed ? `/campionat-continu/gestio-reptes/${r.id}/programar` : undefined}
                      title={!p.allowed ? p.reason : undefined}
                    >Programar</a>
                    <button
                      class="rounded bg-amber-700 text-white px-3 py-1 text-xs disabled:opacity-60"
                      disabled={busy === r.id}
                      on:click={() => refuse(r)}
                    >Refusa</button>
                  {:else if r.estat === 'acceptat' || r.estat === 'programat'}
                    <a
                      class="inline-block rounded bg-indigo-700 text-white px-3 py-1 text-xs"
                      class:pointer-events-none={busy === r.id || !p.allowed}
                      class:opacity-60={busy === r.id || !p.allowed}
                      href={p.allowed ? `/campionat-continu/gestio-reptes/${r.id}/programar` : undefined}
                      title={!p.allowed ? p.reason : undefined}
                    >Programar</a>
                    {#if !p.allowed && p.reason}
                      <span class="text-xs text-slate-500">{p.reason}</span>
                    {/if}
                    {#if canSetResult(r)}
                      <a
                        class="inline-block rounded bg-slate-900 text-white px-3 py-1 text-xs"
                        href={`/campionat-continu/gestio-reptes/${r.id}/resultat`}
                      >Posar resultat</a>
                    {/if}
                  {/if}
                  
                </div>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  <div class="mt-4">
    <a href="/campionat-continu/ranking" class="gr-back">← Tornar a la classificació</a>
  </div>
{/if}
</div>

<style>
  .gr-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .gr-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .gr-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .gr-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }
  .gr-back {
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
    text-decoration: none;
    border-bottom: 1px solid transparent;
    transition: border-color 0.15s ease;
  }
  .gr-back:hover {
    color: var(--ink, #1a1814);
    border-color: var(--ink, #1a1814);
  }

  /* Tailwind overrides dins .gr-root */
  .gr-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .gr-root :global(.bg-slate-100) { background: var(--paper, #fbfaf6) !important; border-bottom: 1px solid var(--ink, #1a1814) !important; }
  .gr-root :global(.bg-slate-200) { background: var(--rule, #e6e3dc) !important; color: var(--ink-2, #4a443e) !important; }
  .gr-root :global(.bg-slate-900) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .gr-root :global(.bg-blue-200) { background: var(--paper, #fbfaf6) !important; color: var(--blue, #1f4a99) !important; border: 1px solid var(--blue, #1f4a99) !important; }
  .gr-root :global(.bg-yellow-200) { background: var(--paper, #fbfaf6) !important; color: var(--amber, #b8860b) !important; border: 1px solid var(--amber, #b8860b) !important; }
  .gr-root :global(.bg-green-200) { background: var(--paper, #fbfaf6) !important; color: var(--green, #1f7a3a) !important; border: 1px solid var(--green, #1f7a3a) !important; }
  .gr-root :global(.bg-orange-200) { background: var(--paper, #fbfaf6) !important; color: var(--amber, #b8860b) !important; border: 1px solid var(--amber, #b8860b) !important; }
  .gr-root :global(.bg-red-200) { background: var(--paper, #fbfaf6) !important; color: var(--accent, #a30b1e) !important; border: 1px solid var(--accent, #a30b1e) !important; }
  .gr-root :global(.text-slate-600),
  .gr-root :global(.text-slate-700),
  .gr-root :global(.text-slate-800) { color: var(--ink-2, #4a443e) !important; }
  .gr-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
  .gr-root :global(.text-yellow-800) { color: var(--amber, #b8860b) !important; }
  .gr-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .gr-root :global(.text-orange-800) { color: var(--amber, #b8860b) !important; }
  .gr-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .gr-root :global(.rounded),
  .gr-root :global(.rounded-sm),
  .gr-root :global(.rounded-md),
  .gr-root :global(.rounded-lg),
  .gr-root :global(.rounded-full) { border-radius: 0 !important; }
  .gr-root :global(input),
  .gr-root :global(select) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .gr-root :global(table) { font-family: var(--font-sans, sans-serif); }
  .gr-root :global(table th),
  .gr-root :global(table td) { border-color: var(--rule, #e6e3dc); }
</style>

