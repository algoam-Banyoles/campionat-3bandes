<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    loadingStates, 
    championshipLoadingIds, 
    withLoading,
    getLoadingState,
    isLoadingById
  } from '$lib/utils/loadingStates';
  import { 
    generateSkeletonConfig,
    generateRankingPattern,
    generateChallengePattern,
    generateWaitingListPattern
  } from '$lib/utils/skeletonUtils';
  
  // Import dels skeleton components
  import {
    RankingTableSkeleton,
    ChallengeCardSkeleton,
    WaitingListSkeleton,
    CreateChallengeSkeleton,
    AdminDashboardSkeleton
  } from '$lib/components/skeletons';

  // Props per personalitzar l'exemple
  export let showRankings: boolean = true;
  export let showChallenges: boolean = true;
  export let showWaitingList: boolean = true;
  export let showAdminDashboard: boolean = false;
  export let simulateSlowLoading: boolean = false;

  // Stores derivats per cada operació
  const rankingsLoading = isLoadingById(championshipLoadingIds.FETCH_RANKINGS);
  const challengesLoading = isLoadingById(championshipLoadingIds.CREATE_CHALLENGE);
  const waitingListLoading = isLoadingById(championshipLoadingIds.JOIN_WAITING_LIST);
  const adminLoading = isLoadingById(championshipLoadingIds.ADMIN_SYSTEM_STATUS);

  // Estats per simular dades reals
  let rankings: any[] = [];
  let challenges: any[] = [];
  let waitingList: any[] = [];
  let adminData: any = null;

  // Configuracions de skeleton dinàmiques
  $: rankingConfig = generateSkeletonConfig(
    $rankingsLoading ? { 
      id: championshipLoadingIds.FETCH_RANKINGS,
      state: 'loading',
      priority: 'high',
      startTime: Date.now() - 2000 // Simular 2s carregant
    } : undefined,
    { theme: 'billiard', compact: false }
  );

  $: challengeConfig = generateSkeletonConfig(
    $challengesLoading ? {
      id: championshipLoadingIds.CREATE_CHALLENGE,
      state: 'loading', 
      priority: 'critical',
      startTime: Date.now() - 1000 // Simular 1s carregant
    } : undefined,
    { theme: 'billiard', urgency: 'warning' }
  );

  $: waitingConfig = generateSkeletonConfig(
    $waitingListLoading ? {
      id: championshipLoadingIds.JOIN_WAITING_LIST,
      state: 'loading',
      priority: 'normal', 
      startTime: Date.now() - 3000 // Simular 3s carregant
    } : undefined,
    { theme: 'billiard', compact: true }
  );

  // Funcions per simular operacions async
  async function fetchRankings() {
    const delay = simulateSlowLoading ? 5000 : 2000;
    
    return withLoading(
      championshipLoadingIds.FETCH_RANKINGS,
      async () => {
        await new Promise(resolve => setTimeout(resolve, delay));
        return Array.from({ length: 20 }, (_, i) => ({
          id: i + 1,
          position: i + 1,
          name: `Jugador ${i + 1}`,
          points: Math.floor(Math.random() * 100) + 50,
          matches: Math.floor(Math.random() * 20) + 5
        }));
      },
      {
        priority: 'high',
        message: 'Carregant classificació del campionat...',
        timeout: 10000
      }
    );
  }

  async function fetchChallenges() {
    const delay = simulateSlowLoading ? 4000 : 1500;
    
    return withLoading(
      championshipLoadingIds.CREATE_CHALLENGE,
      async () => {
        await new Promise(resolve => setTimeout(resolve, delay));
        return Array.from({ length: 3 }, (_, i) => ({
          id: i + 1,
          challenger: `Jugador ${i + 10}`,
          challenged: `Jugador ${i + 5}`,
          status: ['pending', 'active', 'completed'][i],
          daysRemaining: [7, 3, 0][i]
        }));
      },
      {
        priority: 'critical',
        message: 'Carregant desafiaments...'
      }
    );
  }

  async function fetchWaitingList() {
    const delay = simulateSlowLoading ? 3000 : 1000;
    
    return withLoading(
      championshipLoadingIds.JOIN_WAITING_LIST,
      async () => {
        await new Promise(resolve => setTimeout(resolve, delay));
        return Array.from({ length: 8 }, (_, i) => ({
          id: i + 1,
          name: `Aspirant ${i + 1}`,
          position: i + 1,
          waitingDays: Math.floor(Math.random() * 30) + 1,
          accessType: i < 3 ? 'immediate' : i < 7 ? 'next-round' : 'conditional'
        }));
      },
      {
        priority: 'normal',
        message: 'Carregant llista d\'espera...'
      }
    );
  }

  async function fetchAdminData() {
    const delay = simulateSlowLoading ? 6000 : 2500;
    
    return withLoading(
      championshipLoadingIds.ADMIN_SYSTEM_STATUS,
      async () => {
        await new Promise(resolve => setTimeout(resolve, delay));
        return {
          systemHealth: 'healthy',
          totalUsers: 45,
          activeUsers: 20,
          waitingUsers: 8,
          suspendedUsers: 2
        };
      },
      {
        priority: 'high',
        message: 'Carregant panell d\'administració...'
      }
    );
  }

  // Carregar dades en muntar el component
  onMount(async () => {
    try {
      // Carregar en paral·lel totes les dades necessàries
      const promises = [];
      
      if (showRankings) {
        promises.push(fetchRankings().then(data => rankings = data));
      }
      
      if (showChallenges) {
        promises.push(fetchChallenges().then(data => challenges = data));
      }
      
      if (showWaitingList) {
        promises.push(fetchWaitingList().then(data => waitingList = data));
      }
      
      if (showAdminDashboard) {
        promises.push(fetchAdminData().then(data => adminData = data));
      }
      
      await Promise.all(promises);
    } catch (error) {
      console.error('Error carregant dades:', error);
    }
  });

  // Funcions per refrescar dades
  function refreshRankings() {
    rankings = [];
    fetchRankings().then(data => rankings = data);
  }

  function refreshChallenges() {
    challenges = [];
    fetchChallenges().then(data => challenges = data);
  }

  function refreshWaitingList() {
    waitingList = [];
    fetchWaitingList().then(data => waitingList = data);
  }
</script>

<div class="skeleton-integration-example">
  <h1>Exemple d'Integració de Skeleton Loaders</h1>
  
  <!-- Controls per personalitzar l'exemple -->
  <div class="example-controls">
    <label>
      <input type="checkbox" bind:checked={simulateSlowLoading} />
      Simular càrrega lenta
    </label>
    
    <button on:click={refreshRankings} disabled={$rankingsLoading}>
      Refrescar Classificació
    </button>
    
    <button on:click={refreshChallenges} disabled={$challengesLoading}>
      Refrescar Desafiaments
    </button>
    
    <button on:click={refreshWaitingList} disabled={$waitingListLoading}>
      Refrescar Llista d'Espera
    </button>
  </div>

  <!-- Indicador global de loading -->
  <div class="loading-indicator">
    {#if $rankingsLoading || $challengesLoading || $waitingListLoading || $adminLoading}
      <div class="loading-badge">
        Carregant dades del campionat...
      </div>
    {/if}
  </div>

  <div class="content-grid">
    <!-- Secció de classificació -->
    {#if showRankings}
      <section class="content-section">
        <h2>Classificació del Campionat</h2>
        
        {#if $rankingsLoading || rankings.length === 0}
          <RankingTableSkeleton 
            playerCount={20}
            theme={rankingConfig.theme}
            offline={rankingConfig.offline}
            compact={rankingConfig.compact}
            showPositions={true}
            showStats={true}
          />
        {:else}
          <div class="real-content">
            <p>✅ Classificació carregada: {rankings.length} jugadors</p>
            {#each rankings.slice(0, 5) as player}
              <div class="ranking-item">
                {player.position}. {player.name} - {player.points} punts
              </div>
            {/each}
            <p>... i {rankings.length - 5} jugadors més</p>
          </div>
        {/if}
      </section>
    {/if}

    <!-- Secció de desafiaments -->
    {#if showChallenges}
      <section class="content-section">
        <h2>Desafiaments Actius</h2>
        
        {#if $challengesLoading || challenges.length === 0}
          <div class="challenges-skeleton">
            {#each Array(3) as _, index}
              <ChallengeCardSkeleton 
                challengeType={(['pending', 'active', 'completed'] as const)[index]}
                theme={challengeConfig.theme}
                offline={challengeConfig.offline}
                compact={challengeConfig.compact}
                daysRemaining={[7, 3, 0][index]}
                showDeadline={true}
                showPositions={true}
                showMatchResult={index === 2}
              />
            {/each}
          </div>
        {:else}
          <div class="real-content">
            <p>✅ Desafiaments carregats: {challenges.length}</p>
            {#each challenges as challenge}
              <div class="challenge-item">
                {challenge.challenger} vs {challenge.challenged} - {challenge.status}
              </div>
            {/each}
          </div>
        {/if}
      </section>
    {/if}

    <!-- Secció de llista d'espera -->
    {#if showWaitingList}
      <section class="content-section">
        <h2>Llista d'Espera</h2>
        
        {#if $waitingListLoading || waitingList.length === 0}
          <WaitingListSkeleton 
            maxWaitingPlayers={8}
            theme={waitingConfig.theme}
            offline={waitingConfig.offline}
            compact={waitingConfig.compact}
            showAccessRights={true}
            showWaitTime={true}
            showPriority={true}
          />
        {:else}
          <div class="real-content">
            <p>✅ Llista d'espera carregada: {waitingList.length} aspirants</p>
            {#each waitingList.slice(0, 3) as person}
              <div class="waiting-item">
                {person.position}. {person.name} - {person.waitingDays} dies esperant
              </div>
            {/each}
            <p>... i {waitingList.length - 3} més en llista</p>
          </div>
        {/if}
      </section>
    {/if}

    <!-- Panell d'administració -->
    {#if showAdminDashboard}
      <section class="content-section admin-section">
        <h2>Panell d'Administració</h2>
        
        {#if $adminLoading || !adminData}
          <AdminDashboardSkeleton 
            adminLevel="admin"
            theme="billiard"
            offline={false}
            compact={false}
            systemHealthStatus="healthy"
            showSystemStatus={true}
            showUserStats={true}
            showRecentActivity={true}
            showQuickActions={true}
          />
        {:else}
          <div class="real-content">
            <p>✅ Dades d'admin carregades</p>
            <div class="admin-stats">
              <div>Total usuaris: {adminData.totalUsers}</div>
              <div>Usuaris actius: {adminData.activeUsers}</div>
              <div>En llista d'espera: {adminData.waitingUsers}</div>
              <div>Suspesos: {adminData.suspendedUsers}</div>
            </div>
          </div>
        {/if}
      </section>
    {/if}
  </div>
</div>

<style>
  .skeleton-integration-example {
    padding: 24px;
    max-width: 1200px;
    margin: 0 auto;
  }

  .example-controls {
    display: flex;
    gap: 16px;
    align-items: center;
    margin-bottom: 24px;
    padding: 16px;
    background: var(--surface-2);
    border-radius: 8px;
    flex-wrap: wrap;
  }

  .example-controls button {
    padding: 8px 16px;
    border: 1px solid var(--border-color);
    border-radius: 4px;
    background: var(--surface-1);
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .example-controls button:hover:not(:disabled) {
    border-color: var(--primary-color);
    background: var(--primary-color);
    color: white;
  }

  .example-controls button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .loading-indicator {
    margin-bottom: 24px;
    min-height: 32px;
  }

  .loading-badge {
    display: inline-flex;
    align-items: center;
    padding: 8px 16px;
    background: var(--warning-color);
    color: white;
    border-radius: 16px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .content-grid {
    display: grid;
    gap: 32px;
  }

  .content-section {
    background: var(--surface-1);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 24px;
  }

  .content-section h2 {
    margin: 0 0 20px 0;
    color: var(--text-primary);
    border-bottom: 2px solid var(--border-color);
    padding-bottom: 8px;
  }

  .admin-section {
    border-left: 4px solid var(--error-color);
  }

  .challenges-skeleton {
    display: grid;
    gap: 16px;
  }

  .real-content {
    padding: 16px;
    background: rgba(16, 185, 129, 0.05);
    border: 1px solid var(--success-color);
    border-radius: 6px;
  }

  .ranking-item,
  .challenge-item,
  .waiting-item {
    padding: 8px 0;
    border-bottom: 1px solid var(--border-color);
  }

  .admin-stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 12px;
    margin-top: 12px;
  }

  .admin-stats > div {
    padding: 8px 12px;
    background: var(--surface-2);
    border-radius: 4px;
    text-align: center;
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .skeleton-integration-example {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --border-color: #6b7280;
      --text-primary: #f9fafb;
      --primary-color: #3b82f6;
      --success-color: #10b981;
      --warning-color: #f59e0b;
      --error-color: #ef4444;
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .skeleton-integration-example {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --border-color: #e5e7eb;
      --text-primary: #111827;
      --primary-color: #2563eb;
      --success-color: #059669;
      --warning-color: #d97706;
      --error-color: #dc2626;
    }
  }

  /* Responsive */
  @media (max-width: 768px) {
    .skeleton-integration-example {
      padding: 16px;
    }

    .example-controls {
      flex-direction: column;
      align-items: stretch;
    }

    .content-section {
      padding: 16px;
    }

    .admin-stats {
      grid-template-columns: 1fr;
    }
  }
</style>