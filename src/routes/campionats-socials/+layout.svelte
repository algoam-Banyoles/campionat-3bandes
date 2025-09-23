<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import Nav from '$lib/components/Nav.svelte';
  import { initAuthClient } from '$lib/utils/auth-client';
  import { isLoading } from '$lib/stores/auth';

  // Layout específic per lligues socials
  onMount(() => {
    // Inicialitzar autenticació si no ho està ja
    initAuthClient();
  });
</script>

{#if $isLoading}
  <div class="min-h-screen bg-gray-50 flex items-center justify-center">
    <div class="text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <p class="text-gray-600">Carregant sessió…</p>
    </div>
  </div>
{:else}
<div class="min-h-screen bg-gray-50">
  <Nav />

  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Breadcrumb navigation -->
    <nav class="flex mb-6" aria-label="Breadcrumb">
      <ol class="flex items-center space-x-4">
        <li>
          <a href="/" class="text-gray-500 hover:text-gray-700">
            Dashboard
          </a>
        </li>
        <li>
          <svg class="flex-shrink-0 h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
          </svg>
        </li>
        <li>
          <a href="/campionats-socials" class="text-gray-500 hover:text-gray-700">
            Lligues Socials
          </a>
        </li>
      </ol>
    </nav>

    <!-- Dev warning banner -->
    <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4 mb-6">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-yellow-800">
            Funcionalitat en Desenvolupament
          </h3>
          <div class="mt-2 text-sm text-yellow-700">
            <p>Les lligues socials estan en fase de desenvolupament. Accés restringit temporalment.</p>
          </div>
        </div>
      </div>
    </div>

    <main>
      <slot />
    </main>
  </div>
</div>
{/if}