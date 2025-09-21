/// <reference types="vite/client" />
/// <reference types="@types/node" />

declare module '@vite-pwa/sveltekit' {
  export function SvelteKitPWA(options: any): any;
}

declare module 'vite' {
  export function defineConfig(config: any): any;
}