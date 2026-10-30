import { AlertTriangle, BookOpenCheck, ChevronLeft, Phone, Search, WifiOff } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { api } from '../../api/client';
import { Bandeau, Carte, Chargement, EnTetePage, EtatVide } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { date } from '../../lib/format';

const CACHE = 'senalert.fiches-secours';

/** Fiches de premiers secours : chargées depuis l'API puis conservées pour la consultation hors ligne. */
export default function Guide() {
  const config = useConfig();
  const [fiches, setFiches] = useState(() => { try { return JSON.parse(localStorage.getItem(CACHE) || 'null'); } catch { return null; } });
  const [horsLigne, setHorsLigne] = useState(false);
  const [q, setQ] = useState('');
  const [choix, setChoix] = useState(null);

  useEffect(() => {
    api('/fiches-secours/', { auth: false })
      .then((f) => { setFiches(f); setHorsLigne(false); try { localStorage.setItem(CACHE, JSON.stringify(f)); } catch { /* rien */ } })
      .catch(() => setHorsLigne(true));
  }, []);

  const filtrees = useMemo(() => {
    const n = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
    return (fiches || []).filter((f) => !q || n(`${f.titre} ${f.resume} ${f.categorie}`).includes(n(q)));
  }, [fiches, q]);
  const groupes = useMemo(() => filtrees.reduce((g, f) => ({ ...g, [f.categorie]: [...(g[f.categorie] || []), f] }), {}), [filtrees]);
  const fiche = fiches?.find((f) => f.slug === choix);

  if (!fiches) return horsLigne ? <EtatVide icone={WifiOff} titre="Guide indisponible hors connexion" texte="Ouvrez cette page une fois en ligne pour l’enregistrer sur cet appareil." /> : <Chargement />;

  if (fiche) {
    return (
      <div className="mx-auto max-w-2xl">
        <button type="button" className="lien mb-4 inline-flex items-center gap-1 text-sm" onClick={() => setChoix(null)}><ChevronLeft className="h-4 w-4" /> Toutes les fiches</button>
        <h1 className="text-2xl font-extrabold">{fiche.titre}</h1>
        <p className="mt-1 text-texte-doux">{fiche.resume}</p>
        {!fiche.validee && <Bandeau type="alerte" className="mt-4">Fiche rédigée d’après les recommandations citées, en attente de validation par un professionnel de santé.</Bandeau>}
        <Carte className="mt-5" titre="Que faire ?">
          <ol className="space-y-3">
            {fiche.etapes.map((e, i) => (
              <li key={i} className="flex gap-3"><span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-marque-800 text-sm font-bold text-white">{i + 1}</span><span className="pt-0.5">{e}</span></li>
            ))}
          </ol>
        </Carte>
        {fiche.a_eviter?.length > 0 && (
          <Carte className="mt-4" titre="À éviter">
            <ul className="space-y-2">{fiche.a_eviter.map((e) => <li key={e} className="flex gap-2"><AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-600" />{e}</li>)}</ul>
          </Carte>
        )}
        {fiche.appeler_si && (
          <div className="mt-4 rounded-2xl bg-sos p-4 text-white">
            <p className="font-bold">Appelez les secours : {fiche.appeler_si}</p>
            <div className="mt-2 flex flex-wrap gap-2">{config.numeros_urgence.map((n) => <a key={n.numero} href={`tel:${n.numero}`} className="inline-flex items-center gap-1 rounded-full bg-white/15 px-3 py-1 text-sm font-semibold"><Phone className="h-3.5 w-3.5" />{n.service} {n.numero}</a>)}</div>
          </div>
        )}
        <p className="mt-4 text-xs text-texte-pale">Sources : {fiche.sources.join(' ; ')} · mise à jour le {date(fiche.date_mise_a_jour)}{fiche.valide_par ? ` · validée par ${fiche.valide_par}` : ''}.</p>
      </div>
    );
  }

  return (
    <>
      <EnTetePage titre="Premiers secours" sousTitre="Gestes essentiels en attendant les secours. Disponible hors connexion après une première consultation." />
      {horsLigne && <Bandeau type="info" className="mb-4">Mode hors connexion : affichage de la dernière version enregistrée.</Bandeau>}
      <div className="relative mb-5 max-w-md">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-texte-pale" />
        <input className="champ pl-9" placeholder="Rechercher : brûlure, saignement…" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Rechercher une fiche" />
      </div>
      {Object.entries(groupes).map(([cat, liste]) => (
        <section key={cat} className="mb-6">
          <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-texte-doux">{cat}</h2>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {liste.map((f) => (
              <button key={f.slug} type="button" onClick={() => setChoix(f.slug)} className="carte p-4 text-left transition hover:-translate-y-0.5 hover:shadow-flottant">
                <BookOpenCheck className="mb-2 h-5 w-5 text-sos" />
                <p className="font-semibold">{f.titre}</p>
                <p className="mt-1 text-sm text-texte-doux">{f.resume}</p>
              </button>
            ))}
          </div>
        </section>
      ))}
      {filtrees.length === 0 && <EtatVide titre="Aucune fiche ne correspond" />}
    </>
  );
}
