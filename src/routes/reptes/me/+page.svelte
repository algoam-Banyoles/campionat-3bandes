<script lang="ts">
import { onMount } from 'svelte';
import { user } from '$lib/authStore';
import { getSettings, type AppSettings } from '$lib/settings';

type Challenge = {
  id: string;
  event_id: string;
  tipus: 'normal' | 'access';
  reptador_id: string;
  reptat_id: string;
  estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
  dates_proposades: string[];
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
let rows: Challenge[] = [];
let myPlayerId: string | null = null;
let busy: string | null = null;
let scheduleLocal: Map<string, string> = new Map();
let settings: AppSettings = await getSettings();

onMount(async () => {
  try {
    await fetch('/reptes/penalitzacions', { method: 'POST' });
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
      .select('id,event_id,tipus,reptador_id,reptat_id,estat,dates_proposades,data_proposta,data_acceptacio,reprogram_count,pos_reptador,pos_reptat')
      .or(`reptador_id.eq.${myPlayerId},reptat_id.eq.${myPlayerId}`)
      .order('data_proposta', { ascending: false });
    if (e2) throw e2;

    const ids = Array.from(
      new Set([...(ch?.map((c) => c.reptador_id) ?? []), ...(ch?.map((c) => c.reptat_id) ?? [])])
    );
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

    scheduleLocal = new Map();
    const now = toLocalInput(new Date().toISOString());
    for (const r of rows) {
      scheduleLocal.set(r.id, toLocalInput(r.data_acceptacio) || now);
    }
    scheduleLocal = new Map(scheduleLocal);
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

function toLocalInput(iso: string | null) {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function parseLocalToIso(local: string | null) {
  if (!local) return null;
  const d = new Date(local);
  return isNaN(d.getTime()) ? null : d.toISOString();
}

function addDays(date: Date, days: number) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

let maxScheduleLocal = '';
$: maxScheduleLocal = toLocalInput(addDays(new Date(), settings.dies_jugar_despres_acceptar).toISOString());

function isMeReptat(r: Challenge) {
  return myPlayerId === r.reptat_id;
}

function isMeReptador(r: Challenge) {
  return myPlayerId === r.reptador_id;
}

function canAccept(r: Challenge) {
  return r.estat === 'proposat' && isMeReptat(r);
}

function canRefuse(r: Challenge) {
  return r.estat === 'proposat' && isMeReptat(r);
}

function canProgram(r: Challenge) {
  if (r.estat === 'proposat') return isMeReptat(r);
  if (['acceptat', 'programat'].includes(r.estat)) return isMeReptat(r) || isMeReptador(r);
  return false;
}

function isFrozen(r: Challenge) {
  return ['anullat', 'jugat', 'refusat', 'caducat'].includes(r.estat);
}

async function accept(r: Challenge) {
  error = null;
  okMsg = null;
  try {
    busy = r.id;
    const { supabase } = await import('$lib/supabaseClient');
    const { error: e } = await supabase
      .from('challenges')
      .update({ estat: 'acceptat', data_acceptacio: null })
      .eq('id', r.id)
      .eq('estat', 'proposat');
    if (e) throw e;
    okMsg = 'Repte acceptat correctament.';
    await load();
  } catch (e: any) {
    error = e?.message ?? 'No s\u2019ha pogut acceptar el repte';
  } finally {
    busy = null;
  }
}

async function refuse(r: Challenge) {
  error = null;
  okMsg = null;
  try {
    busy = r.id;
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
    busy = null;
  }
}

async function saveSchedule(r: Challenge) {
  error = null;
  okMsg = null;
  const local = scheduleLocal.get(r.id) ?? '';
  const parsedIso = parseLocalToIso(local);
  if (!parsedIso) {
    error = 'Cal indicar una data v\u00e0lida.';
    return;
  }
  const maxDate = addDays(new Date(), settings.dies_jugar_despres_acceptar);
  if (new Date(parsedIso) > maxDate) {
    error = `La data ha d'estar dins de ${settings.dies_jugar_despres_acceptar} dies.`;
    return;
  }
  try {
    busy = r.id;
    const { supabase } = await import('$lib/supabaseClient');
    const { data, error: e } = await supabase.rpc('program_challenge', { p_challenge: r.id, p_when: parsedIso });
    if (e) throw e;
    if (data?.[0]?.ok === false) {
      const reason = data?.[0]?.reason;
      if (reason === 'reprogram_limit_reached') {
        error = 'Aquest repte ja s\u2019ha reprogramat una vegada. Si cal canviar-ho de nou, contacta amb un administrador.';
      } else {
        error = reason ?? 'No s\u2019ha pogut desar la data';
      }
      return;
    }
    okMsg = 'Data desada correctament.';
    await load();
  } catch (e: any) {
    error = e?.message ?? 'No s\u2019ha pogut desar la data';
  } finally {
    busy = null;
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
  <p class="text-slate-500">Carregant…</p>
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
            <span class="text-xs rounded bg-slate-100 px-2 py-0.5 capitalize">{r.estat}</span>
            <span class="text-xs text-slate-500 ml-auto">Proposat: {fmt(r.data_proposta)}</span>
            {#if r.data_acceptacio}
              <span class="text-xs text-slate-500">Programat: {fmt(r.data_acceptacio)}</span>
            {/if}
          </div>

          <div class="text-sm">
            <div><strong>Reptador:</strong> #{r.pos_reptador ?? '—'} — {r.reptador_nom}</div>
            <div><strong>Reptat:</strong> #{r.pos_reptat ?? '—'} — {r.reptat_nom}</div>
          </div>

          {#if r.dates_proposades?.length}
            <div class="text-sm">
              <strong>Dates proposades:</strong>
              <ul class="list-disc ml-6">
                {#each r.dates_proposades as d}<li>{fmt(d)}</li>{/each}
              </ul>
            </div>
          {/if}

          {#if canAccept(r)}
            <div class="flex gap-2 mb-2">
              <button
                class="rounded bg-green-600 text-white px-3 py-1 disabled:opacity-60"
                on:click={() => accept(r)}
                disabled={busy === r.id}
              >
                {busy === r.id ? 'Processant…' : 'Accepta'}
              </button>
              <button
                class="rounded bg-red-600 text-white px-3 py-1 disabled:opacity-60"
                on:click={() => refuse(r)}
                disabled={busy === r.id}
              >
                {busy === r.id ? 'Processant…' : 'Refusa'}
              </button>
            </div>
          {/if}

          {#if canProgram(r)}
            <div class="flex flex-wrap items-end gap-2">
              <div>
                <label class="text-sm" for={`schedule-${r.id}`}>
                  {r.estat === 'proposat' ? 'Programar' : '(Re)programar'}
                </label>
                <input
                  class="block border rounded px-2 py-1 mt-1"
                  type="datetime-local"
                  step="60"
                  max={maxScheduleLocal}
                  id={`schedule-${r.id}`}
                  value={scheduleLocal.get(r.id) ?? ''}
                  on:input={(e) => scheduleLocal.set(r.id, (e.target as HTMLInputElement).value)}
                  disabled={busy === r.id}
                />
                <p class="text-xs text-slate-500 mt-1">
                  La data ha d'estar dins de {settings.dies_jugar_despres_acceptar} dies.
                </p>
                {#if r.estat === 'programat' && r.reprogram_count >= 1}
                  <p class="text-xs text-slate-500 mt-1">
                    Has arribat al límit de reprogramacions. Només un administrador pot canviar-la de nou.
                  </p>
                {/if}
              </div>
              <button
                class="rounded bg-blue-600 text-white px-3 py-1 h-9 disabled:opacity-60"
                on:click={() => saveSchedule(r)}
                disabled={busy === r.id}
              >
                {busy === r.id ? 'Desant…' : 'Desa data'}
              </button>
            </div>
          {:else if isFrozen(r)}
            <div class="text-sm text-slate-500">Sense accions.</div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
{/if}
