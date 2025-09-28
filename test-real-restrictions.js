// Test amb les restriccions reals dels jugadors
console.log("🔍 Testing real player restrictions from database:\n");

// Dades reals dels jugadors
const realRestrictions = [
  { soci: 8715, restriction: "del 1 al 15 de octubre NO" },
  { soci: 7196, restriction: "Del 1 al 15 de octubre NO" },
  { soci: 8648, restriction: "6 octubre NO" },
  { soci: 8747, restriction: "1 i 2 octubre NO" }
];

// Copiem la funció parseSpecialRestrictions del CalendarGenerator
function parseSpecialRestrictions(restrictions) {
  if (!restrictions || restrictions.trim() === '') return [];
  
  const periods = [];
  const currentYear = new Date().getFullYear();
  
  // Mapes dels mesos en català
  const monthMap = {
    'gener': 0, 'febrer': 1, 'març': 2, 'abril': 3, 'maig': 4, 'juny': 5,
    'juliol': 6, 'agost': 7, 'setembre': 8, 'octubre': 9, 'novembre': 10, 'desembre': 11
  };
  
  console.log('🔍 Parsing restrictions:', restrictions);
  
  // Dividir per línies i processar cada línia
  const lines = restrictions.split('\n').map(line => line.trim()).filter(line => line.length > 0);
  
  for (const line of lines) {
    console.log('📝 Processing line:', line);
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
        console.log('✅ Found month period (de):', { start: startDate, end: endDate });
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
          console.log("✅ Found month period (d'):", { start: startDate, end: endDate });
          found = true;
        }
      }
    }
    
    // Test 3: DD/MM al DD/MM
    if (!found) {
      match = line.match(/(\d{1,2})\/(\d{1,2})\s+al\s+(\d{1,2})\/(\d{1,2})/i);
      if (match) {
        const [, startDay, startMonth, endDay, endMonth] = match;
        const startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
        const endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
        periods.push({ start: startDate, end: endDate });
        console.log('✅ Found date period (/):', { start: startDate, end: endDate });
        found = true;
      }
    }
    
    // Test 4: DD-MM al DD-MM
    if (!found) {
      match = line.match(/(\d{1,2})-(\d{1,2})\s+al\s+(\d{1,2})-(\d{1,2})/i);
      if (match) {
        const [, startDay, startMonth, endDay, endMonth] = match;
        const startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
        const endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
        periods.push({ start: startDate, end: endDate });
        console.log('✅ Found dash period (-):', { start: startDate, end: endDate });
        found = true;
      }
    }
    
    // Test 5: Dates específiques "X de [mes]"
    if (!found) {
      match = line.match(/(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, day, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const date = new Date(currentYear, monthNumber, parseInt(day));
          periods.push({ start: date, end: date });
          console.log('✅ Found specific date:', { start: date, end: date });
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
          console.log('✅ Found specific date (no "de"):', { start: date, end: date });
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
          console.log('✅ Found multiple specific dates:', { date1, date2 });
          found = true;
        }
      }
    }
    
    if (!found) {
      console.log('❌ No pattern matched for line:', line);
    }
  }
  
  return periods;
}

// Test amb les restriccions reals
realRestrictions.forEach(({ soci, restriction }) => {
  console.log(`\n=== Testing Soci ${soci}: "${restriction}" ===`);
  const periods = parseSpecialRestrictions(restriction);
  
  if (periods.length > 0) {
    console.log(`✅ Successfully parsed ${periods.length} period(s):`);
    periods.forEach((period, i) => {
      console.log(`   ${i+1}. From ${period.start.toLocaleDateString('ca-ES')} to ${period.end.toLocaleDateString('ca-ES')}`);
    });
  } else {
    console.log('❌ No periods parsed!');
  }
});

console.log("\n🎯 Test completed!");