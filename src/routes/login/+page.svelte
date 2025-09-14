<script lang="ts">
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
    import { status, user } from '$lib/authStore';

  let mode: 'login' | 'signup' = 'login';
  let email = '';
  let password = '';
  let loading = false;

  let uiError: string | null = null;
  let okMsg: string | null = null;

  async function onSubmit() {
    uiError = null; okMsg = null;
    if (!email || !password) {
      uiError = 'Cal email i contrasenya.';
      return;
    }
    try {
      loading = true;
      if (mode === 'login') {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        const session = data?.session;
        if (session) {
          await fetch('/api/session', {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
              access_token: session.access_token,
              refresh_token: session.refresh_token,
              expires_at: session.expires_at
            })
          });
        }
        okMsg = 'Sessió iniciada correctament.';
        await goto('/');   // redirigeix on vulguis
      } else {
        // Crear compte
        const { error } = await supabase.auth.signUp({ email, password });
        if (error) throw error;
        okMsg = 'Compte creat. Si requereix confirmació, revisa el correu.';
        mode = 'login';
      }
    } catch (e: any) {
      uiError = e?.message ?? 'Error d’autenticació';
    } finally {
      loading = false;
    }
  }

  async function sendReset() {
    uiError = null; okMsg = null;
    if (!email) { uiError = 'Escriu el teu email per rebre l’enllaç de reset.'; return; }
    try {
      loading = true;
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`
      });
      if (error) throw error;
      okMsg = 'T’hem enviat un correu per restablir la contrasenya.';
    } catch (e:any) {
      uiError = e?.message ?? 'No s’ha pogut enviar el correu de reset';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head><title>{mode === 'login' ? 'Inicia sessió' : 'Crea un compte'}</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">
  {mode === 'login' ? 'Inicia sessió' : 'Crea un compte'}
</h1>

{#if uiError}
  <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{uiError}</div>
{/if}
{#if okMsg}
  <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{okMsg}</div>
{/if}

  {#if $status === 'authenticated' && $user}
  <p class="text-slate-600">Ja has iniciat sessió com <strong>{$user.email}</strong>.</p>
{:else}
  <form class="max-w-sm space-y-3" on:submit|preventDefault={onSubmit}>
    <div>
      <label for="email" class="block text-sm mb-1">Email</label>
      <input
        id="email"
        type="email"
        class="w-full rounded border px-3 py-2"
        placeholder="tu@exemple.cat"
        bind:value={email}
        autocomplete="email"
      />
    </div>

    <div>
      <label for="password" class="block text-sm mb-1">Contrasenya</label>
      <input
        id="password"
        type="password"
        class="w-full rounded border px-3 py-2"
        placeholder="••••••••"
        bind:value={password}
        autocomplete={mode === 'login' ? 'current-password' : 'new-password'}
      />
    </div>

    <div class="flex items-center gap-2">
      <button
        type="submit"
        class="rounded bg-slate-900 text-white px-3 py-2 disabled:opacity-60"
        disabled={loading}
      >
        {loading ? 'Processant…' : (mode === 'login' ? 'Entrar' : 'Crear compte')}
      </button>

      <button
        type="button"
        class="text-sm underline"
        on:click={() => (mode = mode === 'login' ? 'signup' : 'login')}
      >
        {mode === 'login' ? 'No tens compte? Crea’n un' : 'Ja tens compte? Inicia sessió'}
      </button>
    </div>

    <div class="pt-2">
      <button type="button" class="text-sm underline" on:click={sendReset} disabled={loading}>
        He oblidat la contrasenya
      </button>
    </div>
  </form>
{/if}
