import { BadgeCheck, Building2, Check, Mail, MapPin, Phone, X } from 'lucide-react';
import { useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import {
  Bandeau, Bouton, Carte, Chargement, Confirmation, EnTetePage, EtatErreur, EtatVide, Onglets, Pagination, useToast,
} from '../../components/ui';
import { dateHeure, ilYa } from '../../lib/format';

const ONGLETS = [
  { code: 'en_attente', libelle: 'En attente' },
  { code: 'validee', libelle: 'Validées' },
  { code: 'refusee', libelle: 'Refusées' },
];

/** Demandes d'accès agent : vérifier l'identité professionnelle, puis valider (crée le compte) ou refuser. */
export default function DemandesAgent() {
  const [statut, setStatut] = useState('en_attente');
  const [page, setPage] = useState(1);
  const [action, setAction] = useState(null);
  const toast = useToast();
  const liste = useRessource('/gestion/demandes-agent/', { statut, page });

  const confirmer = async (motif) => {
    const { d, type } = action;
    await api(`/gestion/demandes-agent/${d.id}/${type}/`, { methode: 'POST', corps: type === 'refuser' ? { motif } : {} });
    toast(type === 'valider' ? `Compte agent créé pour ${d.prenom} ${d.nom}.` : 'Demande refusée.');
    liste.recharger();
    window.dispatchEvent(new Event('senalert:demandes-agent'));
  };

  return (
    <>
      <EnTetePage titre="Demandes d’accès agent" sousTitre="Les agents demandent leur compte depuis le site ou l’application ; il n’est actif qu’après votre validation." />
      <Bandeau type="info" className="mb-4">Avant de valider, vérifiez le matricule et la structure auprès du service concerné. La validation crée un compte <b>agent</b> limité au service et aux zones demandés (modifiables ensuite dans Utilisateurs). Le mot de passe a été choisi par l’agent : vous ne le voyez jamais.</Bandeau>
      <div className="mb-4"><Onglets onglets={ONGLETS} actif={statut} onChange={(s) => { setStatut(s); setPage(1); }} /></div>

      <EtatErreur erreur={liste.erreur} onReessayer={() => liste.recharger()} />
      {liste.chargement && !liste.donnees ? <Chargement /> : liste.donnees?.results?.length === 0 ? (
        <EtatVide icone={BadgeCheck} titre="Aucune demande" texte={statut === 'en_attente' ? 'Aucune demande en attente de validation.' : 'Rien dans cette catégorie pour le moment.'} />
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          {liste.donnees?.results?.map((d) => (
            <Carte key={d.id} corpsClassName="p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-lg font-bold">{d.prenom} {d.nom}</p>
                  <p className="text-sm font-semibold text-marque-700">{d.service_nom}{d.fonction ? ` · ${d.fonction}` : ''}</p>
                </div>
                <span className="text-xs text-texte-pale" title={dateHeure(d.date_demande)}>{ilYa(d.date_demande)}</span>
              </div>
              <dl className="mt-3 grid gap-1.5 text-sm text-texte-doux">
                <div className="flex items-center gap-2"><Building2 className="h-4 w-4 shrink-0" /><dt className="sr-only">Structure</dt><dd>{d.structure} · matricule <b className="text-texte">{d.matricule}</b></dd></div>
                <div className="flex items-center gap-2"><Mail className="h-4 w-4 shrink-0" /><dt className="sr-only">E-mail</dt><dd className="break-all">{d.email}</dd></div>
                {d.telephone && <div className="flex items-center gap-2"><Phone className="h-4 w-4 shrink-0" /><dt className="sr-only">Téléphone</dt><dd>{d.telephone}</dd></div>}
                <div className="flex items-center gap-2"><MapPin className="h-4 w-4 shrink-0" /><dt className="sr-only">Zones</dt><dd>{d.zones_libelles.join(', ')}</dd></div>
              </dl>
              {d.message && <p className="mt-3 rounded-xl bg-surface-douce px-3 py-2 text-sm">{d.message}</p>}
              {d.statut === 'en_attente' ? (
                <div className="mt-4 flex justify-end gap-2">
                  <Bouton variante="secondaire" icone={X} onClick={() => setAction({ d, type: 'refuser' })}>Refuser</Bouton>
                  <Bouton icone={Check} onClick={() => setAction({ d, type: 'valider' })}>Valider et créer le compte</Bouton>
                </div>
              ) : (
                <p className="mt-4 text-sm text-texte-doux">
                  {d.statut === 'validee' ? 'Validée' : 'Refusée'} par {d.traite_par_nom || '—'} {d.date_traitement && `le ${dateHeure(d.date_traitement)}`}
                  {d.motif_refus && <> — motif : <i>{d.motif_refus}</i></>}
                </p>
              )}
            </Carte>
          ))}
        </div>
      )}
      <Pagination page={page} total={liste.donnees?.count || 0} onPage={setPage} />

      <Confirmation ouverte={Boolean(action)} onFermer={() => setAction(null)}
        titre={action?.type === 'valider' ? 'Valider la demande' : 'Refuser la demande'}
        message={action?.type === 'valider'
          ? `Un compte agent ${action?.d.service_nom} sera créé pour ${action?.d.prenom} ${action?.d.nom} (${action?.d.email}). Il pourra se connecter immédiatement.`
          : `${action?.d.prenom} ${action?.d.nom} sera informé du refus par e-mail.`}
        libelleAction={action?.type === 'valider' ? 'Valider' : 'Refuser'} variante={action?.type === 'valider' ? 'primaire' : 'danger'}
        motif={action?.type === 'refuser' ? 'Motif du refus' : undefined} onConfirmer={confirmer} />
    </>
  );
}
