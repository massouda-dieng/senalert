import { ShieldAlert } from 'lucide-react';
import { Link, useSearchParams } from 'react-router-dom';
import ListeDossiers from '../../components/ListeDossiers';
import { Bouton, EnTetePage, Onglets } from '../../components/ui';

const VUES = [
  { code: 'tous', libelle: 'Tous', filtres: {} },
  { code: 'en-cours', libelle: 'En cours', filtres: { actifs: 'true' } },
];

export default function MesDossiers() {
  const [params, setParams] = useSearchParams();
  const type = params.get('type') === 'sos' ? 'sos' : 'incident';
  return (
    <>
      <EnTetePage titre="Mes dossiers" sousTitre="Suivez l’évolution de vos signalements et alertes. Vous seul y avez accès."
        actions={<Onglets actif={type} onChange={(t) => setParams(t === 'sos' ? { type: 'sos' } : {})} onglets={[{ code: 'incident', libelle: 'Signalements' }, { code: 'sos', libelle: 'Alertes SOS' }]} />} />
      <ListeDossiers key={type} type={type} vues={VUES} filtresVisibles={['q']} intervalle={30000}
        vide={{ titre: 'Aucun dossier', texte: 'Vos signalements apparaîtront ici.', action: <Link to="/citoyen/signaler"><Bouton icone={ShieldAlert}>Signaler un incident</Bouton></Link> }} />
    </>
  );
}
