<script lang="ts">
  import { supabase } from '$lib/supabaseClient';

  let selectedModality = 'tres_bandes';
  let loading = false;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const modalityMapping = {
    'tres_bandes': '3 BANDES',
    'lliure': 'LLIURE',
    'banda': 'BANDA'
  };

  async function generatePrintView() {
    loading = true;
    console.log('Iniciant generació de llistat per modalitat:', selectedModality);
    
    try {
      // Calcular les últimes dues temporades
      const currentYear = new Date().getFullYear();
      const lastSeasonYear = currentYear; // Temporada actual: 2024-2025 = any 2025
      const previousSeasonYear = currentYear - 1; // Temporada anterior: 2023-2024 = any 2024

      const historialModality = modalityMapping[selectedModality];
      console.log('Buscant mitjanes per:', historialModality);

      // Carregar socis actius i mitjanes EN PARAL·LEL
      console.log('Iniciant queries...');
      
      // Primer carregar els socis actius
      const { data: socisData, error: socisError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .eq('de_baixa', false)
        .order('cognoms', { ascending: true })
        .order('nom', { ascending: true });

      if (socisError) {
        console.error('Error carregant socis:', socisError);
        throw socisError;
      }
      if (!socisData || socisData.length === 0) {
        alert('No s\'han trobat socis actius');
        loading = false;
        return;
      }

      console.log(`Socis carregats: ${socisData.length}`);

      // Ara carregar només les mitjanes dels socis actius
      const sociIds = socisData.map(s => s.numero_soci);
      
      const { data: allAverages, error: allError } = await supabase
        .from('mitjanes_historiques')
        .select('soci_id, mitjana, year')
        .eq('modalitat', historialModality)
        .in('soci_id', sociIds)
        .order('year', { ascending: false });

      if (allError) {
        console.error('Error carregant mitjanes:', allError);
        throw allError;
      }

      console.log(`Mitjanes carregades: ${allAverages?.length || 0}`);

      // Processar dades de socis amb mitjanes
      console.log('Processant dades de socis...');
      const socisWithAverages = socisData.map(soci => {
        const sociAverages = (allAverages || []).filter(m => m.soci_id === soci.numero_soci);

        let lastSeasonAvg = null;
        let previousSeasonAvg = null;
        let maxAvg = null;
        let observations = '';
        let hasHistoricalData = sociAverages.length > 0; // Indica si té dades històriques reals

        // Buscar mitjana temporada passada (any actual)
        const lastSeasonData = sociAverages.find(m => m.year === lastSeasonYear);
        if (lastSeasonData) {
          lastSeasonAvg = parseFloat(lastSeasonData.mitjana);
        }

        // Buscar mitjana temporada anterior (any passat)
        const previousSeasonData = sociAverages.find(m => m.year === previousSeasonYear);
        if (previousSeasonData) {
          previousSeasonAvg = parseFloat(previousSeasonData.mitjana);
        }

        // Calcular màxim
        if (lastSeasonAvg !== null && previousSeasonAvg !== null) {
          maxAvg = Math.max(lastSeasonAvg, previousSeasonAvg);
        } else if (lastSeasonAvg !== null) {
          maxAvg = lastSeasonAvg;
        } else if (previousSeasonAvg !== null) {
          maxAvg = previousSeasonAvg;
        }

        // Si no té mitjanes dels últims 2 anys, buscar l'última mitjana antiga
        if (maxAvg === null && sociAverages.length > 0) {
          // Excloure els últims 2 anys
          const olderAverages = sociAverages.filter(m =>
            m.year !== lastSeasonYear && m.year !== previousSeasonYear
          );

          if (olderAverages.length > 0) {
            // Com ja estan ordenats per any descendent, el primer és el més recent
            const mostRecent = olderAverages[0];
            maxAvg = parseFloat(mostRecent.mitjana);
            observations = `Any ${mostRecent.year}`;
          }
        }

        // Extreure només el primer cognom i abreviar el nom
        const firstCognom = soci.cognoms ? soci.cognoms.split(' ')[0] : '';
        const nomParts = soci.nom ? soci.nom.trim().split(/\s+/) : [];
        const nomInitials = nomParts.map(part => part.charAt(0).toUpperCase() + '.').join('');
        const displayName = firstCognom ? `${nomInitials} ${firstCognom}`.trim() : soci.nom;

        return {
          numero_soci: soci.numero_soci,
          nom: soci.nom,
          cognoms: soci.cognoms,
          displayName,
          lastSeasonAvg,
          previousSeasonAvg,
          maxAvg,
          observations,
          hasHistoricalData
        };
      });

      // Filtrar només socis amb almenys una mitjana històrica real
      // (excloent els que només tenen mitjanes assignades manualment)
      const socisWithData = socisWithAverages.filter(s => s.maxAvg !== null && s.hasHistoricalData);

      console.log(`Processats ${socisData.length} socis, ${socisWithData.length} amb mitjanes per ${historialModality}`);

      if (socisWithData.length === 0) {
        alert('No s\'han trobat mitjanes per a la modalitat seleccionada');
        loading = false;
        return;
      }

      // Generar HTML per imprimir
      console.log('Generant finestra d\'impressió...');
      openPrintWindow(socisWithData);
      console.log('Llistat generat correctament');

    } catch (e) {
      console.error('Error generant llistat:', e);
      alert(`Error generant el llistat: ${e.message || 'Si us plau, torna-ho a intentar.'}`);
    } finally {
      loading = false;
    }
  }

  function openPrintWindow(socisData: any[]) {
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      alert('No es pot obrir la finestra d\'impressió. Si us plau, permet les finestres emergents.');
      return;
    }

    const currentDate = new Date().toLocaleDateString('ca-ES', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });

    const currentYear = new Date().getFullYear();
    const lastSeason = `${currentYear - 1}-${currentYear}`;
    const previousSeason = `${currentYear - 2}-${currentYear - 1}`;

    // Generar files de la taula
    let tableRows = '';
    socisData.forEach((soci, index) => {
      const lastSeasonValue = soci.lastSeasonAvg !== null ? soci.lastSeasonAvg.toFixed(3) : '--';
      const previousSeasonValue = soci.previousSeasonAvg !== null ? soci.previousSeasonAvg.toFixed(3) : '--';
      const maxValue = soci.maxAvg !== null ? soci.maxAvg.toFixed(3) : '--';

      tableRows += `
        <tr style="border-bottom: 1px solid #e5e7eb;">
          <td style="padding: 8px 6px; font-size: 18px; color: #4b5563;">${index + 1}</td>
          <td style="padding: 8px 6px; font-size: 18px; font-weight: 500; color: #111827;">${soci.displayName}</td>
          <td style="padding: 8px 6px; font-size: 18px; text-align: right; color: #111827;">${previousSeasonValue}</td>
          <td style="padding: 8px 6px; font-size: 18px; text-align: right; color: #111827;">${lastSeasonValue}</td>
          <td style="padding: 8px 6px; font-size: 18px; text-align: right; font-weight: 600; color: #1f2937;">${maxValue}</td>
          <td style="padding: 8px 6px; font-size: 18px; color: #6b7280; font-style: ${soci.observations ? 'italic' : 'normal'};">${soci.observations}</td>
        </tr>`;
    });

    const html = `
      <!DOCTYPE html>
      <html lang="ca">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Llistat de Mitjanes - ${modalityNames[selectedModality]}</title>
        <style>
          @page {
            size: A4 landscape;
            margin: 5mm;
          }

          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.3;
            color: #111827;
            margin: 0;
            padding: 0;
          }

          table {
            page-break-inside: auto;
          }

          tr {
            page-break-inside: avoid;
            page-break-after: auto;
          }

          thead {
            display: table-header-group;
          }

          @media print {
            body {
              print-color-adjust: exact;
              -webkit-print-color-adjust: exact;
            }
          }
        </style>
      </head>
      <body>
        <div style="max-width: 100%; margin: 0 auto; padding: 4px;">
          <!-- Capçalera -->
          <div style="text-align: center; margin-bottom: 10px;">
            <h1 style="font-size: 28px; font-weight: bold; color: #111827; margin: 0 0 2px 0;">Llistat de Mitjanes per Soci</h1>
            <p style="font-size: 22px; color: #4b5563; margin: 0;">${modalityNames[selectedModality]}</p>
            <p style="font-size: 18px; color: #6b7280; margin: 2px 0 0 0;">Temporades ${previousSeason} i ${lastSeason}</p>
          </div>

          <!-- Taula -->
          <table style="width: 100%; border-collapse: collapse; margin-bottom: 8px;">
            <thead>
              <tr style="background-color: #f3f4f6; border-bottom: 2px solid #9ca3af;">
                <th style="text-align: left; padding: 10px 6px; font-size: 18px; font-weight: 600; color: #374151; width: 30px;">#</th>
                <th style="text-align: left; padding: 10px 6px; font-size: 18px; font-weight: 600; color: #374151;">Nom</th>
                <th style="text-align: right; padding: 10px 6px; font-size: 18px; font-weight: 600; color: #374151; width: 80px;">Temp. ${previousSeason}</th>
                <th style="text-align: right; padding: 10px 6px; font-size: 18px; font-weight: 600; color: #374151; width: 80px;">Temp. ${lastSeason}</th>
                <th style="text-align: right; padding: 10px 6px; font-size: 18px; font-weight: 600; color: #374151; width: 70px;">Màxim</th>
                <th style="text-align: left; padding: 10px 6px; font-size: 18px; font-weight: 600; color: #374151; width: 105px;">Observacions</th>
              </tr>
            </thead>
            <tbody>
              ${tableRows}
            </tbody>
          </table>

          <!-- Peu -->
          <div style="margin-top: 10px; padding-top: 6px; border-top: 1px solid #d1d5db;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <div style="font-size: 14px; color: #6b7280;">
                Document generat el ${currentDate}
              </div>
              <div style="font-size: 18px; font-weight: bold; color: #111827;">
                Total: ${socisData.length} socis
              </div>
            </div>
          </div>
        </div>
      </body>
      </html>
    `;

    printWindow.document.write(html);
    printWindow.document.close();

    printWindow.onload = () => {
      printWindow.print();
      printWindow.onafterprint = () => {
        printWindow.close();
      };
    };
  }
</script>

<div class="bg-white border border-gray-200 rounded-lg p-4">
  <h3 class="text-lg font-medium text-gray-900 mb-4">
    📊 Llistat de Mitjanes per Soci
  </h3>

  <div class="space-y-4">
    <div>
      <label for="modality-select" class="block text-sm font-medium text-gray-700 mb-2">
        Selecciona la modalitat
      </label>
      <select
        id="modality-select"
        bind:value={selectedModality}
        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="tres_bandes">3 Bandes</option>
        <option value="lliure">Lliure</option>
        <option value="banda">Banda</option>
      </select>
    </div>

    <button
      on:click={generatePrintView}
      disabled={loading}
      class="w-full px-4 py-2 bg-teal-600 text-white text-sm rounded hover:bg-teal-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
    >
      {#if loading}
        <svg class="animate-spin h-5 w-5" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generant llistat...
      {:else}
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"></path>
        </svg>
        Imprimir Llistat de Mitjanes
      {/if}
    </button>
  </div>

  <div class="mt-4 text-xs text-gray-500">
    <p><strong>Aquest llistat inclou:</strong></p>
    <ul class="list-disc list-inside mt-1 space-y-1">
      <li>Mitjana de la temporada passada</li>
      <li>Mitjana de la temporada anterior</li>
      <li>Màxim dels dos promitjos</li>
      <li>Observacions (any de l'última mitjana si no han jugat els últims 2 anys)</li>
    </ul>
  </div>
</div>
