// Test per veure quines variables d'entorn estan disponibles
console.log('\n=== VARIABLES D\'ENTORN DISPONIBLES ===\n');

const supabaseVars = Object.keys(process.env).filter(k => k.includes('SUPABASE'));
console.log('Variables SUPABASE trobades:', supabaseVars);

supabaseVars.forEach(key => {
  const value = process.env[key];
  const preview = value ? value.substring(0, 30) + '...' : '(buida)';
  console.log(`  ${key}: ${preview}`);
});

console.log('\n=== COMPROVACIONS ===\n');
console.log('✅ VITE_SUPABASE_URL:', process.env.VITE_SUPABASE_URL ? 'PRESENT' : '❌ ABSENT');
console.log('✅ VITE_SUPABASE_ANON_KEY:', process.env.VITE_SUPABASE_ANON_KEY ? 'PRESENT' : '❌ ABSENT');
console.log('✅ PUBLIC_SUPABASE_URL:', process.env.PUBLIC_SUPABASE_URL ? 'PRESENT' : '❌ ABSENT');
console.log('✅ PUBLIC_SUPABASE_ANON_KEY:', process.env.PUBLIC_SUPABASE_ANON_KEY ? 'PRESENT' : '❌ ABSENT');
console.log('✅ SUPABASE_URL:', process.env.SUPABASE_URL ? 'PRESENT' : '❌ ABSENT');
console.log('✅ SUPABASE_ANON_KEY:', process.env.SUPABASE_ANON_KEY ? 'PRESENT' : '❌ ABSENT');
