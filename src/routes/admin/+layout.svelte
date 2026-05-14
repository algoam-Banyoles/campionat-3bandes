<script lang="ts">
    import { adminChecked } from '$lib/stores/adminAuth';
    import { effectiveIsAdmin } from '$lib/stores/viewMode';

    // Usem effectiveIsAdmin perquè respecti el toggle viewMode:
    // un admin en vista "Jugador" no ha de poder entrar a /admin.
    $: canAccess = $adminChecked && $effectiveIsAdmin;
</script>

{#if !$adminChecked}
  <!-- Loading state while checking admin status -->
  <div class="no-print m-4 rounded border border-blue-300 bg-blue-50 p-4 text-blue-800">
    Comprovant permisos...
  </div>
{:else if canAccess}
  <div class="admin-content no-print">
    <slot />
  </div>
{:else}
  <div class="no-print m-4 rounded border border-red-300 bg-red-50 p-4 text-red-800">
    Només els administradors poden accedir a aquesta pàgina. — <a href="/" class="underline">Inici</a>
  </div>
{/if}

<style>
  @media print {
    .no-print {
      display: none !important;
    }
  }
</style>

