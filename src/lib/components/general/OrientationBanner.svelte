<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';

  let isVisible = false;
  let isDismissed = false;

  function checkOrientation() {
    if (!browser) return;

    const isPortrait = window.matchMedia('(orientation: portrait)').matches;
    const isMobile = window.matchMedia('(max-width: 768px)').matches;

    isVisible = isPortrait && isMobile && !isDismissed;
  }

  function dismiss() {
    isDismissed = true;
    isVisible = false;
    // Guardar la preferència al sessionStorage perquè no torni a aparèixer en aquesta sessió
    if (browser) {
      sessionStorage.setItem('orientationBannerDismissed', 'true');
    }
  }

  onMount(() => {
    // Comprovar si ja s'ha descartat en aquesta sessió
    if (sessionStorage.getItem('orientationBannerDismissed') === 'true') {
      isDismissed = true;
    }

    checkOrientation();

    // Escoltar canvis d'orientació
    const mediaQuery = window.matchMedia('(orientation: portrait)');
    mediaQuery.addEventListener('change', checkOrientation);

    return () => {
      mediaQuery.removeEventListener('change', checkOrientation);
    };
  });
</script>

{#if isVisible}
  <div class="fixed top-0 left-0 right-0 bg-yellow-400 text-black z-[10000] shadow-md">
    <div class="flex items-center justify-between px-4 py-2">
      <div class="flex items-center gap-2 flex-1">
        <span class="text-xl">🔄</span>
        <p class="text-sm font-semibold">
          Per a una millor experiència, si us plau gira el teu dispositiu a horitzontal
        </p>
      </div>
      <button
        on:click={dismiss}
        class="flex-shrink-0 ml-2 p-1 hover:bg-yellow-500 rounded-full transition-colors"
        aria-label="Tancar missatge"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>
    </div>
  </div>
{/if}
