<script lang="ts">
  import { page } from '$app/stores';
</script>

<div class="mx-auto w-full max-w-7xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
  <div class="bg-white border border-gray-200 rounded-lg p-8 sm:p-12 max-w-lg mx-auto text-center">
    <p class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">Error {$page.status}</p>

    {#if $page.status === 404}
      <h1 class="text-2xl font-bold text-gray-900 mb-4">No s'ha trobat la pàgina</h1>
      <p class="text-base text-gray-600 mb-8">
        La pàgina que cerques no existeix o ha canviat d'adreça.
      </p>
    {:else}
      <h1 class="text-2xl font-bold text-gray-900 mb-4">S'ha produït un error</h1>
      <p class="text-base text-gray-600 mb-8">
        {$page.error?.message ?? 'Ha ocorregut un error inesperat. Torna-ho a intentar.'}
      </p>
    {/if}

    <a href="/" class="inline-flex items-center text-base font-medium text-blue-600 hover:text-blue-800 underline-offset-2 hover:underline">
      &larr; Tornar a l&apos;inici
    </a>
  </div>
</div>
