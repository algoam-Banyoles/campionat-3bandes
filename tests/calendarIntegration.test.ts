import { describe, it, expect } from 'vitest';

describe('Calendar Generation Integration Tests', () => {
  // Simulem les dades d'un jugador amb restriccions especials
  const mockPlayerData = {
    id: 1,
    nom: 'Joan Test',
    preferencies_dies: '[1,3,5]', // Dilluns, dimecres, divendres
    preferencies_hores: '["18:00","19:00","20:00"]',
    restriccions_especials: `No disponible del 15 al 22 de desembre
Del 1/1 al 7/1 vacances
24 de gener no puc jugar`
  };

  const mockPlayerData2 = {
    id: 2,
    nom: 'Maria Test',
    preferencies_dies: '[2,4,6]', // Dimarts, dijous, dissabte
    preferencies_hores: '["19:00","20:00","21:00"]',
    restriccions_especials: `Vacances del 20-07 al 30-07`
  };

  // Simulem la funció parseSpecialRestrictions (copiada del CalendarGenerator)
  function parseSpecialRestrictions(restrictions: string): { start: Date; end: Date }[] {
    if (!restrictions || restrictions.trim() === '') return [];
    
    const periods: { start: Date; end: Date }[] = [];
    const currentYear = new Date().getFullYear();
    
    // Mapes dels mesos en català
    const monthMap: { [key: string]: number } = {
      'gener': 0, 'febrer': 1, 'març': 2, 'abril': 3, 'maig': 4, 'juny': 5,
      'juliol': 6, 'agost': 7, 'setembre': 8, 'octubre': 9, 'novembre': 10, 'desembre': 11
    };
    
    // Dividir per línies i processar cada línia
    const lines = restrictions.split('\n').map(line => line.trim()).filter(line => line.length > 0);
    
    for (const line of lines) {
      // Patró 1: "del X al Y de [mes]" o "X al Y de [mes]"
      const monthPeriodMatch = line.match(/(?:del\s+)?(\d{1,2})\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
      if (monthPeriodMatch) {
        const [, startDay, endDay, monthName] = monthPeriodMatch;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
          const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
          periods.push({ start: startDate, end: endDate });
          continue;
        }
      }
      
      // Patró 2: "del DD/MM al DD/MM" o "DD/MM al DD/MM"
      const datePeriodMatch = line.match(/(?:del\s+)?(\d{1,2})\/(\d{1,2})\s+al\s+(\d{1,2})\/(\d{1,2})/i);
      if (datePeriodMatch) {
        const [, startDay, startMonth, endDay, endMonth] = datePeriodMatch;
        const startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
        const endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
        periods.push({ start: startDate, end: endDate });
        continue;
      }
      
      // Patró 3: "DD-MM al DD-MM" o "del DD-MM al DD-MM"
      const dashPeriodMatch = line.match(/(?:del\s+)?(\d{1,2})-(\d{1,2})\s+al\s+(\d{1,2})-(\d{1,2})/i);
      if (dashPeriodMatch) {
        const [, startDay, startMonth, endDay, endMonth] = dashPeriodMatch;
        const startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
        const endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
        periods.push({ start: startDate, end: endDate });
        continue;
      }
      
      // Patró 4: "X de [mes]" - data específica
      const specificDateMatch = line.match(/(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
      if (specificDateMatch) {
        const [, day, monthName] = specificDateMatch;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const date = new Date(currentYear, monthNumber, parseInt(day));
          periods.push({ start: date, end: date });
          continue;
        }
      }
    }
    
    return periods;
  }

  function isDateRestricted(date: Date, restrictions: string): boolean {
    const periods = parseSpecialRestrictions(restrictions);
    
    for (const period of periods) {
      if (date >= period.start && date <= period.end) {
        return true;
      }
    }
    
    return false;
  }

  // Simulem la lògica del generador de calendari per trobar slot vàlids
  function findValidSlotForPlayers(player1: any, player2: any, proposedDate: Date): boolean {
    // Comprovar restriccions especials
    if (isDateRestricted(proposedDate, player1.restriccions_especials) ||
        isDateRestricted(proposedDate, player2.restriccions_especials)) {
      return false;
    }

    // Comprovar preferències de dies (0=diumenge, 1=dilluns, etc.)
    const dayOfWeek = proposedDate.getDay();
    const player1Days = JSON.parse(player1.preferencies_dies || '[]');
    const player2Days = JSON.parse(player2.preferencies_dies || '[]');
    
    if (player1Days.length > 0 && !player1Days.includes(dayOfWeek)) {
      return false;
    }
    
    if (player2Days.length > 0 && !player2Days.includes(dayOfWeek)) {
      return false;
    }

    return true;
  }

  it('should respect special date restrictions when scheduling matches', () => {
    const currentYear = new Date().getFullYear();
    
    // Dates que haurien d'estar restringides per player1
    const restrictedDates = [
      new Date(currentYear, 11, 18), // 18 de desembre (dins del període del 15 al 22)
      new Date(currentYear, 0, 3),   // 3 de gener (dins del període del 1 al 7 de gener)
      new Date(currentYear, 0, 24),  // 24 de gener (data específica)
    ];
    
    // Dates que NO haurien d'estar restringides
    const validDates = [
      new Date(currentYear, 11, 10), // 10 de desembre (fora del període restringit)
      new Date(currentYear, 0, 10),  // 10 de gener (fora del període restringit)
      new Date(currentYear, 1, 15),  // 15 de febrer (no restringit)
    ];
    
    // Verificar que les dates restringides són detectades
    for (const date of restrictedDates) {
      const isValid = findValidSlotForPlayers(mockPlayerData, mockPlayerData2, date);
      expect(isValid).toBe(false);
    }
    
    // Verificar que les dates vàlides són acceptades (si compleixen altres criteris)
    // Nota: Aquestes podrien fallar per preferències de dies, però no per restriccions especials
    for (const date of validDates) {
      const isRestricted = isDateRestricted(date, mockPlayerData.restriccions_especials);
      expect(isRestricted).toBe(false);
    }
  });

  it('should handle player2 restrictions correctly', () => {
    const currentYear = new Date().getFullYear();
    
    // Data restringida per player2 (vacances del 20-07 al 30-07)
    const restrictedDate = new Date(currentYear, 6, 25); // 25 de juliol
    const validDate = new Date(currentYear, 6, 15); // 15 de juliol
    
    const isRestrictedDateValid = findValidSlotForPlayers(mockPlayerData, mockPlayerData2, restrictedDate);
    expect(isRestrictedDateValid).toBe(false);
    
    const isRestricted = isDateRestricted(validDate, mockPlayerData2.restriccions_especials);
    expect(isRestricted).toBe(false);
  });

  it('should handle empty or missing restrictions gracefully', () => {
    const playerWithoutRestrictions = {
      ...mockPlayerData,
      restriccions_especials: ''
    };
    
    const anyDate = new Date(2025, 5, 15); // 15 de juny
    const isValid = findValidSlotForPlayers(playerWithoutRestrictions, mockPlayerData2, anyDate);
    
    // Hauria de fallar només per preferències de dies, no per restriccions especials
    const isRestricted = isDateRestricted(anyDate, playerWithoutRestrictions.restriccions_especials);
    expect(isRestricted).toBe(false);
  });

  it('should correctly parse all restriction formats from player data', () => {
    const periods = parseSpecialRestrictions(mockPlayerData.restriccions_especials);
    
    expect(periods).toHaveLength(3);
    
    // Primera restricció: del 15 al 22 de desembre
    expect(periods[0].start.getMonth()).toBe(11); // Desembre
    expect(periods[0].start.getDate()).toBe(15);
    expect(periods[0].end.getDate()).toBe(22);
    
    // Segona restricció: del 1/1 al 7/1
    expect(periods[1].start.getMonth()).toBe(0); // Gener
    expect(periods[1].start.getDate()).toBe(1);
    expect(periods[1].end.getDate()).toBe(7);
    
    // Tercera restricció: 24 de gener
    expect(periods[2].start.getMonth()).toBe(0); // Gener
    expect(periods[2].start.getDate()).toBe(24);
    expect(periods[2].end.getDate()).toBe(24); // Mateix dia
  });

  it('should validate multiple competing restrictions', () => {
    const currentYear = new Date().getFullYear();
    
    // Si dos jugadors tenen restriccions que es solapen
    const player1WithRestriction = {
      ...mockPlayerData,
      restriccions_especials: 'No disponible del 10 al 20 de juny'
    };
    
    const player2WithRestriction = {
      ...mockPlayerData2,
      restriccions_especials: 'Vacances del 15 al 25 de juny'
    };
    
    // Dia que està restringit per ambdós jugadors
    const overlapDate = new Date(currentYear, 5, 18); // 18 de juny
    
    const isValid = findValidSlotForPlayers(player1WithRestriction, player2WithRestriction, overlapDate);
    expect(isValid).toBe(false);
    
    // Dia que només està restringit per un jugador
    const partialOverlapDate = new Date(currentYear, 5, 12); // 12 de juny (només player1)
    const isPartialValid = findValidSlotForPlayers(player1WithRestriction, player2WithRestriction, partialOverlapDate);
    expect(isPartialValid).toBe(false);
  });
});