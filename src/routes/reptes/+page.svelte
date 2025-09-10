<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/authStore';

  onMount(async () => {
    try {
      await fetch('/reptes/penalitzacions', { method: 'POST' });
    } catch {
      // ignore errors applying penalties
    }
  });
  
</script>

<h1 class="text-2xl font-semibold mb-4">Reptes</h1>

<p class="text-slate-600 mb-4">
  Aquí mostrarem el llistat general de reptes (filtres, estat, etc.).
</p>

{#if $user}
  <p class="mt-4">
    <a
      href="/reptes/nou"
      class="inline-block rounded bg-slate-900 text-white px-4 py-2 hover:bg-slate-700"
    >
      ➕ Nou repte
    </a>
  </p>
{:else}
  <p class="text-slate-500 mt-4">
    Inicia sessió per poder crear reptes.
  </p>
{/if}

<p class="mt-6">
  <a class="underline" href="/reptes/me">👉 Els meus reptes</a>
</p>
