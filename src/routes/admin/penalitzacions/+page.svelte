<script lang="ts">
    import { onMount } from 'svelte';
    import { user } from '$lib/authStore';
    import { isAdmin as checkAdmin } from '$lib/isAdmin';
    import Banner from '$lib/components/Banner.svelte';
    import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';

  type Event = { id: string; nom: string };
  type Player = { id: string; nom: string };

  let loading = true;
  let unauthorized = false;
  let error: string | null = null;
  let okMsg: string | null = null;
  let busy = false;

  let events: Event[] = [];
  let players: Player[] = [];
  let event_id = '';
  let player_id = '';
  let tipus: string = 'incompareixenca';
  let detalls = '';

  onMount(async () => {
    const u = $user;
    if (!u?.email) {
      unauthorized = true;
      loading = false;
      return;
    }
    const adm = await checkAdmin();
    if (!adm) {
      unauthorized = true;
      loading = false;
      return;
    }
    try {
      const { supabase } = await import('$lib/supabaseClient');
      const { data: ev, error: eEv } = await supabase
        .from('events')
        .select('id, nom')
        .eq('actiu', true)
        .order('creat_el', { ascending: false });
      if (eEv) throw eEv;
      events = ev ?? [];
      if (events.length > 0) event_id = events[0].id;

      const { data: pl, error: ePl } = await supabase
        .from('players')
        .select('id, nom')
        .order('nom', { ascending: true });
      if (ePl) throw ePl;
      players = pl ?? [];
      if (players.length > 0) player_id = players[0].id;
      } catch (e) {
        error = formatSupabaseError(e);
      } finally {
      loading = false;
    }
  });

  async function save() {
    try {
      busy = true;
      error = null;
      okMsg = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { data } = await supabase.auth.getSession();
      const token = data?.session?.access_token;
      const res = await fetch('/reptes/penalitzacions', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer ' + token
        },
        body: JSON.stringify({ event_id, player_id, tipus, detalls: detalls || null })
      });
      const js = await res.json();
      if (!res.ok) throw new Error(js.error || 'Error creant penalització');
        okMsg = okText('Penalització creada');
      tipus = 'incompareixenca';
      detalls = '';
      } catch (e) {
        error = formatSupabaseError(e);
      } finally {
      busy = false;
    }
  }
</script>

<svelte:head>
  <title>Admin · Penalitzacions</title>
</svelte:head>

<div class="max-w-2xl mx-auto">
  <h1 class="text-2xl font-semibold mb-4">Penalitzacions</h1>

    {#if unauthorized}
      <Banner type="error" message="No autoritzat" />
    {:else if loading}
      <p class="text-slate-500">Carregant…</p>
    {:else}
      {#if error}
        <Banner type="error" message={error} class="mb-4" />
      {/if}
      {#if okMsg}
        <Banner type="success" message={okMsg} class="mb-4" />
      {/if}

    <div class="rounded-2xl border bg-white p-6 shadow-sm">
      <form class="space-y-4" on:submit|preventDefault={save}>
        <div>
          <label class="block mb-1 text-sm">Event</label>
          <select bind:value={event_id} class="w-full rounded-xl border px-3 py-2">
            {#each events as e}
              <option value={e.id}>{e.nom}</option>
            {/each}
          </select>
        </div>

        <div>
          <label class="block mb-1 text-sm">Jugador</label>
          <select bind:value={player_id} class="w-full rounded-xl border px-3 py-2">
            {#each players as p}
              <option value={p.id}>{p.nom}</option>
            {/each}
          </select>
        </div>

        <div>
          <label class="block mb-1 text-sm">Tipus</label>
          <select bind:value={tipus} class="w-full rounded-xl border px-3 py-2">
            <option value="incompareixenca">incompareixenca</option>
            <option value="no_acord_dates">no_acord_dates</option>
            <option value="altres">altres</option>
          </select>
        </div>

        <div>
          <label class="block mb-1 text-sm">Detalls (opcional)</label>
          <textarea bind:value={detalls} class="w-full rounded-xl border px-3 py-2" rows="3"></textarea>
        </div>

        <button
          type="submit"
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          disabled={busy}
        >
          {#if busy}Desant…{:else}Desa{/if}
        </button>
      </form>
    </div>
  {/if}
</div>

