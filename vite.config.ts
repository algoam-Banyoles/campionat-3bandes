import { sveltekit } from '@sveltejs/kit/vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    sveltekit(),
    SvelteKitPWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'Campionat 3 Bandes',
        short_name: 'C3B',
        start_url: '/',
        display: 'standalone',
        background_color: '#ffffff',
        theme_color: '#0f172a',
        icons: [
          // Pots afegir icones reals a /static/icons/ si vols
          // { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          // { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' }
        ]
      },
      workbox: {
        runtimeCaching: [
          {
            urlPattern: ({ request }) =>
              ['style', 'script', 'image', 'font'].includes(request.destination),
            handler: 'StaleWhileRevalidate',
            options: { cacheName: 'assets-cache' }
          },
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/api'),
            handler: 'NetworkFirst',
            options: { cacheName: 'api-cache' }
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
