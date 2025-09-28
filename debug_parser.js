// Test simple per debuggar el parser

// Test cases que fallen
const testCases = [
  "No disponible del 15 al 22 de desembre",
  "Del 1 al 15 d'octubre NO", 
  "24 de desembre no disponible",
  "25 de maig NO"
];

testCases.forEach(restriction => {
  console.log(`\n=== Testing: "${restriction}" ===`);
  
  // Patrons per períodes
  const periodPatterns = [
    /del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i,
    /del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+d'([a-zA-Zàèéíòóúç]+)/i,
    /del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)\s+NO/i,
    /del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+d'([a-zA-Zàèéíòóúç]+)\s+NO/i,
  ];
  
  periodPatterns.forEach((pattern, i) => {
    const match = restriction.match(pattern);
    if (match) {
      console.log(`  ✅ Period Pattern ${i} MATCHED:`, match.slice(1, 4));
    }
  });
  
  // Patrons per dates específiques
  const specificPatterns = [
    /(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i,
    /(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)\s+NO/i,
  ];
  
  specificPatterns.forEach((pattern, i) => {
    const match = restriction.match(pattern);
    if (match) {
      console.log(`  ✅ Specific Pattern ${i} MATCHED:`, match.slice(1, 3));
    }
  });
});