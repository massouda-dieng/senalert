import clsx from 'clsx';
import { ExternalLink, RefreshCw, RotateCw, Smartphone } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { BandeDrapeau, Logo } from '../components/Logo';

/** Appareils proposés (dimensions CSS des écrans réels). */
const APPAREILS = {
  iphone15: { libelle: 'iPhone 15', l: 393, h: 852, ios: true },
  iphoneSE: { libelle: 'iPhone SE', l: 375, h: 667, ios: true, bouton: true },
  pixel7: { libelle: 'Google Pixel 7', l: 412, h: 915 },
  galaxyA: { libelle: 'Samsung Galaxy A14', l: 384, h: 854 },
  petit: { libelle: 'Petit Android (360 px)', l: 360, h: 740 },
};

/**
 * Simulateur : la vraie application Flutter (compilée pour le web et servie par
 * Django sous /mobile/) affichée dans un cadre de téléphone, avec l'API réelle.
 */
function Heure() {
  const [h, setH] = useState(() => new Date());
  useEffect(() => { const t = setInterval(() => setH(new Date()), 30000); return () => clearInterval(t); }, []);
  return <span>{h.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}</span>;
}

export default function Simulateur() {
  const [appareil, setAppareil] = useState('iphone15');
  const [paysage, setPaysage] = useState(false);
  const [cle, setCle] = useState(0);
  const [etat, setEtat] = useState('verification');
  const [echelle, setEchelle] = useState(1);
  const zone = useRef(null);
  const a = APPAREILS[appareil];
  const largeur = paysage ? a.h : a.l;
  const hauteur = paysage ? a.l : a.h;
  const cadre = a.bouton ? 18 : 14;

  useEffect(() => {
    fetch('/mobile/', { method: 'GET', cache: 'no-store' }).then((r) => setEtat(r.ok ? 'pret' : 'absent')).catch(() => setEtat('absent'));
  }, []);

  useEffect(() => {
    const ajuster = () => {
      const el = zone.current;
      if (!el) return;
      const dispo = { l: el.clientWidth - 32, h: window.innerHeight - 170 };
      const total = { l: largeur + cadre * 2, h: hauteur + cadre * 2 + (a.bouton && !paysage ? 110 : 0) };
      setEchelle(Math.min(1, dispo.l / total.l, dispo.h / total.h));
    };
    ajuster();
    window.addEventListener('resize', ajuster);
    return () => window.removeEventListener('resize', ajuster);
  }, [largeur, hauteur, cadre, a.bouton, paysage]);

  return (
    <div className="flex min-h-screen flex-col bg-[#0B1210] text-white">
      <BandeDrapeau className="h-1" />
      <header className="flex flex-wrap items-center gap-3 border-b border-white/10 px-4 py-3 sm:px-6">
        <Link to="/" className="flex items-center gap-2"><Logo className="h-8 w-8" clair /><span className="font-titre text-lg font-extrabold">SenAlert</span></Link>
        <span className="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold text-white/80"><Smartphone className="mr-1 inline h-3.5 w-3.5" />Simulateur mobile</span>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          <select value={appareil} onChange={(e) => setAppareil(e.target.value)} aria-label="Appareil"
            className="rounded-xl border border-white/15 bg-white/5 px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-marque-500">
            {Object.entries(APPAREILS).map(([k, x]) => <option key={k} value={k} className="text-texte">{x.libelle} — {x.l}×{x.h}</option>)}
          </select>
          <button type="button" onClick={() => setPaysage((p) => !p)} className="inline-flex items-center gap-1.5 rounded-xl bg-white/10 px-3 py-2 text-sm hover:bg-white/15" aria-pressed={paysage}>
            <RotateCw className="h-4 w-4" /> {paysage ? 'Paysage' : 'Portrait'}
          </button>
          <button type="button" onClick={() => setCle((c) => c + 1)} className="inline-flex items-center gap-1.5 rounded-xl bg-white/10 px-3 py-2 text-sm hover:bg-white/15">
            <RefreshCw className="h-4 w-4" /> Redémarrer l’app
          </button>
          <a href="/mobile/" target="_blank" rel="noreferrer" className="inline-flex items-center gap-1.5 rounded-xl bg-marque-600 px-3 py-2 text-sm font-semibold hover:bg-marque-500">
            <ExternalLink className="h-4 w-4" /> Plein écran
          </a>
        </div>
      </header>

      <main ref={zone} className="flex flex-1 items-start justify-center overflow-hidden p-4 sm:items-center">
        {etat === 'absent' ? (
          <div className="max-w-lg rounded-3xl border border-white/10 bg-white/5 p-8 text-center">
            <Smartphone className="mx-auto h-10 w-10 text-or" />
            <h1 className="mt-3 font-titre text-2xl font-extrabold">Application mobile non compilée</h1>
            <p className="mt-2 text-white/70">Dans un terminal, lancez une fois :</p>
            <pre className="mt-3 rounded-xl bg-black/40 p-3 text-left text-sm text-or">cd ~/Documents/PFF/senalert{'\n'}./run.sh simulateur</pre>
            <p className="mt-3 text-sm text-white/60">puis rechargez cette page.</p>
          </div>
        ) : (
          <div style={{ transform: `scale(${echelle})`, transformOrigin: 'top center' }} className="transition-transform duration-300">
            <div className={clsx('relative bg-gradient-to-b from-[#2A2F2C] to-[#141716] shadow-[0_30px_80px_rgba(0,0,0,.6)] ring-1 ring-white/15',
              a.ios ? 'rounded-[3.2rem]' : 'rounded-[2.4rem]')} style={{ padding: cadre }}>
              {/* Boutons latéraux */}
              <span className="absolute -left-[3px] top-28 h-14 w-[3px] rounded-l bg-[#3a3f3c]" aria-hidden />
              <span className="absolute -right-[3px] top-36 h-20 w-[3px] rounded-r bg-[#3a3f3c]" aria-hidden />
              <div className={clsx('relative overflow-hidden bg-black', a.ios ? 'rounded-[2.6rem]' : 'rounded-[1.9rem]')} style={{ width: largeur, height: hauteur }}>
                <div className="flex h-full flex-col">
                  {/* Barre d'état : l'application ne passe jamais sous l'encoche */}
                  {!paysage && (
                    <div className={clsx('relative flex shrink-0 items-center justify-between bg-black px-7 text-[13px] font-semibold text-white', a.ios ? 'h-[47px]' : 'h-7 px-4 text-[11px]')}>
                      <Heure />
                      {a.ios && !a.bouton && <span className="absolute left-1/2 top-2.5 h-[30px] w-[118px] -translate-x-1/2 rounded-full bg-black ring-1 ring-white/5" aria-hidden />}
                      {!a.ios && <span className="absolute left-1/2 top-1.5 h-3.5 w-3.5 -translate-x-1/2 rounded-full bg-[#111] ring-2 ring-[#222]" aria-hidden />}
                      <span className="flex items-center gap-1.5" aria-hidden>
                        <span className="flex items-end gap-[2px]">{[4, 6, 8, 10].map((h) => <span key={h} className="w-[3px] rounded-sm bg-white" style={{ height: h }} />)}</span>
                        <span className="text-[11px]">4G</span>
                        <span className="relative h-[11px] w-[22px] rounded-[3px] border border-white/70"><span className="absolute inset-[1.5px] right-[5px] rounded-[1.5px] bg-white" /></span>
                      </span>
                    </div>
                  )}
                  {etat === 'pret' && (
                    <iframe key={`${cle}-${appareil}-${paysage}`} src="/mobile/" title={`Application SenAlert sur ${a.libelle}`}
                      className="w-full flex-1 border-0 bg-white" allow="geolocation; camera; clipboard-write" />
                  )}
                </div>
              </div>
              {a.bouton && !paysage && <div className="mx-auto mt-4 h-14 w-14 rounded-full border-2 border-white/15" aria-hidden />}
            </div>
            <p className="mt-4 text-center text-xs text-white/50">{a.libelle} · {largeur}×{hauteur} px · données réelles de l’API SenAlert</p>
          </div>
        )}
      </main>
      <footer className="px-6 pb-4 text-center text-xs text-white/40">
        Simulation dans le navigateur de l’application Flutter. Géolocalisation : autorisez-la quand Chrome la demande. Les notifications push ne sont disponibles que sur un vrai téléphone.
      </footer>
    </div>
  );
}
