<script lang="ts">
    import { onMount } from 'svelte';
    import { goto } from '$app/navigation';
    import { signOut } from '$lib/utils/auth-client';

  onMount(async () => {
      await signOut();
      goto('/');
  });
</script>

<p class="text-slate-600">Tancant sessió…</p>
