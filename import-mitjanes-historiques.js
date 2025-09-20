#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Llegeix els fitxers CSV
const socisData = fs.readFileSync(path.join(__dirname, 'dades', 'socis.csv'), 'utf-8');
const rankingData = fs.readFileSync(path.join(__dirname, 'dades', 'Ranquing (1) (1).csv'), 'utf-8');

// Processa el fitxer de socis
const socisLines = socisData.split('\n').filter(line => line.trim());
const socis = socisLines.map(line => {
    const parts = line.split(';');
    return {
        numero: parseInt(parts[0]),
        nom: parts[1],
        cognoms: parts[2],
        mail: parts[3]
    };
});

console.log(`Socis carregats: ${socis.length}`);

// Processa el fitxer de ranking
const rankingLines = rankingData.split('\n').filter(line => line.trim() && !line.startsWith('Any;'));
const rankings = rankingLines.map(line => {
    const parts = line.split(';');
    return {
        any: parseInt(parts[0]),
        modalitat: parts[1],
        posicio: parseInt(parts[2]),
        jugador: parts[3],
        mitjana: parseFloat(parts[4].replace(',', '.'))
    };
});

console.log(`Rankings carregats: ${rankings.length}`);

// Funció per normalitzar noms per comparació
function normalitzaNom(nom) {
    return nom
        .toLowerCase()
        // Normalitza accents malformats comuns en el CSV
        .replace(/[àáâãäåÀÁÂÃÄÅ�]/g, 'a')
        .replace(/[èéêëÈÉÊË�]/g, 'e')
        .replace(/[ìíîïÌÍÎÏ�]/g, 'i')
        .replace(/[òóôõöÒÓÔÕÖ�]/g, 'o')
        .replace(/[ùúûüÙÚÛÜ�]/g, 'u')
        .replace(/[çÇ]/g, 'c')
        .replace(/[ñÑ]/g, 'n')
        .replace(/[^a-z0-9\s\.]/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

// Funció per trobar coincidències
function trobaCoincidencia(jugadorRanking, socis) {
    const nomNormalitzat = normalitzaNom(jugadorRanking);
    
    // Primer, busca coincidència exacta del nom complet
    for (const soci of socis) {
        const nomCompletSoci = normalitzaNom(`${soci.nom} ${soci.cognoms}`);
        if (nomCompletSoci === nomNormalitzat) {
            return soci;
        }
    }
    
    // Busca per cognoms (molt comú al ranking)
    for (const soci of socis) {
        const cognomsNormalitzats = normalitzaNom(soci.cognoms);
        if (cognomsNormalitzats === nomNormalitzat) {
            return soci;
        }
    }
    
    // Busca per nom i primera part del cognom
    for (const soci of socis) {
        const primerCognom = soci.cognoms.split(' ')[0];
        const nomIPrimerCognom = normalitzaNom(`${soci.nom} ${primerCognom}`);
        if (nomIPrimerCognom === nomNormalitzat) {
            return soci;
        }
    }
    
    // Busca per inicials + cognom (ex: "J. SELGA")
    if (nomNormalitzat.includes('.')) {
        const parts = nomNormalitzat.split('.');
        if (parts.length === 2) {
            const inicial = parts[0].trim();
            const cognom = parts[1].trim();
            
            for (const soci of socis) {
                const nomInicial = normalitzaNom(soci.nom.charAt(0));
                const cognomsNormalitzats = normalitzaNom(soci.cognoms);
                
                if (nomInicial === inicial && cognomsNormalitzats.includes(cognom)) {
                    return soci;
                }
            }
        }
    }
    
    return null;
}

// Processa les coincidències
const coincidencies = [];
const noCoincidencies = [];

for (const ranking of rankings) {
    const soci = trobaCoincidencia(ranking.jugador, socis);
    
    if (soci) {
        coincidencies.push({
            soci_id: soci.numero,
            nom_soci: `${soci.nom} ${soci.cognoms}`,
            nom_ranking: ranking.jugador,
            any: ranking.any,
            modalitat: ranking.modalitat,
            mitjana: ranking.mitjana
        });
    } else {
        noCoincidencies.push(ranking);
    }
}

console.log(`\nCoincidències trobades: ${coincidencies.length}`);
console.log(`No coincidències: ${noCoincidencies.length}`);

// Mostra algunes coincidències com a exemple
console.log('\nExemples de coincidències:');
coincidencies.slice(0, 10).forEach(c => {
    console.log(`${c.nom_ranking} -> ${c.nom_soci} (ID: ${c.soci_id}) - ${c.any} ${c.modalitat}: ${c.mitjana}`);
});

// Mostra les no coincidències per revisar
console.log('\nJugadors sense coincidència:');
const jugadorsSenseCoincidencia = [...new Set(noCoincidencies.map(r => r.jugador))];
jugadorsSenseCoincidencia.slice(0, 20).forEach(jugador => {
    console.log(`- ${jugador}`);
});

// Genera SQL per crear la taula
const createTableSQL = `
-- Crear taula mitjanes_historiques
CREATE TABLE IF NOT EXISTS mitjanes_historiques (
    id SERIAL PRIMARY KEY,
    soci_id INTEGER NOT NULL REFERENCES socis(numero),
    any INTEGER NOT NULL,
    modalitat VARCHAR(20) NOT NULL,
    mitjana DECIMAL(5,3) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(soci_id, any, modalitat)
);

-- Crear índexs per millor rendiment
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_id ON mitjanes_historiques(soci_id);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_any ON mitjanes_historiques(any);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat ON mitjanes_historiques(modalitat);
`;

// Genera SQL per inserir les dades
let insertSQL = createTableSQL + '\n-- Inserir mitjanes històriques\n';

coincidencies.forEach(c => {
    insertSQL += `INSERT INTO mitjanes_historiques (soci_id, any, modalitat, mitjana) VALUES (${c.soci_id}, ${c.any}, '${c.modalitat}', ${c.mitjana}) ON CONFLICT (soci_id, any, modalitat) DO NOTHING;\n`;
});

// Guarda els resultats
fs.writeFileSync('mitjanes_historiques.sql', insertSQL);
fs.writeFileSync('coincidencies.json', JSON.stringify(coincidencies, null, 2));
fs.writeFileSync('no_coincidencies.json', JSON.stringify(noCoincidencies, null, 2));

console.log(`\nFitxers generats:`);
console.log(`- mitjanes_historiques.sql: ${coincidencies.length} inserts`);
console.log(`- coincidencies.json: detall de les coincidències`);
console.log(`- no_coincidencies.json: jugadors sense coincidència per revisar`);

// Estadístiques per modalitat i any
const estadistiques = {};
coincidencies.forEach(c => {
    const key = `${c.modalitat}_${c.any}`;
    if (!estadistiques[key]) {
        estadistiques[key] = 0;
    }
    estadistiques[key]++;
});

console.log('\nEstadístiques per modalitat i any:');
Object.keys(estadistiques).sort().forEach(key => {
    console.log(`${key}: ${estadistiques[key]} jugadors`);
});