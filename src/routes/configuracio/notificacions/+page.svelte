<!-- Pàgina de configuració de notificacions -->
<!-- src/routes/configuracio/notificacions/+page.svelte -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import { user } from '$lib/stores/auth';
  import { goto } from '$app/navigation';
  import NotificationPermissions from '$lib/components/notifications/NotificationPermissions.svelte';
  import NotificationSettings from '$lib/components/notifications/NotificationSettings.svelte';
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

<div class="container mx-auto px-4 py-8">
  <div class="max-w-4xl mx-auto">
    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-slate-900 mb-2">
        Configuració de Notificacions
      </h1>
      <p class="text-slate-600">
        Gestiona com i quan vols rebre notificacions sobre els teus reptes i partides.
      </p>
    </div>

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
  .tab-button {
    @apply flex items-center px-1 py-4 border-b-2 border-transparent text-sm font-medium text-slate-500 hover:text-slate-700 hover:border-slate-300 transition-colors;
  }

  .tab-button.active {
    @apply text-blue-600 border-blue-500;
  }

  .tab-button.disabled {
    @apply opacity-50 cursor-not-allowed;
  }

  .notification-badge {
    @apply ml-2 px-2 py-1 text-xs bg-red-500 text-white rounded-full;
  }

  .tab-content {
    @apply min-h-[400px];
  }

  .notification-history {
    @apply space-y-6;
  }

  .history-header {
    @apply mb-6;
  }

  .loading-state {
    @apply flex items-center justify-center py-12 text-slate-600;
  }

  .loading-spinner {
    @apply w-8 h-8 border-2 border-slate-300 border-t-blue-600 rounded-full animate-spin mr-3;
  }

  .empty-state {
    @apply text-center py-12;
  }

  .history-list {
    @apply space-y-4;
  }

  .history-item {
    @apply flex gap-4 p-4 bg-white border border-slate-200 rounded-lg hover:shadow-sm transition-shadow;
  }

  .history-item.unread {
    @apply border-blue-200 bg-blue-50;
  }

  .history-icon {
    @apply text-2xl flex-shrink-0;
  }

  .history-content {
    @apply flex-1 min-w-0;
  }

  .history-header-row {
    @apply flex items-start justify-between gap-4 mb-2;
  }

  .history-title {
    @apply font-semibold text-slate-900;
  }

  .history-meta {
    @apply flex flex-col items-end gap-1 text-xs text-slate-500 flex-shrink-0;
  }

  .history-type {
    @apply px-2 py-1 bg-slate-100 text-slate-700 rounded-full;
  }

  .history-message {
    @apply text-slate-600 mb-3;
  }

  .mark-read-btn {
    @apply text-sm text-blue-600 hover:text-blue-800 font-medium;
  }
</style>