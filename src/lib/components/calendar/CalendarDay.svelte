<!-- src/lib/components/calendar/CalendarDay.svelte -->
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

  // Colors per tipus d'esdeveniment
  const eventColors = {
    challenge: {
      acceptat: 'bg-green-100 text-green-800 border-green-200',
      proposat: 'bg-yellow-100 text-yellow-800 border-yellow-200',
      jugat: 'bg-blue-100 text-blue-800 border-blue-200',
      default: 'bg-gray-100 text-gray-800 border-gray-200'
    },
    event: {
      torneig: 'bg-purple-100 text-purple-800 border-purple-200',
      social: 'bg-pink-100 text-pink-800 border-pink-200',
      manteniment: 'bg-red-100 text-red-800 border-red-200',
      general: 'bg-blue-100 text-blue-800 border-blue-200',
      default: 'bg-gray-100 text-gray-800 border-gray-200'
    }
  };

  function getEventColor(event: CalendarEvent): string {
    if (event.type === 'challenge') {
      return eventColors.challenge[event.subtype as keyof typeof eventColors.challenge] || eventColors.challenge.default;
    } else {
      return eventColors.event[event.subtype as keyof typeof eventColors.event] || eventColors.event.default;
    }
  }

  function handleDayClick() {
    dispatch('dayClick', { date });
  }

  function handleEventClick(event: CalendarEvent, e: MouseEvent) {
    e.stopPropagation();
    dispatch('eventClick', { event });
  }

  // Limitar número d'esdeveniments visibles
  $: visibleEvents = events.slice(0, 3);
  $: moreEventsCount = events.length - visibleEvents.length;
</script>

<div
  class="min-h-[120px] p-2 border border-slate-200 cursor-pointer transition-colors hover:bg-slate-50
    {isCurrentMonth ? 'bg-white' : 'bg-slate-50 text-slate-400'}
    {isToday ? 'ring-2 ring-blue-500 bg-blue-50' : ''}
    {isSelected ? 'ring-2 ring-blue-300' : ''}"
  on:click={handleDayClick}
  role="button"
  tabindex="0"
  on:keydown={(e) => e.key === 'Enter' && handleDayClick()}
>
  <!-- Número del dia -->
  <div class="flex justify-between items-start mb-2">
    <span class="text-sm font-semibold {isToday ? 'text-blue-600' : ''}">
      {date.getDate()}
    </span>
    {#if events.length > 0}
      <span class="text-xs text-slate-500">
        {events.length}
      </span>
    {/if}
  </div>

  <!-- Esdeveniments -->
  <div class="space-y-1">
    {#each visibleEvents as event (event.id)}
      <button
        class="w-full text-left text-xs px-2 py-1 rounded border truncate {getEventColor(event)}"
        on:click={(e) => handleEventClick(event, e)}
        title={event.description || event.title}
      >
        {#if event.type === 'challenge'}
          <!-- Icona per reptes -->
          <span class="inline-block w-2 h-2 rounded-full bg-current mr-1"></span>
        {:else}
          <!-- Icona per esdeveniments -->
          <span class="inline-block w-2 h-2 rounded bg-current mr-1"></span>
        {/if}
        {event.title}
      </button>
    {/each}

    {#if moreEventsCount > 0}
      <div class="text-xs text-slate-500 px-2">
        +{moreEventsCount} més
      </div>
    {/if}
  </div>
</div>

<style>
  /* Ensure text truncation works properly */
  button {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>