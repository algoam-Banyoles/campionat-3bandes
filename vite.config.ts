import { sveltekit } from '@sveltejs/kit/vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    sveltekit(),
    SvelteKitPWA({
      registerType: 'autoUpdate',
      mode: 'development',
      base: '/',
      scope: '/',
      injectRegister: 'auto',
      includeAssets: ['favicon.ico', 'robots.txt', 'icons/*.png'],
      manifest: false, // Usarem el nostre manifest.json personalitzat
      workbox: {
        cleanupOutdatedCaches: true,
        navigateFallback: '/offline',
        navigateFallbackDenylist: [/^\/api/, /^\/admin/],
        runtimeCaching: [
          {
            urlPattern: ({ request }) =>
              request.destination === 'document',
            handler: 'NetworkFirst',
            options: {
              cacheName: 'pages-cache',
              networkTimeoutSeconds: 3
            }
          },
          {
            urlPattern: ({ request }) =>
              ['style', 'script', 'worker'].includes(request.destination),
            handler: 'StaleWhileRevalidate',
            options: { 
              cacheName: 'assets-cache'
            }
          },
          {
            urlPattern: ({ request }) =>
              ['image', 'font'].includes(request.destination),
            handler: 'CacheFirst',
            options: { 
              cacheName: 'media-cache',
              expiration: {
                maxEntries: 50,
                maxAgeSeconds: 30 * 24 * 60 * 60 // 30 dies
              }
            }
          }
        ]
      }
    })
  ],
  define: {
    'import.meta.env.PUBLIC_SUPABASE_URL': JSON.stringify('https://qbldqtaqawnahuzlzsjs.supabase.co'),
    'import.meta.env.PUBLIC_SUPABASE_ANON_KEY': JSON.stringify('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTkyMDgsImV4cCI6MjA3MjYzNTIwOH0.bLMQFuZkIRW3r41P18Y4eipu1nbNUx3_0QtpwyVZqN4')
  }
});
