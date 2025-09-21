# Guia d'Integració de Skeleton Loaders

Aquest document proporciona instruccions detallades per integrar els skeleton loaders al sistema de campionat de billar de 3 bandes.

## Índex
1. [Visió General](#visió-general)
2. [Components Disponibles](#components-disponibles)
3. [Integració Bàsica](#integració-bàsica)
4. [Configuració Avançada](#configuració-avançada)
5. [Integració amb Stores](#integració-amb-stores)
6. [Exemples Pràctics](#exemples-pràctics)
7. [Bones Pràctiques](#bones-pràctiques)

## Visió General

El sistema de skeleton loaders està dissenyat específicament per al campionat de billar de 3 bandes, respectant les regles següents:
- **Màxim 20 jugadors** en la classificació activa
- **Desafiaments només a posicions +1/+2**
- **7 dies per acceptar** un desafiament
- **15 dies per disputar** un match
- **Llista d'espera** amb drets d'accés diferenciats

## Components Disponibles

### Components Base
- `SkeletonLoader`: Component base configurable
- `SkeletonIntegrationExample`: Exemple complet d'integració

### Components Específics del Campionat
- `RankingTableSkeleton`: Taula de classificació (exactament 20 jugadors)
- `ChallengeCardSkeleton`: Targetes de desafiament amb urgència temporal
- `WaitingListSkeleton`: Llista d'espera amb indicadors d'accés

### Components de Formularis
- `CreateChallengeSkeleton`: Formulari de crear desafiament
- `ChallengeResponseSkeleton`: Formulari de resposta a desafiament
- `MatchResultSkeleton`: Formulari de resultat de partit

### Components d'Administració
- `AdminDashboardSkeleton`: Panell d'administració complet

## Integració Bàsica

### 1. Importar Components

```typescript
// Import dels skeletons necessaris
import {
  RankingTableSkeleton,
  ChallengeCardSkeleton,
  WaitingListSkeleton
} from '$lib/components/skeletons';

// Import de les utilitats
import { 
  loadingStates, 
  championshipLoadingIds,
  isLoadingById 
} from '$lib/utils/loadingStates';
```

### 2. Configurar Loading States

```typescript
// Crear stores derivats per cada operació
const rankingsLoading = isLoadingById(championshipLoadingIds.FETCH_RANKINGS);
const challengesLoading = isLoadingById(championshipLoadingIds.CREATE_CHALLENGE);

// Iniciar càrrega
loadingStates.start(
  championshipLoadingIds.FETCH_RANKINGS,
  'high',
  'Carregant classificació...',
  10000 // timeout de 10s
);
```

### 3. Utilitzar en Templates

```svelte
{#if $rankingsLoading || rankings.length === 0}
  <RankingTableSkeleton 
    playerCount={20}
    theme="billiard"
    showPositions={true}
    showStats={true}
  />
{:else}
  <!-- Contingut real -->
  <RankingTable {rankings} />
{/if}
```

## Configuració Avançada

### Configuració Dinàmica

```typescript
import { generateSkeletonConfig } from '$lib/utils/skeletonUtils';

// Generar configuració basada en l'estat de loading
$: skeletonConfig = generateSkeletonConfig(
  $rankingsLoading ? {
    id: championshipLoadingIds.FETCH_RANKINGS,
    state: 'loading',
    priority: 'high',
    startTime: loadingStartTime
  } : undefined,
  { 
    theme: 'billiard',
    compact: false 
  }
);
```

### Patrons Personalitzats

```typescript
import { 
  generateRankingPattern,
  generateChallengePattern,
  generateWaitingListPattern 
} from '$lib/utils/skeletonUtils';

// Generar patró per 20 jugadors amb urgències realistes
const rankingPattern = generateRankingPattern();

// Generar patró per desafiament amb 3 dies restants
const challengePattern = generateChallengePattern(3);

// Generar patró per llista d'espera de 8 persones
const waitingPattern = generateWaitingListPattern(8);
```

## Integració amb Stores

### Wrapper d'Operacions Async

```typescript
import { withLoading } from '$lib/utils/loadingStates';

async function fetchRankings() {
  return withLoading(
    championshipLoadingIds.FETCH_RANKINGS,
    async () => {
      const response = await fetch('/api/rankings');
      return response.json();
    },
    {
      priority: 'high',
      message: 'Carregant classificació del campionat...',
      timeout: 10000,
      autoCleanup: true
    }
  );
}
```

### Múltiples Operacions

```typescript
// Carregar dades en paral·lel
onMount(async () => {
  try {
    const [rankings, challenges, waitingList] = await Promise.all([
      fetchRankings(),
      fetchChallenges(), 
      fetchWaitingList()
    ]);
    
    // Actualitzar stores locals
    rankingsStore.set(rankings);
    challengesStore.set(challenges);
    waitingListStore.set(waitingList);
    
  } catch (error) {
    console.error('Error carregant dades:', error);
  }
});
```

## Exemples Pràctics

### Dashboard Principal

```svelte
<!-- src/routes/dashboard/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    RankingTableSkeleton,
    ChallengeCardSkeleton 
  } from '$lib/components/skeletons';
  import { 
    loadingStates,
    championshipLoadingIds,
    isLoadingById 
  } from '$lib/utils/loadingStates';

  const rankingsLoading = isLoadingById(championshipLoadingIds.FETCH_RANKINGS);
  const challengesLoading = isLoadingById(championshipLoadingIds.CREATE_CHALLENGE);
  
  let rankings = [];
  let challenges = [];

  onMount(async () => {
    // Carregar dades del dashboard
    await Promise.all([
      loadRankings(),
      loadChallenges()
    ]);
  });

  async function loadRankings() {
    loadingStates.start(championshipLoadingIds.FETCH_RANKINGS, 'high');
    try {
      const response = await fetch('/api/rankings');
      rankings = await response.json();
      loadingStates.success(championshipLoadingIds.FETCH_RANKINGS);
    } catch (error) {
      loadingStates.error(championshipLoadingIds.FETCH_RANKINGS, error.message);
    }
  }

  async function loadChallenges() {
    loadingStates.start(championshipLoadingIds.CREATE_CHALLENGE, 'normal');
    try {
      const response = await fetch('/api/challenges');
      challenges = await response.json();
      loadingStates.success(championshipLoadingIds.CREATE_CHALLENGE);
    } catch (error) {
      loadingStates.error(championshipLoadingIds.CREATE_CHALLENGE, error.message);
    }
  }
</script>

<main class="dashboard">
  <section class="rankings-section">
    <h2>Classificació</h2>
    
    {#if $rankingsLoading || rankings.length === 0}
      <RankingTableSkeleton 
        playerCount={20}
        theme="billiard"
        showPositions={true}
        showStats={true}
      />
    {:else}
      <RankingTable {rankings} />
    {/if}
  </section>

  <section class="challenges-section">
    <h2>Desafiaments</h2>
    
    {#if $challengesLoading || challenges.length === 0}
      <div class="challenges-grid">
        {#each Array(3) as _, i}
          <ChallengeCardSkeleton 
            challengeType="pending"
            theme="billiard"
            daysRemaining={7 - i}
            showDeadline={true}
          />
        {/each}
      </div>
    {:else}
      <ChallengesList {challenges} />
    {/if}
  </section>
</main>
```

### Pàgina de Desafiaments

```svelte
<!-- src/routes/challenges/+page.svelte -->
<script lang="ts">
  import { 
    CreateChallengeSkeleton,
    ChallengeResponseSkeleton 
  } from '$lib/components/skeletons';
  import { page } from '$app/stores';

  $: mode = $page.url.searchParams.get('mode') || 'list';
  $: challengeId = $page.url.searchParams.get('id');
</script>

{#if mode === 'create'}
  <CreateChallengeSkeleton 
    theme="billiard"
    currentPlayerPosition={10}
    showValidation={true}
    showRules={true}
  />
{:else if mode === 'respond' && challengeId}
  <ChallengeResponseSkeleton 
    responseType="accept"
    urgency="warning"
    daysRemaining={5}
    theme="billiard"
    showChallengeDetails={true}
  />
{:else}
  <!-- Llista de desafiaments -->
{/if}
```

### Panell d'Administració

```svelte
<!-- src/routes/admin/+page.svelte -->
<script lang="ts">
  import { AdminDashboardSkeleton } from '$lib/components/skeletons';
  import { adminStore } from '$lib/stores/adminStore';

  $: adminLevel = $adminStore.user?.role || 'moderator';
  $: systemHealth = $adminStore.system?.health || 'healthy';
</script>

{#if $adminStore.loading}
  <AdminDashboardSkeleton 
    {adminLevel}
    {systemHealth}
    theme="billiard"
    showSystemStatus={true}
    showUserStats={true}
    showRecentActivity={true}
    showQuickActions={true}
  />
{:else}
  <AdminDashboard data={$adminStore} />
{/if}
```

## Bones Pràctiques

### 1. Respectar les Regles del Campionat

```typescript
// ✅ Correcte: Màxim 20 jugadors
<RankingTableSkeleton playerCount={20} />

// ❌ Incorrecte: Més de 20 jugadors
<RankingTableSkeleton playerCount={25} />
```

### 2. Urgència Temporal Realista

```typescript
// ✅ Correcte: Urgència segons dies restants
const urgency = daysRemaining <= 1 ? 'critical' : 
               daysRemaining <= 3 ? 'warning' : 'safe';

<ChallengeCardSkeleton {urgency} {daysRemaining} />
```

### 3. Cleanup Automàtic

```typescript
// ✅ Correcte: Usar withLoading amb autoCleanup
await withLoading(
  'operation-id',
  async () => { /* operació */ },
  { autoCleanup: true }
);

// ❌ Evitar: Gestió manual complexa
loadingStates.start('operation-id');
try {
  // operació
  loadingStates.success('operation-id');
} catch (error) {
  loadingStates.error('operation-id', error);
} finally {
  setTimeout(() => loadingStates.remove('operation-id'), 1000);
}
```

### 4. Configuració Responsiva

```typescript
// ✅ Correcte: Configuració responsiva
import { getResponsiveConfig } from '$lib/utils/skeletonUtils';

$: responsiveConfig = getResponsiveConfig(window.innerWidth);
```

### 5. Fallbacks Offline

```typescript
// ✅ Correcte: Detectar estat offline
import { browser } from '$app/environment';

$: offline = browser ? !navigator.onLine : false;

<RankingTableSkeleton {offline} />
```

### 6. Transicions Fluides

```css
/* ✅ Correcte: Transicions suaus */
.content-container {
  transition: opacity 0.3s ease-in-out;
}

.skeleton-container {
  animation: fadeIn 0.2s ease-out;
}
```

## Troubleshooting

### Problema: Skeletons no desapareixen
**Solució**: Verificar que les dades s'assignen correctament i que els loading states s'actualitzen.

### Problema: Animacions molt lentes
**Solució**: Ajustar `shimmerSpeed` segons el temps transcorregut o usar `prefers-reduced-motion`.

### Problema: Urgències incorrectes
**Solució**: Usar les utilitats `mapPriorityToUrgency` i respectar els deadlines del campionat.

### Problema: Massa skeletons en pantalla
**Solució**: Usar `compact={true}` en mòbil i limitar el nombre d'elements mostrats.

---

Per més informació, consulta els fitxers d'exemple a `src/lib/components/examples/` o els tests a `src/tests/skeletons/`.