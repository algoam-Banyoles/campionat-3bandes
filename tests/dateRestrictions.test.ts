import { describe, it, expect } from 'vitest';

// Simulem les funcions del generador de calendari
function parseSpecialRestrictions(restrictions: string): { start: Date; end: Date }[] {
  if (!restrictions || restrictions.trim() === '') return [];
  
  const periods: { start: Date; end: Date }[] = [];
  const currentYear = new Date().getFullYear();
  
  // Mapes dels mesos en català
  const monthMap: { [key: string]: number } = {
    'gener': 0, 'febrer': 1, 'març': 2, 'abril': 3, 'maig': 4, 'juny': 5,
    'juliol': 6, 'agost': 7, 'setembre': 8, 'octubre': 9, 'novembre': 10, 'desembre': 11
  };
  
  console.log('🔍 Parsing restrictions:', restrictions);
  
  // Dividir per línies i processar cada línia
  const lines = restrictions.split('\n').map(line => line.trim()).filter(line => line.length > 0);
  
  for (const line of lines) {
    console.log('📝 Processing line:', line);
    
    // Patró 1: "del X al Y de [mes]" o "X al Y de [mes]"
          const monthPeriodMatch = line.match(/(?:del\\s+)?(\\d{1,2})\\s+al\\s+(\\d{1,2})\\s+d['e]?([a-zA-Zàèéíòóúç]+)(?:\\s+NO)?/i);
    if (monthPeriodMatch) {
      const [, startDay, endDay, monthName] = monthPeriodMatch;
      const monthNumber = monthMap[monthName.toLowerCase()];
      if (monthNumber !== undefined) {
        const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
        const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
        periods.push({ start: startDate, end: endDate });
        console.log('✅ Found month period:', { start: startDate, end: endDate });
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
      console.log('✅ Found date period:', { start: startDate, end: endDate });
      continue;
    }
    
    // Patró 3: "DD-MM al DD-MM" o "del DD-MM al DD-MM"
    const dashPeriodMatch = line.match(/(?:del\s+)?(\d{1,2})-(\d{1,2})\s+al\s+(\d{1,2})-(\d{1,2})/i);
    if (dashPeriodMatch) {
      const [, startDay, startMonth, endDay, endMonth] = dashPeriodMatch;
      const startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
      const endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
      periods.push({ start: startDate, end: endDate });
      console.log('✅ Found dash period:', { start: startDate, end: endDate });
      continue;
    }
    
    // Patró 4: "X de [mes]" - data específica
          const specificDateMatch = line.match(/(\\d{1,2})\\s+de\\s+([a-zA-Zàèéíòóúç]+)(?:\\s+NO)?/i);
    if (specificDateMatch) {
      const [, day, monthName] = specificDateMatch;
      const monthNumber = monthMap[monthName.toLowerCase()];
      if (monthNumber !== undefined) {
        const date = new Date(currentYear, monthNumber, parseInt(day));
        periods.push({ start: date, end: date });
        console.log('✅ Found specific date:', { start: date, end: date });
        continue;
      }
    }
    
    console.log('❌ No pattern matched for line:', line);
  }
  
  return periods;
}

function parseFlexibleDate(dateStr: string): Date | null {
  // Intentem diferents formats
  const patterns = [
    /(\d{1,2})\/(\d{1,2})\/(\d{4})/, // DD/MM/YYYY
    /(\d{4})-(\d{1,2})-(\d{1,2})/, // YYYY-MM-DD
    /(\d{1,2})-(\d{1,2})-(\d{4})/, // DD-MM-YYYY
  ];
  
  for (const pattern of patterns) {
    const match = dateStr.match(pattern);
    if (match) {
      const [, part1, part2, part3] = match;
      let day: number, month: number, year: number;
      
      if (pattern === patterns[1]) { // YYYY-MM-DD
        year = parseInt(part1);
        month = parseInt(part2) - 1; // JavaScript months are 0-indexed
        day = parseInt(part3);
      } else { // DD/MM/YYYY or DD-MM-YYYY
        day = parseInt(part1);
        month = parseInt(part2) - 1; // JavaScript months are 0-indexed
        year = parseInt(part3);
      }
      
      // Validar que els valors són vàlids
      if (month < 0 || month > 11 || day < 1 || day > 31) {
        return null;
      }
      
      const date = new Date(year, month, day);
      
      // Verificar que la data creada coincideix amb els valors introduïts
      // (JavaScript "arregla" dates invàlides com 32/13/2024)
      if (date.getFullYear() !== year || 
          date.getMonth() !== month || 
          date.getDate() !== day) {
        return null;
      }
      
      return date;
    }
  }
  
  return null;
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

describe('Date Restrictions Parser', () => {
  it('should parse "del X al Y de [mes]" format', () => {
    const restrictions = 'No disponible del 15 al 22 de desembre';
    const periods = parseSpecialRestrictions(restrictions);
    
    expect(periods).toHaveLength(1);
    expect(periods[0].start.getMonth()).toBe(11); // December
    expect(periods[0].start.getDate()).toBe(15);
    expect(periods[0].end.getDate()).toBe(22);
  });
  
  it('should parse "del X al Y de [mes] NO" format', () => {
    const restrictions = 'Del 1 al 15 d\'octubre NO';
    const periods = parseSpecialRestrictions(restrictions);
    
    expect(periods).toHaveLength(1);
    expect(periods[0].start.getMonth()).toBe(9); // October
    expect(periods[0].start.getDate()).toBe(1);
    expect(periods[0].end.getDate()).toBe(15);
  });
  
  it('should parse "del DD/MM al DD/MM" format', () => {
    const restrictions = 'Del 1/12 al 5/12 no puc jugar';
    const periods = parseSpecialRestrictions(restrictions);
    
    expect(periods).toHaveLength(1);
    expect(periods[0].start.getMonth()).toBe(11); // December
    expect(periods[0].start.getDate()).toBe(1);
    expect(periods[0].end.getDate()).toBe(5);
  });
  
  it('should parse specific dates "X de [mes]"', () => {
    const restrictions = '24 de desembre no disponible';
    const periods = parseSpecialRestrictions(restrictions);
    
    expect(periods).toHaveLength(1);
    expect(periods[0].start.getMonth()).toBe(11); // December
    expect(periods[0].start.getDate()).toBe(24);
    expect(periods[0].end.getDate()).toBe(24); // Same day for specific dates
  });
  
  it('should parse dash format "DD-MM al DD-MM"', () => {
    const restrictions = 'Vacances del 20-07 al 30-07';
    const periods = parseSpecialRestrictions(restrictions);
    
    expect(periods).toHaveLength(1);
    expect(periods[0].start.getMonth()).toBe(6); // July
    expect(periods[0].start.getDate()).toBe(20);
    expect(periods[0].end.getDate()).toBe(30);
  });
  
  it('should parse multiple restrictions on separate lines', () => {
    const restrictions = `No disponible del 15 al 22 de desembre
Del 1/12 al 5/12 no puc jugar
24 de gener no disponible`;
    
    const periods = parseSpecialRestrictions(restrictions);
    
    expect(periods).toHaveLength(3);
    
    // Primera restricció
    expect(periods[0].start.getMonth()).toBe(11); // December
    expect(periods[0].start.getDate()).toBe(15);
    
    // Segona restricció
    expect(periods[1].start.getMonth()).toBe(11); // December
    expect(periods[1].start.getDate()).toBe(1);
    
    // Tercera restricció
    expect(periods[2].start.getMonth()).toBe(0); // January
    expect(periods[2].start.getDate()).toBe(24);
  });
  
  it('should parse restrictions with "NO" suffix in various formats', () => {
    const restrictions = `Del 1/3 al 10/3 NO
Del 15-04 al 20-04 NO
25 de maig NO`;
    
    const periods = parseSpecialRestrictions(restrictions);
    
    expect(periods).toHaveLength(3);
    
    // Primera restricció: Del 1/3 al 10/3 NO
    expect(periods[0].start.getMonth()).toBe(2); // March
    expect(periods[0].start.getDate()).toBe(1);
    expect(periods[0].end.getDate()).toBe(10);
    
    // Segona restricció: Del 15-04 al 20-04 NO
    expect(periods[1].start.getMonth()).toBe(3); // April
    expect(periods[1].start.getDate()).toBe(15);
    expect(periods[1].end.getDate()).toBe(20);
    
    // Tercera restricció: 25 de maig NO
    expect(periods[2].start.getMonth()).toBe(4); // May
    expect(periods[2].start.getDate()).toBe(25);
    expect(periods[2].end.getDate()).toBe(25);
  });
  
  it('should correctly identify restricted dates', () => {
    const restrictions = 'No disponible del 15 al 22 de desembre';
    
    const currentYear = new Date().getFullYear();
    const restrictedDate = new Date(currentYear, 11, 18); // December 18th
    const nonRestrictedDate = new Date(currentYear, 11, 10); // December 10th
    
    expect(isDateRestricted(restrictedDate, restrictions)).toBe(true);
    expect(isDateRestricted(nonRestrictedDate, restrictions)).toBe(false);
  });
  
  it('should handle empty or null restrictions', () => {
    expect(parseSpecialRestrictions('')).toEqual([]);
    expect(parseSpecialRestrictions(' ')).toEqual([]);
    expect(isDateRestricted(new Date(), '')).toBe(false);
  });
  
  it('should handle malformed restrictions gracefully', () => {
    const restrictions = 'Això no és una data vàlida';
    const periods = parseSpecialRestrictions(restrictions);
    expect(periods).toEqual([]);
  });
});

describe('Flexible Date Parser', () => {
  it('should parse DD/MM/YYYY format', () => {
    const date = parseFlexibleDate('15/12/2024');
    expect(date).not.toBeNull();
    expect(date!.getDate()).toBe(15);
    expect(date!.getMonth()).toBe(11); // December
    expect(date!.getFullYear()).toBe(2024);
  });
  
  it('should parse YYYY-MM-DD format', () => {
    const date = parseFlexibleDate('2024-12-15');
    expect(date).not.toBeNull();
    expect(date!.getDate()).toBe(15);
    expect(date!.getMonth()).toBe(11); // December
    expect(date!.getFullYear()).toBe(2024);
  });
  
  it('should parse DD-MM-YYYY format', () => {
    const date = parseFlexibleDate('15-12-2024');
    expect(date).not.toBeNull();
    expect(date!.getDate()).toBe(15);
    expect(date!.getMonth()).toBe(11); // December
    expect(date!.getFullYear()).toBe(2024);
  });
  
  it('should return null for invalid dates', () => {
    expect(parseFlexibleDate('invalid date')).toBeNull();
    expect(parseFlexibleDate('32/13/2024')).toBeNull();
  });
});