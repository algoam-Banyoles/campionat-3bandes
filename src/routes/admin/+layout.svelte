<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { isAdmin } from '$lib/isAdmin';

  let ready = false;
  let admin = false;
  let email: string | null = null;

  onMount(async () => {
    const { data } = await supabase.auth.getSession();
    email = data.session?.user?.email ?? null;
    admin = await isAdmin();  // consulta amb RLS
    ready = true;
  });
</script>

{#if !ready}
  <div class="rounded border p-3">Comprovant permisos…</div>
{:else if !admin}
  <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3">
    No autoritzat. {email ? `Sessió: ${email}` : 'No hi ha sessió activa.'}
    <div class="mt-2 text-sm"><a href="/login" class="underline">Inicia sessió</a></div>
  </div>
{:else}
  <slot />
{/if}
