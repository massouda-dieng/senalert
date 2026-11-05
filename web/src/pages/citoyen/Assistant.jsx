import clsx from 'clsx';
import { Bot, Mic, Send, Siren, Square, Trash2, Volume2, VolumeX, X } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../../api/client';
import { useAuth } from '../../auth/AuthContext';
import { Bandeau, Bouton, EnTetePage } from '../../components/ui';
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

/** Assistant : historique conservé sur cet appareil uniquement (pas sur le serveur). */
export default function Assistant() {
  const { utilisateur } = useAuth();
  const cle = `senalert.assistant.${utilisateur.id}`;
  const [messages, setMessages] = useState(() => { try { return JSON.parse(localStorage.getItem(cle) || '[]'); } catch { return []; } });
  const [texte, setTexte] = useState('');
  const [envoi, setEnvoi] = useState(false);
  const [erreurVocale, setErreurVocale] = useState(null);
  const fin = useRef(null);
  const champ = useRef(null);
  const config = useConfig();
  const avecMicro = Boolean(config?.assistant_vocal) && dicteePossible();
  const avecLecture = lecturePossible();
  const lecture = useLecture();
  // Le texte reconnu s'ajoute au champ : le citoyen le relit (et le corrige) avant d'envoyer.
  const surTexte = useCallback((reconnu) => {
    setErreurVocale(null);
    setTexte((t) => (t.trim() ? `${t.trim()} ${reconnu}` : reconnu).slice(0, 1000));
    champ.current?.focus();
  }, []);
  const dictee = useDictee({ surTexte, surErreur: setErreurVocale });
  const occupe = envoi || dictee.etat !== 'repos';
  useEffect(() => { try { localStorage.setItem(cle, JSON.stringify(messages.slice(-30))); } catch { /* rien */ } fin.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages, cle]);

  const envoyer = async (contenu) => {
    const message = (contenu ?? texte).trim();
    if (!message || envoi) return;
    setTexte('');
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

  return (
    <div className="mx-auto flex h-[calc(100vh-12rem)] max-w-3xl flex-col">
      <EnTetePage titre="Assistant SenAlert" sousTitre="Conseils de prévention et aide à l’utilisation. Ne remplace pas les secours ni un avis médical."
        actions={messages.length > 0 && <Bouton variante="fantome" taille="sm" icone={Trash2} onClick={() => { lecture.arreter(); setMessages([]); }}>Effacer</Bouton>} />
      <div className="carte flex-1 space-y-4 overflow-y-auto p-4 sm:p-5" aria-live="polite">
        {messages.length === 0 && (
          <div className="py-6 text-center">
            <Bot className="mx-auto h-10 w-10 text-marque-600" />
            <p className="mt-2 font-semibold">Posez une question</p>
            <div className="mt-4 flex flex-wrap justify-center gap-2">
              {SUGGESTIONS.map((s) => <button key={s} type="button" onClick={() => envoyer(s)} className="rounded-full border border-surface-bord px-3.5 py-1.5 text-sm hover:bg-surface-douce">{s}</button>)}
            </div>
          </div>
        )}
        {messages.map((m, i) => (
          <div key={i} className={clsx('flex', m.role === 'user' ? 'justify-end' : 'justify-start')}>
            <div className={clsx('max-w-[85%] space-y-2 rounded-2xl px-4 py-3 text-sm', m.role === 'user' ? 'bg-marque-800 text-white' : m.erreur ? 'bg-sos-clair text-sos-fonce' : 'bg-surface-douce')}>
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
        {envoi && <p className="text-sm text-texte-doux">L’assistant rédige une réponse…</p>}
        <div ref={fin} />
      </div>
      {erreurVocale && <Bandeau type="alerte" className="mt-3">{erreurVocale}</Bandeau>}
      {dictee.etat === 'enregistrement' ? (
        <div className="mt-3 flex items-center gap-2 rounded-xl border border-sos-fonce/30 bg-sos-clair px-3 py-2" role="status">
          <span className="h-2.5 w-2.5 animate-pulse rounded-full bg-sos-fonce" aria-hidden />
          <p className="flex-1 text-sm font-semibold text-sos-fonce">
            Je vous écoute… {dictee.secondes} s <span className="font-normal">/ {DUREE_MAX_S} s</span>
          </p>
          <Bouton variante="fantome" taille="sm" icone={X} onClick={dictee.annuler}>Annuler</Bouton>
          <Bouton variante="danger" taille="sm" icone={Square} onClick={dictee.arreter}>Terminer</Bouton>
        </div>
      ) : (
        <form className="mt-3 flex gap-2" onSubmit={(e) => { e.preventDefault(); envoyer(); }}>
          <input ref={champ} className="champ" value={texte} onChange={(e) => setTexte(e.target.value)} maxLength={1000}
            placeholder={dictee.etat === 'transcription' ? 'Transcription de votre message vocal…' : 'Votre question…'} aria-label="Votre question" disabled={dictee.etat === 'transcription'} />
          {avecMicro && (
            <Bouton variante="secondaire" icone={Mic} onClick={() => { setErreurVocale(null); lecture.arreter(); dictee.demarrer(); }}
              chargement={dictee.etat === 'transcription'} disabled={occupe} aria-label="Dicter ma question" title="Dicter ma question" />
          )}
          <Bouton type="submit" icone={Send} chargement={envoi} disabled={!texte.trim() || occupe}>Envoyer</Bouton>
        </form>
      )}
      <Bandeau type="info" className="mt-3">N’indiquez pas d’informations personnelles (nom, téléphone). Pour une urgence, utilisez le bouton SOS.</Bandeau>
    </div>
  );
}
