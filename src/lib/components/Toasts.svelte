<script lang="ts">
  import { toasts, type Toast } from '$lib/ui/toastStore';
</script>

<div class="fixed top-2 right-2 flex flex-col gap-2 z-50">
  {#each $toasts as t (t.id)}
    <div
      class="px-3 py-2 rounded text-white shadow"
      class:bg-slate-800={t.type === 'info'}
      class:bg-green-600={t.type === 'success'}
      class:bg-red-600={t.type === 'error'}
    >
      {t.message}
    </div>
  {/each}
</div>
