<script lang="ts">
  import { goto } from '$app/navigation';
      // Guard: només admins en vista admin (respecta el toggle viewMode).
      $: if ($adminChecked && !$effectiveIsAdmin) {
        goto('/campionat-continu/reptes');
      }

  import { onMount } from 'svelte';
    import { page } from '$app/stores';
    import { user } from '$lib/stores/auth';
    import { adminChecked } from '$lib/stores/adminAuth';
    import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { getSettings, type AppSettings } from '$lib/settings';
  import { refreshRanking } from '$lib/stores/rankingStore';
  import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';

  type Challenge = {
    id: string;
    event_id: string;
    reptador_soci_numero: number;
    reptat_soci_numero: number;
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

      settings = await getSettings();

      const { supabase } = await import('$lib/supabaseClient');

      const { data: c, error: e1 } = await supabase
        .from('challenges')
        .select('id,event_id,reptador_soci_numero,reptat_soci_numero,pos_reptador,pos_reptat,data_programada,estat')
        .eq('id', id)
        .maybeSingle();
      if (e1) throw e1;
      if (!c) { error = 'Repte no trobat.'; return; }
      if (!['acceptat', 'programat'].includes(c.estat)) {
        error = 'Estat no permet posar resultat.';
        return;
      }
      chal = c as unknown as Challenge;

      const { data: socisData, error: e2 } = await supabase
        .from('socis')
        .select('numero_soci,nom')
        .in('numero_soci', [c.reptador_soci_numero, c.reptat_soci_numero]);
      if (e2) throw e2;
      const dict = new Map((socisData ?? []).map((p:any)=>[p.numero_soci, p.nom]));
      reptadorNom = dict.get((c as any).reptador_soci_numero) ?? '—';
      reptatNom = dict.get((c as any).reptat_soci_numero) ?? '—';

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
      error = e?.message ?? "No s'ha pogut desar el resultat";
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head><title>Posar resultat</title></svelte:head>

<div class="gr-sub-root">
  <header class="gr-sub-mast">
    <div class="editorial-eyebrow">Rànquing continu · Reptes</div>
    <h1>Posar resultat</h1>
  </header>

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
        <a href="/campionat-continu/gestio-reptes" class="text-sm underline text-slate-600">Torna a Reptes</a>
      </div>
    </form>
  {/if}
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
  .gr-sub-root :global(.bg-red-50),
  .gr-sub-root :global(.bg-red-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--accent, #a30b1e) !important; }
  .gr-sub-root :global(.text-slate-500),
  .gr-sub-root :global(.text-slate-600),
  .gr-sub-root :global(.text-slate-700) { color: var(--ink-2, #4a443e) !important; }
  .gr-sub-root :global(.text-red-700),
  .gr-sub-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .gr-sub-root :global(.border-red-300) { border-color: var(--accent, #a30b1e) !important; }
  .gr-sub-root :global(.rounded),
  .gr-sub-root :global(.rounded-md),
  .gr-sub-root :global(.rounded-lg),
  .gr-sub-root :global(.rounded-xl),
  .gr-sub-root :global(.rounded-2xl) { border-radius: 0 !important; }
  .gr-sub-root :global(.shadow-sm),
  .gr-sub-root :global(.shadow) { box-shadow: none !important; }
  .gr-sub-root :global(input),
  .gr-sub-root :global(select),
  .gr-sub-root :global(textarea) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .gr-sub-root :global(input:focus),
  .gr-sub-root :global(select:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
</style>

