<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { isAdmin } from '$lib/isAdmin';

  let email: string | null = null;
  let admin = false;
  let ready = false;
  let err: string | null = null;

  onMount(async () => {
    try {
      const { data, error } = await supabase.auth.getSession();
      if (error) throw error;
      email = data.session?.user?.email ?? null;

      // comprova admin amb la RLS de la taula public.admins
      admin = await isAdmin();
    } catch (e: any) {
      err = e?.message ?? 'Error desconegut';
    } finally {
      ready = true;
    }
  });
</script>

<svelte:head><title>Admin · Check</title></svelte:head>

<h1 class="text-xl font-semibold mb-3">Admin · Check</h1>

{#if !ready}
  <div class="rounded border p-3 text-slate-600">Comprovant…</div>
{:else}
  {#if err}
    <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{err}</div>
  {/if}
  <div class="rounded border p-3">
    <div><strong>Usuari:</strong> {email ?? '—'}</div>
    <div><strong>És admin?</strong> {admin ? 'sí' : 'no'}</div>
  </div>
{/if}
