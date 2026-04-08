import fs from 'node:fs';

const src = process.argv[2];
const dst = process.argv[3];
const raw = JSON.parse(fs.readFileSync(src, 'utf8'));
const text = raw[0].text;
const m = text.match(/<untrusted-data-[^>]+>\s*([\s\S]*?)\s*<\/untrusted-data-/);
const inner = m ? m[1] : text;
const arr = JSON.parse(inner);
const defs = arr[0].defs;
fs.writeFileSync(dst, '-- Snapshot RPCs referencing players (Fase 5c Sessio 3)\n-- Captured ' + new Date().toISOString() + '\n\n' + defs + '\n');
console.log('Wrote', defs.length, 'chars to', dst);
