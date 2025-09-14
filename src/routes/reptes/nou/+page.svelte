<script lang="ts">

    import { onMount } from 'svelte';
    import { getSettings } from '$lib/settings';
    import Banner from '$lib/components/Banner.svelte';
    import Loader from '$lib/components/Loader.svelte';
    import { ok as okMsg, err as errMsg } from '$lib/ui/alerts';
    import { supabase } from '$lib/supabaseClient';
    import { canCreateChallenge, type CanCreateChallengeResult } from '$lib/canCreateChallenge';


  type RankedPlayer = { posicio: number; player_id: string; nom: string };
  type NotReptable = RankedPlayer & { motiu: string };

    let loading = true;
    let err: string | null = null;
    let ok: string | null = null;
    let info: string | null = null;

  let myPlayerId: string | null = null;
  let myPos: number | null = null;
  let eventId: string | null = null;

  let reptables: RankedPlayer[] = [];
  let noReptables: NotReptable[] = [];

  let selectedOpponent: string | null = null;
  let notes = '';

  let canChk: CanCreateChallengeResult | null = null;

  // Dates proposades (en format local del <input>)
  let dateInputs: string[] = [
    toLocalInput(new Date().toISOString())
  ];

  onMount(async () => {
    try {
      loading = true;
      err = null;
      ok = null;
      info = null;
      await getSettings();

      const res = await fetch('/reptes/nou/eligibles', { credentials: 'include' });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        err = errMsg(data.error || 'Error en carregar dades.');
        return;
      }

      myPlayerId = data.my_player_id;
      myPos = data.my_pos;
      eventId = data.event_id;
      reptables = data.reptables ?? [];
      noReptables = data.no_reptables ?? [];
      if (reptables.length === 0) {
        info = 'Ara mateix no pots reptar cap jugador.';
      }
    } catch (e: any) {
      err = errMsg(e?.message || 'Error en carregar dades.');
    } finally {
      loading = false;
    }
  });

  function toLocalInput(iso: string) {
    const d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    const pad = (n:number)=>String(n).padStart(2,'0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function parseLocalToIso(local: string | null): string | null {
    if (!local) return null;
    let s = local.trim().replace(' ', 'T');
    const m = s.match(
      /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?$/
    );
    if (!m) {
      const dt2 = new Date(s);
      return isNaN(dt2.getTime()) ? null : dt2.toISOString();
    }
    const [, y, mo, d, h, mi, ss = '0', ms = '0'] = m;
    const Y = Number(y), M = Number(mo) - 1, D = Number(d);
    const H = Number(h), I = Number(mi), S = Number(ss), MS = Number(ms.padEnd(3, '0'));
    const dt = new Date(Y, M, D, H, I, S, MS);
    if (isNaN(dt.getTime())) return null;
    if (dt.getFullYear() !== Y || dt.getMonth() !== M || dt.getDate() !== D || dt.getHours() !== H || dt.getMinutes() !== I) return null;
    return dt.toISOString();
  }

  function addDateInput() {
    if (dateInputs.length >= 3) return;
    dateInputs = [...dateInputs, ''];
  }
  function removeDateInput(idx: number) {
    dateInputs = dateInputs.filter((_, i) => i !== idx);
    if (dateInputs.length === 0) {
      dateInputs = [''];
    }
  }

  function validate(): string | null {
    if (!eventId || !myPlayerId) return 'Error d’estat intern: falta event o jugador.';
    if (!selectedOpponent) return 'Cal triar oponent.';
    const parsed = dateInputs
      .map(v => parseLocalToIso(v || null))
      .filter(Boolean) as string[];
    if (parsed.length === 0) return 'Has de proposar almenys una data.';
    return null;
  }

  let valMsg: string | null = null;
  $: valMsg = validate();

  $: (async () => {
    if (selectedOpponent && eventId && myPlayerId) {
      canChk = await canCreateChallenge(supabase, eventId, myPlayerId, selectedOpponent);
    } else {
      canChk = null;
    }
  })();

  async function creaRepte() {
    try {
      err = null;
      ok = null;
      const v = validate();
      if (v) { err = v; return; }
      if (canChk && !canChk.ok) { err = errMsg(canChk.reason || 'Repte no permès'); return; }

      // Converteix totes les dates vàlides a ISO
      const datesIso = dateInputs
        .map(v => parseLocalToIso(v || null))
        .filter(Boolean) as string[];

      const res = await fetch('/reptes/nou', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          event_id: eventId,
          reptat_id: selectedOpponent,
          dates_proposades: datesIso,
          observacions: notes || null,
          tipus: 'normal'
        })
      });
      const data = await res.json();
      if (!res.ok || !data.ok) throw new Error(data.error || 'Error en crear repte');

        ok = okMsg('Repte creat correctament. S’han enviat les teves propostes de data.');
      // Reseteja el formulari
      selectedOpponent = null;
      notes = '';
      dateInputs = [toLocalInput(new Date().toISOString())];
      } catch (e: any) {
        err = errMsg(e?.message || 'Error en crear repte');
      }
    }
  </script>

<svelte:head><title>Nou repte</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Nou repte</h1>

{#if loading}
      <Loader />
{:else}
    {#if err}<Banner type="error" message={err} class="mb-3" />{/if}
    {#if ok}<Banner type="success" message={ok} class="mb-3" />{/if}
    {#if info}<Banner type="info" message={info} class="mb-3" />{/if}
    {#if canChk && !canChk.ok}<Banner type="error" message={canChk.reason || 'Repte no permès'} class="mb-3" />{/if}

  {#if myPos}
    <div class="rounded-2xl border bg-white p-4 shadow-sm mb-4">
      <div class="text-sm text-slate-600">La teva posició: <strong>#{myPos}</strong></div>
    </div>
  {/if}

  <div class="rounded-2xl border bg-white p-4 shadow-sm max-w-xl">
    <div class="grid gap-4">
      <div class="grid gap-1">
        <label for="opponent" class="text-sm text-slate-700">Tria oponent (posicions permeses)</label>
        <select id="opponent" class="rounded-xl border px-3 py-2" bind:value={selectedOpponent} disabled={reptables.length === 0}>
          <option value="" disabled selected>— Selecciona jugador —</option>
          {#each reptables as r}
            <option value={r.player_id}>#{r.posicio} — {r.nom}</option>
          {/each}
        </select>
      </div>

      {#if noReptables.length}
        <details class="text-sm text-slate-700">
          <summary class="cursor-pointer select-none">Oponents no disponibles</summary>
          <ul class="mt-2 list-disc pl-6 text-slate-600">
            {#each noReptables as nr}
              <li>#{nr.posicio} — {nr.nom} ({nr.motiu})</li>
            {/each}
          </ul>
        </details>
      {/if}

      <div class="grid gap-2">
        <span id="dates-label" class="text-sm text-slate-700">Proposa dates (mínim 1, màxim 3)</span>

        {#each dateInputs as v, i}
          <div class="flex gap-2 items-center">
            <input
              type="datetime-local"
              step="60"
              class="flex-1 rounded-xl border px-3 py-2"
              bind:value={dateInputs[i]}
              placeholder="AAAA-MM-DDThh:mm"
              aria-describedby="dates-label"
            />
            <button type="button"
              class="rounded border px-3 py-2 text-sm"
              on:click={() => removeDateInput(i)}
              disabled={dateInputs.length <= 1}>
              Elimina
            </button>
          </div>
        {/each}

        <div>
          <button type="button"
            class="rounded-2xl border px-3 py-1 text-sm"
            on:click={addDateInput}
            disabled={dateInputs.length >= 3}>
            + Afegeix una altra data
          </button>
        </div>
      </div>

      <div class="grid gap-1">
        <label for="notes" class="text-sm text-slate-700">Observacions (opcional)</label>
        <textarea id="notes" class="rounded-xl border px-3 py-2" rows="3" bind:value={notes}></textarea>
      </div>

        {#if valMsg}
          <Banner type="warn" message={valMsg} class="p-2 text-sm" />
        {/if}

      <div class="flex items-center gap-3 pt-1">
        <button class="rounded-2xl bg-slate-900 text-white px-4 py-2 disabled:opacity-60"
                on:click|preventDefault={creaRepte}
                disabled={!!valMsg || !(canChk?.ok)}>
          Crear repte
        </button>
        <a href="/reptes" class="text-sm underline text-slate-600">Torna</a>
      </div>
    </div>
  </div>
{/if}
