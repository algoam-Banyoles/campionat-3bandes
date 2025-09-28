<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { goto } from '$app/navigation';

  let password = '';
  let loading = false;
  let uiError: string | null = null;
  let okMsg: string | null = null;

  async function updatePassword() {
    uiError = null; okMsg = null;
    if (!password) { uiError = 'Escriu una nova contrasenya.'; return; }
    try {
      loading = true;
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw error;
      okMsg = 'Contrasenya actualitzada.';
      await goto('/login');
    } catch (e:any) {
      uiError = e?.message ?? 'No s’ha pogut actualitzar la contrasenya';
    } finally {
      loading = false;
    }
  }
</script>

<h1 class="text-2xl font-semibold mb-4">Restableix la contrasenya</h1>

{#if uiError}
  <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{uiError}</div>
{/if}
{#if okMsg}
  <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{okMsg}</div>
{/if}

<form class="max-w-sm space-y-3" on:submit|preventDefault={updatePassword}>
  <div>
    <label for="newpass" class="block text-sm mb-1">Nova contrasenya</label>
    <input id="newpass" type="password" class="w-full rounded border px-3 py-2" bind:value={password} />
  </div>
  <button class="rounded bg-slate-900 text-white px-3 py-2 disabled:opacity-60" disabled={loading} type="submit">
    {loading ? 'Processant…' : 'Actualitza contrasenya'}
  </button>
</form>
