<script lang="ts">
  export let text: string = 'Carregant…';
  export let compact: boolean = false;
</script>

{#if compact}
  <div class="flex items-center gap-2 text-slate-500">
    <div class="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"></div>
    <span class="text-sm">{text}</span>
  </div>
{:else}
  <div class="space-y-3 rounded border p-4">
    <div class="space-y-2 animate-pulse">
      <div class="h-4 w-2/3 rounded bg-slate-200"></div>
      <div class="h-4 w-full rounded bg-slate-200"></div>
      <div class="h-4 w-5/6 rounded bg-slate-200"></div>
    </div>
    <p class="text-sm text-slate-500">{text}</p>
  </div>
{/if}

