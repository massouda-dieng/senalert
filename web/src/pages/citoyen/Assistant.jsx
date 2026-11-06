import clsx from 'clsx';
import { Bot, Languages, Mic, Send, Siren, Square, SquarePen, Volume2, VolumeX, X } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../../api/client';
import { useAuth } from '../../auth/AuthContext';
import { Bandeau, Bouton } from '../../components/ui';
import { DUREE_MAX_S, dicteePossible, lecturePossible, useDictee, useLecture } from '../../lib/audio';
import { useConfig } from '../../lib/config';

const SUGGESTIONS = [
  'Comment signaler une inondation ?',
  'Que faire en cas de brûlure ?',
  'Comment me protéger pendant un incendie ?',
  'Comment suivre mon signalement ?',
  'Comment me préparer à l’hivernage ?',
  'Où trouver une pharmacie proche ?',
];

/**
 * Assistant, à la manière d'une messagerie IA : chaque visite ouvre une nouvelle discussion vide.
 * La conversation n'est gardée qu'en mémoire le temps de la page (ni sur l'appareil, ni sur le serveur).
 */
export default function Assistant() {
  const { utilisateur } = useAuth();
  const [messages, setMessages] = useState([]);
  const [texte, setTexte] = useState('');
  const [envoi, setEnvoi] = useState(false);
  const [erreurVocale, setErreurVocale] = useState(null);
  const [traduit, setTraduit] = useState(false);
  const fin = useRef(null);
  const champ = useRef(null);
  const config = useConfig();
  const avecMicro = Boolean(config?.assistant_vocal) && dicteePossible();
  const avecLecture = lecturePossible();
  const lecture = useLecture();
  // Le texte reconnu (traduit en français s'il était en wolof) s'ajoute au champ : le citoyen le relit avant d'envoyer.
  const surTexte = useCallback((reconnu, details) => {
    setErreurVocale(null);
    setTraduit(Boolean(details?.traduit));
    setTexte((t) => (t.trim() ? `${t.trim()} ${reconnu}` : reconnu).slice(0, 1000));
    champ.current?.focus();
  }, []);
  const dictee = useDictee({ surTexte, surErreur: setErreurVocale });
  const occupe = envoi || dictee.etat !== 'repos';
  const vide = messages.length === 0;

  // Les anciennes versions gardaient l'historique sur l'appareil : on l'efface.
  useEffect(() => { try { localStorage.removeItem(`senalert.assistant.${utilisateur.id}`); } catch { /* rien */ } }, [utilisateur.id]);
  useEffect(() => { if (!vide) fin.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages, envoi, vide]);

  const envoyer = async (contenu) => {
    const message = (contenu ?? texte).trim();
    if (!message || envoi) return;
    setTexte('');
    setTraduit(false);
    const historique = messages.filter((m) => !m.erreur).slice(-6).map((m) => ({ role: m.role, content: m.content }));
    setMessages((m) => [...m, { role: 'user', content: message }]);
    setEnvoi(true);
    try {
      const r = await api('/analyse/assistant/', { methode: 'POST', corps: { message, historique } });
      setMessages((m) => [...m, { role: 'assistant', content: r.reponse, source: r.source, alerte: r.alerte_urgence, fiches: r.fiches, actions: r.actions, avertissement: r.avertissement }]);
    } catch (e) {
      setMessages((m) => [...m, { role: 'assistant', content: e.detail, erreur: true }]);
    } finally { setEnvoi(false); }
  };

  const nouvelleDiscussion = () => {
    lecture.arreter();
    dictee.annuler();
    setMessages([]);
    setTexte('');
    setTraduit(false);
    setErreurVocale(null);
  };

  const saisie = (
    <div className="w-full">
      {erreurVocale && <Bandeau type="alerte" className="mb-2">{erreurVocale}</Bandeau>}
      {traduit && (
        <p className="mb-2 flex items-center gap-1.5 text-xs font-semibold text-marque-700" role="status">
          <Languages className="h-3.5 w-3.5" aria-hidden />Message vocal traduit du wolof : relisez-le avant d’envoyer.
        </p>
      )}
      {dictee.etat === 'enregistrement' ? (
        <div className="flex items-center gap-2 rounded-2xl border border-sos-fonce/30 bg-sos-clair px-3 py-2.5" role="status">
          <span className="h-2.5 w-2.5 animate-pulse rounded-full bg-sos-fonce" aria-hidden />
          <p className="flex-1 text-sm font-semibold text-sos-fonce">
            Je vous écoute… {dictee.secondes} s <span className="font-normal">/ {DUREE_MAX_S} s · français ou wolof</span>
          </p>
          <Bouton variante="fantome" taille="sm" icone={X} onClick={dictee.annuler}>Annuler</Bouton>
          <Bouton variante="danger" taille="sm" icone={Square} onClick={dictee.arreter}>Terminer</Bouton>
        </div>
      ) : (
        <form className="flex items-center gap-2 rounded-2xl border border-surface-bord bg-surface p-1.5 shadow-sm focus-within:border-marque-600"
          onSubmit={(e) => { e.preventDefault(); envoyer(); }}>
          <input ref={champ} className="min-w-0 flex-1 bg-transparent px-3 py-2 text-sm outline-none" value={texte} maxLength={1000}
            onChange={(e) => { setTexte(e.target.value); if (!e.target.value) setTraduit(false); }}
            placeholder={dictee.etat === 'transcription' ? 'Transcription de votre message vocal…' : 'Posez votre question, en français ou à voix haute en wolof…'}
            aria-label="Votre question" disabled={dictee.etat === 'transcription'} />
          {avecMicro && (
            <Bouton variante="fantome" icone={Mic} onClick={() => { setErreurVocale(null); lecture.arreter(); dictee.demarrer(); }}
              chargement={dictee.etat === 'transcription'} disabled={occupe} aria-label="Dicter ma question" title="Dicter ma question (français ou wolof)" />
          )}
          <Bouton type="submit" icone={Send} chargement={envoi} disabled={!texte.trim() || occupe} aria-label="Envoyer" title="Envoyer" />
        </form>
      )}
    </div>
  );

  if (vide) {
    return (
      <div className="mx-auto flex min-h-[calc(100vh-12rem)] max-w-3xl flex-col items-center justify-center px-1 py-8">
        <Bot className="h-11 w-11 text-marque-600" aria-hidden />
        <h1 className="mt-3 text-center font-titre text-2xl font-extrabold sm:text-3xl">
          {`Bonjour ${utilisateur.first_name || ''}`.trim()}, comment puis-je vous aider ?
        </h1>
        <p className="mt-2 max-w-xl text-center text-sm text-texte-doux">
          Conseils de prévention et aide à l’utilisation de SenAlert. Ne remplace pas les secours ni un avis médical.
        </p>
        <div className="mt-6 w-full">{saisie}</div>
        <div className="mt-4 flex flex-wrap justify-center gap-2">
          {SUGGESTIONS.map((s) => <button key={s} type="button" onClick={() => envoyer(s)} className="rounded-full border border-surface-bord px-3.5 py-1.5 text-sm hover:bg-surface-douce">{s}</button>)}
        </div>
        <p className="mt-6 text-center text-xs text-texte-doux">N’indiquez pas d’informations personnelles. Pour une urgence, utilisez le bouton SOS.</p>
      </div>
    );
  }

  return (
    <div className="mx-auto flex h-[calc(100vh-12rem)] max-w-3xl flex-col">
      <div className="mb-3 flex items-center justify-between gap-2">
        <h1 className="flex items-center gap-2 font-titre text-lg font-bold"><Bot className="h-5 w-5 text-marque-600" aria-hidden />Assistant SenAlert</h1>
        <Bouton variante="fantome" taille="sm" icone={SquarePen} onClick={nouvelleDiscussion}>Nouvelle discussion</Bouton>
      </div>
      <div className="flex-1 space-y-5 overflow-y-auto px-1 pb-4" aria-live="polite">
        {messages.map((m, i) => (
          <div key={i} className={clsx('flex', m.role === 'user' ? 'justify-end' : 'justify-start gap-3')}>
            {m.role === 'assistant' && <span className="mt-1 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-marque-800 text-white"><Bot className="h-4 w-4" aria-hidden /></span>}
            <div className={clsx('space-y-2 text-sm', m.role === 'user' ? 'max-w-[80%] rounded-3xl bg-surface-douce px-4 py-2.5' : m.erreur ? 'max-w-[90%] rounded-2xl bg-sos-clair px-4 py-3 text-sos-fonce' : 'max-w-[90%] pt-1')}>
              {m.alerte && <p className="flex gap-2 rounded-xl bg-sos-fonce px-3 py-2 font-semibold text-white"><Siren className="h-4 w-4 shrink-0" />{m.alerte}</p>}
              <p className="whitespace-pre-wrap leading-relaxed">{m.content}</p>
              {m.fiches?.length > 0 && <p className="text-xs">Fiches utiles : {m.fiches.map((f, j) => <span key={f.slug}>{j > 0 && ', '}<Link className="lien" to="/citoyen/secours">{f.titre}</Link></span>)}</p>}
              {m.actions?.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {m.actions.map((a) => <Link key={a.cible} to={a.cible} className="rounded-full bg-marque-800 px-3 py-1 text-xs font-semibold text-white hover:bg-marque-700">{a.libelle}</Link>)}
                </div>
              )}
              {m.source && <p className="text-[11px] text-texte-doux">{m.source === 'groq' ? 'Réponse générée par IA, indicative.' : 'Mode secours (sans IA), d’après les fiches SenAlert.'} {m.avertissement}</p>}
              {avecLecture && m.role === 'assistant' && !m.erreur && (
                <button type="button" onClick={() => lecture.lire(i, [m.alerte, m.content].filter(Boolean).join('. '))}
                  className="inline-flex items-center gap-1.5 rounded-full border border-surface-bord bg-surface px-2.5 py-1 text-xs font-semibold hover:bg-surface-douce"
                  aria-pressed={lecture.enCours === i}>
                  {lecture.enCours === i ? <><VolumeX className="h-3.5 w-3.5" aria-hidden />Arrêter la lecture</> : <><Volume2 className="h-3.5 w-3.5" aria-hidden />Écouter</>}
                </button>
              )}
            </div>
          </div>
        ))}
        {envoi && <p className="pl-10 text-sm text-texte-doux">L’assistant rédige une réponse…</p>}
        <div ref={fin} />
      </div>
      {saisie}
      <p className="mt-2 text-center text-[11px] text-texte-doux">N’indiquez pas d’informations personnelles. Pour une urgence, utilisez le bouton SOS.</p>
    </div>
  );
}
