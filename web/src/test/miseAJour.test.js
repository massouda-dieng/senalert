import { describe, expect, it } from 'vitest';
import { occupe, versionDepuisHtml } from '../lib/miseAJour';

describe('mise à jour automatique', () => {
  it('lit la version dans la page du serveur', () => {
    expect(versionDepuisHtml('<script type="module" src="/static/assets/index-DIhkGyuH.js"></script>')).toBe('assets/index-DIhkGyuH.js');
    expect(versionDepuisHtml('<html></html>')).toBeNull();
  });

  it('ne recharge pas pendant une saisie ou une fenêtre ouverte', () => {
    document.body.innerHTML = '<input type="text" value=""><input type="checkbox" value="on">';
    expect(occupe()).toBe(false);
    document.querySelector('input').value = 'Awa';
    expect(occupe()).toBe(true);
    document.body.innerHTML = '<div role="dialog"></div>';
    expect(occupe()).toBe(true);
  });
});
