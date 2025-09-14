<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import Banner from '$lib/components/Banner.svelte';

  type Row = {
    ordre: number;
    nom: string;
    data_inscripcio: string;
    player_id: string;
  };

  const fmtDate = (iso: string | null): string => {
    if (!iso) return '—';
    const d = new Date(iso);
    return isNaN(d.getTime()) ? '—' : d.toLocaleDateString();
  };

  let loading = true;
  let error: string | null = null;
  let rows: Row[] = [];
  let myPlayerId: string | null = null;
  let player20: { id: string; nom: string } | null = null;
  let countdown = '';
  let timer: ReturnType<typeof setInterval> | null = null;

  onMount(async () => {
    try {
      const { supabase } = await import('$lib/supabaseClient');

      // Usuari actual
      const { data: auth } = await supabase.auth.getUser();
      if (auth?.user?.email) {
        const { data: p } = await supabase
          .from('players')
          .select('id')
          .eq('email', auth.user.email)
          .maybeSingle();
        myPlayerId = (p as any)?.id ?? null;
      }

      // Event actiu
      const { data: ev } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .order('creat_el', { ascending: false })
        .limit(1)
        .maybeSingle();
      const eventId = (ev as any)?.id as string | null;

      // Llista d'espera
      const { data, error: err } = await supabase.rpc('get_waiting_list');
      if (err) error = err.message;
      else rows = (data ?? []) as Row[];
      rows.sort((a, b) => a.ordre - b.ordre);

      // Opponent: jugador #20
      if (eventId) {
        const { data: pos20 } = await supabase
          .from('ranking_positions')
          .select('player_id, players!inner(nom)')
          .eq('event_id', eventId)
          .eq('posicio', 20)
          .maybeSingle();
        if (pos20) {
          player20 = {
            id: (pos20 as any).player_id,
            nom: (pos20 as any).players.nom ?? ''
          };
        }
      }

      const first = rows[0];
      if (first && myPlayerId === first.player_id) {
        const deadline =
          new Date(first.data_inscripcio).getTime() + 15 * 24 * 60 * 60 * 1000;
        const update = () => {
          const diff = deadline - Date.now();
          if (diff <= 0) {
            countdown = 'Temps exhaurit';
            if (timer) clearInterval(timer);
          } else {
            const d = Math.floor(diff / (24 * 60 * 60 * 1000));
            const h = Math.floor((diff % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
            countdown = `${d}d ${h}h`;
          }
        };
        update();
        timer = setInterval(update, 60 * 1000);
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });

  onDestroy(() => {
    if (timer) clearInterval(timer);
  });

  function reptar() {
    if (player20) goto(`/reptes/nou?access=1&opponent=${player20.id}`);
  }
</script>

<svelte:head>
  <title>Llista d’espera</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Llista d’espera</h1>

{#if rows.length && myPlayerId === rows[0].player_id}
  <Banner
    type="info"
    message={`Tens ${countdown} per reptar la posició 20${player20 ? ` — ${player20.nom}` : ''}`}
    class="mb-3"
  />
  {#if player20}
    <button
      class="mb-4 rounded-2xl border px-3 py-1 text-sm"
      on:click={reptar}
    >
      Reptar posició 20
    </button>
  {/if}
{/if}

{#if loading}
  <p class="text-slate-500">Carregant llista d’espera…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-300 bg-red-50 p-3 text-red-800">{error}</div>
{:else if rows.length === 0}
  <p class="text-slate-500">No hi ha ningú en llista d’espera.</p>
{:else}
  <div class="overflow-x-auto rounded-lg border border-slate-200">
    <table class="min-w-full text-sm">
      <thead class="bg-slate-50">
        <tr>
          <th class="px-3 py-2 text-left font-semibold">Ordre</th>
          <th class="px-3 py-2 text-left font-semibold">Nom</th>
          <th class="px-3 py-2 text-left font-semibold">Data inscripció</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t">
            <td class="px-3 py-2">{r.ordre}</td>
            <td class="px-3 py-2">{r.nom}</td>
            <td class="px-3 py-2">{fmtDate(r.data_inscripcio)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}
