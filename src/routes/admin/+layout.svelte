<script lang="ts">
    import { isAdmin } from '$lib/stores/adminAuth';
    import { adminChecked } from '$lib/stores/adminAuth';

    // Simply use the reactive stores - no delays or complex logic
    $: canAccess = $adminChecked && $isAdmin;
</script>

{#if !$adminChecked}
  <!-- Loading state while checking admin status -->
  <div class="m-4 rounded border border-blue-300 bg-blue-50 p-4 text-blue-800">
    Comprovant permisos...
  </div>
{:else if canAccess}
  <slot />
{:else}
  <div class="m-4 rounded border border-red-300 bg-red-50 p-4 text-red-800">
    Només els administradors poden accedir a aquesta pàgina. — <a href="/" class="underline">Inici</a>
  </div>
{/if}

