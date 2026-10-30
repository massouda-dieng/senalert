import clsx from 'clsx';
import { AlertTriangle, CheckCircle2, ChevronLeft, ChevronRight, Info, Loader2, RefreshCw, X, XCircle } from 'lucide-react';
import { createContext, useCallback, useContext, useEffect, useId, useRef, useState } from 'react';
import { GRAVITES, STATUTS, ilYa } from '../lib/format';

/* ---------------------------------------------------------------- Boutons */

const VARIANTES = {
  primaire: 'bg-marque-800 text-white hover:bg-marque-700 shadow-sm',
  secondaire: 'bg-white text-texte border border-surface-bord hover:bg-surface-douce',
  fantome: 'text-texte-doux hover:bg-surface-douce hover:text-texte',
  danger: 'bg-sos text-white hover:bg-sos-fonce shadow-sm',
  succes: 'bg-succes text-white hover:bg-emerald-700 shadow-sm',
};

export function Bouton({ variante = 'primaire', taille = 'md', chargement, icone: Icone, className, children, disabled, ...props }) {
  return (
    <button
      type="button"
      className={clsx(
        'inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition disabled:cursor-not-allowed disabled:opacity-55',
        taille === 'sm' ? 'px-3 py-1.5 text-[13px]' : taille === 'lg' ? 'px-5 py-3 text-[15px]' : 'px-4 py-2.5 text-sm',
        VARIANTES[variante], className,
      )}
      disabled={disabled || chargement}
      aria-busy={chargement || undefined}
      {...props}
    >
      {chargement ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> : Icone && <Icone className="h-4 w-4" aria-hidden />}
      {children}
    </button>
  );
}

/* ---------------------------------------------------------------- Badges */

export function BadgeStatut({ statut }) {
  const s = STATUTS[statut] || { libelle: statut, classe: 'bg-slate-100 text-slate-600' };
  return (
    <span className={clsx('inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ring-1 ring-inset', s.classe)}>
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: s.point }} aria-hidden />
      {s.libelle}
    </span>
  );
}

export function BadgeGravite({ gravite }) {
  const g = GRAVITES[gravite];
  if (!g) return null;
  return <span className={clsx('rounded-md px-2 py-0.5 text-[11px] font-bold uppercase tracking-wide', g.classe)}>{g.libelle}</span>;
}

export function Pastille({ couleur = '#475569', children }) {
  return (
    <span className="inline-flex items-center gap-1.5 text-sm">
      <span className="h-2.5 w-2.5 rounded-full" style={{ background: couleur }} aria-hidden />
      {children}
    </span>
  );
}

/* ---------------------------------------------------------------- États */

export function Chargement({ texte = 'Chargement…', className }) {
  return (
    <div role="status" className={clsx('flex items-center justify-center gap-2 py-10 text-sm text-texte-doux', className)}>
      <Loader2 className="h-5 w-5 animate-spin text-marque-600" aria-hidden /> {texte}
    </div>
  );
}

export function Squelette({ className }) {
  return <div className={clsx('animate-pulse rounded-xl bg-slate-200/70', className)} aria-hidden />;
}

export function EtatVide({ icone: Icone = Info, titre, texte, action }) {
  return (
    <div className="flex flex-col items-center justify-center px-6 py-12 text-center">
      <div className="mb-3 rounded-2xl bg-surface-douce p-3 text-texte-pale"><Icone className="h-7 w-7" aria-hidden /></div>
      <p className="font-semibold">{titre}</p>
      {texte && <p className="mt-1 max-w-sm text-sm text-texte-doux">{texte}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function EtatErreur({ erreur, onReessayer }) {
  if (!erreur) return null;
  return (
    <div role="alert" className="flex items-start gap-3 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-900">
      <XCircle className="mt-0.5 h-5 w-5 shrink-0" aria-hidden />
      <div className="flex-1">
        <p className="font-semibold">Impossible de charger les données</p>
        <p className="mt-0.5">{erreur.detail || String(erreur)}</p>
      </div>
      {onReessayer && <Bouton variante="secondaire" taille="sm" icone={RefreshCw} onClick={() => onReessayer()}>Réessayer</Bouton>}
    </div>
  );
}

export function Bandeau({ type = 'info', titre, children, className }) {
  const styles = {
    info: ['border-marque-600/20 bg-marque-50 text-marque-900', Info],
    alerte: ['border-amber-300 bg-alerte-clair text-amber-900', AlertTriangle],
    danger: ['border-red-200 bg-red-50 text-red-900', XCircle],
    succes: ['border-emerald-200 bg-succes-clair text-emerald-900', CheckCircle2],
  }[type];
  const Icone = styles[1];
  return (
    <div className={clsx('flex gap-3 rounded-2xl border p-3.5 text-sm', styles[0], className)} role={type === 'danger' ? 'alert' : 'note'}>
      <Icone className="mt-0.5 h-5 w-5 shrink-0" aria-hidden />
      <div>{titre && <p className="font-semibold">{titre}</p>}<div className={titre ? 'mt-0.5' : ''}>{children}</div></div>
    </div>
  );
}

export function IndicateurSynchro({ date, chargement, onRafraichir }) {
  return (
    <button type="button" onClick={() => onRafraichir?.()} className="inline-flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs text-texte-doux hover:bg-white" title="Actualiser">
      <RefreshCw className={clsx('h-3.5 w-3.5', chargement && 'animate-spin')} aria-hidden />
      {date ? `Synchronisé ${ilYa(date)}` : 'Non synchronisé'}
    </button>
  );
}

/* ---------------------------------------------------------------- Mise en page */

export function EnTetePage({ titre, sousTitre, actions, retour }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {retour}
        <h1 className="text-2xl font-extrabold text-texte sm:text-[28px]">{titre}</h1>
        {sousTitre && <p className="mt-1 text-sm text-texte-doux">{sousTitre}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function Carte({ titre, action, className, corpsClassName, children }) {
  return (
    <section className={clsx('carte', className)}>
      {(titre || action) && (
        <header className="flex items-center justify-between gap-3 border-b border-surface-bord px-5 py-3.5">
          <h2 className="text-[15px] font-bold">{titre}</h2>
          {action}
        </header>
      )}
      <div className={clsx('p-5', corpsClassName)}>{children}</div>
    </section>
  );
}

export function Indicateur({ libelle, valeur, icone: Icone, ton = 'nuit', aide, sous }) {
  const tons = {
    nuit: 'bg-marque-50 text-marque-700', sos: 'bg-sos-clair text-sos', alerte: 'bg-alerte-clair text-amber-700',
    succes: 'bg-succes-clair text-emerald-700', neutre: 'bg-slate-100 text-slate-600',
  };
  return (
    <div className="carte flex items-start gap-3 p-4" title={aide}>
      {Icone && <div className={clsx('rounded-xl p-2.5', tons[ton])}><Icone className="h-5 w-5" aria-hidden /></div>}
      <div className="min-w-0">
        <p className="text-[13px] font-medium text-texte-doux">{libelle}</p>
        <p className="mt-0.5 font-titre text-2xl font-extrabold tabular-nums">{valeur}</p>
        {sous && <p className="text-xs text-texte-pale">{sous}</p>}
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------- Formulaires */

export function Champ({ libelle, erreur, aide, children, requis }) {
  const id = useId();
  const enfant = typeof children === 'function' ? children(id) : children;
  return (
    <div>
      {libelle && <label htmlFor={id} className="etiquette">{libelle}{requis && <span className="text-sos"> *</span>}</label>}
      {enfant}
      {aide && !erreur && <p className="mt-1 text-xs text-texte-pale">{aide}</p>}
      {erreur && <p className="mt-1 text-xs font-medium text-red-700" role="alert">{Array.isArray(erreur) ? erreur[0] : erreur}</p>}
    </div>
  );
}

export function Selecteur({ valeur, onChange, options, vide = 'Tous', className, ...props }) {
  return (
    <select className={clsx('champ py-2', className)} value={valeur ?? ''} onChange={(e) => onChange(e.target.value)} {...props}>
      {vide !== null && <option value="">{vide}</option>}
      {(options || []).map((o) => <option key={o.code} value={o.code}>{o.libelle}</option>)}
    </select>
  );
}

/* ---------------------------------------------------------------- Pagination */

export function Pagination({ page, total, taille = 20, onPage }) {
  const pages = Math.max(1, Math.ceil(total / taille));
  if (total <= taille) return <p className="px-1 py-3 text-xs text-texte-pale">{total} résultat{total > 1 ? 's' : ''}</p>;
  return (
    <nav className="flex items-center justify-between gap-3 px-1 py-3 text-sm" aria-label="Pagination">
      <span className="text-xs text-texte-doux">{total} résultats · page {page}/{pages}</span>
      <div className="flex gap-1">
        <Bouton variante="secondaire" taille="sm" icone={ChevronLeft} disabled={page <= 1} onClick={() => onPage(page - 1)} aria-label="Page précédente" />
        <Bouton variante="secondaire" taille="sm" icone={ChevronRight} disabled={page >= pages} onClick={() => onPage(page + 1)} aria-label="Page suivante" />
      </div>
    </nav>
  );
}

/* ---------------------------------------------------------------- Fenêtres */

export function Fenetre({ ouverte, onFermer, titre, children, pied, large }) {
  const ref = useRef(null);
  useEffect(() => {
    if (!ouverte) return undefined;
    const precedent = document.activeElement;
    ref.current?.querySelector('input,select,textarea,button:not([data-fermer])')?.focus();
    const clavier = (e) => { if (e.key === 'Escape') onFermer(); };
    document.addEventListener('keydown', clavier);
    return () => { document.removeEventListener('keydown', clavier); precedent?.focus?.(); };
  }, [ouverte, onFermer]);
  if (!ouverte) return null;
  return (
    <div className="fixed inset-0 z-[1000] flex items-end justify-center bg-marque-950/50 p-0 backdrop-blur-[2px] sm:items-center sm:p-4" onMouseDown={(e) => e.target === e.currentTarget && onFermer()}>
      <div ref={ref} role="dialog" aria-modal="true" aria-label={titre} className={clsx('w-full animate-apparition rounded-t-3xl bg-white shadow-flottant sm:rounded-3xl', large ? 'sm:max-w-2xl' : 'sm:max-w-md')}>
        <div className="flex items-center justify-between border-b border-surface-bord px-5 py-4">
          <h2 className="text-lg font-bold">{titre}</h2>
          <button type="button" data-fermer onClick={onFermer} className="rounded-lg p-1.5 text-texte-doux hover:bg-surface-douce" aria-label="Fermer"><X className="h-5 w-5" /></button>
        </div>
        <div className="max-h-[70vh] overflow-y-auto px-5 py-4">{children}</div>
        {pied && <div className="flex justify-end gap-2 border-t border-surface-bord px-5 py-3.5">{pied}</div>}
      </div>
    </div>
  );
}

/** Confirmation d'une action sensible, avec motif optionnel. */
export function Confirmation({ ouverte, onFermer, titre, message, libelleAction = 'Confirmer', variante = 'primaire', motif, onConfirmer }) {
  const [texte, setTexte] = useState('');
  const [chargement, setChargement] = useState(false);
  const [erreur, setErreur] = useState(null);
  useEffect(() => { if (ouverte) { setTexte(''); setErreur(null); } }, [ouverte]);
  const valider = async () => {
    setChargement(true);
    setErreur(null);
    try { await onConfirmer(texte.trim()); onFermer(); } catch (e) { setErreur(e.detail || String(e)); } finally { setChargement(false); }
  };
  return (
    <Fenetre ouverte={ouverte} onFermer={onFermer} titre={titre} pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton variante={variante} chargement={chargement} disabled={motif && texte.trim().length < 3} onClick={valider}>{libelleAction}</Bouton>
    </>}>
      <p className="text-sm text-texte-doux">{message}</p>
      {motif && (
        <div className="mt-4">
          <Champ libelle={motif} requis>{(id) => <textarea id={id} rows={3} className="champ" value={texte} onChange={(e) => setTexte(e.target.value)} maxLength={255} />}</Champ>
        </div>
      )}
      {erreur && <Bandeau type="danger" className="mt-3">{erreur}</Bandeau>}
    </Fenetre>
  );
}

/* ---------------------------------------------------------------- Notifications éphémères */

const ContexteToast = createContext(() => {});

export function FournisseurToasts({ children }) {
  const [toasts, setToasts] = useState([]);
  const afficher = useCallback((message, type = 'succes') => {
    const id = Math.random().toString(36).slice(2);
    setToasts((t) => [...t, { id, message, type }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), type === 'erreur' ? 7000 : 4000);
  }, []);
  return (
    <ContexteToast.Provider value={afficher}>
      {children}
      <div className="pointer-events-none fixed bottom-4 right-4 z-[1100] flex w-[min(92vw,380px)] flex-col gap-2" aria-live="polite">
        {toasts.map((t) => (
          <div key={t.id} className={clsx('pointer-events-auto flex animate-apparition items-start gap-2.5 rounded-2xl px-4 py-3 text-sm font-medium text-white shadow-flottant',
            t.type === 'erreur' ? 'bg-red-700' : t.type === 'info' ? 'bg-marque-800' : 'bg-emerald-700')}>
            {t.type === 'erreur' ? <XCircle className="mt-0.5 h-4 w-4 shrink-0" /> : <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />}
            <span>{t.message}</span>
          </div>
        ))}
      </div>
    </ContexteToast.Provider>
  );
}

export const useToast = () => useContext(ContexteToast);

/* ---------------------------------------------------------------- Onglets */

export function Onglets({ onglets, actif, onChange }) {
  return (
    <div role="tablist" className="inline-flex rounded-xl bg-white p-1 ring-1 ring-surface-bord">
      {onglets.map((o) => (
        <button key={o.code} role="tab" type="button" aria-selected={actif === o.code} onClick={() => onChange(o.code)}
          className={clsx('rounded-lg px-3 py-1.5 text-[13px] font-semibold transition', actif === o.code ? 'bg-marque-800 text-white' : 'text-texte-doux hover:text-texte')}>
          {o.libelle}{o.compte != null && <span className="ml-1.5 opacity-70">{o.compte}</span>}
        </button>
      ))}
    </div>
  );
}
