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

<div class="rp-root">
  <header class="rp-mast">
    <div class="editorial-eyebrow">Foment Martinenc · Secció billar</div>
    <h1 class="rp-title">Restableix la contrasenya</h1>
  </header>

  {#if uiError}
    <div class="rp-error">{uiError}</div>
  {/if}
  {#if okMsg}
    <div class="rp-ok">{okMsg}</div>
  {/if}

  <form class="rp-form" on:submit|preventDefault={updatePassword}>
    <div>
      <label for="newpass" class="rp-label">Nova contrasenya</label>
      <input id="newpass" type="password" class="rp-input" bind:value={password} autocomplete="new-password" />
    </div>
    <button class="rp-btn-primary" disabled={loading} type="submit">
      {loading ? 'Processant…' : 'Actualitza contrasenya'}
    </button>
  </form>
</div>

<style>
  .rp-root {
    max-width: 32rem;
    margin: 0 auto;
    padding: 2rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .rp-mast {
    margin-bottom: 1.5rem;
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
  .rp-title {
    margin: 0.4rem 0 0;
    font-size: clamp(1.5rem, 2vw, 2rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .rp-error {
    padding: 0.75rem 1rem;
    margin-bottom: 1rem;
    font-size: 0.875rem;
    background: var(--paper);
    border: 1px solid var(--accent);
    color: var(--accent);
  }
  .rp-ok {
    padding: 0.75rem 1rem;
    margin-bottom: 1rem;
    font-size: 0.875rem;
    background: var(--paper);
    border: 1px solid var(--green);
    color: var(--green);
  }
  .rp-form { display: flex; flex-direction: column; gap: 0.85rem; }
  .rp-label {
    display: block;
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink-2, #4a443e);
    margin-bottom: 0.3rem;
  }
  .rp-input {
    width: 100%;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule-strong, #b8b3a8);
    padding: 0.6rem 0.85rem;
    font-family: var(--font-sans, sans-serif);
    font-size: 0.9375rem;
    color: var(--ink, #1a1814);
  }
  .rp-input:focus {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
  .rp-btn-primary {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
    border: 1px solid var(--ink, #1a1814);
    padding: 0.65rem 1.25rem;
    font-family: var(--font-sans, sans-serif);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
    align-self: flex-start;
  }
  .rp-btn-primary:hover:not(:disabled) { opacity: 0.9; }
  .rp-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
