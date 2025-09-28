<script lang="ts">
  import CalendarView from '$lib/components/general/calendar/CalendarView.svelte';
</script>

<svelte:head>
  <title>Calendari - Campionat 3 Bandes</title>
  <meta name="description" content="Calendari d'esdeveniments i reptes programats del campionat de billar a 3 bandes" />
</svelte:head>

<div class="container mx-auto px-4 py-8">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-slate-900 mb-2">Calendari General</h1>
    <p class="text-slate-600">
      Tots els esdeveniments: campionats socials, reptes del ranking continu, esdeveniments del club i activitats programades
    </p>
  </div>

  <CalendarView />
</div>
