<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import HandicapBracketPrintVisualModal from '$lib/components/handicap/HandicapBracketPrintVisualModal.svelte';

	let eventId: string | null = null;
	let eventNom = '';
	let eventTemporada = '';
	let loading = true;
	let participantCount = 0;

	onMount(async () => {
		const { data: ev } = await supabase
			.from('events')
			.select('id, nom, temporada')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.maybeSingle();
		if (ev) {
			eventId = ev.id;
			eventNom = ev.nom ?? '';
			eventTemporada = ev.temporada ?? '';
			const { count } = await supabase
				.from('handicap_participants')
				.select('id', { count: 'exact', head: true })
				.eq('event_id', ev.id);
			participantCount = count ?? 0;
		}
		loading = false;
	});
</script>

<svelte:head>
	<title>Bracket visual — Hàndicap</title>
</svelte:head>

{#if !loading && eventId}
	<HandicapBracketPrintVisualModal
		{eventId}
		{eventNom}
		{eventTemporada}
		participantCount={participantCount || null}
		onClose={() => goto('/handicap/quadre')}
	/>
{:else if !loading}
	<div style="padding: 2rem; text-align: center;">
		<p>No hi ha cap torneig hàndicap actiu.</p>
		<a href="/handicap" style="color: #1f1f1f; text-decoration: underline;">Tornar a Hàndicap</a>
	</div>
{/if}
