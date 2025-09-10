<script lang="ts">
  import { onMount } from 'svelte';
  import { isAdmin } from '$lib/authStore';
  import { get } from 'svelte/store';

  let admin = false;
  let checked = false;

  onMount(() => {
    admin = get(isAdmin);
    checked = true;
  });
</script>

{#if admin}
  <slot />
{:else if checked}
  <div class="m-4 rounded border border-red-300 bg-red-50 p-4 text-red-800">
    No autoritzat — <a href="/" class="underline">Inici</a>
  </div>
{/if}
