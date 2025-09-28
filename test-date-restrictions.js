// Test de la funció isDateRestricted amb dades reals
console.log("🎯 Testing isDateRestricted function with real data:\n");

// Copiem les funcions necessàries del CalendarGenerator
function parseSpecialRestrictions(restrictions) {
  if (!restrictions || restrictions.trim() === '') return [];
  
  const periods = [];
  const currentYear = new Date().getFullYear();
  
  // Mapes dels mesos en català
  const monthMap = {
    'gener': 0, 'febrer': 1, 'març': 2, 'abril': 3, 'maig': 4, 'juny': 5,
    'juliol': 6, 'agost': 7, 'setembre': 8, 'octubre': 9, 'novembre': 10, 'desembre': 11
  };
  
  // Dividir per línies i processar cada línia
  const lines = restrictions.split('\n').map(line => line.trim()).filter(line => line.length > 0);
  
  for (const line of lines) {
    let found = false;
    
    // Test 1: Períodes "del X al Y de [mes]"
    let match = line.match(/del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
    if (match) {
      const [, startDay, endDay, monthName] = match;
      const monthNumber = monthMap[monthName.toLowerCase()];
      if (monthNumber !== undefined) {
        const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
        const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
        periods.push({ start: startDate, end: endDate });
        found = true;
      }
    }
    
    // Test 2: Períodes "del X al Y d'[mes]"
    if (!found) {
      match = line.match(/del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+d'([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, startDay, endDay, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
          const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
          periods.push({ start: startDate, end: endDate });
          found = true;
        }
      }
    }
    
    // Test 6: "X [mes]" sense "de"
    if (!found) {
      match = line.match(/(\d{1,2})\s+([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, day, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const date = new Date(currentYear, monthNumber, parseInt(day));
          periods.push({ start: date, end: date });
          found = true;
        }
      }
    }
    
    // Test 7: Multiple dates "X i Y [mes]"
    if (!found) {
      match = line.match(/(\d{1,2})\s+i\s+(\d{1,2})\s+([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, day1, day2, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const date1 = new Date(currentYear, monthNumber, parseInt(day1));
          const date2 = new Date(currentYear, monthNumber, parseInt(day2));
          periods.push({ start: date1, end: date1 });
          periods.push({ start: date2, end: date2 });
          found = true;
        }
      }
    }
  }
  
  return periods;
}

function isDateRestricted(date, restrictionsText) {
  if (!restrictionsText || restrictionsText.trim() === '') return false;
  
  const restrictions = parseSpecialRestrictions(restrictionsText);
  
  return restrictions.some(restriction => {
    // Comparar només les dates (sense hora)
    const checkDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const startDate = new Date(restriction.start.getFullYear(), restriction.start.getMonth(), restriction.start.getDate());
    const endDate = new Date(restriction.end.getFullYear(), restriction.end.getMonth(), restriction.end.getDate());
    
    return checkDate >= startDate && checkDate <= endDate;
  });
}

// Dades reals dels jugadors
const realRestrictions = [
  { soci: 8715, restriction: "del 1 al 15 de octubre NO" },
  { soci: 7196, restriction: "Del 1 al 15 de octubre NO" },
  { soci: 8648, restriction: "6 octubre NO" },
  { soci: 8747, restriction: "1 i 2 octubre NO" }
];

// Dates de test per octubre 2025
const testDates = [
  new Date(2025, 9, 1),   // 1 d'octubre
  new Date(2025, 9, 2),   // 2 d'octubre  
  new Date(2025, 9, 6),   // 6 d'octubre
  new Date(2025, 9, 10),  // 10 d'octubre
  new Date(2025, 9, 15),  // 15 d'octubre
  new Date(2025, 9, 16),  // 16 d'octubre (no restringit)
  new Date(2025, 9, 25),  // 25 d'octubre (no restringit)
];

console.log("Testing date restrictions:\n");

realRestrictions.forEach(({ soci, restriction }) => {
  console.log(`=== Soci ${soci}: "${restriction}" ===`);
  
  testDates.forEach(testDate => {
    const isRestricted = isDateRestricted(testDate, restriction);
    const dateStr = testDate.toLocaleDateString('ca-ES');
    const status = isRestricted ? '🚫 RESTRINGIT' : '✅ Disponible';
    console.log(`   ${dateStr}: ${status}`);
  });
  
  console.log('');
});

console.log("🎯 Test completed!");