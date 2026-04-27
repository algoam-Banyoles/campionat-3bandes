<script lang="ts">
  import { confirmDialogState, resolveConfirm } from '$lib/stores/confirmDialogStore';

  /**
   * Component global que renderitza el confirm modal de l'app.
   * Es munta una sola vegada al layout arrel; les invocacions venen
   * via l'store imperatiu `showConfirm()`.
   */

  $: state = $confirmDialogState;

  function handleConfirm() {
    resolveConfirm(true);
  }

  function handleCancel() {
    resolveConfirm(false);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (!state.open) return;
    if (e.key === 'Escape') {
      e.preventDefault();
      handleCancel();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      handleConfirm();
    }
  }

  $: severity = state.severity ?? 'warning';
  $: confirmBtnClass =
    severity === 'danger'
      ? 'bg-red-600 hover:bg-red-700'
      : severity === 'info'
      ? 'bg-blue-600 hover:bg-blue-700'
      : 'bg-orange-600 hover:bg-orange-700';
  $: headerClass =
    severity === 'danger'
      ? 'bg-red-50 text-red-900'
      : severity === 'info'
      ? 'bg-blue-50 text-blue-900'
      : 'bg-orange-50 text-orange-900';
  $: icon = severity === 'danger' ? '🚨' : severity === 'info' ? 'ℹ️' : '⚠️';
</script>

<svelte:window on:keydown={handleKeydown} />

{#if state.open}
  <div
    class="fixed inset-0 z-[60] flex items-center justify-center bg-black/40 px-4 py-6"
    role="dialog"
    aria-modal="true"
    aria-labelledby="confirm-dialog-title"
  >
    <button
      type="button"
      class="absolute inset-0 cursor-default"
      aria-label="Tancar diàleg"
      on:click={handleCancel}
    ></button>

    <div class="relative bg-white rounded-lg shadow-xl max-w-md w-full">
      <div class="px-6 py-4 border-b border-gray-200 {headerClass} rounded-t-lg">
        <h3 id="confirm-dialog-title" class="text-lg font-semibold flex items-center gap-2">
          <span>{icon}</span>
          {state.title ?? 'Confirmació'}
        </h3>
      </div>

      <div class="px-6 py-5">
        <p class="text-sm text-gray-700 whitespace-pre-line">{state.message}</p>
      </div>

      <div class="px-6 py-4 border-t border-gray-200 flex items-center justify-end gap-3 rounded-b-lg bg-gray-50">
        <button
          type="button"
          on:click={handleCancel}
          class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
        >
          {state.cancelLabel ?? 'Cancel·lar'}
        </button>
        <button
          type="button"
          on:click={handleConfirm}
          class="px-4 py-2 text-sm font-medium text-white border border-transparent rounded-md {confirmBtnClass}"
        >
          {state.confirmLabel ?? 'Confirmar'}
        </button>
      </div>
    </div>
  </div>
{/if}
