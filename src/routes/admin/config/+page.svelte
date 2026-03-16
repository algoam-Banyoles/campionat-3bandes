<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  onMount(() => goto('/admin/configuracio', { replaceState: true }));
</script>
