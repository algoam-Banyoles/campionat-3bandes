<script lang="ts">
      import { onMount } from 'svelte';
      import { page } from '$app/stores';
      import { user } from '$lib/authStore';
      import { adminStore as isAdmin } from '$lib/roles';
    import Banner from '$lib/components/Banner.svelte';
    import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';

  type Challenge = {
    id: string;
    event_id: string;
    reptador_id: string;
    reptat_id: string;
    pos_reptador: number | null;
    pos_reptat: number | null;
    data_acceptacio: string | null;
  };

  type Settings = {
    caramboles_objectiu: number;
    max_entrades: number;
    allow_tiebreak: boolean;
  };

  let loading = true;
  let saving = false;
    let error: string | null = null;
    let okMsg: string | null = null;

  let chal: Challenge | null = null;
  let reptadorNom = '—';
  let reptatNom = '—';

  // Config per defecte (es pot sobreescriure amb app_settings)
  let settings: Settings = {
    caramboles_objectiu: 20,
    max_entrades: 50,
    allow_tiebreak: true
  };

  // Formulari
  let carR = 0;
  let carT = 0;
  let entrades = 0;
  let tiebreak = false;
  let tbR: number | null = null;
  let tbT: number | null = null;
  let data_joc_local = '';

  const id = $page.params.id;

  onMount(load);

  async function load() {
    try {
      loading = true; error = null;

        if (!$user?.email) { error = errText('Has d’iniciar sessió.'); return; }
        if (!$isAdmin) { error = errText('Només admins poden posar resultats.'); return; }

      const { supabase } = await import('$lib/supabaseClient');

      // 1) Carrega repte
      const { data: c, error: e1 } = await supabase
        .from('challenges')
        .select('id,event_id,reptador_id,reptat_id,pos_reptador,pos_reptat,data_acceptacio')
        .eq('id', id)
        .maybeSingle();
      if (e1) throw e1;
      if (!c) { error = errText('Repte no trobat.'); return; }
      chal = c;

      // 2) Noms jugadors
      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', [c.reptador_id, c.reptat_id]);
      if (e2) throw e2;
      const dict = new Map((players ?? []).map((p:any)=>[p.id, p.nom]));
      reptadorNom = dict.get(c.reptador_id) ?? '—';
      reptatNom = dict.get(c.reptat_id) ?? '—';

      // 3) Config admin
      const { data: cfg } = await supabase
        .from('app_settings')
        .select('caramboles_objectiu,max_entrades,allow_tiebreak')
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (cfg) settings = cfg;

      data_joc_local = toLocalInput(c.data_acceptacio) || toLocalInput(new Date().toISOString());
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
    const pad = (n:number)=>String(n).padStart(2,'0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function parseLocalToIso(local: string) {
    const d = new Date(local);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  function decideWinner(): 'reptador' | 'reptat' | 'empat' {
    if (tiebreak && tbR != null && tbT != null) return tbR > tbT ? 'reptador' : 'reptat';
    if (carR === settings.caramboles_objectiu && carT < settings.caramboles_objectiu) return 'reptador';
    if (carT === settings.caramboles_objectiu && carR < settings.caramboles_objectiu) return 'reptat';
    if (carR > carT) return 'reptador';
    if (carT > carR) return 'reptat';
    return 'empat';
  }

  async function save() {
    error = null; okMsg = null;
    const data_iso = parseLocalToIso(data_joc_local);
    if (!data_iso) { error = errText('Data invàlida.'); return; }

    const resultat = decideWinner();

    try {
      saving = true;
      const { supabase } = await import('$lib/supabaseClient');

      // 1) Inserir match
      const { error: e1 } = await supabase.from('matches').insert({
        challenge_id: id,
        data_joc: data_iso,
        caramboles_reptador: carR,
        caramboles_reptat: carT,
        entrades,
        resultat,
        tiebreak,
        tiebreak_reptador: tiebreak ? tbR : null,
        tiebreak_reptat: tiebreak ? tbT : null
      });
      if (e1) throw e1;

      // 2) Update estat repte
      const { error: e2 } = await supabase
        .from('challenges')
        .update({ estat: 'jugat' })
        .eq('id', id);
      if (e2) throw e2;

      okMsg = okText('Resultat desat correctament. Repte marcat com a jugat.');
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      saving = false;
    }
  }
</script>

<h1 class="text-2xl font-semibold mb-3">Posar resultat</h1>

{#if loading}
  <p>Carregant…</p>
  {:else if error}
    <Banner type="error" message={error} />
  {:else if chal}
    {#if okMsg}
      <Banner type="success" message={okMsg} class="mb-2" />
    {/if}

  <div class="mb-4">
    <p><strong>Reptador:</strong> #{chal.pos_reptador ?? '—'} — {reptadorNom}</p>
    <p><strong>Reptat:</strong> #{chal.pos_reptat ?? '—'} — {reptatNom}</p>
  </div>

  <form class="space-y-3" on:submit|preventDefault={save}>
    <div>
      <label for="data_joc" class="mr-2">Data joc:</label>
      <input id="data_joc" type="datetime-local" bind:value={data_joc_local} class="border rounded px-2 py-1" />
    </div>
    <div>
      <label for="carR" class="mr-2">Caràmboles reptador:</label>
      <input id="carR" type="number" bind:value={carR} min="0" max={settings.caramboles_objectiu} />
    </div>
    <div>
      <label for="carT" class="mr-2">Caràmboles reptat:</label>
      <input id="carT" type="number" bind:value={carT} min="0" max={settings.caramboles_objectiu} />
    </div>
    <div>
      <label for="entrades" class="mr-2">Entrades:</label>
      <input id="entrades" type="number" bind:value={entrades} min="0" max={settings.max_entrades} />
    </div>
    <div class="flex items-center gap-2">
      <input id="tiebreak" type="checkbox" bind:checked={tiebreak} />
      <label for="tiebreak">Hi ha hagut tie-break</label>
    </div>
    {#if tiebreak}
      <div>
        <label for="tbR" class="mr-2">Tie-break reptador:</label>
        <input id="tbR" type="number" bind:value={tbR} min="0" />
      </div>
      <div>
        <label for="tbT" class="mr-2">Tie-break reptat:</label>
        <input id="tbT" type="number" bind:value={tbT} min="0" />
      </div>
    {/if}
    <button class="bg-slate-900 text-white px-4 py-2 rounded" disabled={saving}>
      {saving ? 'Desant…' : 'Desa resultat'}
    </button>
  </form>
{/if}
