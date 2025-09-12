<script lang="ts">
    import { onMount } from 'svelte';
    import { adminStore, checkIsAdmin } from '$lib/roles';

    let checked = false;

    onMount(async () => {
      const ok = await checkIsAdmin();
      checked = true;
      if (!ok) {
        // adminStore remains false; unauthorized message will show
      }
    });
  </script>

  {#if $adminStore}
    <slot />
  {:else if checked}
    <div class="m-4 rounded border border-red-300 bg-red-50 p-4 text-red-800">
      No autoritzat — <a href="/" class="underline">Inici</a>
    </div>
  {/if}

