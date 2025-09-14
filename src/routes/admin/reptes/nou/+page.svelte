<script lang="ts">
import { onMount } from 'svelte';
import { user } from '$lib/authStore';
import { goto } from '$app/navigation';
import { checkIsAdmin } from '$lib/roles';
import Banner from '$lib/components/Banner.svelte';
import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';
import type { SupabaseClient } from '@supabase/supabase-js';
import { canCreateAccessChallenge } from '$lib/canCreateAccessChallenge';

  // Configurable al gust: quins estats considerem “actius”
  const ACTIVE_STATES = ['proposat', 'acceptat', 'programat'] as const;

  type Ranked = { player_id: string; posicio: number; nom: string; email: string | null };
  type PlayerRow = { id: string; nom: string; email: string | null };

  let loading = true;
  let error: string | null = null;
  let okMsg: string | null = null;

  let eventActiuId: string | null = null;
  let isAdmin = false;

  // selecció
  let reptador_id: string | null = null;
  let reptat_id: string | null = null;
  let tipus: 'normal' | 'access' = 'normal';
  let estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat' = 'proposat';

  // dates proposades (0..3, però recomanat 3 si estat = proposat)
  let d1 = '';
  let d2 = '';
  let d3 = '';

  // si admin vol “programar” directament (si estat = acceptat)
  let data_programada = '';

  // permisos extra d’admin
  let forceCreate = false; // permet saltar bloquejos (actius, rang, etc.)
  let playersById = new Map<string, PlayerRow>();
  let ranked: Ranked[] = []; // rànquing de l’event actiu
  let waitFirst: PlayerRow | null = null; // primer de la llista d'espera

  let busy = false;

  onMount(load);

  // Assigna reptador/reptat automàticament en reptes d'accés
  $: if (tipus === 'access') {
    reptador_id = waitFirst?.id ?? null;
    const p20 = ranked.find(r => r.posicio === 20);
    reptat_id = p20?.player_id ?? null;
  }

  function toISO(dtLocal: string): string | null {
    if (!dtLocal) return null;
    const d = new Date(dtLocal);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  async function load() {
    try {
      loading = true; error = null; okMsg = null;

      const u = $user;
      if (!u?.email) {
        // si no hi ha sessió, cap a login
        goto('/login');
        return;
      }

      const adm = await checkIsAdmin();
      if (!adm) {
        error = errText('Només els administradors poden accedir a aquesta pàgina.');
        return;
      }
      isAdmin = true;

      const { supabase } = await import('$lib/supabaseClient');

      // 2) Event actiu
      const { data: ev, error: eEvent } = await supabase
        .from('events')
        .select('id, nom')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();
      if (eEvent) throw eEvent;
        if (!ev) { error = errText('No s’ha trobat cap event actiu.'); return; }
      eventActiuId = ev.id;

      // 3) Rànquing de l’event actiu (ranking_positions + players)
      const { data: rp, error: eRank } = await supabase
        .from('ranking_positions')
        .select('player_id, posicio, players(id, nom, email)')
        .eq('event_id', eventActiuId)
        .order('posicio', { ascending: true });
      if (eRank) throw eRank;

      ranked = (rp ?? []).map(row => ({
        player_id: row.player_id,
        posicio: row.posicio,
        nom: (row as any).players?.nom ?? '—',
        email: (row as any).players?.email ?? null
      }));

      // diccionari auxiliar
      playersById = new Map(ranked.map(r => [r.player_id, { id: r.player_id, nom: r.nom, email: r.email }]));

      // 4) Primer jugador de la llista d'espera
      const { data: wl, error: eWl } = await supabase
        .from('waiting_list')
        .select('player_id, players(id, nom, email)')
        .eq('event_id', eventActiuId)
        .order('ordre', { ascending: true })
        .limit(1)
        .maybeSingle();
      if (eWl) throw eWl;
      if (wl) {
        waitFirst = {
          id: wl.player_id,
          nom: (wl as any).players?.nom ?? '—',
          email: (wl as any).players?.email ?? null
        };
        playersById.set(waitFirst.id, waitFirst);
      }
      } catch (e) {
        error = formatSupabaseError(e);
      } finally {
      loading = false;
    }
  }

async function hasActiveChallenge(supabase: SupabaseClient, playerId: string) {
    const { data: act, error: eAct } = await supabase
      .from('challenges')
      .select('id, estat')
      .eq('event_id', eventActiuId)
      .or(`reptador_id.eq.${playerId},reptat_id.eq.${playerId}`)
      .in('estat', ACTIVE_STATES as any);
    if (eAct) throw eAct;
    return (act ?? []).length > 0;
  }

  async function createChallenge(e: Event) {
    e.preventDefault();
    okMsg = null; error = null;

    try {
      if (!isAdmin) throw new Error('No autoritzat.');
      if (!eventActiuId) throw new Error('No hi ha event actiu.');
      if (!reptador_id || !reptat_id) throw new Error('Cal seleccionar reptador i reptat.');
      if (reptador_id === reptat_id) throw new Error('Reptador i reptat no poden ser la mateixa persona.');

      const { supabase } = await import('$lib/supabaseClient');

      // posicions actuals al rànquing (per coherència)
      const r1 = ranked.find(r => r.player_id === reptador_id);
      const r2 = ranked.find(r => r.player_id === reptat_id);
      if (tipus === 'access') {
        if (!waitFirst || reptador_id !== waitFirst.id)
          throw new Error('El reptador ha de ser el primer de la llista d’espera.');
        if (!r2 || r2.posicio !== 20)
          throw new Error('El reptat ha de ser el jugador #20 del rànquing.');
      } else {
        if (!r1 || !r2)
          throw new Error('Jugadors no presents al rànquing de l’event actiu.');
      }

      // Validacions per defecte (es poden “forçar” si forceCreate = true)
      if (!forceCreate) {
        if (tipus === 'access') {
          const chk = await canCreateAccessChallenge(
            supabase,
            eventActiuId,
            reptador_id,
            reptat_id
          );
          if (!chk.ok) throw new Error(chk.reason || 'Repte d’accés no permès');
        } else {
          // rang: reptador només pot reptar -1 o -2
          const allowed = [r1!.posicio - 1, r1!.posicio - 2].includes(r2!.posicio);
          if (!allowed)
            throw new Error(
              `Rang invàlid: #${r1!.posicio} només pot reptar #${r1!.posicio - 1} o #${r1!.posicio - 2}.`
            );
        }

        // cap dels dos amb repte actiu
        const a1 = await hasActiveChallenge(supabase, reptador_id);
        const a2 = await hasActiveChallenge(supabase, reptat_id);
        if (a1) throw new Error('El reptador ja té un repte actiu.');
        if (a2) throw new Error('El reptat ja té un repte actiu.');
      }

      // dates proposades
      const dates = [d1, d2, d3].map(toISO).filter(Boolean) as string[];

      // si estat és “proposat”: demanem 3 dates
      if (estat === 'proposat' && dates.length < 3 && !forceCreate) {
        throw new Error('En estat "proposat" calen 3 dates proposades (normativa).');
      }

      // si es crea ja acceptat, opcionalment es pot programar
      let data_programada_iso: string | null = null;
      let finalEstat = estat;
      let data_acceptacio_iso: string | null = null;
      if (finalEstat === 'acceptat') {
        data_acceptacio_iso = new Date().toISOString();
        const iso = toISO(data_programada);
        if (iso) {
          data_programada_iso = iso;
          finalEstat = 'programat';
        }
      }

      busy = true;

      const payload: any = {
        event_id: eventActiuId,
        tipus,
        reptador_id,
        reptat_id,
        estat: finalEstat,
        dates_proposades: dates,           // pot estar buit si admin ho vol forçar
        data_proposta: new Date().toISOString(),
        data_programada: data_programada_iso,
        pos_reptador: r1?.posicio ?? null,
        pos_reptat: r2?.posicio ?? null
      };
      if (data_acceptacio_iso) {
        payload.data_acceptacio = data_acceptacio_iso;
      }

      const { error: eIns } = await supabase.from('challenges').insert(payload);
      if (eIns) throw eIns;

      okMsg = okText('Repte creat correctament.');
      reptador_id = reptat_id = null;
      d1 = d2 = d3 = ''; data_programada = '';
      tipus = 'normal'; estat = 'proposat';
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      busy = false;
    }
  }
</script>

<svelte:head>
  <title>Admin · Nou repte</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Administració — Crear repte</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else}
    {#if error}
      <Banner type="error" message={error} class="mb-3" />
    {/if}
    {#if okMsg}
      <Banner type="success" message={okMsg} class="mb-3" />
    {/if}

  {#if isAdmin && eventActiuId}
    <form class="space-y-4 max-w-2xl" on:submit={createChallenge}>
      <div class="grid sm:grid-cols-2 gap-3">
        <div>
          <label for="event_actiu" class="block text-sm mb-1">Event actiu</label>
          <input id="event_actiu" class="w-full rounded border px-3 py-2 bg-slate-50" value={eventActiuId} disabled />
        </div>

        <div>
          <label for="tipus" class="block text-sm mb-1">Tipus</label>
          <select id="tipus" class="w-full rounded border px-3 py-2" bind:value={tipus}>
            <option value="normal">Normal</option>
            <option value="access">Accés</option>
          </select>
        </div>
      </div>

      <div class="grid sm:grid-cols-2 gap-3">
        <div>
          <label for="reptador" class="block text-sm mb-1">Reptador</label>
          {#if tipus === 'access'}
            <input
              id="reptador"
              class="w-full rounded border px-3 py-2 bg-slate-50"
              value={waitFirst ? waitFirst.nom : '—'}
              disabled
            />
          {:else}
            <select id="reptador" class="w-full rounded border px-3 py-2" bind:value={reptador_id} required>
              <option value="" disabled selected>— Selecciona —</option>
              {#each ranked as r}
                <option value={r.player_id}>#{r.posicio} — {r.nom}</option>
              {/each}
            </select>
          {/if}
        </div>
        <div>
          <label for="reptat" class="block text-sm mb-1">Reptat</label>
          {#if tipus === 'access'}
            <input
              id="reptat"
              class="w-full rounded border px-3 py-2 bg-slate-50"
              value={ranked.find(r => r.posicio === 20)?.nom ?? '—'}
              disabled
            />
          {:else}
            <select id="reptat" class="w-full rounded border px-3 py-2" bind:value={reptat_id} required>
              <option value="" disabled selected>— Selecciona —</option>
              {#each ranked as r}
                <option value={r.player_id}>#{r.posicio} — {r.nom}</option>
              {/each}
            </select>
          {/if}
        </div>
      </div>

      <div class="grid sm:grid-cols-2 gap-3">
        <div>
          <label for="estat" class="block text-sm mb-1">Estat inicial</label>
          <select id="estat" class="w-full rounded border px-3 py-2" bind:value={estat}>
            <option value="proposat">Proposat</option>
            <option value="acceptat">Acceptat (programat)</option>
            <option value="refusat">Refusat</option>
            <option value="caducat">Caducat</option>
            <option value="jugat">Jugat</option>
            <option value="anullat">Anullat</option>
          </select>
        </div>

        {#if estat === 'acceptat'}
          <div>
            <label for="prog" class="block text-sm mb-1">Data programada (opcional)</label>
            <input id="prog" type="datetime-local" class="w-full rounded border px-2 py-1" bind:value={data_programada} />
            <p class="text-xs text-slate-500 mt-1">Si s’omple, l’estat passa a «programat» i es desa com a <em>data_programada</em>.</p>
          </div>
        {/if}
      </div>

      <fieldset class="border rounded p-3">
        <legend class="text-sm px-1">Dates proposades (normativa: 3 si “proposat”)</legend>
        <div class="grid sm:grid-cols-3 gap-2">
          <div>
            <label for="d1" class="block text-sm mb-1">Data 1</label>
            <input id="d1" type="datetime-local" class="w-full rounded border px-2 py-1" bind:value={d1} />
          </div>
          <div>
            <label for="d2" class="block text-sm mb-1">Data 2</label>
            <input id="d2" type="datetime-local" class="w-full rounded border px-2 py-1" bind:value={d2} />
          </div>
          <div>
            <label for="d3" class="block text-sm mb-1">Data 3</label>
            <input id="d3" type="datetime-local" class="w-full rounded border px-2 py-1" bind:value={d3} />
          </div>
        </div>
        <p class="text-xs text-slate-500 mt-2">L’admin pot forçar la creació encara que hi hagi bloquejos.</p>
      </fieldset>

      <div class="flex items-center gap-2">
        <input id="force" type="checkbox" bind:checked={forceCreate} />
        <label for="force" class="text-sm">Força creació (ignora rang i reptes actius)</label>
      </div>

      <div class="flex gap-2">
        <button class="rounded bg-slate-900 text-white px-4 py-2 disabled:opacity-60" disabled={busy} type="submit">
          {busy ? 'Creant…' : 'Crear repte'}
        </button>
        <a class="rounded border px-4 py-2" href="/admin">Cancel·lar</a>
      </div>
    </form>
  {/if}
{/if}
