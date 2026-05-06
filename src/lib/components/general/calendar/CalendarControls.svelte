<!-- src/lib/components/general/calendar/CalendarControls.svelte -->
<script lang="ts">
  import {
    currentDate,
    calendarView,
    navigateMonth,
    navigateWeek,
    navigateToToday,
    setCalendarView,
    type CalendarView
  } from '$lib/stores/calendar';

  $: monthYear = $currentDate.toLocaleDateString('ca-ES', {
    month: 'long',
    year: 'numeric'
  });

  $: weekRange = (() => {
    const startOfWeek = new Date($currentDate);
    const day = startOfWeek.getDay();
    const diff = startOfWeek.getDate() - day + (day === 0 ? -6 : 1);
    startOfWeek.setDate(diff);

    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);

    return `${startOfWeek.getDate()} – ${endOfWeek.getDate()} ${endOfWeek.toLocaleDateString('ca-ES', { month: 'long', year: 'numeric' })}`;
  })();

  function handlePrevious() {
    if ($calendarView === 'month') navigateMonth(-1);
    else navigateWeek(-1);
  }

  function handleNext() {
    if ($calendarView === 'month') navigateMonth(1);
    else navigateWeek(1);
  }

  function handleViewChange(view: CalendarView) {
    setCalendarView(view);
  }
</script>

<div class="cal-ctrl-bar">
  <div class="cal-period">
    <button
      on:click={handlePrevious}
      class="btn-icon"
      title="Anterior"
      aria-label="Període anterior"
    >
      <svg class="ic" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
      </svg>
    </button>

    <h2 class="cal-period-title">
      {$calendarView === 'month' ? monthYear : weekRange}
    </h2>

    <button
      on:click={handleNext}
      class="btn-icon"
      title="Següent"
      aria-label="Període següent"
    >
      <svg class="ic" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
      </svg>
    </button>
  </div>

  <div class="cal-tools">
    <button on:click={navigateToToday} class="btn-today">
      Avui
    </button>

    <div class="view-toggle" role="tablist" aria-label="Tipus de vista">
      <button
        role="tab"
        aria-selected={$calendarView === 'month'}
        on:click={() => handleViewChange('month')}
        class:active={$calendarView === 'month'}
      >
        Mes
      </button>
      <button
        role="tab"
        aria-selected={$calendarView === 'week'}
        on:click={() => handleViewChange('week')}
        class:active={$calendarView === 'week'}
      >
        Setmana
      </button>
    </div>
  </div>
</div>

<style>
  .cal-ctrl-bar {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    margin-bottom: 1rem;
    font-family: var(--font-sans);
  }
  @media (min-width: 640px) {
    .cal-ctrl-bar {
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
    }
  }

  .cal-period {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .cal-period-title {
    margin: 0;
    font-family: var(--font-sans);
    font-weight: 700;
    letter-spacing: -0.018em;
    font-size: 1.125rem;
    color: var(--ink);
    text-transform: capitalize;
    min-width: 14ch;
    text-align: center;
    line-height: 1.2;
  }

  .btn-icon {
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    padding: 0.5rem 0.6rem;
    cursor: pointer;
    min-height: 40px;
    min-width: 40px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    transition: border-color 0.12s ease;
  }
  .btn-icon:hover { border-color: var(--ink); }
  .btn-icon:focus-visible {
    outline: 2px solid var(--ink);
    outline-offset: 2px;
  }
  .ic { width: 1.05rem; height: 1.05rem; }

  .cal-tools {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .btn-today {
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    padding: 0.5rem 0.85rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
    transition: border-color 0.12s ease;
  }
  .btn-today:hover { border-color: var(--ink); }
  .btn-today:focus-visible {
    outline: 2px solid var(--ink);
    outline-offset: 2px;
  }

  .view-toggle {
    display: inline-flex;
    border: 1px solid var(--rule-strong);
  }
  .view-toggle button {
    background: var(--paper-elevated);
    color: var(--ink-2);
    border: none;
    padding: 0.5rem 0.95rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
    transition: background 0.12s ease, color 0.12s ease;
  }
  .view-toggle button + button {
    border-left: 1px solid var(--rule-strong);
  }
  .view-toggle button:hover { color: var(--ink); }
  .view-toggle button.active {
    background: var(--ink);
    color: var(--paper);
  }
  .view-toggle button:focus-visible {
    outline: 2px solid var(--ink);
    outline-offset: 2px;
    z-index: 1;
  }
</style>
