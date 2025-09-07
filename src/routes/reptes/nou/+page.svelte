<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/authStore';

  type Player = { id: string; nom: string; email: string | null; posicio?: number | null };

  let loading = true;
  let error: string | null = null;
  let okMsg: string | null = null;

  let me: Player | null = null;          // jugador logat (a partir del seu email)
  let rivals: Player[] = [];              // rivals possibles (ex. tots, o filtrats segons normativa)
  let reptat_id: string | null = null;    // selecció de rival
  let tipus: 'normal' | 'access' = 'normal';

  // Dates proposades (màxim 3)
  let d1: string = '';
  let d2: string = '';
  let d3: string = '';

  let busy = false;

  onMount(async () => {
    try {
      okMsg = null; error = null; loading = true;

      const u = $user;
      if (!u?.email) {
        error = 'Has d’iniciar sessió per crear un repte.';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      // 1) El meu jugador (per email)
      const { data: p, error: e1 } = await supabase
        .from('players')
        .select('id,nom,email,posicio')
        .eq('email', u.email)
        .maybeSingle();
      if (e1) throw e1;
      if (!p) {
        error = 'El teu correu no està vinculat a cap jugador.';
        return;
      }
      me = p;

      // 2) Llista de rivals (exemple: tots menys jo; si vols filtrar posicions, ho fem després)
      const { data: all, error: e2 } = await supabase
        .from('players')
        .select('id,nom,email,posicio')
        .neq('id', p.id)
        .order('posicio', { ascending: true });
      if (e2) throw e2;

      rivals = all ?? [];
    } catch (e: any) {
      error = e?.message ?? 'Error carregant el formulari';
    } finally {
      loading = false;
    }
  });

  function toISO(dtLocal: string): string | null {
    if (!dtLocal) return null;
    const d = new Date(dtLocal);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  async function createChallenge(e: Event) {
    e.preventDefault();
    okMsg = null; error = null;

    try {
      if (!me) throw new Error('Sessió no preparada.');
      if (!reptat_id) throw new Error('Has de seleccionar el jugador reptat.');

      // almenys una data proposada
      const dates = [toISO(d1), toISO(d2), toISO(d3)].filter(Boolean) as string[];
      if (dates.length === 0) throw new Error('Cal proposar almenys una data (pots posar-ne fins a 3).');

      busy = true;
      const { supabase } = await import('$lib/supabaseClient');

      // Inserció a la taula "challenges"
      const payload = {
        event_id: null,                 // si tens un event/temporada activa, posa-hi el seu id
        tipus,                          // 'normal' | 'access'
        reptador_id: me.id,             // jo
        reptat_id,                      // rival seleccionat
        estat: 'proposat',              // d’entrada, proposat
        dates_proposades: dates,        // fins a 3 dates
        data_proposta: new Date().toISOString(),
        data_acceptacio: null,
        pos_reptador: me.posicio ?? null,
        pos_reptat: (rivals.find(r => r.id === reptat_id)?.posicio ?? null)
      };

      const { error: eIns } = await supabase.from('challenges').insert(payload);
      if (eIns) throw eIns;

      okMsg = 'Repte creat! El rival rebrà les dates i podrà acceptar, refusar o fer contraproposta.';
      // neteja formulari
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

  {#if me}
    <form class="space-y-4 max-w-xl" on:submit={createChallenge}>
      <div>
        <label class="block text-sm mb-1">Reptador</label>
        <input class="w-full rounded border px-3 py-2 bg-slate-50" value={`${me.nom} (${me.email ?? ''})`} disabled />
      </div>

      <div>
        <label class="block text-sm mb-1">Tipus</label>
        <select class="w-full rounded border px-3 py-2" bind:value={tipus}>
          <option value="normal">Normal</option>
          <option value="access">Accés</option>
        </select>
      </div>

      <div>
        <label class="block text-sm mb-1">Jugador reptat</label>
        <select class="w-full rounded border px-3 py-2" bind:value={reptat_id} required>
          <option value="" disabled selected>— Selecciona —</option>
          {#each rivals as r}
            <option value={r.id}>
              #{r.posicio ?? '—'} — {r.nom}
            </option>
          {/each}
        </select>
      </div>

      <fieldset class="border rounded p-3">
        <legend class="text-sm px-1">Dates proposades (mínim 1, màxim 3)</legend>
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
        <p class="text-xs text-slate-500 mt-2">Recomanat: proposar tres alternatives (p.ex. franges de 90 min).</p>
      </fieldset>

      <div class="flex gap-2">
        <button class="rounded bg-slate-900 text-white px-4 py-2 disabled:opacity-60" disabled={busy} type="submit">
          {busy ? 'Creant…' : 'Crear repte'}
        </button>
        <a class="rounded border px-4 py-2" href="/reptes/me">Cancel·lar</a>
      </div>
    </form>
  {/if}
{/if}
