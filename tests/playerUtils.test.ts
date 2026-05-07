import { describe, it, expect } from 'vitest';
import {
  formatarNomJugador,
  obtenirInicials,
  nomComplertSoci,
  nomFormatatSoci,
  esNomValid
} from '../src/lib/utils/playerUtils';

describe('formatarNomJugador', () => {
  it('retorna cadena buida per a entrada buida o nul·la', () => {
    expect(formatarNomJugador('')).toBe('');
    expect(formatarNomJugador('   ')).toBe('');
    // @ts-expect-error testing null robustness
    expect(formatarNomJugador(null)).toBe('');
  });

  it('retorna el nom intacte si només hi ha una part', () => {
    expect(formatarNomJugador('Joan')).toBe('Joan');
  });

  it('format estàndard: nom + cognom → "I. Cognom"', () => {
    expect(formatarNomJugador('Joan Garcia')).toBe('J. Garcia');
  });

  it('format estàndard: nom + 2 cognoms → "I. CognomPenúltim"', () => {
    // Per "Albert Gómez Ametller", l'última paraula és Ametller (cognom 2)
    // i la penúltima és Gómez (cognom 1). El primer cognom mostrat és Gómez.
    expect(formatarNomJugador('Albert Gómez Ametller')).toBe('A. Gómez');
  });

  it('dos noms + cognom: "J. M. Cognom"', () => {
    expect(formatarNomJugador('José María Campos Gonzalez')).toBe('J. M. Campos');
  });

  it('connector català "i" entre cognoms: "Joan Garcia i Pujol"', () => {
    expect(formatarNomJugador('Joan Garcia i Pujol')).toBe('J. Garcia');
  });

  it('connector català "i" amb noms compostos: "Francesc Pi i Margall"', () => {
    expect(formatarNomJugador('Francesc Pi i Margall')).toBe('F. Pi');
  });

  it('connector "I" majúscula també detectat (cas insensible)', () => {
    expect(formatarNomJugador('Joan Garcia I Pujol')).toBe('J. Garcia');
  });

  it('"i" al final no és connector (no hi ha cognom 2 darrere)', () => {
    // Per "Joan Garcia i", la "i" és al final → no és connector → format estàndard
    // 3 parts → l'últim és cognom2, el penúltim és cognom1, "Joan" és nom
    expect(formatarNomJugador('Joan Garcia i')).toBe('J. Garcia');
  });

  it('manté padding/spacing inconsistent', () => {
    expect(formatarNomJugador('  Joan   Garcia  ')).toBe('J. Garcia');
  });
});

describe('obtenirInicials', () => {
  it('retorna inicials sense punts', () => {
    expect(obtenirInicials('Albert Gómez Ametller')).toBe('AGA');
  });
  it('una sola paraula', () => {
    expect(obtenirInicials('Joan')).toBe('J');
  });
  it('cadena buida', () => {
    expect(obtenirInicials('')).toBe('');
    expect(obtenirInicials('   ')).toBe('');
  });
});

describe('nomComplertSoci / nomFormatatSoci', () => {
  it('amb soci nul retorna buit', () => {
    expect(nomComplertSoci(null)).toBe('');
    expect(nomComplertSoci(undefined)).toBe('');
    expect(nomFormatatSoci(null)).toBe('');
  });

  it('concatena nom + cognoms', () => {
    expect(nomComplertSoci({ nom: 'Joan', cognoms: 'Garcia Pujol' })).toBe('Joan Garcia Pujol');
  });

  it('format final via formatarNomJugador', () => {
    expect(nomFormatatSoci({ nom: 'Joan', cognoms: 'Garcia Pujol' })).toBe('J. Garcia');
  });

  it('amb cognoms en format català "Garcia i Pujol"', () => {
    expect(nomFormatatSoci({ nom: 'Joan', cognoms: 'Garcia i Pujol' })).toBe('J. Garcia');
  });

  it('robust amb camps null', () => {
    expect(nomFormatatSoci({ nom: null, cognoms: 'Garcia' })).toBe('Garcia');
    expect(nomFormatatSoci({ nom: 'Joan', cognoms: null })).toBe('Joan');
  });
});

describe('esNomValid', () => {
  it('cal mínim nom + cognom', () => {
    expect(esNomValid('Joan')).toBe(false);
    expect(esNomValid('Joan Garcia')).toBe(true);
  });
  it('rebutja buit', () => {
    expect(esNomValid('')).toBe(false);
    expect(esNomValid('   ')).toBe(false);
  });
});
