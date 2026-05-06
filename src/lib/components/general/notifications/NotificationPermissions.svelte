<!-- Component per gestionar permisos de notificacions push -->
<!-- src/lib/components/notifications/NotificationPermissions.svelte -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    pushSupported,
    pushPermission,
    notificationsEnabled,
    notificationsLoading,
    notificationsError,
    initializeNotifications,
    requestNotificationPermission,
    subscribeToPush,
    unsubscribeFromPush
  } from '$lib/stores/notifications';
  
  export let compact: boolean = false;
  export let showDetails: boolean = true;

  let showExplanation = false;

  onMount(() => {
    initializeNotifications();
  });

  async function handleEnableNotifications() {
    console.log('🔔 Intentant habilitar notificacions...');
    console.log('Permís actual:', Notification.permission);
    
    // Intentar sol·licitar permisos directament primer
    if (Notification.permission === 'default') {
      try {
        const directPermission = await Notification.requestPermission();
        console.log('Permís directe:', directPermission);
        
        if (directPermission === 'granted') {
          // Procedir amb la subscripció
          const success = await requestNotificationPermission();
          console.log('Subscripció exitosa:', success);
          return;
        }
      } catch (error) {
        console.error('Error sol·licitant permisos directament:', error);
      }
    }
    
    // Si no funciona, usar el mètode del store
    const success = await requestNotificationPermission();
    console.log('Resultat del store:', success);
    
    if (!success) {
      showExplanation = true;
    }
  }

  async function handleDisableNotifications() {
    await unsubscribeFromPush();
  }

  function getBrowserInstructions(): string {
    const userAgent = navigator.userAgent.toLowerCase();
    
    if (userAgent.includes('chrome')) {
      return 'Fes clic a la icona del cadenat a la barra d\'adreces i permet les notificacions.';
    } else if (userAgent.includes('firefox')) {
      return 'Fes clic a l\'icona d\'informació a la barra d\'adreces i permet les notificacions.';
    } else if (userAgent.includes('safari')) {
      return 'Ves a Preferències del Safari > Llocs web > Notificacions i permet aquest lloc.';
    } else {
      return 'Comprova la configuració del navegador per permetre notificacions d\'aquest lloc web.';
    }
  }
</script>

<div class="notification-permissions" class:compact>
  {#if !$pushSupported}
    <div class="alert alert-warning">
      <div class="alert-icon">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.99-.833-2.75 0L4.064 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
      </div>
      <div>
        <h3 class="alert-title">Notificacions no compatibles</h3>
        <p class="alert-message">El teu navegador no suporta notificacions push. Prova amb un navegador més recent.</p>
      </div>
    </div>
  {:else if $pushPermission === 'denied'}
    <div class="alert alert-error">
      <div class="alert-icon">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728A9 9 0 015.636 5.636" />
        </svg>
      </div>
      <div>
        <h3 class="alert-title">Notificacions bloquejades</h3>
        <p class="alert-message">
          Has bloquejat les notificacions per aquest lloc web. 
          {#if showDetails}
            Per rebre notificacions dels teus reptes, cal que les permetis manualment.
          {/if}
        </p>
        {#if showDetails}
          <div class="mt-2">
            <button 
              on:click={() => showExplanation = !showExplanation}
              class="text-sm underline text-red-700 hover:text-red-800"
            >
              Com permetre notificacions?
            </button>
          </div>
        {/if}
      </div>
    </div>

    {#if showExplanation}
      <div class="explanation-box">
        <h4 class="font-medium mb-2">Com permetre notificacions:</h4>
        <p class="text-sm text-slate-600 mb-3">
          {getBrowserInstructions()}
        </p>
        <p class="text-sm text-slate-600">
          Després de canviar la configuració, recarga la pàgina per aplicar els canvis.
        </p>
      </div>
    {/if}
  {:else if $pushPermission === 'default'}
    <div class="permission-request">
      <div class="permission-content">
        <div class="permission-icon">
          <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5zM4.086 9.086a2 2 0 000 2.828l8.5 8.5a2 2 0 002.828 0L21 14.828a2 2 0 000-2.828l-8.5-8.5a2 2 0 00-2.828 0L4.086 9.086z" />
          </svg>
        </div>
        
        <div class="permission-text">
          <h3 class="permission-title">Habilitar notificacions</h3>
          {#if showDetails}
            <p class="permission-description">
              Rebre notificacions instantànies quan:
            </p>
            <ul class="permission-benefits">
              <li>Reps un nou repte</li>
              <li>Un repte està a punt de caducar</li>
              <li>Tens una partida programada</li>
              <li>Cal confirmar la teva assistència</li>
            </ul>
          {:else}
            <p class="permission-description">
              Mantén-te al dia amb els teus reptes i partides
            </p>
          {/if}
        </div>
      </div>

      <div class="permission-actions">
        <button
          on:click={handleEnableNotifications}
          disabled={$notificationsLoading}
          class="btn btn-primary"
        >
          {#if $notificationsLoading}
            <span class="loading-spinner"></span>
            Habilitant...
          {:else}
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5z" />
            </svg>
            Habilitar notificacions
          {/if}
        </button>
        
        {#if !compact}
          <button
            on:click={() => showExplanation = !showExplanation}
            class="btn btn-ghost text-sm"
          >
            Més informació
          </button>
        {/if}
      </div>
    </div>

    {#if showExplanation && !compact}
      <div class="explanation-box">
        <h4 class="font-medium mb-2">Sobre les notificacions:</h4>
        <ul class="text-sm text-slate-600 space-y-1">
          <li>• Les notificacions només s'envien per esdeveniments importants</li>
          <li>• Pots configurar quins tipus de notificacions vols rebre</li>
          <li>• Pots desactivar les notificacions en qualsevol moment</li>
          <li>• Les notificacions respecten el mode "No molestar" del teu dispositiu</li>
        </ul>
      </div>
    {/if}
  {:else if $notificationsEnabled}
    <div class="alert alert-success">
      <div class="alert-icon">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
      <div class="flex-1">
        <h3 class="alert-title">Notificacions habilitades</h3>
        <p class="alert-message">
          Rebraràs notificacions per reptes nous i recordatoris de partides.
        </p>
      </div>
      
      {#if showDetails}
        <button
          on:click={handleDisableNotifications}
          disabled={$notificationsLoading}
          class="btn btn-ghost btn-sm"
        >
          {#if $notificationsLoading}
            Deshabilitant...
          {:else}
            Deshabilitar
          {/if}
        </button>
      {/if}
    </div>
  {/if}

  {#if $notificationsError}
    <div class="alert alert-error mt-3">
      <div class="alert-icon">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
      <div>
        <h3 class="alert-title">Error</h3>
        <p class="alert-message">{$notificationsError}</p>
      </div>
    </div>
  {/if}
</div>

<style>
  .notification-permissions { display: flex; flex-direction: column; gap: 1rem; }
  .notification-permissions.compact { gap: 0.5rem; }

  .alert {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 1rem;
    border: 1px solid var(--rule, #e6e3dc);
    background: var(--paper, #fbfaf6);
  }
  .alert-warning { border-color: var(--amber, #b8860b); color: var(--amber, #b8860b); }
  .alert-error { border-color: var(--accent, #a30b1e); color: var(--accent, #a30b1e); }
  .alert-success { border-color: var(--green, #1f7a3a); color: var(--green, #1f7a3a); }

  .alert-icon { flex-shrink: 0; }
  .alert-title { font-weight: 600; font-size: 0.875rem; }
  .alert-message { font-size: 0.875rem; margin-top: 0.25rem; }

  .permission-request {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 1.5rem;
    font-family: var(--font-sans, sans-serif);
  }
  .compact .permission-request { padding: 1rem; }

  .permission-content {
    display: flex;
    align-items: flex-start;
    gap: 1rem;
    margin-bottom: 1rem;
  }
  .compact .permission-content { gap: 0.75rem; margin-bottom: 0.75rem; }

  .permission-icon { flex-shrink: 0; }

  .permission-title {
    font-size: 1.125rem;
    font-weight: 700;
    color: var(--ink, #1a1814);
    letter-spacing: -0.01em;
  }
  .compact .permission-title { font-size: 1rem; }

  .permission-description {
    color: var(--ink-2, #4a443e);
    margin-top: 0.25rem;
    font-size: 0.9375rem;
  }

  .permission-benefits {
    list-style: disc inside;
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
    margin-top: 0.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .permission-actions {
    display: flex;
    gap: 0.75rem;
    align-items: center;
    flex-wrap: wrap;
  }
  .compact .permission-actions { gap: 0.5rem; }

  .explanation-box {
    background: var(--paper, #fbfaf6);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 1rem;
    margin-top: 0.75rem;
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
  }

  .btn {
    display: inline-flex;
    align-items: center;
    padding: 0.55rem 1rem;
    font-family: var(--font-sans, sans-serif);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    border: 1px solid transparent;
    transition: opacity 0.15s ease, background 0.15s ease, color 0.15s ease;
  }
  .btn:focus-visible {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: 2px;
  }

  .btn-primary {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
    border-color: var(--ink, #1a1814);
  }
  .btn-primary:hover:not(:disabled) { opacity: 0.9; }

  .btn-ghost {
    background: transparent;
    color: var(--ink-2, #4a443e);
    border-color: var(--rule-strong, #b8b3a8);
  }
  .btn-ghost:hover:not(:disabled) {
    color: var(--ink, #1a1814);
    border-color: var(--ink, #1a1814);
    background: var(--paper, #fbfaf6);
  }

  .btn-sm { padding: 0.35rem 0.75rem; font-size: 0.8125rem; }

  .btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .loading-spinner {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    border: 2px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-right: 0.5rem;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>