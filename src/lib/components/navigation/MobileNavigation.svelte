<script lang="ts">
  import { onMount } from 'svelte';
  import HamburgerMenu from './HamburgerMenu.svelte';
  import BottomTabBar from './BottomTabBar.svelte';
  
  let isMobile = $state(false);
  let showBottomBar = $state(false);
  
  onMount(() => {
    const checkMobile = () => {
      isMobile = window.innerWidth <= 768;
      showBottomBar = window.innerWidth <= 640;
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    
    return () => window.removeEventListener('resize', checkMobile);
  });
</script>

<div class="mobile-navigation">
  <!-- Top navigation with hamburger menu (visible on mobile) -->
  {#if isMobile}
    <header class="top-nav">
      <div class="nav-content">
        <HamburgerMenu />
        <div class="nav-title">
          <h1>3Bandes</h1>
        </div>
        <div class="nav-actions">
          <!-- Space for future actions like notifications, user menu, etc. -->
        </div>
      </div>
    </header>
  {/if}
  
  <!-- Bottom tab bar (visible on small mobile screens) -->
  {#if showBottomBar}
    <BottomTabBar />
  {/if}
</div>

<style>
  .mobile-navigation {
    position: relative;
  }
  
  .top-nav {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    background-color: white;
    border-bottom: 1px solid #e5e7eb;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    z-index: 50;
    height: 56px;
  }
  
  .nav-content {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 100%;
    padding: 0 1rem;
    max-width: 100%;
  }
  
  .nav-title {
    flex: 1;
    text-align: center;
  }
  
  .nav-title h1 {
    margin: 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: #3b82f6;
  }
  
  .nav-actions {
    min-width: 44px;
    display: flex;
    justify-content: flex-end;
  }
  
  /* Add top padding to body when mobile nav is shown */
  :global(body.mobile-nav-active) {
    padding-top: 56px;
  }
  
  @media (max-width: 768px) {
    :global(body) {
      padding-top: 56px;
    }
  }
</style>