import { writable, get } from 'svelte/store';
import { connectionManager } from './connectionManager';
import type { RealtimeChannel } from '@supabase/supabase-js';

export interface QueuedOperation {
  id: string;
  type: 'challenge_create' | 'challenge_accept' | 'challenge_refuse' | 'challenge_cancel' | 
        'ranking_update' | 'user_update' | 'mitjana_add' | 'mitjana_update' | 'generic';
  priority: 'critical' | 'high' | 'normal' | 'low';
  operation: () => Promise<any>;
  data: any;
  timestamp: Date;
  retryCount: number;
  maxRetries: number;
  lastError?: string;
  userId?: string;
  expiresAt?: Date;
}

export interface QueueStats {
  total: number;
  pending: number;
  processing: number;
  failed: number;
  byPriority: Record<string, number>;
  byType: Record<string, number>;
}

class OfflineQueue {
  private queue = writable<QueuedOperation[]>([]);
  private isProcessing = writable<boolean>(false);
  private processingOperation = writable<string | null>(null);
  private processedOperations = writable<string[]>([]);
  private failedOperations = writable<string[]>([]);

  private processingInterval: number | null = null;
  private storageKey = 'campionat_offline_queue';

  // Priority weights for sorting
  private priorityWeights = {
    critical: 4,
    high: 3,
    normal: 2,
    low: 1
  };

  // Operation type configurations
  private operationConfigs = {
    challenge_create: { maxRetries: 3, priority: 'high', expirationHours: 24 },
    challenge_accept: { maxRetries: 5, priority: 'critical', expirationHours: 168 }, // 7 days
    challenge_refuse: { maxRetries: 3, priority: 'high', expirationHours: 168 },
    challenge_cancel: { maxRetries: 3, priority: 'normal', expirationHours: 24 },
    ranking_update: { maxRetries: 2, priority: 'normal', expirationHours: 72 },
    user_update: { maxRetries: 2, priority: 'normal', expirationHours: 24 },
    mitjana_add: { maxRetries: 3, priority: 'high', expirationHours: 48 },
    mitjana_update: { maxRetries: 2, priority: 'normal', expirationHours: 48 },
    generic: { maxRetries: 1, priority: 'low', expirationHours: 12 }
  };

  constructor() {
    this.loadFromStorage();
    this.startProcessing();
    
    // Subscribe to connection changes
    connectionManager.isConnected().subscribe(connected => {
      if (connected) {
        this.processQueue();
      }
    });
  }

  private loadFromStorage() {
    try {
      const stored = localStorage.getItem(this.storageKey);
      if (stored) {
        const operations: QueuedOperation[] = JSON.parse(stored);
        
        // Filter out expired operations
        const validOperations = operations.filter(op => {
          if (op.expiresAt) {
            return new Date(op.expiresAt) > new Date();
          }
          return true;
        });

        this.queue.set(validOperations);
      }
    } catch (error) {
      console.error('Error loading offline queue from storage:', error);
    }
  }

  private saveToStorage() {
    try {
      const currentQueue = get(this.queue);
      localStorage.setItem(this.storageKey, JSON.stringify(currentQueue));
    } catch (error) {
      console.error('Error saving offline queue to storage:', error);
    }
  }

  private startProcessing() {
    // Process queue every 5 seconds when connected
    this.processingInterval = window.setInterval(() => {
      const connected = get(connectionManager.isConnected());
      const processing = get(this.isProcessing);
      
      if (connected && !processing) {
        this.processQueue();
      }
    }, 5000);
  }

  private generateId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private calculateExpiration(type: QueuedOperation['type']): Date {
    const config = this.operationConfigs[type];
    const expirationTime = new Date();
    expirationTime.setHours(expirationTime.getHours() + config.expirationHours);
    return expirationTime;
  }

  private sortQueue(operations: QueuedOperation[]): QueuedOperation[] {
    return operations.sort((a, b) => {
      // First, sort by priority
      const priorityDiff = this.priorityWeights[b.priority] - this.priorityWeights[a.priority];
      if (priorityDiff !== 0) return priorityDiff;
      
      // Then by timestamp (older first)
      return a.timestamp.getTime() - b.timestamp.getTime();
    });
  }

  async enqueue(
    type: QueuedOperation['type'],
    operation: () => Promise<any>,
    data: any,
    options?: {
      priority?: QueuedOperation['priority'];
      maxRetries?: number;
      userId?: string;
      customExpiration?: Date;
    }
  ): Promise<string> {
    const config = this.operationConfigs[type];
    const id = this.generateId();

    const queuedOperation: QueuedOperation = {
      id,
      type,
      priority: options?.priority || config.priority as QueuedOperation['priority'],
      operation,
      data,
      timestamp: new Date(),
      retryCount: 0,
      maxRetries: options?.maxRetries || config.maxRetries,
      userId: options?.userId,
      expiresAt: options?.customExpiration || this.calculateExpiration(type)
    };

    this.queue.update(queue => {
      const newQueue = [...queue, queuedOperation];
      return this.sortQueue(newQueue);
    });

    this.saveToStorage();

    // Try to process immediately if connected
    const connected = get(connectionManager.isConnected());
    if (connected) {
      this.processQueue();
    }

    return id;
  }

  private async processQueue() {
    const processing = get(this.isProcessing);
    if (processing) return;

    const queue = get(this.queue);
    if (queue.length === 0) return;

    const connected = get(connectionManager.isConnected());
    if (!connected) return;

    this.isProcessing.set(true);

    try {
      // Get the next operation to process
      const operation = queue[0];
      this.processingOperation.set(operation.id);

      try {
        // Execute the operation with connection retry
        await connectionManager.executeWithRetry(
          operation.operation,
          operation.priority === 'critical' ? 'critical' : 'standard'
        );

        // Success - remove from queue and add to processed
        this.queue.update(q => q.filter(op => op.id !== operation.id));
        this.processedOperations.update(processed => [operation.id, ...processed].slice(0, 100));

        console.log(`✅ Processed offline operation: ${operation.type}`, operation.data);

      } catch (error) {
        // Handle failure
        const errorMessage = error instanceof Error ? error.message : String(error);
        
        if (operation.retryCount < operation.maxRetries) {
          // Retry - update retry count and move to end of queue
          this.queue.update(queue => {
            const updatedQueue = queue.map(op => 
              op.id === operation.id 
                ? { ...op, retryCount: op.retryCount + 1, lastError: errorMessage }
                : op
            );
            return this.sortQueue(updatedQueue);
          });

          console.warn(`⚠️ Retrying offline operation (${operation.retryCount + 1}/${operation.maxRetries}): ${operation.type}`, errorMessage);

        } else {
          // Max retries reached - move to failed
          this.queue.update(q => q.filter(op => op.id !== operation.id));
          this.failedOperations.update(failed => [operation.id, ...failed].slice(0, 50));

          console.error(`❌ Failed offline operation after ${operation.maxRetries} retries: ${operation.type}`, errorMessage);
        }
      }

    } finally {
      this.isProcessing.set(false);
      this.processingOperation.set(null);
      this.saveToStorage();

      // Continue processing if there are more operations
      const remainingQueue = get(this.queue);
      if (remainingQueue.length > 0) {
        setTimeout(() => this.processQueue(), 1000);
      }
    }
  }

  // Public API
  getQueue() {
    return { subscribe: this.queue.subscribe };
  }

  getProcessingState() {
    return { subscribe: this.isProcessing.subscribe };
  }

  getCurrentOperation() {
    return { subscribe: this.processingOperation.subscribe };
  }

  getStats() {
    return {
      subscribe: (callback: (stats: QueueStats) => void) => {
        return this.queue.subscribe(queue => {
          const stats: QueueStats = {
            total: queue.length,
            pending: queue.filter(op => op.retryCount === 0).length,
            processing: get(this.isProcessing) ? 1 : 0,
            failed: get(this.failedOperations).length,
            byPriority: {
              critical: queue.filter(op => op.priority === 'critical').length,
              high: queue.filter(op => op.priority === 'high').length,
              normal: queue.filter(op => op.priority === 'normal').length,
              low: queue.filter(op => op.priority === 'low').length
            },
            byType: queue.reduce((acc, op) => {
              acc[op.type] = (acc[op.type] || 0) + 1;
              return acc;
            }, {} as Record<string, number>)
          };
          callback(stats);
        });
      }
    };
  }

  async forceProcessQueue() {
    await this.processQueue();
  }

  removeOperation(id: string): boolean {
    const queue = get(this.queue);
    const operationExists = queue.some(op => op.id === id);
    
    if (operationExists) {
      this.queue.update(q => q.filter(op => op.id !== id));
      this.saveToStorage();
      return true;
    }
    
    return false;
  }

  clearQueue() {
    this.queue.set([]);
    this.saveToStorage();
  }

  clearProcessedOperations() {
    this.processedOperations.set([]);
  }

  clearFailedOperations() {
    this.failedOperations.set([]);
  }

  getQueueSize(): number {
    return get(this.queue).length;
  }

  hasOperationOfType(type: QueuedOperation['type']): boolean {
    const queue = get(this.queue);
    return queue.some(op => op.type === type);
  }

  getOperationsByUser(userId: string): QueuedOperation[] {
    const queue = get(this.queue);
    return queue.filter(op => op.userId === userId);
  }

  destroy() {
    if (this.processingInterval) {
      clearInterval(this.processingInterval);
    }
  }
}

// Singleton instance
export const offlineQueue = new OfflineQueue();

// Convenient stores
export const queueState = offlineQueue.getQueue();
export const isProcessingQueue = offlineQueue.getProcessingState();
export const currentOperation = offlineQueue.getCurrentOperation();
export const queueStats = offlineQueue.getStats();

// Utility functions
export async function queueOperation<T>(
  type: QueuedOperation['type'],
  operation: () => Promise<T>,
  data: any,
  options?: {
    priority?: QueuedOperation['priority'];
    maxRetries?: number;
    userId?: string;
  }
): Promise<string> {
  return offlineQueue.enqueue(type, operation, data, options);
}

export function hasQueuedOperations(): boolean {
  return offlineQueue.getQueueSize() > 0;
}