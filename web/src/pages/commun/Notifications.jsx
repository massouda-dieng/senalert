import clsx from 'clsx';
import { Bell, CheckCheck } from 'lucide-react';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { estSupervision, useAuth } from '../../auth/AuthContext';
import { Bouton, Chargement, EnTetePage, EtatErreur, EtatVide, IconeNotification, Pagination } from '../../components/ui';
import { dateHeure, ilYa } from '../../lib/format';

const PUSH = {
  envoyee: 'Push accepté par FCM', echec: 'Échec du push', non_configure: 'Push non configuré', aucun_appareil: 'Aucun appareil mobile',
  desactivee: 'Push désactivé', en_attente: 'Push en attente',
};

export default function Notifications() {
  const { utilisateur } = useAuth();
  const navigate = useNavigate();
  const [page, setPage] = useState(1);
  const { donnees, chargement, erreur, recharger } = useRessource('/notifications/', { page }, { intervalle: 30000 });
  const ouvrir = async (n) => {
    if (!n.lue) api(`/notifications/${n.id}/lire/`, { methode: 'POST' }).then(() => recharger(true)).catch(() => {});
    if (!n.dossier) return;
    const base = estSupervision(utilisateur.role) ? (n.dossier.type === 'sos' ? '/supervision/sos' : '/supervision/incidents')
      : { citoyen: '/citoyen/dossiers', agent: '/agent/interventions' }[utilisateur.role];
    const type = n.dossier.type === 'sos' && !estSupervision(utilisateur.role) ? 'type=sos&' : '';
    navigate(`${base}?${type}dossier=${n.dossier.id}`);
  };
  return (
    <div className="mx-auto max-w-3xl">
      <EnTetePage titre="Notifications" sousTitre="Les événements de vos dossiers."
        actions={<Bouton variante="secondaire" icone={CheckCheck} onClick={async () => { await api('/notifications/tout-lire/', { methode: 'POST' }); recharger(true); }}>Tout marquer comme lu</Bouton>} />
      <EtatErreur erreur={erreur} onReessayer={recharger} />
      <div className="carte overflow-hidden">
        {chargement && !donnees ? <Chargement /> : !donnees?.results.length ? <EtatVide icone={Bell} titre="Aucune notification" /> : (
          <ul className="divide-y divide-surface-bord">
            {donnees.results.map((n) => (
              <li key={n.id}>
                <button type="button" onClick={() => ouvrir(n)} className={clsx('flex w-full gap-3 px-5 py-4 text-left hover:bg-surface-douce', !n.lue && 'bg-marque-50/50')}>
                  <IconeNotification type={n.type} />
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-2 font-semibold">{n.titre}{!n.lue && <span className="h-2 w-2 shrink-0 rounded-full bg-marque-600" role="img" aria-label="Non lue" />}</span>
                    <span className="block text-sm text-texte-doux">{n.message}</span>
                    <span className="mt-1 block text-xs text-texte-pale" title={dateHeure(n.date_creation)}>{ilYa(n.date_creation)}{utilisateur.role === 'superadmin' && ` · ${PUSH[n.statut_push] || n.statut_push}`}</span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
        {donnees && <div className="border-t border-surface-bord px-3"><Pagination page={page} total={donnees.count} onPage={setPage} /></div>}
      </div>
    </div>
  );
}
