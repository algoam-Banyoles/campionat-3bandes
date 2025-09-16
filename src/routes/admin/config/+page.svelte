<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/stores/auth';
  import { checkIsAdmin } from '$lib/roles';
  import Banner from '$lib/components/Banner.svelte';
  import Loader from '$lib/components/Loader.svelte';
  import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';
  import { updateSettingsValues } from '$lib/settings';

  type Settings = {
    id?: string;
    caramboles_objectiu: number;
    max_entrades: number;
    allow_tiebreak: boolean;
    cooldown_min_dies: number;
    cooldown_max_dies: number;
    dies_acceptar_repte: number;
    dies_jugar_despres_acceptar: number;
    ranking_max_jugadors: number;
    pre_inactiu_setmanes: number;
    inactiu_setmanes: number;
    updated_at?: string | null;
  };

  const DEFAULT_FORM: Settings = {
    caramboles_objectiu: 20,
    max_entrades: 50,
    allow_tiebreak: true,
    cooldown_min_dies: 3,
    cooldown_max_dies: 7,
    dies_acceptar_repte: 7,
    dies_jugar_despres_acceptar: 7,
    ranking_max_jugadors: 20,
    pre_inactiu_setmanes: 3,
    inactiu_setmanes: 6
  };

  let form: Settings | null = null;
  let saving = false;
  let warning: string | null = null;
  let error: string | null = null;
  let ok: string | null = null;
  let loading = true;
  let admin = false;

  async function loadSettings() {
    const { supabase } = await import('$lib/supabaseClient');
    const { data } = await supabase
      .from('app_settings')
      .select(
        'id,caramboles_objectiu,max_entrades,allow_tiebreak,cooldown_min_dies,cooldown_max_dies,dies_acceptar_repte,dies_jugar_despres_acceptar,ranking_max_jugadors,pre_inactiu_setmanes,inactiu_setmanes,updated_at'
      )
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (data) {
      const partial = data as Partial<Settings>;
      form = {
        ...DEFAULT_FORM,
        ...partial,
        caramboles_objectiu: partial.caramboles_objectiu ?? DEFAULT_FORM.caramboles_objectiu,
        max_entrades: partial.max_entrades ?? DEFAULT_FORM.max_entrades,
        allow_tiebreak: partial.allow_tiebreak ?? DEFAULT_FORM.allow_tiebreak,
        cooldown_min_dies: partial.cooldown_min_dies ?? DEFAULT_FORM.cooldown_min_dies,
        cooldown_max_dies: partial.cooldown_max_dies ?? DEFAULT_FORM.cooldown_max_dies,
        dies_acceptar_repte: partial.dies_acceptar_repte ?? DEFAULT_FORM.dies_acceptar_repte,
        dies_jugar_despres_acceptar:
          partial.dies_jugar_despres_acceptar ?? DEFAULT_FORM.dies_jugar_despres_acceptar,
        ranking_max_jugadors: partial.ranking_max_jugadors ?? DEFAULT_FORM.ranking_max_jugadors,
        pre_inactiu_setmanes: partial.pre_inactiu_setmanes ?? DEFAULT_FORM.pre_inactiu_setmanes,
        inactiu_setmanes: partial.inactiu_setmanes ?? DEFAULT_FORM.inactiu_setmanes,
        updated_at: partial.updated_at ?? null,
        id: partial.id
      };
    } else {
      form = { ...DEFAULT_FORM };
    }
  }

  async function init() {
    try {
      loading = true;
        admin = await checkIsAdmin();
      if (admin) {
        await loadSettings();
      }
      } catch (e) {
        error = formatSupabaseError(e);
      } finally {
      loading = false;
    }
  }

  onMount(init);

  function validate(): string | null {
    if (!form) return null;
    if (!Number.isInteger(form.caramboles_objectiu) || form.caramboles_objectiu <= 0)
      return 'Caràmboles objectiu ha de ser un enter > 0';
    if (!Number.isInteger(form.max_entrades) || form.max_entrades <= 0)
      return 'Entrades màximes han de ser un enter > 0';
    if (!Number.isInteger(form.cooldown_min_dies) || form.cooldown_min_dies < 0)
      return 'El temps d'espera mínim ha de ser un enter ≥ 0';
    if (!Number.isInteger(form.cooldown_max_dies) || form.cooldown_max_dies < 0)
      return 'El temps d'espera màxim ha de ser un enter ≥ 0';
    if (form.cooldown_min_dies > form.cooldown_max_dies)
      return 'El temps d'espera mínim no pot superar el màxim';
    if (!Number.isInteger(form.dies_acceptar_repte) || form.dies_acceptar_repte <= 0)
      return 'Dies per acceptar repte han de ser un enter > 0';
    if (
      !Number.isInteger(form.dies_jugar_despres_acceptar) ||
      form.dies_jugar_despres_acceptar <= 0
    )
      return 'Dies per jugar després d’acceptar han de ser un enter > 0';
    if (!Number.isInteger(form.ranking_max_jugadors) || form.ranking_max_jugadors <= 0)
      return 'Rànquing: màxim jugadors ha de ser un enter > 0';
    if (!Number.isInteger(form.pre_inactiu_setmanes) || form.pre_inactiu_setmanes < 0)
      return 'Pre-inactivitat ha de ser un enter ≥ 0';
    if (!Number.isInteger(form.inactiu_setmanes) || form.inactiu_setmanes <= 0)
      return 'Inactivitat ha de ser un enter > 0';
    if (form.pre_inactiu_setmanes >= form.inactiu_setmanes)
      return 'La pre-inactivitat ha de ser inferior a la inactivitat';
    return null;
  }

  async function save() {
    if (!form) return;
    const v = validate();
    if (v) {
      warning = v;
      error = null;
      ok = null;
      return;
    }
    warning = null;
    error = null;
    ok = null;
    saving = true;
    try {
      const { supabase } = await import('$lib/supabaseClient');
      if (form.id) {
        const { id, updated_at, ...fields } = form;
        const { error: e } = await supabase
          .from('app_settings')
          .update({ ...fields, updated_at: new Date().toISOString() })
          .eq('id', id);
        if (e) throw e;
      } else {
        const { data: inserted, error: e } = await supabase
          .from('app_settings')
          .insert({
            caramboles_objectiu: form.caramboles_objectiu,
            max_entrades: form.max_entrades,
            allow_tiebreak: form.allow_tiebreak,
            cooldown_min_dies: form.cooldown_min_dies,
            cooldown_max_dies: form.cooldown_max_dies,
            dies_acceptar_repte: form.dies_acceptar_repte,
            dies_jugar_despres_acceptar: form.dies_jugar_despres_acceptar,
            ranking_max_jugadors: form.ranking_max_jugadors,
            pre_inactiu_setmanes: form.pre_inactiu_setmanes,
            inactiu_setmanes: form.inactiu_setmanes
          })
          .select('id')
          .single();
        if (e) throw e;
        if (!inserted?.id) throw new Error('No s’ha pogut crear la configuració');
        form.id = inserted.id;
      }

      await updateSettingsValues({
        diesAcceptar: form.dies_acceptar_repte,
        diesJugar: form.dies_jugar_despres_acceptar,
        preInact: form.pre_inactiu_setmanes,
        inact: form.inactiu_setmanes
      });
      await loadSettings();
      ok = okText('Configuració desada');
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head><title>Admin · Configuració</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Administració — Configuració</h1>

{#if loading}
  <Loader />
{:else if !$user?.email}
  <Banner type="error" message="Has d’iniciar sessió" />
{:else if !admin}
  <Banner type="error" message="Només administradors…" />
{:else}
  {#if warning}
    <Banner type="warn" message={warning} class="mb-3" />
  {/if}
  {#if error}
    <Banner type="error" message={error} class="mb-3" />
  {/if}
  {#if ok}
    <Banner type="success" message={ok} class="mb-3" />
  {/if}

  {#if form}
    <div class="mx-auto max-w-3xl">
      <div class="rounded-2xl border bg-white p-6 shadow-sm">
        <form class="space-y-4" on:submit|preventDefault={save}>
          <div>
            <label for="caramboles_objectiu" class="block text-sm mb-1">Caràmboles objectiu</label>
            <input
              id="caramboles_objectiu"
              type="number"
              min="1"
              class="w-full rounded-xl border px-3 py-2"
              bind:value={form.caramboles_objectiu}
            />
          </div>

          <div>
            <label for="max_entrades" class="block text-sm mb-1">Entrades màximes</label>
            <input
              id="max_entrades"
              type="number"
              min="1"
              class="w-full rounded-xl border px-3 py-2"
              bind:value={form.max_entrades}
            />
          </div>

          <div class="flex items-center gap-2">
            <input
              id="allow_tiebreak"
              type="checkbox"
              class="rounded border"
              bind:checked={form.allow_tiebreak}
            />
            <label for="allow_tiebreak">Permet tie-break</label>
          </div>

          <div class="flex gap-4">
            <div class="flex-1">
              <label for="cooldown_min_dies" class="block text-sm mb-1">Temps d'espera mínim (dies)</label>
              <input
                id="cooldown_min_dies"
                type="number"
                min="0"
                class="w-full rounded-xl border px-3 py-2"
                bind:value={form.cooldown_min_dies}
              />
            </div>
            <div class="flex-1">
              <label for="cooldown_max_dies" class="block text-sm mb-1">Temps d'espera màxim (dies)</label>
              <input
                id="cooldown_max_dies"
                type="number"
                min="0"
                class="w-full rounded-xl border px-3 py-2"
                bind:value={form.cooldown_max_dies}
              />
            </div>
          </div>

          <div>
            <label for="dies_acceptar_repte" class="block text-sm mb-1">Dies per acceptar repte</label>
            <input
              id="dies_acceptar_repte"
              type="number"
              min="1"
              class="w-full rounded-xl border px-3 py-2"
              bind:value={form.dies_acceptar_repte}
            />
          </div>

          <div>
            <label for="dies_jugar_despres_acceptar" class="block text-sm mb-1">Dies per jugar després d’acceptar</label>
            <input
              id="dies_jugar_despres_acceptar"
              type="number"
              min="1"
              class="w-full rounded-xl border px-3 py-2"
              bind:value={form.dies_jugar_despres_acceptar}
            />
          </div>

          <div class="flex gap-4">
            <div class="flex-1">
              <label for="pre_inactiu_setmanes" class="block text-sm mb-1">Pre-inactivitat (setmanes)</label>
              <input
                id="pre_inactiu_setmanes"
                type="number"
                min="0"
                class="w-full rounded-xl border px-3 py-2"
                bind:value={form.pre_inactiu_setmanes}
              />
            </div>
            <div class="flex-1">
              <label for="inactiu_setmanes" class="block text-sm mb-1">Inactivitat (setmanes)</label>
              <input
                id="inactiu_setmanes"
                type="number"
                min="1"
                class="w-full rounded-xl border px-3 py-2"
                bind:value={form.inactiu_setmanes}
              />
            </div>
          </div>

          <div>
            <label for="ranking_max_jugadors" class="block text-sm mb-1">Rànquing: màxim jugadors</label>
            <input
              id="ranking_max_jugadors"
              type="number"
              min="1"
              class="w-full rounded-xl border px-3 py-2"
              bind:value={form.ranking_max_jugadors}
            />
          </div>

          <div class="pt-2">
            <button
              class="rounded-2xl bg-slate-900 text-white px-4 py-2 disabled:opacity-60"
              disabled={saving}
              type="submit"
            >
              {saving ? 'Desant…' : 'Desa configuració'}
            </button>
          </div>
        </form>
        {#if form.updated_at}
          <p class="mt-4 text-sm text-slate-500">Actualitzat: {new Date(form.updated_at).toLocaleString()}</p>
        {/if}
      </div>
    </div>
  {/if}
{/if}
