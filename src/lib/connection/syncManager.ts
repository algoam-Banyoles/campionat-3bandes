import { writable, derived, get } from 'svelte/store';
import { connectionManager } from './connectionManager';
import { offlineQueue } from './offlineQueue';
import { supabase } from '$lib/supabaseClient';
import type { RealtimeChannel } from '@supabase/supabase-js';

export interface SyncState {
  lastSync: Date | null;
  isSyncing: boolean;
  syncProgress: number;
  conflictsDetected: number;
  conflictsResolved: number;
  syncErrors: string[];
  autoSyncEnabled: boolean;
  syncStrategy: 'conservative' | 'aggressive' | 'manual';
}

export interface ConflictResolution {
  id: string;
  table: string;
  localData: any;
  remoteData: any;
  resolution: 'use_local' | 'use_remote' | 'merge' | 'manual';
  resolvedData?: any;
  timestamp: Date;
}

export interface SyncMetrics {
  totalSyncs: number;
  successfulSyncs: number;
  failedSyncs: number;
  averageSyncTime: number;
  dataTransferred: number;
  conflictsTotal: number;
  conflictsAutoResolved: number;
}

class SyncManager {
  private syncState = writable<SyncState>({
    lastSync: null,
    isSyncing: false,
    syncProgress: 0,
    conflictsDetected: 0,
    conflictsResolved: 0,
    syncErrors: [],
    autoSyncEnabled: true,
    syncStrategy: 'conservative'
  });

  private pendingConflicts = writable<ConflictResolution[]>([]);
  private syncMetrics = writable<SyncMetrics>({
    totalSyncs: 0,
    successfulSyncs: 0,
    failedSyncs: 0,
    averageSyncTime: 0,
    dataTransferred: 0,
    conflictsTotal: 0,
    conflictsAutoResolved: 0
  });

  private realtimeChannel: RealtimeChannel | null = null;
  private syncInterval: number | null = null;
  private lastSyncVersions: Map<string, number> = new Map();

  // Championship business rules for conflict resolution
  private championshipRules = {
    // Challenge acceptance deadline: 7 days
    challengeAcceptanceDeadline: 7 * 24 * 60 * 60 * 1000,
    
    // Only one active challenge per player pair
    uniqueChallengePerPair: true,
    
    // Mitjana calculations are additive, never overwrite
    mitjanaCalculations: 'additive',
    
    // Ranking updates: remote wins (official source)
    rankingUpdates: 'remote_wins',
    
    // User profile: local wins (user preference)
    userProfile: 'local_wins'
  };

  constructor() {
    if (typeof window !== 'undefined') {
      this.initializeRealtimeSync();
      this.startAutoSync();
      this.loadSyncState();

      // Subscribe to connection changes
      connectionManager.isConnected().subscribe(connected => {
        if (connected) {
          this.handleConnectionRestored();
        }
      });
    }
  }

  private loadSyncState() {
    if (typeof localStorage === 'undefined') return;

    try {
      const stored = localStorage.getItem('campionat_sync_state');
      if (stored) {
        const storedState = JSON.parse(stored);
        this.syncState.update(state => ({
          ...state,
          lastSync: storedState.lastSync ? new Date(storedState.lastSync) : null,
          autoSyncEnabled: storedState.autoSyncEnabled ?? true,
          syncStrategy: storedState.syncStrategy || 'conservative'
        }));
      }
    } catch (error) {
      console.error('Error loading sync state:', error);
    }
  }

  private saveSyncState() {
    if (typeof localStorage === 'undefined') return;

    try {
      const state = get(this.syncState);
      localStorage.setItem('campionat_sync_state', JSON.stringify({
        lastSync: (state as any).lastSync,
        autoSyncEnabled: (state as any).autoSyncEnabled,
        syncStrategy: (state as any).syncStrategy
      }));
    } catch (error) {
      console.error('Error saving sync state:', error);
    }
  }

  private initializeRealtimeSync() {
    const connected = get(connectionManager.isConnected());
    if (!connected) return;

    // Subscribe to critical table changes
    this.realtimeChannel = supabase
      .channel('sync_changes')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'reptes' },
        (payload) => this.handleRealtimeChange('reptes', payload)
      )
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'mitjanes' },
        (payload) => this.handleRealtimeChange('mitjanes', payload)
      )
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'ranquing' },
        (payload) => this.handleRealtimeChange('ranquing', payload)
      )
      .subscribe();
  }

  private handleRealtimeChange(table: string, payload: any) {
    console.log(`📡 Realtime change detected in ${table}:`, payload);
    
    // Trigger selective sync for changed data
    this.performSelectiveSync(table, payload);
  }

  private startAutoSync() {
    if (typeof window === 'undefined') return;

    // Auto-sync every 5 minutes when enabled and connected
    this.syncInterval = window.setInterval(() => {
      const state = get(this.syncState);
      const connected = get(connectionManager.isConnected());
      
      if ((state as any).autoSyncEnabled && connected && !(state as any).isSyncing) {
        this.performSync('auto');
      }
    }, 5 * 60 * 1000);
  }

  private async handleConnectionRestored() {
    const state = get(this.syncState);
    
    // Re-initialize realtime if needed
    if (!this.realtimeChannel) {
      this.initializeRealtimeSync();
    }

    // Trigger sync if auto-sync is enabled
    if ((state as any).autoSyncEnabled && !(state as any).isSyncing) {
      await this.performSync('connection_restored');
    }
  }

  private async performSelectiveSync(table: string, change: any) {
    if ((get(this.syncState) as any).isSyncing) return;

    try {
      await this.syncTable(table, [change]);
    } catch (error) {
      console.error(`Error in selective sync for ${table}:`, error);
    }
  }

  private async syncTable(table: string, changes?: any[]): Promise<void> {
    // Implementation depends on table-specific sync logic
    switch (table) {
      case 'reptes':
        await this.syncChallenges(changes);
        break;
      case 'mitjanes':
        await this.syncMitjanes(changes);
        break;
      case 'ranquing':
        await this.syncRanking(changes);
        break;
      default:
        console.warn(`No sync handler for table: ${table}`);
    }
  }

  private async syncChallenges(changes?: any[]): Promise<void> {
    // Get local and remote challenges
    const localChallenges = this.getLocalChallenges();
    const { data: remoteChallenges } = await supabase
      .from('reptes')
      .select('*')
      .order('data_creacio', { ascending: false })
      .limit(100);

    if (!remoteChallenges) return;

    const conflicts: ConflictResolution[] = [];

    // Check for conflicts
    for (const local of localChallenges) {
      const remote = remoteChallenges.find(r => r.id === local.id);
      
      if (remote && this.hasConflict(local, remote)) {
        const resolution = await this.resolveChallengeConflict(local, remote);
        conflicts.push(resolution);
      }
    }

    // Apply conflict resolutions
    for (const conflict of conflicts) {
      await this.applyConflictResolution(conflict);
    }

    this.updateConflictStats(conflicts.length, conflicts.filter(c => c.resolution !== 'manual').length);
  }

  private async syncMitjanes(changes?: any[]): Promise<void> {
    // Mitjanes are additive - no conflicts, just merge
    const localMitjanes = this.getLocalMitjanes();
    
    for (const mitjana of localMitjanes) {
      if (!mitjana.synced) {
        try {
          await supabase.from('mitjanes').insert(mitjana);
          this.markMitjanaSynced(mitjana.id);
        } catch (error) {
          console.error('Error syncing mitjana:', error);
        }
      }
    }
  }

  private async syncRanking(changes?: any[]): Promise<void> {
    // Ranking: remote wins (official source)
    const { data: remoteRanking } = await supabase
      .from('ranquing')
      .select('*')
      .order('posicio', { ascending: true });

    if (remoteRanking) {
      this.updateLocalRanking(remoteRanking);
    }
  }

  private async resolveChallengeConflict(local: any, remote: any): Promise<ConflictResolution> {
    const conflictId = `${local.id}-${Date.now()}`;

    // Championship rule: Check acceptance deadline
    const creationDate = new Date(remote.data_creacio);
    const deadline = new Date(creationDate.getTime() + this.championshipRules.challengeAcceptanceDeadline);
    const now = new Date();

    if (now > deadline && local.estat === 'acceptat' && remote.estat === 'pendent') {
      // Local acceptance after deadline - use remote (expired)
      return {
        id: conflictId,
        table: 'reptes',
        localData: local,
        remoteData: remote,
        resolution: 'use_remote',
        timestamp: new Date()
      };
    }

    // Rule: First acceptance wins
    if (local.estat === 'acceptat' && remote.estat === 'acceptat') {
      const localAcceptTime = new Date(local.data_acceptacio || local.updated_at);
      const remoteAcceptTime = new Date(remote.data_acceptacio || remote.updated_at);
      
      return {
        id: conflictId,
        table: 'reptes',
        localData: local,
        remoteData: remote,
        resolution: localAcceptTime < remoteAcceptTime ? 'use_local' : 'use_remote',
        timestamp: new Date()
      };
    }

    // Default: conservative approach - use remote
    return {
      id: conflictId,
      table: 'reptes',
      localData: local,
      remoteData: remote,
      resolution: 'use_remote',
      timestamp: new Date()
    };
  }

  private hasConflict(local: any, remote: any): boolean {
    // Simple conflict detection based on update timestamps
    const localUpdated = new Date(local.updated_at || local.data_creacio);
    const remoteUpdated = new Date(remote.updated_at || remote.data_creacio);
    
    return Math.abs(localUpdated.getTime() - remoteUpdated.getTime()) > 1000 && 
           JSON.stringify(local) !== JSON.stringify(remote);
  }

  private async applyConflictResolution(conflict: ConflictResolution) {
    try {
      let dataToUse;
      
      switch (conflict.resolution) {
        case 'use_local':
          dataToUse = conflict.localData;
          await supabase.from(conflict.table).upsert(dataToUse);
          break;
        case 'use_remote':
          dataToUse = conflict.remoteData;
          this.updateLocalData(conflict.table, dataToUse);
          break;
        case 'merge':
          dataToUse = conflict.resolvedData;
          await supabase.from(conflict.table).upsert(dataToUse);
          this.updateLocalData(conflict.table, dataToUse);
          break;
        case 'manual':
          // Add to pending conflicts for manual resolution
          this.pendingConflicts.update(conflicts => [...conflicts, conflict]);
          return;
      }

      console.log(`✅ Resolved conflict for ${conflict.table}:`, conflict.resolution);
      
    } catch (error) {
      console.error('Error applying conflict resolution:', error);
      throw error;
    }
  }

  // Placeholder methods - would be implemented based on actual data layer
  private getLocalChallenges(): any[] {
    // Would get from local cache/storage
    return [];
  }

  private getLocalMitjanes(): any[] {
    // Would get from local cache/storage
    return [];
  }

  private markMitjanaSynced(id: string) {
    // Would mark in local storage
  }

  private updateLocalRanking(ranking: any[]) {
    // Would update local cache
  }

  private updateLocalData(table: string, data: any) {
    // Would update local cache/storage
  }

  private updateConflictStats(detected: number, resolved: number) {
    this.syncState.update(state => ({
      ...state,
      conflictsDetected: detected,
      conflictsResolved: resolved
    }));
  }

  // Public API
  async performSync(trigger: 'manual' | 'auto' | 'connection_restored' = 'manual'): Promise<void> {
    const state = get(this.syncState);
    if ((state as any).isSyncing) return;

    const connected = get(connectionManager.isConnected());
    if (!connected) {
      throw new Error('Cannot sync while offline');
    }

    const startTime = performance.now();

    this.syncState.update(s => ({
      ...s,
      isSyncing: true,
      syncProgress: 0,
      syncErrors: []
    }));

    try {
      // Sync tables sequentially
      const tables = ['reptes', 'mitjanes', 'ranquing'];
      
      for (let i = 0; i < tables.length; i++) {
        const table = tables[i];
        await this.syncTable(table);
        
        const progress = ((i + 1) / tables.length) * 100;
        this.syncState.update(s => ({ ...s, syncProgress: progress }));
      }

      // Process offline queue
      await offlineQueue.forceProcessQueue();

      const endTime = performance.now();
      const syncTime = endTime - startTime;

      // Update metrics
      this.syncMetrics.update(metrics => ({
        ...metrics,
        totalSyncs: metrics.totalSyncs + 1,
        successfulSyncs: metrics.successfulSyncs + 1,
        averageSyncTime: (metrics.averageSyncTime * metrics.totalSyncs + syncTime) / (metrics.totalSyncs + 1)
      }));

      this.syncState.update(s => ({
        ...s,
        lastSync: new Date(),
        isSyncing: false,
        syncProgress: 100
      }));

      this.saveSyncState();

      console.log(`✅ Sync completed in ${syncTime.toFixed(2)}ms (${trigger})`);

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      
      this.syncState.update(s => ({
        ...s,
        isSyncing: false,
        syncErrors: [...s.syncErrors, errorMessage]
      }));

      this.syncMetrics.update(metrics => ({
        ...metrics,
        totalSyncs: metrics.totalSyncs + 1,
        failedSyncs: metrics.failedSyncs + 1
      }));

      console.error('❌ Sync failed:', error);
      throw error;
    }
  }

  async resolveConflictManually(conflictId: string, resolution: 'use_local' | 'use_remote' | 'merge', mergedData?: any) {
    const conflicts = get(this.pendingConflicts) as any;
    const conflict = conflicts.find((c: any) => c.id === conflictId);
    
    if (!conflict) {
      throw new Error('Conflict not found');
    }

    const updatedConflict = {
      ...conflict,
      resolution,
      resolvedData: mergedData
    };

    await this.applyConflictResolution(updatedConflict);

    this.pendingConflicts.update(conflicts => 
      conflicts.filter(c => c.id !== conflictId)
    );
  }

  enableAutoSync(enabled: boolean) {
    this.syncState.update(s => ({ ...s, autoSyncEnabled: enabled }));
    this.saveSyncState();
  }

  setSyncStrategy(strategy: 'conservative' | 'aggressive' | 'manual') {
    this.syncState.update(s => ({ ...s, syncStrategy: strategy }));
    this.saveSyncState();
  }

  // Store getters
  getSyncState() {
    return { subscribe: this.syncState.subscribe };
  }

  getPendingConflicts() {
    return { subscribe: this.pendingConflicts.subscribe };
  }

  getSyncMetrics() {
    return { subscribe: this.syncMetrics.subscribe };
  }

  isSyncing() {
    return derived(this.syncState, $state => $state.isSyncing);
  }

  getLastSync() {
    return derived(this.syncState, $state => $state.lastSync);
  }

  destroy() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }

    if (this.realtimeChannel) {
      this.realtimeChannel.unsubscribe();
    }
  }
}

// Singleton instance
export const syncManager = new SyncManager();

// Convenient stores
export const syncState = syncManager.getSyncState();
export const pendingConflicts = syncManager.getPendingConflicts();
export const syncMetrics = syncManager.getSyncMetrics();
export const isSyncing = syncManager.isSyncing();
export const lastSync = syncManager.getLastSync();

// Utility functions
export async function manualSync(): Promise<void> {
  return syncManager.performSync('manual');
}

export async function resolveConflict(
  conflictId: string, 
  resolution: 'use_local' | 'use_remote' | 'merge', 
  mergedData?: any
): Promise<void> {
  return syncManager.resolveConflictManually(conflictId, resolution, mergedData);
}