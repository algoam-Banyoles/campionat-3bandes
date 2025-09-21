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
    const success = await requestNotificationPermission();
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
  .notification-permissions {
    @apply space-y-4;
  }

  .notification-permissions.compact {
    @apply space-y-2;
  }

  .alert {
    @apply flex items-start gap-3 p-4 rounded-lg border;
  }

  .alert-warning {
    @apply bg-yellow-50 border-yellow-200 text-yellow-800;
  }

  .alert-error {
    @apply bg-red-50 border-red-200 text-red-800;
  }

  .alert-success {
    @apply bg-green-50 border-green-200 text-green-800;
  }

  .alert-icon {
    @apply flex-shrink-0;
  }

  .alert-title {
    @apply font-semibold text-sm;
  }

  .alert-message {
    @apply text-sm mt-1;
  }

  .permission-request {
    @apply bg-white border border-slate-200 rounded-lg p-6;
  }

  .compact .permission-request {
    @apply p-4;
  }

  .permission-content {
    @apply flex items-start gap-4 mb-4;
  }

  .compact .permission-content {
    @apply gap-3 mb-3;
  }

  .permission-icon {
    @apply flex-shrink-0;
  }

  .permission-title {
    @apply text-lg font-semibold text-slate-900;
  }

  .compact .permission-title {
    @apply text-base;
  }

  .permission-description {
    @apply text-slate-600 mt-1;
  }

  .permission-benefits {
    @apply list-disc list-inside text-sm text-slate-600 mt-2 space-y-1;
  }

  .permission-actions {
    @apply flex gap-3 items-center;
  }

  .compact .permission-actions {
    @apply gap-2;
  }

  .explanation-box {
    @apply bg-slate-50 border border-slate-200 rounded-lg p-4 mt-3;
  }

  .btn {
    @apply inline-flex items-center px-4 py-2 rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2;
  }

  .btn-primary {
    @apply bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500;
  }

  .btn-ghost {
    @apply text-slate-600 hover:text-slate-800 hover:bg-slate-100 focus:ring-slate-500;
  }

  .btn-sm {
    @apply px-3 py-1 text-sm;
  }

  .btn:disabled {
    @apply opacity-50 cursor-not-allowed;
  }

  .loading-spinner {
    @apply inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin mr-2;
  }
</style>