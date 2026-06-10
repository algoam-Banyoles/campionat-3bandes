<script lang="ts">
    import { goto } from '$app/navigation';
    import { supabase } from '$lib/supabaseClient';
    import { status, user } from '$lib/stores/auth';
    import { authFetch } from '$lib/utils/http';

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
          await authFetch('/api/session', {
            method: 'POST',
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
        redirectTo: `${window.location.origin}/general/reset-password`
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

<div class="lg-root">
  <header class="lg-mast">
    <div class="editorial-eyebrow">Foment Martinenc · Secció billar</div>
    <h1 class="lg-title">{mode === 'login' ? 'Inicia sessió' : 'Crea un compte'}</h1>
  </header>

  {#if uiError}
    <div class="lg-error">{uiError}</div>
  {/if}
  {#if okMsg}
    <div class="lg-ok">{okMsg}</div>
  {/if}

  {#if $status === 'authenticated' && $user}
    <p class="lg-already">Ja has iniciat sessió com <strong>{$user.email}</strong>.</p>
  {:else}
    <form class="lg-form" on:submit|preventDefault={onSubmit}>
      <div>
        <label for="email" class="lg-label">Email</label>
        <input
          id="email"
          type="email"
          class="lg-input"
          placeholder="tu@exemple.cat"
          bind:value={email}
          autocomplete="email"
        />
      </div>

      <div>
        <label for="password" class="lg-label">Contrasenya</label>
        <input
          id="password"
          type="password"
          class="lg-input"
          placeholder="••••••••"
          bind:value={password}
          autocomplete={mode === 'login' ? 'current-password' : 'new-password'}
        />
      </div>

      <div class="lg-actions">
        <button type="submit" class="lg-btn-primary" disabled={loading}>
          {loading ? 'Processant…' : (mode === 'login' ? 'Entrar' : 'Crear compte')}
        </button>

        <button type="button" class="lg-link" on:click={() => (mode = mode === 'login' ? 'signup' : 'login')}>
          {mode === 'login' ? 'No tens compte? Crea’n un' : 'Ja tens compte? Inicia sessió'}
        </button>
      </div>

      <div>
        <button type="button" class="lg-link lg-link-muted" on:click={sendReset} disabled={loading}>
          He oblidat la contrasenya
        </button>
      </div>
    </form>
  {/if}
</div>

<style>
  .lg-root {
    max-width: 32rem;
    margin: 0 auto;
    padding: 2rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .lg-mast {
    margin-bottom: 1.75rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .lg-title {
    margin: 0.4rem 0 0;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .lg-error,
  .lg-ok {
    padding: 0.75rem 1rem;
    margin-bottom: 1rem;
    font-size: 0.875rem;
    border: 1px solid;
  }
  .lg-error { background: var(--paper); border-color: var(--accent); color: var(--accent); }
  .lg-ok { background: var(--paper); border-color: var(--green); color: var(--green); }
  .lg-already { color: var(--ink-2, #4a443e); }
  .lg-form {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
  }
  .lg-label {
    display: block;
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink-2, #4a443e);
    margin-bottom: 0.3rem;
  }
  .lg-input {
    width: 100%;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule-strong, #b8b3a8);
    padding: 0.6rem 0.85rem;
    font-family: var(--font-sans, sans-serif);
    font-size: 0.9375rem;
    color: var(--ink, #1a1814);
  }
  .lg-input:focus {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
  .lg-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.85rem;
    margin-top: 0.4rem;
  }
  .lg-btn-primary {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
    border: 1px solid var(--ink, #1a1814);
    padding: 0.65rem 1.25rem;
    font-family: var(--font-sans, sans-serif);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .lg-btn-primary:hover:not(:disabled) { opacity: 0.9; }
  .lg-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .lg-link {
    background: transparent;
    border: none;
    padding: 0;
    color: var(--ink, #1a1814);
    font-family: var(--font-sans, sans-serif);
    font-size: 0.8125rem;
    font-weight: 600;
    cursor: pointer;
    border-bottom: 1px solid currentColor;
  }
  .lg-link:hover { color: var(--accent, #a30b1e); }
  .lg-link-muted { color: var(--ink-3, #807a72); font-weight: 500; }
</style>
