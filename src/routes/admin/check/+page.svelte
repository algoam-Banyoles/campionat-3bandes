<script lang="ts">
  import { onMount } from 'svelte';
  import { user, loadingAuth } from '$lib/authStore';
  import { isAdmin } from '$lib/isAdmin';

  let admin = false;
  let ready = false;

  onMount(async () => {
    // espera auth
    while ($loadingAuth) {
      await new Promise(r => setTimeout(r, 50));
    }
    admin = await isAdmin();
    ready = true;
  });
</script>

<h1 class="text-xl font-semibold mb-3">Admin · Check</h1>

{#if !ready}
  <div class="rounded border p-3 text-slate-600">Comprovant…</div>
{:else}
  <div class="rounded border p-3">
    <div><strong>Usuari:</strong> {$user?.email ?? '—'}</div>
    <div><strong>És admin?</strong> {admin ? 'sí' : 'no'}</div>
  </div>
{/if}

