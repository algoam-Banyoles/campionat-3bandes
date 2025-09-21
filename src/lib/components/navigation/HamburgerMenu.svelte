<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  
  let isOpen = $state(false);
  let menuRef: HTMLElement;
  
  const toggleMenu = () => {
    isOpen = !isOpen;
  };
  
  const closeMenu = () => {
    isOpen = false;
  };
  
  // Close menu when clicking outside
  onMount(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef && !menuRef.contains(event.target as Node)) {
        closeMenu();
      }
    };
    
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  });
  
  // Close menu on route change
  $effect(() => {
    $page.url.pathname;
    closeMenu();
  });
  
  const menuItems = [
    { href: '/', label: 'Inici', icon: '🏠' },
    { href: '/ranking', label: 'Ranking', icon: '🏆' },
    { href: '/reptes', label: 'Reptes', icon: '⚔️' },
    { href: '/calendari', label: 'Calendari', icon: '📅' },
    { href: '/historial', label: 'Historial', icon: '📊' },
    { href: '/configuracio/notificacions', label: 'Notificacions', icon: '🔔' }
  ];
</script>

<div class="hamburger-container" bind:this={menuRef}>
  <!-- Hamburger Button -->
  <button 
    class="hamburger-btn" 
    class:open={isOpen}
    onclick={toggleMenu}
    aria-label="Menu principal"
    aria-expanded={isOpen}
  >
    <span class="hamburger-line"></span>
    <span class="hamburger-line"></span>
    <span class="hamburger-line"></span>
  </button>
  
  <!-- Menu Overlay -->
  {#if isOpen}
    <div 
      class="menu-overlay" 
      onclick={closeMenu}
      onkeydown={(e) => e.key === 'Escape' && closeMenu()}
      role="button"
      tabindex="-1"
      aria-label="Tancar menu"
    ></div>
  {/if}
  
  <!-- Menu Panel -->
  <nav class="menu-panel" class:open={isOpen}>
    <div class="menu-header">
      <h2>3Bandes</h2>
      <button class="close-btn" onclick={closeMenu} aria-label="Tancar menu">
        ✕
      </button>
    </div>
    
    <ul class="menu-items">
      {#each menuItems as item}
        <li>
          <a 
            href={item.href} 
            class="menu-item"
            class:active={$page.url.pathname === item.href}
            onclick={closeMenu}
          >
            <span class="menu-icon">{item.icon}</span>
            <span class="menu-label">{item.label}</span>
          </a>
        </li>
      {/each}
    </ul>
  </nav>
</div>

<style>
  .hamburger-container {
    position: relative;
    z-index: 1000;
  }
  
  .hamburger-btn {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    width: 44px;
    height: 44px;
    background: none;
    border: none;
    cursor: pointer;
    padding: 8px;
    border-radius: 8px;
    transition: background-color 0.2s ease;
  }
  
  .hamburger-btn:hover {
    background-color: rgba(59, 130, 246, 0.1);
  }
  
  .hamburger-btn:focus-visible {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }
  
  .hamburger-line {
    display: block;
    width: 24px;
    height: 3px;
    background-color: #374151;
    margin: 2px 0;
    border-radius: 2px;
    transition: all 0.3s ease;
    transform-origin: center;
  }
  
  .hamburger-btn.open .hamburger-line:nth-child(1) {
    transform: rotate(45deg) translate(7px, 7px);
  }
  
  .hamburger-btn.open .hamburger-line:nth-child(2) {
    opacity: 0;
    transform: scaleX(0);
  }
  
  .hamburger-btn.open .hamburger-line:nth-child(3) {
    transform: rotate(-45deg) translate(7px, -7px);
  }
  
  .menu-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5);
    z-index: 998;
    animation: fadeIn 0.3s ease;
  }
  
  .menu-panel {
    position: fixed;
    top: 0;
    left: -300px;
    width: 300px;
    height: 100vh;
    background-color: white;
    box-shadow: 2px 0 10px rgba(0, 0, 0, 0.1);
    z-index: 999;
    transition: left 0.3s ease;
    overflow-y: auto;
  }
  
  .menu-panel.open {
    left: 0;
  }
  
  .menu-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #e5e7eb;
    background-color: #f9fafb;
  }
  
  .menu-header h2 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
    color: #3b82f6;
  }
  
  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    color: #6b7280;
    transition: background-color 0.2s ease;
  }
  
  .close-btn:hover {
    background-color: rgba(0, 0, 0, 0.1);
  }
  
  .menu-items {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  
  .menu-item {
    display: flex;
    align-items: center;
    padding: 1rem;
    text-decoration: none;
    color: #374151;
    border-bottom: 1px solid #f3f4f6;
    transition: background-color 0.2s ease;
    min-height: 60px;
  }
  
  .menu-item:hover,
  .menu-item:focus {
    background-color: #f9fafb;
  }
  
  .menu-item.active {
    background-color: #eff6ff;
    color: #3b82f6;
    border-left: 4px solid #3b82f6;
  }
  
  .menu-icon {
    font-size: 1.25rem;
    margin-right: 12px;
    min-width: 28px;
  }
  
  .menu-label {
    font-size: 1rem;
    font-weight: 500;
  }
  
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  
  @media (max-width: 320px) {
    .menu-panel {
      width: 280px;
      left: -280px;
    }
  }
</style>