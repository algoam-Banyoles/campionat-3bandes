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

  // Valor inicial vàlid per evitar validació prematura
  let data_joc_local = toLocalInput(new Date().toISOString());

  const id = $page.params.id;

  onMount(load);

  async function load() {
    try {
      loading = true; error = null; okMsg = null;

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

      data_joc_local =
        toLocalInput(c.data_acceptacio) ||
        toLocalInput(new Date().toISOString()) ||
        data_joc_local;
    } catch (e:any) {
      error = e?.message ?? 'Error carregant el repte';
    } finally {
      loading = false;
    }
  }

  // ISO → valor <input type="datetime-local">
  function toLocalInput(iso: string | null) {
    if (!iso) return '';
    const d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    const pad = (n:number)=>String(n).padStart(2,'0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  // Parser robust LOCAL → ISO
  function parseLocalToIso(local: string | null): string | null {
    if (!local) return null;
    let s = local.trim().replace(' ', 'T');
    const m = s.match(
      /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?$/
    );
    if (!m) {
      const dt2 = new Date(s);
      return isNaN(dt2.getTime()) ? null : dt2.toISOString();
    }
    const [, y, mo, d, h, mi, ss = '0', ms = '0'] = m;
    const Y = Number(y), M = Number(mo) - 1, D = Number(d);
    const H = Number(h), I = Number(mi), S = Number(ss), MS = Number(ms.padEnd(3, '0'));
    const dt = new Date(Y, M, D, H, I, S, MS);
    if (isNaN(dt.getTime())) return null;
    if (dt.getFullYear() !== Y || dt.getMonth() !== M || dt.getDate() !== D || dt.getHours() !== H || dt.getMinutes() !== I) return null;
    return dt.toISOString();
  }

  const toNum = (v: number | '' ) => (v === '' ? NaN : Number(v));
  const isInt = (v: number | '' ) => Number.isInteger(toNum(v));

  // Reactives
  let parsedIso: string | null = null;
  $: parsedIso = parseLocalToIso(data_joc_local);

  function validate(parsed: string | null): string | null {
    if (!parsed) return 'Cal indicar la data de joc.';

    const _carR = toNum(carR), _carT = toNum(carT), _entr = toNum(entrades);
    if (!isInt(carR) || _carR < 0) return 'Caràmboles (reptador) ha de ser un enter ≥ 0.';
    if (!isInt(carT) || _carT < 0) return 'Caràmboles (reptat) ha de ser un enter ≥ 0.';
    if (!isInt(entrades) || _entr < 0) return 'Entrades ha de ser un enter ≥ 0.';
    if (_carR > settings.caramboles_objectiu || _carT > settings.caramboles_objectiu) {
      return `Caràmboles màximes: ${settings.caramboles_objectiu}.`;
    }
    if (_entr > settings.max_entrades) return `Entrades màximes: ${settings.max_entrades}.`;

    // Si hi ha empat de caràmboles, cal tie-break
    if (_carR === _carT && !tiebreak) {
      return settings.allow_tiebreak
        ? 'Empat de caràmboles: activa tie-break i informa el resultat.'
        : 'Empat de caràmboles i el tie-break està desactivat a Configuració.';
    }

    // Si hi ha tie-break, valors enters i no empat
    if (tiebreak) {
      const _tbR = toNum(tbR), _tbT = toNum(tbT);
      if (!isInt(tbR) || !isInt(tbT)) return 'Resultat de tie-break ha de ser enter.';
      if (_tbR < 0 || _tbT < 0) return 'Els resultats del tie-break no poden ser negatius.';
      if (_tbR === _tbT) return 'El tie-break no pot acabar en empat.';
    }

    return null;
  }

  // Retorna EXACTAMENT un dels valors de l’enum match_result
  function resultEnum():
    'guanya_reptador' | 'guanya_reptat' | 'empat_tiebreak_reptador' | 'empat_tiebreak_reptat' {

    const _carR = toNum(carR), _carT = toNum(carT);

    if (tiebreak) {
      const _tbR = Number(tbR), _tbT = Number(tbT);
      return _tbR > _tbT ? 'empat_tiebreak_reptador' : 'empat_tiebreak_reptat';
    }

    // Sense tie-break: algú guanya per caràmboles
    return _carR > _carT ? 'guanya_reptador' : 'guanya_reptat';
  }

  $: valMsg = validate(parsedIso);
  $: guanyadorText = (() => {
    if (tiebreak) {
      const _tbR = toNum(tbR), _tbT = toNum(tbT);
      if (Number.isFinite(_tbR) && Number.isFinite(_tbT)) {
        return _tbR > _tbT ? `Reptador (${reptadorNom})` : `Reptat (${reptatNom})`;
      }
      return '—';
    }
    const _carR = toNum(carR), _carT = toNum(carT);
    if (Number.isFinite(_carR) && Number.isFinite(_carT)) {
      if (_carR > _carT) return `Reptador (${reptadorNom})`;
      if (_carT > _carR) return `Reptat (${reptatNom})`;
      return 'Empat (cal tie-break)';
    }
    return '—';
  })();

  async function save() {
    error = null; okMsg = null;
    if (valMsg) { error = valMsg; return; }
    if (!parsedIso) { error = 'Data invàlida.'; return; }

    const resultat = resultEnum();
    const _carR = Number(carR), _carT = Number(carT), _entr = Number(entrades);
    const _tbR  = tiebreak ? Number(tbR) : null;
    const _tbT  = tiebreak ? Number(tbT) : null;

    try {
      saving = true;
      const { supabase } = await import('$lib/supabaseClient');

      const insertRow: any = {
        challenge_id: id,
        data_joc: parsedIso,
        caramboles_reptador: _carR,
        caramboles_reptat: _carT,
        entrades: _entr,
        resultat
      };

      // Si la teva taula `matches` té aquests camps, els incloem; si no, ignora’ls
      insertRow.tiebreak = tiebreak;
      insertRow.tiebreak_reptador = _tbR;
      insertRow.tiebreak_reptat = _tbT;

      const { error: e1 } = await supabase.from('matches').insert(insertRow);
      if (e1) throw e1;

      const { error: e2 } = await supabase
        .from('challenges')
        .update({ estat: 'jugat' })
        .eq('id', id);
      if (e2) throw e2;

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
    <div class="rounded border border-green-300 bg-green-50 text-green-800 p-3 mb-4">{okMsg}</div>
  {/if}

  {#if !error && chal}
    <div class="rounded-2xl border bg-white p-4 shadow-sm mb-6">
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-xs rounded-full bg-slate-900 text-white px-2 py-0.5">Repte</span>
        <span class="text-xs rounded-full bg-slate-100 px-2 py-0.5">ID: {chal.id}</span>
        <span class="text-xs text-slate-500 ml-auto">
          Objectiu: {settings.caramboles_objectiu} · Entrades màx: {settings.max_entrades} · Tie-break: {settings.allow_tiebreak ? 'Permès' : 'No'}
        </span>
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

      <div class="rounded-2xl border bg-slate-50 p-4">
        <div class="text-xs uppercase tracking-wide text-slate-500 mb-2">Previsualització</div>
        <div class="flex items-center gap-2 text-sm">
          <span class="text-slate-600">Guanyador estimat:</span>
          <span class="rounded-full bg-slate-700 text-white px-2 py-0.5">{guanyadorText}</span>
        </div>
      </div>

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
