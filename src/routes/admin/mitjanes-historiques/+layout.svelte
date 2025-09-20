<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { adminStore } from '$lib/stores/auth';

	onMount(() => {
		// Assegurar-se que només els admins poden accedir
		if (!$adminStore) {
			goto('/');
		}
	});
</script>

<slot />