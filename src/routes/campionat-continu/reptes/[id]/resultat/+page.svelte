<script lang="ts">
      import { onMount } from 'svelte';
        import { page } from '$app/stores';
        import { user } from '$lib/stores/auth';
        import { checkIsAdmin } from '$lib/roles';
    import Banner from '$lib/components/general/Banner.svelte';
    import { formatSupabaseError, ok as okText, err as errText } from '$lib/ui/alerts';
    import { refreshRanking } from '$lib/stores/rankingStore';
    import { addToast } from '$lib/ui/toastStore';
    import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';

  type Challenge = {
    id: string;
    event_id: string;
    reptador_id: string;
    reptat_id: string;
    pos_reptador: number | null;
    pos_reptat: number | null;
    data_programada: string | null;
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
    let rpcMsg: string | null = null;

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
  let serieR = 0;
  let serieT = 0;
  let tbR: number | null = null;
  let tbT: number | null = null;
  let data_joc_local = '';

  const id = $page.params.id;

  onMount(load);

  async function load() {
    try {
      loading = true; error = null;

        if (!$user?.email) { error = errText('Has d’iniciar sessió.'); return; }
        const isAdmin = await checkIsAdmin();
        if (!isAdmin) { error = errText('Només admins poden posar resultats.'); return; }

      const { supabase } = await import('$lib/supabaseClient');

      // 1) Carrega repte
      const { data: c, error: e1 } = await supabase
        .from('challenges')
        .select('id,event_id,reptador_id,reptat_id,pos_reptador,pos_reptat,data_programada')
        .eq('id', id)
        .maybeSingle();
      if (e1) throw e1;
      if (!c) { error = errText('Repte no trobat.'); return; }
      chal = c;

      // 2) Noms jugadors
      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id, socis!inner(nom)')
        .in('id', [c.reptador_id, c.reptat_id]);
      if (e2) throw e2;
      const dict = new Map((players ?? []).map((p:any)=>[p.id, p.socis?.nom]));
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

      data_joc_local = toLocalInput(c.data_programada) || toLocalInput(new Date().toISOString());
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
    if (carR === settings.caramboles_objectiu && carT < settings.caramboles_objectiu) return 'reptador';
    if (carT === settings.caramboles_objectiu && carR < settings.caramboles_objectiu) return 'reptat';
    if (carR === carT) {
      if (tbR != null && tbT != null) return tbR > tbT ? 'reptador' : 'reptat';
      return 'empat';
    }
    if (carR > carT) return 'reptador';
    if (carT > carR) return 'reptat';
    return 'empat';
  }

  async function save() {
    error = null; okMsg = null; rpcMsg = null;
    const data_iso = parseLocalToIso(data_joc_local);
    if (!data_iso) { error = errText('Data invàlida.'); return; }
    if (carR < 0 || carT < 0 || entrades < 0 || serieR < 0 || serieT < 0) {
      error = errText('Els valors han de ser enters ≥ 0.');
      return;
    }
    if (serieR > carR || serieT > carT) {
      error = errText('La sèrie màxima no pot superar les caràmboles.');
      return;
    }
    const isTie = carR === carT;
    if (isTie) {
      if (!settings.allow_tiebreak) {
        error = errText('Empat de caràmboles i el tie-break està desactivat.');
        return;
      }
      if (tbR == null || tbT == null) {
        error = errText('Cal informar el resultat del tie-break.');
        return;
      }
      if (tbR < 0 || tbT < 0) {
        error = errText('El tie-break no pot tenir valors negatius.');
        return;
      }
      if (tbR === tbT) {
        error = errText('El tie-break no pot acabar en empat.');
        return;
      }
    }

    const resultat = decideWinner();

    try {
      saving = true;
      const { supabase } = await import('$lib/supabaseClient');

      // 1) Inserir match
      const { error: e1 } = await supabase
        .from('matches')
        .insert({
          challenge_id: id,
          data_joc: data_iso,
          caramboles_reptador: carR,
          caramboles_reptat: carT,
          entrades,
          serie_max_reptador: serieR,
          serie_max_reptat: serieT,
          resultat,
          tiebreak: isTie,
          tiebreak_reptador: isTie ? tbR : null,
          tiebreak_reptat: isTie ? tbT : null
        })
        .select('id')
        .single();
      if (e1) throw e1;

      // 2) Update estat repte
      const { error: e2 } = await supabase
        .from('challenges')
        .update({ estat: 'jugat' })
        .eq('id', id);
      if (e2) throw e2;
      // 3) Actualitza rànquing
      const { data: d3, error: e3 } = await supabase.rpc('apply_match_result', { p_challenge: id });
      if (e3) {
        rpcMsg = errText(`Rànquing NO actualitzat (RPC): ${e3.message}`);
      } else {
        const r = Array.isArray(d3) && d3[0] ? d3[0] : null;
        rpcMsg = r?.swapped
          ? okText('Rànquing actualitzat: intercanvi de posicions fet.')
          : okText(`Rànquing sense canvis${r?.reason ? ' (' + r.reason + ')' : ''}.`);
        await refreshRanking();
        addToast('Rànquing actualitzat', 'success');
      }

      okMsg = okText(
        `Resultat desat correctament. Repte marcat com a ${CHALLENGE_STATE_LABEL.jugat.toLowerCase()}.`
      );
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
    {#if rpcMsg}
      <Banner type="info" message={rpcMsg} class="mb-2" />
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
    <div>
      <label for="serieR" class="mr-2">Sèrie màxima reptador:</label>
      <input id="serieR" type="number" bind:value={serieR} min="0" max={carR} />
    </div>
    <div>
      <label for="serieT" class="mr-2">Sèrie màxima reptat:</label>
      <input id="serieT" type="number" bind:value={serieT} min="0" max={carT} />
    </div>
    {#if carR === carT && settings.allow_tiebreak}
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
