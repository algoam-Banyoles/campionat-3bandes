<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { Category, CategoryMovement } from '$lib/types';

  export let open = false;
  export let movements: CategoryMovement[] = [];
  export let categories: Category[] = [];
  export let processing = false;

  const dispatch = createEventDispatcher<{
    confirm: void;
    cancel: void;
  }>();

  function categoryName(id: string | null | undefined): string {
    if (!id) return 'Sense categoria';
    return categories.find(c => c.id === id)?.nom ?? 'Desconeguda';
  }

  function close() {
    if (processing) return;
    dispatch('cancel');
  }

  function confirm() {
    if (processing) return;
    dispatch('confirm');
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }

  $: cascadeCount = Math.max(0, movements.length - 1);
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4 py-6"
    role="dialog"
    aria-modal="true"
    aria-labelledby="movement-preview-title"
  >
    <button
      type="button"
      class="absolute inset-0 cursor-default"
      aria-label="Tancar diàleg"
      on:click={close}
    ></button>

    <div class="relative bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 id="movement-preview-title" class="text-lg font-semibold text-gray-900 flex items-center gap-2">
          <span>🔀</span> Confirmar moviment intel·ligent
        </h3>
        <p class="text-sm text-gray-600 mt-1">
          {#if cascadeCount === 0}
            S'aplicarà 1 moviment.
          {:else}
            S'aplicaran <strong>{movements.length}</strong> moviments en total ({cascadeCount} per efecte cascada).
          {/if}
        </p>
      </div>

      <div class="flex-1 overflow-y-auto px-6 py-4">
        {#if movements.length === 0}
          <p class="text-center text-gray-500 py-8">No hi ha moviments per aplicar.</p>
        {:else}
          <ol class="space-y-2">
            {#each movements as m, i (m.inscriptionId + i)}
              {@const isMain = i === 0}
              <li class="flex items-start gap-3 p-3 rounded-lg border"
                class:border-blue-200={isMain}
                class:bg-blue-50={isMain}
                class:border-gray-200={!isMain}
                class:bg-gray-50={!isMain}
              >
                <span class="flex-shrink-0 inline-flex items-center justify-center w-7 h-7 rounded-full text-xs font-bold"
                  class:bg-blue-600={isMain}
                  class:text-white={isMain}
                  class:bg-gray-300={!isMain}
                  class:text-gray-700={!isMain}
                >
                  {i + 1}
                </span>
                <div class="flex-1 min-w-0">
                  <div class="font-medium text-gray-900">
                    {m.playerName ?? 'Jugador'}
                  </div>
                  <div class="text-sm text-gray-700 mt-0.5">
                    <span class="text-gray-500">{categoryName(m.previousCategoryId)}</span>
                    <span class="mx-1.5 text-gray-400">→</span>
                    <span class="font-medium text-gray-900">{categoryName(m.categoryId)}</span>
                  </div>
                  <div class="text-xs text-gray-500 mt-1">
                    {m.reason}
                  </div>
                </div>
              </li>
            {/each}
          </ol>
        {/if}
      </div>

      <div class="px-6 py-4 border-t border-gray-200 flex items-center justify-end gap-3">
        <button
          type="button"
          on:click={close}
          disabled={processing}
          class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
        >
          Cancel·lar
        </button>
        <button
          type="button"
          on:click={confirm}
          disabled={processing || movements.length === 0}
          class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 disabled:opacity-50 inline-flex items-center gap-2"
        >
          {#if processing}
            <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25" />
              <path d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" fill="currentColor" class="opacity-75" />
            </svg>
            Aplicant...
          {:else}
            Confirmar i aplicar
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}
