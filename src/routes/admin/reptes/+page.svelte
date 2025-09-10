<script lang="ts">
  import { onMount } from 'svelte';
  import { user, isAdmin } from '$lib/authStore';

  type ChallengeRow = {
    id: string;
    event_id: string;
    tipus: 'normal' | 'access';
    reptador_id: string;
    reptat_id: string;
    estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
    data_proposta: string;
    data_acceptacio: string | null;
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

  onMount(load);

  async function load() {
    try {
      loading = true;
      error = null;
      okMsg = null;

      if (!$user?.email) {
        error = 'Has d’iniciar sessió.';
        return;
      }
      if (!$isAdmin) {
        error = 'Només administradors poden veure aquesta pàgina.';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      const { data: ch, error: e1 } = await supabase
        .from('challenges')
        .select(`id,event_id,tipus,reptador_id,reptat_id,estat,data_proposta,data_acceptacio,reprogram_count,pos_reptador,pos_reptat`)
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

      const nameById = new Map(players?.map(p => [p.id, p.nom]) ?? []);

      rows = (ch ?? []).map(c => ({
        ...c,
        reptador_nom: nameById.get(c.reptador_id) ?? '—',
        reptat_nom: nameById.get(c.reptat_id) ?? '—'
      }));
    } catch (e:any) {
      error = e?.message ?? 'No s’ha pogut carregar la llista de reptes';
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
  function canAccept(r: ChallengeRow) {
    return r.estat === 'proposat';
  }
  function programInfo(r: ChallengeRow) {
    if (r.estat === 'proposat') return { allowed: true };
    if (['acceptat', 'programat'].includes(r.estat)) {
      if (!$isAdmin && r.estat === 'programat' && r.reprogram_count >= 1) {
        return { allowed: false, reason: 'límit de reprogramació assolit' };
      }
      return { allowed: true };
    }
    return { allowed: false, reason: 'estat no permet programar' };
  }
  function canRefuse(r: ChallengeRow) {
    return r.estat === 'proposat';
  }
  function canCancel(r: ChallengeRow) {
    // Segons indicacions: un repte ACCEPTAT ja NO es pot anul·lar.
    // Permetem anul·lar si és 'proposat' (i opcionalment 'programat' si ho vols).
    return r.estat === 'proposat'; // canvia-ho a (r.estat === 'proposat' || r.estat === 'programat')
                               // si vols permetre cancel·lar programats
  }
  function canSetResult(r: ChallengeRow) {
    // Pots posar resultat si està 'acceptat' (si s'ha jugat sense data Acceptació?) o 'programat'
    // i evidentment no si és 'jugat' o 'anullat' etc.
    return r.estat === 'acceptat' || r.estat === 'programat';
  }
  function isFrozen(r: ChallengeRow) {
    // cap acció possible
    return r.estat === 'anullat' || r.estat === 'jugat' || r.estat === 'refusat' || r.estat === 'caducat';
  }

  // --- Accions (admins) ---
  async function updateState(id: string, newState: ChallengeRow['estat'], also?: Record<string, any>) {
    try {
      busy = id;
      error = null;
      okMsg = null;
      const { supabase } = await import('$lib/supabaseClient');
      const payload: any = { estat: newState, ...(also ?? {}) };
      const { error: e } = await supabase.from('challenges').update(payload).eq('id', id);
      if (e) throw e;
      okMsg = `Repte actualitzat a "${newState}".`;
      await load();
    } catch (e:any) {
      error = e?.message ?? 'No s’ha pogut actualitzar el repte';
    } finally {
      busy = null;
    }
  }

  async function accept(r: ChallengeRow) {
    if (!canAccept(r)) return;
    await updateState(r.id, 'acceptat');
  }

  async function refuse(r: ChallengeRow) {
    if (!canRefuse(r)) return;
    await updateState(r.id, 'refusat');
  }

  async function cancel(r: ChallengeRow) {
    if (!canCancel(r)) return;
    await updateState(r.id, 'anullat');
  }
</script>

<svelte:head><title>Admin · Reptes</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Reptes (administració)</h1>

{#if loading}
  <div class="animate-pulse rounded border p-4 text-slate-500">Carregant…</div>
{:else}
  {#if error}
    <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{error}</div>
  {/if}
  {#if okMsg}
    <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{okMsg}</div>
  {/if}

  <div class="overflow-auto rounded border">
    <table class="min-w-full text-sm">
      <thead class="bg-slate-100 text-slate-700">
        <tr>
          <th class="px-3 py-2 text-left">Data prop.</th>
          <th class="px-3 py-2 text-left">Tipus</th>
          <th class="px-3 py-2 text-left">Reptador</th>
          <th class="px-3 py-2 text-left">Reptat</th>
          <th class="px-3 py-2 text-left">Estat</th>
          <th class="px-3 py-2 text-left">Accions</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t">
            <td class="px-3 py-2">{fmt(r.data_proposta)}</td>
            <td class="px-3 py-2">
              <span class="rounded bg-slate-800 text-white text-xs px-2 py-0.5">{r.tipus}</span>
            </td>
            <td class="px-3 py-2">#{r.pos_reptador ?? '—'} — {r.reptador_nom}</td>
            <td class="px-3 py-2">#{r.pos_reptat ?? '—'} — {r.reptat_nom}</td>
            <td class="px-3 py-2">
              <span class={`text-xs rounded px-2 py-0.5 capitalize ${estatClass(r.estat)}`}>{r.estat.replace('_',' ')}</span>
            </td>
            <td class="px-3 py-2">
              {#if isFrozen(r)}
                <span class="text-slate-500 text-xs">Sense accions</span>
              {:else}
                {@const p = programInfo(r)}
                <div class="flex flex-wrap items-center gap-2">
                  {#if canAccept(r)}
                    <button
                      class="rounded bg-emerald-700 text-white px-3 py-1 text-xs disabled:opacity-60"
                      disabled={busy === r.id}
                      on:click={() => accept(r)}
                    >Accepta</button>
                  {/if}

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
                      class:pointer-events-none={busy === r.id}
                      class:opacity-60={busy === r.id}
                      href={`/admin/reptes/${r.id}/resultat`}
                    >Posar resultat</a>
                  {/if}

                  {#if canRefuse(r)}
                    <button
                      class="rounded bg-amber-700 text-white px-3 py-1 text-xs disabled:opacity-60"
                      disabled={busy === r.id}
                      on:click={() => refuse(r)}
                    >Refusa</button>
                  {/if}

                  {#if canCancel(r)}
                    <button
                      class="rounded bg-red-700 text-white px-3 py-1 text-xs disabled:opacity-60"
                      disabled={busy === r.id}
                      on:click={() => cancel(r)}
                    >Anul·la</button>
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
