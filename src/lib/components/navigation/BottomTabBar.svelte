<script lang="ts">
  import { page } from '$app/stores';
  
  const tabItems = [
    { href: '/', label: 'Inici', icon: '🏠' },
    { href: '/ranking', label: 'Ranking', icon: '🏆' },
    { href: '/reptes', label: 'Reptes', icon: '⚔️' },
    { href: '/calendari', label: 'Calendari', icon: '📅' },
    { href: '/historial', label: 'Historial', icon: '📊' }
  ];
  
  // Function to determine if a tab is active
  const isActive = (href: string, pathname: string) => {
    if (href === '/') {
      return pathname === '/';
    }
    return pathname.startsWith(href);
  };
</script>

<nav class="bottom-tab-bar" aria-label="Navegació principal">
  {#each tabItems as tab}
    <a 
      href={tab.href} 
      class="tab-item"
      class:active={isActive(tab.href, $page.url.pathname)}
      aria-label={tab.label}
    >
      <span class="tab-icon" role="img" aria-hidden="true">{tab.icon}</span>
      <span class="tab-label">{tab.label}</span>
    </a>
  {/each}
</nav>

<style>
  .bottom-tab-bar {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    background-color: white;
    border-top: 1px solid #e5e7eb;
    box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
    z-index: 100;
    height: 64px;
    padding-bottom: env(safe-area-inset-bottom);
  }
  
  .tab-item {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 8px 4px;
    text-decoration: none;
    color: #6b7280;
    transition: all 0.2s ease;
    min-height: 64px;
    position: relative;
  }
  
  .tab-item:hover {
    background-color: #f9fafb;
  }
  
  .tab-item:focus-visible {
    outline: 2px solid #3b82f6;
    outline-offset: -2px;
  }
  
  .tab-item.active {
    color: #3b82f6;
  }
  
  .tab-item.active::before {
    content: '';
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 32px;
    height: 3px;
    background-color: #3b82f6;
    border-radius: 0 0 2px 2px;
  }
  
  .tab-icon {
    font-size: 1.25rem;
    margin-bottom: 2px;
    display: block;
  }
  
  .tab-label {
    font-size: 0.75rem;
    font-weight: 500;
    text-align: center;
    line-height: 1;
  }
  
  /* Add bottom padding to body to account for fixed bottom bar */
  :global(body) {
    padding-bottom: 64px;
  }
  
  @media (max-width: 480px) {
    .tab-label {
      font-size: 0.625rem;
    }
    
    .tab-icon {
      font-size: 1.125rem;
    }
  }
  
  @media (max-width: 360px) {
    .tab-item {
      padding: 6px 2px;
    }
    
    .tab-label {
      display: none;
    }
    
    .tab-icon {
      font-size: 1.5rem;
    }
    
    .bottom-tab-bar {
      height: 56px;
    }
    
    :global(body) {
      padding-bottom: 56px;
    }
  }
</style>