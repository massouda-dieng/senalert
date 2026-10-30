import { describe, expect, it } from 'vitest';
import WOLOF from '../../../traductions/wolof.json';
import { libelleCategorie, traduire } from '../lib/langue';

describe('traductions wolof', () => {
  it('traduit, remplace les valeurs et retombe sur le français', () => {
    expect(traduire('wo', 'Résolu')).toBe(WOLOF['Résolu']);
    expect(traduire('wo', 'Bonjour {nom}', { nom: 'Awa' })).toContain('Awa');
    expect(traduire('fr', 'Résolu')).toBe('Résolu');
    expect(traduire('wo', 'Texte sans traduction')).toBe('Texte sans traduction');
    expect(libelleCategorie('wo', 'incendie', 'Incendie')).toBe(WOLOF['categorie:incendie']);
    expect(libelleCategorie('fr', 'incendie', 'Incendie')).toBe('Incendie');
  });

  it('garde les mêmes variables {…} que le texte français', () => {
    const vars = (s) => (s.match(/\{\w+\}/g) || []).sort().join();
    Object.entries(WOLOF).filter(([k]) => !k.startsWith('_') && !k.startsWith('categorie:'))
      .forEach(([fr, wo]) => expect(vars(wo), fr).toBe(vars(fr)));
  });
});
