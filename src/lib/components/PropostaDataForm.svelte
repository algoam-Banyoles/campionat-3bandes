<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import Banner from '$lib/components/Banner.svelte';

  import { authFetch } from '$lib/utils/http';


  export let challengeId: string;
  export let reptadorId: string | null = null;
  export let reptatId: string | null = null;

  let dataLocal = '';
  let submitting = false;
  let err: string | null = null;
  let ok: string | null = null;

  async function ensureChallengeParties() {
    // Si no han arribat per props, els busquem
    if (reptadorId && reptatId) return;
    const res = await authFetch(`/reptes/detall/${challengeId}`); // adapta si tens un altre endpoint
    const j = await res.json();
    if (res.ok) {
      reptadorId = j.reptador_id;
      reptatId  = j.reptat_id;
    }
  }

  function toIso(local: string): string | null {
    if (!local) return null;
    const s = local.replace(' ', 'T');
    const d = new Date(s);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  // Permís al CLIENT: mostrar només si logat i és reptador/reptat
  let canShow = false;
  async function computeCanShow() {
    err = null; ok = null;
    const { data: auth } = await supabase.auth.getUser();
    const email = auth?.user?.email ?? null;
    if (!email) { canShow = false; return; }

    // trobem el player_id d'aquest email
    const { data: me, error } = await supabase
      .from('players')
      .select('id')
      .eq('email', email)
      .maybeSingle();
    if (error || !me?.id) { canShow = false; return; }

    await ensureChallengeParties();
    canShow = isParticipant(me.id ?? null, {
      reptador_id: reptadorId,
      reptat_id: reptatId
    });
  }

  $: computeCanShow(); // re-calcula si canvien props

  async function proposa() {
    err = null; ok = null;
    const iso = toIso(dataLocal);
    if (!iso) { err = 'Introdueix una data/hora vàlida futura.'; return; }

    submitting = true;
    try {
      const res = await authFetch('/reptes/proposa-data', {
        method: 'POST',
        body: JSON.stringify({ challenge_id: challengeId, data_programada: iso })
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok || body?.ok === false) {
        throw new Error(body?.error || 'No s’ha pogut proposar la data');
      }
      ok = 'Data proposada/reprogramada correctament';
    } catch (e: any) {
      err = e?.message || 'Error en proposar data';
    } finally {
      submitting = false;
    }
  }
</script>

{#if canShow}
  {#if err}<Banner type="error" class="mb-2" message={err} />{/if}
  {#if ok}<Banner type="success" class="mb-2" message={ok} />{/if}

  <div class="flex gap-2 items-center">
    <input
      type="datetime-local"
      step="60"
      class="rounded-xl border px-3 py-2"
      bind:value={dataLocal}
      aria-label="Proposa data"
    />
    <button
      class="rounded-2xl border px-3 py-2"
      on:click|preventDefault={proposa}
      disabled={submitting || !dataLocal}>
      {submitting ? 'Enviant…' : 'Proposa data'}
    </button>
  </div>
{/if}
