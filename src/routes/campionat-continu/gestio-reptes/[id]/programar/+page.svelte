<script lang="ts">
  import { goto } from '$app/navigation';
      // Guard: només admins.
      $: if ($adminChecked && !$isAdmin) {
        goto('/campionat-continu/reptes');
      }

      import { onMount } from 'svelte';
    import { page } from '$app/stores';
    import { user } from '$lib/stores/auth';
    import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
    import Banner from '$lib/components/general/Banner.svelte';
    import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';
    import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';

  type Challenge = {
    id: string;
    reptador_soci_numero: number;
    reptat_soci_numero: number;
    pos_reptador: number | null;
    pos_reptat: number | null;
    estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
    data_programada: string | null;
    reprogram_count: number;
  };

  let loading = true;
  let saving = false;
  let error: string | null = null;
  let okMsg: string | null = null;

  let chal: Challenge | null = null;
  let reptadorNom = '—';
  let reptatNom = '—';
  let data_local = '';

  const id = $page.params.id;

  const challengeStateLabel = (state: string): string =>
    CHALLENGE_STATE_LABEL[state] ?? state.replace('_', ' ');

  onMount(load);

  async function load() {
    try {
      loading = true;
      error = null;
      okMsg = null;

      const { supabase } = await import('$lib/supabaseClient');

      const { data: c, error: e1 } = await supabase
        .from('challenges')
        .select('id,reptador_soci_numero,reptat_soci_numero,pos_reptador,pos_reptat,estat,data_programada,reprogram_count')
        .eq('id', id)
        .maybeSingle();
      if (e1) throw e1;
      if (!c) {
        error = errText('Repte no trobat.');
        return;
      }
      chal = c as unknown as Challenge;
      data_local = toLocalInput(c.data_programada);

      const { data: socisData, error: e2 } = await supabase
        .from('socis')
        .select('numero_soci,nom')
        .in('numero_soci', [(c as any).reptador_soci_numero, (c as any).reptat_soci_numero]);
      if (e2) throw e2;
      const dict = new Map((socisData ?? []).map((p: any) => [p.numero_soci, p.nom]));
      reptadorNom = dict.get((c as any).reptador_soci_numero) ?? '—';
      reptatNom = dict.get((c as any).reptat_soci_numero) ?? '—';
      } catch (e) {
        error = formatSupabaseError(e);
      } finally {
      loading = false;
    }
  }

  function toLocalInput(iso: string | null) {
    if (!iso) return '';
    const d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function parseLocalToIso(local: string | null): string | null {
    if (!local) return null;
    const d = new Date(local);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  function fmt(iso: string | null) {
    if (!iso) return '—';
    const d = new Date(iso);
    return isNaN(d.getTime()) ? iso : d.toLocaleString();
  }

  $: frozen = chal && ['anullat', 'jugat', 'refusat', 'caducat'].includes(chal.estat);
  $: canProgram = chal && ['proposat', 'acceptat', 'programat'].includes(chal.estat);

  async function save() {
    error = null;
    okMsg = null;
    const iso = parseLocalToIso(data_local);
    if (!iso) {
      error = errText('Cal indicar la data.');
      return;
    }
    if (!chal || !['proposat', 'acceptat', 'programat'].includes(chal.estat)) {
      error = errText('Estat no permet programar.');
      return;
    }
    try {
      saving = true;
      if (!$user?.email) {
        error = errText('Has d\u2019iniciar sessi\u00f3.');
        saving = false;
        return;
      }
      const { supabase } = await import('$lib/supabaseClient');
      const { data: out, error: rpcErr } = await supabase.rpc('programar_repte', {
        p_challenge: id,
        p_data: iso,
        p_actor_email: $user.email
      });
      if (rpcErr) throw rpcErr;
      if (!out?.ok) {
        throw new Error(out.error || 'Error programant repte');
      }
      okMsg = okText('Data programada correctament.');
      const wasReprogram = chal.estat === 'programat' && chal.data_programada !== iso;
      chal.estat = 'programat';
      chal.data_programada = iso;
      if (wasReprogram) {
        chal.reprogram_count = (chal.reprogram_count ?? 0) + 1;
      }
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }

</script>

<svelte:head>
  <title>Programar repte</title>
</svelte:head>

<div class="gr-sub-root">
  <header class="gr-sub-mast">
    <div class="editorial-eyebrow">Rànquing continu · Reptes</div>
    <h1>Programar repte</h1>
  </header>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else}
    {#if error}
      <Banner type="error" message={error} class="mb-3" />
    {/if}
    {#if okMsg}
      <Banner type="success" message={okMsg} class="mb-3" />
    {/if}

  {#if chal}
    <div class="mb-4 space-y-1">
      <div>Reptador: #{chal.pos_reptador ?? '—'} — {reptadorNom}</div>
      <div>Reptat: #{chal.pos_reptat ?? '—'} — {reptatNom}</div>
    <div>Estat actual: <span>{challengeStateLabel(chal.estat)}</span></div>
      <div>Data programada actual: {fmt(chal.data_programada)}</div>
    </div>

    {#if canProgram}
      <form class="max-w-sm space-y-4" on:submit|preventDefault={save}>
        <div>
          <label for="data" class="block text-sm mb-1">Data programada</label>
          <input
            id="data"
            type="datetime-local"
            step="900"
            class="w-full rounded border px-3 py-2"
            bind:value={data_local}
          />
        </div>
        <div class="flex gap-2">
          <button
            type="submit"
            class="rounded bg-indigo-700 text-white px-3 py-1 disabled:opacity-60"
            disabled={saving}
          >Desa</button>
        </div>
      </form>
    {:else if frozen}
      <p class="text-slate-500">El repte està en estat «{challengeStateLabel(chal.estat)}» i no es pot programar.</p>
    {/if}
  {/if}

  <div class="mt-4">
    <a href="/campionat-continu/gestio-reptes" class="text-blue-700">&larr; Torna</a>
  </div>
{/if}
</div>

<style>
  .gr-sub-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .gr-sub-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .gr-sub-mast .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .gr-sub-mast h1 {
    margin: 0.4rem 0 0;
    font-size: clamp(1.5rem, 2vw, 2rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .gr-sub-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .gr-sub-root :global(.bg-slate-100),
  .gr-sub-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .gr-sub-root :global(.bg-slate-900) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .gr-sub-root :global(.text-slate-500),
  .gr-sub-root :global(.text-slate-600),
  .gr-sub-root :global(.text-slate-700) { color: var(--ink-2, #4a443e) !important; }
  .gr-sub-root :global(.text-blue-700) { color: var(--ink, #1a1814) !important; border-bottom: 1px solid currentColor; }
  .gr-sub-root :global(.rounded),
  .gr-sub-root :global(.rounded-md),
  .gr-sub-root :global(.rounded-lg),
  .gr-sub-root :global(.rounded-xl) { border-radius: 0 !important; }
  .gr-sub-root :global(input),
  .gr-sub-root :global(select),
  .gr-sub-root :global(textarea) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
</style>
