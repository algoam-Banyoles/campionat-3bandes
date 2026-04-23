// scripts/upload-socis-fotos.mjs
//
// Puja les fotos locals de docs/fotossocis/<numero_soci>.jpg al bucket privat
// socis-fotos de Supabase Storage. Redimensiona abans de pujar (max 800x800,
// JPEG qualitat 82, ~100KB). Actualitza socis.foto_path amb el nom del fitxer.
//
// Usa SUPABASE_SERVICE_ROLE_KEY per saltar RLS.
//
// Ús: `node scripts/upload-socis-fotos.mjs`
//     `node scripts/upload-socis-fotos.mjs --dry-run`        (només mostra el pla)
//     `node scripts/upload-socis-fotos.mjs --only 8747`      (un sol soci)
//     `node scripts/upload-socis-fotos.mjs --skip-existing`  (salta els ja pujats)

import { createClient } from '@supabase/supabase-js';
import sharp from 'sharp';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, basename, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');
const fotosDir = join(projectRoot, 'docs', 'fotossocis');

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');
const skipExisting = args.has('--skip-existing');
const onlyArg = process.argv.find((a, i) => process.argv[i - 1] === '--only');
const onlyNum = onlyArg ? Number(onlyArg) : null;

// Load .env
const envPath = join(projectRoot, '.env');
const env = Object.fromEntries(
  readFileSync(envPath, 'utf8')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'))
    .map((l) => {
      const eq = l.indexOf('=');
      return [l.slice(0, eq).trim(), l.slice(eq + 1).trim()];
    })
);

const SUPABASE_URL = env.SUPABASE_URL || env.PUBLIC_SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('❌ Falten SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY al .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false }
});

const BUCKET = 'socis-fotos';
const MAX_DIM = 800;
const JPEG_QUALITY = 82;

async function main() {
  // 1. List local files matching <numero>.jpg|jpeg|png
  const files = readdirSync(fotosDir)
    .filter((f) => /^\d+\.(jpg|jpeg|png)$/i.test(f))
    .filter((f) => statSync(join(fotosDir, f)).isFile());

  console.log(`📁 Trobades ${files.length} fotos locals amb format <numero>.<ext>`);

  // Warnings for non-standard files
  const nonStandard = readdirSync(fotosDir).filter(
    (f) =>
      !/^\d+\.(jpg|jpeg|png)$/i.test(f) &&
      !['.gitkeep', 'README.md'].includes(f)
  );
  if (nonStandard.length > 0) {
    console.log('\n⚠️  Fitxers ignorats (no tenen format <numero>.<ext>):');
    nonStandard.forEach((f) => console.log(`   - ${f}`));
    console.log('');
  }

  // 2. Fetch all socis with foto_path to know what's already uploaded
  const { data: existingSocis, error: fetchErr } = await supabase
    .from('socis')
    .select('numero_soci, foto_path');

  if (fetchErr) {
    console.error('❌ Error llegint socis:', fetchErr.message);
    process.exit(1);
  }

  const existingMap = new Map(existingSocis.map((s) => [s.numero_soci, s.foto_path]));

  let uploaded = 0;
  let skipped = 0;
  let errors = 0;
  let unknownSocis = 0;

  for (const file of files) {
    const numero = Number(basename(file, extname(file)));

    if (onlyNum !== null && numero !== onlyNum) continue;

    if (!existingMap.has(numero)) {
      console.log(`⚠️  Soci ${numero} no existeix a la BD — saltant ${file}`);
      unknownSocis++;
      continue;
    }

    if (skipExisting && existingMap.get(numero)) {
      skipped++;
      continue;
    }

    const srcPath = join(fotosDir, file);
    const destName = `${numero}.jpg`; // sempre jpg a Storage

    try {
      // 3. Resize to max 800x800, jpeg q82
      const buffer = await sharp(srcPath)
        .rotate() // honor EXIF orientation
        .resize(MAX_DIM, MAX_DIM, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: JPEG_QUALITY, progressive: true, mozjpeg: true })
        .toBuffer();

      const sizeKB = Math.round(buffer.length / 1024);

      if (dryRun) {
        console.log(`[DRY] ${file} → ${destName} (${sizeKB} KB)`);
        continue;
      }

      // 4. Upload (upsert)
      const { error: uploadErr } = await supabase.storage
        .from(BUCKET)
        .upload(destName, buffer, {
          contentType: 'image/jpeg',
          upsert: true,
          cacheControl: '3600'
        });

      if (uploadErr) {
        console.error(`❌ ${file} → ${destName}: ${uploadErr.message}`);
        errors++;
        continue;
      }

      // 5. Update socis.foto_path
      const { error: updateErr } = await supabase
        .from('socis')
        .update({ foto_path: destName })
        .eq('numero_soci', numero);

      if (updateErr) {
        console.error(`⚠️  ${destName} pujat, però error actualitzant foto_path: ${updateErr.message}`);
        errors++;
        continue;
      }

      console.log(`✅ ${file} → ${destName} (${sizeKB} KB)`);
      uploaded++;
    } catch (e) {
      console.error(`❌ ${file}: ${e.message}`);
      errors++;
    }
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`✅ Pujades:     ${uploaded}`);
  console.log(`⏭️  Saltades:   ${skipped}`);
  console.log(`❌ Errors:      ${errors}`);
  console.log(`⚠️  Socis desconeguts: ${unknownSocis}`);
  if (dryRun) console.log('(mode dry-run, cap canvi real)');
}

main().catch((e) => {
  console.error('Error inesperat:', e);
  process.exit(1);
});
