<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { getSettings } from '$lib/settings';

  type RankedPlayer = { posicio: number; player_id: string; nom: string };
  type NotReptable = RankedPlayer & { motiu: string };

  let loading = true;
  let err: string | null = null;
  let ok: string | null = null;

  let myPlayerId: string | null = null;
  let myPos: number | null = null;
  let eventId: string | null = null;

  let allRank: RankedPlayer[] = [];
  let reptables: RankedPlayer[] = [];
  let noReptables: NotReptable[] = [];

  let selectedOpponent: string | null = null;
  let notes = '';

  // Dates proposades (en format local del <input>)
  let dateInputs: string[] = [
    toLocalInput(new Date().toISOString())
  ];

  onMount(async () => {
    try {
      loading = true;
      err = null;
      ok = null;
      await getSettings();

      // 1) Sessió i player_id
      const { data: s } = await supabase.auth.getSession();
      const email = s?.session?.user?.email ?? null;
      if (!email) { err = "Has d’iniciar sessió."; return; }

      const qPlayer = await supabase.from('players').select('id').eq('email', email).maybeSingle();
      if (qPlayer.error) throw qPlayer.error;
      if (!qPlayer.data) { err = 'El teu email no està vinculat a cap jugador.'; return; }
      myPlayerId = qPlayer.data.id;

      // 2) Event actiu
      const qEvent = await supabase.from('events').select('id').eq('actiu', true).order('creat_el', { ascending: false }).limit(1).maybeSingle();
      if (qEvent.error) throw qEvent.error;
      if (!qEvent.data) { err = 'No hi ha cap esdeveniment actiu.'; return; }
      eventId = qEvent.data.id;

      // 3) Rànquing complet i meva posició
      const qRank = await supabase
        .from('ranking_positions')
        .select('posicio, player_id, players!inner(nom)')
        .eq('event_id', eventId)
        .order('posicio', { ascending: true });
      if (qRank.error) throw qRank.error;
      allRank = (qRank.data ?? []).map((r: any) => ({
        posicio: r.posicio, player_id: r.player_id, nom: r.players?.nom ?? '—'
      }));

      const mine = allRank.find(r => r.player_id === myPlayerId) ?? null;
      if (!mine) { err = 'No formes part del rànquing actual.'; return; }
      myPos = mine.posicio;

      // 4) Determinar reptables i no disponibles
      reptables = [];
      noReptables = [];
      for (const r of allRank) {
        if (r.player_id === myPlayerId) continue;
        if (r.posicio >= myPos! || r.posicio < myPos! - 2) {
          noReptables.push({ ...r, motiu: 'fora del marge de posicions' });
          continue;
        }
        const { data: chk, error: eChk } = await supabase.rpc('can_create_challenge', {
          p_event: eventId,
          p_reptador: myPlayerId,
          p_reptat: r.player_id
        });
        if (eChk) {
          noReptables.push({ ...r, motiu: 'no disponible' });
          continue;
        }
        const res = (chk as any)?.[0];
        if (res?.ok) {
          reptables.push(r);
        } else {
          let motiu = res?.reason ?? 'no disponible';
          if (motiu.toLowerCase().includes('repte actiu')) motiu = 'té un repte actiu';
          else if (motiu.toLowerCase().includes('temps mínim')) motiu = 'cooldown no complert';
          else if (motiu.toLowerCase().includes('diferència de posicions')) motiu = 'fora del marge de posicions';
          noReptables.push({ ...r, motiu });
        }
      }
    } catch (e: any) {
      const msg = String(e?.message || '').toLowerCase();
      if (msg.includes('policy') || msg.includes('row-level security') || msg.includes('permission')) {
        err = 'No tens permisos per carregar les dades.';
      } else {
        err = e?.message ?? 'Error carregant dades';
      }
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

  async function creaRepte() {
    try {
      err = null;
      ok = null;
      const v = validate();
      if (v) { err = v; return; }

      // Converteix totes les dates vàlides a ISO
      const datesIso = dateInputs
        .map(v => parseLocalToIso(v || null))
        .filter(Boolean) as string[];

      const { error } = await supabase.from('challenges').insert({
        event_id: eventId,
        reptador_id: myPlayerId,
        reptat_id: selectedOpponent,
        tipus: 'normal',
        estat: 'proposat',
        dates_proposades: datesIso,
        observacions: notes || null
      });
      if (error) throw error;

      ok = 'Repte creat correctament. S’han enviat les teves propostes de data.';
      // Reseteja el formulari
      selectedOpponent = null;
      notes = '';
      dateInputs = [toLocalInput(new Date().toISOString())];
    } catch (e:any) {
      const msg = String(e?.message || '').toLowerCase();
      if (msg.includes('policy') || msg.includes('row-level security') || msg.includes('permission')) {
        err = 'No tens permisos per crear el repte.';
      } else {
        err = e?.message ?? 'No s’ha pogut crear el repte';
      }
    }
  }
</script>

<svelte:head><title>Nou repte</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Nou repte</h1>

{#if loading}
  <div class="rounded border p-3 animate-pulse text-slate-600">Carregant…</div>
{:else}
  {#if err}<div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{err}</div>{/if}
  {#if ok}<div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{ok}</div>{/if}

  {#if myPos}
    <div class="rounded-2xl border bg-white p-4 shadow-sm mb-4">
      <div class="text-sm text-slate-600">La teva posició: <strong>#{myPos}</strong></div>
    </div>
  {/if}

  <div class="rounded-2xl border bg-white p-4 shadow-sm max-w-xl">
    <div class="grid gap-4">
      <div class="grid gap-1">
        <label for="opponent" class="text-sm text-slate-700">Tria oponent (posicions permeses)</label>
        <select id="opponent" class="rounded-xl border px-3 py-2" bind:value={selectedOpponent}>
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
        <div class="rounded border border-amber-300 bg-amber-50 text-amber-900 p-2 text-sm">
          {valMsg}
        </div>
      {/if}

      <div class="flex items-center gap-3 pt-1">
        <button class="rounded-2xl bg-slate-900 text-white px-4 py-2 disabled:opacity-60"
                on:click|preventDefault={creaRepte}
                disabled={!!valMsg}>
          Crear repte
        </button>
        <a href="/reptes" class="text-sm underline text-slate-600">Torna</a>
      </div>
    </div>
  </div>
{/if}
