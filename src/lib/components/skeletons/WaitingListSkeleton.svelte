<script lang="ts">
  import SkeletonLoader from './SkeletonLoader.svelte';
  
  export let maxWaitingPlayers: number = 10; // Màxim jugadors en llista d'espera
  export let showAccessRights: boolean = true;
  export let showWaitTime: boolean = true;
  export let compact: boolean = false;
  export let offline: boolean = false;
  export let theme: 'billiard' | 'default' = 'billiard';
  export let showPriority: boolean = true;

  // Simular diferents tipus d'accés segons posició a la llista
  function getAccessRights(index: number): {
    accessType: 'immediate' | 'next-round' | 'conditional' | 'blocked';
    urgency: 'safe' | 'warning' | 'critical' | 'none';
    waitDays: number;
    priority: 'high' | 'medium' | 'low';
  } {
    // Primers 3: accés immediat quan es liberi plaça
    if (index < 3) {
      return {
        accessType: 'immediate',
        urgency: 'safe',
        waitDays: Math.floor(Math.random() * 5) + 1,
        priority: 'high'
      };
    }
    
    // Següents 4: accés següent ronda
    if (index < 7) {
      return {
        accessType: 'next-round',
        urgency: 'warning',
        waitDays: Math.floor(Math.random() * 15) + 10,
        priority: 'medium'
      };
    }

    // Resta: accés condicional o bloquejat
    return {
      accessType: Math.random() > 0.3 ? 'conditional' : 'blocked',
      urgency: Math.random() > 0.5 ? 'critical' : 'none',
      waitDays: Math.floor(Math.random() * 30) + 30,
      priority: 'low'
    };
  }

  function getAccessTypeText(accessType: string): string {
    switch (accessType) {
      case 'immediate': return 'Accés immediat';
      case 'next-round': return 'Següent ronda';
      case 'conditional': return 'Condicional';
      case 'blocked': return 'Bloquejat';
      default: return 'Desconegut';
    }
  }

  function getPriorityIcon(priority: string): string {
    switch (priority) {
      case 'high': return '🔥';
      case 'medium': return '⚡';
      case 'low': return '⏳';
      default: return '❓';
    }
  }
</script>

<div class="waiting-list-skeleton" class:compact>
  <!-- Header amb informació de la llista -->
  <div class="skeleton-header">
    <div class="skeleton-title">
      <SkeletonLoader 
        width="140px"
        height="24px"
        variant="text"
        {theme}
        {offline}
      />
    </div>
    
    <div class="skeleton-counter">
      <SkeletonLoader 
        width="60px"
        height="20px"
        variant="rectangular"
        borderRadius="10px"
        {theme}
        urgency="warning"
        {offline}
      />
    </div>
  </div>

  <!-- Llista de jugadors en espera -->
  <div class="skeleton-list">
    {#each Array(Math.min(maxWaitingPlayers, 15)) as _, index}
      {@const player = getAccessRights(index)}
      <div class="skeleton-waiting-item" data-access={player.accessType}>
        <!-- Posició a la llista -->
        <div class="skeleton-position">
          <SkeletonLoader 
            width="32px"
            height="32px"
            variant="rectangular"
            borderRadius="6px"
            {theme}
            urgency={player.urgency}
            {offline}
          />
          {#if showPriority}
            <div class="skeleton-priority">
              <SkeletonLoader 
                width="16px"
                height="16px"
                variant="circular"
                {theme}
                urgency={player.priority === 'high' ? 'safe' : player.priority === 'medium' ? 'warning' : 'none'}
                {offline}
              />
            </div>
          {/if}
        </div>

        <!-- Informació del jugador -->
        <div class="skeleton-player">
          <div class="skeleton-player-main">
            <SkeletonLoader 
              width={compact ? '36px' : '44px'}
              height={compact ? '36px' : '44px'}
              variant="circular"
              {theme}
              urgency={player.urgency}
              {offline}
            />
            <div class="skeleton-player-info">
              <SkeletonLoader 
                width="85%"
                height="16px"
                variant="text"
                {theme}
                urgency={player.urgency}
                {offline}
              />
              {#if !compact}
                <SkeletonLoader 
                  width="60%"
                  height="12px"
                  variant="text"
                  {theme}
                  {offline}
                />
              {/if}
            </div>
          </div>
        </div>

        <!-- Drets d'accés -->
        {#if showAccessRights}
          <div class="skeleton-access-rights">
            <div class="skeleton-access-badge">
              <SkeletonLoader 
                width="90px"
                height="24px"
                variant="rectangular"
                borderRadius="12px"
                {theme}
                urgency={player.urgency}
                {offline}
              />
            </div>
            {#if !compact}
              <div class="skeleton-access-details">
                <SkeletonLoader 
                  width="70px"
                  height="12px"
                  variant="text"
                  {theme}
                  {offline}
                />
              </div>
            {/if}
          </div>
        {/if}

        <!-- Temps d'espera -->
        {#if showWaitTime}
          <div class="skeleton-wait-time">
            <SkeletonLoader 
              width="50px"
              height="16px"
              variant="text"
              {theme}
              urgency={player.waitDays > 30 ? 'critical' : player.waitDays > 15 ? 'warning' : 'safe'}
              {offline}
            />
            {#if !compact}
              <SkeletonLoader 
                width="35px"
                height="12px"
                variant="text"
                {theme}
                {offline}
              />
            {/if}
          </div>
        {/if}

        <!-- Accions disponibles -->
        <div class="skeleton-actions">
          {#if player.accessType === 'immediate'}
            <!-- Notificar disponibilitat -->
            <SkeletonLoader 
              width="80px"
              height="28px"
              variant="rectangular"
              borderRadius="14px"
              {theme}
              urgency="safe"
              {offline}
            />
          {:else if player.accessType === 'blocked'}
            <!-- Revisar requisits -->
            <SkeletonLoader 
              width="70px"
              height="28px"
              variant="rectangular"
              borderRadius="14px"
              {theme}
              urgency="critical"
              {offline}
            />
          {:else}
            <!-- Mantenir posició -->
            <SkeletonLoader 
              width="75px"
              height="28px"
              variant="rectangular"
              borderRadius="14px"
              {theme}
              {offline}
            />
          {/if}
          
          {#if !compact}
            <SkeletonLoader 
              width="24px"
              height="24px"
              variant="circular"
              {theme}
              {offline}
            />
          {/if}
        </div>
      </div>
    {/each}
  </div>

  <!-- Informació adicional de la llista d'espera -->
  <div class="skeleton-footer">
    <div class="skeleton-stats">
      <SkeletonLoader 
        width="120px"
        height="14px"
        variant="text"
        {theme}
        {offline}
      />
      <SkeletonLoader 
        width="100px"
        height="14px"
        variant="text"
        {theme}
        {offline}
      />
    </div>
    
    {#if !compact}
      <div class="skeleton-join-action">
        <SkeletonLoader 
          width="100px"
          height="32px"
          variant="rectangular"
          borderRadius="16px"
          {theme}
          urgency="safe"
          {offline}
        />
      </div>
    {/if}
  </div>
</div>

<style>
  .waiting-list-skeleton {
    background: var(--surface-1);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    overflow: hidden;
  }

  .compact.waiting-list-skeleton {
    border-radius: 8px;
  }

  .skeleton-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    background: var(--surface-2);
    border-bottom: 1px solid var(--border-color);
  }

  .compact .skeleton-header {
    padding: 12px;
  }

  .skeleton-title {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .skeleton-counter {
    display: flex;
    align-items: center;
  }

  .skeleton-list {
    max-height: 500px;
    overflow-y: auto;
  }

  .skeleton-waiting-item {
    display: grid;
    grid-template-columns: auto 1fr auto auto auto;
    gap: 12px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
    align-items: center;
    transition: background-color 0.2s ease;
  }

  .compact .skeleton-waiting-item {
    grid-template-columns: auto 1fr auto auto;
    gap: 8px;
    padding: 8px 12px;
  }

  .skeleton-waiting-item:hover {
    background: var(--surface-hover);
  }

  /* Estats d'accés */
  .skeleton-waiting-item[data-access="immediate"] {
    background: rgba(16, 185, 129, 0.05);
    border-left: 3px solid var(--success-color);
  }

  .skeleton-waiting-item[data-access="next-round"] {
    background: rgba(245, 158, 11, 0.05);
    border-left: 3px solid var(--warning-color);
  }

  .skeleton-waiting-item[data-access="conditional"] {
    background: rgba(107, 114, 128, 0.05);
    border-left: 3px solid var(--text-secondary);
  }

  .skeleton-waiting-item[data-access="blocked"] {
    background: rgba(239, 68, 68, 0.05);
    border-left: 3px solid var(--error-color);
    opacity: 0.8;
  }

  .skeleton-position {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .skeleton-priority {
    position: absolute;
    top: -4px;
    right: -4px;
  }

  .skeleton-player {
    display: flex;
    align-items: center;
  }

  .skeleton-player-main {
    display: flex;
    align-items: center;
    gap: 12px;
    width: 100%;
  }

  .compact .skeleton-player-main {
    gap: 8px;
  }

  .skeleton-player-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .skeleton-access-rights {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }

  .skeleton-access-badge {
    display: flex;
    align-items: center;
  }

  .skeleton-access-details {
    text-align: center;
  }

  .skeleton-wait-time {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    text-align: center;
  }

  .skeleton-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .skeleton-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    background: var(--surface-2);
    border-top: 1px solid var(--border-color);
  }

  .compact .skeleton-footer {
    padding: 12px;
  }

  .skeleton-stats {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .skeleton-join-action {
    display: flex;
    align-items: center;
  }

  /* Responsive */
  @media (max-width: 768px) {
    .skeleton-waiting-item {
      grid-template-columns: auto 1fr auto;
      gap: 8px;
    }

    .skeleton-access-rights,
    .skeleton-wait-time {
      display: none;
    }

    .skeleton-actions {
      flex-direction: column;
      gap: 4px;
    }

    .skeleton-footer {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .waiting-list-skeleton {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --surface-hover: #4b5563;
      --border-color: #6b7280;
      --text-secondary: #9ca3af;
      --success-color: #10b981;
      --warning-color: #f59e0b;
      --error-color: #ef4444;
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .waiting-list-skeleton {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --surface-hover: #f3f4f6;
      --border-color: #e5e7eb;
      --text-secondary: #6b7280;
      --success-color: #059669;
      --warning-color: #d97706;
      --error-color: #dc2626;
    }
  }
</style>