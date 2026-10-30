import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { api, effacerJetons, enregistrerJetons, ErreurApi, surSessionExpiree } from '../api/client';

const json = (status, corps) => new Response(JSON.stringify(corps), { status, headers: { 'Content-Type': 'application/json' } });

describe('client API', () => {
  beforeEach(() => { effacerJetons(); sessionStorage.clear(); });
  afterEach(() => vi.restoreAllMocks());

  it('envoie le jeton et renvoie le JSON', async () => {
    enregistrerJetons({ access: 'A1', refresh: 'R1' });
    const f = vi.spyOn(global, 'fetch').mockResolvedValue(json(200, { ok: true }));
    expect(await api('/x/')).toEqual({ ok: true });
    expect(f.mock.calls[0][1].headers.Authorization).toBe('Bearer A1');
  });

  it('renouvelle la session sur 401 puis rejoue la requête une seule fois', async () => {
    enregistrerJetons({ access: 'expire', refresh: 'R1' });
    const f = vi.spyOn(global, 'fetch')
      .mockResolvedValueOnce(json(401, { detail: 'expiré' }))
      .mockResolvedValueOnce(json(200, { access: 'A2', refresh: 'R2' }))
      .mockResolvedValueOnce(json(200, { ok: 2 }));
    expect(await api('/x/')).toEqual({ ok: 2 });
    expect(f.mock.calls[1][0]).toContain('/auth/jeton/rafraichir/');
    expect(f.mock.calls[2][1].headers.Authorization).toBe('Bearer A2');
    expect(sessionStorage.getItem('senalert.refresh')).toBe('R2');
  });

  it('signale l’expiration quand le renouvellement échoue', async () => {
    enregistrerJetons({ access: 'expire', refresh: 'R1' });
    const ecouteur = vi.fn();
    const desabonner = surSessionExpiree(ecouteur);
    vi.spyOn(global, 'fetch').mockResolvedValueOnce(json(401, {})).mockResolvedValueOnce(json(401, {})).mockResolvedValueOnce(json(401, {}));
    await expect(api('/x/')).rejects.toMatchObject({ status: 401 });
    expect(ecouteur).toHaveBeenCalled();
    expect(sessionStorage.getItem('senalert.refresh')).toBeNull();
    desabonner();
  });

  it('normalise les erreurs de validation', async () => {
    vi.spyOn(global, 'fetch').mockResolvedValue(json(400, { detail: 'Email invalide', code: 'invalide', champs: { email: ['Email invalide'] } }));
    const e = await api('/x/', { methode: 'POST', corps: {} }).catch((x) => x);
    expect(e).toBeInstanceOf(ErreurApi);
    expect(e.champs.email[0]).toBe('Email invalide');
  });

  it('ne rejoue jamais automatiquement un POST en cas de coupure réseau', async () => {
    const f = vi.spyOn(global, 'fetch').mockRejectedValue(new TypeError('Failed to fetch'));
    const e = await api('/alertes/sos/', { methode: 'POST', corps: {} }).catch((x) => x);
    expect(e.code).toBe('reseau');
    expect(f).toHaveBeenCalledTimes(1);
  });

  it('réessaie une lecture après une coupure réseau', async () => {
    vi.useFakeTimers();
    const f = vi.spyOn(global, 'fetch').mockRejectedValueOnce(new TypeError('x')).mockResolvedValueOnce(json(200, { ok: 1 }));
    const p = api('/x/');
    await vi.runAllTimersAsync();
    expect(await p).toEqual({ ok: 1 });
    expect(f).toHaveBeenCalledTimes(2);
    vi.useRealTimers();
  });
});
