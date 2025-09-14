<script lang="ts">
  import { user } from '$lib/authStore';
  import { invalidate } from '$app/navigation';

  let loading = false;
  let error: string | null = null;
  let ok: string | null = null;

  async function inscriure() {
    try {
      loading = true;
      error = null;
      ok = null;
      const u = $user;
      if (!u?.email) {
        error = 'Has d\u2019iniciar sessi\u00f3.';
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
        ok = `Inscrit a la llista d\u2019espera (ordre ${r.ordre})`;
      } else {
        ok = `Inscrit al r\u00e0nquing (posici\u00f3 ${r.posicio})`;
      }
      await Promise.all([
        invalidate('/classificacio'),
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
  <title>Inscripci\u00f3</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Inscripci\u00f3</h1>

{#if $user}
  <button
    class="rounded bg-slate-800 px-4 py-2 text-white disabled:opacity-50"
    disabled={loading}
    on:click={inscriure}
  >
    {loading ? 'Processant…' : 'Inscriu-me'}
  </button>
  {#if error}
    <div class="mt-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">{error}</div>
  {/if}
  {#if ok}
    <div class="mt-4 rounded border border-green-200 bg-green-50 p-3 text-green-700">{ok}</div>
  {/if}
{:else}
  <p>Cal iniciar sessi\u00f3 per inscriure's.</p>
{/if}
