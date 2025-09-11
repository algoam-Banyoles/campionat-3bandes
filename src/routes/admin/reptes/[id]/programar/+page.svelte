<script lang="ts">
      import { onMount } from 'svelte';
      import { page } from '$app/stores';
      import { user } from '$lib/authStore';
      import { adminStore as isAdmin } from '$lib/roles';
    import Banner from '$lib/components/Banner.svelte';
    import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';

  type Challenge = {
    id: string;
    reptador_id: string;
    reptat_id: string;
    pos_reptador: number | null;
    pos_reptat: number | null;
    estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
    data_acceptacio: string | null;
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

  onMount(load);

  async function load() {
    try {
      loading = true;
      error = null;
      okMsg = null;

        if (!$user?.email) {
          error = errText('Has d’iniciar sessió.');
          return;
        }
        if (!$isAdmin) {
          error = errText('Només administradors poden programar reptes.');
          return;
        }

      const { supabase } = await import('$lib/supabaseClient');

      const { data: c, error: e1 } = await supabase
        .from('challenges')
        .select('id,reptador_id,reptat_id,pos_reptador,pos_reptat,estat,data_acceptacio,reprogram_count')
        .eq('id', id)
        .maybeSingle();
      if (e1) throw e1;
      if (!c) {
        error = errText('Repte no trobat.');
        return;
      }
      chal = c;
      data_local = toLocalInput(c.data_acceptacio);

      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', [c.reptador_id, c.reptat_id]);
      if (e2) throw e2;
      const dict = new Map((players ?? []).map((p: any) => [p.id, p.nom]));
      reptadorNom = dict.get(c.reptador_id) ?? '—';
      reptatNom = dict.get(c.reptat_id) ?? '—';
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
    try {
      saving = true;
      const { supabase } = await import('$lib/supabaseClient');
      const updates: any = { data_acceptacio: iso, estat: 'programat' };
      if (chal && chal.estat === 'programat' && chal.data_acceptacio !== iso) {
        updates.reprogram_count = (chal.reprogram_count ?? 0) + 1;
      }
      const { error: e } = await supabase
        .from('challenges')
        .update(updates)
        .eq('id', id);
      if (e) throw e;
        okMsg = okText('Data programada correctament.');
      if (chal) {
        chal.estat = 'programat';
        chal.data_acceptacio = iso;
        if (updates.reprogram_count) {
          chal.reprogram_count = updates.reprogram_count;
        }
      }
    } catch (e: any) {
        error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }

  async function clearDate() {
    error = null;
    okMsg = null;
    try {
      saving = true;
      const { supabase } = await import('$lib/supabaseClient');
      const { error: e } = await supabase
        .from('challenges')
        .update({ data_acceptacio: null, estat: 'acceptat' })
        .eq('id', id);
      if (e) throw e;
        okMsg = okText('Data eliminada.');
      data_local = '';
      if (chal) {
        chal.estat = 'acceptat';
        chal.data_acceptacio = null;
      }
    } catch (e: any) {
        error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head>
  <title>Programar repte</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Programar repte</h1>

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
      <div>Estat actual: <span class="capitalize">{chal.estat.replace('_', ' ')}</span></div>
      <div>Data acceptació actual: {fmt(chal.data_acceptacio)}</div>
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
          <button
            type="button"
            class="rounded bg-slate-500 text-white px-3 py-1 disabled:opacity-60"
            on:click={clearDate}
            disabled={saving}
          >Deixa sense data</button>
        </div>
      </form>
    {:else if frozen}
      <p class="text-slate-500">El repte està en estat «{chal.estat}» i no es pot programar.</p>
    {/if}
  {/if}

  <div class="mt-4">
    <a href="/admin/reptes" class="text-blue-700">&larr; Torna</a>
  </div>
{/if}
