<script lang="ts">
  import { onMount } from 'svelte';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { initAdminPage } from '$lib/utils/adminPage';
  import UsageChart from '$lib/components/admin/UsageChart.svelte';
  import {
    getPageViewTotals,
    getSectionStats,
    getDailyStats,
    getTopPaths,
    sectionLabel,
    type PageViewTotals,
    type SectionStat,
    type DailyStat,
    type TopPath
  } from '$lib/api/pageViews';
  import type { EChartsOption } from 'echarts';

  let loading = true;
  let error: string | null = null;

  // Controls
  const RANGES = [
    { days: 7, label: '7 dies' },
    { days: 30, label: '30 dies' },
    { days: 90, label: '90 dies' },
    { days: 365, label: '1 any' }
  ];
  let rangeDays = 30;
  let excludeAdmin = true;

  // Data
  let totals: PageViewTotals = {
    total_views: 0,
    unique_visitors: 0,
    authed_views: 0,
    anon_views: 0
  };
  let sections: SectionStat[] = [];
  let daily: DailyStat[] = [];
  let topPaths: TopPath[] = [];

  onMount(async () => {
    const result = await initAdminPage(async () => {
      await load();
    });
    loading = result.loading;
    if (result.error) error = result.error;
  });

  function rangeBounds(days: number): { fromISO: string; toISO: string } {
    const to = new Date();
    const from = new Date(to.getTime() - days * 24 * 60 * 60 * 1000);
    return { fromISO: from.toISOString(), toISO: to.toISOString() };
  }

  async function load() {
    loading = true;
    error = null;
    try {
      const { fromISO, toISO } = rangeBounds(rangeDays);
      const opts = { fromISO, toISO, includeAdmin: !excludeAdmin };
      const [t, s, d, p] = await Promise.all([
        getPageViewTotals(opts),
        getSectionStats(opts),
        getDailyStats(opts),
        getTopPaths({ ...opts, limit: 20 })
      ]);
      totals = t;
      sections = s;
      daily = d;
      topPaths = p;
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }

  function setRange(days: number) {
    if (days === rangeDays) return;
    rangeDays = days;
    void load();
  }

  function toggleExcludeAdmin() {
    excludeAdmin = !excludeAdmin;
    void load();
  }

  // ── Derivats ────────────────────────────────────────────────────────────
  $: pctAuthed =
    totals.total_views > 0
      ? Math.round((totals.authed_views / totals.total_views) * 100)
      : 0;
  $: topSection = sections.length > 0 ? sectionLabel(sections[0].section) : '—';
  $: hasData = totals.total_views > 0;

  function fmtNum(n: number): string {
    return new Intl.NumberFormat('ca-ES').format(n);
  }

  // Omple els dies sense dades amb 0 perquè la línia temporal sigui contínua.
  function fillDailyGaps(rows: DailyStat[], days: number): DailyStat[] {
    const map = new Map(rows.map((r) => [r.day, r]));
    const out: DailyStat[] = [];
    const today = new Date();
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(today.getTime() - i * 24 * 60 * 60 * 1000);
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      const key = `${y}-${m}-${dd}`;
      out.push(map.get(key) ?? { day: key, views: 0, visitors: 0 });
    }
    return out;
  }

  function shortDay(iso: string): string {
    const [y, m, d] = iso.split('-').map(Number);
    return new Date(y, m - 1, d).toLocaleDateString('ca-ES', {
      day: 'numeric',
      month: 'short'
    });
  }

  // ── Opcions ECharts ─────────────────────────────────────────────────────
  $: filledDaily = fillDailyGaps(daily, rangeDays);

  $: dailyOption = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['Visites', 'Visitants únics'], top: 0 },
    grid: { left: 48, right: 24, top: 36, bottom: 64 },
    xAxis: {
      type: 'category',
      data: filledDaily.map((r) => shortDay(r.day)),
      axisLabel: {
        rotate: 45,
        interval: Math.max(0, Math.floor(filledDaily.length / 12))
      }
    },
    yAxis: { type: 'value', minInterval: 1 },
    series: [
      {
        name: 'Visites',
        type: 'line',
        smooth: true,
        showSymbol: false,
        data: filledDaily.map((r) => r.views),
        itemStyle: { color: '#1f4a99' },
        areaStyle: { color: 'rgba(31,74,153,0.10)' }
      },
      {
        name: 'Visitants únics',
        type: 'line',
        smooth: true,
        showSymbol: false,
        data: filledDaily.map((r) => r.visitors),
        itemStyle: { color: '#1f7a3a' }
      }
    ]
  } as EChartsOption;

  $: sectionOption = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: 8, right: 24, top: 12, bottom: 12, containLabel: true },
    xAxis: { type: 'value', minInterval: 1 },
    yAxis: {
      type: 'category',
      data: [...sections].reverse().map((s) => sectionLabel(s.section)),
      axisLabel: { fontSize: 13 }
    },
    series: [
      {
        name: 'Visites',
        type: 'bar',
        data: [...sections].reverse().map((s) => s.views),
        itemStyle: { color: '#1f4a99' },
        label: { show: true, position: 'right' }
      }
    ]
  } as EChartsOption;
</script>

<svelte:head>
  <title>Estadístiques d'accés</title>
</svelte:head>

<div class="st-root">
  <header class="st-mast">
    <div class="editorial-eyebrow">Administració · Ús de l'aplicació</div>
    <h1 class="st-title">Estadístiques d'accés</h1>
    <p class="st-sub">
      Visites a les diferents seccions i pàgines de l'aplicació. Les dades són
      <strong>agregades i anònimes</strong>: no es vincula cap visita a un soci concret.
    </p>
  </header>

  <!-- Controls -->
  <div class="st-controls">
    <div class="st-range" role="group" aria-label="Període">
      {#each RANGES as r (r.days)}
        <button
          type="button"
          class="st-range-btn"
          class:active={rangeDays === r.days}
          on:click={() => setRange(r.days)}
        >
          {r.label}
        </button>
      {/each}
    </div>
    <label class="st-toggle">
      <input type="checkbox" checked={excludeAdmin} on:change={toggleExcludeAdmin} />
      <span>Excloure trànsit d'administradors</span>
    </label>
  </div>

  {#if error}
    <Banner type="error" message={error} />
    <p class="st-hint">
      Si el problema persisteix, comprova que la migració d'estadístiques s'ha aplicat
      a la base de dades.
    </p>
  {:else if loading}
    <Loader />
  {:else if !hasData}
    <div class="st-empty">
      <p>Encara no s'ha registrat cap visita en aquest període.</p>
      <p class="st-hint">
        El registre comença a partir del desplegament d'aquesta funcionalitat; les dades
        s'aniran acumulant a mesura que els usuaris naveguin per l'aplicació.
      </p>
    </div>
  {:else}
    <!-- KPIs -->
    <div class="st-kpis">
      <div class="st-kpi">
        <div class="st-kpi-val tabular-nums">{fmtNum(totals.total_views)}</div>
        <div class="st-kpi-lbl">Visites totals</div>
      </div>
      <div class="st-kpi">
        <div class="st-kpi-val tabular-nums">{fmtNum(totals.unique_visitors)}</div>
        <div class="st-kpi-lbl">Visitants únics</div>
      </div>
      <div class="st-kpi">
        <div class="st-kpi-val tabular-nums">{pctAuthed}%</div>
        <div class="st-kpi-lbl">Visites amb sessió iniciada</div>
      </div>
      <div class="st-kpi">
        <div class="st-kpi-val">{topSection}</div>
        <div class="st-kpi-lbl">Secció més visitada</div>
      </div>
    </div>

    <!-- Evolució diària -->
    <section class="st-block">
      <h2 class="st-block-title">Evolució diària</h2>
      <UsageChart option={dailyOption} height={320} />
    </section>

    <!-- Visites per secció -->
    <section class="st-block">
      <h2 class="st-block-title">Visites per secció</h2>
      <UsageChart option={sectionOption} height={Math.max(220, sections.length * 46)} />
    </section>

    <!-- Pàgines més vistes -->
    <section class="st-block">
      <h2 class="st-block-title">Pàgines més vistes</h2>
      <div class="st-table-wrap">
        <table class="st-table">
          <thead>
            <tr>
              <th>Pàgina</th>
              <th>Secció</th>
              <th class="num">Visites</th>
              <th class="num">Visitants</th>
            </tr>
          </thead>
          <tbody>
            {#each topPaths as p (p.path)}
              <tr>
                <td class="st-path">{p.path}</td>
                <td>{sectionLabel(p.section)}</td>
                <td class="num tabular-nums">{fmtNum(p.views)}</td>
                <td class="num tabular-nums">{fmtNum(p.visitors)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </section>
  {/if}
</div>

<style>
  .st-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .st-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .st-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .st-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 64ch;
  }

  .st-controls {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 1.5rem;
  }
  .st-range {
    display: inline-flex;
    border: 1px solid var(--rule-strong, #b8b3a8);
  }
  .st-range-btn {
    appearance: none;
    border: none;
    background: var(--paper-elevated, #fff);
    color: var(--ink-2, #4a443e);
    padding: 0.5rem 0.9rem;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    border-right: 1px solid var(--rule, #e6e3dc);
    min-height: 44px;
  }
  .st-range-btn:last-child {
    border-right: none;
  }
  .st-range-btn.active {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
  }
  .st-toggle {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
    cursor: pointer;
  }
  .st-toggle input {
    width: 18px;
    height: 18px;
  }

  .st-kpis {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }
  .st-kpi {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    border-left: 3px solid var(--blue, #1f4a99);
    padding: 1rem 1.1rem;
  }
  .st-kpi-val {
    font-size: 1.875rem;
    font-weight: 800;
    line-height: 1.1;
    letter-spacing: -0.02em;
  }
  .st-kpi-lbl {
    margin-top: 0.25rem;
    font-size: 0.8125rem;
    color: var(--ink-3, #807a72);
    font-weight: 600;
  }

  .st-block {
    margin-bottom: 2.25rem;
  }
  .st-block-title {
    font-size: 1.05rem;
    font-weight: 700;
    margin: 0 0 0.75rem;
    color: var(--ink, #1a1814);
  }

  .st-table-wrap {
    border: 1px solid var(--rule, #e6e3dc);
    background: var(--paper-elevated, #fff);
    overflow-x: auto;
  }
  .st-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
  }
  .st-table th,
  .st-table td {
    text-align: left;
    padding: 0.6rem 0.85rem;
    border-bottom: 1px solid var(--rule, #e6e3dc);
  }
  .st-table thead th {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--ink-3, #807a72);
    background: var(--paper, #fbfaf6);
  }
  .st-table tbody tr:last-child td {
    border-bottom: none;
  }
  .st-table .num {
    text-align: right;
  }
  .st-path {
    font-family: var(--font-mono, ui-monospace, monospace);
    color: var(--ink-2, #4a443e);
    word-break: break-all;
  }

  .st-empty {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 2.5rem 1.5rem;
    text-align: center;
    color: var(--ink-2, #4a443e);
  }
  .st-hint {
    margin-top: 0.5rem;
    font-size: 0.8125rem;
    color: var(--ink-3, #807a72);
  }
</style>
