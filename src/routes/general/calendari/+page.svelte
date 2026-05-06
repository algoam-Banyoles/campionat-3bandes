<script lang="ts">
  import CalendarView from '$lib/components/general/calendar/CalendarView.svelte';
  import { mySociNumero } from '$lib/stores/mySoci';

  let onlyMine = false;
</script>

<svelte:head>
  <title>Calendari general</title>
  <meta name="description" content="Calendari d'esdeveniments i reptes programats del campionat de billar a 3 bandes" />
</svelte:head>

<div class="cal-root">
  <header class="cal-mast">
    <div class="cal-mast-row">
      <div>
        <div class="editorial-eyebrow">Foment Martinenc · Secció billar</div>
        <h1 class="cal-title">Calendari general</h1>
        <p class="cal-sub">
          Tots els esdeveniments: campionats socials, reptes del rànquing continu,
          activitats del club i partides hàndicap programades.
        </p>
      </div>
      {#if $mySociNumero}
        <label class="cal-mine-toggle">
          <input type="checkbox" bind:checked={onlyMine} />
          <span>Només meves</span>
        </label>
      {/if}
    </div>
  </header>

  <CalendarView {onlyMine} />
</div>

<style>
  .cal-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .cal-mast {
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
  .cal-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .cal-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }
  .cal-mast-row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
    flex-wrap: wrap;
  }
  .cal-mine-toggle {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem 0.85rem;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule-strong, #b8b3a8);
    cursor: pointer;
    font-family: var(--font-sans, sans-serif);
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink, #1a1814);
    user-select: none;
    flex-shrink: 0;
    min-height: 40px;
  }
  .cal-mine-toggle:hover { border-color: var(--ink, #1a1814); }
  .cal-mine-toggle input[type='checkbox'] {
    width: 1rem;
    height: 1rem;
    accent-color: var(--ink, #1a1814);
    cursor: pointer;
  }
  .cal-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .cal-root :global(.bg-slate-50),
  .cal-root :global(.bg-gray-50) { background: var(--paper, #fbfaf6) !important; }
  .cal-root :global(.rounded),
  .cal-root :global(.rounded-md),
  .cal-root :global(.rounded-lg),
  .cal-root :global(.rounded-xl) { border-radius: 0 !important; }
  .cal-root :global(.shadow),
  .cal-root :global(.shadow-sm),
  .cal-root :global(.shadow-md) { box-shadow: none !important; }
</style>
