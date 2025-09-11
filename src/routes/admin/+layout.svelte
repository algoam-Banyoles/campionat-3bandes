<script lang="ts">
  import { onMount } from 'svelte';
    import { supabase } from '$lib/supabaseClient';
    import { checkIsAdmin } from '$lib/roles';
  import Banner from '$lib/components/Banner.svelte';

  let ready = false;
  let admin = false;
  let email: string | null = null;

  onMount(async () => {
    const { data } = await supabase.auth.getSession();
    email = data.session?.user?.email ?? null;
      admin = await checkIsAdmin(); // consulta amb RLS
    ready = true;
  });
</script>

{#if !ready}
  <div class="rounded border p-3">Comprovant permisos…</div>
{:else if !admin}
  <Banner
    type="error"
    message={email ? `No autoritzat. Sessió: ${email}` : 'No autoritzat. No hi ha sessió activa.'}
  />
  <div class="mt-2 text-sm"><a href="/login" class="underline">Inicia sessió</a></div>
{:else}
  <slot />
{/if}
