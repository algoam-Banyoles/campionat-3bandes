<script lang="ts">
  import { onMount } fr      // Use reactive admin check
      if (!$adminChecked || !$isAdmin) {
        error = 'Només els administradors poden accedir a aquesta pàgina.';
        return;
      }velte';
  import { goto } from '$app/navigation';
  import { user, adminStore } from '$lib/stores/auth';
  import { checkIsAdmin } from '$lib/roles';
  import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
  import Banner from '$lib/components/general/Banner.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';

  type AppSettings = {
    id: string;
    caramboles_objectiu: number;
    max_entrades: number;
    allow_tiebreak: boolean;
    cooldown_min_dies: number;
    cooldown_max_dies: number;
    dies_acceptar_repte: number;
    dies_jugar_despres_acceptar: number;
    ranking_max_jugadors: number;
    max_rank_gap: number;
    pre_inactiu_setmanes: number;
    inactiu_setmanes: number;
    updated_at: string;
  };

  let loading = true;
  let error: string | null = null;
  let settings: AppSettings | null = null;
  let saving = false;
  let saveSuccess: string | null = null;
  let saveError: string | null = null;

  onMount(async () => {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        goto('/login');
        return;
      }

      const adm = await checkIsAdmin();
      if (!adm) {
        error = errText('Només els administradors poden accedir a aquesta pàgina.');
        return;
      }

      await loadSettings();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadSettings() {
    const { supabase } = await import('$lib/supabaseClient');
    const { data, error: settingsError } = await supabase
      .from('app_settings')
      .select('*')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (settingsError) throw settingsError;

    if (!data) {
      // Crear configuració per defecte si no existeix
      const { data: newData, error: createError } = await supabase
        .from('app_settings')
        .insert({})
        .select()
        .single();

      if (createError) throw createError;
      settings = newData;
    } else {
      settings = data;
    }
  }

  async function saveSettings() {
    if (!settings) return;

    try {
      saving = true;
      saveSuccess = null;
      saveError = null;

      const { supabase } = await import('$lib/supabaseClient');
      const { error: updateError } = await supabase
        .from('app_settings')
        .update({
          caramboles_objectiu: settings.caramboles_objectiu,
          max_entrades: settings.max_entrades,
          allow_tiebreak: settings.allow_tiebreak,
          cooldown_min_dies: settings.cooldown_min_dies,
          cooldown_max_dies: settings.cooldown_max_dies,
          dies_acceptar_repte: settings.dies_acceptar_repte,
          dies_jugar_despres_acceptar: settings.dies_jugar_despres_acceptar,
          ranking_max_jugadors: settings.ranking_max_jugadors,
          max_rank_gap: settings.max_rank_gap,
          pre_inactiu_setmanes: settings.pre_inactiu_setmanes,
          inactiu_setmanes: settings.inactiu_setmanes,
          updated_at: new Date().toISOString()
        })
        .eq('id', settings.id);

      if (updateError) throw updateError;

      saveSuccess = 'Configuració guardada correctament';
      await loadSettings(); // Recarregar per obtenir el timestamp actualitzat
    } catch (e) {
      saveError = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head>
  <title>Configuració del Campionat</title>
</svelte:head>

<div class="mb-4">
  <a href="/admin" class="text-blue-600 hover:text-blue-800">← Tornar a l'administració</a>
</div>

<h1 class="text-2xl font-semibold mb-6">Configuració del Campionat</h1>

{#if loading}
  <p class="text-slate-500">Carregant configuració…</p>
{:else if error}
  <Banner type="error" message={error} />
{:else if $adminStore && settings}
  <div class="max-w-2xl space-y-6">
    {#if saveSuccess}
      <Banner type="success" message={saveSuccess} />
    {/if}
    {#if saveError}
      <Banner type="error" message={saveError} />
    {/if}

    <form on:submit|preventDefault={saveSettings} class="space-y-6">
      <!-- Configuració del joc -->
      <div class="rounded-xl border p-6">
        <h2 class="text-lg font-semibold mb-4 text-gray-800">⚽ Configuració del Joc</h2>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label for="caramboles" class="block text-sm font-medium text-gray-700 mb-1">
              Caramboles objectiu per partida
            </label>
            <input
              id="caramboles"
              type="number"
              min="1"
              bind:value={settings.caramboles_objectiu}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label for="entrades" class="block text-sm font-medium text-gray-700 mb-1">
              Màxim entrades per jugador
            </label>
            <input
              id="entrades"
              type="number"
              min="10"
              max="200"
              bind:value={settings.max_entrades}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div class="sm:col-span-2">
            <label class="flex items-center">
              <input
                type="checkbox"
                bind:checked={settings.allow_tiebreak}
                class="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
              />
              <span class="ml-2 text-sm text-gray-700">Permetre desempat per entrades</span>
            </label>
          </div>
        </div>
      </div>

      <!-- Configuració del rànquing -->
      <div class="rounded-xl border p-6">
        <h2 class="text-lg font-semibold mb-4 text-gray-800">🏆 Configuració del Rànquing</h2>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label for="max_jugadors" class="block text-sm font-medium text-gray-700 mb-1">
              Màxim jugadors al rànquing
            </label>
            <input
              id="max_jugadors"
              type="number"
              min="10"
              max="50"
              bind:value={settings.ranking_max_jugadors}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label for="max_gap" class="block text-sm font-medium text-gray-700 mb-1">
              Màxim salts de posició per repte
            </label>
            <input
              id="max_gap"
              type="number"
              min="1"
              max="10"
              bind:value={settings.max_rank_gap}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">
              Un jugador només pot reptar a jugadors fins a {settings.max_rank_gap} posicions per sobre
            </p>
          </div>
        </div>
      </div>

      <!-- Terminis i dates -->
      <div class="rounded-xl border p-6">
        <h2 class="text-lg font-semibold mb-4 text-gray-800">📅 Terminis i Dates</h2>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label for="dies_acceptar" class="block text-sm font-medium text-gray-700 mb-1">
              Dies per acceptar un repte
            </label>
            <input
              id="dies_acceptar"
              type="number"
              min="1"
              max="30"
              bind:value={settings.dies_acceptar_repte}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label for="dies_jugar" class="block text-sm font-medium text-gray-700 mb-1">
              Dies per jugar després d'acceptar
            </label>
            <input
              id="dies_jugar"
              type="number"
              min="1"
              max="30"
              bind:value={settings.dies_jugar_despres_acceptar}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>
      </div>

      <!-- Cooldown entre partides -->
      <div class="rounded-xl border p-6">
        <h2 class="text-lg font-semibold mb-4 text-gray-800">⏰ Cooldown entre Partides</h2>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label for="cooldown_min" class="block text-sm font-medium text-gray-700 mb-1">
              Dies mínims entre partides
            </label>
            <input
              id="cooldown_min"
              type="number"
              min="0"
              max="30"
              bind:value={settings.cooldown_min_dies}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">
              Un jugador no pot jugar durant aquests dies després d'una partida
            </p>
          </div>

          <div>
            <label for="cooldown_max" class="block text-sm font-medium text-gray-700 mb-1">
              Dies màxims entre partides
            </label>
            <input
              id="cooldown_max"
              type="number"
              min="0"
              max="60"
              bind:value={settings.cooldown_max_dies}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">
              Temps màxim recomanat entre partides abans de considerar inactivitat
            </p>
          </div>
        </div>
      </div>

      <!-- Inactivitat -->
      <div class="rounded-xl border p-6">
        <h2 class="text-lg font-semibold mb-4 text-gray-800">😴 Gestió d'Inactivitat</h2>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label for="pre_inactiu" class="block text-sm font-medium text-gray-700 mb-1">
              Setmanes per pre-inactivitat
            </label>
            <input
              id="pre_inactiu"
              type="number"
              min="1"
              max="20"
              bind:value={settings.pre_inactiu_setmanes}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">
              Avís de possible inactivitat després d'aquest temps sense jugar
            </p>
          </div>

          <div>
            <label for="inactiu" class="block text-sm font-medium text-gray-700 mb-1">
              Setmanes per inactivitat completa
            </label>
            <input
              id="inactiu"
              type="number"
              min="2"
              max="30"
              bind:value={settings.inactiu_setmanes}
              class="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">
              El jugador és marcat com inactiu i pot ser relegat del rànquing
            </p>
          </div>
        </div>
      </div>

      <!-- Botó de guardar -->
      <div class="flex justify-between items-center pt-4">
        <p class="text-sm text-gray-500">
          Última actualització: {new Date(settings.updated_at).toLocaleString()}
        </p>
        <button
          type="submit"
          disabled={saving}
          class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-md disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {saving ? 'Guardant…' : 'Guardar Configuració'}
        </button>
      </div>
    </form>
  </div>
{/if}