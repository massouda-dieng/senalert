import clsx from 'clsx';
import { Crosshair, Eye, EyeOff, MessageCircle, Send, ThumbsUp, UsersRound } from 'lucide-react';
import { useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import Photo from '../../components/Photo';
import { BadgeStatut, Bandeau, Bouton, Chargement, EnTetePage, EtatErreur, EtatVide, Fenetre, Pagination, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { distance, ilYa } from '../../lib/format';
import { lirePosition } from '../citoyen/Accueil';

function Commentaires({ incident, onFermer, onChange }) {
  const { utilisateur } = useAuth();
  const toast = useToast();
  const { donnees, chargement, recharger } = useRessource(`/incidents/communaute/${incident.id}/commentaires/`);
  const [texte, setTexte] = useState('');
  const [envoi, setEnvoi] = useState(false);
  const moderateur = utilisateur.role === 'superadmin';
  return (
    <Fenetre ouverte large onFermer={onFermer} titre={`${incident.categorie_libelle} — ${incident.region_libelle}`}>
      <Bandeau type="info" className="mb-4">Les messages sont visibles par tous les utilisateurs. N’y indiquez ni nom, ni numéro, ni adresse personnelle.</Bandeau>
      {chargement && !donnees ? <Chargement /> : (
        <ul className="space-y-3">
          {(donnees || []).length === 0 && <li className="text-sm text-texte-doux">Aucun message pour l’instant.</li>}
          {(donnees || []).map((c) => (
            <li key={c.id} className={clsx('rounded-2xl p-3 text-sm', c.est_mien ? 'bg-marque-50' : 'bg-surface-douce', c.masque && 'opacity-50')}>
              <div className="flex items-center justify-between gap-2">
                <p className="font-semibold">{c.auteur_nom}</p>
                <div className="flex items-center gap-2 text-xs text-texte-pale">{ilYa(c.date)}
                  {moderateur && (
                    <button type="button" title={c.masque ? 'Rétablir' : 'Masquer'} aria-label={c.masque ? 'Rétablir le message' : 'Masquer le message'} className="rounded p-1 hover:bg-surface"
                      onClick={async () => { await api(`/incidents/communaute/commentaires/${c.id}/masquer/`, { methode: 'POST', corps: { masque: !c.masque } }); recharger(true); toast('Modération enregistrée.'); }}>
                      {c.masque ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                    </button>
                  )}
                </div>
              </div>
              <p className="mt-1 whitespace-pre-wrap">{c.texte}</p>
            </li>
          ))}
        </ul>
      )}
      <form className="mt-4 flex gap-2" onSubmit={async (e) => {
        e.preventDefault();
        if (texte.trim().length < 3) return;
        setEnvoi(true);
        try {
          await api(`/incidents/communaute/${incident.id}/commentaires/`, { methode: 'POST', corps: { texte: texte.trim() } });
          setTexte(''); recharger(true); onChange();
        } catch (err) { toast(err.detail, 'erreur'); } finally { setEnvoi(false); }
      }}>
        <input className="champ" value={texte} onChange={(e) => setTexte(e.target.value)} maxLength={500} placeholder="Information utile (accès, évolution…)" aria-label="Votre message" />
        <Bouton type="submit" icone={Send} chargement={envoi} disabled={texte.trim().length < 3}>Publier</Bouton>
      </form>
    </Fenetre>
  );
}

/** Fil communautaire : incidents récents autour de soi, confirmations et échanges. */
export default function Communaute() {
  const { utilisateur } = useAuth();
  const config = useConfig();
  const toast = useToast();
  const citoyen = utilisateur.role === 'citoyen';
  const [position, setPosition] = useState(null);
  const [rayon, setRayon] = useState('10');
  const [jours, setJours] = useState('7');
  const [type, setType] = useState('');
  const [page, setPage] = useState(1);
  const [discussion, setDiscussion] = useState(null);
  const params = { page, jours, type_incident: type, ...(position ? { lat: position.lat, lng: position.lng, rayon_km: rayon } : {}) };
  const { donnees, chargement, erreur, recharger, setDonnees } = useRessource('/incidents/communaute/', params, { intervalle: 60000 });
  const liste = donnees?.results || [];

  const localiser = async () => {
    const p = await lirePosition();
    if (p.erreur) toast(p.erreur, 'erreur'); else { setPosition(p); setPage(1); }
  };
  const confirmer = async (inc) => {
    try {
      const r = await api(`/incidents/communaute/${inc.id}/confirmer/`, { methode: inc.je_confirme ? 'DELETE' : 'POST' });
      setDonnees((d) => ({ ...d, results: d.results.map((x) => (x.id === inc.id ? { ...x, ...r } : x)) }));
    } catch (e) { toast(e.detail, 'erreur'); }
  };

  return (
    <>
      <div className="relative mb-6 overflow-hidden rounded-3xl">
        <Photo nom="croix-rouge-equipe" className="absolute inset-0 h-full w-full" alt="" credit={false} />
        <div className="absolute inset-0 bg-gradient-to-r from-black/80 via-black/50 to-black/5" aria-hidden />
        <div className="relative px-6 py-8 text-white sm:px-8">
          <h1 className="font-titre text-3xl font-extrabold">{citoyen ? 'Autour de moi' : 'Communauté'}</h1>
          <p className="mt-1 max-w-xl text-white/85">{citoyen ? 'Les incidents signalés près de chez vous. Confirmez ceux que vous constatez : cela aide les secours à prioriser.' : 'Confirmations et messages des citoyens. Masquez les messages qui ne respectent pas les règles.'}</p>
          <div className="mt-5 flex flex-wrap gap-2">
            {citoyen && <Bouton variante="secondaire" icone={Crosshair} onClick={localiser}>{position ? 'Actualiser ma position' : 'Me localiser'}</Bouton>}
            {position && <Selecteur aria-label="Rayon" vide={null} valeur={rayon} onChange={(v) => { setRayon(v); setPage(1); }} className="w-auto"
              options={[{ code: '2', libelle: '2 km' }, { code: '5', libelle: '5 km' }, { code: '10', libelle: '10 km' }, { code: '50', libelle: '50 km' }]} />}
            <Selecteur aria-label="Période" vide={null} valeur={jours} onChange={(v) => { setJours(v); setPage(1); }} className="w-auto"
              options={[{ code: '1', libelle: '24 heures' }, { code: '7', libelle: '7 jours' }, { code: '30', libelle: '30 jours' }]} />
            <Selecteur aria-label="Catégorie" valeur={type} onChange={(v) => { setType(v); setPage(1); }} vide="Toutes catégories" className="w-auto" options={config.categories} />
          </div>
        </div>
      </div>
      <EtatErreur erreur={erreur} onReessayer={recharger} />
      <div className="space-y-3">
        {chargement && !donnees ? <Chargement /> : liste.length === 0 ? (
          <EtatVide icone={UsersRound} titre="Aucun incident récent" texte={position ? 'Rien n’a été signalé dans ce rayon sur la période.' : citoyen ? 'Localisez-vous pour voir les incidents proches.' : 'Rien n’a été signalé sur la période.'} />
        ) : liste.map((i) => (
          <article key={i.id} className="carte flex flex-wrap items-center gap-4 p-4">
            <span className="h-12 w-1.5 rounded-full" style={{ background: config.categorie(i.type_incident)?.couleur }} aria-hidden />
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2"><h2 className="font-bold">{i.categorie_libelle}</h2><BadgeStatut statut={i.statut} /></div>
              <p className="text-sm text-texte-doux">{i.region_libelle} · {ilYa(i.date_creation)}{i.distance_m != null ? ` · à ${distance(i.distance_m)}` : ''}{i.est_mien ? ' · votre signalement' : ''}</p>
            </div>
            <div className="flex gap-2">
              {citoyen && !i.est_mien && (
                <Bouton taille="sm" variante={i.je_confirme ? 'succes' : 'secondaire'} icone={ThumbsUp} onClick={() => confirmer(i)} aria-pressed={i.je_confirme}>
                  {i.je_confirme ? 'Confirmé' : 'Je le vois aussi'} · {i.nb_confirmations}
                </Bouton>
              )}
              {(!citoyen || i.est_mien) && <span className="inline-flex items-center gap-1 rounded-xl bg-surface-douce px-3 text-sm"><ThumbsUp className="h-4 w-4" />{i.nb_confirmations}</span>}
              <Bouton taille="sm" variante="secondaire" icone={MessageCircle} onClick={() => setDiscussion(i)}>{i.nb_commentaires}</Bouton>
            </div>
          </article>
        ))}
        {donnees && <Pagination page={page} total={donnees.count} onPage={setPage} />}
      </div>
      {discussion && <Commentaires incident={discussion} onFermer={() => setDiscussion(null)} onChange={() => recharger(true)} />}
    </>
  );
}
