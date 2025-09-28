<script lang="ts">
  export let type: 'success' | 'error' | 'info' | 'warn' = 'info';
  export let message: string;

  const styles = {
    success: 'border-green-300 bg-green-50 text-green-800',
    error: 'border-red-300 bg-red-50 text-red-800',
    info: 'border-blue-300 bg-blue-50 text-blue-800',
    warn: 'border-amber-300 bg-amber-50 text-amber-900'
  } as const;

  const icons = {
    success: '✅',
    error: '❌',
    info: 'ℹ️',
    warn: '⚠️'
  } as const;
</script>

<div class={`flex items-center gap-2 rounded border p-3 text-sm ${styles[type]}`} {...$$restProps}>
  <span>{icons[type]}</span>
  <span>{message}</span>
</div>
