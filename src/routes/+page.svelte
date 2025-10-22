<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { refreshCalendarData, getEventsForDate } from '$lib/stores/calendar';

  let upcomingEvents: any[] = [];
  let loading = true;

  // Dynamic content variables
  let mainContent = { title: '', content: '' };
  let horarisContent = { title: '', content: '' };
  let normesObligatories = { title: '', content: '' };
  let prohibicions = { title: '', content: '' };
  let normesInscripcio = { title: '', content: '' };
  let normesAssignacio = { title: '', content: '' };
  let normesTemps = { title: '', content: '' };
  let normesRepetir = { title: '', content: '' };
  let serveisSoci = { title: '', content: '' };

  onMount(async () => {
    loading = true;
    try {
      await refreshCalendarData();
      await loadPageContent();

      // Obtenir esdeveniments d'avui i demà
      const today = new Date();
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const todayEvents = getEventsForDate(today);
      const tomorrowEvents = getEventsForDate(tomorrow);

      // Combinar i marcar cada esdeveniment amb la seva data
      upcomingEvents = [
        ...todayEvents.map(e => ({ ...e, isToday: true })),
        ...tomorrowEvents.map(e => ({ ...e, isToday: false }))
      ];

      console.log('📅 Properes activitats carregades:', upcomingEvents.length, '(avui:', todayEvents.length, ', demà:', tomorrowEvents.length, ')');
    } catch (error) {
      console.error('❌ Error carregant esdeveniments:', error);
    } finally {
      loading = false;
    }
  });

  async function loadPageContent() {
    try {
      const { data, error } = await supabase
        .from('page_content')
        .select('*')
        .in('page_key', [
          'home_main', 'horaris', 'normes_obligatories', 'prohibicions',
          'normes_inscripcio', 'normes_assignacio', 'normes_temps',
          'normes_repetir', 'serveis_soci'
        ]);

      if (error) throw error;

      data?.forEach((item) => {
        const content = { title: item.title || '', content: item.content || '' };
        switch (item.page_key) {
          case 'home_main': mainContent = content; break;
          case 'horaris': horarisContent = content; break;
          case 'normes_obligatories': normesObligatories = content; break;
          case 'prohibicions': prohibicions = content; break;
          case 'normes_inscripcio': normesInscripcio = content; break;
          case 'normes_assignacio': normesAssignacio = content; break;
          case 'normes_temps': normesTemps = content; break;
          case 'normes_repetir': normesRepetir = content; break;
          case 'serveis_soci': serveisSoci = content; break;
        }
      });
    } catch (error) {
      console.error('❌ Error carregant contingut de pàgina:', error);
    }
  }

  function formatTime(date: Date): string {
    return date.toLocaleTimeString('ca-ES', { hour: '2-digit', minute: '2-digit' });
  }
</script>


<div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6 lg:space-y-8">
  <!-- Capçalera de benvinguda -->
  {#if mainContent.title || mainContent.content}
    <div class="text-center mb-6 lg:mb-8">
      {#if mainContent.title}
        <h1 class="text-xl sm:text-2xl md:text-3xl lg:text-4xl font-bold text-gray-900 mb-2 px-2 leading-tight">{mainContent.title}</h1>
      {/if}
      {#if mainContent.content}
        <div class="text-sm sm:text-base lg:text-lg text-gray-600 px-2 prose prose-sm max-w-none">{@html mainContent.content}</div>
      {/if}
    </div>
  {:else}
    <div class="text-center mb-6 lg:mb-8">
      <h1 class="text-xl sm:text-2xl md:text-3xl lg:text-4xl font-bold text-gray-900 mb-2 px-2 leading-tight">Secció de Billar del Foment Martinenc</h1>
      <p class="text-sm sm:text-base lg:text-lg text-gray-600 px-2">Informació general i calendari d'activitats</p>
    </div>
  {/if}

  <!-- Properes activitats -->
  <div class="bg-white rounded-lg shadow-md p-4 sm:p-6">
    <h2 class="text-lg sm:text-xl lg:text-2xl font-bold text-gray-900 mb-4 sm:mb-6 flex items-center">
      <svg class="w-5 h-5 sm:w-6 sm:h-6 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      Properes activitats
    </h2>

    <div class="bg-gray-50 rounded-lg p-4 sm:p-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-4 gap-2">
        <h3 class="text-sm sm:text-base lg:text-lg font-semibold text-gray-700">Avui i demà</h3>
        <a href="/general/calendari" class="text-blue-600 hover:text-blue-800 text-xs sm:text-sm font-medium whitespace-nowrap">→ Veure calendari complet</a>
      </div>

      <div class="space-y-3">
        {#if loading}
          <div class="bg-white rounded-lg p-4 sm:p-6 border border-gray-200">
            <div class="flex items-center text-gray-600">
              <svg class="w-4 h-4 sm:w-5 sm:h-5 mr-2 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span class="text-xs sm:text-sm">Carregant activitats...</span>
            </div>
          </div>
        {:else if upcomingEvents.length === 0}
          <div class="bg-white rounded-lg p-4 sm:p-6 border border-gray-200 text-center">
            <svg class="w-8 h-8 sm:w-10 sm:h-10 mx-auto text-gray-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
            </svg>
            <h4 class="text-sm sm:text-base font-medium text-gray-900 mb-1">No hi ha activitats programades</h4>
            <p class="text-xs sm:text-sm text-gray-500">Consulta el calendari complet per veure pròximes activitats</p>
          </div>
        {:else}
          {#each upcomingEvents as event}
            <div class="bg-white rounded-lg p-3 sm:p-4 border border-gray-200">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                <div class="flex items-start gap-2 flex-1 min-w-0">
                  {#if event.type === 'challenge' && event.subtype?.startsWith('campionat-social')}
                    <svg class="w-4 h-4 sm:w-5 sm:h-5 mt-0.5 text-green-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
                    </svg>
                  {:else}
                    <svg class="w-4 h-4 sm:w-5 sm:h-5 mt-0.5 text-blue-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                    </svg>
                  {/if}
                  <div class="flex-1 min-w-0">
                    <p class="text-sm sm:text-base font-medium text-gray-900 truncate">{event.title}</p>
                    <p class="text-xs text-gray-500 mt-0.5">
                      {event.isToday ? 'Avui' : 'Demà'}
                    </p>
                  </div>
                </div>
                <div class="text-xs sm:text-sm text-gray-500 font-medium whitespace-nowrap">
                  {formatTime(event.start)}
                </div>
              </div>
            </div>
          {/each}
        {/if}

        <div class="text-center text-xs sm:text-sm text-gray-500 mt-4 px-2">
          <p>📅 Consulta el calendari complet per veure tornejos, competicions i esdeveniments</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Horaris i Normativa -->
  <div class="bg-white rounded-lg shadow-md p-4 sm:p-6">
    <h2 class="text-lg sm:text-xl lg:text-2xl font-bold text-gray-900 mb-4 sm:mb-6 flex items-center">
      <svg class="w-5 h-5 sm:w-6 sm:h-6 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      Horaris i Normativa
    </h2>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
      <!-- Horari d'obertura -->
      <div class="bg-blue-50 rounded-lg p-3 sm:p-4">
        <h3 class="text-sm sm:text-base lg:text-lg font-semibold text-blue-900 mb-2 sm:mb-3 flex items-center">
          🕒 {horarisContent.title || "Horari d'obertura de la Secció"}
        </h3>
        {#if horarisContent.content}
          <div class="space-y-2 text-xs sm:text-sm text-blue-800 prose prose-sm max-w-none prose-p:my-1 prose-strong:text-blue-900">{@html horarisContent.content}</div>
        {:else}
          <div class="space-y-2 text-xs sm:text-sm text-blue-800">
            <p><strong>Dilluns, dimecres, dijous, dissabte i diumenge:</strong> 9:00 – 21:30</p>
            <p><strong>Dimarts i divendres:</strong> 10:30 – 21:30</p>
            <div class="mt-3 text-xs text-blue-700 bg-blue-100 p-2 rounded">
              <p>L'horari d'obertura pot canviar en funció dels horaris d'obertura del Bar del Foment.</p>
              <p class="mt-1">L'horari d'atenció al públic del FOMENT és de <strong>DILLUNS A DIVENDRES de 9:00 A 13:00 i de 16:00 A 20:00</strong>.</p>
              <p class="mt-1">Les seccions poden tenir activitat fora d'aquest horari si el bar està obert, excepte <strong>AGOST i FESTIUS</strong>, quan el FOMENT resta oficialment tancat.</p>
              <p class="mt-1">La secció romandrà tancada els dies de <strong>TANCAMENT OFICIAL</strong> del FOMENT.</p>
            </div>
          </div>
        {/if}
      </div>

      <!-- Normes obligatòries -->
      <div class="bg-green-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-green-900 mb-3">
          🚨 {normesObligatories.title || 'OBLIGATORI'}
        </h3>
        {#if normesObligatories.content}
          <div class="text-sm text-green-800 prose prose-sm max-w-none prose-p:my-1">{@html normesObligatories.content}</div>
        {:else}
          <p class="text-sm text-green-800">
            Netejar el billar i les boles abans de començar cada partida amb el material que la Secció posa a disposició de tots els socis.
          </p>
        {/if}
      </div>
    </div>

    <!-- Prohibicions -->
    <div class="bg-red-50 rounded-lg p-4 mt-6">
      <h3 class="text-lg font-semibold text-red-900 mb-3">
        🚫 {prohibicions.title || 'PROHIBIT'}
      </h3>
      {#if prohibicions.content}
        <div class="text-sm text-red-800 prose prose-sm max-w-none prose-ul:my-1 prose-li:my-0.5">{@html prohibicions.content}</div>
      {:else}
        <ul class="list-disc list-inside space-y-1 text-sm text-red-800">
          <li>Jugar a fantasia</li>
          <li>Menjar mentre s'està jugant</li>
          <li>Posar begudes sobre cap element del billar</li>
        </ul>
      {/if}
    </div>

    <!-- Normes de joc -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 sm:gap-6 mt-4 sm:mt-6">
      <!-- Inscripció -->
      <div class="bg-yellow-50 rounded-lg p-3 sm:p-4">
        <h3 class="text-base sm:text-lg font-semibold text-yellow-900 mb-2 sm:mb-3">
          📝 {normesInscripcio.title || 'Inscripció a les partides'}
        </h3>
        {#if normesInscripcio.content}
          <div class="text-sm text-yellow-800 prose prose-sm max-w-none prose-ul:my-1 prose-li:my-0.5 prose-strong:text-yellow-900">{@html normesInscripcio.content}</div>
        {:else}
          <ul class="list-disc list-inside space-y-1 text-sm text-yellow-800">
            <li>Apunta't a la pissarra única de <strong>PARTIDES SOCIALS</strong></li>
            <li>Els companys no cal que s'apuntin; si ho fan, que sigui al costat del primer jugador</li>
          </ul>
        {/if}
      </div>

      <!-- Assignació de taula -->
      <div class="bg-purple-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-purple-900 mb-3">
          🗂 {normesAssignacio.title || 'Assignació de taula'}
        </h3>
        {#if normesAssignacio.content}
          <div class="text-sm text-purple-800 prose prose-sm max-w-none prose-ul:my-1 prose-li:my-0.5">{@html normesAssignacio.content}</div>
        {:else}
          <ul class="list-disc list-inside space-y-1 text-sm text-purple-800">
            <li>Quan hi hagi una taula lliure, ratlla el teu nom i juga</li>
            <li>Si vols una taula concreta ocupada, passa el torn fins que s'alliberi</li>
          </ul>
        {/if}
      </div>

      <!-- Temps de joc -->
      <div class="bg-orange-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-orange-900 mb-3">
          ⏳ {normesTemps.title || 'Temps de joc'}
        </h3>
        {#if normesTemps.content}
          <div class="text-sm text-orange-800 prose prose-sm max-w-none prose-ul:my-1 prose-li:my-0.5 prose-strong:text-orange-900">{@html normesTemps.content}</div>
        {:else}
          <ul class="list-disc list-inside space-y-1 text-sm text-orange-800">
            <li><strong>Màxim 1 hora</strong> per partida (sol o en grup)</li>
            <li><strong>PROHIBIT</strong> posar monedes per allargar el temps, encara que hi hagi taules lliures</li>
          </ul>
        {/if}
      </div>

      <!-- Tornar a jugar -->
      <div class="bg-indigo-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-indigo-900 mb-3">
          🔄 {normesRepetir.title || 'Tornar a jugar'}
        </h3>
        {#if normesRepetir.content}
          <div class="text-sm text-indigo-800 prose prose-sm max-w-none prose-p:my-1">{@html normesRepetir.content}</div>
        {:else}
          <p class="text-sm text-indigo-800">
            Només pots repetir si no hi ha ningú apuntat i hi ha una taula lliure.
          </p>
        {/if}
      </div>
    </div>
  </div>

  <!-- Serveis al Soci -->
  <div class="bg-white rounded-lg shadow-md p-4 sm:p-6">
    <h2 class="text-lg sm:text-xl lg:text-2xl font-bold text-gray-900 mb-4 sm:mb-6 flex items-center">
      <svg class="w-5 h-5 sm:w-6 sm:h-6 mr-2 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
      </svg>
      {serveisSoci.title || 'Serveis al Soci'}
    </h2>

    <div class="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-lg p-4 sm:p-6">
      {#if serveisSoci.content}
        <div class="prose prose-sm sm:prose max-w-none prose-headings:text-indigo-900 prose-p:text-gray-700 prose-ul:text-gray-700 prose-li:text-gray-700">{@html serveisSoci.content}</div>
      {:else}
        <div class="text-center py-6">
          <svg class="w-12 h-12 mx-auto text-indigo-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
          </svg>
          <p class="text-sm sm:text-base text-gray-600">Contingut en preparació</p>
          <p class="text-xs sm:text-sm text-gray-500 mt-2">Aviat trobaràs aquí informació sobre els serveis disponibles per als socis</p>
        </div>
      {/if}
    </div>
  </div>

  <!-- Accés ràpid -->
  <div class="bg-gray-50 rounded-lg p-4 sm:p-6">
    <h2 class="text-lg sm:text-xl font-semibold text-gray-900 mb-3 sm:mb-4">Accés ràpid</h2>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
      <a href="/campionat-continu/ranking" class="bg-white rounded-lg p-3 sm:p-4 text-center hover:shadow-md transition-shadow">
        <div class="text-xl sm:text-2xl mb-2">🏆</div>
        <div class="text-sm sm:text-base font-medium text-gray-700">Campionat Continu</div>
      </a>
      <a href="/campionats-socials" class="bg-white rounded-lg p-3 sm:p-4 text-center hover:shadow-md transition-shadow">
        <div class="text-xl sm:text-2xl mb-2">👥</div>
        <div class="text-sm sm:text-base font-medium text-gray-700">Campionats Socials</div>
      </a>
    </div>
  </div>
</div>
