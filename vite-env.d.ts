/// <reference types="vite/client" />
/// <reference types="@types/node" />
/// <reference types="vite-plugin-pwa/client" />

declare module '@vite-pwa/sveltekit' {
  export function SvelteKitPWA(options: any): any;
}

declare module 'vite' {
  export function defineConfig(config: any): any;
}

declare module 'virtual:pwa-register' {
  export function registerSW(options?: {
    immediate?: boolean;
    onNeedRefresh?: () => void;
    onOfflineReady?: () => void;
  }): void;
}

declare module 'virtual:pwa-info' {
  export const pwaInfo: any;
}