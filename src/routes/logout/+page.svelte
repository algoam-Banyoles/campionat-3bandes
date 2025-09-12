<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { goto } from '$app/navigation';

  onMount(async () => {
    await supabase.auth.signOut();
    await fetch('/api/session', { method: 'DELETE', credentials: 'include' });
    goto('/');
  });
</script>

<p class="text-slate-600">Tancant sessió…</p>
