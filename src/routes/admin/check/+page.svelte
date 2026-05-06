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

<div class="ck-root">
  <header class="ck-mast">
    <div class="editorial-eyebrow">Eines · Comprovació</div>
    <h1 class="ck-title">Estat de sessió i admin</h1>
  </header>

  {#if !ready}
    <div class="ck-card">Comprovant…</div>
  {:else}
    {#if err}
      <Banner type="error" message={err} class="mb-3" />
    {/if}
    <div class="ck-card">
      <div><strong>Usuari:</strong> {email ?? '—'}</div>
      <div><strong>És admin?</strong> {admin ? 'sí' : 'no'}</div>
    </div>
  {/if}
</div>

<style>
  .ck-root {
    max-width: 760px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .ck-mast {
    margin-bottom: 1.25rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .ck-title {
    margin: 0.4rem 0 0;
    font-size: 1.5rem;
    font-weight: 800;
    letter-spacing: -0.018em;
  }
  .ck-card {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 1rem 1.1rem;
    color: var(--ink-2, #4a443e);
    font-size: 0.9375rem;
    line-height: 1.5;
  }
  .ck-card strong { color: var(--ink, #1a1814); }
</style>
