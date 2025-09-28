<script lang="ts">
  import { onMount } from 'svelte';
  
  interface Props {
    onSwipeLeft?: (() => void) | undefined;
    onSwipeRight?: (() => void) | undefined;
    onSwipeUp?: (() => void) | undefined;
    onSwipeDown?: (() => void) | undefined;
    threshold?: number;
    restraint?: number;
    allowedTime?: number;
  }
  
  let { 
    onSwipeLeft = undefined, 
    onSwipeRight = undefined, 
    onSwipeUp = undefined, 
    onSwipeDown = undefined,
    threshold = 50, 
    restraint = 100, 
    allowedTime = 300 
  }: Props = $props();
  
  let swipeElement: HTMLElement;
  let startX = 0;
  let startY = 0;
  let startTime = 0;
  
  const handleTouchStart = (e: TouchEvent) => {
    const touch = e.touches[0];
    startX = touch.clientX;
    startY = touch.clientY;
    startTime = Date.now();
  };
  
  const handleTouchEnd = (e: TouchEvent) => {
    const touch = e.changedTouches[0];
    const endX = touch.clientX;
    const endY = touch.clientY;
    const endTime = Date.now();
    
    const elapsedTime = endTime - startTime;
    const distanceX = Math.abs(endX - startX);
    const distanceY = Math.abs(endY - startY);
    
    // Check if swipe was fast enough
    if (elapsedTime > allowedTime) return;
    
    // Horizontal swipe
    if (distanceX >= threshold && distanceY <= restraint) {
      if (endX < startX && onSwipeLeft) {
        e.preventDefault();
        onSwipeLeft();
      } else if (endX > startX && onSwipeRight) {
        e.preventDefault();
        onSwipeRight();
      }
    }
    // Vertical swipe
    else if (distanceY >= threshold && distanceX <= restraint) {
      if (endY < startY && onSwipeUp) {
        e.preventDefault();
        onSwipeUp();
      } else if (endY > startY && onSwipeDown) {
        e.preventDefault();
        onSwipeDown();
      }
    }
  };
  
  onMount(() => {
    if (swipeElement) {
      swipeElement.addEventListener('touchstart', handleTouchStart, { passive: true });
      swipeElement.addEventListener('touchend', handleTouchEnd, { passive: false });
      
      return () => {
        if (swipeElement) {
          swipeElement.removeEventListener('touchstart', handleTouchStart);
          swipeElement.removeEventListener('touchend', handleTouchEnd);
        }
      };
    }
  });
</script>

<div 
  bind:this={swipeElement}
  class="swipe-handler"
  role="region"
  aria-label="Zona de gestos deslitzament"
>
  <slot />
</div>

<style>
  .swipe-handler {
    width: 100%;
    height: 100%;
    touch-action: pan-y; /* Allow vertical scrolling but handle horizontal swipes */
  }
  
  /* When only vertical swipes are enabled, allow horizontal scrolling */
  .swipe-handler:not(.horizontal-swipe) {
    touch-action: pan-x;
  }
  
  /* When all swipes are enabled, handle touch events manually */
  .swipe-handler.all-swipes {
    touch-action: none;
  }
</style>