<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { buildBadgeDescriptors } from '$lib/playerBadges';
  import type { PlayerBadgeDescriptor, PlayerBadgeSource } from '$lib/playerBadges';

  export let row: PlayerBadgeSource;

  const dispatch = createEventDispatcher<{ challenge: string }>();

  let badges: PlayerBadgeDescriptor[] = [];
  $: badges = buildBadgeDescriptors(row);

  const handleChallenge = () => {
    if (row.player_id) {
      dispatch('challenge', row.player_id);
    }
  };
</script>

{#each badges as badge (badge.state)}
  {#if badge.element === 'button'}
    <button
      type="button"
      class={badge.className}
      title={badge.title}
      aria-label={badge.ariaLabel}
      disabled={badge.disabled ? true : undefined}
      on:click={handleChallenge}
    >
      {badge.text}
    </button>
  {:else}
    <span
      class={badge.className}
      title={badge.title}
      aria-label={badge.ariaLabel}
    >
      {badge.text}
    </span>
  {/if}
{/each}
