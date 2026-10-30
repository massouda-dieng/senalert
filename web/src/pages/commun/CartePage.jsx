import { useAuth } from '../../auth/AuthContext';
import CarteAvancee from '../../components/CarteAvancee';
import { EnTetePage } from '../../components/ui';

export default function CartePage() {
  const { utilisateur } = useAuth();
  const titre = { citoyen: 'Carte interactive', agent: 'Carte opérationnelle', superadmin: 'Carte de supervision' }[utilisateur.role];
  const sousTitre = utilisateur.role === 'citoyen'
    ? 'Incidents récents, carte de chaleur, zones à risque, alertes officielles et services proches.'
    : 'Dossiers ouverts, SOS actifs, carte de chaleur, zones à risque et alertes de zone.';
  return (
    <>
      <EnTetePage titre={titre} sousTitre={sousTitre} />
      <CarteAvancee role={utilisateur.role} />
    </>
  );
}
