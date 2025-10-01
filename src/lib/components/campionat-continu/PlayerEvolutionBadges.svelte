<!-- src/lib/components/campionat-continu/PlayerEvolutionBadges.svelte -->
<script lang="ts">
  import type { ChallengeResult } from '$lib/stores/playerChallengeHistory';

  export let results: ChallengeResult[] = [];

  // Funció per obtenir la classe CSS segons el resultat
  function getBadgeClass(result: ChallengeResult): string {
    return result === 'W' 
      ? 'bg-green-500 text-white border-green-600' 
      : 'bg-red-500 text-white border-red-600';
  }

  // Funció per obtenir el text a mostrar
  function getBadgeText(result: ChallengeResult): string {
    return result === 'W' ? 'V' : 'P';
  }

  // Funció per obtenir el tooltip
  function getBadgeTooltip(result: ChallengeResult, index: number): string {
    const position = index + 1;
    const resultText = result === 'W' ? 'Victòria' : 'Derrota';
    return `${resultText} (${position}${position === 1 ? 'r' : position === 2 ? 'n' : position === 3 ? 'r' : 'è'} més recent)`;
  }
</script>

<div class="flex gap-1 items-center">
  {#each results as result, index}
    <div 
      class="w-6 h-6 sm:w-7 sm:h-7 lg:w-8 lg:h-8 rounded-full border-2 flex items-center justify-center text-xs sm:text-sm lg:text-base font-bold shadow-sm {getBadgeClass(result)}"
      title={getBadgeTooltip(result, index)}
    >
      {getBadgeText(result)}
    </div>
  {/each}
  
  <!-- Mostrar punts suspensius si no hi ha prou resultats -->
  {#if results.length < 6}
    {#each Array(6 - results.length) as _, index}
      <div 
        class="w-6 h-6 sm:w-7 sm:h-7 lg:w-8 lg:h-8 rounded-full border-2 border-gray-200 bg-gray-100 flex items-center justify-center text-xs sm:text-sm lg:text-base text-gray-400"
        title="Sense dades"
      >
        ·
      </div>
    {/each}
  {/if}
</div>

<style>
  /* Afegir animació suau per quan apareixen nous badges */
  div {
    transition: all 0.2s ease-in-out;
  }
</style>