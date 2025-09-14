<script lang="ts">
    import { adminStore } from '$lib/stores/auth';
</script>

{#if $adminStore}
  <slot />
{:else}
  <div class="m-4 rounded border border-red-300 bg-red-50 p-4 text-red-800">
    No autoritzat — <a href="/" class="underline">Inici</a>
  </div>
{/if}

