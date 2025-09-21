import { writable, derived, type Readable } from 'svelte/store';

// Tipus per diferents estats de càrrega
export type LoadingState = 'idle' | 'loading' | 'success' | 'error';
export type LoadingPriority = 'low' | 'normal' | 'high' | 'critical';

// Interfície per un estat de càrrega individual
export interface LoadingItem {
  id: string;
  state: LoadingState;
  priority: LoadingPriority;
  message?: string;
  error?: string;
  startTime: number;
  endTime?: number;
  timeout?: number;
}

// Store principal per gestionar tots els estats de càrrega
function createLoadingStatesStore() {
  const { subscribe, update } = writable<Map<string, LoadingItem>>(new Map());

  return {
    subscribe,
    
    // Iniciar un nou estat de càrrega
    start: (
      id: string, 
      priority: LoadingPriority = 'normal', 
      message?: string,
      timeout?: number
    ) => {
      update(states => {
        const newItem: LoadingItem = {
          id,
          state: 'loading',
          priority,
          message,
          startTime: Date.now(),
          timeout
        };
        
        states.set(id, newItem);
        
        // Configurar timeout si està especificat
        if (timeout) {
          setTimeout(() => {
            update(currentStates => {
              const item = currentStates.get(id);
              if (item && item.state === 'loading') {
                item.state = 'error';
                item.error = 'Timeout: La operació ha trigat massa temps';
                item.endTime = Date.now();
              }
              return currentStates;
            });
          }, timeout);
        }
        
        return states;
      });
    },
    
    // Marcar com a completat amb èxit
    success: (id: string, message?: string) => {
      update(states => {
        const item = states.get(id);
        if (item) {
          item.state = 'success';
          item.message = message;
          item.endTime = Date.now();
        }
        return states;
      });
    },
    
    // Marcar com a error
    error: (id: string, error: string) => {
      update(states => {
        const item = states.get(id);
        if (item) {
          item.state = 'error';
          item.error = error;
          item.endTime = Date.now();
        }
        return states;
      });
    },
    
    // Actualitzar missatge durant la càrrega
    updateMessage: (id: string, message: string) => {
      update(states => {
        const item = states.get(id);
        if (item && item.state === 'loading') {
          item.message = message;
        }
        return states;
      });
    },
    
    // Eliminar un estat de càrrega
    remove: (id: string) => {
      update(states => {
        states.delete(id);
        return states;
      });
    },
    
    // Netejar tots els estats completats
    clearCompleted: () => {
      update(states => {
        for (const [id, item] of states) {
          if (item.state === 'success' || item.state === 'error') {
            states.delete(id);
          }
        }
        return states;
      });
    },
    
    // Netejar tots els estats
    clear: () => {
      update(() => new Map());
    }
  };
}

export const loadingStates = createLoadingStatesStore();

// Store derivat per obtenir només els estats que estan carregant
export const isLoading: Readable<boolean> = derived(
  loadingStates,
  $states => {
    for (const item of $states.values()) {
      if (item.state === 'loading') return true;
    }
    return false;
  }
);

// Store derivat per obtenir el nombre total d'operacions que estan carregant
export const loadingCount: Readable<number> = derived(
  loadingStates,
  $states => {
    let count = 0;
    for (const item of $states.values()) {
      if (item.state === 'loading') count++;
    }
    return count;
  }
);

// Store derivat per obtenir només els errors actius
export const activeErrors: Readable<LoadingItem[]> = derived(
  loadingStates,
  $states => {
    const errors: LoadingItem[] = [];
    for (const item of $states.values()) {
      if (item.state === 'error') {
        errors.push(item);
      }
    }
    return errors.sort((a, b) => {
      // Ordenar per prioritat i després per temps
      const priorityOrder = { critical: 4, high: 3, normal: 2, low: 1 };
      const priorityDiff = priorityOrder[b.priority] - priorityOrder[a.priority];
      if (priorityDiff !== 0) return priorityDiff;
      return b.startTime - a.startTime;
    });
  }
);

// Store derivat per obtenir operacions per prioritat
export const loadingByPriority: Readable<Record<LoadingPriority, LoadingItem[]>> = derived(
  loadingStates,
  $states => {
    const byPriority: Record<LoadingPriority, LoadingItem[]> = {
      low: [],
      normal: [],
      high: [],
      critical: []
    };
    
    for (const item of $states.values()) {
      if (item.state === 'loading') {
        byPriority[item.priority].push(item);
      }
    }
    
    // Ordenar cada grup per temps d'inici
    Object.keys(byPriority).forEach(priority => {
      byPriority[priority as LoadingPriority].sort((a, b) => a.startTime - b.startTime);
    });
    
    return byPriority;
  }
);

// Helpers per crear loading states específics del campionat
export const championshipLoadingIds = {
  FETCH_RANKINGS: 'fetch-rankings',
  CREATE_CHALLENGE: 'create-challenge',
  ACCEPT_CHALLENGE: 'accept-challenge',
  REJECT_CHALLENGE: 'reject-challenge',
  REPORT_MATCH: 'report-match',
  DISPUTE_RESULT: 'dispute-result',
  JOIN_WAITING_LIST: 'join-waiting-list',
  LEAVE_WAITING_LIST: 'leave-waiting-list',
  UPDATE_PROFILE: 'update-profile',
  SYNC_OFFLINE_DATA: 'sync-offline-data',
  ADMIN_USER_MANAGEMENT: 'admin-user-management',
  ADMIN_SYSTEM_STATUS: 'admin-system-status'
} as const;

// Helper per obtenir l'estat d'una operació específica
export function getLoadingState(id: string): Readable<LoadingItem | undefined> {
  return derived(
    loadingStates,
    $states => $states.get(id)
  );
}

// Helper per comprovar si una operació específica està carregant
export function isLoadingById(id: string): Readable<boolean> {
  return derived(
    loadingStates,
    $states => {
      const item = $states.get(id);
      return item ? item.state === 'loading' : false;
    }
  );
}

// Helper per obtenir el temps transcorregut d'una operació
export function getElapsedTime(item: LoadingItem): number {
  const endTime = item.endTime || Date.now();
  return endTime - item.startTime;
}

// Helper per determinar si una operació ha superat el temps esperat
export function isOperationSlow(item: LoadingItem, expectedDuration: number = 3000): boolean {
  return item.state === 'loading' && getElapsedTime(item) > expectedDuration;
}

// Wrapper per crear operacions amb cleanup automàtic
export async function withLoading<T>(
  id: string,
  operation: () => Promise<T>,
  options?: {
    priority?: LoadingPriority;
    message?: string;
    timeout?: number;
    autoCleanup?: boolean;
  }
): Promise<T> {
  const {
    priority = 'normal',
    message,
    timeout = 30000, // 30 segons per defecte
    autoCleanup = true
  } = options || {};

  try {
    loadingStates.start(id, priority, message, timeout);
    const result = await operation();
    loadingStates.success(id, 'Operació completada amb èxit');
    
    if (autoCleanup) {
      // Netejar després d'un breu temps per mostrar l'èxit
      setTimeout(() => {
        loadingStates.remove(id);
      }, 1000);
    }
    
    return result;
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Error desconegut';
    loadingStates.error(id, errorMessage);
    
    if (autoCleanup) {
      // Mantenir els errors més temps per que l'usuari els pugui veure
      setTimeout(() => {
        loadingStates.remove(id);
      }, 5000);
    }
    
    throw error;
  }
}