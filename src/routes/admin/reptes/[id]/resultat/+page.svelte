<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { user, isAdmin } from '$lib/authStore';

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
  let rpcMsg: string | null = null;

  let chal: Challenge | null = null;
  let reptadorNom = '—';
  let reptatNom = '—';

  let settings: Settings = {
    caramboles_objectiu: 2,
    max_entrades: 50,
    allow_tiebreak: true
  };

  // Formulari
  let carR: number | '' = 0;
  let carT: number | '' = 0;
  let entrades: number | '' = 0;
  let tiebreak = false;
  let tbR: number | '' = '';
  let tbT: number | '' = '';
  let tipusResultat: 'normal' | 'walkover_reptador' | 'walkover_reptat' = 'normal';

  let data_joc_local = '';

  const id = $page.params.id;

  onMount(load);

  async function load() {
    try {
      loading = true; error = null; okMsg = null; rpcMsg = null;

      if (!$user?.email) { error = 'Has d’iniciar sessió.'; return; }
      if (!$isAdmin) { error = 'Només administradors poden registrar resultats.'; return; }

      const { supabase } = await import('$lib/supabaseClient');

      const { data: c, error: e1 } = await supabase
        .from('challenges')
        .select('id,event_id,reptador_id,reptat_id,pos_reptador,pos_reptat,data_acceptacio')
        .eq('id', id)
        .maybeSingle();
      if (e1) throw e1;
      if (!c) { error = 'Repte no trobat.'; return; }
      chal = c;

      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', [c.reptador_id, c.reptat_id]);
      if (e2) throw e2;
      const dict = new Map((players ?? []).map((p:any)=>[p.id, p.nom]));
      reptadorNom = dict.get(c.reptador_id) ?? '—';
      reptatNom = dict.get(c.reptat_id) ?? '—';

      const { data: cfg } = await supabase
        .from('app_settings')
        .select('caramboles_objectiu,max_entrades,allow_tiebreak')
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (cfg) settings = cfg;

      data_joc_local = toLocalInput(c.data_acceptacio || new Date().toISOString());
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
  $: if (tipusResultat !== 'normal') tiebreak = false;

  function validate(parsed: string | null, tipus: 'normal' | 'walkover_reptador' | 'walkover_reptat'): string | null {
    if (!parsed) return 'Cal indicar la data de joc.';
    if (tipus !== 'normal') return null;
    const _carR = toNum(carR), _carT = toNum(carT), _entr = toNum(entrades);
    if (!isInt(carR) || _carR < 0) return 'Caràmboles (reptador) ha de ser un enter ≥ 0.';
    if (!isInt(carT) || _carT < 0) return 'Caràmboles (reptat) ha de ser un enter ≥ 0.';
    if (!isInt(entrades) || _entr < 0) return 'Entrades ha de ser un enter ≥ 0.';
    if (_carR > settings.caramboles_objectiu || _carT > settings.caramboles_objectiu) {
      return `Caràmboles màximes: ${settings.caramboles_objectiu}.`;
    }
    if (_entr > settings.max_entrades) return `Entrades màximes: ${settings.max_entrades}.`;
    if (_carR === _carT && !tiebreak) {
      return settings.allow_tiebreak
        ? 'Empat de caràmboles: activa tie-break i informa el resultat.'
        : 'Empat de caràmboles i el tie-break està desactivat a Configuració.';
    }
    if (tiebreak) {
      const _tbR = toNum(tbR), _tbT = toNum(tbT);
      if (!isInt(tbR) || !isInt(tbT)) return 'Resultat de tie-break ha de ser enter.';
      if (_tbR < 0 || _tbT < 0) return 'Els resultats del tie-break no poden ser negatius.';
      if (_tbR === _tbT) return 'El tie-break no pot acabar en empat.';
    }
    return null;
  }

  function resultEnum():
    | 'guanya_reptador'
    | 'guanya_reptat'
    | 'empat_tiebreak_reptador'
    | 'empat_tiebreak_reptat'
    | 'walkover_reptador'
    | 'walkover_reptat' {
    if (tipusResultat !== 'normal') return tipusResultat;
    const _carR = toNum(carR), _carT = toNum(carT);
    if (tiebreak) {
      const _tbR = Number(tbR), _tbT = Number(tbT);
      return _tbR > _tbT ? 'empat_tiebreak_reptador' : 'empat_tiebreak_reptat';
    }
    return _carR > _carT ? 'guanya_reptador' : 'guanya_reptat';
  }

  $: valMsg = loading ? null : validate(parsedIso, tipusResultat);

  async function save() {
    error = null; okMsg = null; rpcMsg = null;
    if (valMsg) { error = valMsg; return; }
    if (!parsedIso) { error = 'Data invàlida.'; return; }

    const isWalkover = tipusResultat !== 'normal';
    const hasTB = !isWalkover && !!tiebreak;

    try {
      saving = true;
      const { supabase } = await import('$lib/supabaseClient');

      const insertRow: any = {
        challenge_id: id,
        data_joc: parsedIso,
        caramboles_reptador: isWalkover ? 0 : Number(carR),
        caramboles_reptat:   isWalkover ? 0 : Number(carT),
        entrades:            isWalkover ? 0 : Number(entrades),
        resultat: isWalkover ? tipusResultat : resultEnum(),
        tiebreak: hasTB
      };

      if (hasTB) {
        insertRow.tiebreak_reptador = Number(tbR);
        insertRow.tiebreak_reptat   = Number(tbT);
      } else {
        // Respectar el CHECK: sense tiebreak, aquests camps han de ser NULL
        insertRow.tiebreak_reptador = null;
        insertRow.tiebreak_reptat   = null;
      }

      const { error: e1 } = await supabase.from('matches').insert(insertRow);
      if (e1) throw e1;

      const { error: e2 } = await supabase
        .from('challenges')
        .update({ estat: 'jugat' })
        .eq('id', id);
      if (e2) throw e2;

      // Aplicar resultat al rànquing (si tens la RPC creada)
      const { data: d3, error: e3 } = await supabase.rpc('apply_match_result', { p_challenge: id });
      if (e3) {
        rpcMsg = `Rànquing NO actualitzat (RPC): ${e3.message}`;
      } else {
        const r = Array.isArray(d3) && d3[0] ? d3[0] : null;
        if (r?.swapped) rpcMsg = 'Rànquing actualitzat: intercanvi de posicions fet.';
        else rpcMsg = `Rànquing sense canvis${r?.reason ? ' (' + r.reason + ')' : ''}.`;
      }

      okMsg = 'Resultat desat correctament. Repte marcat com a "jugat".';
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
          <option value="walkover_reptador">Incompareixença (guanya reptador)</option>
          <option value="walkover_reptat">Incompareixença (guanya reptat)</option>
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
            <div class="mt-4 flex items-center gap-2">
              <input id="tiebreak" type="checkbox" class="rounded border" bind:checked={tiebreak} disabled={!settings.allow_tiebreak} />
              <label for="tiebreak" class="text-sm">Hi ha hagut tie-break</label>
            </div>

            {#if tiebreak}
              <div class="mt-3 grid grid-cols-2 gap-3">
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
