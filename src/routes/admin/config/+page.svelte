<script lang="ts">
  import { onMount } from 'svelte';
  import { user, isAdmin } from '$lib/authStore';

  type Settings = {
    id?: string;
    caramboles_objectiu: number;
    max_entrades: number;
    allow_tiebreak: boolean;
  };

  let loading = true;
  let saving = false;
  let error: string | null = null;
  let okMsg: string | null = null;

  let form: Settings = {
    caramboles_objectiu: 2,
    max_entrades: 50,
    allow_tiebreak: true
  };

  onMount(load);

  async function load() {
    try {
      loading = true; error = null; okMsg = null;

      if (!$user?.email) {
        error = 'Has d’iniciar sessió.';
        return;
      }
      if (!$isAdmin) {
        error = 'Només administradors.';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');

      // agafa l’últim registre d’app_settings (o valors per defecte si no hi ha res)
      const { data, error: e1 } = await supabase
        .from('app_settings')
        .select('id, caramboles_objectiu, max_entrades, allow_tiebreak')
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (e1) throw e1;

      if (data) {
        form = {
          id: data.id,
          caramboles_objectiu: data.caramboles_objectiu ?? 2,
          max_entrades: data.max_entrades ?? 50,
          allow_tiebreak: data.allow_tiebreak ?? true
        };
      }
    } catch (e:any) {
      error = e?.message ?? 'No s’ha pogut carregar la configuració';
    } finally {
      loading = false;
    }
  }

  function validate(): string | null {
    if (form.caramboles_objectiu < 1) return 'Caràmboles objectiu ha de ser ≥ 1';
    if (form.max_entrades < 1) return 'Entrades màximes han de ser ≥ 1';
    return null;
  }

  async function save() {
    const v = validate();
    if (v) { error = v; okMsg = null; return; }

    try {
      saving = true; error = null; okMsg = null;
      const { supabase } = await import('$lib/supabaseClient');

      if (form.id) {
        // update existent
        const { error: eU } = await supabase
          .from('app_settings')
          .update({
            caramboles_objectiu: form.caramboles_objectiu,
            max_entrades: form.max_entrades,
            allow_tiebreak: form.allow_tiebreak,
            updated_at: new Date().toISOString()
          })
          .eq('id', form.id);
        if (eU) throw eU;
      } else {
        // crea un nou registre
        const { data, error: eI } = await supabase
          .from('app_settings')
          .insert({
            caramboles_objectiu: form.caramboles_objectiu,
            max_entrades: form.max_entrades,
            allow_tiebreak: form.allow_tiebreak
          })
          .select('id')
          .single();
        if (eI) throw eI;
        form.id = data?.id;
      }

      okMsg = 'Configuració desada correctament.';
    } catch (e:any) {
      error = e?.message ?? 'No s’ha pogut desar la configuració';
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head><title>Admin · Configuració</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Administració — Configuració</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else}
  {#if error}
    <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{error}</div>
  {/if}
  {#if okMsg}
    <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{okMsg}</div>
  {/if}

  {#if !error}
    <form class="max-w-lg space-y-4" on:submit|preventDefault={save}>
      <div>
        <label for="caramb" class="block text-sm mb-1">Caràmboles objectiu</label>
        <input
          id="caramb"
          type="number"
          min="1"
          class="w-full rounded border px-3 py-2"
          bind:value={form.caramboles_objectiu}
        />
      </div>

      <div>
        <label for="maxent" class="block text-sm mb-1">Entrades màximes</label>
        <input
          id="maxent"
          type="number"
          min="1"
          class="w-full rounded border px-3 py-2"
          bind:value={form.max_entrades}
        />
      </div>

      <div class="flex items-center gap-2">
        <input id="tb" type="checkbox" class="rounded border" bind:checked={form.allow_tiebreak} />
        <label for="tb">Permet tie-break</label>
      </div>

      <div class="pt-2">
        <button class="rounded bg-slate-900 text-white px-4 py-2 disabled:opacity-60" disabled={saving} type="submit">
          {saving ? 'Desant…' : 'Desa configuració'}
        </button>
      </div>
    </form>
  {/if}
{/if}
