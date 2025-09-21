<script lang="ts">
  import { onMount } from 'svelte';
  
  import type { Snippet } from 'svelte';
  
  interface Props {
    onRefresh: () => Promise<void>;
    threshold?: number;
    disabled?: boolean;
    children: Snippet;
  }
  
  let { onRefresh, threshold = 80, disabled = false, children }: Props = $props();
  
  let containerElement: HTMLElement;
  let refreshElement: HTMLElement;
  let isRefreshing = $state(false);
  let pullDistance = $state(0);
  let startY = 0;
  let currentY = 0;
  let isAtTop = true;
  
  const checkScrollPosition = () => {
    if (containerElement) {
      isAtTop = containerElement.scrollTop <= 0;
    }
  };
  
  const handleTouchStart = (e: TouchEvent) => {
    if (disabled || isRefreshing) return;
    
    checkScrollPosition();
    if (!isAtTop) return;
    
    startY = e.touches[0].clientY;
    currentY = startY;
  };
  
  const handleTouchMove = (e: TouchEvent) => {
    if (disabled || isRefreshing || !isAtTop) return;
    
    currentY = e.touches[0].clientY;
    const deltaY = currentY - startY;
    
    if (deltaY > 0) {
      // Calculate pull distance with diminishing returns
      pullDistance = Math.min(deltaY * 0.4, threshold * 1.5);
      
      // Prevent default scrolling when pulling down
      if (pullDistance > 10) {
        e.preventDefault();
      }
    } else {
      pullDistance = 0;
    }
  };
  
  const handleTouchEnd = async () => {
    if (disabled || isRefreshing || !isAtTop) {
      pullDistance = 0;
      return;
    }
    
    if (pullDistance >= threshold) {
      isRefreshing = true;
      pullDistance = threshold;
      
      try {
        await onRefresh();
      } catch (error) {
        console.error('Refresh error:', error);
      } finally {
        isRefreshing = false;
        pullDistance = 0;
      }
    } else {
      pullDistance = 0;
    }
  };
  
  onMount(() => {
    if (containerElement) {
      containerElement.addEventListener('touchstart', handleTouchStart, { passive: true });
      containerElement.addEventListener('touchmove', handleTouchMove, { passive: false });
      containerElement.addEventListener('touchend', handleTouchEnd, { passive: true });
      containerElement.addEventListener('scroll', checkScrollPosition, { passive: true });
      
      return () => {
        if (containerElement) {
          containerElement.removeEventListener('touchstart', handleTouchStart);
          containerElement.removeEventListener('touchmove', handleTouchMove);
          containerElement.removeEventListener('touchend', handleTouchEnd);
          containerElement.removeEventListener('scroll', checkScrollPosition);
        }
      };
    }
  });
  
  $effect(() => {
    if (refreshElement) {
      refreshElement.style.transform = `translateY(${pullDistance}px)`;
    }
  });
</script>

<div 
  bind:this={containerElement}
  class="pull-to-refresh-container"
  class:refreshing={isRefreshing}
>
  <div 
    bind:this={refreshElement}
    class="refresh-indicator"
    class:visible={pullDistance > 0}
    class:active={pullDistance >= threshold}
    style="opacity: {Math.min(pullDistance / threshold, 1)}"
  >
    <div class="refresh-content">
      {#if isRefreshing}
        <div class="spinner" aria-label="Actualitzant...">
          <div class="spinner-circle"></div>
        </div>
        <span class="refresh-text">Actualitzant...</span>
      {:else if pullDistance >= threshold}
        <div class="refresh-icon ready">↻</div>
        <span class="refresh-text">Deixar anar per actualitzar</span>
      {:else if pullDistance > 0}
        <div class="refresh-icon" style="transform: rotate({pullDistance * 2}deg)">↓</div>
        <span class="refresh-text">Arrossegar per actualitzar</span>
      {/if}
    </div>
  </div>
  
  <div class="content">
    {@render children?.()}
  </div>
</div>

<style>
  .pull-to-refresh-container {
    position: relative;
    height: 100%;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }
  
  .refresh-indicator {
    position: absolute;
    top: -80px;
    left: 0;
    right: 0;
    height: 80px;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: #f9fafb;
    border-bottom: 1px solid #e5e7eb;
    z-index: 10;
    transition: opacity 0.2s ease;
  }
  
  .refresh-indicator.visible {
    opacity: 1;
  }
  
  .refresh-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
  }
  
  .refresh-icon {
    font-size: 1.5rem;
    color: #6b7280;
    transition: all 0.2s ease;
  }
  
  .refresh-icon.ready {
    color: #3b82f6;
    animation: pulse 0.6s infinite;
  }
  
  .refresh-text {
    font-size: 0.875rem;
    color: #6b7280;
    font-weight: 500;
  }
  
  .spinner {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .spinner-circle {
    width: 24px;
    height: 24px;
    border: 2px solid #e5e7eb;
    border-top: 2px solid #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  .content {
    position: relative;
    z-index: 1;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }
  
  /* Disable pull-to-refresh when refreshing */
  .pull-to-refresh-container.refreshing {
    touch-action: auto;
  }
</style>