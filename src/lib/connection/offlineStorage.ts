import { writable, get } from 'svelte/store';

export interface StorageSchema {
  socis: {
    id: number;
    nom: string;
    cognom: string;
    email?: string;
    telefon?: string;
    data_alta: string;
    actiu: boolean;
    updated_at: string;
  };
  reptes: {
    id: number;
    soci_retador_id: number;
    soci_retat_id: number;
    estat: 'pendent' | 'acceptat' | 'refusat' | 'finalitzat' | 'cancel·lat';
    data_creacio: string;
    data_acceptacio?: string;
    data_limit: string;
    punts_retador?: number;
    punts_retat?: number;
    guanyador_id?: number;
    notes?: string;
    updated_at: string;
  };
  mitjanes: {
    id: number;
    soci_id: number;
    mitjana: number;
    partides_jugades: number;
    periode: string;
    data_calcul: string;
    synced?: boolean;
  };
  ranquing: {
    id: number;
    soci_id: number;
    posicio: number;
    mitjana_actual: number;
    partides_totals: number;
    victories: number;
    derrotes: number;
    updated_at: string;
  };
  user_preferences: {
    user_id: string;
    theme: string;
    notifications: boolean;
    language: string;
    updated_at: string;
  };
}

export interface CacheEntry<T> {
  data: T;
  timestamp: number;
  expiry?: number;
  version: number;
}

export interface StorageStats {
  totalSize: number;
  itemCount: number;
  lastCleanup: Date | null;
  storageQuota: number;
  usedStorage: number;
}

class OfflineStorage {
  private dbName = 'campionat_3bandes_offline';
  private dbVersion = 1;
  private db: IDBDatabase | null = null;
  private storageReady = writable<boolean>(false);
  private storageStats = writable<StorageStats>({
    totalSize: 0,
    itemCount: 0,
    lastCleanup: null,
    storageQuota: 0,
    usedStorage: 0
  });

  private tableConfigs = {
    socis: { ttl: 24 * 60 * 60 * 1000, maxItems: 1000 }, // 24h, max 1000 items
    reptes: { ttl: 7 * 24 * 60 * 60 * 1000, maxItems: 500 }, // 7 days, max 500 items
    mitjanes: { ttl: 24 * 60 * 60 * 1000, maxItems: 2000 }, // 24h, max 2000 items
    ranquing: { ttl: 1 * 60 * 60 * 1000, maxItems: 200 }, // 1h, max 200 items
    user_preferences: { ttl: Infinity, maxItems: 10 } // Never expire, max 10 items
  };

  constructor() {
    if (typeof window !== 'undefined' && 'indexedDB' in window) {
      this.initializeDB();
      this.startPeriodicCleanup();
      this.updateStorageStats();
    }
  }

  private async initializeDB(): Promise<void> {
    if (typeof indexedDB === 'undefined') {
      console.warn('IndexedDB not available');
      return Promise.resolve();
    }

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.dbVersion);

      request.onerror = () => {
        console.error('Error opening IndexedDB:', request.error);
        reject(request.error);
      };

      request.onsuccess = () => {
        this.db = request.result;
        this.storageReady.set(true);
        console.log('✅ OfflineStorage initialized');
        resolve();
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;
        
        // Create object stores for each table
        Object.keys(this.tableConfigs).forEach(tableName => {
          if (!db.objectStoreNames.contains(tableName)) {
            const objectStore = db.createObjectStore(tableName, { keyPath: 'id' });
            
            // Create indexes
            if (tableName === 'socis') {
              objectStore.createIndex('nom', 'nom', { unique: false });
              objectStore.createIndex('email', 'email', { unique: false });
            } else if (tableName === 'reptes') {
              objectStore.createIndex('soci_retador_id', 'soci_retador_id', { unique: false });
              objectStore.createIndex('soci_retat_id', 'soci_retat_id', { unique: false });
              objectStore.createIndex('estat', 'estat', { unique: false });
              objectStore.createIndex('data_creacio', 'data_creacio', { unique: false });
            } else if (tableName === 'mitjanes') {
              objectStore.createIndex('soci_id', 'soci_id', { unique: false });
              objectStore.createIndex('periode', 'periode', { unique: false });
            } else if (tableName === 'ranquing') {
              objectStore.createIndex('soci_id', 'soci_id', { unique: false });
              objectStore.createIndex('posicio', 'posicio', { unique: false });
            }
          }
        });

        // Create metadata store for cache management
        if (!db.objectStoreNames.contains('_metadata')) {
          db.createObjectStore('_metadata', { keyPath: 'key' });
        }
      };
    });
  }

  private startPeriodicCleanup() {
    if (typeof setInterval === 'undefined') return;

    // Clean up expired items every hour
    setInterval(() => {
      this.cleanupExpiredItems();
    }, 60 * 60 * 1000);
  }

  private async updateStorageStats() {
    if (!this.db) return;

    try {
      // Get storage quota (if available)
      let quota = 0;
      let usage = 0;

      if ('storage' in navigator && 'estimate' in navigator.storage) {
        const estimate = await navigator.storage.estimate();
        quota = estimate.quota || 0;
        usage = estimate.usage || 0;
      }

      // Count items across all stores
      let totalItems = 0;
      for (const tableName of Object.keys(this.tableConfigs)) {
        const count = await this.countItems(tableName);
        totalItems += count;
      }

      this.storageStats.update(stats => ({
        ...stats,
        itemCount: totalItems,
        storageQuota: quota,
        usedStorage: usage
      }));

    } catch (error) {
      console.error('Error updating storage stats:', error);
    }
  }

  private async countItems(tableName: string): Promise<number> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([tableName], 'readonly');
      const objectStore = transaction.objectStore(tableName);
      const request = objectStore.count();

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  private async cleanupExpiredItems() {
    if (!this.db) return;

    console.log('🧹 Starting offline storage cleanup...');
    const now = Date.now();
    let totalCleaned = 0;

    for (const [tableName, config] of Object.entries(this.tableConfigs)) {
      if (config.ttl === Infinity) continue; // Skip tables that never expire

      try {
        const expired = await this.getExpiredItems(tableName, now - config.ttl);
        
        for (const item of expired) {
          await this.deleteItem(tableName, item.id);
          totalCleaned++;
        }

        // Also enforce max items limit
        const count = await this.countItems(tableName);
        if (count > config.maxItems) {
          const excess = count - config.maxItems;
          const oldestItems = await this.getOldestItems(tableName, excess);
          
          for (const item of oldestItems) {
            await this.deleteItem(tableName, item.id);
            totalCleaned++;
          }
        }

      } catch (error) {
        console.error(`Error cleaning up ${tableName}:`, error);
      }
    }

    this.storageStats.update(stats => ({
      ...stats,
      lastCleanup: new Date()
    }));

    this.updateStorageStats();

    if (totalCleaned > 0) {
      console.log(`✅ Cleaned up ${totalCleaned} expired items`);
    }
  }

  private async getExpiredItems(tableName: string, cutoffTime: number): Promise<any[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([tableName], 'readonly');
      const objectStore = transaction.objectStore(tableName);
      const request = objectStore.getAll();

      request.onsuccess = () => {
        const items = request.result.filter(item => {
          const timestamp = new Date(item.updated_at || item.data_creacio).getTime();
          return timestamp < cutoffTime;
        });
        resolve(items);
      };

      request.onerror = () => reject(request.error);
    });
  }

  private async getOldestItems(tableName: string, count: number): Promise<any[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([tableName], 'readonly');
      const objectStore = transaction.objectStore(tableName);
      const request = objectStore.getAll();

      request.onsuccess = () => {
        const items = request.result
          .sort((a, b) => {
            const aTime = new Date(a.updated_at || a.data_creacio).getTime();
            const bTime = new Date(b.updated_at || b.data_creacio).getTime();
            return aTime - bTime;
          })
          .slice(0, count);
        resolve(items);
      };

      request.onerror = () => reject(request.error);
    });
  }

  private async deleteItem(tableName: string, id: number | string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([tableName], 'readwrite');
      const objectStore = transaction.objectStore(tableName);
      const request = objectStore.delete(id);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  // Public API
  async store<K extends keyof StorageSchema>(
    table: K,
    data: StorageSchema[K] | StorageSchema[K][]
  ): Promise<void> {
    await this.waitForReady();

    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([table], 'readwrite');
      const objectStore = transaction.objectStore(table);

      const items = Array.isArray(data) ? data : [data];

      let completed = 0;
      const total = items.length;

      for (const item of items) {
        // Add timestamp if not present
        const itemWithTimestamp = {
          ...item,
          updated_at: (item as any).updated_at || new Date().toISOString()
        };

        const request = objectStore.put(itemWithTimestamp);

        request.onsuccess = () => {
          completed++;
          if (completed === total) {
            this.updateStorageStats();
            resolve();
          }
        };

        request.onerror = () => reject(request.error);
      }
    });
  }

  async get<K extends keyof StorageSchema>(
    table: K,
    id: number | string
  ): Promise<StorageSchema[K] | null> {
    await this.waitForReady();

    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([table], 'readonly');
      const objectStore = transaction.objectStore(table);
      const request = objectStore.get(id);

      request.onsuccess = () => {
        const result = request.result;
        
        // Check if item is expired
        if (result && this.isExpired(table, result)) {
          this.deleteItem(table as string, id);
          resolve(null);
        } else {
          resolve(result || null);
        }
      };

      request.onerror = () => reject(request.error);
    });
  }

  async getAll<K extends keyof StorageSchema>(
    table: K,
    filter?: (item: StorageSchema[K]) => boolean
  ): Promise<StorageSchema[K][]> {
    await this.waitForReady();

    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([table], 'readonly');
      const objectStore = transaction.objectStore(table);
      const request = objectStore.getAll();

      request.onsuccess = () => {
        let results = request.result;

        // Filter out expired items
        results = results.filter(item => !this.isExpired(table, item));

        // Apply custom filter if provided
        if (filter) {
          results = results.filter(filter);
        }

        resolve(results);
      };

      request.onerror = () => reject(request.error);
    });
  }

  async query<K extends keyof StorageSchema>(
    table: K,
    indexName: string,
    value: any
  ): Promise<StorageSchema[K][]> {
    await this.waitForReady();

    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([table], 'readonly');
      const objectStore = transaction.objectStore(table);
      
      try {
        const index = objectStore.index(indexName);
        const request = index.getAll(value);

        request.onsuccess = () => {
          const results = request.result.filter(item => !this.isExpired(table, item));
          resolve(results);
        };

        request.onerror = () => reject(request.error);
      } catch (error) {
        reject(error);
      }
    });
  }

  async delete<K extends keyof StorageSchema>(
    table: K,
    id: number | string
  ): Promise<void> {
    await this.waitForReady();
    await this.deleteItem(table as string, id);
    this.updateStorageStats();
  }

  async clear<K extends keyof StorageSchema>(table: K): Promise<void> {
    await this.waitForReady();

    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const transaction = this.db.transaction([table], 'readwrite');
      const objectStore = transaction.objectStore(table);
      const request = objectStore.clear();

      request.onsuccess = () => {
        this.updateStorageStats();
        resolve();
      };

      request.onerror = () => reject(request.error);
    });
  }

  private isExpired<K extends keyof StorageSchema>(table: K, item: StorageSchema[K]): boolean {
    const config = this.tableConfigs[table];
    if (config.ttl === Infinity) return false;

    const itemTime = new Date((item as any).updated_at || (item as any).data_creacio).getTime();
    const now = Date.now();
    
    return (now - itemTime) > config.ttl;
  }

  private async waitForReady(): Promise<void> {
    return new Promise((resolve) => {
      let unsubscribe: (() => void) | undefined;
      
      unsubscribe = this.storageReady.subscribe(ready => {
        if (ready && unsubscribe) {
          unsubscribe();
          resolve();
        }
      });
    });
  }

  // Utility methods
  async getStorageInfo(): Promise<{
    isReady: boolean;
    stats: StorageStats;
    tableConfigs: any;
  }> {
    const ready = get(this.storageReady);
    const stats = get(this.storageStats);
    
    return {
      isReady: ready as boolean,
      stats: stats as any,
      tableConfigs: this.tableConfigs
    };
  }

  async exportData(): Promise<Partial<{ [K in keyof StorageSchema]: StorageSchema[K][] }>> {
    const result: Partial<{ [K in keyof StorageSchema]: StorageSchema[K][] }> = {};
    
    for (const table of Object.keys(this.tableConfigs) as (keyof StorageSchema)[]) {
      (result as any)[table] = await this.getAll(table);
    }
    
    return result;
  }

  async importData(data: Partial<{ [K in keyof StorageSchema]: StorageSchema[K][] }>): Promise<void> {
    for (const [table, items] of Object.entries(data) as [keyof StorageSchema, any[]][]) {
      if (items && items.length > 0) {
        await this.store(table, items);
      }
    }
  }

  getStorageReady() {
    return { subscribe: this.storageReady.subscribe };
  }

  getStorageStats() {
    return { subscribe: this.storageStats.subscribe };
  }

  destroy() {
    if (this.db) {
      this.db.close();
    }
  }
}

// Singleton instance
export const offlineStorage = new OfflineStorage();

// Convenient stores
export const storageReady = offlineStorage.getStorageReady();
export const storageStats = offlineStorage.getStorageStats();

// Utility functions
export async function storeOffline<K extends keyof StorageSchema>(
  table: K,
  data: StorageSchema[K] | StorageSchema[K][]
): Promise<void> {
  return offlineStorage.store(table, data);
}

export async function getOffline<K extends keyof StorageSchema>(
  table: K,
  id: number | string
): Promise<StorageSchema[K] | null> {
  return offlineStorage.get(table, id);
}

export async function getAllOffline<K extends keyof StorageSchema>(
  table: K,
  filter?: (item: StorageSchema[K]) => boolean
): Promise<StorageSchema[K][]> {
  return offlineStorage.getAll(table, filter);
}

export async function queryOffline<K extends keyof StorageSchema>(
  table: K,
  indexName: string,
  value: any
): Promise<StorageSchema[K][]> {
  return offlineStorage.query(table, indexName, value);
}