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
  let socis: Array<{ numero_soci: number; cognoms: string; nom: string; email: string }> = [];
  let selectedSoci: number | null = null;
  let mitjana: number | null = null;

  onMount(async () => {
    // Carrega socis si admin
    if ($adminStore) {
      const { supabase } = await import('$lib/supabaseClient');
      const { data, error: err } = await supabase.from('socis').select('*');
      if (err) error = err.message;
      else socis = data ?? [];
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
        .from('players')
        .select('id')
        .eq('email', u.email)
        .maybeSingle();
      if (ePl) throw ePl;
      if (!pl) return;
      const { data: rp, error: eRp } = await supabase
        .from('ranking_positions')
        .select('id')
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
        .select('id')
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
        error = 'Has d’iniciar sessió.';
        return;
      }
      const { supabase } = await import('$lib/supabaseClient');
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
      const { data: pl, error: ePl } = await supabase
        .from('players')
        .select('id')
        .eq('email', u.email)
        .maybeSingle();
      if (ePl) throw ePl;
      if (!pl) {
        error = 'Email sense jugador associat.';
        return;
      }
      const { data: res, error: eRpc } = await supabase.rpc('register_player', {
        p_event: eventId,
        p_player: pl.id
      });
      if (eRpc) throw eRpc;
      const r: any = res;
      if (!r?.ok) {
        error = r?.error || 'Error desconegut';
        return;
      }
      if (r.waiting) {
        ok = `Inscrit a la llista d’espera (ordre ${r.ordre})`;
        inWaiting = true;
      } else {
        ok = `Inscrit al rànquing (posició ${r.posicio})`;
        inRanking = true;
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
  {:else if inRanking}
    <p>Ja estàs inscrit al rànquing.</p>
  {:else if inWaiting}
    <p>Ja estàs a la llista d'espera.</p>
  {:else}
    {#if $adminStore}
      <form on:submit|preventDefault={inscriure} class="space-y-4">
        <label for="soci">Selecciona el soci:</label>
        <select id="soci" bind:value={selectedSoci} required>
          <option value="">-- Selecciona --</option>
          {#each socis as soci}
            <option value={soci.numero_soci}>{soci.nom} {soci.cognoms} ({soci.email})</option>
          {/each}
        </select>
        <label for="mitjana">Mitjana inicial (opcional):</label>
        <input id="mitjana" type="number" step="0.01" bind:value={mitjana} min="0" />
        <button type="submit" class="mt-2 px-4 py-2 bg-blue-600 text-white rounded" disabled={loading}>
          {loading ? 'Processant…' : 'Inscriure'}
        </button>
      </form>
    {:else}
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

