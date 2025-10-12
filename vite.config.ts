/// <reference types="vite/client" />
import { sveltekit } from '@sveltejs/kit/vite';
// @ts-ignore - Tipus no detectats correctament
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
// @ts-ignore - Tipus no detectats correctament  
import { defineConfig, loadEnv } from 'vite';
import dotenv from 'dotenv';

// Carregar TOTES les variables del fitxer .env a process.env
dotenv.config();

export default defineConfig(({ mode }) => {
  // També carregar variables específiques de Vite
  const env = loadEnv(mode, process.cwd(), '');
  
  // Assegurar que les variables VITE_ també estan disponibles sense prefix
  if (env.VITE_SUPABASE_URL && !process.env.SUPABASE_URL) {
    process.env.SUPABASE_URL = env.VITE_SUPABASE_URL;
  }
  if (env.VITE_SUPABASE_ANON_KEY && !process.env.SUPABASE_ANON_KEY) {
    process.env.SUPABASE_ANON_KEY = env.VITE_SUPABASE_ANON_KEY;
  }
  
  return {
  server: {
    hmr: true
  },
  plugins: [
    sveltekit()
    // Vite-PWA DESACTIVAT - usem sw.js personalitzat que NO intercepta APIs
    // El problema era que Vite-PWA generava un service-worker.js que cachejava
    // les peticions de Supabase i eliminava les capçaleres (apikey)
  ],
  define: {
    'import.meta.env.PUBLIC_SUPABASE_URL': JSON.stringify('https://qbldqtaqawnahuzlzsjs.supabase.co'),
    'import.meta.env.PUBLIC_SUPABASE_ANON_KEY': JSON.stringify('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTkyMDgsImV4cCI6MjA3MjYzNTIwOH0.bLMQFuZkIRW3r41P18Y4eipu1nbNUx3_0QtpwyVZqN4')
  }
  };
});
