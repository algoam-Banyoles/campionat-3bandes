<!-- src/lib/components/calendar/CalendarView.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    currentDate, 
    calendarView, 
    calendarEvents, 
    getEventsForDate,
    calendarLoading,
    calendarError,
    refreshCalendarData,
    deleteEsdeveniment
  } from '$lib/stores/calendar';
  import { isAdmin } from '$lib/stores/adminAuth';
  import CalendarControls from './CalendarControls.svelte';
  import CalendarDay from './CalendarDay.svelte';
  import EventForm from './EventForm.svelte';
  import type { CalendarEvent, RepteCalendari, PartidaCalendari } from '$lib/stores/calendar';
  import { mySociNumero } from '$lib/stores/mySoci';

  /** Si es passa, filtra events on l'usuari (numero_soci) hi participa.
   * Quan el filtre està actiu, els esdeveniments del club (type='event')
   * també s'amaguen, ja que no tenen jugadors associats. */
  export let onlyMine = false;

  let selectedDate: Date | null = null;
  let selectedEvent: CalendarEvent | null = null;
  let showEventForm = false;
  let editingEvent: any = null;
  let showDeleteConfirmation = false;
  let eventToDelete: CalendarEvent | null = null;

  /**
   * Versió filtrada de getEventsForDate que respecta `onlyMine`.
   * Quan està actiu, només es mostren events on l'usuari (numero_soci) hi participa
   * com a reptador/reptat (challenge) o jugador 1/2 (partida social).
   * Els events del club (type='event') s'amaguen sota el filtre perquè no tenen
   * un participant identificable per soci.
   */
  function getFilteredEventsForDate(date: Date): CalendarEvent[] {
    const events = getEventsForDate(date);
    if (!onlyMine || $mySociNumero == null) return events;
    const me = $mySociNumero;
    return events.filter((ev) => {
      if (ev.type === 'event') return false; // sense jugadors
      const data: any = ev.data;
      if (ev.type === 'challenge') {
        const repte = data as RepteCalendari;
        return repte.reptador_soci_numero === me || repte.reptat_soci_numero === me;
      }
      // type que pot ser 'event' amb subtype social-match (futur) o partida via subtypes
      if (data && typeof data === 'object') {
        const partida = data as PartidaCalendari;
        return partida.jugador1_soci_numero === me || partida.jugador2_soci_numero === me;
      }
      return false;
    });
  }

  // Dies de la setmana
  const weekDays = ['Dl', 'Dt', 'Dc', 'Dj', 'Dv', 'Ds', 'Dg'];

  onMount(() => {
    refreshCalendarData();
  });

  // Generar dies per vista mensual
  $: monthDays = (() => {
    if ($calendarView !== 'month') return [];
    
    const year = $currentDate.getFullYear();
    const month = $currentDate.getMonth();
    
    // Primer dia del mes
    const firstDay = new Date(year, month, 1);
    // Últim dia del mes
    const lastDay = new Date(year, month + 1, 0);
    
    // Primer dilluns de la graella (pot ser del mes anterior)
    const startDate = new Date(firstDay);
    const firstWeekday = firstDay.getDay();
    const daysBack = firstWeekday === 0 ? 6 : firstWeekday - 1; // Dilluns = 0
    startDate.setDate(firstDay.getDate() - daysBack);
    
    // Generar 42 dies (6 setmanes × 7 dies)
    const days = [];
    const currentDay = new Date(startDate);
    
    for (let i = 0; i < 42; i++) {
      days.push(new Date(currentDay));
      currentDay.setDate(currentDay.getDate() + 1);
    }
    
    return days;
  })();

  // Generar dies per vista setmanal
  $: weekDays_dates = (() => {
    if ($calendarView !== 'week') return [];
    
    const startOfWeek = new Date($currentDate);
    const day = startOfWeek.getDay();
    const diff = startOfWeek.getDate() - day + (day === 0 ? -6 : 1); // Dilluns com a primer dia
    startOfWeek.setDate(diff);
    
    const days = [];
    const currentDay = new Date(startOfWeek);
    
    for (let i = 0; i < 7; i++) {
      days.push(new Date(currentDay));
      currentDay.setDate(currentDay.getDate() + 1);
    }
    
    return days;
  })();

  // Comprovar si una data és avui
  function isToday(date: Date): boolean {
    const today = new Date();
    return date.toDateString() === today.toDateString();
  }

  // Comprovar si una data és del mes actual
  function isCurrentMonth(date: Date): boolean {
    return date.getMonth() === $currentDate.getMonth() && 
           date.getFullYear() === $currentDate.getFullYear();
  }

  // Gestors d'esdeveniments
  function handleDayClick(event: CustomEvent<{ date: Date }>) {
    selectedDate = event.detail.date;
  }

  function handleEventClick(event: CustomEvent<{ event: CalendarEvent }>) {
    selectedEvent = event.detail.event;
  }

  function closeEventModal() {
    selectedEvent = null;
  }

  function closeDayModal() {
    selectedDate = null;
  }

  function handleCreateEvent() {
    editingEvent = null;
    showEventForm = true;
  }

  function handleEditEvent(event: CalendarEvent) {
    if (event.type === 'event') {
      editingEvent = event.data;
      showEventForm = true;
    }
  }

  function closeEventForm() {
    showEventForm = false;
    editingEvent = null;
  }

  function handleDeleteEvent(event: CalendarEvent) {
    if (event.type === 'event') {
      eventToDelete = event;
      showDeleteConfirmation = true;
    }
  }

  function closeDeleteConfirmation() {
    showDeleteConfirmation = false;
    eventToDelete = null;
  }

  async function confirmDeleteEvent() {
    if (!eventToDelete?.data?.id) return;
    
    try {
      await deleteEsdeveniment(eventToDelete.data.id);
      closeDeleteConfirmation();
      closeEventModal();
    } catch (error) {
      console.error('Error eliminant esdeveniment:', error);
    }
  }
</script>

<div class="cal-view" class:is-week={$calendarView === 'week'} class:is-month={$calendarView === 'month'}>
  <!-- Controls -->
  <div class="cal-toolbar">
    <CalendarControls />

    {#if $isAdmin}
      <button
        on:click={handleCreateEvent}
        class="btn-new-event"
        title="Crear un nou esdeveniment al calendari"
      >
        <svg class="ic" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        <span>Nou esdeveniment</span>
      </button>
    {/if}
  </div>

  {#if $calendarLoading}
    <div class="cal-loading" role="status" aria-live="polite">
      <span class="editorial-eyebrow">Carregant calendari…</span>
    </div>
  {:else if $calendarError}
    {#if $calendarError.includes('iniciar sessió') || $calendarError.includes('públiques')}
      <div class="cal-banner cal-banner-info" role="status">
        <span class="editorial-eyebrow" style="color: var(--blue);">Accés restringit</span>
        <p class="cal-banner-title">Calendari amb accés restringit</p>
        <p class="cal-banner-body">{$calendarError}</p>
        <p class="cal-banner-body">
          Podeu veure els esdeveniments generals del club, però les partides programades
          dels campionats socials requereixen autenticació.
        </p>
      </div>
    {:else}
      <div class="cal-banner cal-banner-error" role="alert">
        <span class="editorial-eyebrow" style="color: var(--accent);">Error</span>
        <p class="cal-banner-body">No s'han pogut carregar els esdeveniments: {$calendarError}</p>
        <button on:click={refreshCalendarData} class="btn-retry">
          Tornar a intentar
        </button>
      </div>
    {/if}
  {:else}
    <div class="cal-grid-frame">
      <div class="cal-weekhead" role="row">
        {#each weekDays as day}
          <div class="cal-weekhead-cell" role="columnheader">{day}</div>
        {/each}
      </div>

      {#if $calendarView === 'month'}
        <div class="cal-grid">
          {#each monthDays as date}
            <CalendarDay
              {date}
              events={getFilteredEventsForDate(date)}
              isCurrentMonth={isCurrentMonth(date)}
              isToday={isToday(date)}
              isSelected={selectedDate?.toDateString() === date.toDateString()}
              on:dayClick={handleDayClick}
              on:eventClick={handleEventClick}
            />
          {/each}
        </div>
      {/if}

      {#if $calendarView === 'week'}
        <div class="cal-grid">
          {#each weekDays_dates as date}
            <CalendarDay
              {date}
              events={getFilteredEventsForDate(date)}
              isCurrentMonth={true}
              isToday={isToday(date)}
              isSelected={selectedDate?.toDateString() === date.toDateString()}
              on:dayClick={handleDayClick}
              on:eventClick={handleEventClick}
            />
          {/each}
        </div>
      {/if}
    </div>
  {/if}
</div>

<!-- Modal per detalls d'esdeveniment -->
{#if selectedEvent}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg max-w-md w-full p-6">
      <div class="flex justify-between items-start mb-4">
        <h3 class="text-lg font-semibold">{selectedEvent.title}</h3>
        <button 
          on:click={closeEventModal}
          class="text-slate-400 hover:text-slate-600"
          aria-label="Tancar modal d'esdeveniment"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      
      <div class="space-y-3">
        <div>
          <span class="text-sm font-medium text-slate-600">Data:</span>
          <span class="ml-2 text-base sm:text-lg lg:text-xl xl:text-4xl font-bold text-slate-900">{selectedEvent.start.toLocaleDateString('ca-ES', { 
            weekday: 'long', 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          })}</span>
        </div>
        
        {#if selectedEvent.description}
          <div>
            <span class="text-sm font-medium text-slate-600">Descripció:</span>
            <p class="mt-1 text-slate-700">{selectedEvent.description}</p>
          </div>
        {/if}
        
        <div>
          <span class="text-sm font-medium text-slate-600">Tipus:</span>
          <span class="ml-2 text-base sm:text-lg lg:text-xl xl:text-4xl font-bold capitalize">
            {#if selectedEvent.subtype?.includes('campionat-social')}
              Campionat Social
            {:else if selectedEvent.type === 'challenge'}
              Repte Ranking Continu
            {:else}
              Esdeveniment
            {/if}
          </span>
          {#if selectedEvent.subtype && !selectedEvent.subtype.includes('campionat-social')}
            <span class="ml-1 text-slate-500">({selectedEvent.subtype})</span>
          {/if}
        </div>
        
        <!-- Informació addicional per partides de campionats socials -->
        {#if selectedEvent.subtype?.includes('campionat-social') && selectedEvent.data}
          {#if 'taula_assignada' in selectedEvent.data && selectedEvent.data.taula_assignada}
            <div>
              <span class="text-sm font-medium text-slate-600">Taula:</span>
              <span class="ml-2">{selectedEvent.data.taula_assignada}</span>
            </div>
          {/if}
          {#if 'estat' in selectedEvent.data && selectedEvent.data.estat}
            <div>
              <span class="text-sm font-medium text-slate-600">Estat:</span>
              <span class="ml-2 capitalize">{selectedEvent.data.estat}</span>
            </div>
          {/if}
        {/if}
      </div>
      
      <div class="mt-6 flex justify-end gap-3">
        {#if $isAdmin && selectedEvent?.type === 'event'}
          <button 
            on:click={() => {
              if (selectedEvent) {
                handleEditEvent(selectedEvent);
                closeEventModal();
              }
            }}
            class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
          >
            Editar
          </button>
          <button 
            on:click={() => {
              if (selectedEvent) {
                handleDeleteEvent(selectedEvent);
              }
            }}
            class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
          >
            Eliminar
          </button>
        {/if}
        <button 
          on:click={closeEventModal}
          class="px-4 py-2 bg-slate-100 text-slate-700 rounded hover:bg-slate-200 transition-colors"
        >
          Tancar
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Modal per detalls del dia -->
{#if selectedDate}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg max-w-lg w-full p-6">
      <div class="flex justify-between items-start mb-4">
        <h3 class="text-lg font-semibold">
          {selectedDate.toLocaleDateString('ca-ES', { 
            weekday: 'long', 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric' 
          })}
        </h3>
        <button 
          on:click={closeDayModal}
          class="text-slate-400 hover:text-slate-600"
          aria-label="Tancar modal del dia"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      
      {#if getFilteredEventsForDate(selectedDate).length > 0}
        <div class="space-y-2">
          {#each getFilteredEventsForDate(selectedDate) as event}
            <button
              class="w-full text-left p-2 sm:p-3 rounded border border-slate-200 hover:bg-slate-50 transition-colors"
              on:click={() => {
                selectedEvent = event;
                selectedDate = null;
              }}
            >
              <div class="font-bold text-base sm:text-lg lg:text-xl xl:text-4xl text-slate-900">{event.title}</div>
              <div class="text-sm sm:text-base lg:text-lg xl:text-3xl text-slate-600 font-bold mt-1">
                {event.start.toLocaleTimeString('ca-ES', { hour: '2-digit', minute: '2-digit' })}
                {#if event.end}
                  - {event.end.toLocaleTimeString('ca-ES', { hour: '2-digit', minute: '2-digit' })}
                {/if}
              </div>
              {#if event.description}
                <div class="text-xs sm:text-sm lg:text-base text-slate-500 mt-2">{event.description}</div>
              {/if}
            </button>
          {/each}
        </div>
      {:else}
        <p class="text-slate-500">No hi ha esdeveniments programats per aquest dia.</p>
      {/if}
      
      <div class="mt-6 flex justify-end">
        <button 
          on:click={closeDayModal}
          class="px-4 py-2 bg-slate-100 text-slate-700 rounded hover:bg-slate-200 transition-colors"
        >
          Tancar
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Modal de confirmació d'eliminació -->
{#if showDeleteConfirmation && eventToDelete}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg max-w-md w-full p-6">
      <div class="flex items-center gap-3 mb-4">
        <div class="flex-shrink-0 w-10 h-10 bg-red-100 rounded-full flex items-center justify-center">
          <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.99-.833-2.75 0L4.064 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        <div>
          <h3 class="text-lg font-semibold text-slate-900">Confirmar eliminació</h3>
          <p class="text-sm text-slate-600">Aquesta acció no es pot desfer.</p>
        </div>
      </div>
      
      <div class="mb-6">
        <p class="text-slate-700">
          Estàs segur que vols eliminar l'esdeveniment <strong>"{eventToDelete.title}"</strong>?
        </p>
        <p class="text-sm text-slate-500 mt-2">
          Data: {eventToDelete.start.toLocaleDateString('ca-ES', { 
            weekday: 'long', 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric' 
          })}
        </p>
      </div>
      
      <div class="flex justify-end gap-3">
        <button 
          on:click={closeDeleteConfirmation}
          class="px-4 py-2 bg-slate-100 text-slate-700 rounded hover:bg-slate-200 transition-colors"
        >
          Cancel·lar
        </button>
        <button 
          on:click={confirmDeleteEvent}
          class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
          disabled={$calendarLoading}
        >
          {$calendarLoading ? 'Eliminant...' : 'Eliminar'}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Modal per crear/editar esdeveniments -->
<EventForm
  isOpen={showEventForm}
  {editingEvent}
  on:close={closeEventForm}
  on:success={closeEventForm}
/>

<style>
  .cal-view {
    width: 100%;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  .cal-toolbar {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    margin-bottom: 1rem;
  }
  @media (min-width: 640px) {
    .cal-toolbar {
      flex-direction: row;
      justify-content: space-between;
      align-items: center;
    }
    .cal-toolbar > :global(.cal-ctrl-bar) { margin-bottom: 0; flex: 1; }
  }

  .btn-new-event {
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
    padding: 0.55rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    transition: background 0.12s ease, border-color 0.12s ease;
    flex-shrink: 0;
  }
  .btn-new-event:hover {
    background: var(--accent);
    border-color: var(--accent);
  }
  .btn-new-event:focus-visible {
    outline: 2px solid var(--ink);
    outline-offset: 2px;
  }
  .btn-new-event .ic { width: 1rem; height: 1rem; }

  .cal-loading {
    padding: 3rem 1rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    text-align: center;
  }

  .cal-banner {
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    padding: 1rem 1.15rem;
    margin-bottom: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }
  .cal-banner-info { border-color: var(--blue); border-left: 3px solid var(--blue); }
  .cal-banner-error { border-color: var(--accent); border-left: 3px solid var(--accent); }
  .cal-banner-title {
    margin: 0;
    font-size: 1rem;
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.01em;
  }
  .cal-banner-body {
    margin: 0;
    font-size: 0.875rem;
    color: var(--ink-2);
    line-height: 1.5;
  }
  .btn-retry {
    align-self: flex-start;
    margin-top: 0.35rem;
    background: var(--paper-elevated);
    color: var(--ink);
    border: 1px solid var(--rule-strong);
    padding: 0.45rem 0.85rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.8125rem;
    cursor: pointer;
    min-height: 36px;
  }
  .btn-retry:hover { border-color: var(--ink); }

  .cal-grid-frame {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    overflow: hidden;
  }
  .cal-weekhead {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    background: var(--paper);
    border-bottom: 1px solid var(--rule);
  }
  .cal-weekhead-cell {
    padding: 0.55rem 0.4rem;
    text-align: center;
    font-size: 0.6875rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
  }
  @media (min-width: 640px) {
    .cal-weekhead-cell { padding: 0.7rem 0.5rem; font-size: 0.75rem; }
  }
  .cal-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
  }
  /* Eliminem el border-right de la última columna per evitar doble línia amb el frame */
  .cal-grid > :global(.cal-cell:nth-child(7n)) { border-right: 0; }
  /* Eliminem el border-bottom de l'última fila */
  .cal-grid > :global(.cal-cell:nth-last-child(-n+7)) { border-bottom: 0; }

  /* Mòbil portrait — vista setmanal stackeada (1 columna, agenda) */
  @media (max-width: 639px) {
    .cal-view.is-week .cal-weekhead { display: none; }
    .cal-view.is-week .cal-grid {
      grid-template-columns: 1fr;
    }
    /* Cel·les en stacked: tot l'amplada, sense borde dret */
    .cal-view.is-week .cal-grid :global(.cal-cell) {
      border-right: 0 !important;
      border-bottom: 1px solid var(--rule);
      min-height: 92px;
      padding: 0.65rem 0.85rem;
    }
    .cal-view.is-week .cal-grid :global(.cal-cell:last-child) {
      border-bottom: 0;
    }
    /* Mostrem el nom del dia (Dl, Dt, ...) al cap */
    .cal-view.is-week .cal-grid :global(.cal-cell-weekday) {
      display: inline;
    }
    /* Restablim pills amb text complet (sobreescriu el mode "barres" mòbil) */
    .cal-view.is-week .cal-grid :global(.cal-cell-events) {
      max-height: none;
      overflow: visible;
      gap: 0.25rem;
    }
    .cal-view.is-week .cal-grid :global(.evt-pill) {
      height: auto;
      min-height: 32px;
      padding: 0.3rem 0.5rem;
      border: 1px solid var(--rule);
      border-left: 3px solid currentColor;
      background: var(--paper);
      opacity: 1;
      font-size: 0.8125rem;
    }
    .cal-view.is-week .cal-grid :global(.evt-title),
    .cal-view.is-week .cal-grid :global(.evt-meta) {
      display: revert;
    }
    .cal-view.is-week .cal-grid :global(.evt-more) {
      display: block;
      border: 1px dashed var(--rule);
      padding: 0.15rem 0.4rem;
    }
  }
</style>