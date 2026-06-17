<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';

	// El format "compacte" s'ha unificat amb el "visual": ara hi ha un sol
	// format d'impressió de bracket per a la pissarra. Redirigim a la ruta
	// canònica per evitar dues sortides diferents.
	onMount(() => {
		goto(`${base}/handicap/quadre/visual`, { replaceState: true });
	});
</script>

<svelte:head>
	<title>Bracket — Hàndicap</title>
</svelte:head>

<div style="padding: 2rem; text-align: center;">
	<p>Redirigint al bracket visual…</p>
	<a href="{base}/handicap/quadre/visual" style="color: #1f1f1f; text-decoration: underline;">
		Obrir el bracket visual
	</a>
</div>
