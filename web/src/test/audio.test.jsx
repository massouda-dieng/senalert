import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { extensionAudio, texteAParler } from '../lib/audio';
import Assistant from '../pages/citoyen/Assistant';

vi.mock('../auth/AuthContext', () => ({ useAuth: () => ({ utilisateur: { id: 1 } }) }));
vi.mock('../lib/config', () => ({ useConfig: () => globalThis.__config }));
vi.mock('../api/client', () => ({ api: vi.fn(async () => ({ reponse: 'Refroidissez la zone.', source: 'groq' })) }));
// jsdom ne fait pas défiler : l'assistant descend vers le dernier message.
Element.prototype.scrollIntoView = () => {};

describe('audio : utilitaires', () => {
  it('extension selon le type enregistré', () => {
    expect(extensionAudio('audio/webm;codecs=opus')).toBe('webm');
    expect(extensionAudio('audio/ogg;codecs=opus')).toBe('ogg');
    expect(extensionAudio('audio/mp4')).toBe('m4a');
    expect(extensionAudio('audio/wav')).toBe('wav');
    expect(extensionAudio('')).toBe('webm');
  });

  it('texte lu sans puces ni symboles', () => {
    expect(texteAParler('• Refroidissez **la zone**\n# Titre')).toBe('Refroidissez la zone Titre');
  });
});

describe('assistant : boutons audio', () => {
  const navigateur = () => {
    window.MediaRecorder = function MediaRecorder() {};
    Object.defineProperty(navigator, 'mediaDevices', { value: { getUserMedia: vi.fn() }, configurable: true });
  };
  const afficher = () => render(<MemoryRouter><Assistant /></MemoryRouter>);

  afterEach(() => {
    cleanup();
    delete window.MediaRecorder;
    delete navigator.mediaDevices;
    localStorage.clear();
  });

  it('micro affiché quand le serveur et le navigateur le permettent', () => {
    navigateur();
    globalThis.__config = { assistant_vocal: true };
    afficher();
    expect(screen.getByRole('button', { name: 'Dicter ma question' })).toBeInTheDocument();
  });

  it('micro masqué sans clé de transcription sur le serveur', () => {
    navigateur();
    globalThis.__config = { assistant_vocal: false };
    afficher();
    expect(screen.queryByRole('button', { name: 'Dicter ma question' })).not.toBeInTheDocument();
  });

  it('micro masqué si le navigateur ne sait pas enregistrer', () => {
    globalThis.__config = { assistant_vocal: true };
    afficher();
    expect(screen.queryByRole('button', { name: 'Dicter ma question' })).not.toBeInTheDocument();
  });

  it('bouton « Écouter » sur les réponses si la synthèse vocale existe', async () => {
    window.speechSynthesis = { cancel: vi.fn(), speak: vi.fn(), getVoices: () => [] };
    globalThis.__config = { assistant_vocal: false };
    afficher();
    fireEvent.click(screen.getByRole('button', { name: 'Que faire en cas de brûlure ?' }));
    expect(await screen.findByText('Refroidissez la zone.')).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: /Écouter/ })).toHaveLength(1);
    delete window.speechSynthesis;
  });
});

describe('assistant : comme une messagerie IA', () => {
  afterEach(() => { cleanup(); localStorage.clear(); });

  it('chaque visite ouvre une discussion vide, sans les anciennes questions', () => {
    localStorage.setItem('senalert.assistant.1', JSON.stringify([{ role: 'user', content: 'ancienne question' }]));
    globalThis.__config = { assistant_vocal: false };
    render(<MemoryRouter><Assistant /></MemoryRouter>);
    expect(screen.queryByText('ancienne question')).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /comment puis-je vous aider/ })).toBeInTheDocument();
    expect(localStorage.getItem('senalert.assistant.1')).toBeNull();
  });

  it('« Nouvelle discussion » vide la conversation en cours', async () => {
    globalThis.__config = { assistant_vocal: false };
    render(<MemoryRouter><Assistant /></MemoryRouter>);
    fireEvent.click(screen.getByRole('button', { name: 'Comment suivre mon signalement ?' }));
    expect(await screen.findByText('Refroidissez la zone.')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: /Nouvelle discussion/ }));
    expect(screen.queryByText('Refroidissez la zone.')).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /comment puis-je vous aider/ })).toBeInTheDocument();
  });
});
