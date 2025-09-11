<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/authStore';
  import Banner from '$lib/components/Banner.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;
  let isAdmin = false;

  onMount(async () => {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        // si no hi ha sessió, cap a login
        goto('/login');
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      // comprovar que l'usuari és administrador
      const { data: adm, error: eAdm } = await supabase
        .from('admins')
        .select('email')
        .eq('email', u.email)
        .maybeSingle();

      if (eAdm) throw eAdm;
      if (!adm) {
        error = errText('Només els administradors poden accedir a aquesta pàgina.');
        return;
      }

      isAdmin = true;
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Administració</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Administració</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else if error}
  <Banner type="error" message={error} />
{:else if isAdmin}
  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
    <!-- Targeta: crear repte -->
    <a href="/admin/reptes/nou" class="block rounded-2xl border p-4 hover:shadow-sm">
      <h2 class="font-semibold">➕ Crear repte</h2>
      <p class="text-sm text-slate-600 mt-1">
        Dona d’alta un repte entre dos jugadors. Pots forçar excepcions i programar-lo directament.
      </p>
    </a>

    <!-- Targeta: gestió de reptes (llistat i filtres) -->
    <a href="/admin/reptes" class="block rounded-2xl border p-4 hover:shadow-sm">
      <h2 class="font-semibold">🗂️ Reptes — Gestió</h2>
      <p class="text-sm text-slate-600 mt-1">
        Visualitza, filtra i actualitza l’estat dels reptes (proposats, acceptats, programats, jugats…).
      </p>
    </a>

    <!-- (espai per futures seccions d’admin) -->
    <div class="rounded-2xl border p-4 opacity-70">
      <h2 class="font-semibold">📈 Rànquing / Penes (properament)</h2>
      <p class="text-sm text-slate-600 mt-1">
        Històric de moviments, aplicació de penes i ajustos de posició segons normativa.
      </p>
    </div>
  </div>
{/if}
