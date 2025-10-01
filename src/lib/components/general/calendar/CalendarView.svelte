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
  import type { CalendarEvent } from '$lib/stores/calendar';

  let selectedDate: Date | null = null;
  let selectedEvent: CalendarEvent | null = null;
  let showEventForm = false;
  let editingEvent: any = null;
  let showDeleteConfirmation = false;
  let eventToDelete: CalendarEvent | null = null;

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

<div class="max-w-6xl mx-auto">
  <!-- Controls -->
  <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
    <CalendarControls />
    
    {#if $isAdmin}
      <button
        on:click={handleCreateEvent}
        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Nou Esdeveniment
      </button>
    {/if}
  </div>

  <!-- Loading state -->
  {#if $calendarLoading}
    <div class="flex justify-center items-center h-64">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
    </div>
  {:else if $calendarError}
    <!-- Check if this is an authentication-related error -->
    {#if $calendarError.includes('iniciar sessió') || $calendarError.includes('públiques')}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
        <div class="flex items-start gap-3">
          <svg class="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div>
            <p class="text-blue-700 font-medium">Calendari amb accés restringit</p>
            <p class="text-blue-600 text-sm mt-1">{$calendarError}</p>
            <p class="text-blue-600 text-sm mt-2">
              Podeu veure els esdeveniments generals del club, però les partides programades dels campionats socials requereixen autenticació.
            </p>
          </div>
        </div>
      </div>
    {:else}
      <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
        <p class="text-red-700">Error carregant esdeveniments: {$calendarError}</p>
        <button 
          on:click={refreshCalendarData}
          class="mt-2 px-3 py-1 bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors"
        >
          Tornar a intentar
        </button>
      </div>
    {/if}
  {:else}
    
    <!-- Calendar Grid -->
    <div class="bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden">
      <!-- Header amb dies de la setmana -->
      <div class="grid grid-cols-7 bg-slate-50 border-b border-slate-200">
        {#each weekDays as day}
          <div class="p-2 sm:p-3 text-center text-xs sm:text-sm font-semibold text-slate-600">
            {day}
          </div>
        {/each}
      </div>

      <!-- Vista mensual -->
      {#if $calendarView === 'month'}
        <div class="grid grid-cols-7">
          {#each monthDays as date}
            <CalendarDay 
              {date}
              events={getEventsForDate(date)}
              isCurrentMonth={isCurrentMonth(date)}
              isToday={isToday(date)}
              isSelected={selectedDate?.toDateString() === date.toDateString()}
              on:dayClick={handleDayClick}
              on:eventClick={handleEventClick}
            />
          {/each}
        </div>
      {/if}

      <!-- Vista setmanal -->
      {#if $calendarView === 'week'}
        <div class="grid grid-cols-7">
          {#each weekDays_dates as date}
            <CalendarDay 
              {date}
              events={getEventsForDate(date)}
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
      
      {#if getEventsForDate(selectedDate).length > 0}
        <div class="space-y-2">
          {#each getEventsForDate(selectedDate) as event}
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