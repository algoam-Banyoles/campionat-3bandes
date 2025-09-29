<script lang="ts">
  import { onMount } from 'svelte';
  import { refreshCalendarData, getEventsForDate, calendarLoading } from '$lib/stores/calendar';

  let todayEvents: any[] = [];
  let loading = true;

  onMount(async () => {
    loading = true;
    try {
      await refreshCalendarData();
      const today = new Date();
      todayEvents = getEventsForDate(today);
      console.log('📅 Esdeveniments d\'avui carregats:', todayEvents.length);
    } catch (error) {
      console.error('❌ Error carregant esdeveniments:', error);
    } finally {
      loading = false;
    }
  });

  function formatTime(date: Date): string {
    return date.toLocaleTimeString('ca-ES', { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div class="max-w-4xl mx-auto p-6 space-y-8">
  <!-- Capçalera de benvinguda -->
  <div class="text-center mb-8">
    <h1 class="text-3xl font-bold text-gray-900 mb-2">Secció de Billar del Foment Martinenc</h1>
    <p class="text-lg text-gray-600">Informació general i calendari d'activitats</p>
  </div>

  <!-- Horaris i Normativa -->
  <div class="bg-white rounded-lg shadow-md p-6">
    <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center">
      <svg class="w-6 h-6 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      Horaris i Normativa
    </h2>
    
    <div class="grid md:grid-cols-2 gap-6">
      <!-- Horari d'obertura -->
      <div class="bg-blue-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-blue-900 mb-3 flex items-center">
          🕒 Horari d'obertura de la Secció
        </h3>
        <div class="space-y-2 text-sm text-blue-800">
          <p><strong>Dilluns, dimecres, dijous, dissabte i diumenge:</strong> 9:00 – 21:30</p>
          <p><strong>Dimarts i divendres:</strong> 10:30 – 21:30</p>
          <div class="mt-3 text-xs text-blue-700 bg-blue-100 p-2 rounded">
            <p>L'horari d'obertura pot canviar en funció dels horaris d'obertura del Bar del Foment.</p>
            <p class="mt-1">L'horari d'atenció al públic del FOMENT és de <strong>DILLUNS A DIVENDRES de 9:00 A 13:00 i de 16:00 A 20:00</strong>.</p>
            <p class="mt-1">Les seccions poden tenir activitat fora d'aquest horari si el bar està obert, excepte <strong>AGOST i FESTIUS</strong>, quan el FOMENT resta oficialment tancat.</p>
            <p class="mt-1">La secció romandrà tancada els dies de <strong>TANCAMENT OFICIAL</strong> del FOMENT.</p>
          </div>
        </div>
      </div>

      <!-- Normes obligatòries -->
      <div class="bg-green-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-green-900 mb-3">
          🚨 OBLIGATORI
        </h3>
        <p class="text-sm text-green-800">
          Netejar el billar i les boles abans de començar cada partida amb el material que la Secció posa a disposició de tots els socis.
        </p>
      </div>
    </div>

    <!-- Prohibicions -->
    <div class="bg-red-50 rounded-lg p-4 mt-6">
      <h3 class="text-lg font-semibold text-red-900 mb-3">
        🚫 PROHIBIT
      </h3>
      <ul class="list-disc list-inside space-y-1 text-sm text-red-800">
        <li>Jugar a fantasia</li>
        <li>Menjar mentre s'està jugant</li>
        <li>Posar begudes sobre cap element del billar</li>
      </ul>
    </div>

    <!-- Normes de joc -->
    <div class="grid md:grid-cols-2 gap-6 mt-6">
      <!-- Inscripció -->
      <div class="bg-yellow-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-yellow-900 mb-3">
          📝 Inscripció a les partides
        </h3>
        <ul class="list-disc list-inside space-y-1 text-sm text-yellow-800">
          <li>Apunta't a la pissarra única de <strong>PARTIDES SOCIALS</strong></li>
          <li>Els companys no cal que s'apuntin; si ho fan, que sigui al costat del primer jugador</li>
        </ul>
      </div>

      <!-- Assignació de taula -->
      <div class="bg-purple-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-purple-900 mb-3">
          🗂 Assignació de taula
        </h3>
        <ul class="list-disc list-inside space-y-1 text-sm text-purple-800">
          <li>Quan hi hagi una taula lliure, ratlla el teu nom i juga</li>
          <li>Si vols una taula concreta ocupada, passa el torn fins que s'alliberi</li>
        </ul>
      </div>

      <!-- Temps de joc -->
      <div class="bg-orange-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-orange-900 mb-3">
          ⏳ Temps de joc
        </h3>
        <ul class="list-disc list-inside space-y-1 text-sm text-orange-800">
          <li><strong>Màxim 1 hora</strong> per partida (sol o en grup)</li>
          <li><strong>PROHIBIT</strong> posar monedes per allargar el temps, encara que hi hagi taules lliures</li>
        </ul>
      </div>

      <!-- Tornar a jugar -->
      <div class="bg-indigo-50 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-indigo-900 mb-3">
          � Tornar a jugar
        </h3>
        <p class="text-sm text-indigo-800">
          Només pots repetir si no hi ha ningú apuntat i hi ha una taula lliure.
        </p>
      </div>
    </div>
  </div>

  <!-- Activitats d'avui -->
  <div class="bg-white rounded-lg shadow-md p-6">
    <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center">
      <svg class="w-6 h-6 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      Activitats d'avui
    </h2>
    
    <div class="bg-gray-50 rounded-lg p-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-700">Avui, {new Date().toLocaleDateString('ca-ES', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</h3>
        <a href="/general/calendari" class="text-blue-600 hover:text-blue-800 text-sm font-medium">Veure calendari complet →</a>
      </div>
      
      <div class="space-y-3">
        {#if loading}
          <div class="bg-white rounded-lg p-4 border border-gray-200">
            <div class="flex items-center text-gray-600">
              <svg class="w-5 h-5 mr-2 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span class="text-sm">Carregant activitats...</span>
            </div>
          </div>
        {:else if todayEvents.length === 0}
          <div class="bg-white rounded-lg p-4 border border-gray-200">
            <div class="flex items-center text-gray-600">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span class="text-sm">No hi ha activitats programades per avui</span>
            </div>
          </div>
        {:else}
          {#each todayEvents as event}
            <div class="bg-white rounded-lg p-4 border border-gray-200">
              <div class="flex items-center justify-between">
                <div class="flex items-center">
                  {#if event.type === 'challenge' && event.subtype?.startsWith('campionat-social')}
                    <svg class="w-5 h-5 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
                    </svg>
                  {:else}
                    <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                    </svg>
                  {/if}
                  <div>
                    <p class="font-medium text-gray-900">{event.title}</p>
                    {#if event.description}
                      <p class="text-sm text-gray-600">{event.description}</p>
                    {/if}
                  </div>
                </div>
                <div class="text-sm text-gray-500">
                  {formatTime(event.start)}
                </div>
              </div>
            </div>
          {/each}
        {/if}
        
        <div class="text-center text-sm text-gray-500 mt-4">
          <p>📅 Consulta el calendari complet per veure tornejos, competicions i esdeveniments</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Accés ràpid -->
  <div class="bg-gray-50 rounded-lg p-6">
    <h2 class="text-xl font-semibold text-gray-900 mb-4">Accés ràpid</h2>
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <a href="/campionat-continu/ranking" class="bg-white rounded-lg p-4 text-center hover:shadow-md transition-shadow">
        <div class="text-2xl mb-2">🏆</div>
        <div class="text-sm font-medium text-gray-700">Campionat Continu</div>
      </a>
      <a href="/campionats-socials" class="bg-white rounded-lg p-4 text-center hover:shadow-md transition-shadow">
        <div class="text-2xl mb-2">👥</div>
        <div class="text-sm font-medium text-gray-700">Lligues Socials</div>
      </a>
      <a href="/admin" class="bg-white rounded-lg p-4 text-center hover:shadow-md transition-shadow">
        <div class="text-2xl mb-2">⚙️</div>
        <div class="text-sm font-medium text-gray-700">Administració</div>
      </a>
      <a href="/help" class="bg-white rounded-lg p-4 text-center hover:shadow-md transition-shadow">
        <div class="text-2xl mb-2">❓</div>
        <div class="text-sm font-medium text-gray-700">Ajuda</div>
      </a>
    </div>
  </div>
</div>
