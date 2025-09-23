<script lang="ts">
  import { onMount } from 'svelte';
  import type { PageData } from './$types';
  import SocialLeaguesOverview from '$lib/components/SocialLeaguesOverview.svelte';

  export let data: PageData;
</script>

<svelte:head>
  <title>Lligues Socials - Campionat 3 Bandes</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="md:flex md:items-center md:justify-between">
    <div class="flex-1 min-w-0">
      <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
        Lligues Socials
      </h2>
      <p class="mt-1 text-sm text-gray-500">
        Campionats socials per modalitats: Lliure, Banda i 3 Bandes
      </p>
    </div>
    <div class="mt-4 flex md:mt-0 md:ml-4">
      <button
        type="button"
        class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        disabled
      >
        Nova Lliga (Coming Soon)
      </button>
    </div>
  </div>

  <!-- Status Cards -->
  <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
    <!-- Lligues Actives -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Lligues Actives</dt>
              <dd class="text-lg font-medium text-gray-900">0</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- Inscripcions Obertes -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Inscripcions Obertes</dt>
              <dd class="text-lg font-medium text-gray-900">0</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- Partides Pendents -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Partides Pendents</dt>
              <dd class="text-lg font-medium text-gray-900">0</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Dades Històriques -->
  <SocialLeaguesOverview />

  <!-- Development Status -->
  <div class="bg-white shadow rounded-lg">
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
        Estat del Desenvolupament
      </h3>

      <div class="space-y-4">
        <div class="border-l-4 border-green-400 bg-green-50 p-4">
          <div class="flex">
            <div class="ml-3">
              <p class="text-sm text-green-700">
                <strong>Fase 1:</strong> Migració de base de dades completada ✅
              </p>
            </div>
          </div>
        </div>

        <div class="border-l-4 border-green-400 bg-green-50 p-4">
          <div class="flex">
            <div class="ml-3">
              <p class="text-sm text-green-700">
                <strong>Fase 2:</strong> Importació dades Excel històriques completada ✅
              </p>
            </div>
          </div>
        </div>

        <div class="border-l-4 border-green-400 bg-green-50 p-4">
          <div class="flex">
            <div class="ml-3">
              <p class="text-sm text-green-700">
                <strong>Fase 3:</strong> API i components UI bàsics completats ✅
              </p>
            </div>
          </div>
        </div>

        <div class="border-l-4 border-yellow-400 bg-yellow-50 p-4">
          <div class="flex">
            <div class="ml-3">
              <p class="text-sm text-yellow-700">
                <strong>Fase 4:</strong> Funcionalitats avançades (en desenvolupament)
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <p class="text-sm text-gray-500">
          Pròximes funcionalitats a implementar:
        </p>
        <ul class="mt-2 text-sm text-gray-500 list-disc list-inside space-y-1">
          <li>Gestió d'inscripcions amb preferències horàries</li>
          <li>Assignació automàtica de categories</li>
          <li>Generació automàtica de calendaris</li>
          <li>Sistema de validació per la junta</li>
          <li>Classificacions en temps real</li>
        </ul>
      </div>
    </div>
  </div>
</div>