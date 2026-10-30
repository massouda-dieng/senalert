import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import Photo from '../components/Photo';
import { BadgeStatut, Confirmation, Pagination } from '../components/ui';
import { CREDITS } from '../lib/photos';
import { distance, duree } from '../lib/format';

vi.mock('../auth/AuthContext', async (orig) => {
  const mod = await orig();
  return { ...mod, useAuth: () => globalThis.__auth };
});

describe('formatage', () => {
  it('distances et durées', () => {
    expect(distance(850)).toBe('850 m');
    expect(distance(2340)).toBe('2,3 km');
    expect(duree(75)).toBe('1 h 15');
    expect(duree(null)).toBe('—');
  });
});

describe('composants', () => {
  it('badge de statut lisible (pas seulement une couleur)', () => {
    render(<BadgeStatut statut="en_cours" />);
    expect(screen.getByText('En cours')).toBeInTheDocument();
  });

  it('pagination', async () => {
    const onPage = vi.fn();
    render(<Pagination page={1} total={45} onPage={onPage} />);
    expect(screen.getByText(/page 1\/3/)).toBeInTheDocument();
    await userEvent.click(screen.getByLabelText('Page suivante'));
    expect(onPage).toHaveBeenCalledWith(2);
  });

  it('confirmation exige un motif pour une action sensible', async () => {
    const onConfirmer = vi.fn().mockResolvedValue();
    render(<Confirmation ouverte onFermer={() => {}} titre="Annuler" message="m" motif="Motif" libelleAction="Valider" onConfirmer={onConfirmer} />);
    const bouton = screen.getByRole('button', { name: 'Valider' });
    expect(bouton).toBeDisabled();
    await userEvent.type(screen.getByLabelText(/Motif/), 'Fausse alerte');
    await userEvent.click(bouton);
    await waitFor(() => expect(onConfirmer).toHaveBeenCalledWith('Fausse alerte'));
  });
});

describe('photos d’illustration', () => {
  it('chaque photo a un auteur, une licence et une source', () => {
    expect(CREDITS.length).toBeGreaterThanOrEqual(9);
    CREDITS.forEach((c) => { expect(c.licence).toBeTruthy(); expect(c.source).toMatch(/^https:\/\/commons\.wikimedia\.org/); });
  });

  it('le crédit de licence est affiché avec l’image', () => {
    render(<Photo nom="pompiers-bnsp" alt="Pompiers" />);
    expect(screen.getByAltText('Pompiers')).toBeInTheDocument();
    expect(screen.getByText(/CC BY-SA 4\.0/)).toBeInTheDocument();
  });
});

describe('garde des espaces par rôle', () => {
  const rendre = async (role, chemin) => {
    globalThis.__auth = { initialise: true, utilisateur: role ? { role } : null };
    const { default: App } = await import('../App');
    render(<MemoryRouter initialEntries={[chemin]}><Routes><Route path="/*" element={<App />} /></Routes></MemoryRouter>);
  };

  it('un citoyen ne peut pas afficher la supervision', async () => {
    vi.doMock('../components/Layout', () => ({ default: () => { const { Outlet } = require('react-router-dom'); return <Outlet />; } }));
    vi.doMock('../pages/citoyen/Accueil', () => ({ default: () => <p>accueil citoyen</p> }));
    vi.doMock('../pages/admin/Supervision', () => ({ default: () => <p>supervision</p> }));
    await rendre('citoyen', '/supervision');
    expect(await screen.findByText('accueil citoyen')).toBeInTheDocument();
    expect(screen.queryByText('supervision')).not.toBeInTheDocument();
  }, 20000);
});
