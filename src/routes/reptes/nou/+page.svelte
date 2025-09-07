<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/authStore';

  type Ranked = { player_id: string; posicio: number; nom: string; email: string | null };

  let loading = true;
  let error: string | null = null;
  let okMsg: string | null = null;

  let eventActiuId: string | null = null;

  // qui sóc jo (amb posició a l’event actiu)
  let jo: Ranked | null = null;

  // rivals filtrats per normativa (només posició -1 o -2, sense reptes actius)
  let rivals: Ranked[] = [];
  let reptat_id: string | null = null;

  // tipus de repte
  let tipus: 'normal' | 'access' = 'normal';

  // 3 dates obligatòries (normativa)
  let d1 = '';
  let d2 = '';
  let d3 = '';

  let busy = false;

  onMount(load);

  function toISO(dtLocal: string): string | null {
    if (!dtLocal) return null;
    const d = new Date(dtLocal);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  // utilitats
  function daysBetween(a: string | Date, b: string | Date) {
    const da = new Date(a).getTime();
    const db = new Date(b).getTime();
    if (isNaN(da) || isNaN(db)) return Number.POSITIVE_INFINITY;
    return Math.floor(Math.abs(da - db) / (1000 * 60 * 60 * 24));
  }

  // Estat que considerem “actiu” (no es pot repetir a la vegada)
  const ACTIVE_STATES = ['proposat', 'acceptat'] as const;

  async function load() {
    try {
      loading = true; error = null; okMsg = null;

      const u = $user;
      if (!u?.email) {
        error = 'Has d’iniciar sessió per crear un repte.';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      // 1) EVENT ACTIU
      const { data: ev, error: eEvent } = await supabase
        .from('events')
        .select('id, nom, any_temporada')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();
      if (eEvent) throw eEvent;
      if (!ev) { error = 'No s’ha trobat cap event actiu.'; return; }
      eventActiuId = ev.id;

      // 2) QUI SÓC JO (player per email)
      const { data: mePlayer, error: ePlayer } = await supabase
        .from('players')
        .select('id, nom, email, data_ultim_repte')
        .eq('email', u.email)
        .maybeSingle();
      if (ePlayer) throw ePlayer;
      if (!mePlayer) { error = 'El teu correu no està vinculat a cap jugador.'; return; }

      // 3) La meva POSICIÓ a l’event actiu (ranking_positions)
      const { data: meRank, error: eRankMe } = await supabase
        .from('ranking_positions')
        .select('posicio')
        .eq('event_id', eventActiuId)
        .eq('player_id', mePlayer.id)
        .maybeSingle();
      if (eRankMe) throw eRankMe;
      if (!meRank) { error = 'No tens posició assignada al rànquing de l’event actiu.'; return; }

      jo = { player_id: mePlayer.id, posicio: meRank.posicio, nom: mePlayer.nom, email: mePlayer.email };

      // 4) VALIDACIÓ: 7 dies des de l’últim repte (excepte si el darrer va ser "refusat")
      //    Preferim usar players.data_ultim_repte si està omplert.
      let blockByCooldown = false;
      if (mePlayer.data_ultim_repte) {
        const diff = daysBetween(mePlayer.data_ultim_repte, new Date());
        if (diff < 7) {
          // Mirem si l’últim repte va acabar en "refusat"; si és així, no bloquegem
          const { data: lastCh, error: eLast } = await supabase
            .from('challenges')
            .select('estat, data_proposta')
            .or(`reptador_id.eq.${mePlayer.id},reptat_id.eq.${mePlayer.id}`)
            .order('data_proposta', { ascending: false })
            .limit(1)
            .maybeSingle();
          if (eLast) throw eLast;

          if (!lastCh || lastCh.estat !== 'refusat') {
            blockByCooldown = true;
          }
        }
      }
      if (blockByCooldown) {
        error = 'Han de passar 7 dies des del teu darrer repte (excepte si va ser refusat).';
        // no return: deixem veure la UI (sense rivals) però no podràs crear
      }

      // 5) Llista de rivals candidates: posició -1 o -2 respecte la meva
      const targetPositions = [jo.posicio - 1, jo.posicio - 2].filter(p => p >= 1);
      if (targetPositions.length === 0) {
        error = 'No tens rivals vàlids per normativa (ja ets al capdamunt del rànquing).';
        rivals = [];
        return;
      }

      const { data: rp, error: eRankAll } = await supabase
        .from('ranking_positions')
        .select('player_id, posicio, players(id, nom, email)')
        .eq('event_id', eventActiuId)
        .in('posicio', targetPositions)
        .order('posicio', { ascending: true });
      if (eRankAll) throw eRankAll;

      let candidates: Ranked[] = (rp ?? []).map(row => ({
        player_id: row.player_id,
        posicio: row.posicio,
        nom: (row as any).players?.nom ?? '—',
        email: (row as any).players?.email ?? null
      }));

      // 6) Excloure rivals (i jo) si tenen reptes ACTIUS (proposat o acceptat)
      //    Mirarem reptes on participin qualsevol de les dues parts.
      async function hasActiveChallenge(playerId: string) {
        const { data: act, error: eAct } = await supabase
          .from('challenges')
          .select('id, estat')
          .eq('event_id', eventActiuId)
          .or(`reptador_id.eq.${playerId},reptat_id.eq.${playerId}`)
          .in('estat', ACTIVE_STATES as any);
        if (eAct) throw eAct;
        return (act ?? []).length > 0;
      }

      const meHasActive = await hasActiveChallenge(jo.player_id);
      if (meHasActive) {
        error = 'Ja tens un repte actiu. No en pots crear un altre fins que acabi.';
        candidates = [];
      } else {
        // filtrar rivals que tinguin repte actiu
        const filtered: Ranked[] = [];
        for (const r of candidates) {
          const rivHas = await hasActiveChallenge(r.player_id);
          if (!rivHas) filtered.push(r);
        }
        candidates = filtered;
      }

      rivals = candidates;
    } catch (e: any) {
      error = e?.message ?? 'Error carregant el formulari';
    } finally {
      loading = false;
    }
  }

  async function createChallenge(e: Event) {
    e.preventDefault();
    okMsg = null; error = null;

    try {
      if (!eventActiuId) throw new Error('No hi ha event actiu.');
      if (!jo) throw new Error('Sessió no preparada.');
      if (!reptat_id) throw new Error('Has de seleccionar el jugador reptat.');

      // Normativa: mínim 3 dates
      const dates = [toISO(d1), toISO(d2), toISO(d3)].filter(Boolean) as string[];
      if (dates.length < 3) throw new Error('La normativa exigeix proposar 3 dates.');

      // Validació final de posicions (per si ha canviat el rànquing entre càrrega i enviament)
      const { supabase } = await import('$lib/supabaseClient');
      const { data: rivRank, error: eRR } = await supabase
        .from('ranking_positions')
        .select('posicio')
        .eq('event_id', eventActiuId)
        .eq('player_id', reptat_id)
        .maybeSingle();
      if (eRR) throw eRR;
      if (!rivRank) throw new Error('El rival no té posició al rànquing actual.');

      const allowed = [jo.posicio - 1, jo.posicio - 2].includes(rivRank.posicio);
      if (!allowed) {
        throw new Error('No pots reptar aquest jugador: només pots reptar fins a 2 posicions per sobre teu.');
      }

      // Validació final de reptes actius (concurrent safety)
      const { data: actMe, error: eActMe } = await supabase
        .from('challenges')
        .select('id')
        .eq('event_id', eventActiuId)
        .or(`reptador_id.eq.${jo.player_id},reptat_id.eq.${jo.player_id}`)
        .in('estat', ACTIVE_STATES as any);
      if (eActMe) throw eActMe;
      if ((actMe ?? []).length > 0) throw new Error('Ja tens un repte actiu.');

      const { data: actRiv, error: eActR } = await supabase
        .from('challenges')
        .select('id')
        .eq('event_id', eventActiuId)
        .or(`reptador_id.eq.${reptat_id},reptat_id.eq.${reptat_id}`)
        .in('estat', ACTIVE_STATES as any);
      if (eActR) throw eActR;
      if ((actRiv ?? []).length > 0) throw new Error('El rival té un altre repte actiu.');

      // Inserció
      busy = true;

      const payload = {
        event_id: eventActiuId,
        tipus,
        reptador_id: jo.player_id,
        reptat_id,
        estat: 'proposat',
        dates_proposades: dates,               // timestamptz[]
        data_proposta: new Date().toISOString(),
        data_acceptacio: null,
        pos_reptador: jo.posicio,
        pos_reptat: rivRank.posicio
      };

      const { error: eIns } = await supabase.from('challenges').insert(payload);
      if (eIns) throw eIns;

      okMsg = 'Repte creat! El rival rebrà les 3 dates i podrà acceptar, refusar o fer contraproposta.';
      // reset formulari
      reptat_id = null; d1 = d2 = d3 = ''; tipus = 'normal';
    } catch (e: any) {
      error = e?.message ?? 'No s’ha pogut crear el repte';
    } finally {
      busy = false;
    }
  }
</script>

<svelte:head>
  <title>Nou repte</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Crear un nou repte</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else}
  {#if error}
    <div class="mb-3 rounded border border-red-300 bg-red-50 p-3 text-red-700">{error}</div>
  {/if}
  {#if okMsg}
    <div class="mb-3 rounded border border-green-300 bg-green-50 p-3 text-green-700">{okMsg}</div>
  {/if}

  {#if jo}
    <form class="space-y-4 max-w-xl" on:submit={createChallenge}>
      <div class="grid sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-sm mb-1">Event actiu</label>
          <input class="w-full rounded border px-3 py-2 bg-slate-50" value={eventActiuId} disabled />
        </div>

        <div>
          <label class="block text-sm mb-1">Tipus</label>
          <select class="w-full rounded border px-3 py-2" bind:value={tipus}>
            <option value="normal">Normal</option>
            <option value="access">Accés</option>
          </select>
        </div>
      </div>

      <div class="grid sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-sm mb-1">Reptador</label>
          <input class="w-full rounded border px-3 py-2 bg-slate-50" value={`#${jo.posicio} — ${jo.nom}`} disabled />
        </div>

        <div>
          <label class="block text-sm mb-1">Jugador reptat</label>
          <select class="w-full rounded border px-3 py-2" bind:value={reptat_id} required>
            <option value="" disabled selected>— Selecciona —</option>
            {#each rivals as r}
              <option value={r.player_id}>
                #{r.posicio} — {r.nom}
              </option>
            {/each}
          </select>
          {#if !rivals.length}
            <p class="text-xs text-amber-700 mt-1">
              No tens rivals disponibles (potser tens un repte actiu o no hi ha posicions -1/-2 lliures).
            </p>
          {/if}
        </div>
      </div>

      <fieldset class="border rounded p-3">
        <legend class="text-sm px-1">Dates proposades (obligatori: 3)</legend>
        <div class="grid sm:grid-cols-3 gap-2">
          <div>
            <label for="d1" class="block text-sm mb-1">Data 1</label>
            <input id="d1" type="datetime-local" class="w-full rounded border px-2 py-1" bind:value={d1} required />
          </div>
          <div>
            <label for="d2" class="block text-sm mb-1">Data 2</label>
            <input id="d2" type="datetime-local" class="w-full rounded border px-2 py-1" bind:value={d2} required />
          </div>
          <div>
            <label for="d3" class="block text-sm mb-1">Data 3</label>
            <input id="d3" type="datetime-local" class="w-full rounded border px-2 py-1" bind:value={d3} required />
          </div>
        </div>
        <p class="text-xs text-slate-500 mt-2">La normativa exigeix proposar 3 dates alternatives.</p>
      </fieldset>

      <div class="flex gap-2">
        <button class="rounded bg-slate-900 text-white px-4 py-2 disabled:opacity-60" disabled={busy || !rivals.length} type="submit">
          {busy ? 'Creant…' : 'Crear repte'}
        </button>
        <a class="rounded border px-4 py-2" href="/reptes">Cancel·lar</a>
      </div>
    </form>
  {/if}
{/if}
