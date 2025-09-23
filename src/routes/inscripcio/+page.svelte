<script lang="ts">
  import { user, adminStore } from '$lib/stores/auth';
  import { invalidate } from '$app/navigation';
  import { onMount } from 'svelte';

  let loading = false;
  let error: string | null = null;
  let ok: string | null = null;
  let checking = true;
  let preError: string | null = null;
  let inRanking = false;
  let inWaiting = false;

  // Per a la inscripció de socis (Junta)
  let socis: Array<{ id: string; nom: string; email: string }> = [];
  let selectedSoci: string | null = null;
  let mitjana: number | null = null;

  onMount(async () => {
    // Carrega socis si admin
    if ($adminStore) {
      const { supabase } = await import('$lib/supabaseClient');

      // Obtenir event actiu
      const { data: event, error: eventError } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();

      if (eventError) {
        error = eventError.message;
      } else if (event) {
        // Obtenir jugadors ja inscrits
        const { data: rankingPlayers } = await supabase
          .from('ranking_positions')
          .select('player_id')
          .eq('event_id', event.id);

        const { data: waitingPlayers } = await supabase
          .from('waiting_list')
          .select('player_id')
          .eq('event_id', event.id);

        const inscritIds = new Set([
          ...(rankingPlayers?.map(r => r.player_id) || []),
          ...(waitingPlayers?.map(w => w.player_id) || [])
        ]);

        // Obtenir tots els socis i filtrar els no inscrits
        const { data: allPlayers, error: playersError } = await supabase
          .from('socis')
          .select('id, nom, cognoms, email')
          .eq('de_baixa', false)
          .order('nom');

        if (playersError) {
          error = playersError.message;
        } else {
          socis = (allPlayers || []).filter(player => !inscritIds.has(player.id));
        }
      }
    }
    try {
      const u = $user;
      if (!u?.email) return;
      const { supabase } = await import('$lib/supabaseClient');
      const { data: ev, error: eEv } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();
      if (eEv) throw eEv;
      const eventId = ev?.id;
      if (!eventId) return;
      const { data: pl, error: ePl } = await supabase
        .from('socis')
        .select('id')
        .eq('email', u.email)
        .maybeSingle();
      if (ePl) throw ePl;
      if (!pl) return;
      const { data: rp, error: eRp } = await supabase
        .from('ranking_positions')
        .select('posicio')
        .eq('event_id', eventId)
        .eq('player_id', pl.id)
        .maybeSingle();
      if (eRp) throw eRp;
      if (rp) {
        inRanking = true;
        return;
      }
      const { data: wl, error: eWl } = await supabase
        .from('waiting_list')
        .select('ordre')
        .eq('event_id', eventId)
        .eq('player_id', pl.id)
        .maybeSingle();
      if (eWl) throw eWl;
      if (wl) inWaiting = true;
    } catch (e: any) {
      preError = e?.message ?? 'Error desconegut';
    } finally {
      checking = false;
    }
  });

  async function inscriure() {
    try {
      loading = true;
      error = null;
      ok = null;
      const u = $user;
      if (!u?.email) {
        error = 'Has d\'iniciar sessio.';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      // Obtenir event actiu
      const { data: ev, error: eEv } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();
      if (eEv) throw eEv;
      const eventId = ev?.id;
      if (!eventId) {
        error = 'No hi ha cap campionat actiu.';
        return;
      }

      let playerId: string;
      let playerName: string;

      if ($adminStore && selectedSoci) {
        // Mode admin: inscriure el jugador seleccionat
        const selectedPlayer = socis.find(s => s.id === selectedSoci);
        if (!selectedPlayer) {
          error = 'Jugador no trobat.';
          return;
        }

        playerId = selectedPlayer.id;
        playerName = selectedPlayer.nom;
      } else {
        // Mode usuari normal: inscriure's a si mateix
        const { data: pl, error: ePl } = await supabase
          .from('socis')
          .select('id, nom')
          .eq('email', u.email)
          .maybeSingle();
        if (ePl) throw ePl;
        if (!pl) {
          error = 'Email sense jugador associat.';
          return;
        }
        playerId = pl.id;
        playerName = pl.nom;
      }

      // Inscriure el jugador directament
      // Comprovar si ja està inscrit
      const { data: existingRanking } = await supabase
        .from('ranking_positions')
        .select('posicio')
        .eq('event_id', eventId)
        .eq('player_id', playerId)
        .maybeSingle();

      if (existingRanking) {
        error = `${playerName} ja està inscrit al rànquing (posició ${existingRanking.posicio})`;
        return;
      }

      const { data: existingWaiting } = await supabase
        .from('waiting_list')
        .select('ordre')
        .eq('event_id', eventId)
        .eq('player_id', playerId)
        .maybeSingle();

      if (existingWaiting) {
        error = `${playerName} ja està en llista d'espera (ordre ${existingWaiting.ordre})`;
        return;
      }

      // Comptar posicions ocupades al rànquing
      const { count: rankingCount } = await supabase
        .from('ranking_positions')
        .select('*', { count: 'exact', head: true })
        .eq('event_id', eventId);

      if ((rankingCount || 0) < 20) {
        // Hi ha espai al rànquing - trobar primera posició lliure
        const { data: occupiedPositions } = await supabase
          .from('ranking_positions')
          .select('posicio')
          .eq('event_id', eventId)
          .order('posicio');

        let posicioLliure = 1;
        const ocupades = (occupiedPositions || []).map(p => p.posicio).sort((a, b) => a - b);

        for (let i = 1; i <= 20; i++) {
          if (!ocupades.includes(i)) {
            posicioLliure = i;
            break;
          }
        }

        // Inserir al rànquing
        const { error: insertError } = await supabase
          .from('ranking_positions')
          .insert({
            event_id: eventId,
            player_id: playerId,
            posicio: posicioLliure,
            assignat_el: new Date().toISOString()
          });

        if (insertError) throw insertError;

        ok = `${playerName} inscrit al rànquing (posició ${posicioLliure})`;
        if (!$adminStore) inRanking = true;
      } else {
        // Rànquing ple - afegir a llista d'espera
        const { count: waitingCount } = await supabase
          .from('waiting_list')
          .select('*', { count: 'exact', head: true })
          .eq('event_id', eventId);

        const nouOrdre = (waitingCount || 0) + 1;

        const { error: insertError } = await supabase
          .from('waiting_list')
          .insert({
            event_id: eventId,
            player_id: playerId,
            ordre: nouOrdre,
            data_inscripcio: new Date().toISOString()
          });

        if (insertError) throw insertError;

        ok = `${playerName} inscrit a la llista d'espera (ordre ${nouOrdre})`;
        if (!$adminStore) inWaiting = true;
      }

      // Netejar formulari admin i actualitzar llista
      if ($adminStore) {
        selectedSoci = null;
        mitjana = null;
        // Eliminar el jugador inscrit de la llista de socis disponibles
        socis = socis.filter(s => s.id !== playerId);
      }

      await Promise.all([
        invalidate('/ranking'),
        invalidate('/llista-espera')
      ]);
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Inscripció</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Inscripció</h1>

{#if $user}
  {#if checking}
    <p class="text-slate-500">Comprovant inscripció…</p>
  {:else if preError}
    <div class="rounded border border-red-200 bg-red-50 p-3 text-red-700">{preError}</div>
  {:else}
    <!-- Estat actual de l'usuari -->
    {#if inRanking}
      <div class="mb-4 rounded border border-green-200 bg-green-50 p-3 text-green-700">
        ✅ Ja estàs inscrit al rànquing.
      </div>
    {:else if inWaiting}
      <div class="mb-4 rounded border border-blue-200 bg-blue-50 p-3 text-blue-700">
        ⏳ Ja estàs a la llista d'espera.
      </div>
    {/if}
    {#if $adminStore}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
        <h2 class="text-lg font-semibold text-blue-800 mb-3">Mode Administrador</h2>
        <p class="text-blue-700 text-sm mb-4">Pots inscriure qualsevol soci al campionat.</p>

        <form on:submit|preventDefault={inscriure} class="space-y-4">
          <div>
            <label for="soci" class="block text-sm font-medium text-gray-700 mb-1">
              Selecciona el soci a inscriure:
            </label>
            <select
              id="soci"
              bind:value={selectedSoci}
              required
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">-- Selecciona un jugador --</option>
              {#each socis as soci}
                <option value={soci.id}>
                  {soci.nom} ({soci.email})
                </option>
              {/each}
            </select>
          </div>

          <div>
            <label for="mitjana" class="block text-sm font-medium text-gray-700 mb-1">
              Mitjana inicial (opcional):
            </label>
            <input
              id="mitjana"
              type="number"
              step="0.01"
              bind:value={mitjana}
              min="0"
              placeholder="Ex: 1.25"
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">
              Si no s'especifica, el jugador s'assignarà a la primera posició lliure
            </p>
          </div>

          <button
            type="submit"
            class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            disabled={loading || !selectedSoci}
          >
            {loading ? 'Processant…' : 'Inscriure soci al campionat'}
          </button>
        </form>
      </div>

      {#if !inRanking && !inWaiting}
        <div class="border-t pt-4">
          <h3 class="text-md font-medium text-gray-700 mb-2">O pots inscriure't tu mateix:</h3>
          <button
            class="rounded bg-slate-800 px-4 py-2 text-white disabled:opacity-50 hover:bg-slate-700 transition-colors"
            disabled={loading}
            on:click={inscriure}
          >
            {loading ? 'Processant…' : 'Inscriu-me a mi'}
          </button>
        </div>
      {/if}
    {:else if !inRanking && !inWaiting}
      <button
        class="rounded bg-slate-800 px-4 py-2 text-white disabled:opacity-50"
        disabled={loading}
        on:click={inscriure}
      >
        {loading ? 'Processant…' : 'Inscriu-me'}
      </button>
    {/if}
  {/if}
  {#if error}
    <div class="mt-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">{error}</div>
  {/if}
  {#if ok}
    <div class="mt-4 rounded border border-green-200 bg-green-50 p-3 text-green-700">{ok}</div>
  {/if}
{:else}
  <p>Cal iniciar sessió per inscriure's.</p>
{/if}

