<!-- src/lib/components/calendar/CalendarControls.svelte -->
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

  // Format del mes actual
  $: monthYear = $currentDate.toLocaleDateString('ca-ES', { 
    month: 'long', 
    year: 'numeric' 
  });

  // Format de la setmana actual
  $: weekRange = (() => {
    const startOfWeek = new Date($currentDate);
    const day = startOfWeek.getDay();
    const diff = startOfWeek.getDate() - day + (day === 0 ? -6 : 1); // Dilluns com a primer dia
    startOfWeek.setDate(diff);
    
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);
    
    return `${startOfWeek.getDate()} - ${endOfWeek.getDate()} ${endOfWeek.toLocaleDateString('ca-ES', { month: 'long', year: 'numeric' })}`;
  })();

  function handlePrevious() {
    if ($calendarView === 'month') {
      navigateMonth(-1);
    } else {
      navigateWeek(-1);
    }
  }

  function handleNext() {
    if ($calendarView === 'month') {
      navigateMonth(1);
    } else {
      navigateWeek(1);
    }
  }

  function handleViewChange(view: CalendarView) {
    setCalendarView(view);
  }
</script>

<div class="flex flex-col sm:flex-row items-center justify-between gap-4 mb-6">
  <!-- Navegació temporal -->
  <div class="flex items-center gap-4">
    <button
      on:click={handlePrevious}
      class="p-2 rounded-lg border border-slate-300 hover:bg-slate-50 transition-colors"
      title="Anterior"
      aria-label="Període anterior"
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
      </svg>
    </button>
    
    <div class="text-center min-w-[200px]">
      <h2 class="text-xl font-semibold capitalize">
        {$calendarView === 'month' ? monthYear : weekRange}
      </h2>
    </div>
    
    <button
      on:click={handleNext}
      class="p-2 rounded-lg border border-slate-300 hover:bg-slate-50 transition-colors"
      title="Següent"
      aria-label="Període següent"
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
      </svg>
    </button>
  </div>

  <!-- Controls -->
  <div class="flex items-center gap-2">
    <!-- Botó Avui -->
    <button
      on:click={navigateToToday}
      class="px-3 py-2 text-sm rounded-lg border border-slate-300 hover:bg-slate-50 transition-colors"
    >
      Avui
    </button>

    <!-- Toggle vista -->
    <div class="flex rounded-lg border border-slate-300 overflow-hidden">
      <button
        on:click={() => handleViewChange('month')}
        class="px-3 py-2 text-sm transition-colors {$calendarView === 'month' 
          ? 'bg-blue-500 text-white' 
          : 'bg-white text-slate-700 hover:bg-slate-50'}"
      >
        Mes
      </button>
      <button
        on:click={() => handleViewChange('week')}
        class="px-3 py-2 text-sm transition-colors {$calendarView === 'week' 
          ? 'bg-blue-500 text-white' 
          : 'bg-white text-slate-700 hover:bg-slate-50'}"
      >
        Setmana
      </button>
    </div>
  </div>
</div>