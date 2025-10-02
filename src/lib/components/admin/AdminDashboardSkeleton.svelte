<script lang="ts">
  import SkeletonLoader from '../campionat-continu/SkeletonLoader.svelte';
  
  export let showSystemStatus: boolean = true;
  export let showUserStats: boolean = true;
  export let showRecentActivity: boolean = true;
  export let showQuickActions: boolean = true;
  export let adminLevel: 'super' | 'admin' | 'moderator' = 'admin';
  export let compact: boolean = false;
  export let offline: boolean = false;
  export let theme: 'billiard' | 'default' = 'billiard';
  export let systemHealthStatus: 'healthy' | 'warning' | 'critical' = 'healthy';

  // Determinar urgència basada en l'estat del sistema
  function getSystemUrgency(status: string): 'safe' | 'warning' | 'critical' | 'none' {
    switch (status) {
      case 'healthy': return 'safe';
      case 'warning': return 'warning';
      case 'critical': return 'critical';
      default: return 'none';
    }
  }

  // Obtenir permisos segons el nivell d'admin
  function getPermissionLevel(level: string): {
    canManageUsers: boolean;
    canModifySystem: boolean;
    canViewLogs: boolean;
    canManageChampionship: boolean;
  } {
    switch (level) {
      case 'super':
        return {
          canManageUsers: true,
          canModifySystem: true,
          canViewLogs: true,
          canManageChampionship: true
        };
      case 'admin':
        return {
          canManageUsers: true,
          canModifySystem: false,
          canViewLogs: true,
          canManageChampionship: true
        };
      case 'moderator':
        return {
          canManageUsers: false,
          canModifySystem: false,
          canViewLogs: false,
          canManageChampionship: true
        };
      default:
        return {
          canManageUsers: false,
          canModifySystem: false,
          canViewLogs: false,
          canManageChampionship: false
        };
    }
  }

  $: systemUrgency = getSystemUrgency(systemHealthStatus);
  $: permissions = getPermissionLevel(adminLevel);
</script>

<div class="admin-dashboard-skeleton" class:compact>
  <!-- Header amb informació d'administrador -->
  <div class="skeleton-admin-header">
    <div class="skeleton-admin-info">
      <SkeletonLoader 
        width={compact ? '48px' : '64px'}
        height={compact ? '48px' : '64px'}
        variant="circular"
        {theme}
        urgency="safe"
        {offline}
      />
      <div class="skeleton-admin-details">
        <SkeletonLoader 
          width="120px"
          height="20px"
          variant="text"
          {theme}
          {offline}
        />
        <SkeletonLoader 
          width="80px"
          height="16px"
          variant="text"
          {theme}
          urgency="safe"
          {offline}
        />
      </div>
    </div>
    
    <div class="skeleton-admin-level">
      <SkeletonLoader 
        width="90px"
        height="28px"
        variant="rectangular"
        borderRadius="14px"
        {theme}
        urgency={adminLevel === 'super' ? 'critical' : adminLevel === 'admin' ? 'warning' : 'safe'}
        {offline}
      />
    </div>
  </div>

  <!-- Estat del sistema -->
  {#if showSystemStatus}
    <div class="skeleton-system-status">
      <div class="skeleton-status-header">
        <SkeletonLoader 
          width="120px"
          height="20px"
          variant="text"
          {theme}
          {offline}
        />
        <SkeletonLoader 
          width="80px"
          height="24px"
          variant="rectangular"
          borderRadius="12px"
          {theme}
          urgency={systemUrgency}
          {offline}
        />
      </div>
      
      <div class="skeleton-status-metrics">
        <!-- CPU Usage -->
        <div class="skeleton-metric">
          <SkeletonLoader 
            width="60px"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
          <SkeletonLoader 
            width="100%"
            height="8px"
            variant="rectangular"
            borderRadius="4px"
            {theme}
            urgency={systemUrgency}
            {offline}
          />
          <SkeletonLoader 
            width="40px"
            height="12px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <!-- Memory Usage -->
        <div class="skeleton-metric">
          <SkeletonLoader 
            width="70px"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
          <SkeletonLoader 
            width="100%"
            height="8px"
            variant="rectangular"
            borderRadius="4px"
            {theme}
            urgency={systemUrgency}
            {offline}
          />
          <SkeletonLoader 
            width="45px"
            height="12px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <!-- Database -->
        <div class="skeleton-metric">
          <SkeletonLoader 
            width="80px"
            height="14px"
            variant="text"
            {theme}
            {offline}
          />
          <SkeletonLoader 
            width="100%"
            height="8px"
            variant="rectangular"
            borderRadius="4px"
            {theme}
            urgency="safe"
            {offline}
          />
          <SkeletonLoader 
            width="50px"
            height="12px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
      </div>
    </div>
  {/if}

  <!-- Estadístiques d'usuaris -->
  {#if showUserStats}
    <div class="skeleton-user-stats">
      <div class="skeleton-stats-header">
        <SkeletonLoader 
          width="140px"
          height="20px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
      
      <div class="skeleton-stats-grid">
        <!-- Total usuaris -->
        <div class="skeleton-stat-card">
          <SkeletonLoader 
            width="32px"
            height="32px"
            variant="circular"
            {theme}
            urgency="safe"
            {offline}
          />
          <div class="skeleton-stat-info">
            <SkeletonLoader 
              width="60px"
              height="24px"
              variant="text"
              {theme}
              {offline}
            />
            <SkeletonLoader 
              width="80px"
              height="14px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        </div>
        
        <!-- Usuaris actius -->
        <div class="skeleton-stat-card">
          <SkeletonLoader 
            width="32px"
            height="32px"
            variant="circular"
            {theme}
            urgency="safe"
            {offline}
          />
          <div class="skeleton-stat-info">
            <SkeletonLoader 
              width="50px"
              height="24px"
              variant="text"
              {theme}
              {offline}
            />
            <SkeletonLoader 
              width="90px"
              height="14px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        </div>
        
        <!-- Usuaris en llista d'espera -->
        <div class="skeleton-stat-card">
          <SkeletonLoader 
            width="32px"
            height="32px"
            variant="circular"
            {theme}
            urgency="warning"
            {offline}
          />
          <div class="skeleton-stat-info">
            <SkeletonLoader 
              width="40px"
              height="24px"
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
        </div>
        
        <!-- Usuaris suspesos -->
        <div class="skeleton-stat-card">
          <SkeletonLoader 
            width="32px"
            height="32px"
            variant="circular"
            {theme}
            urgency="critical"
            {offline}
          />
          <div class="skeleton-stat-info">
            <SkeletonLoader 
              width="30px"
              height="24px"
              variant="text"
              {theme}
              {offline}
            />
            <SkeletonLoader 
              width="85px"
              height="14px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- Activitat recent -->
  {#if showRecentActivity}
    <div class="skeleton-recent-activity">
      <div class="skeleton-activity-header">
        <SkeletonLoader 
          width="120px"
          height="20px"
          variant="text"
          {theme}
          {offline}
        />
        <SkeletonLoader 
          width="80px"
          height="24px"
          variant="rectangular"
          borderRadius="12px"
          {theme}
          {offline}
        />
      </div>
      
      <div class="skeleton-activity-list">
        {#each Array(5) as _, index}
          <div class="skeleton-activity-item">
            <SkeletonLoader 
              width="24px"
              height="24px"
              variant="circular"
              {theme}
              urgency={index === 0 ? 'warning' : 'none'}
              {offline}
            />
            <div class="skeleton-activity-content">
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
                {offline}
              />
            </div>
            <div class="skeleton-activity-time">
              <SkeletonLoader 
                width="50px"
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

  <!-- Accions ràpides -->
  {#if showQuickActions}
    <div class="skeleton-quick-actions">
      <div class="skeleton-actions-header">
        <SkeletonLoader 
          width="100px"
          height="20px"
          variant="text"
          {theme}
          {offline}
        />
      </div>
      
      <div class="skeleton-actions-grid">
        <!-- Gestió d'usuaris -->
        {#if permissions.canManageUsers}
          <div class="skeleton-action-card">
            <SkeletonLoader 
              width="40px"
              height="40px"
              variant="circular"
              {theme}
              urgency="safe"
              {offline}
            />
            <SkeletonLoader 
              width="90px"
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        {/if}
        
        <!-- Configuració del campionat -->
        {#if permissions.canManageChampionship}
          <div class="skeleton-action-card">
            <SkeletonLoader 
              width="40px"
              height="40px"
              variant="circular"
              {theme}
              urgency="warning"
              {offline}
            />
            <SkeletonLoader 
              width="100px"
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        {/if}
        
        <!-- Logs del sistema -->
        {#if permissions.canViewLogs}
          <div class="skeleton-action-card">
            <SkeletonLoader 
              width="40px"
              height="40px"
              variant="circular"
              {theme}
              {offline}
            />
            <SkeletonLoader 
              width="80px"
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        {/if}
        
        <!-- Configuració del sistema -->
        {#if permissions.canModifySystem}
          <div class="skeleton-action-card">
            <SkeletonLoader 
              width="40px"
              height="40px"
              variant="circular"
              {theme}
              urgency="critical"
              {offline}
            />
            <SkeletonLoader 
              width="85px"
              height="16px"
              variant="text"
              {theme}
              {offline}
            />
          </div>
        {/if}
        
        <!-- Backup -->
        <div class="skeleton-action-card">
          <SkeletonLoader 
            width="40px"
            height="40px"
            variant="circular"
            {theme}
            urgency="safe"
            {offline}
          />
          <SkeletonLoader 
            width="70px"
            height="16px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
        
        <!-- Notificacions -->
        <div class="skeleton-action-card">
          <SkeletonLoader 
            width="40px"
            height="40px"
            variant="circular"
            {theme}
            urgency="warning"
            {offline}
          />
          <SkeletonLoader 
            width="95px"
            height="16px"
            variant="text"
            {theme}
            {offline}
          />
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .admin-dashboard-skeleton {
    display: grid;
    gap: 24px;
    padding: 24px;
    background: var(--surface-1);
    border-radius: 12px;
  }

  .compact.admin-dashboard-skeleton {
    gap: 16px;
    padding: 16px;
    border-radius: 8px;
  }

  .skeleton-admin-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px;
    background: var(--surface-2);
    border-radius: 8px;
    border-left: 4px solid var(--primary-color);
  }

  .compact .skeleton-admin-header {
    padding: 16px;
  }

  .skeleton-admin-info {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .compact .skeleton-admin-info {
    gap: 12px;
  }

  .skeleton-admin-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .skeleton-admin-level {
    display: flex;
    align-items: center;
  }

  .skeleton-system-status {
    padding: 20px;
    background: var(--surface-2);
    border-radius: 8px;
    border: 1px solid var(--border-color);
  }

  .compact .skeleton-system-status {
    padding: 16px;
  }

  .skeleton-status-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .skeleton-status-metrics {
    display: grid;
    gap: 16px;
  }

  .compact .skeleton-status-metrics {
    gap: 12px;
  }

  .skeleton-metric {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .skeleton-user-stats {
    padding: 20px;
    background: var(--surface-2);
    border-radius: 8px;
  }

  .compact .skeleton-user-stats {
    padding: 16px;
  }

  .skeleton-stats-header {
    margin-bottom: 16px;
  }

  .skeleton-stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }

  .compact .skeleton-stats-grid {
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 12px;
  }

  .skeleton-stat-card {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px;
    background: var(--surface-1);
    border-radius: 6px;
    border: 1px solid var(--border-color);
  }

  .compact .skeleton-stat-card {
    gap: 8px;
    padding: 12px;
  }

  .skeleton-stat-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .skeleton-recent-activity {
    padding: 20px;
    background: var(--surface-2);
    border-radius: 8px;
  }

  .compact .skeleton-recent-activity {
    padding: 16px;
  }

  .skeleton-activity-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .skeleton-activity-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .skeleton-activity-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    background: var(--surface-1);
    border-radius: 6px;
    transition: background-color 0.2s ease;
  }

  .skeleton-activity-item:hover {
    background: var(--surface-hover);
  }

  .skeleton-activity-content {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .skeleton-activity-time {
    display: flex;
    align-items: center;
  }

  .skeleton-quick-actions {
    padding: 20px;
    background: var(--surface-2);
    border-radius: 8px;
  }

  .compact .skeleton-quick-actions {
    padding: 16px;
  }

  .skeleton-actions-header {
    margin-bottom: 16px;
  }

  .skeleton-actions-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 16px;
  }

  .compact .skeleton-actions-grid {
    grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
    gap: 12px;
  }

  .skeleton-action-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 16px;
    background: var(--surface-1);
    border-radius: 6px;
    border: 1px solid var(--border-color);
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .compact .skeleton-action-card {
    padding: 12px;
    gap: 6px;
  }

  .skeleton-action-card:hover {
    border-color: var(--primary-color);
    transform: translateY(-2px);
  }

  /* Responsive */
  @media (max-width: 768px) {
    .admin-dashboard-skeleton {
      padding: 16px;
      gap: 16px;
    }

    .skeleton-admin-header {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }

    .skeleton-stats-grid {
      grid-template-columns: 1fr;
    }

    .skeleton-actions-grid {
      grid-template-columns: repeat(2, 1fr);
    }

    .skeleton-activity-item {
      flex-wrap: wrap;
      gap: 8px;
    }

    .skeleton-activity-time {
      order: -1;
      align-self: flex-end;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .admin-dashboard-skeleton {
      --surface-1: #1f2937;
      --surface-2: #374151;
      --surface-hover: #4b5563;
      --border-color: #6b7280;
      --primary-color: #3b82f6;
    }
  }

  /* Light mode */
  @media (prefers-color-scheme: light) {
    .admin-dashboard-skeleton {
      --surface-1: #ffffff;
      --surface-2: #f9fafb;
      --surface-hover: #f3f4f6;
      --border-color: #e5e7eb;
      --primary-color: #2563eb;
    }
  }
</style>