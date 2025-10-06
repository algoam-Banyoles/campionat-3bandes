/// <reference types="vite/client" />
import { sveltekit } from '@sveltejs/kit/vite';
// @ts-ignore - Tipus no detectats correctament
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
// @ts-ignore - Tipus no detectats correctament  
import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    hmr: true
  },
  plugins: [
    sveltekit(),
    SvelteKitPWA({
      registerType: 'autoUpdate',
      devOptions: {
        enabled: true,
        type: 'module'
      },
      base: '/',
      scope: '/',
      injectRegister: 'auto',
      includeAssets: ['favicon.ico', 'robots.txt', 'icons/*.png'],
      manifest: false, // Usarem el nostre manifest.json personalitzat
      strategies: 'generateSW',
      filename: 'service-worker.js', // Canviat per evitar conflicte amb sw.js personalitzat
      workbox: {
        cleanupOutdatedCaches: true,
        skipWaiting: true,
        clientsClaim: true,
        // Esborrar tot el cache en cada actualització
        mode: 'production',
        navigateFallback: '/offline.html',
        navigateFallbackDenylist: [/^\/api/, /^\/admin/, /^\/auth/],
        additionalManifestEntries: [
          { url: '/offline.html', revision: null }
        ],
        globPatterns: [
          'client/**/*.{js,css,ico,png,svg,webp,woff,woff2}',
          '*.{html,json,ico,png,svg,webp}',
          'offline.html',
          'prerendered/**/*.html'
        ],
        globIgnores: [
          '**/service-worker.*',
          '**/sw.js', // Ignorar el nostre sw.js personalitzat
          'server/**',
          '**/workbox-*.js'
        ],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-stylesheets',
              cacheableResponse: {
                statuses: [0, 200]
              }
            }
          },
          {
            urlPattern: /^https:\/\/fonts\.gstatic\.com\/.*/,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-webfonts',
              expiration: {
                maxEntries: 30,
                maxAgeSeconds: 60 * 60 * 24 * 365 // 1 any
              },
              cacheableResponse: {
                statuses: [0, 200]
              }
            }
          },
          {
            urlPattern: /\.(js|css)$/,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'static-resources',
              networkTimeoutSeconds: 8,
              cacheableResponse: {
                statuses: [0, 200]
              }
            }
          },
          {
            urlPattern: /^https:\/\/.*\.supabase\.co\/.*/,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'supabase-api',
              networkTimeoutSeconds: 8,
              expiration: {
                maxEntries: 50,
                maxAgeSeconds: 60 * 5 // 5 minuts
              },
              cacheableResponse: {
                statuses: [200]
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
