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
    max-width: 42rem;
    margin: 0 auto;
    padding: 1.5rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }

  .settings-header { margin-bottom: 2rem; }
  .settings-title {
    font-size: 1.5rem;
    font-weight: 800;
    color: var(--ink, #1a1814);
    margin: 0 0 0.5rem;
    letter-spacing: -0.018em;
  }
  .settings-description { color: var(--ink-2, #4a443e); margin: 0; }

  .loading-state {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 3rem 0;
    color: var(--ink-3, #807a72);
  }
  .loading-spinner {
    width: 2rem;
    height: 2rem;
    border: 2px solid var(--rule, #e6e3dc);
    border-top-color: var(--ink, #1a1814);
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-right: 0.75rem;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .settings-form { display: flex; flex-direction: column; gap: 2rem; }

  .form-section {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 1.5rem;
  }
  .section-title {
    font-size: 1.0625rem;
    font-weight: 700;
    color: var(--ink, #1a1814);
    margin: 0 0 1rem;
    letter-spacing: -0.012em;
  }

  .form-group { margin-bottom: 1rem; }
  .form-group:last-child { margin-bottom: 0; }

  .form-row {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  @media (min-width: 640px) {
    .form-row { grid-template-columns: 1fr 1fr; }
  }

  .checkbox-label {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    cursor: pointer;
    padding: 0.75rem;
    transition: background 0.15s ease;
  }
  .checkbox-label:hover { background: var(--paper, #fbfaf6); }

  .checkbox {
    width: 1.1rem;
    height: 1.1rem;
    accent-color: var(--ink, #1a1814);
    margin-top: 0.15rem;
    cursor: pointer;
  }
  .checkbox-content { flex: 1; }
  .checkbox-title {
    display: block;
    font-weight: 600;
    color: var(--ink, #1a1814);
  }
  .checkbox-description {
    display: block;
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
    margin-top: 0.25rem;
  }

  .form-label {
    display: block;
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink-2, #4a443e);
    margin-bottom: 0.5rem;
  }
  .form-help {
    display: block;
    font-size: 0.75rem;
    color: var(--ink-3, #807a72);
    font-weight: 400;
    margin-top: 0.25rem;
  }

  .form-input,
  .form-select {
    width: 100%;
    padding: 0.6rem 0.85rem;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule-strong, #b8b3a8);
    font-family: var(--font-sans, sans-serif);
    font-size: 0.9375rem;
    color: var(--ink, #1a1814);
  }
  .form-input:focus,
  .form-select:focus {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
  .form-input:disabled,
  .form-select:disabled { opacity: 0.5; cursor: not-allowed; }

  .input-group { display: flex; align-items: center; }
  .input-suffix {
    margin-left: 0.75rem;
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
  }

  .form-actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.75rem;
    padding-top: 1.5rem;
    border-top: 1px solid var(--rule, #e6e3dc);
    flex-wrap: wrap;
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

  .btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .loading-spinner-sm {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    border: 2px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-right: 0.5rem;
  }

  .success-message {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: var(--paper, #fbfaf6);
    border: 1px solid var(--green, #1f7a3a);
    color: var(--green, #1f7a3a);
    font-size: 0.875rem;
  }

  .error-message {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: var(--paper, #fbfaf6);
    border: 1px solid var(--accent, #a30b1e);
    color: var(--accent, #a30b1e);
    font-size: 0.875rem;
  }
</style>