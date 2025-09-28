<script lang="ts">
  import SkeletonLoader from './SkeletonLoader.svelte';
  
  export let resultType: 'report' | 'dispute' | 'confirm' | 'view' = 'report';
  export let matchStatus: 'pending' | 'reported' | 'disputed' | 'confirmed' | 'expired' = 'pending';
  export let showValidation: boolean = true;
  export let showMatchDetails: boolean = true;
  export let compact: boolean = false;
  export let offline: boolean = false;
  export let theme: 'billiard' | 'default' = 'billiard';
  export let daysRemaining: number = 10; // Dies restants per reportar (màx 15)
  export let canReport: boolean = true;

  // Determinar urgència basada en dies restants per reportar resultat
  function getReportUrgency(days: number): 'safe' | 'warning' | 'critical' | 'none' {
    if (days <= 2) return 'critical';
    if (days <= 5) return 'warning';
    if (days <= 15) return 'safe';
    return 'none';
  }

  // Obtenir urgència segons l'estat del match
  function getStatusUrgency(status: string): 'safe' | 'warning' | 'critical' | 'none' {
    switch (status) {
      case 'confirmed': return 'safe';
      case 'reported': return 'warning';
      case 'disputed': return 'critical';
      case 'expired': return 'critical';
      case 'pending': return getReportUrgency(daysRemaining);
      default: return 'none';
    }
  }

  // Obtenir text de l'estat
  function getStatusText(status: string): string {
    switch (status) {
      case 'pending': return 'Pendent de disputar';
      case 'reported': return 'Resultat reportat';
      case 'disputed': return 'Sota disputa';
      case 'confirmed': return 'Confirmat';
      case 'expired': return 'Expirat';
      default: return 'Desconegut';
    }
  }

  $: reportUrgency = getReportUrgency(daysRemaining);
  $: statusUrgency = getStatusUrgency(matchStatus);
  $: isExpired = daysRemaining <= 0 || matchStatus === 'expired';
</script>

<div class="match-result-skeleton" class:compact class:expired={isExpired}>
  <!-- Header amb estat del match -->
  <div class="skeleton-header">
    <div class="skeleton-status-badge">
      <SkeletonLoader 
        width="120px"
        height="28px"
        variant="rectangular"
        borderRadius="14px"
        {theme}
        urgency={statusUrgency}
        {offline}
      />
    </div>
    
    {#if matchStatus === 'pending' && !isExpired}
      <div class="skeleton-deadline">
        <SkeletonLoader 
          width="90px"
          height="32px"
          variant="countdown"
          {theme}
          urgency={reportUrgency}
          {offline}
          showCountdown={true}
          countdownDays={daysRemaining}
        />
      </div>
    {:else if matchStatus === 'disputed'}
      <div class="skeleton-dispute-indicator">
        <SkeletonLoader 
          width="80px"
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

  <!-- Detalls del match -->
  {#if showMatchDetails}
    <div class="skeleton-match-details">
      <!-- Jugadors -->
      <div class="skeleton-players-section">
        <!-- Challenger -->
        <div class="skeleton-player player-1">
          <div class="skeleton-player-info">
            <SkeletonLoader 
              width={compact ? '48px' : '64px'}
              height={compact ? '48px' : '64px'}
              variant="circular"
              {theme}
              urgency={statusUrgency}
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
            </div>
          </div>
          
          <!-- Puntuació -->
          <div class="skeleton-score">
            <SkeletonLoader 
              width="60px"
              height="48px"
              variant="rectangular"
              borderRadius="8px"
              {theme}
              urgency={matchStatus === 'confirmed' ? 'safe' : statusUrgency}
              {offline}
            />
          </div>
        </div>

        <!-- VS Separator -->
        <div class="skeleton-vs-separator">
          <SkeletonLoader 
            width="40px"
            height="40px"
            variant="circular"
            {theme}
            {offline}
          />
        </div>

        <!-- Challenged -->
        <div class="skeleton-player player-2">
          <div class="skeleton-player-info">
            <SkeletonLoader 
              width={compact ? '48px' : '64px'}
              height={compact ? '48px' : '64px'}
              variant="circular"
              {theme}
              urgency={statusUrgency}
              {offline}
            />
            <div class="skeleton-player-details">
              <SkeletonLoader 
                width="90%"
                height="18px"
                variant="text"
                {theme}
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
            </div>
          </div>
          
          <!-- Puntuació -->
          <div class="skeleton-score">
            <SkeletonLoader 
              width="60px"
              height="48px"
              variant="rectangular"
              borderRadius="8px"
              {theme}
              urgency={matchStatus === 'confirmed' ? 'safe' : statusUrgency}
              {offline}
            />
          </div>
        </div>
      </div>

      <!-- Informació del match -->
      {#if !compact}
        <div class="skeleton-match-info">
          <div class="skeleton-match-date">
            <SkeletonLoader 
              width="100px"
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
          
          <div class="skeleton-match-duration">
            <SkeletonLoader 
              width="80px"
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
          
          <div class="skeleton-match-location">
            <SkeletonLoader 
              width="120px"
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        </div>
      {/if}
    </div>
  {/if}

  <!-- Formulari segons el tipus de resultat -->
  {#if resultType === 'report' && matchStatus === 'pending' && !isExpired}
    <div class="skeleton-result-form">
      <div class="skeleton-form-title">
        <SkeletonLoader 
          width="120px"
          height="20px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
      
      <!-- Camps de puntuació -->
      <div class="skeleton-score-inputs">
        <div class="skeleton-score-field">
          <SkeletonLoader 
            width="100%"
            height="48px"
            variant="rectangular"
            borderRadius="8px"
            {theme}
            urgency={showValidation ? 'safe' : 'warning'}
            {offline}
          />
        </div>
        
        <div class="skeleton-vs-label">
          <SkeletonLoader 
            width="24px"
            height="16px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <div class="skeleton-score-field">
          <SkeletonLoader 
            width="100%"
            height="48px"
            variant="rectangular"
            borderRadius="8px"
            {theme}
            urgency={showValidation ? 'safe' : 'warning'}
            {offline}
          />
        </div>
      </div>
      
      <!-- Comentaris opcionals -->
      <div class="skeleton-comments-field">
        <SkeletonLoader 
          width="80px"
          height="16px"
          variant="text"
          {theme}
          {offline}
        />
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
  {:else if resultType === 'dispute' && matchStatus === 'reported'}
    <div class="skeleton-dispute-form">
      <div class="skeleton-dispute-title">
        <SkeletonLoader 
          width="100px"
          height="20px"
          variant="text"
          {theme}
          urgency="critical"
          {offline}
        />
      </div>
      
      <!-- Motiu de la disputa -->
      <div class="skeleton-dispute-reason">
        <SkeletonLoader 
          width="120px"
          height="16px"
          variant="text"
          {theme}
          {offline}
        />
        <SkeletonLoader 
          width="100%"
          height="48px"
          variant="rectangular"
          borderRadius="8px"
          {theme}
          urgency="critical"
          {offline}
        />
      </div>
      
      <!-- Explicació detallada -->
      <div class="skeleton-dispute-explanation">
        <SkeletonLoader 
          width="100px"
          height="16px"
          variant="text"
          {theme}
          {offline}
        />
        <SkeletonLoader 
          width="100%"
          height="100px"
          variant="rectangular"
          borderRadius="8px"
          {theme}
          urgency="critical"
          {offline}
        />
      </div>
    </div>
  {/if}

  <!-- Historial de canvis (si s'escau) -->
  {#if matchStatus === 'disputed' || matchStatus === 'reported'}
    <div class="skeleton-history">
      <div class="skeleton-history-title">
        <SkeletonLoader 
          width="80px"
          height="16px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
      
      <div class="skeleton-history-items">
        {#each Array(2) as _, index}
          <div class="skeleton-history-item">
            <SkeletonLoader 
              width="24px"
              height="24px"
              variant="circular"
              {theme}
              urgency={index === 0 ? statusUrgency : 'none'}
              {offline}
            />
            <div class="skeleton-history-content">
              <SkeletonLoader 
                width="90%"
                height="14px"
                variant="text"
                {theme}
                {offline}
              />
              <SkeletonLoader 
                width="60%"
                height="12px"
                variant="text"
                {theme}
                {offline}
              />
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <!-- Accions principals -->
  <div class="skeleton-result-actions">
    {#if resultType === 'report' && matchStatus === 'pending' && !isExpired}
      <!-- Reportar resultat -->
      <SkeletonLoader 
        width="130px"
        height="44px"
        variant="rectangular"
        borderRadius="22px"
        {theme}
        urgency="safe"
        {offline}
      />
      
      <!-- Guardar esborrany -->
      <SkeletonLoader 
        width="120px"
        height="44px"
        variant="rectangular"
        borderRadius="22px"
        {theme}
        {offline}
      />
    {:else if resultType === 'dispute' && matchStatus === 'reported'}
      <!-- Disputar resultat -->
      <SkeletonLoader 
        width="130px"
        height="44px"
        variant="rectangular"
        borderRadius="22px"
        {theme}
        urgency="critical"
        {offline}
      />
      
      <!-- Acceptar resultat -->
      <SkeletonLoader 
        width="120px"
        height="44px"
        variant="rectangular"
        borderRadius="22px"
        {theme}
        urgency="safe"
        {offline}
      />
    {:else if resultType === 'confirm' && matchStatus === 'reported'}
      <!-- Confirmar resultat -->
      <SkeletonLoader 
        width="130px"
        height="44px"
        variant="rectangular"
        borderRadius="22px"
        {theme}
        urgency="safe"
        {offline}
      />
    {:else}
      <!-- Veure detalls -->
      <SkeletonLoader 
        width="120px"
        height="44px"
        variant="rectangular"
        borderRadius="22px"
        {theme}
        {offline}
      />
    {/if}
    
    <!-- Cancel·lar -->
    <SkeletonLoader 
      width="80px"
      height="44px"
      variant="rectangular"
      borderRadius="22px"
      {theme}
      {offline}
    />
  </div>

  <!-- Indicador de validació -->
  {#if showValidation && (resultType === 'report' || resultType === 'dispute')}
    <div class="skeleton-validation-status">
      <SkeletonLoader 
        width="100%"
        height="32px"
        variant="rectangular"
        borderRadius="6px"
        {theme}
        urgency={canReport ? 'safe' : 'critical'}
        {offline}
      />
    </div>
  {/if}
</div>

<style>
  .match-result-skeleton {
    background: var(--surface-1);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 24px;
    max-width: 800px;
  }

  .compact.match-result-skeleton {
    padding: 16px;
    border-radius: 8px;
  }

  .match-result-skeleton.expired {
    opacity: 0.8;
    border-color: var(--error-color);
    background: rgba(239, 68, 68, 0.05);
  }

  .skeleton-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24px;
    padding-bottom: 16px;
    border-bottom: 2px solid var(--border-color);
  }

  .compact .skeleton-header {
    margin-bottom: 16px;
    padding-bottom: 12px;
  }

  .skeleton-status-badge {
    display: flex;
    align-items: center;
  }

  .skeleton-deadline,
  .skeleton-dispute-indicator {
    display: flex;
    align-items: center;
  }

  .skeleton-match-details {
    margin-bottom: 24px;
  }

  .compact .skeleton-match-details {
    margin-bottom: 16px;
  }

  .skeleton-players-section {
    display: flex;
    align-items: center;
    gap: 24px;
    margin-bottom: 20px;
  }

  .compact .skeleton-players-section {
    gap: 16px;
    margin-bottom: 16px;
  }

  .skeleton-player {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    flex: 1;
  }

  .skeleton-player-info {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    text-align: center;
  }

  .skeleton-player-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    align-items: center;
  }

  .skeleton-score {
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 2rem;
    font-weight: bold;
  }

  .skeleton-vs-separator {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .skeleton-match-info {
    display: flex;
    justify-content: space-around;
    align-items: center;
    padding: 16px;
    background: var(--surface-2);
    border-radius: 8px;
    flex-wrap: wrap;
    gap: 12px;
  }

  .compact .skeleton-match-info {
    padding: 12px;
    gap: 8px;
  }

  .skeleton-result-form,
  .skeleton-dispute-form {
    margin-bottom: 24px;
    padding: 20px;
    background: var(--surface-2);
    border-radius: 8px;
  }

  .compact .skeleton-result-form,
  .compact .skeleton-dispute-form {
    margin-bottom: 16px;
    padding: 16px;
  }

  .skeleton-form-title,
  .skeleton-dispute-title {
    margin-bottom: 16px;
    font-weight: 600;
  }

  .skeleton-score-inputs {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 20px;
  }

  .compact .skeleton-score-inputs {
    gap: 12px;
    margin-bottom: 16px;
  }

  .skeleton-score-field {
    flex: 1;
  }

  .skeleton-vs-label {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .skeleton-comments-field,
  .skeleton-dispute-reason,
  .skeleton-dispute-explanation {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-bottom: 16px;
  }

  .skeleton-history {
    margin-bottom: 24px;
    padding: 16px;
    background: var(--surface-2);
    border-radius: 8px;
  }

  .compact .skeleton-history {
    margin-bottom: 16px;
    padding: 12px;
  }

  .skeleton-history-title {
    margin-bottom: 12px;
    font-weight: 600;
  }

  .skeleton-history-items {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .skeleton-history-item {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .skeleton-history-content {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .skeleton-result-actions {
    display: flex;
    gap: 12px;
    align-items: center;
    justify-content: center;
    flex-wrap: wrap;
    padding-top: 20px;
    border-top: 1px solid var(--border-color);
  }

  .compact .skeleton-result-actions {
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
    .match-result-skeleton {
      padding: 16px;
      margin: 0 8px;
    }

    .skeleton-header {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }

    .skeleton-players-section {
      flex-direction: column;
      gap: 16px;
    }

    .skeleton-vs-separator {
      transform: rotate(90deg);
      order: 2;
    }

    .skeleton-player.player-1 {
      order: 1;
    }

    .skeleton-player.player-2 {
      order: 3;
    }

    .skeleton-score-inputs {
      flex-direction: column;
      gap: 12px;
    }

    .skeleton-result-actions {
      flex-direction: column;
      align-items: stretch;
    }

    .skeleton-match-info {
      flex-direction: column;
      align-items: stretch;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .match-result-skeleton {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --border-color: #6b7280;
      --error-color: #ef4444;
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .match-result-skeleton {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --border-color: #e5e7eb;
      --error-color: #dc2626;
    }
  }
</style>