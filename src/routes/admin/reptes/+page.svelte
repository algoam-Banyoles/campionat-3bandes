<script lang="ts">

        import { onMount } from 'svelte';
        import { user } from '$lib/stores/auth';
      import { checkIsAdmin } from '$lib/roles';
      import Banner from '$lib/components/Banner.svelte';
      import Loader from '$lib/components/Loader.svelte';
      import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';
      import { authFetch } from '$lib/utils/http';
      import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';
      import { refreshActiveChallenges, activeChallenges, invalidateChallengeCaches } from '$lib/challengeStore';
      import { performanceMonitor } from '$lib/monitoring/performance';
  type ChallengeRow = {
    id: string;
    event_id: string;
    tipus: 'normal' | 'access';
    reptador_id: string;
    reptat_id: string;
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
  let isAdmin = false;
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

        if (!$user?.email) {
          error = errText('Has d’iniciar sessió.');
          return;
        }
        // aquesta pàgina està pensada per a administradors
        const adm = await checkIsAdmin();
        if (!adm) {
          error = errText('Només administradors poden veure aquesta pàgina.');
          return;
        }
        isAdmin = true;

      const { supabase } = await import('$lib/supabaseClient');

      // Usar el store optimitzat per obtenir challenges
      await refreshActiveChallenges();
      
      // Per l'admin, obtenir tots els challenges, no només els actius
      const { data: ch, error: e1 } = await supabase
        .from('challenges')
        .select(
          `id,event_id,tipus,reptador_id,reptat_id,estat,dates_proposades,data_proposta,data_programada,reprogram_count,pos_reptador,pos_reptat`
        )
        .order('data_proposta', { ascending: false })
        .limit(100); // Limitar per rendiment
        
      if (e1) throw e1;

      const ids = Array.from(
        new Set([...(ch?.map((c) => c.reptador_id) ?? []), ...(ch?.map((c) => c.reptat_id) ?? [])])
      );

      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', ids);
      if (e2) throw e2;

      const nameById = new Map(players?.map((p) => [p.id, p.nom]) ?? []);

      rows = (ch ?? []).map((c) => ({
        ...c,
        reptador_nom: nameById.get(c.reptador_id) ?? '—',
        reptat_nom: nameById.get(c.reptat_id) ?? '—'
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
      if (!isAdmin && r.estat === 'programat' && r.reprogram_count >= reproLimit) {
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
        const res = await authFetch('/reptes/accepta', {
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
      const { supabase } = await import('$lib/supabaseClient');
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
      const { supabase } = await import('$lib/supabaseClient');
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

<svelte:head><title>Admin · Reptes</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Reptes (administració)</h1>

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
                      href={p.allowed ? `/admin/reptes/${r.id}/programar` : undefined}
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
                      href={p.allowed ? `/admin/reptes/${r.id}/programar` : undefined}
                      title={!p.allowed ? p.reason : undefined}
                    >Programar</a>
                    {#if !p.allowed && p.reason}
                      <span class="text-xs text-slate-500">{p.reason}</span>
                    {/if}
                    {#if canSetResult(r)}
                      <a
                        class="inline-block rounded bg-slate-900 text-white px-3 py-1 text-xs"
                        href={`/admin/reptes/${r.id}/resultat`}
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
    <a href="/admin" class="text-sm underline text-slate-600">← Tornar al panell</a>
  </div>
{/if}

