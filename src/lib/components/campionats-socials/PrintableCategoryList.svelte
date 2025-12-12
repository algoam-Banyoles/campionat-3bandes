<script lang="ts">
  export let inscriptions: any[] = [];
  export let categories: any[] = [];
  export let socis: any[] = [];
  export let eventName: string = '';
  export let eventSeason: string = '';
  export let modality: string = '';

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  function getSociInfo(inscription: any) {
    return socis.find(s => s.numero_soci === inscription.soci_numero) || {
      nom: 'Desconegut',
      cognoms: '',
      numero_soci: inscription.soci_numero,
      historicalAverage: null,
      historicalAverageYear: null,
      oldestAverage: null,
      oldestAverageYear: null
    };
  }

  function getAverageInfo(sociInfo: any) {
    if (sociInfo.historicalAverage !== null) {
      return {
        value: sociInfo.historicalAverage,
        year: sociInfo.historicalAverageYear,
        type: 'recent'
      };
    } else if (sociInfo.oldestAverage !== null) {
      return {
        value: sociInfo.oldestAverage,
        year: sociInfo.oldestAverageYear,
        type: 'antiga'
      };
    }
    return null;
  }

  // Agrupar inscripcions per categoria
  function getInscriptionsByCategory() {
    return categories
      .sort((a, b) => a.ordre_categoria - b.ordre_categoria)
      .map(category => {
        const categoryInscriptions = inscriptions
          .filter(i => i.categoria_assignada_id === category.id)
          .map(inscription => {
            const sociInfo = getSociInfo(inscription);
            const averageInfo = getAverageInfo(sociInfo);
            // Extreure només el primer cognom i abreviar el nom
            const firstCognom = sociInfo.cognoms ? sociInfo.cognoms.split(' ')[0] : '';
            const nomParts = sociInfo.nom ? sociInfo.nom.trim().split(/\s+/) : [];
            const nomInitials = nomParts.map(part => part.charAt(0).toUpperCase() + '.').join('');
            const displayName = firstCognom ? `${nomInitials} ${firstCognom}`.trim() : sociInfo.nom;
            return {
              inscription,
              sociInfo,
              averageInfo,
              displayName
            };
          })
          .sort((a, b) => {
            const avgA = a.averageInfo?.value || 0;
            const avgB = b.averageInfo?.value || 0;
            if (avgB !== avgA) return avgB - avgA;
            return a.displayName.localeCompare(b.displayName, 'ca');
          });

        return {
          category,
          inscriptions: categoryInscriptions,
          count: categoryInscriptions.length
        };
      })
      .filter(g => g.count > 0);
  }

  function openPrintView() {
    const inscriptionsByCategory = getInscriptionsByCategory();
    const totalAssigned = inscriptions.filter(i => i.categoria_assignada_id).length;

    // Generar HTML per imprimir
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

    let categoriesHTML = '';
    inscriptionsByCategory.forEach(group => {
      categoriesHTML += `
        <div style="margin-bottom: 32px; page-break-inside: avoid;">
          <div style="background-color: #f3f4f6; border-bottom: 2px solid #9ca3af; padding: 12px 16px; margin-bottom: 12px;">
            <h2 style="font-size: 20px; font-weight: bold; color: #111827; margin: 0;">
              ${group.category.nom}
              <span style="font-size: 14px; font-weight: normal; color: #4b5563; margin-left: 8px;">
                (${group.count} ${group.count === 1 ? 'jugador' : 'jugadors'})
              </span>
            </h2>
            <p style="font-size: 14px; color: #4b5563; margin: 4px 0 0 0;">
              Distància: ${group.category.distancia_caramboles} caramboles
            </p>
          </div>

          <table style="width: 100%; border-collapse: collapse;">
            <thead>
              <tr style="border-bottom: 1px solid #d1d5db;">
                <th style="text-align: left; padding: 8px 12px; font-size: 14px; font-weight: 600; color: #374151; width: 48px;">#</th>
                <th style="text-align: left; padding: 8px 12px; font-size: 14px; font-weight: 600; color: #374151;">Jugador</th>
                <th style="text-align: right; padding: 8px 12px; font-size: 14px; font-weight: 600; color: #374151; width: 128px;">Mitjana</th>
                <th style="text-align: left; padding: 8px 12px; font-size: 14px; font-weight: 600; color: #374151; width: 96px;">Origen</th>
              </tr>
            </thead>
            <tbody>`;

      group.inscriptions.forEach((player, index) => {
        const avgValue = player.averageInfo ? player.averageInfo.value.toFixed(3) : '--';
        const avgYear = player.averageInfo ? player.averageInfo.year : '--';
        const avgColor = player.averageInfo && player.averageInfo.type === 'antiga' ? '#d97706' : '#15803d';
        const avgMark = player.averageInfo && player.averageInfo.type === 'antiga' ? ' *' : '';

        categoriesHTML += `
          <tr style="border-bottom: 1px solid #e5e7eb;">
            <td style="padding: 8px 12px; font-size: 14px; color: #4b5563;">${index + 1}</td>
            <td style="padding: 8px 12px; font-size: 14px; font-weight: 500; color: #111827;">${player.displayName}</td>
            <td style="padding: 8px 12px; font-size: 14px; text-align: right; font-weight: 500; color: #111827;">${avgValue}</td>
            <td style="padding: 8px 12px; font-size: 14px; color: ${avgColor};">${avgYear}${avgMark}</td>
          </tr>`;
      });

      categoriesHTML += `
            </tbody>
          </table>
        </div>`;
    });

    const html = `
      <!DOCTYPE html>
      <html lang="ca">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Llistat per Categories - ${eventName}</title>
        <style>
          @page {
            size: A4;
            margin: 15mm;
          }

          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.5;
            color: #111827;
            margin: 0;
            padding: 0;
          }

          table {
            page-break-inside: avoid;
          }

          tr {
            page-break-inside: avoid;
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
        <div style="max-width: 210mm; margin: 0 auto; padding: 20px;">
          <!-- Capçalera -->
          <div style="text-align: center; margin-bottom: 32px;">
            <h1 style="font-size: 28px; font-weight: bold; color: #111827; margin: 0 0 8px 0;">${eventName}</h1>
            <p style="font-size: 18px; color: #4b5563; margin: 0;">Temporada ${eventSeason}</p>
            <p style="font-size: 16px; color: #6b7280; margin: 4px 0;">${modalityNames[modality] || modality}</p>
            <p style="font-size: 14px; color: #9ca3af; margin: 16px 0 0 0;">Llistat de jugadors per categoria</p>
          </div>

          <!-- Llistat per categories -->
          ${categoriesHTML}

          <!-- Resum total -->
          <div style="margin-top: 32px; padding-top: 16px; border-top: 2px solid #9ca3af;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <div style="font-size: 14px; color: #4b5563;">
                * Mitjanes anteriors a ${currentYear - 1}
              </div>
              <div style="font-size: 18px; font-weight: bold; color: #111827;">
                Total: ${totalAssigned} jugadors
              </div>
            </div>
          </div>

          <!-- Peu de pàgina -->
          <div style="margin-top: 48px; text-align: center; font-size: 12px; color: #9ca3af;">
            <p style="margin: 0;">Document generat el ${currentDate}</p>
          </div>
        </div>
      </body>
      </html>
    `;

    printWindow.document.write(html);
    printWindow.document.close();

    // Esperar que es carregui i imprimir
    printWindow.onload = () => {
      printWindow.print();
      printWindow.onafterprint = () => {
        printWindow.close();
      };
    };
  }
</script>

<button
  on:click={openPrintView}
  class="px-4 py-2 bg-indigo-600 text-white text-sm rounded hover:bg-indigo-700 flex items-center gap-2"
>
  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"></path>
  </svg>
  Imprimir Llistat per Categories
</button>
