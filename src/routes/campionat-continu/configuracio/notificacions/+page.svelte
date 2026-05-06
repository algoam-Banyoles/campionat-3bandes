<!-- Pàgina de configuració de notificacions -->
<!-- src/routes/configuracio/notificacions/+page.svelte -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import { user } from '$lib/stores/auth';
  import { goto } from '$app/navigation';
  import NotificationPermissions from '$lib/components/general/notifications/NotificationPermissions.svelte';
  import NotificationSettings from '$lib/components/general/notifications/NotificationSettings.svelte';
  import { 
    notificationsEnabled,
    notificationHistory,
    loadNotificationHistory,
    markNotificationAsRead,
    notificationsLoading,
    initializeNotifications
  } from '$lib/stores/notifications';

  let activeTab: 'permissions' | 'settings' | 'history' = 'permissions';

  onMount(() => {
    // Comprovar autenticació
    if (!$user) {
      goto('/login');
      return;
    }

    // Inicialitzar sistema de notificacions
    initializeNotifications();
    
    // Carregar historial
    loadNotificationHistory();
  });

  function formatDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('ca-ES', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function getNotificationIcon(tipus: string): string {
    switch (tipus) {
      case 'repte_nou':
        return '🥎';
      case 'caducitat_proxima':
        return '⏰';
      case 'repte_caducat':
        return '❌';
      case 'partida_recordatori':
        return '📅';
      case 'confirmacio_requerida':
        return '❓';
      default:
        return '📢';
    }
  }

  function getNotificationTypeLabel(tipus: string): string {
    switch (tipus) {
      case 'repte_nou':
        return 'Repte nou';
      case 'caducitat_proxima':
        return 'Caducitat propera';
      case 'repte_caducat':
        return 'Repte caducat';
      case 'partida_recordatori':
        return 'Recordatori';
      case 'confirmacio_requerida':
        return 'Confirmació';
      default:
        return 'Notificació';
    }
  }

  async function handleMarkAsRead(notificationId: string) {
    await markNotificationAsRead(notificationId);
  }
</script>

<svelte:head>
  <title>Configuració de Notificacions - Campionat 3 Bandes</title>
  <meta name="description" content="Configura les teves preferències de notificacions push per reptes i partides programades" />
</svelte:head>

<div class="notif-root">
  <div class="notif-inner">
    <header class="page-mast">
      <div>
        <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Campionat continu · Configuració</div>
        <h1 class="page-title">Notificacions</h1>
        <p class="page-lede">Gestiona com i quan vols rebre notificacions sobre els teus reptes i partides.</p>
      </div>
    </header>

    <!-- Navigation Tabs -->
    <div class="border-b border-slate-200 mb-8">
      <nav class="flex space-x-8">
        <button
          class="tab-button"
          class:active={activeTab === 'permissions'}
          on:click={() => activeTab = 'permissions'}
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5z" />
          </svg>
          Permisos
        </button>
        
        <button
          class="tab-button"
          class:active={activeTab === 'settings'}
          class:disabled={!$notificationsEnabled}
          on:click={() => activeTab = 'settings'}
          disabled={!$notificationsEnabled}
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          Preferències
        </button>
        
        <button
          class="tab-button"
          class:active={activeTab === 'history'}
          class:disabled={!$notificationsEnabled}
          on:click={() => activeTab = 'history'}
          disabled={!$notificationsEnabled}
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          Historial
          {#if $notificationHistory.filter(n => !n.llegida_el).length > 0}
            <span class="notification-badge">
              {$notificationHistory.filter(n => !n.llegida_el).length}
            </span>
          {/if}
        </button>
      </nav>
    </div>

    <!-- Tab Content -->
    <div class="tab-content">
      {#if activeTab === 'permissions'}
        <div class="space-y-6">
          <NotificationPermissions showDetails={true} />
          
          {#if $notificationsEnabled}
            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
              <div class="flex items-center gap-3">
                <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <div>
                  <h3 class="font-semibold text-green-900">Notificacions habilitades</h3>
                  <p class="text-green-700 text-sm">
                    Ja pots rebre notificacions push. Personalitza les teves preferències a la pestanya "Preferències".
                  </p>
                </div>
              </div>
            </div>
          {/if}
        </div>

      {:else if activeTab === 'settings'}
        <NotificationSettings />

      {:else if activeTab === 'history'}
        <div class="notification-history">
          <div class="history-header">
            <h3 class="text-lg font-semibold text-slate-900">Historial de notificacions</h3>
            <p class="text-slate-600 text-sm">
              Les últimes 50 notificacions enviades al teu dispositiu.
            </p>
          </div>

          {#if $notificationsLoading}
            <div class="loading-state">
              <div class="loading-spinner"></div>
              <p>Carregant historial...</p>
            </div>
          {:else if $notificationHistory.length === 0}
            <div class="empty-state">
              <svg class="w-12 h-12 text-slate-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5z" />
              </svg>
              <h3 class="text-lg font-medium text-slate-900 mb-2">Cap notificació encara</h3>
              <p class="text-slate-600">
                Quan rebis notificacions, apareixeran aquí per poder revisar-les.
              </p>
            </div>
          {:else}
            <div class="history-list">
              {#each $notificationHistory as notification (notification.id)}
                <div 
                  class="history-item"
                  class:unread={!notification.llegida_el}
                >
                  <div class="history-icon">
                    {getNotificationIcon(notification.tipus)}
                  </div>
                  
                  <div class="history-content">
                    <div class="history-header-row">
                      <h4 class="history-title">{notification.titol}</h4>
                      <div class="history-meta">
                        <span class="history-type">
                          {getNotificationTypeLabel(notification.tipus)}
                        </span>
                        <span class="history-date">
                          {formatDate(notification.enviada_el)}
                        </span>
                      </div>
                    </div>
                    
                    <p class="history-message">{notification.missatge}</p>
                    
                    {#if !notification.llegida_el}
                      <button
                        class="mark-read-btn"
                        on:click={() => handleMarkAsRead(notification.id)}
                      >
                        Marcar com llegida
                      </button>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .notif-root {
    width: 100%;
    padding: 1.5rem 1rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .notif-inner {
    max-width: 56rem;
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  .page-mast { padding-bottom: 1rem; border-bottom: 2px solid var(--ink); }
  .editorial-eyebrow {
    font-size: 0.75rem; font-weight: 600;
    letter-spacing: 0.16em; text-transform: uppercase;
    color: var(--sec-continu);
  }
  .page-title {
    font-weight: 800; font-size: 2rem;
    letter-spacing: -0.025em; line-height: 1.05;
    margin: 0; color: var(--ink);
  }
  .page-lede {
    margin: 0.4rem 0 0;
    font-size: 0.875rem;
    color: var(--ink-2);
  }

  .tab-button {
    display: inline-flex;
    align-items: center;
    padding: 0.85rem 0;
    margin-right: 1.75rem;
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    color: var(--ink-3);
    font-family: var(--font-sans);
    font-weight: 500;
    font-size: 0.9375rem;
    cursor: pointer;
    min-height: 48px;
    letter-spacing: -0.005em;
  }
  .tab-button:hover { color: var(--ink-2); }
  .tab-button.active {
    color: var(--ink);
    font-weight: 700;
    border-bottom-color: var(--ink);
  }
  .tab-button.disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .notification-badge {
    margin-left: 0.55rem;
    padding: 0.18rem 0.45rem;
    font-size: 0.625rem;
    font-weight: 700;
    color: white;
    background: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.12em;
  }

  .tab-content { min-height: 24rem; }

  .notification-history {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .history-header { margin-bottom: 1rem; }

  .loading-state {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2.5rem 1rem;
    color: var(--ink-2);
  }
  .loading-spinner {
    width: 1.5rem; height: 1.5rem;
    border: 2px solid var(--rule);
    border-top-color: var(--ink);
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-right: 0.75rem;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .empty-state {
    text-align: center;
    padding: 2.5rem 1.5rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
  }

  .history-list {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }
  .history-item {
    display: flex;
    gap: 1rem;
    padding: 0.85rem 1rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
  }
  .history-item.unread {
    border-left: 3px solid var(--blue);
  }
  .history-icon { font-size: 1.5rem; flex-shrink: 0; }
  .history-content { flex: 1; min-width: 0; }
  .history-header-row {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 0.4rem;
    align-items: flex-start;
  }
  .history-title {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .history-meta {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.25rem;
    font-size: 0.6875rem;
    color: var(--ink-3);
    flex-shrink: 0;
  }
  .history-type {
    padding: 0.18rem 0.5rem;
    background: var(--paper);
    border: 1px solid var(--rule-strong);
    color: var(--ink-2);
    text-transform: uppercase;
    letter-spacing: 0.12em;
    font-weight: 600;
  }
  .history-message {
    color: var(--ink-2);
    margin-bottom: 0.65rem;
    font-size: 0.875rem;
    line-height: 1.5;
  }
  .mark-read-btn {
    background: transparent;
    border: none;
    padding: 0;
    color: var(--blue);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.8125rem;
    cursor: pointer;
    border-bottom: 1px solid var(--blue);
    padding-bottom: 1px;
  }
  .mark-read-btn:hover { color: var(--ink); border-color: var(--ink); }
</style>