<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/authStore';

  type Challenge = {
    id: string;
    event_id: string;
    tipus: 'normal' | 'access';
    reptador_id: string;
    reptat_id: string;
    estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
    dates_proposades: string[];
    data_proposta: string;
    data_acceptacio: string | null; // la fem servir com a data programada
    pos_reptador: number | null;
    pos_reptat: number | null;
    reptador_nom?: string;
    reptat_nom?: string;
  };

  const ALL_STATES = ['tots','proposat','acceptat','programat','refusat','caducat','jugat','anullat'] as const;

  let loading = true;
  let error: string | null = null;    // errors de càrrega
  let uiError: string | null = null;  // errors d’acció (programar, canviar estat)

  let isAdmin = false;
  let eventActiuId: string | null = null;

  // dades i filtres
  let rows: Challenge[] = [];
  let q = '';
  let stateFilter: (typeof ALL_STATES)[number] = 'tots'; // <- ara "tots" per defecte
  let fromDate = '';
  let toDate = '';

  // accions ràpides
  let busyId: string | null = null;
  let planDate: Record<string, string> = {}; // challengeId -> datetime-local (valor d’input)

  onMount(async () => {
    try {
      loading = true; error = null;

      const u = $user;
      if (!u?.email) { goto('/login'); return; }

      const { supabase } = await import('$lib/supabaseClient');

      // comprovar admin
      const { data: adm, error: eAdm } = await supabase
        .from('admins').select('email').eq('email', u.email).maybeSingle();
      if (eAdm) throw eAdm;
      if (!adm) { error = 'Només els administradors poden accedir a aquesta pàgina.'; return; }
      isAdmin = true;

      // event actiu
      const { data: ev, error: eEv } = await supabase
        .from('events').select('id').eq('actiu', true).limit(1).maybeSingle();
      if (eEv) throw eEv;
      if (!ev) { error = 'No s’ha trobat cap event actiu.'; return; }
      eventActiuId = ev.id;

      await load();
    } catch (e:any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });

  function toLocalInputValue(iso: string | null) {
    if (!iso) return '';
    const d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  async function load() {
    try {
      if (!eventActiuId) return;
      uiError = null;

      const { supabase } = await import('$lib/supabaseClient');

      let query = supabase
        .from('challenges')
        .select('id,event_id,tipus,reptador_id,reptat_id,estat,dates_proposades,data_proposta,data_acceptacio,pos_reptador,pos_reptat')
        .eq('event_id', eventActiuId)
        .order('data_proposta', { ascending: false });

      // filtres
      if (fromDate) query = query.gte('data_proposta', new Date(fromDate).toISOString());
      if (toDate) {
        const dt = new Date(toDate);
        dt.setHours(23,59,59,999);
        query = query.lte('data_proposta', dt.toISOString());
      }
      if (stateFilter !== 'tots') query = query.eq('estat', stateFilter);

      const { data: ch, error: e1 } = await query;
      if (e1) throw e1;

      // si no hi ha reptes, neteja i surt
      if (!ch || ch.length === 0) {
        rows = [];
        planDate = {};
        return;
      }

      // noms jugadors
      const idsSet = new Set<string>();
      for (const c of ch) { idsSet.add(c.reptador_id); idsSet.add(c.reptat_id); }
      const ids = Array.from(idsSet);
      let dict = new Map<string, string>();
      if (ids.length > 0) {
        const { data: players, error: e2 } = await supabase
          .from('players').select('id,nom').in('id', ids);
        if (e2) throw e2;
        dict = new Map((players ?? []).map((p: any) => [p.id, p.nom]));
      }

      rows = ch.map(c => ({
        ...c,
        reptador_nom: dict.get(c.reptador_id) ?? '—',
        reptat_nom: dict.get(c.reptat_id) ?? '—'
      }));

      // preomple data programada als inputs
      planDate = {};
      for (const r of rows) planDate[r.id] = toLocalInputValue(r.data_acceptacio);
    } catch (e:any) {
      error = e?.message ?? 'No s’ha pogut carregar la llista';
    }
  }

  function fmt(d: string | null) {
    if (!d) return '—';
    try { return new Date(d).toLocaleString(); } catch { return d; }
  }

  function matchesQuery(r: Challenge) {
    const t = q.trim().toLowerCase();
    if (!t) return true;
    return (r.reptador_nom ?? '').toLowerCase().includes(t)
        || (r.reptat_nom ?? '').toLowerCase().includes(t);
  }

  async function setEstat(r: Challenge, estat: Challenge['estat']) {
    uiError = null;
    try {
      busyId = r.id;
      const { supabase } = await import('$lib/supabaseClient');
      const { error: e } = await supabase
        .from('challenges')
        .update({ estat })
        .eq('id', r.id);
      if (e) throw e;
      await load();
    } catch (e:any) {
      uiError = e?.message ?? 'No s’ha pogut actualitzar l’estat';
    } finally {
      busyId = null;
    }
  }

  async function programar(r: Challenge) {
    uiError = null;
    try {
      const val = planDate[r.id];
      if (!val) { uiError = 'Indica una data per programar.'; return; }
      const iso = new Date(val).toISOString();

      busyId = r.id;
      const { supabase } = await import('$lib/supabaseClient');
      const { error: e } = await supabase
        .from('challenges')
        .update({
          estat: 'programat',
          data_acceptacio: iso
        })
        .eq('id', r.id);
      if (e) throw e;

      await load();
    } catch (e:any) {
      uiError = e?.message ?? 'No s’ha pogut programar el repte';
    } finally {
      busyId = null;
    }
  }
</script>

<svelte:head>
  <title>Admin · Reptes</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Administració — Reptes</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else if error}
  <div class="rounded border border-red-300 bg-red-50 p-3 text-red-700">{error}</div>
{:else if isAdmin}
<!-- Filtres -->
<div class="mb-4 grid gap-2 sm:grid-cols-5">
  <div class="sm:col-span-2">
    <label class="block text-sm mb-1" for="filtre-q">Cerca per nom</label>
    <input
      id="filtre-q"
      class="w-full rounded border px-3 py-2"
      placeholder="Reptador o reptat…"
      bind:value={q}
      on:input={load}
    />
  </div>

  <div>
    <label class="block text-sm mb-1" for="filtre-estat">Estat</label>
    <select
      id="filtre-estat"
      class="w-full rounded border px-3 py-2"
      bind:value={stateFilter}
      on:change={load}
    >
      {#each ALL_STATES as s}
        <option value={s}>{s}</option>
      {/each}
    </select>
  </div>

  <div>
    <label class="block text-sm mb-1" for="filtre-from">Des de</label>
    <input
      id="filtre-from"
      type="date"
      class="w-full rounded border px-3 py-2"
      bind:value={fromDate}
      on:change={load}
    />
  </div>

  <div>
    <label class="block text-sm mb-1" for="filtre-to">Fins a</label>
    <input
      id="filtre-to"
      type="date"
      class="w-full rounded border px-3 py-2"
      bind:value={toDate}
      on:change={load}
    />
  </div>
</div>


  {#if uiError}
    <div class="mb-3 rounded border border-red-300 bg-red-50 p-2 text-sm text-red-700">{uiError}</div>
  {/if}

  <!-- Taula -->
  {#if rows.length === 0}
    <p class="text-slate-600">No hi ha reptes amb aquests filtres.</p>
  {:else}
    <div class="overflow-x-auto border rounded">
      <table class="min-w-full text-sm">
        <thead class="bg-slate-100">
          <tr>
            <th class="px-3 py-2 text-left">Data proposta</th>
            <th class="px-3 py-2 text-left">Reptador</th>
            <th class="px-3 py-2 text-left">Reptat</th>
            <th class="px-3 py-2 text-left">Estat</th>
            <th class="px-3 py-2 text-left">Data programada</th>
            <th class="px-3 py-2 text-left">Accions</th>
          </tr>
        </thead>
        <tbody>
          {#each rows.filter(matchesQuery) as r}
            <tr class="border-t align-top">
              <td class="px-3 py-2">{fmt(r.data_proposta)}</td>
              <td class="px-3 py-2">#{r.pos_reptador ?? '—'} — {r.reptador_nom}</td>
              <td class="px-3 py-2">#{r.pos_reptat ?? '—'} — {r.reptat_nom}</td>
              <td class="px-3 py-2 capitalize">{r.estat.replace('_',' ')}</td>
              <td class="px-3 py-2">{fmt(r.data_acceptacio)}</td>
              <td class="px-3 py-2">
                <div class="flex flex-wrap items-center gap-2">
                  <!-- Programar / Reprogramar -->
                  <div class="flex items-center gap-1">
                    <input type="datetime-local" class="rounded border px-2 py-1"
                           bind:value={planDate[r.id]} />
                    <button
                      class="rounded bg-slate-900 text-white px-2 py-1 disabled:opacity-60"
                      on:click={() => programar(r)}
                      disabled={busyId === r.id}
                      title={r.estat === 'programat' ? 'Reprogramar' : 'Programar'}
                    >
                      {busyId === r.id ? '...' : (r.estat === 'programat' ? 'Reprogramar' : 'Programar')}
                    </button>
                  </div>

                  <!-- Acceptar/refusar/anul·lar -->
                  <button class="rounded border px-2 py-1 disabled:opacity-60"
                          on:click={() => setEstat(r, 'acceptat')}
                          disabled={busyId === r.id}>
                    Acceptar
                  </button>
                  <button class="rounded border px-2 py-1 disabled:opacity-60"
                          on:click={() => setEstat(r, 'refusat')}
                          disabled={busyId === r.id}>
                    Refusar
                  </button>
                  <button class="rounded border px-2 py-1 disabled:opacity-60"
                          on:click={() => setEstat(r, 'anullat')}
                          disabled={busyId === r.id}>
                    Anul·lar
                  </button>

                  <!-- Posar resultat -->
                  <a class="rounded border px-2 py-1 hover:bg-slate-50"
                     href={`/admin/reptes/${r.id}/resultat`}>
                    Posar resultat
                  </a>
                </div>

                {#if r.dates_proposades?.length}
                  <div class="text-xs text-slate-500 mt-2">
                    Dates proposades:
                    <ul class="list-disc ml-5">
                      {#each r.dates_proposades as d}<li>{fmt(d)}</li>{/each}
                    </ul>
                  </div>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
{/if}
