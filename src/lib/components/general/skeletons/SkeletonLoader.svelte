<script lang="ts">
  import { onMount } from 'svelte';

  export let width: string = '100%';
  export let height: string = '20px';
  export let variant: 'rectangular' | 'circular' | 'text' | 'ranking-row' | 'challenge-card' | 'countdown' = 'rectangular';
  export let lines: number = 1; // Para variant 'text'
  export let borderRadius: string = '4px';
  export let theme: 'billiard' | 'default' = 'billiard';
  export let urgency: 'safe' | 'warning' | 'critical' | 'none' = 'none';
  export let offline: boolean = false;
  export let shimmerSpeed: 'slow' | 'normal' | 'fast' = 'normal';
  export let showCountdown: boolean = false;
  export let countdownDays: number = 0;

  let mounted = false;

  onMount(() => {
    mounted = true;
  });

  function getVariantStyles(variant: string): string {
    switch (variant) {
      case 'circular':
        return `width: ${height}; height: ${height}; border-radius: 50%;`;
      case 'text':
        return `height: 1.2em; border-radius: 2px;`;
      case 'ranking-row':
        return `height: 48px; border-radius: 6px;`;
      case 'challenge-card':
        return `height: 120px; border-radius: 8px;`;
      case 'countdown':
        return `height: 32px; border-radius: 16px;`;
      default:
        return `width: ${width}; height: ${height}; border-radius: ${borderRadius};`;
    }
  }

  function getThemeClasses(): string {
    const base = 'skeleton-loader';
    const themeClass = theme === 'billiard' ? 'skeleton-billiard' : 'skeleton-default';
    const urgencyClass = urgency !== 'none' ? `skeleton-${urgency}` : '';
    const offlineClass = offline ? 'skeleton-offline' : '';
    const speedClass = `skeleton-${shimmerSpeed}`;
    
    return [base, themeClass, urgencyClass, offlineClass, speedClass].filter(Boolean).join(' ');
  }

  function getCountdownWidth(): string {
    if (!showCountdown || countdownDays <= 0) return '0%';
    const maxDays = urgency === 'critical' ? 1 : urgency === 'warning' ? 3 : 7;
    const percentage = Math.min((countdownDays / maxDays) * 100, 100);
    return `${percentage}%`;
  }
</script>

{#if mounted}
  <div 
    class={getVariantStyles(variant)} 
    class:skeleton-loader={true}
    class:skeleton-billiard={theme === 'billiard'}
    class:skeleton-default={theme === 'default'}
    class:skeleton-safe={urgency === 'safe'}
    class:skeleton-warning={urgency === 'warning'}
    class:skeleton-critical={urgency === 'critical'}
    class:skeleton-offline={offline}
    class:skeleton-slow={shimmerSpeed === 'slow'}
    class:skeleton-normal={shimmerSpeed === 'normal'}
    class:skeleton-fast={shimmerSpeed === 'fast'}
    style={getVariantStyles(variant)}
    role="status"
    aria-label="Carregant contingut..."
  >
    {#if variant === 'text' && lines > 1}
      {#each Array(lines) as _, i}
        <div 
          class="skeleton-text-line"
          style="width: {i === lines - 1 ? '75%' : '100%'}; margin-bottom: {i < lines - 1 ? '8px' : '0'};"
        ></div>
      {/each}
    {/if}
    
    {#if showCountdown && countdownDays > 0}
      <div class="skeleton-countdown-bar">
        <div 
          class="skeleton-countdown-fill" 
          style="width: {getCountdownWidth()}"
        ></div>
        <span class="skeleton-countdown-text">{countdownDays}d</span>
      </div>
    {/if}
  </div>
{/if}

<style>
  .skeleton-loader {
    position: relative;
    overflow: hidden;
    background: var(--skeleton-bg);
    animation: var(--skeleton-shimmer-animation);
  }

  /* Tema Billar */
  .skeleton-billiard {
    --skeleton-bg: linear-gradient(90deg, #2d5f3f 25%, #34704a 50%, #2d5f3f 75%);
    --skeleton-shimmer: linear-gradient(90deg, transparent, #4a8060, transparent);
    --skeleton-shimmer-animation: shimmer-billiard var(--skeleton-duration) ease-in-out infinite;
  }

  /* Tema Default */
  .skeleton-default {
    --skeleton-bg: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
    --skeleton-shimmer: linear-gradient(90deg, transparent, #ffffff, transparent);
    --skeleton-shimmer-animation: shimmer-default var(--skeleton-duration) ease-in-out infinite;
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .skeleton-billiard {
      --skeleton-bg: linear-gradient(90deg, #1a3d2b 25%, #236038 50%, #1a3d2b 75%);
      --skeleton-shimmer: linear-gradient(90deg, transparent, #2d5f3f, transparent);
    }
    
    .skeleton-default {
      --skeleton-bg: linear-gradient(90deg, #374151 25%, #4b5563 50%, #374151 75%);
      --skeleton-shimmer: linear-gradient(90deg, transparent, #6b7280, transparent);
    }
  }

  /* Estados de urgencia */
  .skeleton-safe {
    --skeleton-bg: linear-gradient(90deg, #059669 25%, #10b981 50%, #059669 75%);
  }

  .skeleton-warning {
    --skeleton-bg: linear-gradient(90deg, #d97706 25%, #f59e0b 50%, #d97706 75%);
  }

  .skeleton-critical {
    --skeleton-bg: linear-gradient(90deg, #dc2626 25%, #ef4444 50%, #dc2626 75%);
  }

  /* Estado offline */
  .skeleton-offline {
    --skeleton-bg: linear-gradient(90deg, #6b7280 25%, #9ca3af 50%, #6b7280 75%);
    opacity: 0.7;
  }

  /* Velocidades de shimmer */
  .skeleton-slow {
    --skeleton-duration: 2.5s;
  }

  .skeleton-normal {
    --skeleton-duration: 1.5s;
  }

  .skeleton-fast {
    --skeleton-duration: 1s;
  }

  /* Shimmer effect */
  .skeleton-loader::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: var(--skeleton-shimmer);
    animation: shimmer var(--skeleton-duration) ease-in-out infinite;
  }

  /* Text lines */
  .skeleton-text-line {
    height: 1.2em;
    background: var(--skeleton-bg);
    border-radius: 2px;
    position: relative;
    overflow: hidden;
  }

  .skeleton-text-line::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: var(--skeleton-shimmer);
    animation: shimmer var(--skeleton-duration) ease-in-out infinite;
  }

  /* Countdown bar */
  .skeleton-countdown-bar {
    position: absolute;
    bottom: 4px;
    left: 4px;
    right: 4px;
    height: 6px;
    background: rgba(0, 0, 0, 0.1);
    border-radius: 3px;
    overflow: hidden;
  }

  .skeleton-countdown-fill {
    height: 100%;
    background: currentColor;
    border-radius: 3px;
    transition: width 0.3s ease;
  }

  .skeleton-countdown-text {
    position: absolute;
    top: -20px;
    right: 0;
    font-size: 0.75rem;
    font-weight: 600;
    color: currentColor;
    background: rgba(255, 255, 255, 0.9);
    padding: 2px 4px;
    border-radius: 2px;
  }

  /* Keyframes */
  @keyframes shimmer {
    0% {
      left: -100%;
    }
    100% {
      left: 100%;
    }
  }

  @keyframes shimmer-billiard {
    0% {
      background-position: -468px 0;
    }
    100% {
      background-position: 468px 0;
    }
  }

  @keyframes shimmer-default {
    0% {
      background-position: -468px 0;
    }
    100% {
      background-position: 468px 0;
    }
  }

  /* Responsive */
  @media (max-width: 768px) {
    .skeleton-challenge-card {
      height: 100px;
    }
    
    .skeleton-ranking-row {
      height: 40px;
    }
  }

  /* Reduce motion */
  @media (prefers-reduced-motion: reduce) {
    .skeleton-loader {
      animation: none;
    }
    
    .skeleton-loader::before {
      animation: none;
      background: var(--skeleton-bg);
    }
    
    .skeleton-text-line::before {
      animation: none;
      background: var(--skeleton-bg);
    }
  }

  /* High contrast */
  @media (prefers-contrast: high) {
    .skeleton-loader {
      border: 1px solid currentColor;
    }
  }
</style>