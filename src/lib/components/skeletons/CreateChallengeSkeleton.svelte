<script lang="ts">
  import SkeletonLoader from './SkeletonLoader.svelte';
  
  export let showValidation: boolean = true;
  export let showRules: boolean = true;
  export let compact: boolean = false;
  export let offline: boolean = false;
  export let theme: 'billiard' | 'default' = 'billiard';
  export let currentPlayerPosition: number = 10; // Simular posició actual
  export let showPositionLimits: boolean = true;

  // Determinar quines posicions són vàlides per desafiar (+1, +2)
  function getValidTargetPositions(): number[] {
    const validPositions = [];
    if (currentPlayerPosition > 1) {
      validPositions.push(currentPlayerPosition - 1); // +1 posició
    }
    if (currentPlayerPosition > 2) {
      validPositions.push(currentPlayerPosition - 2); // +2 posicions
    }
    return validPositions;
  }

  // Obtenir urgència basada en la validació
  function getValidationUrgency(fieldType: string): 'safe' | 'warning' | 'critical' | 'none' {
    switch (fieldType) {
      case 'opponent': return showValidation ? 'safe' : 'warning';
      case 'position': return showValidation ? 'safe' : 'critical';
      case 'deadline': return 'warning';
      case 'rules': return 'none';
      default: return 'none';
    }
  }

  $: validPositions = getValidTargetPositions();
  $: canChallenge = validPositions.length > 0;
</script>

<div class="create-challenge-skeleton" class:compact>
  <!-- Header -->
  <div class="skeleton-header">
    <div class="skeleton-title">
      <SkeletonLoader 
        width="150px"
        height="28px"
        variant="text"
        {theme}
        {offline}
      />
    </div>
    
    {#if showPositionLimits}
      <div class="skeleton-position-info">
        <SkeletonLoader 
          width="180px"
          height="20px"
          variant="rectangular"
          borderRadius="10px"
          {theme}
          urgency={canChallenge ? 'safe' : 'critical'}
          {offline}
        />
      </div>
    {/if}
  </div>

  <!-- Informació jugador actual -->
  <div class="skeleton-current-player">
    <div class="skeleton-player-card">
      <SkeletonLoader 
        width={compact ? '40px' : '56px'}
        height={compact ? '40px' : '56px'}
        variant="circular"
        {theme}
        {offline}
      />
      <div class="skeleton-player-info">
        <SkeletonLoader 
          width="120px"
          height="18px"
          variant="text"
          {theme}
          {offline}
        />
        <SkeletonLoader 
          width="80px"
          height="14px"
          variant="text"
          {theme}
          urgency="safe"
          {offline}
        />
      </div>
    </div>
  </div>

  <!-- Selecció d'oponent -->
  <div class="skeleton-form-section">
    <div class="skeleton-label">
      <SkeletonLoader 
        width="100px"
        height="16px"
        variant="text"
        {theme}
        {offline}
      />
      {#if showValidation}
        <div class="skeleton-validation-indicator">
          <SkeletonLoader 
            width="16px"
            height="16px"
            variant="circular"
            {theme}
            urgency={getValidationUrgency('opponent')}
            {offline}
          />
        </div>
      {/if}
    </div>
    
    <div class="skeleton-opponent-selector">
      <SkeletonLoader 
        width="100%"
        height="48px"
        variant="rectangular"
        borderRadius="8px"
        {theme}
        urgency={getValidationUrgency('opponent')}
        {offline}
      />
    </div>

    <!-- Llista d'oponents vàlids -->
    {#if showRules && canChallenge}
      <div class="skeleton-valid-opponents">
        {#each validPositions as position, index}
          <div class="skeleton-opponent-option">
            <SkeletonLoader 
              width="32px"
              height="32px"
              variant="circular"
              {theme}
              urgency="safe"
              {offline}
            />
            <div class="skeleton-opponent-details">
              <SkeletonLoader 
                width="85%"
                height="16px"
                variant="text"
                {theme}
                {offline}
              />
              <SkeletonLoader 
                width="60%"
                height="12px"
                variant="text"
                {theme}
                urgency="safe"
                {offline}
              />
            </div>
            <div class="skeleton-position-badge">
              <SkeletonLoader 
                width="30px"
                height="20px"
                variant="rectangular"
                borderRadius="10px"
                {theme}
                urgency="safe"
                {offline}
              />
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Configuració del desafiament -->
  <div class="skeleton-form-section">
    <div class="skeleton-label">
      <SkeletonLoader 
        width="120px"
        height="16px"
        variant="text"
        {theme}
        {offline}
      />
    </div>
    
    <!-- Deadline (7 dies per acceptar) -->
    <div class="skeleton-deadline-field">
      <SkeletonLoader 
        width="100%"
        height="48px"
        variant="rectangular"
        borderRadius="8px"
        {theme}
        urgency={getValidationUrgency('deadline')}
        {offline}
        showCountdown={true}
        countdownDays={7}
      />
    </div>
  </div>

  <!-- Missatge opcional -->
  {#if !compact}
    <div class="skeleton-form-section">
      <div class="skeleton-label">
        <SkeletonLoader 
          width="90px"
          height="16px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
      
      <div class="skeleton-message-field">
        <SkeletonLoader 
          width="100%"
          height="80px"
          variant="rectangular"
          borderRadius="8px"
          {theme}
          {offline}
        />
      </div>
    </div>
  {/if}

  <!-- Regles del desafiament -->
  {#if showRules}
    <div class="skeleton-rules-section">
      <div class="skeleton-rules-header">
        <SkeletonLoader 
          width="120px"
          height="16px"
          variant="text"
          {theme}
          urgency="warning"
          {offline}
        />
      </div>
      
      <div class="skeleton-rules-list">
        <!-- Regla 1: Només +1/+2 posicions -->
        <div class="skeleton-rule-item">
          <SkeletonLoader 
            width="16px"
            height="16px"
            variant="circular"
            {theme}
            urgency="warning"
            {offline}
          />
          <SkeletonLoader 
            width="85%"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <!-- Regla 2: 7 dies per acceptar -->
        <div class="skeleton-rule-item">
          <SkeletonLoader 
            width="16px"
            height="16px"
            variant="circular"
            {theme}
            urgency="warning"
            {offline}
          />
          <SkeletonLoader 
            width="80%"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <!-- Regla 3: 15 dies per disputar -->
        <div class="skeleton-rule-item">
          <SkeletonLoader 
            width="16px"
            height="16px"
            variant="circular"
            {theme}
            urgency="critical"
            {offline}
          />
          <SkeletonLoader 
            width="75%"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
      </div>
    </div>
  {/if}

  <!-- Accions -->
  <div class="skeleton-form-actions">
    {#if canChallenge}
      <!-- Crear desafiament -->
      <SkeletonLoader 
        width="120px"
        height="40px"
        variant="rectangular"
        borderRadius="20px"
        {theme}
        urgency="safe"
        {offline}
      />
      
      <!-- Previsualitzar -->
      {#if !compact}
        <SkeletonLoader 
          width="100px"
          height="40px"
          variant="rectangular"
          borderRadius="20px"
          {theme}
          {offline}
        />
      {/if}
    {:else}
      <!-- No es pot desafiar -->
      <SkeletonLoader 
        width="140px"
        height="40px"
        variant="rectangular"
        borderRadius="20px"
        {theme}
        urgency="critical"
        {offline}
      />
    {/if}
    
    <!-- Cancel·lar -->
    <SkeletonLoader 
      width="80px"
      height="40px"
      variant="rectangular"
      borderRadius="20px"
      {theme}
      {offline}
    />
  </div>

  <!-- Indicador de validació global -->  
  {#if showValidation}
    <div class="skeleton-validation-status">
      <SkeletonLoader 
        width="100%"
        height="24px"
        variant="rectangular"
        borderRadius="4px"
        {theme}
        urgency={canChallenge ? 'safe' : 'critical'}
        {offline}
      />
    </div>
  {/if}
</div>

<style>
  .create-challenge-skeleton {
    background: var(--surface-1);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 20px;
    max-width: 600px;
  }

  .compact.create-challenge-skeleton {
    padding: 16px;
    border-radius: 8px;
  }

  .skeleton-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--border-color);
  }

  .compact .skeleton-header {
    margin-bottom: 16px;
    padding-bottom: 12px;
  }

  .skeleton-title {
    display: flex;
    align-items: center;
  }

  .skeleton-position-info {
    display: flex;
    align-items: center;
  }

  .skeleton-current-player {
    margin-bottom: 24px;
  }

  .compact .skeleton-current-player {
    margin-bottom: 16px;
  }

  .skeleton-player-card {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 16px;
    background: var(--surface-2);
    border-radius: 8px;
    border: 2px solid var(--primary-color);
  }

  .compact .skeleton-player-card {
    gap: 12px;
    padding: 12px;
  }

  .skeleton-player-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .skeleton-form-section {
    margin-bottom: 20px;
  }

  .compact .skeleton-form-section {
    margin-bottom: 16px;
  }

  .skeleton-label {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
  }

  .skeleton-validation-indicator {
    display: flex;
    align-items: center;
  }

  .skeleton-opponent-selector {
    margin-bottom: 12px;
  }

  .skeleton-valid-opponents {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px;
    background: var(--surface-2);
    border-radius: 8px;
  }

  .skeleton-opponent-option {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px;
    border-radius: 6px;
    transition: background-color 0.2s ease;
  }

  .skeleton-opponent-option:hover {
    background: var(--surface-hover);
  }

  .skeleton-opponent-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .skeleton-position-badge {
    display: flex;
    align-items: center;
  }

  .skeleton-deadline-field,
  .skeleton-message-field {
    width: 100%;
  }

  .skeleton-rules-section {
    margin-bottom: 24px;
    padding: 16px;
    background: rgba(245, 158, 11, 0.05);
    border: 1px solid var(--warning-color);
    border-radius: 8px;
  }

  .compact .skeleton-rules-section {
    margin-bottom: 16px;
    padding: 12px;
  }

  .skeleton-rules-header {
    margin-bottom: 12px;
  }

  .skeleton-rules-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .skeleton-rule-item {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .skeleton-form-actions {
    display: flex;
    gap: 12px;
    align-items: center;
    justify-content: flex-end;
    padding-top: 16px;
    border-top: 1px solid var(--border-color);
  }

  .compact .skeleton-form-actions {
    padding-top: 12px;
    gap: 8px;
  }

  .skeleton-validation-status {
    margin-top: 16px;
    padding: 12px;
    border-radius: 6px;
  }

  /* Responsive */
  @media (max-width: 768px) {
    .create-challenge-skeleton {
      padding: 16px;
      margin: 0 8px;
    }

    .skeleton-header {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }

    .skeleton-player-card {
      flex-direction: column;
      text-align: center;
      gap: 12px;
    }

    .skeleton-form-actions {
      flex-direction: column;
      align-items: stretch;
    }

    .skeleton-valid-opponents {
      padding: 8px;
    }

    .skeleton-opponent-option {
      flex-wrap: wrap;
      gap: 8px;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .create-challenge-skeleton {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --surface-hover: #4b5563;
      --border-color: #6b7280;
      --primary-color: #3b82f6;
      --warning-color: #f59e0b;
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .create-challenge-skeleton {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --surface-hover: #f3f4f6;
      --border-color: #e5e7eb;
      --primary-color: #2563eb;
      --warning-color: #d97706;
    }
  }
</style>