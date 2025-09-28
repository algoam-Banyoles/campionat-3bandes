<script lang="ts">
  import SkeletonLoader from './SkeletonLoader.svelte';
  
  export let responseType: 'accept' | 'reject' | 'view' = 'accept';
  export let daysRemaining: number = 3; // Dies restants per respondre (màx 7)
  export let showChallengeDetails: boolean = true;
  export let showValidation: boolean = true;
  export let compact: boolean = false;
  export let offline: boolean = false;
  export let theme: 'billiard' | 'default' = 'billiard';
  export let canRespond: boolean = true;

  // Determinar urgència basada en dies restants
  function getTimeUrgency(days: number): 'safe' | 'warning' | 'critical' | 'none' {
    if (days <= 1) return 'critical';
    if (days <= 2) return 'warning';
    if (days <= 7) return 'safe';
    return 'none';
  }

  // Obtenir acció principal segons el tipus
  function getPrimaryAction(): string {
    switch (responseType) {
      case 'accept': return 'Acceptar';
      case 'reject': return 'Rebutjar';
      case 'view': return 'Veure detalls';
      default: return 'Accions';
    }
  }

  $: timeUrgency = getTimeUrgency(daysRemaining);
  $: isExpired = daysRemaining <= 0;
</script>

<div class="challenge-response-skeleton" class:compact class:expired={isExpired}>
  <!-- Header amb countdown -->
  <div class="skeleton-header">
    <div class="skeleton-challenge-type">
      <SkeletonLoader 
        width="120px"
        height="24px"
        variant="rectangular"
        borderRadius="12px"
        {theme}
        urgency={isExpired ? 'critical' : timeUrgency}
        {offline}
      />
    </div>
    
    {#if !isExpired && canRespond}
      <div class="skeleton-countdown">
        <SkeletonLoader 
          width="80px"
          height="32px"
          variant="countdown"
          {theme}
          urgency={timeUrgency}
          {offline}
          showCountdown={true}
          countdownDays={daysRemaining}
        />
      </div>
    {:else}
      <div class="skeleton-status">
        <SkeletonLoader 
          width="70px"
          height="24px"
          variant="rectangular"
          borderRadius="12px"
          {theme}
          urgency="critical"
          {offline}
        />
      </div>
    {/if}
  </div>

  <!-- Detalls del desafiament -->
  {#if showChallengeDetails}
    <div class="skeleton-challenge-details">
      <!-- Challenger info -->
      <div class="skeleton-challenger-section">
        <div class="skeleton-section-title">
          <SkeletonLoader 
            width="80px"
            height="16px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <div class="skeleton-player-info">
          <SkeletonLoader 
            width={compact ? '40px' : '56px'}
            height={compact ? '40px' : '56px'}
            variant="circular"
            {theme}
            urgency={timeUrgency}
            {offline}
          />
          <div class="skeleton-player-details">
            <SkeletonLoader 
              width="85%"
              height="18px"
              variant="text"
              {theme}
              {offline}
            />
            <SkeletonLoader 
              width="60%"
              height="14px"
              variant="text"
              {theme}
              urgency="safe"
              {offline}
            />
            {#if !compact}
              <SkeletonLoader 
                width="70%"
                height="12px"
                variant="text"
                {theme}
                {offline}
              />
            {/if}
          </div>
          <div class="skeleton-current-position">
            <SkeletonLoader 
              width="30px"
              height="24px"
              variant="rectangular"
              borderRadius="12px"
              {theme}
              urgency="safe"
              {offline}
            />
          </div>
        </div>
      </div>

      <!-- Challenge target (tu) -->
      <div class="skeleton-target-section">
        <div class="skeleton-section-title">
          <SkeletonLoader 
            width="90px"
            height="16px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <div class="skeleton-player-info highlighted">
          <SkeletonLoader 
            width={compact ? '40px' : '56px'}
            height={compact ? '40px' : '56px'}
            variant="circular"
            {theme}
            urgency="warning"
            {offline}
          />
          <div class="skeleton-player-details">
            <SkeletonLoader 
              width="80%"
              height="18px"
              variant="text"
              {theme}
              urgency="warning"
              {offline}
            />
            <SkeletonLoader 
              width="55%"
              height="14px"
              variant="text"
              {theme}
              urgency="warning"
              {offline}
            />
            {#if !compact}
              <SkeletonLoader 
                width="65%"
                height="12px"
                variant="text"
                {theme}
                {offline}
              />
            {/if}
          </div>
          <div class="skeleton-target-position">
            <SkeletonLoader 
              width="30px"
              height="24px"
              variant="rectangular"
              borderRadius="12px"
              {theme}
              urgency="warning"
              {offline}
            />
          </div>
        </div>
      </div>

      <!-- Moviment de posicions -->
      <div class="skeleton-position-change">
        <div class="skeleton-position-arrow">
          <SkeletonLoader 
            width="100%"
            height="32px"
            variant="rectangular"
            borderRadius="16px"
            {theme}
            urgency={timeUrgency}
            {offline}
          />
        </div>
      </div>
    </div>
  {/if}

  <!-- Missatge del challenger -->
  {#if !compact}
    <div class="skeleton-challenge-message">
      <div class="skeleton-message-header">
        <SkeletonLoader 
          width="70px"
          height="16px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
      
      <div class="skeleton-message-content">
        <SkeletonLoader 
          width="100%"
          height="60px"
          variant="rectangular"
          borderRadius="6px"
          {theme}
          {offline}
        />
      </div>
    </div>
  {/if}

  <!-- Regles recordatori -->
  <div class="skeleton-rules-reminder">
    <div class="skeleton-rules-title">
      <SkeletonLoader 
        width="100px"
        height="16px"
        variant="text"
        {theme}
        urgency="warning"
        {offline}
      />
    </div>
    
    <div class="skeleton-rules-items">
      <!-- 15 dies per disputar -->
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
      
      <!-- Consequències de no respondre -->
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
          width="80%"
          height="14px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
    </div>
  </div>

  <!-- Camp de resposta (si és acceptar/rebutjar) -->
  {#if (responseType === 'accept' || responseType === 'reject') && !isExpired}
    <div class="skeleton-response-section">
      <div class="skeleton-response-label">
        <SkeletonLoader 
          width="120px"
          height="16px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
      
      <div class="skeleton-response-field">
        <SkeletonLoader 
          width="100%"
          height="80px"
          variant="rectangular"
          borderRadius="8px"
          {theme}
          urgency={responseType === 'reject' ? 'warning' : 'none'}
          {offline}
        />
      </div>
    </div>
  {/if}

  <!-- Accions principals -->
  <div class="skeleton-response-actions">
    {#if canRespond && !isExpired}
      {#if responseType === 'accept'}
        <!-- Acceptar desafiament -->
        <SkeletonLoader 
          width="130px"
          height="44px"
          variant="rectangular"
          borderRadius="22px"
          {theme}
          urgency="safe"
          {offline}
        />
        
        <!-- Demanar aclaracions -->
        <SkeletonLoader 
          width="120px"
          height="44px"
          variant="rectangular"
          borderRadius="22px"
          {theme}
          {offline}
        />
        
        <!-- Rebutjar -->
        <SkeletonLoader 
          width="80px"
          height="44px"
          variant="rectangular"
          borderRadius="22px"
          {theme}
          urgency="critical"
          {offline}
        />
      {:else if responseType === 'reject'}
        <!-- Confirmar rebuig -->
        <SkeletonLoader 
          width="120px"
          height="44px"
          variant="rectangular"
          borderRadius="22px"
          {theme}
          urgency="critical"
          {offline}
        />
        
        <!-- Cancel·lar -->
        <SkeletonLoader 
          width="80px"
          height="44px"
          variant="rectangular"
          borderRadius="22px"
          {theme}
          {offline}
        />
      {:else}
        <!-- Veure detalls complets -->
        <SkeletonLoader 
          width="140px"
          height="44px"
          variant="rectangular"
          borderRadius="22px"
          {theme}
          {offline}
        />
      {/if}
    {:else}
      <!-- Desafiament expirat -->
      <SkeletonLoader 
        width="150px"
        height="44px"
        variant="rectangular"
        borderRadius="22px"
        {theme}
        urgency="critical"
        {offline}
      />
    {/if}
  </div>

  <!-- Indicador de validació -->
  {#if showValidation && (responseType === 'accept' || responseType === 'reject')}
    <div class="skeleton-validation-status">
      <SkeletonLoader 
        width="100%"
        height="32px"
        variant="rectangular"
        borderRadius="6px"
        {theme}
        urgency={canRespond ? 'safe' : 'critical'}
        {offline}
      />
    </div>
  {/if}
</div>

<style>
  .challenge-response-skeleton {
    background: var(--surface-1);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 20px;
    max-width: 700px;
    position: relative;
  }

  .compact.challenge-response-skeleton {
    padding: 16px;
    border-radius: 8px;
  }

  .challenge-response-skeleton.expired {
    opacity: 0.8;
    border-color: var(--error-color);
    background: rgba(239, 68, 68, 0.05);
  }

  .skeleton-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    padding-bottom: 16px;
    border-bottom: 2px solid var(--border-color);
  }

  .compact .skeleton-header {
    margin-bottom: 16px;
    padding-bottom: 12px;
  }

  .skeleton-challenge-type {
    display: flex;
    align-items: center;
  }

  .skeleton-countdown,
  .skeleton-status {
    display: flex;
    align-items: center;
  }

  .skeleton-challenge-details {
    margin-bottom: 24px;
  }

  .compact .skeleton-challenge-details {
    margin-bottom: 16px;
  }

  .skeleton-challenger-section,
  .skeleton-target-section {
    margin-bottom: 16px;
  }

  .skeleton-section-title {
    margin-bottom: 8px;
    font-weight: 600;
  }

  .skeleton-player-info {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 16px;
    background: var(--surface-2);
    border-radius: 8px;
    transition: all 0.2s ease;
  }

  .compact .skeleton-player-info {
    gap: 12px;
    padding: 12px;
  }

  .skeleton-player-info.highlighted {
    border: 2px solid var(--primary-color);
    background: rgba(59, 130, 246, 0.05);
  }

  .skeleton-player-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .skeleton-current-position,
  .skeleton-target-position {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .skeleton-position-change {
    display: flex;
    justify-content: center;
    margin: 16px 0;
  }

  .skeleton-position-arrow {
    width: 200px;
  }

  .compact .skeleton-position-arrow {
    width: 150px;
  }

  .skeleton-challenge-message {
    margin-bottom: 20px;
    padding: 16px;
    background: var(--surface-2);
    border-radius: 8px;
  }

  .compact .skeleton-challenge-message {
    margin-bottom: 16px;
    padding: 12px;
  }

  .skeleton-message-header {
    margin-bottom: 8px;
  }

  .skeleton-message-content {
    width: 100%;
  }

  .skeleton-rules-reminder {
    margin-bottom: 20px;
    padding: 16px;
    background: rgba(245, 158, 11, 0.05);
    border: 1px solid var(--warning-color);
    border-radius: 8px;
  }

  .compact .skeleton-rules-reminder {
    margin-bottom: 16px;
    padding: 12px;
  }

  .skeleton-rules-title {
    margin-bottom: 12px;
    font-weight: 600;
  }

  .skeleton-rules-items {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .skeleton-rule-item {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .skeleton-response-section {
    margin-bottom: 24px;
  }

  .compact .skeleton-response-section {
    margin-bottom: 16px;
  }

  .skeleton-response-label {
    margin-bottom: 8px;
  }

  .skeleton-response-field {
    width: 100%;
  }

  .skeleton-response-actions {
    display: flex;
    gap: 12px;
    align-items: center;
    justify-content: center;
    flex-wrap: wrap;
    padding-top: 20px;
    border-top: 1px solid var(--border-color);
  }

  .compact .skeleton-response-actions {
    padding-top: 16px;
    gap: 8px;
  }

  .skeleton-validation-status {
    margin-top: 16px;
    padding: 12px;
    border-radius: 6px;
  }

  /* Responsive */
  @media (max-width: 768px) {
    .challenge-response-skeleton {
      padding: 16px;
      margin: 0 8px;
    }

    .skeleton-header {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }

    .skeleton-player-info {
      flex-direction: column;
      text-align: center;
      gap: 12px;
    }

    .skeleton-response-actions {
      flex-direction: column;
      align-items: stretch;
    }

    .skeleton-position-arrow {
      width: 120px;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .challenge-response-skeleton {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --border-color: #6b7280;
      --primary-color: #3b82f6;
      --warning-color: #f59e0b;
      --error-color: #ef4444;
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .challenge-response-skeleton {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --border-color: #e5e7eb;
      --primary-color: #2563eb;
      --warning-color: #d97706;
      --error-color: #dc2626;
    }
  }
</style>