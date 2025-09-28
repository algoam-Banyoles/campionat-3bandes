<script lang="ts">
  import { onMount } from 'svelte';
    import { supabase } from '$lib/supabaseClient';
    import { checkIsAdmin } from '$lib/roles';
  import Banner from '$lib/components/general/Banner.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';

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
          admin = await checkIsAdmin();
      } catch (e) {
        err = formatSupabaseError(e);
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
      <Banner type="error" message={err} class="mb-3" />
    {/if}
  <div class="rounded border p-3">
    <div><strong>Usuari:</strong> {email ?? '—'}</div>
    <div><strong>És admin?</strong> {admin ? 'sí' : 'no'}</div>
  </div>
{/if}
