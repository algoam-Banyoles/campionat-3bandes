<script lang="ts">
  export let width: string | number = '100%';
  export let height: string | number = '16px';
  export let variant: 'text' | 'rectangular' | 'circular' | 'countdown' = 'text';
  export let borderRadius: string = '4px';
  export let theme: 'billiard' | 'default' = 'default';
  export let urgency: 'none' | 'safe' | 'warning' | 'critical' = 'none';
  export let offline: boolean = false;
  export let showCountdown: boolean = false;
  export let countdownDays: number = 0;

  $: styleWidth = typeof width === 'number' ? `${width}px` : width;
  $: styleHeight = typeof height === 'number' ? `${height}px` : height;

  $: baseClasses = [
    'skeleton-loader',
    `variant-${variant}`,
    `theme-${theme}`,
    `urgency-${urgency}`,
    offline ? 'offline' : ''
  ].filter(Boolean).join(' ');

  $: style = `
    width: ${styleWidth};
    height: ${styleHeight};
    border-radius: ${borderRadius};
  `;
</script>

<div
  class={baseClasses}
  {style}
  data-countdown={showCountdown ? countdownDays : null}
>
  {#if variant === 'countdown' && showCountdown}
    <span class="countdown-text">{countdownDays}d</span>
  {/if}
</div>

<style>
  .skeleton-loader {
    position: relative;
    overflow: hidden;
    background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
    background-size: 200% 100%;
    animation: skeleton-loading 1.5s infinite;
  }

  /* Variants */
  .variant-circular {
    border-radius: 50% !important;
  }

  .variant-text {
    border-radius: 4px;
  }

  .variant-rectangular {
    /* Uses the borderRadius prop */
  }

  .variant-countdown {
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    font-weight: 500;
  }

  .countdown-text {
    color: #666;
    font-size: 11px;
    font-weight: 600;
  }

  /* Themes */
  .theme-billiard {
    background: linear-gradient(90deg, #8b4513 25%, #a0522d 50%, #8b4513 75%);
    background-size: 200% 100%;
  }

  .theme-default {
    background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
    background-size: 200% 100%;
  }

  /* Urgency levels */
  .urgency-safe {
    background: linear-gradient(90deg, #dcfce7 25%, #bbf7d0 50%, #dcfce7 75%);
    background-size: 200% 100%;
  }

  .urgency-warning {
    background: linear-gradient(90deg, #fef3c7 25%, #fde68a 50%, #fef3c7 75%);
    background-size: 200% 100%;
  }

  .urgency-critical {
    background: linear-gradient(90deg, #fee2e2 25%, #fecaca 50%, #fee2e2 75%);
    background-size: 200% 100%;
  }

  /* Offline state */
  .offline {
    opacity: 0.6;
  }

  .offline::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: repeating-linear-gradient(
      45deg,
      transparent,
      transparent 2px,
      rgba(255, 255, 255, 0.1) 2px,
      rgba(255, 255, 255, 0.1) 4px
    );
  }

  /* Animation */
  @keyframes skeleton-loading {
    0% {
      background-position: 200% 0;
    }
    100% {
      background-position: -200% 0;
    }
  }

  /* Dark mode support */
  @media (prefers-color-scheme: dark) {
    .skeleton-loader:not(.theme-billiard) {
      background: linear-gradient(90deg, #374151 25%, #4b5563 50%, #374151 75%);
      background-size: 200% 100%;
    }

    .urgency-safe {
      background: linear-gradient(90deg, #14532d 25%, #166534 50%, #14532d 75%);
      background-size: 200% 100%;
    }

    .urgency-warning {
      background: linear-gradient(90deg, #92400e 25%, #b45309 50%, #92400e 75%);
      background-size: 200% 100%;
    }

    .urgency-critical {
      background: linear-gradient(90deg, #991b1b 25%, #dc2626 50%, #991b1b 75%);
      background-size: 200% 100%;
    }

    .countdown-text {
      color: #d1d5db;
    }
  }
</style>