<!-- Component per configurar preferències de notificacions -->
<!-- src/lib/components/notifications/NotificationSettings.svelte -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    notificationPreferences,
    notificationsLoading,
    notificationsError,
    loadNotificationPreferences,
    updateNotificationPreferences,
    type NotificationPreferences
  } from '$lib/stores/notifications';

  // Valors locals per al formulari
  let formData: Partial<NotificationPreferences> = {
    reptes_nous: true,
    caducitat_terminis: true,
    recordatoris_partides: true,
    hores_abans_recordatori: 24,
    minuts_abans_caducitat: 1440, // 24 hores
    silenci_nocturn: true,
    hora_inici_silenci: '22:00:00',
    hora_fi_silenci: '08:00:00'
  };

  let hasChanges = false;
  let saveMessage = '';

  onMount(() => {
    loadNotificationPreferences();
  });

  // Sincronitzar dades del store amb el formulari
  $: if ($notificationPreferences) {
    formData = { ...$notificationPreferences };
    hasChanges = false;
  }

  // Detectar canvis en el formulari
  function handleInputChange() {
    hasChanges = true;
    saveMessage = '';
  }

  // Guardar preferències
  async function savePreferences() {
    const success = await updateNotificationPreferences(formData);
    if (success) {
      hasChanges = false;
      saveMessage = 'Preferències guardades correctament';
      setTimeout(() => {
        saveMessage = '';
      }, 3000);
    }
  }

  // Restaurar valors originals
  function resetForm() {
    if ($notificationPreferences) {
      formData = { ...$notificationPreferences };
    }
    hasChanges = false;
    saveMessage = '';
  }

  // Convertir minuts a format llegible
  function minutsToHours(minuts: number): string {
    const hores = Math.floor(minuts / 60);
    const minutsRestants = minuts % 60;
    
    if (hores === 0) {
      return `${minutsRestants} minuts`;
    } else if (minutsRestants === 0) {
      return `${hores} ${hores === 1 ? 'hora' : 'hores'}`;
    } else {
      return `${hores}h ${minutsRestants}m`;
    }
  }

  // Opcions predefinides per recordatoris
  const recordatoriOptions = [
    { value: 60, label: '1 hora abans' },
    { value: 120, label: '2 hores abans' },
    { value: 360, label: '6 hores abans' },
    { value: 720, label: '12 hores abans' },
    { value: 1440, label: '1 dia abans' },
    { value: 2880, label: '2 dies abans' }
  ];
</script>

<div class="notification-settings">
  <div class="settings-header">
    <h2 class="settings-title">Configuració de notificacions</h2>
    <p class="settings-description">
      Personalitza quan i com vols rebre notificacions del campionat.
    </p>
  </div>

  {#if $notificationsLoading}
    <div class="loading-state">
      <div class="loading-spinner"></div>
      <p>Carregant preferències...</p>
    </div>
  {:else}
    <form class="settings-form" on:submit|preventDefault={savePreferences}>
      <!-- Tipus de notificacions -->
      <div class="form-section">
        <h3 class="section-title">Tipus de notificacions</h3>
        
        <div class="form-group">
          <label class="checkbox-label">
            <input
              type="checkbox"
              bind:checked={formData.reptes_nous}
              on:change={handleInputChange}
              class="checkbox"
            />
            <div class="checkbox-content">
              <span class="checkbox-title">Reptes nous</span>
              <span class="checkbox-description">
                Quan algú et proposa un nou repte
              </span>
            </div>
          </label>
        </div>

        <div class="form-group">
          <label class="checkbox-label">
            <input
              type="checkbox"
              bind:checked={formData.caducitat_terminis}
              on:change={handleInputChange}
              class="checkbox"
            />
            <div class="checkbox-content">
              <span class="checkbox-title">Caducitat de terminis</span>
              <span class="checkbox-description">
                Recordatoris abans que caduquin els reptes
              </span>
            </div>
          </label>
        </div>

        <div class="form-group">
          <label class="checkbox-label">
            <input
              type="checkbox"
              bind:checked={formData.recordatoris_partides}
              on:change={handleInputChange}
              class="checkbox"
            />
            <div class="checkbox-content">
              <span class="checkbox-title">Recordatoris de partides</span>
              <span class="checkbox-description">
                Quan tens una partida programada
              </span>
            </div>
          </label>
        </div>
      </div>

      <!-- Temporització -->
      <div class="form-section">
        <h3 class="section-title">Temporització</h3>
        
        <div class="form-group">
          <label class="form-label" for="recordatori-caducitat">
            Recordatori de caducitat
            <span class="form-help">Quan avisar abans que caduqui un repte</span>
          </label>
          <select
            id="recordatori-caducitat"
            bind:value={formData.minuts_abans_caducitat}
            on:change={handleInputChange}
            disabled={!formData.caducitat_terminis}
            class="form-select"
          >
            {#each recordatoriOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>

        <div class="form-group">
          <label class="form-label" for="recordatori-partides">
            Recordatori de partides
            <span class="form-help">Quan avisar abans d'una partida programada</span>
          </label>
          <div class="input-group">
            <input
              id="recordatori-partides"
              type="number"
              min="1"
              max="168"
              bind:value={formData.hores_abans_recordatori}
              on:input={handleInputChange}
              disabled={!formData.recordatoris_partides}
              class="form-input"
            />
            <span class="input-suffix">hores abans</span>
          </div>
        </div>
      </div>

      <!-- Mode silenciós -->
      <div class="form-section">
        <h3 class="section-title">Mode silenciós</h3>
        
        <div class="form-group">
          <label class="checkbox-label">
            <input
              type="checkbox"
              bind:checked={formData.silenci_nocturn}
              on:change={handleInputChange}
              class="checkbox"
            />
            <div class="checkbox-content">
              <span class="checkbox-title">Silenci nocturn</span>
              <span class="checkbox-description">
                No enviar notificacions durant les hores de descans
              </span>
            </div>
          </label>
        </div>

        {#if formData.silenci_nocturn}
          <div class="form-row">
            <div class="form-group">
              <label class="form-label" for="inici-silenci">Inici del silenci</label>
              <input
                id="inici-silenci"
                type="time"
                bind:value={formData.hora_inici_silenci}
                on:change={handleInputChange}
                class="form-input"
              />
            </div>
            
            <div class="form-group">
              <label class="form-label" for="fi-silenci">Fi del silenci</label>
              <input
                id="fi-silenci"
                type="time"
                bind:value={formData.hora_fi_silenci}
                on:change={handleInputChange}
                class="form-input"
              />
            </div>
          </div>
        {/if}
      </div>

      <!-- Accions -->
      <div class="form-actions">
        {#if hasChanges}
          <button
            type="button"
            on:click={resetForm}
            class="btn btn-ghost"
          >
            Cancel·lar
          </button>
        {/if}
        
        <button
          type="submit"
          disabled={!hasChanges || $notificationsLoading}
          class="btn btn-primary"
        >
          {#if $notificationsLoading}
            <span class="loading-spinner-sm"></span>
            Guardant...
          {:else}
            Guardar preferències
          {/if}
        </button>
      </div>

      <!-- Missatges -->
      {#if saveMessage}
        <div class="success-message">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          {saveMessage}
        </div>
      {/if}

      {#if $notificationsError}
        <div class="error-message">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          {$notificationsError}
        </div>
      {/if}
    </form>
  {/if}
</div>

<style>
  .notification-settings {
    @apply max-w-2xl mx-auto p-6;
  }

  .settings-header {
    @apply mb-8;
  }

  .settings-title {
    @apply text-2xl font-bold text-slate-900 mb-2;
  }

  .settings-description {
    @apply text-slate-600;
  }

  .loading-state {
    @apply flex items-center justify-center py-12 text-slate-600;
  }

  .loading-spinner {
    @apply w-8 h-8 border-2 border-slate-300 border-t-blue-600 rounded-full animate-spin mr-3;
  }

  .settings-form {
    @apply space-y-8;
  }

  .form-section {
    @apply bg-white border border-slate-200 rounded-lg p-6;
  }

  .section-title {
    @apply text-lg font-semibold text-slate-900 mb-4;
  }

  .form-group {
    @apply mb-4 last:mb-0;
  }

  .form-row {
    @apply grid grid-cols-1 sm:grid-cols-2 gap-4;
  }

  .checkbox-label {
    @apply flex items-start gap-3 cursor-pointer p-3 rounded-lg hover:bg-slate-50 transition-colors;
  }

  .checkbox {
    @apply w-5 h-5 text-blue-600 border-slate-300 rounded focus:ring-blue-500 focus:ring-2 mt-0.5;
  }

  .checkbox-content {
    @apply flex-1;
  }

  .checkbox-title {
    @apply block font-medium text-slate-900;
  }

  .checkbox-description {
    @apply block text-sm text-slate-600 mt-1;
  }

  .form-label {
    @apply block text-sm font-medium text-slate-700 mb-2;
  }

  .form-help {
    @apply block text-xs text-slate-500 font-normal mt-1;
  }

  .form-input {
    @apply w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50 disabled:cursor-not-allowed;
  }

  .form-select {
    @apply w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50 disabled:cursor-not-allowed;
  }

  .input-group {
    @apply flex items-center;
  }

  .input-suffix {
    @apply ml-3 text-sm text-slate-600;
  }

  .form-actions {
    @apply flex items-center justify-end gap-3 pt-6 border-t border-slate-200;
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

  .btn:disabled {
    @apply opacity-50 cursor-not-allowed;
  }

  .loading-spinner-sm {
    @apply inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin mr-2;
  }

  .success-message {
    @apply flex items-center gap-2 p-3 bg-green-50 border border-green-200 text-green-800 rounded-lg;
  }

  .error-message {
    @apply flex items-center gap-2 p-3 bg-red-50 border border-red-200 text-red-800 rounded-lg;
  }
</style>