/**
 * Storage adapter resilient per a la sessió de Supabase Auth.
 *
 * Per què existeix: en PWAs instal·lades (especialment iOS amb Intelligent
 * Tracking Prevention, o Android amb pressió de memòria/neteja del navegador),
 * `localStorage` es pot esborrar entre sessions i l'usuari ha de tornar a
 * loguejar-se. IndexedDB és més durable en aquests contextos.
 *
 * Estratègia: write-through a localStorage + IndexedDB. Lectura prioritza
 * localStorage (síncron, ràpid) i, si falla, fa fallback async a IndexedDB i
 * rehidrata localStorage per a futures lectures.
 *
 * Compatible amb la interfície que espera `@supabase/supabase-js` (mètodes
 * `getItem`, `setItem`, `removeItem`, possiblement async).
 */

const DB_NAME = 'campionat3b-auth';
const DB_VERSION = 1;
const STORE_NAME = 'kv';

let dbPromise: Promise<IDBDatabase | null> | null = null;

function isBrowser(): boolean {
  return typeof window !== 'undefined' && typeof indexedDB !== 'undefined';
}

function openDb(): Promise<IDBDatabase | null> {
  if (!isBrowser()) return Promise.resolve(null);
  if (dbPromise) return dbPromise;

  dbPromise = new Promise((resolve) => {
    try {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME);
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => {
        console.warn('[auth-storage] IndexedDB open error:', req.error);
        resolve(null);
      };
      req.onblocked = () => {
        console.warn('[auth-storage] IndexedDB open blocked');
        resolve(null);
      };
    } catch (e) {
      console.warn('[auth-storage] IndexedDB unavailable:', e);
      resolve(null);
    }
  });

  return dbPromise;
}

async function idbGet(key: string): Promise<string | null> {
  const db = await openDb();
  if (!db) return null;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const req = store.get(key);
      req.onsuccess = () => {
        const val = req.result;
        resolve(typeof val === 'string' ? val : null);
      };
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

async function idbSet(key: string, value: string): Promise<void> {
  const db = await openDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const req = store.put(value, key);
      req.onsuccess = () => resolve();
      req.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

async function idbRemove(key: string): Promise<void> {
  const db = await openDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const req = store.delete(key);
      req.onsuccess = () => resolve();
      req.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

function lsGet(key: string): string | null {
  if (!isBrowser()) return null;
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function lsSet(key: string, value: string): void {
  if (!isBrowser()) return;
  try {
    window.localStorage.setItem(key, value);
  } catch (e) {
    console.warn('[auth-storage] localStorage setItem failed:', e);
  }
}

function lsRemove(key: string): void {
  if (!isBrowser()) return;
  try {
    window.localStorage.removeItem(key);
  } catch {
    /* noop */
  }
}

export const resilientAuthStorage = {
  getItem(key: string): string | null | Promise<string | null> {
    const local = lsGet(key);
    if (local !== null) return local;
    // Si localStorage no té res, intenta IndexedDB i rehidrata localStorage
    return idbGet(key).then((val) => {
      if (val !== null) {
        lsSet(key, val);
      }
      return val;
    });
  },

  setItem(key: string, value: string): void {
    lsSet(key, value);
    // Fire-and-forget: no bloquegem l'usuari per la rèplica a IDB
    void idbSet(key, value);
  },

  removeItem(key: string): void {
    lsRemove(key);
    void idbRemove(key);
  }
};
