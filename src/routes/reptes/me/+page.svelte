<script lang="ts">
import { onMount } from 'svelte';
import { user } from '$lib/authStore';
import type { AppSettings } from '$lib/settings';
import Loader from '$lib/components/Loader.svelte';

type Challenge = {
  id: string;
  event_id: string;
  tipus: 'normal' | 'access';
  reptador_id: string;
  reptat_id: string;
  estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
  dates_proposades: string[];
  data_proposta: string;
  pos_reptador: number | null;
  pos_reptat: number | null;
  reptador_nom?: string;
  reptat_nom?: string;
};

let loading = true;
let error: string | null = null;
let okMsg: string | null = null;
let rows: Challenge[] = [];
let myPlayerId: string | null = null;
let actionBusy: string | null = null;
let selectedDates: Map<string, string> = new Map();
export let data: { settings: AppSettings };
let settings: AppSettings = data.settings;

onMount(async () => {
  try {
    await fetch('/reptes/penalitzacions');
  } catch {
    /* ignore */
  }
  await load();
});

async function load() {
  try {
    loading = true;
    error = null;
    okMsg = null;

    const u = $user;
    if (!u?.email) {
      error = 'Has d\u2019iniciar sessi\u00f3.';
      return;
    }

    const { supabase } = await import('$lib/supabaseClient');

    const { data: p, error: e1 } = await supabase
      .from('players')
      .select('id')
      .eq('email', u.email)
      .maybeSingle();
    if (e1) throw e1;
    if (!p) {
      error = 'El teu email no est\u00e0 vinculat a cap jugador.';
      return;
    }
    myPlayerId = p.id;

    const { data: ch, error: e2 } = await supabase
      .from('challenges')
      .select('id,event_id,tipus,reptador_id,reptat_id,estat,dates_proposades,data_proposta,pos_reptador,pos_reptat')
      .or(`reptador_id.eq.${myPlayerId},reptat_id.eq.${myPlayerId}`)
      .order('data_proposta', { ascending: false });
    if (e2) throw e2;

    const ids = Array.from(new Set([...(ch?.map((c) => c.reptador_id) ?? []), ...(ch?.map((c) => c.reptat_id) ?? [])]));
    let nameById = new Map<string, string>();
    if (ids.length) {
      const { data: players, error: e3 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', ids);
      if (e3) throw e3;
      nameById = new Map(players?.map((p) => [p.id, p.nom]) ?? []);
    }

    rows = (ch ?? []).map((c) => ({
      ...c,
      reptador_nom: nameById.get(c.reptador_id) ?? '—',
      reptat_nom: nameById.get(c.reptat_id) ?? '—'
    }));

    selectedDates = new Map();
  } catch (e: any) {
    error = e?.message ?? 'Error desconegut carregant reptes';
  } finally {
    loading = false;
  }
}

function fmt(iso: string | null) {
  if (!iso) return '—';
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleString();
}

function estatClass(e: Challenge['estat']) {
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

function canAct(r: Challenge) {
  return r.estat === 'proposat' && r.reptat_id === myPlayerId && !['anullat', 'jugat'].includes(r.estat);
}

async function acceptWithDate(r: Challenge) {
  error = null;
  okMsg = null;
  const d = selectedDates.get(r.id);
  if (!d) {
    error = 'Cal seleccionar una data.';
    return;
  }
  try {
    actionBusy = r.id;
    const res = await fetch('/reptes/accepta', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: r.id, data_iso: d })
    });
    const j = await res.json();
    if (!j.ok) throw new Error(j.error || 'Error');
    okMsg = 'Repte acceptat correctament.';
    await load();
  } catch (e: any) {
    error = e?.message ?? 'No s\u2019ha pogut acceptar el repte';
  } finally {
    actionBusy = null;
  }
}

async function acceptWithoutDate(r: Challenge) {
  error = null;
  okMsg = null;
  try {
    actionBusy = r.id;
    const res = await fetch('/reptes/accepta', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: r.id, data_iso: null })
    });
    const j = await res.json();
    if (!j.ok) throw new Error(j.error || 'Error');
    okMsg = 'Repte acceptat correctament.';
    await load();
  } catch (e: any) {
    error = e?.message ?? 'No s\u2019ha pogut acceptar el repte';
  } finally {
    actionBusy = null;
  }
}

async function refuse(r: Challenge) {
  error = null;
  okMsg = null;
  try {
    actionBusy = r.id;
    const { supabase } = await import('$lib/supabaseClient');
    const { error: e } = await supabase
      .from('challenges')
      .update({ estat: 'refusat' })
      .eq('id', r.id)
      .eq('estat', 'proposat');
    if (e) throw e;
    okMsg = 'Repte refusat correctament.';
    await load();
  } catch (e: any) {
    error = e?.message ?? 'No s\u2019ha pogut refusar el repte';
  } finally {
    actionBusy = null;
  }
}
</script>

<svelte:head>
  <title>Els meus reptes</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Els meus reptes</h1>
<div class="rounded border border-blue-300 bg-blue-50 text-blue-900 p-3 mb-4 text-sm">
  Tens {settings.dies_acceptar_repte} dies per acceptar un repte i {settings.dies_jugar_despres_acceptar} dies per jugar-lo un cop acceptat.
</div>

{#if loading}
  <Loader />
{:else}
  {#if error}
    <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{error}</div>
  {/if}
  {#if okMsg}
    <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{okMsg}</div>
  {/if}

  {#if !error && rows.length === 0}
    <p class="text-slate-600">No tens reptes registrats.</p>
  {/if}

  {#if rows.length > 0}
    <div class="space-y-3">
      {#each rows as r}
        <div class="rounded border p-3 space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-xs rounded bg-slate-800 text-white px-2 py-0.5">{r.tipus}</span>
            <span class={`text-xs rounded px-2 py-0.5 capitalize ${estatClass(r.estat)}`}>{r.estat}</span>
            <span class="text-xs text-slate-500 ml-auto">Proposat: {fmt(r.data_proposta)}</span>
          </div>

          <div class="text-sm">
            <div><strong>Reptador:</strong> #{r.pos_reptador ?? '—'} — {r.reptador_nom}</div>
            <div><strong>Reptat:</strong> #{r.pos_reptat ?? '—'} — {r.reptat_nom}</div>
          </div>

          {#if r.dates_proposades?.length}
            <div class="text-sm">
              <strong>Dates proposades:</strong>
              <ul class="mt-1 space-y-1">
                {#each r.dates_proposades as d, i}
                  <li class="flex items-center gap-2">
                    <input
                      id={`date-${r.id}-${i}`}
                      type="radio"
                      name={`dates-${r.id}`}
                      value={d}
                      checked={selectedDates.get(r.id) === d}
                      on:change={() => {
                        selectedDates.set(r.id, d);
                        selectedDates = new Map(selectedDates);
                      }}
                    />
                    <label for={`date-${r.id}-${i}`}>{fmt(d)}</label>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}

          {#if canAct(r)}
            <div class="flex gap-2 flex-wrap">
              <button
                class="rounded bg-green-600 text-white px-3 py-1 disabled:opacity-60"
                on:click={() => acceptWithDate(r)}
                disabled={actionBusy === r.id || !selectedDates.get(r.id)}
                title={!selectedDates.get(r.id) ? 'Cal seleccionar una data' : undefined}
              >
                {actionBusy === r.id ? 'Processant…' : 'Accepta amb data'}
              </button>
              <button
                class="rounded bg-blue-600 text-white px-3 py-1 disabled:opacity-60"
                on:click={() => acceptWithoutDate(r)}
                disabled={actionBusy === r.id}
              >
                {actionBusy === r.id ? 'Processant…' : 'Accepta sense data'}
              </button>
              <button
                class="rounded bg-red-600 text-white px-3 py-1 disabled:opacity-60"
                on:click={() => refuse(r)}
                disabled={actionBusy === r.id}
              >
                {actionBusy === r.id ? 'Processant…' : 'Refusa'}
              </button>
            </div>
            {#if !selectedDates.get(r.id)}
              <div class="text-xs text-slate-500">Cal seleccionar una data.</div>
            {/if}
          {:else if ['anullat', 'jugat'].includes(r.estat)}
            <div class="text-sm text-slate-500">Sense accions.</div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
{/if}

