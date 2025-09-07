<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { goto } from '$app/navigation';
  import { loadingAuth, user } from '$lib/authStore';
  import { get } from 'svelte/store';

  let email = '';
  let password = '';
  let loading = false;
  let error: string | null = null;
  let mode: 'signin' | 'signup' = 'signin';

  async function submit() {
    error = null;
    loading = true;
    try {
      if (mode === 'signin') {
        const { error: err } = await supabase.auth.signInWithPassword({ email, password });
        if (err) throw err;
      } else {
        const { error: err } = await supabase.auth.signUp({ email, password });
        if (err) throw err;
      }
      // si ha anat bé, cap a l'inici
      await goto('/');
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Inicia sessió</title>
</svelte:head>

<div class="mx-auto max-w-md space-y-4">
  <h1 class="text-2xl font-semibold">{mode === 'signin' ? 'Inicia sessió' : 'Crea compte'}</h1>

  {#if $loadingAuth && !$user}
    <p class="text-slate-500">Carregant…</p>
  {:else if $user}
    <div class="rounded border p-3 bg-green-50">
      Ja has iniciat sessió com <strong>{$user.email}</strong>.
    </div>
  {:else}
    {#if error}
      <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3">{error}</div>
    {/if}

    <form class="space-y-3" on:submit|preventDefault={submit}>
      <div>
        <label class="block text-sm font-medium mb-1">Email</label>
        <input class="w-full border rounded px-3 py-2" type="email" bind:value={email} required />
      </div>
      <div>
        <label class="block text-sm font-medium mb-1">Contrasenya</label>
        <input class="w-full border rounded px-3 py-2" type="password" bind:value={password} required minlength="6" />
      </div>

      <button
        class="w-full rounded bg-slate-900 text-white py-2 font-medium disabled:opacity-60"
        disabled={loading}
        type="submit">
        {loading ? 'Processant…' : mode === 'signin' ? 'Entrar' : 'Registrar'}
      </button>
    </form>

    <p class="text-sm text-slate-600">
      {mode === 'signin' ? "No tens compte?" : "Ja tens compte?"}
      <button class="underline" on:click={() => (mode = mode === 'signin' ? 'signup' : 'signin')}>
        {mode === 'signin' ? 'Registra’t' : 'Entra'}
      </button>
    </p>
  {/if}
</div>
