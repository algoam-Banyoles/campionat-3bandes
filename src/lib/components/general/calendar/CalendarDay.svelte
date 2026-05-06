<!-- src/lib/components/general/calendar/CalendarDay.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { CalendarEvent } from '$lib/stores/calendar';

  export let date: Date;
  export let events: CalendarEvent[] = [];
  export let isCurrentMonth: boolean = true;
  export let isToday: boolean = false;
  export let isSelected: boolean = false;

  const dispatch = createEventDispatcher<{
    dayClick: { date: Date };
    eventClick: { event: CalendarEvent };
  }>();

  type EvtTone = 'accent' | 'blue' | 'green' | 'amber' | 'purple' | 'ink';

  const challengeTone: Record<string, EvtTone> = {
    acceptat: 'green',
    proposat: 'amber',
    jugat: 'blue'
  };

  const eventTone: Record<string, EvtTone> = {
    torneig: 'purple',
    social: 'green',
    manteniment: 'accent',
    general: 'blue'
  };

  const palette: EvtTone[] = ['accent', 'blue', 'green', 'amber', 'purple', 'ink'];

  function hashTone(name: string): EvtTone {
    const hash = name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    return palette[hash % palette.length];
  }

  function getEventTone(event: CalendarEvent): EvtTone {
    if (event.type === 'challenge' && event.subtype?.startsWith('campionat-social')) {
      const data = event.data as { categoria_nom?: unknown } | undefined;
      if (data && typeof data.categoria_nom === 'string') {
        return hashTone(data.categoria_nom);
      }
    }

    if (event.type === 'challenge') {
      return challengeTone[event.subtype ?? ''] ?? 'ink';
    }

    return eventTone[event.subtype ?? ''] ?? 'ink';
  }

  function handleDayClick() {
    dispatch('dayClick', { date });
  }

  function handleEventClick(event: CalendarEvent, e: MouseEvent) {
    e.stopPropagation();
    dispatch('eventClick', { event });
  }

  $: visibleEvents = events.slice(0, 6);
  $: moreEventsCount = events.length - visibleEvents.length;
</script>

<div
  class="cal-cell"
  class:off-month={!isCurrentMonth}
  class:is-today={isToday}
  class:is-selected={isSelected}
  on:click={handleDayClick}
  role="button"
  tabindex="0"
  on:keydown={(e) => e.key === 'Enter' && handleDayClick()}
>
  <div class="cal-cell-head">
    <span class="cal-cell-num">
      {date.getDate()}
    </span>
    {#if events.length > 0}
      <span class="cal-cell-count tabular-nums" aria-label="{events.length} esdeveniments">
        {events.length}
      </span>
    {/if}
  </div>

  <div class="cal-cell-events">
    {#each visibleEvents as event (event.id)}
      <button
        class="evt-pill evt-{getEventTone(event)}"
        on:click={(e) => handleEventClick(event, e)}
        title={event.description || event.title}
      >
        <span class="evt-title">{event.title}</span>
        {#if event.tableInfo}
          <span class="evt-meta">{event.tableInfo}</span>
        {/if}
      </button>
    {/each}

    {#if moreEventsCount > 0}
      <div class="evt-more tabular-nums">
        +{moreEventsCount} més
      </div>
    {/if}
  </div>
</div>

<style>
  .cal-cell {
    min-height: clamp(110px, 15vw, 180px);
    padding: 0.45rem 0.5rem;
    background: var(--paper-elevated);
    border-right: 1px solid var(--rule);
    border-bottom: 1px solid var(--rule);
    cursor: pointer;
    font-family: var(--font-sans);
    color: var(--ink);
    transition: background-color 0.12s ease;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    position: relative;
  }
  .cal-cell:hover { background: var(--paper); }
  .cal-cell:focus-visible {
    outline: 2px solid var(--ink);
    outline-offset: -2px;
  }

  .cal-cell.off-month {
    background: var(--paper);
  }
  .cal-cell.off-month .cal-cell-num {
    color: var(--ink-3);
    font-weight: 500;
  }
  .cal-cell.off-month .evt-pill { opacity: 0.55; }

  .cal-cell.is-today::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--accent);
  }
  .cal-cell.is-today .cal-cell-num {
    color: var(--accent);
    font-weight: 800;
  }

  .cal-cell.is-selected {
    outline: 2px solid var(--ink);
    outline-offset: -2px;
    z-index: 1;
  }

  .cal-cell-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 0.4rem;
  }
  .cal-cell-num {
    font-size: 0.875rem;
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.01em;
  }
  .cal-cell-count {
    font-size: 0.625rem;
    font-weight: 700;
    color: var(--ink-3);
    border: 1px solid var(--rule-strong);
    padding: 0.05rem 0.35rem;
    letter-spacing: 0.04em;
    line-height: 1.4;
  }

  .cal-cell-events {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    overflow: hidden;
  }

  .evt-pill {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.4rem;
    width: 100%;
    text-align: left;
    background: var(--paper);
    color: var(--ink);
    border: 1px solid var(--rule);
    border-left: 3px solid var(--rule-strong);
    padding: 0.25rem 0.45rem;
    font-family: var(--font-sans);
    font-size: 0.75rem;
    font-weight: 600;
    line-height: 1.25;
    cursor: pointer;
    min-height: 28px;
    transition: background-color 0.12s ease, border-color 0.12s ease;
  }
  .evt-pill:hover {
    background: var(--paper-elevated);
    border-color: var(--ink);
  }
  .evt-pill:focus-visible {
    outline: 2px solid var(--ink);
    outline-offset: 1px;
  }
  .evt-title {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .evt-meta {
    flex-shrink: 0;
    font-size: 0.6875rem;
    font-weight: 500;
    color: var(--ink-3);
  }

  .evt-accent { border-left-color: var(--accent); color: var(--accent-dark, var(--accent)); }
  .evt-blue   { border-left-color: var(--blue);   color: var(--blue); }
  .evt-green  { border-left-color: var(--green);  color: var(--green); }
  .evt-amber  { border-left-color: var(--amber);  color: var(--amber); }
  .evt-purple { border-left-color: var(--sec-handicap, #5b3a8b); color: var(--sec-handicap, #5b3a8b); }
  .evt-ink    { border-left-color: var(--ink);    color: var(--ink-2); }

  .evt-more {
    font-size: 0.6875rem;
    font-weight: 600;
    color: var(--ink-3);
    padding: 0.15rem 0.4rem;
    border: 1px dashed var(--rule);
    margin-top: 0.1rem;
    text-align: center;
    letter-spacing: 0.02em;
  }

  @media (min-width: 640px) {
    .cal-cell {
      padding: 0.6rem 0.7rem;
      gap: 0.45rem;
    }
    .cal-cell-num { font-size: 0.95rem; }
    .evt-pill {
      font-size: 0.8125rem;
      padding: 0.3rem 0.55rem;
      min-height: 32px;
    }
  }

  /* Mòbil portrait: cel·les compactes amb barres fines per indicar events.
     Tap → s'obre el modal del dia amb la llista detallada. */
  @media (max-width: 639px) {
    .cal-cell {
      min-height: 78px;
      padding: 0.4rem 0.3rem 0.45rem;
      gap: 0.3rem;
    }
    .cal-cell-num { font-size: 0.9375rem; }
    .cal-cell-count {
      font-size: 0.5625rem;
      padding: 0.02rem 0.3rem;
    }
    .cal-cell-events {
      gap: 0.18rem;
      max-height: 38px;
      overflow: hidden;
    }
    .evt-pill {
      height: 5px;
      min-height: 0;
      padding: 0;
      border: none;
      background: currentColor;
      opacity: 0.85;
    }
    .evt-pill:hover {
      background: currentColor;
      border: none;
      opacity: 1;
    }
    .evt-title,
    .evt-meta { display: none; }
    .evt-more { display: none; }
  }
</style>
