<script lang="ts">
  import { onMount } from 'svelte';
    import { page } from '$app/stores';
    import { user } from '$lib/stores/auth';
    import { checkIsAdmin } from '$lib/roles';
  import { getSettings, type AppSettings } from '$lib/settings';
  import { refreshRanking } from '$lib/rankingStore';
  import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';

  type Challenge = {
    id: string;
    event_id: string;
    reptador_id: string;
    reptat_id: string;
    pos_reptador: number | null;
    pos_reptat: number | null;
    data_programada: string | null;
    estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
  };

  let loading = true;
  let saving = false;
  let error: string | null = null;
  let okMsg: string | null = null;
  let rpcMsg: string | null = null;

  let chal: Challenge | null = null;
  let reptadorNom = '—';
  let reptatNom = '—';

  let settings: AppSettings;

  // Formulari
  let carR: number | '' = 0;
  let carT: number | '' = 0;
  let entrades: number | '' = 0;
  let serieR: number | '' = 0;
  let serieT: number | '' = 0;
  let tbR: number | '' = '';
  let tbT: number | '' = '';
  let tipusResultat: 'normal' | 'incompareixenca_reptador' | 'incompareixenca_reptat' = 'normal';

  let data_joc_local = '';


  function resultEnum():
    | 'guanya_reptador'
    | 'guanya_reptat'
    | 'empat_tiebreak_reptador'
    | 'empat_tiebreak_reptat' {
    if (tipusResultat === 'incompareixenca_reptador') return 'guanya_reptat';
    if (tipusResultat === 'incompareixenca_reptat') return 'guanya_reptador';
    if (Number(carR) === Number(carT))
      return Number(tbR) > Number(tbT) ? 'empat_tiebreak_reptador' : 'empat_tiebreak_reptat';
    return Number(carR) > Number(carT) ? 'guanya_reptador' : 'guanya_reptat';
  }

  const id = $page.params.id;

  onMount(load);

  async function load() {
    try {
      loading = true; error = null; okMsg = null; rpcMsg = null;

      if (!$user?.email) { error = 'Has d’iniciar sessió.'; return; }
      const adm = await checkIsAdmin();
      if (!adm) { error = 'Només administradors poden registrar resultats.'; return; }

      settings = await getSettings();

      const { supabase } = await import('$lib/supabaseClient');

      const { data: c, error: e1 } = await supabase
        .from('challenges')
        .select('id,event_id,reptador_id,reptat_id,pos_reptador,pos_reptat,data_programada,estat')
        .eq('id', id)
        .maybeSingle();
      if (e1) throw e1;
      if (!c) { error = 'Repte no trobat.'; return; }
      if (!['acceptat', 'programat'].includes(c.estat)) {
        error = 'Estat no permet posar resultat.';
        return;
      }
      chal = c;

      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', [c.reptador_id, c.reptat_id]);
      if (e2) throw e2;
      const dict = new Map((players ?? []).map((p:any)=>[p.id, p.nom]));
      reptadorNom = dict.get(c.reptador_id) ?? '—';
      reptatNom = dict.get(c.reptat_id) ?? '—';

      data_joc_local = toLocalInput(c.data_programada || new Date().toISOString());
    } catch (e:any) {
      error = e?.message ?? 'Error carregant el repte';
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

  function parseLocalToIso(local: string | null): string | null {
    if (!local) return null;
    const s = local.trim();
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/);
    if (!m) {
      const dt2 = new Date(s);
      return isNaN(dt2.getTime()) ? null : dt2.toISOString();
    }
    const [, y, mo, d, h, mi] = m;
    const Y = Number(y), M = Number(mo) - 1, D = Number(d);
    const H = Number(h), I = Number(mi);
    const dt = new Date(Y, M, D, H, I);
    if (isNaN(dt.getTime())) return null;
    if (
      dt.getFullYear() !== Y ||
      dt.getMonth() !== M ||
      dt.getDate() !== D ||
      dt.getHours() !== H ||
      dt.getMinutes() !== I
    )
      return null;
    return dt.toISOString();
  }

  const toNum = (v: number | '' ) => (v === '' ? NaN : Number(v));

  const isInt = (v: number | '' ) => Number.isInteger(toNum(v));

  let parsedIso: string | null = null;
  $: parsedIso = parseLocalToIso(data_joc_local);

  function validate(parsed: string | null, tipus: 'normal' | 'incompareixenca_reptador' | 'incompareixenca_reptat'): string | null {
    if (!parsed) return 'Cal indicar la data de joc.';
    if (tipus !== 'normal') return null;
    const _carR = toNum(carR), _carT = toNum(carT), _entr = toNum(entrades);
    const _serR = toNum(serieR), _serT = toNum(serieT);
    if (!isInt(carR) || _carR < 0) return 'Caràmboles (reptador) ha de ser un enter ≥ 0.';
    if (!isInt(carT) || _carT < 0) return 'Caràmboles (reptat) ha de ser un enter ≥ 0.';
    if (!isInt(entrades) || _entr < 0) return 'Entrades ha de ser un enter ≥ 0.';
    if (!isInt(serieR) || _serR < 0) return 'Sèrie màxima (reptador) ha de ser un enter ≥ 0.';
    if (!isInt(serieT) || _serT < 0) return 'Sèrie màxima (reptat) ha de ser un enter ≥ 0.';
    if (_serR > _carR) return 'Sèrie màxima (reptador) no pot superar les caràmboles.';
    if (_serT > _carT) return 'Sèrie màxima (reptat) no pot superar les caràmboles.';
    if (_carR > settings.caramboles_objectiu || _carT > settings.caramboles_objectiu) {
      return `Caràmboles màximes: ${settings.caramboles_objectiu}.`;
    }
    if (_entr > settings.max_entrades) return `Entrades màximes: ${settings.max_entrades}.`;
    if (_carR === _carT) {
      if (!settings.allow_tiebreak) return 'Empat de caràmboles i el tie-break està desactivat a Configuració.';
      const _tbR = toNum(tbR), _tbT = toNum(tbT);
      if (!isInt(tbR) || !isInt(tbT)) return 'Resultat de tie-break ha de ser enter.';
      if (_tbR < 0 || _tbT < 0) return 'Els resultats del tie-break no poden ser negatius.';
      if (_tbR === _tbT) return 'El tie-break no pot acabar en empat.';
    }
    return null;
  }


  $: valMsg = loading ? null : validate(parsedIso, tipusResultat);

  async function save() {
    error = null; okMsg = null; rpcMsg = null;
    if (valMsg) { error = valMsg; return; }
    if (!parsedIso) { error = 'Data invàlida.'; return; }
    if (!chal || !['acceptat', 'programat'].includes(chal.estat)) {
      error = 'Estat no permet posar resultat.';
      return;
    }

    try {
      saving = true;
      const { supabase } = await import('$lib/supabaseClient');

      const isWalkover = tipusResultat !== 'normal';
      const isTie = tipusResultat === 'normal' && Number(carR) === Number(carT);
      const resEnum = resultEnum();

      const insertRow: any = {
        challenge_id: id,
        data_joc: parsedIso,
        caramboles_reptador: isWalkover ? 0 : Number(carR),
        caramboles_reptat:   isWalkover ? 0 : Number(carT),
        entrades:            isWalkover ? 0 : Number(entrades),
        serie_max_reptador: isWalkover ? 0 : Number(serieR),
        serie_max_reptat:   isWalkover ? 0 : Number(serieT),
        resultat: resEnum,
        tiebreak: isTie,
        tiebreak_reptador: isTie ? Number(tbR) : null,
        tiebreak_reptat:   isTie ? Number(tbT) : null
      };

      const { error: e1 } = await supabase
        .from('matches')
        .insert(insertRow)
        .select('id')
        .single();
      if (e1) throw e1;

      const { data: upd, error: e2 } = await supabase
        .from('challenges')
        .update({ estat: 'jugat' })
        .eq('id', id)
        .in('estat', ['acceptat', 'programat'])
        .select('id');
      if (e2) throw e2;
      if (!upd || upd.length === 0) throw new Error('Estat no permet posar resultat');

      // Aplicar resultat al rànquing (si tens la RPC creada)
      const { data: d3, error: e3 } = await supabase.rpc('apply_match_result', { p_challenge: id });
      if (e3) {
        rpcMsg = `Rànquing NO actualitzat (RPC): ${e3.message}`;
      } else {
        const r = Array.isArray(d3) && d3[0] ? d3[0] : null;
        if (r?.swapped) rpcMsg = 'Rànquing actualitzat: intercanvi de posicions fet.';
        else rpcMsg = `Rànquing sense canvis${r?.reason ? ' (' + r.reason + ')' : ''}.`;
      }
      okMsg = `Resultat desat correctament. Repte marcat com a "${CHALLENGE_STATE_LABEL.jugat.toLowerCase()}".`;
      await refreshRanking();
    } catch (e:any) {
      error = e?.message ?? 'No s’ha pogut desar el resultat';
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head><title>Posar resultat</title></svelte:head>

<h1 class="text-2xl font-semibold mb-4">Posar resultat</h1>

{#if loading}
  <div class="animate-pulse rounded border p-4 text-slate-500">Carregant…</div>
{:else}
  {#if error}
    <div class="rounded border border-red-300 bg-red-50 text-red-800 p-3 mb-4">{error}</div>
  {/if}
  {#if okMsg}
    <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-2">{okMsg}</div>
  {/if}
  {#if rpcMsg}
    <div class="rounded border border-blue-300 bg-blue-50 text-blue-900 p-3 mb-4">{rpcMsg}</div>
  {/if}

  {#if !error && chal}
    <div class="rounded-2xl border bg-white p-4 shadow-sm mb-6">
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-xs rounded-full bg-slate-900 text-white px-2 py-0.5">Repte</span>
        <span class="text-xs rounded-full bg-slate-100 px-2 py-0.5">ID: {chal.id}</span>
      </div>

      <div class="mt-3 grid gap-2 text-sm">
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center gap-2 rounded-full bg-blue-50 text-blue-900 px-3 py-1">
            <span class="text-[10px] uppercase tracking-wide opacity-70">Reptador</span>
            <span class="font-medium">#{chal.pos_reptador ?? '—'} — {reptadorNom}</span>
          </span>
        </div>
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center gap-2 rounded-full bg-emerald-50 text-emerald-900 px-3 py-1">
            <span class="text-[10px] uppercase tracking-wide opacity-70">Reptat</span>
            <span class="font-medium">#{chal.pos_reptat ?? '—'} — {reptatNom}</span>
          </span>
        </div>
      </div>
    </div>

    <form class="grid gap-5 max-w-2xl" on:submit|preventDefault={save}>
      <div class="grid gap-2">
        <label for="tipus" class="text-sm text-slate-700">Tipus de resultat</label>
        <select id="tipus" class="rounded-xl border px-3 py-2" bind:value={tipusResultat}>
          <option value="normal">Partida normal</option>
          <option value="incompareixenca_reptador">Incompareixença del reptador (guanya reptat)</option>
          <option value="incompareixenca_reptat">Incompareixença del reptat (guanya reptador)</option>
        </select>
      </div>

      <div class="grid gap-2">
        <label for="data_joc" class="text-sm text-slate-700">Data del joc</label>
        <input
          id="data_joc"
          type="datetime-local"
          step="60"
          class="w-full rounded-xl border px-3 py-2"
          bind:value={data_joc_local}
          required
        />
        <p class="text-xs text-slate-500 mt-1">
          Debug data: <code>{data_joc_local}</code> → <code>{parsedIso ?? 'INVALID'}</code>
        </p>
      </div>

      {#if tipusResultat === 'normal'}
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div class="rounded-2xl border bg-white p-4 shadow-sm">
            <div class="text-xs uppercase tracking-wide text-slate-500 mb-2">Caràmboles</div>
            <div class="grid grid-cols-1 gap-3">
              <label class="grid gap-1">
                <span class="text-sm text-slate-700">Reptador</span>
                <input type="number" min="0" max={settings.caramboles_objectiu}
                       class="rounded-xl border px-3 py-2"
                       bind:value={carR}/>
              </label>
              <label class="grid gap-1">
                <span class="text-sm text-slate-700">Reptat</span>
                <input type="number" min="0" max={settings.caramboles_objectiu}
                       class="rounded-xl border px-3 py-2"
                       bind:value={carT}/>
              </label>
            </div>
          </div>
          <div class="rounded-2xl border bg-white p-4 shadow-sm">
            <div class="text-xs uppercase tracking-wide text-slate-500 mb-2">Entrades i Tie-break</div>
            <label class="grid gap-1">
              <span class="text-sm text-slate-700">Entrades (total)</span>
              <input type="number" min="0" max={settings.max_entrades}
                     class="rounded-xl border px-3 py-2"
                     bind:value={entrades}/>
            </label>
            {#if Number(carR) === Number(carT) && settings.allow_tiebreak}
              <div class="mt-4 grid grid-cols-2 gap-3">
                <label class="grid gap-1">
                  <span class="text-sm text-slate-700">Tie-break (reptador)</span>
                  <input type="number" min="0" class="rounded-xl border px-3 py-2" bind:value={tbR} />
                </label>
                <label class="grid gap-1">
                  <span class="text-sm text-slate-700">Tie-break (reptat)</span>
                  <input type="number" min="0" class="rounded-xl border px-3 py-2" bind:value={tbT} />
                </label>
              </div>
            {/if}
          </div>

          <div class="rounded-2xl border bg-white p-4 shadow-sm">
            <div class="text-xs uppercase tracking-wide text-slate-500 mb-2">Sèrie màxima</div>
            <div class="grid grid-cols-1 gap-3">
              <label class="grid gap-1">
                <span class="text-sm text-slate-700">Reptador</span>
                <input type="number" min="0" class="rounded-xl border px-3 py-2" bind:value={serieR} />
              </label>
              <label class="grid gap-1">
                <span class="text-sm text-slate-700">Reptat</span>
                <input type="number" min="0" class="rounded-xl border px-3 py-2" bind:value={serieT} />
              </label>
            </div>
          </div>
        </div>
      {/if}

      {#if valMsg}
        <div class="rounded border border-amber-300 bg-amber-50 text-amber-900 p-2 text-sm">
          {valMsg}
        </div>
      {/if}

      <div class="flex items-center gap-3 pt-1">
        <button type="submit"
                class="rounded-2xl bg-slate-900 text-white px-4 py-2 disabled:opacity-60 shadow-sm"
                disabled={saving || !!valMsg}>
          {saving ? 'Desant…' : 'Desa resultat'}
        </button>
        <a href="/admin/reptes" class="text-sm underline text-slate-600">Torna a Reptes</a>
      </div>
    </form>
  {/if}
{/if}

