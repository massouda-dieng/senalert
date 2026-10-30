import { Eye, EyeOff, LogIn, MailCheck, ShieldCheck } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../../api/client';
import { ESPACE_PAR_ROLE, useAuth } from '../../auth/AuthContext';
import { BandeDrapeau, Logo } from '../../components/Logo';
import Photo from '../../components/Photo';
import { Bandeau, Bouton, Champ, Selecteur } from '../../components/ui';
import { useConfig } from '../../lib/config';

function Cadre({ titre, sousTitre, children }) {
  const config = useConfig();
  return (
    <div className="grid min-h-screen lg:grid-cols-[1.1fr_1fr]">
      <div className="relative hidden overflow-hidden lg:flex lg:flex-col">
        <Photo nom="pompiers-bnsp" className="absolute inset-0 h-full w-full" alt="Brigade nationale des sapeurs-pompiers" priorite />
        <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/55 to-black/10" aria-hidden />
        <BandeDrapeau className="relative h-1.5" />
        <div className="relative flex items-center gap-3 p-12 text-white"><Logo className="h-11 w-11" clair /><span className="font-titre text-2xl font-extrabold">SenAlert</span></div>
        <div className="relative mt-auto max-w-lg p-12 text-white">
          <h2 className="font-titre text-4xl font-extrabold leading-tight">Signaler. Coordonner.<br /><span className="text-or">Protéger.</span></h2>
          <p className="mt-4 text-white/80">Citoyens, agents de secours et superviseurs réunis sur un même canal, partout au Sénégal.</p>
          <div className="mt-8 flex flex-wrap gap-2">
            {config?.numeros_urgence?.map((n) => (
              <a key={n.numero} href={`tel:${n.numero}`} className="rounded-full bg-white/15 px-3.5 py-1.5 text-sm font-semibold ring-1 ring-white/25 hover:bg-white/25">{n.service} · {n.numero}</a>
            ))}
          </div>
          <p className="mt-6 text-xs text-white/60">SenAlert ne remplace pas les services officiels de secours.</p>
        </div>
      </div>
      <div className="flex items-center justify-center px-4 py-10 sm:px-8">
        <div className="w-full max-w-[420px]">
          <Link to="/" className="mb-8 flex items-center gap-2.5 lg:hidden"><Logo className="h-9 w-9" /><span className="font-titre text-xl font-extrabold">SenAlert</span></Link>
          <h1 className="text-[26px] font-extrabold">{titre}</h1>
          {sousTitre && <p className="mt-1.5 text-sm text-texte-doux">{sousTitre}</p>}
          <div className="mt-7">{children}</div>
        </div>
      </div>
    </div>
  );
}

function ChampMotDePasse({ id, valeur, onChange, autoComplete = 'current-password' }) {
  const [visible, setVisible] = useState(false);
  return (
    <div className="relative">
      <input id={id} type={visible ? 'text' : 'password'} className="champ pr-11" value={valeur} onChange={(e) => onChange(e.target.value)} autoComplete={autoComplete} required />
      <button type="button" onClick={() => setVisible((v) => !v)} className="absolute right-2 top-1/2 -translate-y-1/2 rounded-lg p-1.5 text-texte-pale hover:text-texte" aria-label={visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}>
        {visible ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
      </button>
    </div>
  );
}

/** Bouton Google Identity Services : l'ID token est vérifié par le backend, jamais côté navigateur. */
function BoutonGoogle({ onJeton }) {
  const config = useConfig();
  const ref = useRef(null);
  const [etat, setEtat] = useState('attente');
  const clientId = config?.google_client_id_web;
  const rappel = useRef(onJeton);
  rappel.current = onJeton;

  useEffect(() => {
    if (!config?.pret || !config.google_actif || !clientId) { setEtat('non_configure'); return undefined; }
    let annule = false;
    const initialiser = () => {
      if (annule || !window.google?.accounts?.id) return;
      window.google.accounts.id.initialize({ client_id: clientId, callback: (r) => rappel.current(r.credential), ux_mode: 'popup', use_fedcm_for_prompt: true });
      window.google.accounts.id.renderButton(ref.current, { theme: 'outline', size: 'large', width: 380, text: 'continue_with', locale: 'fr', shape: 'pill' });
      setEtat('pret');
    };
    if (window.google?.accounts?.id) initialiser();
    else {
      const s = document.createElement('script');
      s.src = 'https://accounts.google.com/gsi/client';
      s.async = true;
      s.onload = initialiser;
      s.onerror = () => setEtat('erreur');
      document.head.appendChild(s);
    }
    return () => { annule = true; };
  }, [config?.pret, config?.google_actif, clientId]);

  if (etat === 'non_configure') return <p className="rounded-xl bg-surface-douce px-3 py-2.5 text-center text-xs text-texte-doux">Connexion Google non configurée sur ce serveur (voir la documentation).</p>;
  if (etat === 'erreur') return <p className="text-center text-xs text-red-700">Le service Google est injoignable. Utilisez votre e-mail et votre mot de passe.</p>;
  return <div ref={ref} className="flex min-h-[44px] justify-center" />;
}

function useApresConnexion() {
  const navigate = useNavigate();
  const lieu = useLocation();
  return (u) => navigate(lieu.state?.depuis && lieu.state.depuis !== '/' ? lieu.state.depuis : ESPACE_PAR_ROLE[u.role] || '/', { replace: true });
}

export function Connexion() {
  const { connexion, connexionGoogle, sessionExpiree } = useAuth();
  const apres = useApresConnexion();
  const [identifiant, setIdentifiant] = useState('');
  const [mdp, setMdp] = useState('');
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);

  const google = async (jeton) => {
    setErreur(null);
    try { apres(await connexionGoogle(jeton)); } catch (e) { setErreur(e.detail); }
  };

  return (
    <Cadre titre="Connexion" sousTitre="Accédez à votre espace citoyen, agent ou supervision.">
      {sessionExpiree && <Bandeau type="alerte" className="mb-4">Votre session a expiré. Reconnectez-vous.</Bandeau>}
      <BoutonGoogle onJeton={google} />
      <div className="my-5 flex items-center gap-3 text-xs text-texte-pale"><span className="h-px flex-1 bg-surface-bord" />ou<span className="h-px flex-1 bg-surface-bord" /></div>
      <form className="space-y-4" onSubmit={async (e) => {
        e.preventDefault();
        setEnvoi(true);
        setErreur(null);
        try { apres(await connexion(identifiant.trim(), mdp)); } catch (err) { setErreur(err.detail); } finally { setEnvoi(false); }
      }}>
        <Champ libelle="E-mail ou identifiant">{(id) => <input id={id} className="champ" value={identifiant} onChange={(e) => setIdentifiant(e.target.value)} autoComplete="username" required autoFocus />}</Champ>
        <Champ libelle="Mot de passe">{(id) => <ChampMotDePasse id={id} valeur={mdp} onChange={setMdp} />}</Champ>
        <div className="flex justify-end"><Link to="/mot-de-passe-oublie" className="lien text-sm">Mot de passe oublié ?</Link></div>
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
        <Bouton type="submit" taille="lg" className="w-full" icone={LogIn} chargement={envoi}>Se connecter</Bouton>
      </form>
      <p className="mt-6 text-center text-sm text-texte-doux">Pas encore de compte ? <Link to="/inscription" className="lien">Créer un compte citoyen</Link></p>
    </Cadre>
  );
}

export function Inscription() {
  const { inscription, connexionGoogle } = useAuth();
  const config = useConfig();
  const apres = useApresConnexion();
  const [f, setF] = useState({ first_name: '', last_name: '', email: '', telephone: '', region: '', password: '' });
  const [erreurs, setErreurs] = useState({});
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const maj = (k) => (v) => setF((x) => ({ ...x, [k]: typeof v === 'string' ? v : v.target.value }));

  return (
    <Cadre titre="Créer un compte citoyen" sousTitre="Les comptes agents sont créés par un responsable habilité.">
      <BoutonGoogle onJeton={async (j) => { try { apres(await connexionGoogle(j)); } catch (e) { setErreur(e.detail); } }} />
      <div className="my-5 flex items-center gap-3 text-xs text-texte-pale"><span className="h-px flex-1 bg-surface-bord" />ou avec votre e-mail<span className="h-px flex-1 bg-surface-bord" /></div>
      <form className="space-y-4" onSubmit={async (e) => {
        e.preventDefault();
        setEnvoi(true);
        setErreur(null);
        setErreurs({});
        try { apres(await inscription(f)); } catch (err) { setErreurs(err.champs || {}); setErreur(err.detail); } finally { setEnvoi(false); }
      }}>
        <div className="grid grid-cols-2 gap-3">
          <Champ libelle="Prénom" erreur={erreurs.first_name}>{(id) => <input id={id} className="champ" value={f.first_name} onChange={maj('first_name')} autoComplete="given-name" />}</Champ>
          <Champ libelle="Nom" erreur={erreurs.last_name}>{(id) => <input id={id} className="champ" value={f.last_name} onChange={maj('last_name')} autoComplete="family-name" />}</Champ>
        </div>
        <Champ libelle="E-mail" requis erreur={erreurs.email}>{(id) => <input id={id} type="email" className="champ" value={f.email} onChange={maj('email')} autoComplete="email" required />}</Champ>
        <div className="grid grid-cols-2 gap-3">
          <Champ libelle="Téléphone" aide="Utile aux secours pour vous rappeler." erreur={erreurs.telephone}>{(id) => <input id={id} type="tel" className="champ" value={f.telephone} onChange={maj('telephone')} autoComplete="tel" />}</Champ>
          <Champ libelle="Région" erreur={erreurs.region}>{(id) => <Selecteur id={id} valeur={f.region} onChange={maj('region')} vide="—" options={config.regions} />}</Champ>
        </div>
        <Champ libelle="Mot de passe" requis aide="8 caractères minimum, pas uniquement des chiffres." erreur={erreurs.password}>{(id) => <ChampMotDePasse id={id} valeur={f.password} onChange={maj('password')} autoComplete="new-password" />}</Champ>
        <p className="flex gap-2 text-xs text-texte-doux"><ShieldCheck className="h-4 w-4 shrink-0 text-succes" /> Vos données servent uniquement au traitement de vos signalements (loi n° 2008-12). Votre position n’est transmise que lorsque vous envoyez un SOS ou un signalement.</p>
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
        <Bouton type="submit" taille="lg" className="w-full" chargement={envoi}>Créer mon compte</Bouton>
      </form>
      <p className="mt-6 text-center text-sm text-texte-doux">Déjà inscrit ? <Link to="/connexion" className="lien">Se connecter</Link></p>
    </Cadre>
  );
}

export function MotDePasseOublie() {
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState(null);
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  return (
    <Cadre titre="Mot de passe oublié" sousTitre="Recevez un lien de réinitialisation valable une heure.">
      {message ? <Bandeau type="succes" titre="Demande envoyée">{message}</Bandeau> : (
        <form className="space-y-4" onSubmit={async (e) => {
          e.preventDefault();
          setEnvoi(true);
          setErreur(null);
          try { setMessage((await api('/auth/mot-de-passe/oubli/', { methode: 'POST', corps: { email }, auth: false })).detail); } catch (err) { setErreur(err.detail); } finally { setEnvoi(false); }
        }}>
          <Champ libelle="E-mail du compte">{(id) => <input id={id} type="email" className="champ" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus />}</Champ>
          {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
          <Bouton type="submit" className="w-full" icone={MailCheck} chargement={envoi}>Envoyer le lien</Bouton>
        </form>
      )}
      <p className="mt-6 text-center text-sm"><Link to="/connexion" className="lien">Retour à la connexion</Link></p>
    </Cadre>
  );
}

export function Reinitialiser() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const [mdp, setMdp] = useState('');
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const [fait, setFait] = useState(false);
  return (
    <Cadre titre="Nouveau mot de passe">
      {fait ? (
        <Bandeau type="succes" titre="Mot de passe modifié">Toutes vos sessions ont été fermées. <button type="button" className="lien" onClick={() => navigate('/connexion')}>Se connecter</button></Bandeau>
      ) : (
        <form className="space-y-4" onSubmit={async (e) => {
          e.preventDefault();
          setEnvoi(true);
          setErreur(null);
          try {
            await api('/auth/mot-de-passe/reinitialiser/', { methode: 'POST', auth: false, corps: { uid: params.get('uid'), token: params.get('token'), nouveau: mdp } });
            setFait(true);
          } catch (err) { setErreur(err.detail); } finally { setEnvoi(false); }
        }}>
          <Champ libelle="Nouveau mot de passe" aide="8 caractères minimum.">{(id) => <ChampMotDePasse id={id} valeur={mdp} onChange={setMdp} autoComplete="new-password" />}</Champ>
          {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
          <Bouton type="submit" className="w-full" chargement={envoi}>Enregistrer</Bouton>
        </form>
      )}
    </Cadre>
  );
}
