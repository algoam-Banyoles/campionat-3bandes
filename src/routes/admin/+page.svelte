<script lang="ts">
  import { onMount } from 'svelte';
  import { user, loadingAuth } from '$lib/authStore';
  import { get } from 'svelte/store';
  import { isAdmin } from '$lib/isAdmin';
  import { goto } from '$app/navigation';

  let allowed = false;
  let checking = true;
  let error: string | null = null;

  onMount(async () => {
    try {
      // si no hi ha usuari, cap al login
      if (!get(user)) {
        goto('/login');
        return;
      }
      // comprova si és admin
      allowed = await isAdmin();
      if (!allowed) {
        error = 'No tens permisos per accedir a aquesta secció.';
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      checking = false;
    }
  });
</script>

<svelte:head>
  <title>Panell d’Administració</title>
</svelte:head>

{#if $loadingAuth || checking}
  <p class="text-slate-500">Comprovant permisos…</p>
{:else if error}
  <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3">{error}</div>
{:else if allowed}
  <div class="space-y-4">
    <h1 class="text-2xl font-semibold">Panell d’Administració</h1>
    <p class="text-slate-600">Eines de gestió del rànquing, reptes i resultats.</p>

    <div class="grid gap-4 md:grid-cols-2">
      <a href="/admin/ranking" class="block rounded border p-4 hover:bg-slate-50">
        <h2 class="font-semibold mb-1">Rànquing</h2>
        <p class="text-slate-600 text-sm">Veure/editar posicions, moure jugadors (intercanvi), historial.</p>
      </a>

      <a href="/admin/reptes" class="block rounded border p-4 hover:bg-slate-50">
        <h2 class="font-semibold mb-1">Reptes</h2>
        <p class="text-slate-600 text-sm">Crear, acceptar/refusar, control de terminis i penalitzacions.</p>
      </a>

      <a href="/admin/partides" class="block rounded border p-4 hover:bg-slate-50">
        <h2 class="font-semibold mb-1">Partides</h2>
        <p class="text-slate-600 text-sm">Acta digital i registre de resultats, tie-break.</p>
      </a>

      <a href="/admin/llista-espera" class="block rounded border p-4 hover:bg-slate-50">
        <h2 class="font-semibold mb-1">Llista d’espera</h2>
        <p class="text-slate-600 text-sm">Gestió d’accessos (repte al 20è), altes/baixes.</p>
      </a>
    </div>
  </div>
{/if}
