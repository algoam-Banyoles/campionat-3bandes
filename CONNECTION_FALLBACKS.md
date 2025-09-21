# Sistema de Fallbacks per Errors de Connexió

Sistema complet de gestió d'errors de connexió per a l'aplicació del Campionat de 3 Bandes, implementant funcionalitats offline, retry automàtic, i sincronització intel·ligent.

## 🎯 Funcionalitats Principals

### ✅ Detecció d'Estat de Connexió
- Monitorització en temps real de connexió a internet i servidor
- Detecció intel·ligent de tipus d'error (xarxa, servidor, autenticació)
- Mesurament de qualitat de connexió (excel·lent, bona, lenta, offline)

### ✅ Sistema de Retry Automàtic
- Backoff exponencial configurable per tipus d'operació
- Estratègies diferenciades (crítiques, estàndard, background)
- Límits intel·ligents de reintents segons tipus d'error

### ✅ Mode Offline Complet
- Cua d'operacions amb prioritats per a processament diferit
- Cache persistent amb IndexedDB per a dades essencials
- Fallbacks automàtics a dades locals quan no hi ha connexió

### ✅ Sincronització Intel·ligent
- Resolució automàtica de conflictes respectant normes del campionat
- Sync en temps real amb Supabase
- Mètriques de rendiment i estats de sincronització

### ✅ Cache Estratègic
- Service Worker per a cache d'assets i dades crítiques
- Estratègies cache-first i network-first segons tipus de recurs
- Neteja automàtica d'entrades expirades

## 📁 Estructura del Sistema

```
src/lib/connection/
├── connectionManager.ts      # Gestor principal de connexió
├── offlineQueue.ts          # Sistema de cua d'operacions offline
├── syncManager.ts           # Gestió de sincronització i conflictes
├── offlineStorage.ts        # Cache persistent amb IndexedDB
├── serviceWorker.ts         # Registre i gestió del Service Worker
└── integration-example.ts   # Exemples d'integració

src/lib/components/
├── ConnectionStatus.svelte   # Component d'estat detallat
└── OfflineIndicator.svelte  # Indicador discret de connexió

static/
├── sw.js                    # Service Worker per cache estratègic
└── offline.html            # Pàgina offline personalitzada
```

## 🚀 Ús Ràpid

### 1. Integració Bàsica

```typescript
import { useConnectionFallbacks } from '$lib/connection/integration-example';

// En el teu component principal
export default function App() {
  useConnectionFallbacks(); // Activa tot el sistema automàticament
  
  return (
    <div>
      <!-- Els teus components -->
      <ConnectionStatus position="top-right" />
      <OfflineIndicator />
    </div>
  );
}
```

### 2. Operacions amb Fallback Automàtic

```typescript
import { connectionManager } from '$lib/connection/connectionManager';

// Operació amb retry automàtic
await connectionManager.executeWithRetry(
  async () => {
    const { error } = await supabase
      .from('reptes')
      .update({ estat: 'acceptat' })
      .eq('id', challengeId);
    if (error) throw error;
  },
  'critical' // Estratègia de retry crítica
);
```

### 3. Cua d'Operacions Offline

```typescript
import { queueOperation } from '$lib/connection/offlineQueue';

// Afegir operació a la cua quan no hi ha connexió
await queueOperation(
  'challenge_accept',
  async () => {
    // L'operació que s'executarà quan es recuperi la connexió
    return await supabase.from('reptes').update(data).eq('id', id);
  },
  { challengeId, data },
  { 
    priority: 'critical',
    userId: currentUserId,
    maxRetries: 5
  }
);
```

### 4. Sincronització Manual

```typescript
import { manualSync } from '$lib/connection/syncManager';

// Forçar sincronització
try {
  await manualSync();
  console.log('Sincronització completada');
} catch (error) {
  console.error('Error en la sincronització:', error);
}
```

## 🔧 Configuració Avançada

### Estratègies de Retry

```typescript
// connectionManager.ts - Configuració per defecte
const retryStrategies = {
  critical: {
    maxRetries: 5,
    baseDelay: 500,
    maxDelay: 10000,
    backoffFactor: 2,
    immediateRetry: true
  },
  standard: {
    maxRetries: 3,
    baseDelay: 1000, 
    maxDelay: 8000,
    backoffFactor: 1.5
  },
  background: {
    maxRetries: 2,
    baseDelay: 2000,
    maxDelay: 15000,
    backoffFactor: 2
  }
};
```

### Configuració de Cache

```typescript
// offlineStorage.ts - TTL per tipus de dada
const tableConfigs = {
  socis: { ttl: 24 * 60 * 60 * 1000, maxItems: 1000 }, // 24h
  reptes: { ttl: 7 * 24 * 60 * 60 * 1000, maxItems: 500 }, // 7 dies
  ranquing: { ttl: 1 * 60 * 60 * 1000, maxItems: 200 }, // 1h
  user_preferences: { ttl: Infinity, maxItems: 10 } // Mai expira
};
```

### Regles de Resolució de Conflictes

```typescript
// syncManager.ts - Regles del campionat
const championshipRules = {
  challengeAcceptanceDeadline: 7 * 24 * 60 * 60 * 1000, // 7 dies
  uniqueChallengePerPair: true,
  mitjanaCalculations: 'additive', // Mai sobreescriure
  rankingUpdates: 'remote_wins', // Font oficial
  userProfile: 'local_wins' // Preferències locals
};
```

## 📊 Monitorització

### Components Visuals

```svelte
<!-- Estat detallat de connexió -->
<ConnectionStatus 
  position="top-right"
  showDetails={true}
  compact={false}
/>

<!-- Indicador discret -->
<OfflineIndicator 
  position="top"
  showWhenOnline={false}
/>
```

### Mètriques Programàtiques

```typescript
import { connectionState, syncMetrics, queueStats } from '$lib/connection';

// Escoltar estat de connexió
connectionState.subscribe(state => {
  console.log('Connexió:', state.isConnected);
  console.log('Qualitat:', state.quality);
  console.log('Reintents:', state.retryCount);
});

// Mètriques de sincronització
syncMetrics.subscribe(metrics => {
  console.log('Syncs exitosos:', metrics.successfulSyncs);
  console.log('Temps mitjà:', metrics.averageSyncTime);
});

// Estat de la cua offline
queueStats.subscribe(stats => {
  console.log('Operacions pendents:', stats.total);
  console.log('Per prioritat:', stats.byPriority);
});
```

## 🔧 Service Worker

El Service Worker s'activa automàticament en producció per:

- **Cache d'assets estàtics**: CSS, JS, fonts, imatges
- **Cache d'API responses**: Dades crítiques per funcionament offline  
- **Fallbacks intel·ligents**: Pàgina offline quan no hi ha connexió
- **Background sync**: Processament automàtic de cua offline

### Configuració Manual

```typescript
import { serviceWorkerManager } from '$lib/connection/serviceWorker';

// Registre manual
await serviceWorkerManager.register();

// Prefetch de recursos crítics
await serviceWorkerManager.prefetchResources([
  '/api/ranking',
  '/api/challenges/active'
]);

// Invalidar cache
await serviceWorkerManager.invalidateCache('/api/ranking');
```

## 🧪 Testing

### Simulació d'Errors de Connexió

```typescript
// Per testing - desactivar la connexió temporalment
navigator.serviceWorker.controller?.postMessage({
  type: 'SIMULATE_OFFLINE',
  duration: 10000 // 10 segons
});
```

### Verificació de Funcionalitat Offline

1. Desactiva la xarxa al navegador
2. Navega per l'aplicació - ha de funcionar amb dades en cache
3. Intenta fer operacions - s'han d'afegir a la cua
4. Reactiva la xarxa - les operacions s'han de processar automàticament

## 📋 Resolució de Problemes

### Problemes Comuns

1. **Service Worker no es registra**
   - Verifica que estàs en mode producció o HTTPS
   - Comprova la consola per errors de registre

2. **Dades no es desen offline**
   - Verifica que IndexedDB està disponible
   - Comprova la quota d'emmagatzematge

3. **Operacions no es processen després de recuperar connexió**
   - Verifica que el `connectionManager` detecta la connexió
   - Comprova l'estat de la cua amb `queueStats`

### Debug

```typescript
// Activar logs detallats
localStorage.setItem('DEBUG_CONNECTION', 'true');

// Verificar estat del sistema
import { checkOfflineCapabilities } from '$lib/connection/integration-example';
const status = await checkOfflineCapabilities();
console.log('Capacitats offline:', status);
```

## 🔮 Funcionalitats Futures

- [ ] Compressió automàtica de dades en cache
- [ ] Sync selectiu per tipus d'usuari
- [ ] Mètriques avançades de rendiment
- [ ] Push notifications per sincronització
- [ ] Cache predictiu basat en patrons d'ús

## 📄 Llicència

Aquest sistema forma part de l'aplicació del Campionat de 3 Bandes i segueix la seva llicència.