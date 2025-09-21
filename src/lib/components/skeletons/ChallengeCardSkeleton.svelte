<script lang="ts">
  import SkeletonLoader from './SkeletonLoader.svelte';
  
  export let challengeType: 'pending' | 'active' | 'completed' | 'expired' = 'pending';
  export let showDeadline: boolean = true;
  export let showPositions: boolean = true;
  export let compact: boolean = false;
  export let offline: boolean = false;
  export let theme: 'billiard' | 'default' = 'billiard';
  export let daysRemaining: number = 7; // Simular dies restants per deadline
  export let showMatchResult: boolean = false;

  // Determinar urgència basada en els dies restants
  function getUrgencyLevel(days: number): 'safe' | 'warning' | 'critical' | 'none' {
    if (challengeType === 'expired') return 'critical';
    if (challengeType === 'completed') return 'safe';
    if (days <= 1) return 'critical'; // Menys d'1 dia
    if (days <= 3) return 'warning';  // Menys de 3 dies
    if (days <= 7) return 'safe';     // Fins a 7 dies (normal)
    return 'none';
  }

  // Obtenir text del tipus de challenge
  function getChallengeTypeText(): string {
    switch (challengeType) {
      case 'pending': return 'Pendent acceptació';
      case 'active': return 'Desafiament actiu';
      case 'completed': return 'Completat';
      case 'expired': return 'Expirat';
      default: return 'Desconegut';
    }
  }

  $: urgency = getUrgencyLevel(daysRemaining);
  $: showCountdown = showDeadline && challengeType !== 'completed' && challengeType !== 'expired';
</script>

<div class="challenge-card-skeleton" class:compact data-type={challengeType}>
  <!-- Header amb tipus i estat -->
  <div class="skeleton-header">
    <div class="skeleton-type-badge">
      <SkeletonLoader 
        width="90px"
        height="20px"
        variant="rectangular"
        borderRadius="10px"
        {theme}
        {urgency}
        {offline}
      />
    </div>
    
    {#if showDeadline}
      <div class="skeleton-deadline">
        <SkeletonLoader 
          width="80px"
          height="16px"
          variant="countdown"
          {theme}
          {urgency}
          {offline}
          showCountdown={showCountdown}
          countdownDays={daysRemaining}
        />
      </div>
    {/if}
  </div>

  <!-- Jugadors involucrats -->
  <div class="skeleton-players">
    <!-- Challenger (desafiador) -->
    <div class="skeleton-player challenger">
      <div class="skeleton-player-info">
        <SkeletonLoader 
          width={compact ? '36px' : '48px'}
          height={compact ? '36px' : '48px'}
          variant="circular"
          {theme}
          {urgency}
          {offline}
        />
        <div class="skeleton-player-details">
          <SkeletonLoader 
            width="85%"
            height="16px"
            variant="text"
            {theme}
            {urgency}
            {offline}
          />
          {#if showPositions}
            <SkeletonLoader 
              width="45%"
              height="12px"
              variant="text"
              {theme}
              {offline}
            />
          {/if}
        </div>
      </div>
      
      {#if !compact}
        <div class="skeleton-player-stats">
          <SkeletonLoader 
            width="30px"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
      {/if}
    </div>

    <!-- VS indicator -->
    <div class="skeleton-vs">
      <SkeletonLoader 
        width="32px"
        height="32px"
        variant="circular"
        {theme}
        {offline}
      />
    </div>

    <!-- Challenged (desafiat) -->
    <div class="skeleton-player challenged">
      <div class="skeleton-player-info">
        <SkeletonLoader 
          width={compact ? '36px' : '48px'}
          height={compact ? '36px' : '48px'}
          variant="circular"
          {theme}
          {urgency}
          {offline}
        />
        <div class="skeleton-player-details">
          <SkeletonLoader 
            width="90%"
            height="16px"
            variant="text"
            {theme}
            {urgency}
            {offline}
          />
          {#if showPositions}
            <SkeletonLoader 
              width="40%"
              height="12px"
              variant="text"
              {theme}
              {offline}
            />
          {/if}
        </div>
      </div>
      
      {#if !compact}
        <div class="skeleton-player-stats">
          <SkeletonLoader 
            width="35px"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
      {/if}
    </div>
  </div>

  <!-- Informació del match -->
  {#if showMatchResult && (challengeType === 'active' || challengeType === 'completed')}
    <div class="skeleton-match-info">
      <div class="skeleton-score">
        <SkeletonLoader 
          width="60px"
          height="24px"
          variant="text"
          {theme}
          urgency={challengeType === 'completed' ? 'safe' : 'none'}
          {offline}
        />
      </div>
      <div class="skeleton-match-details">
        <SkeletonLoader 
          width="120px"
          height="14px"
          variant="text"
          {theme}
          {offline}
        />
        <SkeletonLoader 
          width="80px"
          height="12px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
    </div>
  {/if}

  <!-- Actions segons el tipus de challenge -->
  <div class="skeleton-actions">
    {#if challengeType === 'pending'}
      <!-- Acceptar / Rebutjar -->
      <SkeletonLoader 
        width="80px"
        height="32px"
        variant="rectangular"
        borderRadius="16px"
        {theme}
        urgency="safe"
        {offline}
      />
      <SkeletonLoader 
        width="80px"
        height="32px"
        variant="rectangular"
        borderRadius="16px"
        {theme}
        urgency="critical"
        {offline}
      />
    {:else if challengeType === 'active'}
      <!-- Reportar resultat -->
      <SkeletonLoader 
        width="120px"
        height="32px"
        variant="rectangular"
        borderRadius="16px"
        {theme}
        {urgency}
        {offline}
      />
    {:else if challengeType === 'completed'}
      <!-- Veure detalls -->
      <SkeletonLoader 
        width="100px"
        height="32px"
        variant="rectangular"
        borderRadius="16px"
        {theme}
        urgency="safe"
        {offline}
      />
    {:else if challengeType === 'expired'}
      <!-- Renovar challenge (si aplicable) -->
      <SkeletonLoader 
        width="90px"
        height="32px"
        variant="rectangular"
        borderRadius="16px"
        {theme}
        urgency="warning"
        {offline}
      />
    {/if}
    
    {#if !compact}
      <!-- Menu d'opcions -->
      <SkeletonLoader 
        width="32px"
        height="32px"
        variant="circular"
        {theme}
        {offline}
      />
    {/if}
  </div>

  <!-- Barra de progrés si és actiu -->
  {#if challengeType === 'active' && showDeadline}
    <div class="skeleton-progress-bar">
      <SkeletonLoader 
        width="100%"
        height="4px"
        variant="rectangular"
        borderRadius="2px"
        {theme}
        {urgency}
        {offline}
        showCountdown={true}
        countdownDays={daysRemaining}
      />
    </div>
  {/if}
</div>

<style>
  .challenge-card-skeleton {
    background: var(--surface-1);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 16px;
    transition: all 0.2s ease;
    position: relative;
    overflow: hidden;
  }

  .compact.challenge-card-skeleton {
    padding: 12px;
    border-radius: 8px;
  }

  .challenge-card-skeleton:hover {
    border-color: var(--primary-color);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .skeleton-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .compact .skeleton-header {
    margin-bottom: 12px;
  }

  .skeleton-type-badge {
    position: relative;
  }

  .skeleton-deadline {
    position: relative;
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .skeleton-players {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 16px;
  }

  .compact .skeleton-players {
    gap: 12px;
    margin-bottom: 12px;
  }

  .skeleton-player {
    display: flex;
    align-items: center;
    gap: 12px;
    flex: 1;
  }

  .compact .skeleton-player {
    gap: 8px;
  }

  .skeleton-player-info {
    display: flex;
    align-items: center;
    gap: 12px;
    flex: 1;
  }

  .compact .skeleton-player-info {
    gap: 8px;
  }

  .skeleton-player-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .skeleton-player-stats {
    text-align: right;
    min-width: 40px;
  }

  .skeleton-vs {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 8px;
  }

  .skeleton-match-info {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 12px;
    background: var(--surface-2);
    border-radius: 8px;
    margin-bottom: 16px;
  }

  .compact .skeleton-match-info {
    gap: 12px;
    padding: 8px;
    margin-bottom: 12px;
  }

  .skeleton-score {
    display: flex;
    align-items: center;
    font-weight: 600;
  }

  .skeleton-match-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .skeleton-actions {
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
  }

  .skeleton-progress-bar {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 4px;
  }

  /* Variants per tipus de challenge */
  .challenge-card-skeleton[data-type="pending"] {
    border-left: 4px solid var(--warning-color);
  }

  .challenge-card-skeleton[data-type="active"] {
    border-left: 4px solid var(--primary-color);
  }

  .challenge-card-skeleton[data-type="completed"] {
    border-left: 4px solid var(--success-color);
  }

  .challenge-card-skeleton[data-type="expired"] {
    border-left: 4px solid var(--error-color);
    opacity: 0.8;
  }

  /* Responsive */
  @media (max-width: 768px) {
    .skeleton-players {
      flex-direction: column;
      gap: 12px;
    }

    .skeleton-vs {
      transform: rotate(90deg);
      padding: 8px 0;
    }

    .skeleton-actions {
      flex-direction: column;
      align-items: stretch;
    }

    .skeleton-match-info {
      flex-direction: column;
      align-items: flex-start;
      gap: 8px;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .challenge-card-skeleton {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --border-color: #6b7280;
      --primary-color: #3b82f6;
      --success-color: #10b981;
      --warning-color: #f59e0b;
      --error-color: #ef4444;
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .challenge-card-skeleton {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --border-color: #e5e7eb;
      --primary-color: #2563eb;
      --success-color: #059669;
      --warning-color: #d97706;
      --error-color: #dc2626;
    }
  }
</style>