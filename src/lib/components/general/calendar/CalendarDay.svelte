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

  // Colors per tipus d'esdeveniment i categoria
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
    },
    // Colors per categories de campionats socials
    categoria: {
      'A': 'bg-red-100 text-red-800 border-red-200',
      'B': 'bg-orange-100 text-orange-800 border-orange-200', 
      'C': 'bg-amber-100 text-amber-800 border-amber-200',
      'D': 'bg-yellow-100 text-yellow-800 border-yellow-200',
      'E': 'bg-lime-100 text-lime-800 border-lime-200',
      'F': 'bg-green-100 text-green-800 border-green-200',
      'G': 'bg-emerald-100 text-emerald-800 border-emerald-200',
      'H': 'bg-teal-100 text-teal-800 border-teal-200',
      'I': 'bg-cyan-100 text-cyan-800 border-cyan-200',
      'J': 'bg-sky-100 text-sky-800 border-sky-200',
      'K': 'bg-blue-100 text-blue-800 border-blue-200',
      'L': 'bg-indigo-100 text-indigo-800 border-indigo-200',
      'M': 'bg-violet-100 text-violet-800 border-violet-200',
      'N': 'bg-purple-100 text-purple-800 border-purple-200',
      'O': 'bg-fuchsia-100 text-fuchsia-800 border-fuchsia-200',
      'P': 'bg-pink-100 text-pink-800 border-pink-200',
      'Q': 'bg-rose-100 text-rose-800 border-rose-200',
      // També per noms de categories més llargs
      'Primera': 'bg-red-100 text-red-800 border-red-200',
      'Segona': 'bg-orange-100 text-orange-800 border-orange-200',
      'Tercera': 'bg-yellow-100 text-yellow-800 border-yellow-200',
      'Quarta': 'bg-green-100 text-green-800 border-green-200',
      'Cinquena': 'bg-blue-100 text-blue-800 border-blue-200',
      'Sisena': 'bg-purple-100 text-purple-800 border-purple-200',
      default: 'bg-gray-100 text-gray-800 border-gray-200'
    }
  };

  function getEventColor(event: CalendarEvent): string {
    // Si és un partit de campionat social, usar color per categoria
    if (event.type === 'challenge' && event.subtype?.startsWith('campionat-social')) {
      // Type guard to check if data has categoria_nom property
      const hasCategoriaNom = (data: any): data is { categoria_nom: string } => {
        return data && typeof data.categoria_nom === 'string';
      };
      
      if (hasCategoriaNom(event.data)) {
        const categoria = event.data.categoria_nom;
        // Primer provar amb la categoria exacta
        if (eventColors.categoria[categoria as keyof typeof eventColors.categoria]) {
          return eventColors.categoria[categoria as keyof typeof eventColors.categoria];
        }
        
        // Si no trobem la categoria, generar un color basat en un hash del nom
        const hash = categoria.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
        const colors = [
          'bg-red-100 text-red-800 border-red-200',
          'bg-orange-100 text-orange-800 border-orange-200',
          'bg-yellow-100 text-yellow-800 border-yellow-200',
          'bg-green-100 text-green-800 border-green-200',
          'bg-blue-100 text-blue-800 border-blue-200',
          'bg-purple-100 text-purple-800 border-purple-200',
          'bg-pink-100 text-pink-800 border-pink-200',
          'bg-indigo-100 text-indigo-800 border-indigo-200',
          'bg-teal-100 text-teal-800 border-teal-200',
          'bg-cyan-100 text-cyan-800 border-cyan-200'
        ];
        return colors[hash % colors.length];
      }
    }
    
    // Altres reptes
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

  // Mostrar més esdeveniments per dia
  $: visibleEvents = events.slice(0, 6);
  $: moreEventsCount = events.length - visibleEvents.length;
</script>

<div
  class="min-h-[180px] p-2 border border-slate-200 cursor-pointer transition-colors hover:bg-slate-50
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
  <div class="space-y-0.5">
    {#each visibleEvents as event (event.id)}
      <button
        class="w-full text-left text-xs px-1 py-0.5 rounded border truncate leading-tight {getEventColor(event)}"
        on:click={(e) => handleEventClick(event, e)}
        title={event.description || event.title}
      >
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