<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { PendingMatchSummary } from '$lib/services/calendarMutationsService';
  import { formatDate } from '$lib/services/calendarTimelineService';

  /**
   * Modal de confirmació previa al registre d'incompareixença.
   *
   * Mostra a l'admin l'impacte real abans de confirmar:
   *  - Nom del jugador absent
   *  - Comptador d'incompareixences (actual → futur)
   *  - Si el futur és 2: avís de desqualificació + llista de partides
   *    pendents que quedaran anul·lades
   */

  export let open = false;
  export let playerName: string = '';
  export let currentCount: number = 0;
  /** El llindar a partir del qual el jugador queda eliminat (per defecte 2). */
  export let disqualificationThreshold: number = 2;
  export let pendingMatches: PendingMatchSummary[] = [];
  export let loading: boolean = false;

  const dispatch = createEventDispatcher<{
    confirm: void;
    cancel: void;
  }>();

  $: futureCount = currentCount + 1;
  $: willDisqualify = futureCount >= disqualificationThreshold;

  function close() {
    if (loading) return;
    dispatch('cancel');
  }

  function confirmAction() {
    if (loading) return;
    dispatch('confirm');
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4 py-6"
    role="dialog"
    aria-modal="true"
    aria-labelledby="incompareixenca-preflight-title"
  >
    <button
      type="button"
      class="absolute inset-0 cursor-default"
      aria-label="Tancar diàleg"
      on:click={close}
    ></button>

    <div class="relative bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-200"
        class:bg-red-50={willDisqualify}
        class:bg-orange-50={!willDisqualify}
      >
        <h3 id="incompareixenca-preflight-title" class="text-lg font-semibold flex items-center gap-2"
          class:text-red-900={willDisqualify}
          class:text-orange-900={!willDisqualify}
        >
          {#if willDisqualify}
            ⛔ Confirmar incompareixença + DESQUALIFICACIÓ
          {:else}
            ⚠️ Confirmar incompareixença
          {/if}
        </h3>
      </div>

      <div class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="text-sm text-gray-600">Jugador absent</div>
          <div class="text-lg font-semibold text-gray-900">{playerName}</div>
        </div>

        <div class="grid grid-cols-3 gap-3 text-center">
          <div class="bg-white border border-gray-200 rounded-lg p-3">
            <div class="text-xs text-gray-500 uppercase">Actual</div>
            <div class="text-2xl font-bold text-gray-700">{currentCount}</div>
          </div>
          <div class="bg-white border border-gray-200 rounded-lg p-3 flex flex-col items-center justify-center">
            <div class="text-2xl text-gray-400">→</div>
          </div>
          <div class="bg-white border-2 rounded-lg p-3"
            class:border-red-400={willDisqualify}
            class:border-orange-400={!willDisqualify}
          >
            <div class="text-xs uppercase"
              class:text-red-600={willDisqualify}
              class:text-orange-600={!willDisqualify}
            >Després</div>
            <div class="text-2xl font-bold"
              class:text-red-700={willDisqualify}
              class:text-orange-700={!willDisqualify}
            >{futureCount}</div>
          </div>
        </div>

        <div class="text-xs text-center text-gray-500">
          Llindar de desqualificació: <strong>{disqualificationThreshold}</strong> incompareixences
        </div>

        {#if willDisqualify}
          <div class="bg-red-50 border-2 border-red-300 rounded-lg p-4 space-y-2">
            <div class="font-bold text-red-900 flex items-center gap-2">
              <span>🚨</span> Aquesta acció DESQUALIFICARÀ el jugador
            </div>
            <p class="text-sm text-red-800">
              {playerName} arribarà a {futureCount} incompareixences i quedarà <strong>eliminat del campionat</strong>.
              {#if pendingMatches.length > 0}
                Les <strong>{pendingMatches.length}</strong> partides pendents següents quedaran <strong>anul·lades</strong>:
              {:else}
                No hi ha partides pendents per anul·lar.
              {/if}
            </p>
          </div>

          {#if pendingMatches.length > 0}
            <div class="border border-gray-200 rounded-lg overflow-hidden">
              <div class="px-4 py-2 bg-gray-50 border-b border-gray-200 text-sm font-medium text-gray-700">
                Partides que s'anul·laran ({pendingMatches.length})
              </div>
              <ul class="divide-y divide-gray-100 max-h-64 overflow-y-auto">
                {#each pendingMatches as m (m.id)}
                  <li class="px-4 py-2 text-sm flex items-center justify-between gap-3">
                    <span class="text-gray-900">
                      vs <span class="font-medium">{m.rivalNom} {m.rivalCognoms}</span>
                    </span>
                    <span class="text-gray-500 text-xs whitespace-nowrap">
                      {#if m.data_programada}
                        {formatDate(new Date(m.data_programada))}
                        {#if m.hora_inici} · {m.hora_inici}{/if}
                        {#if m.taula_assignada} · B{m.taula_assignada}{/if}
                      {:else}
                        Sense programar
                      {/if}
                    </span>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}
        {:else}
          <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 space-y-2">
            <p class="text-sm text-orange-900">
              <strong>{playerName}</strong> rebrà <strong>0 punts</strong> i <strong>50 entrades</strong> en aquesta partida.
              Després d'aquesta serà la seva incompareixença <strong>número {futureCount}</strong>.
            </p>
            {#if futureCount === disqualificationThreshold - 1}
              <p class="text-sm text-orange-900">
                ⚠️ Una incompareixença més comportarà la desqualificació automàtica.
              </p>
            {/if}
          </div>
        {/if}
      </div>

      <div class="px-6 py-4 border-t border-gray-200 flex items-center justify-end gap-3">
        <button
          type="button"
          on:click={close}
          disabled={loading}
          class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
        >
          Cancel·lar
        </button>
        <button
          type="button"
          on:click={confirmAction}
          disabled={loading}
          class="px-4 py-2 text-sm font-medium text-white border border-transparent rounded-md inline-flex items-center gap-2 disabled:opacity-50"
          class:bg-red-600={willDisqualify}
          class:hover:bg-red-700={willDisqualify}
          class:bg-orange-600={!willDisqualify}
          class:hover:bg-orange-700={!willDisqualify}
        >
          {#if loading}
            <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25" />
              <path d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" fill="currentColor" class="opacity-75" />
            </svg>
            Aplicant...
          {:else if willDisqualify}
            ⛔ Confirmar i desqualificar
          {:else}
            Confirmar incompareixença
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}
