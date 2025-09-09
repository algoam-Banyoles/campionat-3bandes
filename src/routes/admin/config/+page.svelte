<script lang="ts">
  import { user, isAdmin } from '$lib/authStore';
  import type { PageData } from './$types';

  export let data: PageData;

  type Settings = {
    id: string;
    caramboles_objectiu: number;
    max_entrades: number;
    allow_tiebreak: boolean;
    cooldown_min_dies: number;
    cooldown_max_dies: number;
    dies_acceptar_repte: number;
    dies_jugar_despres_acceptar: number;
    ranking_max_jugadors: number;
  };

  let saving = false;
  let error: string | null = data.loadError;
  let okMsg: string | null = null;

  let form: Settings = data.settings
    ? { ...data.settings }
    : {
        id: '',
        caramboles_objectiu: 20,
        max_entrades: 50,
        allow_tiebreak: true,
        cooldown_min_dies: 0,
        cooldown_max_dies: 0,
        dies_acceptar_repte: 1,
        dies_jugar_despres_acceptar: 1,
        ranking_max_jugadors: 10
      };

  function validate(): string | null {
    if (form.caramboles_objectiu < 1) return 'Caràmboles objectiu ha de ser ≥ 1';
    if (form.max_entrades < 1) return 'Entrades màximes han de ser ≥ 1';
    if (form.cooldown_min_dies < 0) return 'Cooldown mínim ha de ser ≥ 0';
    if (form.cooldown_max_dies < form.cooldown_min_dies)
      return 'Cooldown màxim ha de ser ≥ mínim';
    if (form.dies_acceptar_repte < 1)
      return 'Dies per acceptar repte ha de ser ≥ 1';
    if (form.dies_jugar_despres_acceptar < 1)
      return 'Dies per jugar després d’acceptar ha de ser ≥ 1';
    if (form.ranking_max_jugadors < 1)
      return 'Rànquing: màxim de jugadors ha de ser ≥ 1';
    return null;
  }

  async function save() {
    const v = validate();
    if (v) {
      error = v;
      okMsg = null;
      return;
    }

    try {
      saving = true;
      error = null;
      okMsg = null;
      const { supabase } = await import('$lib/supabaseClient');
      if (!form.id) {
        error = 'Configuració no trobada';
        return;
      }
      const { id, ...fields } = form;
      const { error: e } = await supabase
        .from('app_settings')
        .update({ ...fields, updated_at: new Date().toISOString() })
        .eq('id', id);
      if (e) throw e;

      const { data: fresh, error: e2 } = await supabase
        .from('app_settings')
        .select(
          'id, caramboles_objectiu, max_entrades, allow_tiebreak, cooldown_min_dies, cooldown_max_dies, dies_acceptar_repte, dies_jugar_despres_acceptar, ranking_max_jugadors'
        )
        .eq('id', id)
        .maybeSingle();
      if (e2) throw e2;
      if (fresh) form = fresh as Settings;

      okMsg = 'Configuració desada';
    } catch (e: any) {
      error = e?.message ?? 'No s’ha pogut desar la configuració';
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head><title>Admin · Configuració</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Administració — Configuració</h1>

{#if !$user?.email || !$isAdmin}
  <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3">No autoritzat</div>
{:else}
  {#if error}
    <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-3">{error}</div>
  {/if}
  {#if okMsg}
    <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-3">{okMsg}</div>
  {/if}

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
      <input
        id="tb"
        type="checkbox"
        class="rounded border"
        bind:checked={form.allow_tiebreak}
      />
      <label for="tb">Permet tie-break</label>
    </div>

    <div class="flex gap-4">
      <div class="flex-1">
        <label for="cooldown-min" class="block text-sm mb-1">Cooldown mínim (dies)</label>
        <input
          id="cooldown-min"
          type="number"
          min="0"
          class="w-full rounded border px-3 py-2"
          bind:value={form.cooldown_min_dies}
        />
      </div>
      <div class="flex-1">
        <label for="cooldown-max" class="block text-sm mb-1">Cooldown màxim (dies)</label>
        <input
          id="cooldown-max"
          type="number"
          min="0"
          class="w-full rounded border px-3 py-2"
          bind:value={form.cooldown_max_dies}
        />
      </div>
    </div>

    <div>
      <label for="dies-acceptar" class="block text-sm mb-1">Dies per acceptar repte</label>
      <input
        id="dies-acceptar"
        type="number"
        min="1"
        class="w-full rounded border px-3 py-2"
        bind:value={form.dies_acceptar_repte}
      />
    </div>

    <div>
      <label for="dies-jugar" class="block text-sm mb-1">Dies per jugar després d’acceptar</label>
      <input
        id="dies-jugar"
        type="number"
        min="1"
        class="w-full rounded border px-3 py-2"
        bind:value={form.dies_jugar_despres_acceptar}
      />
    </div>

    <div>
      <label for="ranking-max" class="block text-sm mb-1">Rànquing: màxim jugadors</label>
      <input
        id="ranking-max"
        type="number"
        min="1"
        class="w-full rounded border px-3 py-2"
        bind:value={form.ranking_max_jugadors}
      />
    </div>

    <div class="pt-2">
      <button
        class="rounded bg-slate-900 text-white px-4 py-2 disabled:opacity-60"
        disabled={saving}
        type="submit"
      >
        {saving ? 'Desant…' : 'Desa configuració'}
      </button>
    </div>
  </form>
{/if}

