import clsx from 'clsx';
import { BookOpenCheck, ChevronRight, MapPinned, Phone, ShieldAlert, Siren } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import Photo from '../../components/Photo';
import { BadgeStatut, Carte, Chargement } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { ilYa } from '../../lib/format';
import { libelleCategorie, useLangue } from '../../lib/langue';
import { PHOTO_CATEGORIE } from '../../lib/photos';

export { lirePosition } from '../../components/BoutonSOS';

const ETAPES_SUIVI = [['nouveau', 'Reçu'], ['affecte', 'Affecté'], ['accepte', 'Pris en charge'], ['en_cours', 'En cours'], ['resolu', 'Résolu']];

/** Progression d'un dossier ; un dossier rejeté ou annulé garde son badge, sans fausse progression. */
function Progression({ statut }) {
  const { t } = useLangue();
  const rang = ETAPES_SUIVI.findIndex(([code]) => code === statut);
  if (rang < 0) return null;
  return (
    <ol className="mt-2 flex items-center gap-1" aria-label={`${t('Étape')} ${rang + 1} / ${ETAPES_SUIVI.length} : ${t(ETAPES_SUIVI[rang][1])}`}>
      {ETAPES_SUIVI.map(([code], i) => <li key={code} className={clsx('h-1.5 flex-1 rounded-full', i > rang ? 'bg-surface-bord' : statut === 'resolu' ? 'bg-succes-vif' : 'bg-marque-600')} />)}
    </ol>
  );
}

const STYLE_ALERTE = { danger: 'border-sos', vigilance: 'border-or', info: 'border-marque-600' };

export default function Accueil() {
  const { utilisateur } = useAuth();
  const config = useConfig();
  const { t, langue } = useLangue();
  const opts = { intervalle: 30000 };
  const region = utilisateur.region || undefined;
  const incidents = useRessource('/incidents/', { taille: 5 }, opts);
  const sos = useRessource('/alertes/sos/', { taille: 5 }, opts);
  const alertes = useRessource('/alertes/zones/', { region, en_cours: 1 }, { intervalle: 120000 });
  const dossiers = [...(sos.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(incidents.donnees?.results || [])]
    .sort((a, b) => new Date(b.date_creation) - new Date(a.date_creation)).slice(0, 4);

  return (
    <div className="space-y-7 pb-16">
      {/* Accueil : une photo, une question, deux actions. Le SOS reste en bouton flottant sur toutes les pages. */}
      <div className="relative overflow-hidden rounded-3xl text-white">
        <Photo nom="dakar-vue" className="absolute inset-0 h-full w-full" alt="" credit={false} priorite />
        <div className="absolute inset-0 bg-gradient-to-r from-marque-950/90 via-marque-900/70 to-marque-900/20" aria-hidden />
        <div className="relative max-w-xl p-6 sm:p-9">
          <h1 className="font-titre text-3xl font-extrabold sm:text-4xl">{t('Bonjour {nom}', { nom: utilisateur.first_name || '' }).trim()}</h1>
          <p className="mt-2 text-white/85">{t('Signalez un problème, nous l’envoyons à la structure compétente la plus proche.')}</p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link to="/citoyen/signaler" className="inline-flex items-center gap-2 rounded-xl bg-white px-5 py-3 font-bold text-marque-900 shadow-sm hover:bg-marque-50">
              <ShieldAlert className="h-5 w-5" aria-hidden /> {t('Signaler un incident')}
            </Link>
            <Link to="/citoyen/services" className="inline-flex items-center gap-2 rounded-xl bg-white/15 px-5 py-3 font-semibold ring-1 ring-white/30 hover:bg-white/25">
              <MapPinned className="h-5 w-5" aria-hidden /> {t('Services proches')}
            </Link>
          </div>
          <p className="mt-5 inline-flex items-center gap-2 text-sm text-white/80"><Siren className="h-4 w-4" aria-hidden /> {t('Danger immédiat : bouton SOS en bas à droite.')}</p>
        </div>
      </div>

      <section>
        <h2 className="mb-3 text-lg font-extrabold">{t('Que voulez-vous signaler ?')}</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {config.categories.map((c) => (
            <Link key={c.code} to={`/citoyen/signaler?type=${c.code}`} className="group overflow-hidden rounded-2xl border border-surface-bord bg-surface transition hover:shadow-carte">
              <Photo nom={PHOTO_CATEGORIE[c.code] || 'dakar-vue'} className="aspect-[16/10]" imgClassName="transition duration-300 group-hover:scale-[1.03]" alt="" credit={false} />
              <p className="px-3 py-2.5 text-sm font-bold">{libelleCategorie(langue, c.code, c.libelle)}</p>
            </Link>
          ))}
        </div>
        <p className="mt-2 text-xs text-texte-pale">{t('Photos d’illustration sous licence libre (voir Crédits photos).')}</p>
      </section>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1.5fr)_minmax(300px,1fr)]">
        <Carte titre={t('Mes signalements')} action={<Link to="/citoyen/dossiers" className="lien text-sm">{t('Tout voir')}</Link>} corpsClassName="p-0">
          {incidents.chargement && !incidents.donnees ? <Chargement /> : dossiers.length === 0 ? (
            <p className="p-5 text-sm text-texte-doux">{t('Aucun signalement pour l’instant.')}</p>
          ) : (
            <ul className="divide-y divide-surface-bord">
              {dossiers.map((d) => (
                <li key={`${d.sos ? 's' : 'i'}${d.id}`}>
                  <Link to={`/citoyen/dossiers?${d.sos ? 'type=sos&' : ''}dossier=${d.id}`} className="block px-5 py-3.5 hover:bg-surface-douce">
                    <div className="flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <p className="truncate font-semibold">{d.sos ? `${t('Alerte SOS')}${d.type_urgence_libelle && d.type_urgence !== 'non_precise' ? ` · ${d.type_urgence_libelle}` : ''}` : libelleCategorie(langue, d.type_incident, d.categorie_libelle)}</p>
                        <p className="truncate text-xs text-texte-doux"><span className="font-mono">{d.reference}</span> · {d.structure_nom || t('en attente d’orientation')} · {ilYa(d.date_creation)}</p>
                      </div>
                      <BadgeStatut statut={d.statut} />
                    </div>
                    <Progression statut={d.statut} />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Carte>

        <div className="space-y-6">
          {alertes.donnees?.results?.length > 0 && (
            <Carte titre={t('Alertes dans ma région')}>
              <ul className="space-y-3">
                {alertes.donnees.results.slice(0, 3).map((a) => (
                  <li key={a.id} className={clsx('border-l-4 pl-3', STYLE_ALERTE[a.niveau])}>
                    <p className="text-sm font-bold">{a.titre}</p>
                    <p className="text-sm text-texte-doux">{a.message}</p>
                  </li>
                ))}
              </ul>
            </Carte>
          )}
          <Carte titre={t('Numéros d’urgence')}>
            <div className="grid gap-2">
              {config.numeros_urgence.map((n) => (
                <a key={n.numero} href={`tel:${n.numero}`} className="flex items-center justify-between rounded-xl bg-surface-douce px-3.5 py-2.5 text-sm font-semibold hover:bg-marque-50">
                  <span className="inline-flex items-center gap-2"><Phone className="h-4 w-4 text-marque-600" aria-hidden />{n.service}</span>
                  <span className="font-mono text-base font-bold">{n.numero}</span>
                </a>
              ))}
            </div>
            <Link to="/citoyen/secours" className="mt-3 flex items-center justify-between rounded-xl border border-surface-bord px-3.5 py-2.5 text-sm font-semibold hover:bg-surface-douce">
              <span className="inline-flex items-center gap-2"><BookOpenCheck className="h-4 w-4 text-marque-600" aria-hidden />{t('Premiers secours')}</span>
              <ChevronRight className="h-4 w-4 text-texte-pale" aria-hidden />
            </Link>
          </Carte>
        </div>
      </div>
    </div>
  );
}
