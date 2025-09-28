<script lang="ts">
  import SkeletonLoader from './SkeletonLoader.svelte';
  
  export let playerCount: number = 20; // Màxim 20 jugadors segons les regles
  export let showPositions: boolean = true;
  export let showStats: boolean = true;
  export let compact: boolean = false;
  export let offline: boolean = false;
  export let theme: 'billiard' | 'default' = 'billiard';

  // Generar un patró realista basat en les regles del campionat
  function getPlayerVariation(index: number): {
    nameWidth: string;
    matchesWidth: string;
    pointsWidth: string;
    urgency: 'safe' | 'warning' | 'critical' | 'none';
  } {
    const nameWidths = ['85%', '75%', '90%', '80%', '70%', '95%'];
    const matchesWidths = ['45%', '60%', '55%', '40%', '65%'];
    const pointsWidths = ['35%', '50%', '40%', '45%', '55%'];
    
    // Simular urgències basades en posicions de desafiament
    let urgency: 'safe' | 'warning' | 'critical' | 'none' = 'none';
    if (index <= 2) urgency = 'safe'; // Top 3 posicions segures
    else if (index >= 17) urgency = 'critical'; // Últimes posicions en risc
    else if (index >= 15) urgency = 'warning'; // Posicions de risg mitjà
    
    return {
      nameWidth: nameWidths[index % nameWidths.length],
      matchesWidth: matchesWidths[index % matchesWidths.length],
      pointsWidth: pointsWidths[index % pointsWidths.length],
      urgency
    };
  }
</script>

<div class="ranking-table-skeleton" class:compact>
  <!-- Header -->
  <div class="skeleton-header">
    <div class="skeleton-header-cell position">
      <SkeletonLoader 
        width="30px" 
        height="24px" 
        variant="text"
        {theme}
        {offline}
      />
    </div>
    <div class="skeleton-header-cell player">
      <SkeletonLoader 
        width="80px" 
        height="24px" 
        variant="text"
        {theme}
        {offline}
      />
    </div>
    {#if showStats}
      <div class="skeleton-header-cell matches">
        <SkeletonLoader 
          width="60px" 
          height="24px" 
          variant="text"
          {theme}
          {offline}
        />
      </div>
      <div class="skeleton-header-cell points">
        <SkeletonLoader 
          width="50px" 
          height="24px" 
          variant="text"
          {theme}
          {offline}
        />
      </div>
    {/if}
    <div class="skeleton-header-cell actions">
      <SkeletonLoader 
        width="70px" 
        height="24px" 
        variant="text"
        {theme}
        {offline}
      />
    </div>
  </div>

  <!-- Players rows - màxim 20 segons regles del campionat -->
  <div class="skeleton-body">
    {#each Array(Math.min(playerCount, 20)) as _, index}
      {@const player = getPlayerVariation(index)}
      <div class="skeleton-row" class:top-position={index < 3} class:danger-zone={index >= 17}>
        <!-- Posició -->
        {#if showPositions}
          <div class="skeleton-cell position">
            <SkeletonLoader 
              width="24px" 
              height={compact ? '32px' : '40px'}
              variant="rectangular"
              {theme}
              urgency={player.urgency}
              {offline}
            />
          </div>
        {/if}

        <!-- Avatar + Nom -->
        <div class="skeleton-cell player">
          <div class="skeleton-player-content">
            <SkeletonLoader 
              width={compact ? '32px' : '40px'}
              height={compact ? '32px' : '40px'}
              variant="circular"
              {theme}
              urgency={player.urgency}
              {offline}
            />
            <div class="skeleton-player-info">
              <SkeletonLoader 
                width={player.nameWidth}
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

        <!-- Estadístiques -->
        {#if showStats}
          <div class="skeleton-cell matches">
            <SkeletonLoader 
              width={player.matchesWidth}
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
          <div class="skeleton-cell points">
            <SkeletonLoader 
              width={player.pointsWidth}
              height="16px"
              variant="text"
              {theme}
              urgency={player.urgency}
              {offline}
            />
          </div>
        {/if}

        <!-- Accions (Desafiar +1/+2 posicions) -->
        <div class="skeleton-cell actions">
          <div class="skeleton-actions">
            {#if index > 0 && index < 19}
              <!-- Botó desafiar només disponible per posicions +1/+2 -->
              <SkeletonLoader 
                width="70px"
                height="28px"
                variant="rectangular"
                borderRadius="14px"
                {theme}
                urgency={index <= 1 ? 'safe' : 'none'}
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
      </div>
    {/each}
  </div>

  <!-- Indicador de límit 20 jugadors -->
  {#if playerCount >= 20}
    <div class="skeleton-limit-indicator">
      <SkeletonLoader 
        width="100%"
        height="32px"
        variant="rectangular"
        {theme}
        urgency="warning"
        {offline}
      />
    </div>
  {/if}
</div>

<style>
  .ranking-table-skeleton {
    width: 100%;
    background: var(--surface-1);
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid var(--border-color);
  }

  .skeleton-header {
    display: grid;
    grid-template-columns: 60px 1fr auto auto auto;
    gap: 16px;
    padding: 16px;
    background: var(--surface-2);
    border-bottom: 1px solid var(--border-color);
    font-weight: 600;
  }

  .compact .skeleton-header {
    padding: 12px;
    grid-template-columns: 50px 1fr auto auto auto;
    gap: 12px;
  }

  .skeleton-header-cell {
    display: flex;
    align-items: center;
  }

  .skeleton-body {
    max-height: 600px;
    overflow-y: auto;
  }

  .skeleton-row {
    display: grid;
    grid-template-columns: 60px 1fr auto auto auto;
    gap: 16px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
    transition: background-color 0.2s ease;
  }

  .compact .skeleton-row {
    padding: 8px 12px;
    grid-template-columns: 50px 1fr auto auto auto;
    gap: 12px;
  }

  .skeleton-row:hover {
    background: var(--surface-hover);
  }

  .skeleton-row.top-position {
    background: rgba(16, 185, 129, 0.05);
  }

  .skeleton-row.danger-zone {
    background: rgba(239, 68, 68, 0.05);
  }

  .skeleton-cell {
    display: flex;
    align-items: center;
    min-height: 48px;
  }

  .compact .skeleton-cell {
    min-height: 40px;
  }

  .skeleton-cell.position {
    justify-content: center;
    font-weight: 600;
  }

  .skeleton-player-content {
    display: flex;
    align-items: center;
    gap: 12px;
    width: 100%;
  }

  .compact .skeleton-player-content {
    gap: 8px;
  }

  .skeleton-player-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .skeleton-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .skeleton-limit-indicator {
    padding: 12px 16px;
    background: rgba(245, 158, 11, 0.1);
    border-top: 1px solid var(--border-color);
  }

  /* Responsive */
  @media (max-width: 768px) {
    .skeleton-header,
    .skeleton-row {
      grid-template-columns: 40px 1fr auto;
      gap: 8px;
      padding: 8px 12px;
    }

    .skeleton-cell.matches,
    .skeleton-cell.points {
      display: none;
    }

    .skeleton-actions {
      flex-direction: column;
      gap: 4px;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .ranking-table-skeleton {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --surface-hover: #4b5563;
      --border-color: #6b7280;
    }

    .skeleton-row.top-position {
      background: rgba(16, 185, 129, 0.1);
    }

    .skeleton-row.danger-zone {
      background: rgba(239, 68, 68, 0.1);
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .ranking-table-skeleton {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --surface-hover: #f3f4f6;
      --border-color: #e5e7eb;
    }
  }
</style>