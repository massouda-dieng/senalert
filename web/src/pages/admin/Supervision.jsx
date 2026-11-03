import clsx from 'clsx';
import {
  Activity, AlertTriangle, ArrowDownRight, ArrowRight, ArrowUpRight, Building2, CheckCircle2, ClipboardList, Clock, Database, FileClock, FileDown,
  FileSpreadsheet, Hourglass, Info, Minus, Radio, ShieldCheck, Siren, Star, Tags, Timer, Users,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Bar, BarChart, CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { telecharger } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import CarteAvancee from '../../components/CarteAvancee';
import { Bandeau, Bouton, Carte, Chargement, EtatErreur, IndicateurSynchro, Indicateur, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { COULEURS } from '../../lib/couleurs';
import { GRAVITES, ORDRE_GRAVITE, date, duree, ilYa, isoJour, nombre, pct } from '../../lib/format';

// Paires validées par validate_palette.js. La période précédente reste neutre et pointillée ; le rouge est réservé au SOS.
const { principal: COULEUR_INCIDENTS, sos: COULEUR_SOS, succes: COULEUR_RESOLUES, precedente: COULEUR_PRECEDENTE } = COULEURS.graphiques;
const COULEUR_PRISES = COULEUR_INCIDENTS;
const AXE = { fontSize: 12, fill: 'rgb(var(--c-texte-doux))' };
const GRILLE = 'rgb(var(--c-bord))';

const texteLegende = (v) => <span className="text-texte-doux">{v}</span>;

function Infobulle({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-surface-bord bg-surface px-3 py-2 text-xs shadow-flottant">
      <p className="mb-1 font-semibold text-texte">{label}</p>
      {payload.map((p) => (
        <p key={p.dataKey} className="flex items-center gap-2 text-texte-doux">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color || p.fill }} />{p.name} : <b className="text-texte">{nombre(p.value)}</b>
        </p>
      ))}
    </div>
  );
}

/** Variation par rapport à la période précédente. `inverse` : une baisse est une bonne nouvelle (délais). */
function Tendance({ actuel, precedent, unite = '', inverse = false }) {
  if (actuel == null || precedent == null) return <p className="mt-0.5 text-xs text-texte-doux">période précédente : —</p>;
  const ecart = Math.round((actuel - precedent) * 10) / 10;
  if (ecart === 0) return <p className="mt-0.5 flex items-center gap-1 text-xs text-texte-doux"><Minus className="h-3 w-3" aria-hidden /> stable</p>;
  const hausse = ecart > 0;
  const Icone = hausse ? ArrowUpRight : ArrowDownRight;
  // Plus de signalements n'est ni bon ni mauvais : seule la variation d'un délai reçoit une couleur.
  const ton = inverse ? (hausse ? 'text-alerte' : 'text-succes') : 'text-texte-doux';
  return (
    <p className={clsx('mt-0.5 flex items-center gap-1 text-xs font-semibold', ton)}>
      <Icone className="h-3 w-3" aria-hidden />{hausse ? '+' : '−'}{nombre(Math.abs(ecart))}{unite} <span className="font-normal text-texte-doux">vs avant</span>
    </p>
  );
}

/** Signalements de la période par niveau d'urgence ; une alerte SOS est toujours critique. */
function NiveauxUrgence({ repartition, sos }) {
  const niveaux = ORDRE_GRAVITE.map((g) => ({ code: g, ...GRAVITES[g], n: (repartition?.[g] || 0) + (g === 'critique' ? sos : 0) }));
  const total = niveaux.reduce((s, x) => s + x.n, 0);
  return (
    <section className="carte mt-5 p-5" aria-label="Signalements par niveau d'urgence">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 className="text-[15px] font-bold">Niveaux d’urgence</h2>
        <p className="text-xs text-texte-doux">{nombre(total)} signalements sur la période, dont {nombre(sos)} SOS comptés en critique</p>
      </div>
      {total > 0 && (
        <div className="mt-3 flex h-3 gap-0.5 overflow-hidden rounded-full" role="img" aria-label={niveaux.map((x) => `${x.libelle} : ${x.n}`).join(', ')}>
          {niveaux.filter((x) => x.n).map((x) => <span key={x.code} title={`${x.libelle} : ${x.n}`} style={{ flexGrow: x.n, background: x.couleur }} />)}
        </div>
      )}
      <ul className="mt-3 grid grid-cols-2 gap-x-6 gap-y-1.5 text-sm sm:grid-cols-4">
        {niveaux.map((x) => (
          <li key={x.code} className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full" style={{ background: x.couleur }} aria-hidden />
            <span className="text-texte-doux">{x.libelle}</span>
            <b className="ml-auto tabular-nums sm:ml-0">{nombre(x.n)}</b>
            <span className="text-xs text-texte-doux">{total ? pct(Math.round((1000 * x.n) / total) / 10) : ''}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}

const ADMINISTRATION = [
  { a: '/supervision/utilisateurs', titre: 'Citoyens et agents', icone: Users, cle: 'comptes' },
  { a: '/supervision/structures', titre: 'Structures', icone: Building2, cle: 'structures', national: true },
  { a: '/supervision/incidents', titre: 'Incidents', icone: ClipboardList, cle: 'incidents' },
  { a: '/supervision/sos', titre: 'Alertes SOS', icone: Siren, cle: 'sos' },
  { a: '/supervision/incidents?statut=en_cours', titre: 'Interventions', icone: Activity, cle: 'interventions' },
  { a: '/supervision/referentiels', titre: 'Catégories et services', icone: Tags, cle: 'referentiels', national: true },
  { a: '/supervision/audit', titre: 'Activités', icone: FileClock, cle: 'audit', national: true },
];

export default function Supervision() {
  const config = useConfig();
  const { utilisateur } = useAuth();
  // Le superviseur d'une structure ne voit que sa structure (le serveur filtre déjà toutes les données).
  const national = utilisateur.role === 'superadmin';
  const toast = useToast();
  const [periode, setPeriode] = useState('30');
  const [region, setRegion] = useState('');
  const [categorie, setCategorie] = useState('');
  const [granularite, setGranularite] = useState('jour');
  const [exportEnCours, setExportEnCours] = useState(null);
  const fin = new Date();
  const debut = new Date(Date.now() - (Number(periode) - 1) * 86400000);
  const filtres = { date_debut: isoJour(debut), date_fin: isoJour(fin), region, type_incident: categorie, granularite };
  const { donnees: s, chargement, erreur, recharger, derniereSynchro } = useRessource('/tableau-de-bord/statistiques/', filtres, { intervalle: 60000 });
  const sosOuverts = useRessource('/alertes/sos/', { statut: 'nouveau', taille: 5 }, { intervalle: 15000 });
  const incOuverts = useRessource('/incidents/', { statut: 'nouveau', taille: 5 }, { intervalle: 30000 });
  const activite = useRessource(national ? '/audit/' : null, { taille: 6 }, { intervalle: 60000 });
  const comptes = useRessource('/gestion/utilisateurs/statistiques/');

  const serie = useMemo(() => {
    if (!s) return [];
    const cles = [...new Set([...Object.keys(s.evolution.incidents), ...Object.keys(s.evolution.sos)])].sort();
    return cles.map((k, i) => ({
      periode: date(k), incidents: s.evolution.incidents[k] || 0, sos: s.evolution.sos[k] || 0, precedente: s.comparaison.evolution[i] ?? null,
    }));
  }, [s]);
  const serieInterventions = useMemo(() => {
    if (!s) return [];
    const { prises_en_charge: p, resolues: r } = s.interventions;
    return [...new Set([...Object.keys(p), ...Object.keys(r)])].sort().map((k) => ({ periode: date(k), prises: p[k] || 0, resolues: r[k] || 0 }));
  }, [s]);
  const regions = useMemo(() => (s?.par_region || []).filter((x) => x.incidents + x.sos > 0), [s]);

  const exporter = async (format) => {
    setExportEnCours(format);
    try {
      await telecharger(`/tableau-de-bord/export/${format}/`, { date_debut: filtres.date_debut, date_fin: filtres.date_fin, region, type_incident: categorie }, `senalert.${format}`);
      toast(`Export ${format.toUpperCase()} téléchargé.`);
    } catch (e) { toast(e.detail, 'erreur'); } finally { setExportEnCours(null); }
  };

  const r = s?.resume;
  const c = s?.comparaison;
  const def = s?.definitions || {};
  const file = [...(sosOuverts.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(incOuverts.donnees?.results || [])].slice(0, 6);
  const comptesAdmin = {
    comptes: !comptes.donnees ? '…' : national ? `${nombre(comptes.donnees.citoyens)} citoyens · ${nombre(comptes.donnees.agents)} agents`
      : `${nombre(comptes.donnees.agents)} agents · ${nombre(comptes.donnees.agents_disponibles)} disponibles`,
    structures: 'Casernes, commissariats, hôpitaux…',
    incidents: r ? `${nombre(r.total_incidents)} sur la période` : '…',
    sos: r ? `${nombre(r.total_sos)} sur la période` : '…',
    interventions: r ? `${nombre(r.en_cours)} en cours` : '…',
    referentiels: config.categories.length ? `${config.categories.length} catégories · ${config.services?.length ?? 0} services` : '…',
    audit: 'Journal des actions',
  };

  return (
    <>
      <div className="mb-5 rounded-3xl bg-marque-800 px-5 py-6 text-white sm:px-7">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="inline-flex items-center gap-2 text-[13px] font-semibold text-white/80"><Radio className="h-4 w-4 text-marque-100" aria-hidden /> {national ? 'Supervision nationale' : 'Supervision de structure'}</p>
            <h1 className="mt-1 font-titre text-2xl font-extrabold sm:text-3xl">{national ? 'Centre de supervision' : utilisateur.structure_nom || 'Ma structure'}</h1>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Bouton variante="secondaire" taille="sm" icone={FileSpreadsheet} chargement={exportEnCours === 'csv'} onClick={() => exporter('csv')}>CSV</Bouton>
            <Bouton variante="secondaire" taille="sm" icone={FileDown} chargement={exportEnCours === 'pdf'} onClick={() => exporter('pdf')}>Rapport PDF</Bouton>
            <div className="rounded-lg bg-surface text-texte"><IndicateurSynchro date={derniereSynchro} chargement={chargement} onRafraichir={recharger} /></div>
          </div>
        </div>
        <div className="mt-4 grid grid-cols-2 gap-2 text-texte md:flex md:flex-wrap md:items-center">
          <Selecteur aria-label="Période" className="md:w-auto" vide={null} valeur={periode} onChange={setPeriode}
            options={[{ code: '7', libelle: '7 derniers jours' }, { code: '30', libelle: '30 derniers jours' }, { code: '90', libelle: '90 derniers jours' }, { code: '365', libelle: '12 derniers mois' }]} />
          <Selecteur aria-label="Région" className="md:w-auto" valeur={region} onChange={setRegion} vide="Toutes régions" options={config.regions} />
          <Selecteur aria-label="Catégorie" className="md:w-auto" valeur={categorie} onChange={setCategorie} vide="Toutes catégories" options={config.categories} />
          <Selecteur aria-label="Granularité" className="md:w-auto" vide={null} valeur={granularite} onChange={setGranularite}
            options={[{ code: 'jour', libelle: 'Par jour' }, { code: 'semaine', libelle: 'Par semaine' }, { code: 'mois', libelle: 'Par mois' }]} />
          <span className="col-span-2 text-xs text-white/75 md:ml-auto">{s && `Du ${date(s.periode.debut)} au ${date(s.periode.fin)}, comparé au ${date(c.periode.debut)} – ${date(c.periode.fin)}`}</span>
        </div>
      </div>

      <EtatErreur erreur={erreur} onReessayer={recharger} />
      {s?.donnees_demo && <Bandeau type="alerte" className="mb-5" titre="Données de démonstration présentes">Des dossiers étiquetés « [DÉMO] » sont inclus dans ces indicateurs. Ils ne correspondent à aucun événement réel.</Bandeau>}
      {!s && chargement ? <Chargement /> : s && (
        <>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-7">
            <Indicateur libelle="Signalements" valeur={nombre(r.total_signalements)} icone={ClipboardList} aide={def.total_signalements} tendance={<Tendance actuel={r.total_signalements} precedent={c.total_signalements} />} />
            <Indicateur libelle="Alertes SOS" valeur={nombre(r.total_sos)} icone={Siren} ton="sos" aide={def.total_sos} tendance={<Tendance actuel={r.total_sos} precedent={c.total_sos} />} />
            <Indicateur libelle="En attente" valeur={nombre(r.a_traiter)} icone={Hourglass} ton="alerte" aide={def.a_traiter} sous={`${nombre(r.en_retard)} en retard`} />
            <Indicateur libelle="En cours" valeur={nombre(r.en_cours)} icone={Timer} aide={def.en_cours} sous={`${nombre(r.agents_en_intervention)} agents mobilisés`} />
            <Indicateur libelle="Terminées" valeur={nombre(r.resolus)} icone={CheckCircle2} ton="succes" aide={def.resolus} sous={`Taux : ${pct(r.taux_resolution)}`} />
            <Indicateur libelle="Agents actifs" valeur={nombre(r.agents)} icone={ShieldCheck} ton="neutre" aide={def.agents} sous={`${nombre(r.citoyens)} citoyens`} />
            <Indicateur libelle="Prise en charge" valeur={duree(r.delai_moyen_prise_en_charge_min)} icone={Clock} ton="neutre" aide={def.delai_moyen_prise_en_charge_min}
              tendance={<Tendance actuel={r.delai_moyen_prise_en_charge_min} precedent={c.delai_moyen_prise_en_charge_min} unite=" min" inverse />} />
          </div>

          <NiveauxUrgence repartition={s.par_gravite} sos={r.total_sos} />

          <div className="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]">
            <section aria-label="Carte nationale" className="min-w-0">
              <CarteAvancee role="superadmin" hauteur="600px" panneauOuvert={false} />
            </section>
            <div className="min-w-0 space-y-5">
              <Carte titre="À traiter maintenant" action={<Link to="/supervision/incidents" className="lien text-sm">Tout voir</Link>} corpsClassName="p-0">
                {file.length === 0 ? <p className="flex items-center gap-2 p-5 text-sm text-texte-doux"><CheckCircle2 className="h-4 w-4 text-succes" aria-hidden /> Aucun dossier en attente d’affectation.</p> : (
                  <ul className="divide-y divide-surface-bord">
                    {file.map((d) => (
                      <li key={`${d.sos ? 's' : 'i'}${d.id}`}>
                        <Link to={`/supervision/${d.sos ? 'sos' : 'incidents'}?dossier=${d.id}`} className="flex items-center gap-3 border-l-4 px-4 py-2.5 hover:bg-surface-douce" style={{ borderLeftColor: GRAVITES[d.gravite]?.couleur }}>
                          {d.sos ? <Siren className="h-4 w-4 shrink-0 text-sos-fonce" aria-hidden /> : <ClipboardList className="h-4 w-4 shrink-0 text-texte-pale" aria-hidden />}
                          <div className="min-w-0 flex-1">
                            <p className="truncate text-sm font-semibold">{d.sos ? 'Alerte SOS' : d.categorie_libelle}</p>
                            <p className="truncate text-xs text-texte-doux">{d.region_libelle || 'Région inconnue'} · {ilYa(d.date_creation)}</p>
                          </div>
                          {d.en_retard && <span className="shrink-0 rounded-full bg-alerte-clair px-2 py-0.5 text-[11px] font-semibold text-alerte">Retard</span>}
                        </Link>
                      </li>
                    ))}
                  </ul>
                )}
              </Carte>
              {national && <Carte titre="Activité récente" action={<Link to="/supervision/audit" className="lien text-sm">Journal</Link>} corpsClassName="p-0">
                {!activite.donnees?.results?.length ? <p className="p-5 text-sm text-texte-doux">Aucune activité enregistrée.</p> : (
                  <ul className="divide-y divide-surface-bord">
                    {activite.donnees.results.slice(0, 5).map((e) => (
                      <li key={e.id} className="px-5 py-2.5">
                        <p className="truncate font-mono text-xs font-semibold text-marque-700">{e.action}</p>
                        <p className="truncate text-xs text-texte-doux">{e.acteur_nom || 'Système'} · {ilYa(e.date)}</p>
                      </li>
                    ))}
                  </ul>
                )}
              </Carte>}
            </div>
          </div>

          <div className="mt-5 grid gap-5 xl:grid-cols-2">
            <Carte titre="Évolution des signalements">
              {serie.length === 0 ? <p className="py-16 text-center text-sm text-texte-doux">Aucun signalement sur la période.</p> : (
                <div className="h-72" role="img" aria-label="Courbes du nombre d’incidents, de SOS et du total de la période précédente">
                  <ResponsiveContainer>
                    <LineChart data={serie} margin={{ top: 8, right: 12, left: -16, bottom: 0 }}>
                      <CartesianGrid stroke={GRILLE} vertical={false} />
                      <XAxis dataKey="periode" tick={AXE} tickLine={false} axisLine={{ stroke: GRILLE }} minTickGap={32} />
                      <YAxis tick={AXE} tickLine={false} axisLine={false} allowDecimals={false} />
                      <Tooltip content={<Infobulle />} cursor={{ stroke: COULEUR_PRECEDENTE, strokeDasharray: '3 3' }} />
                      <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} formatter={texteLegende} />
                      <Line type="linear" dataKey="precedente" name="Total, période précédente" stroke={COULEUR_PRECEDENTE} strokeWidth={2} strokeDasharray="2 4" dot={false} connectNulls />
                      <Line type="linear" dataKey="incidents" name="Incidents" stroke={COULEUR_INCIDENTS} strokeWidth={2} dot={false} activeDot={{ r: 5, stroke: '#fff', strokeWidth: 2 }} />
                      <Line type="linear" dataKey="sos" name="SOS" stroke={COULEUR_SOS} strokeWidth={2} strokeDasharray="5 3" dot={false} activeDot={{ r: 5, stroke: '#fff', strokeWidth: 2 }} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Carte>
            <Carte titre="Évolution des interventions">
              {serieInterventions.length === 0 ? <p className="py-16 text-center text-sm text-texte-doux">Aucune intervention sur la période.</p> : (
                <div className="h-72" role="img" aria-label="Courbes des dossiers pris en charge et des dossiers résolus">
                  <ResponsiveContainer>
                    <LineChart data={serieInterventions} margin={{ top: 8, right: 12, left: -16, bottom: 0 }}>
                      <CartesianGrid stroke={GRILLE} vertical={false} />
                      <XAxis dataKey="periode" tick={AXE} tickLine={false} axisLine={{ stroke: GRILLE }} minTickGap={32} />
                      <YAxis tick={AXE} tickLine={false} axisLine={false} allowDecimals={false} />
                      <Tooltip content={<Infobulle />} cursor={{ stroke: COULEUR_PRECEDENTE, strokeDasharray: '3 3' }} />
                      <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} formatter={texteLegende} />
                      <Line type="linear" dataKey="prises" name="Prises en charge" stroke={COULEUR_PRISES} strokeWidth={2} strokeDasharray="5 3" dot={false} activeDot={{ r: 5, stroke: '#fff', strokeWidth: 2 }} />
                      <Line type="linear" dataKey="resolues" name="Résolues" stroke={COULEUR_RESOLUES} strokeWidth={2} dot={false} activeDot={{ r: 5, stroke: '#fff', strokeWidth: 2 }} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Carte>
          </div>

          <div className="mt-5 grid gap-5 xl:grid-cols-3">
            <Carte titre="Incidents par catégorie">
              {s.par_categorie.length === 0 ? <p className="py-16 text-center text-sm text-texte-doux">Aucune donnée.</p> : (
                <div style={{ height: Math.max(180, s.par_categorie.length * 36) }} role="img" aria-label="Barres du nombre d’incidents par catégorie">
                  <ResponsiveContainer>
                    <BarChart data={s.par_categorie} layout="vertical" margin={{ top: 0, right: 28, left: 0, bottom: 0 }}>
                      <XAxis type="number" hide allowDecimals={false} />
                      <YAxis type="category" dataKey="libelle" width={124} tick={AXE} tickLine={false} axisLine={false} />
                      <Tooltip content={<Infobulle />} cursor={{ fill: 'rgb(var(--c-surface-douce))' }} />
                      <Bar dataKey="total" name="Incidents" fill={COULEUR_INCIDENTS} radius={[0, 4, 4, 0]} barSize={14} label={{ position: 'right', fontSize: 12, fill: 'rgb(var(--c-texte))' }} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Carte>
            <Carte titre="Répartition par région" action={national && <Link to="/supervision/risques" className="lien text-sm">Zones de risque</Link>}>
              {regions.length === 0 ? <p className="py-16 text-center text-sm text-texte-doux">Aucune donnée.</p> : (
                <div style={{ height: Math.max(180, regions.length * 34 + 28) }} role="img" aria-label="Barres empilées du nombre d’incidents et de SOS par région">
                  <ResponsiveContainer>
                    <BarChart data={regions} layout="vertical" margin={{ top: 0, right: 12, left: 0, bottom: 0 }}>
                      <XAxis type="number" hide allowDecimals={false} />
                      <YAxis type="category" dataKey="libelle" width={96} tick={AXE} tickLine={false} axisLine={false} />
                      <Tooltip content={<Infobulle />} cursor={{ fill: 'rgb(var(--c-surface-douce))' }} />
                      <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} formatter={texteLegende} />
                      <Bar dataKey="incidents" name="Incidents" stackId="a" fill={COULEUR_INCIDENTS} stroke="rgb(var(--c-surface))" strokeWidth={2} barSize={14} />
                      <Bar dataKey="sos" name="SOS" stackId="a" fill={COULEUR_SOS} stroke="rgb(var(--c-surface))" strokeWidth={2} radius={[0, 4, 4, 0]} barSize={14} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Carte>
            <Carte titre="Comparaison des périodes" corpsClassName="p-0">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-surface-douce text-left text-xs uppercase text-texte-doux">
                    <tr><th className="px-4 py-2 font-semibold">Indicateur</th><th className="px-3 py-2 text-right font-semibold">Actuelle</th><th className="px-4 py-2 text-right font-semibold">Précédente</th></tr>
                  </thead>
                  <tbody className="divide-y divide-surface-bord">
                    {[
                      ['Signalements', nombre(r.total_signalements), nombre(c.total_signalements)],
                      ['Incidents', nombre(r.total_incidents), nombre(c.total_incidents)],
                      ['Alertes SOS', nombre(r.total_sos), nombre(c.total_sos)],
                      ['Résolus', nombre(r.resolus), nombre(c.resolus)],
                      ['Prise en charge', duree(r.delai_moyen_prise_en_charge_min), duree(c.delai_moyen_prise_en_charge_min)],
                    ].map(([l, a, b]) => (
                      <tr key={l}><td className="px-4 py-2.5">{l}</td><td className="px-3 py-2.5 text-right font-semibold tabular-nums">{a}</td><td className="px-4 py-2.5 text-right tabular-nums text-texte-doux">{b}</td></tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p className="px-4 py-3 text-xs text-texte-doux">{def.comparaison}</p>
            </Carte>
          </div>

          <div className="mt-5 grid items-start gap-5 xl:grid-cols-2">
            <Carte titre="Satisfaction des citoyens">
              {!s.satisfaction?.nombre ? (
                <p className="text-sm text-texte-doux">Aucune évaluation sur la période. Après la résolution d’un dossier, le déclarant peut noter l’intervention de 1 à 5.</p>
              ) : (
                <div className="grid gap-6 md:grid-cols-[170px_1fr]">
                  <div title={def.satisfaction}>
                    <p className="flex items-center gap-2 font-titre text-4xl font-extrabold">{s.satisfaction.moyenne.toFixed(1).replace('.', ',')}<Star className="h-7 w-7 fill-or text-or" aria-hidden /></p>
                    <p className="text-sm text-texte-doux">sur 5 · {nombre(s.satisfaction.nombre)} avis</p>
                    <p className="mt-1 text-xs text-texte-doux">Taux de réponse : {pct(s.satisfaction.taux_reponse)}</p>
                  </div>
                  <ul className="space-y-2.5">
                    {s.satisfaction.par_service.map((x) => (
                      <li key={x.service} className="grid grid-cols-[minmax(0,150px)_1fr_auto] items-center gap-3 text-sm" title={`${x.moyenne} / 5 sur ${x.nombre} avis`}>
                        <span className="truncate">{x.service}</span>
                        <span className="h-2 overflow-hidden rounded-full bg-surface-douce"><span className="block h-full rounded-[4px] bg-marque-600" style={{ width: `${(x.moyenne / 5) * 100}%` }} /></span>
                        <span className="font-semibold tabular-nums">{x.moyenne.toFixed(1).replace('.', ',')} <span className="font-normal text-texte-doux">({x.nombre})</span></span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </Carte>
            <Carte titre="Qualité des données">
              {s.qualite.total === 0 ? <p className="text-sm text-texte-doux">Aucun incident sur la période.</p> : (
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
                  {[
                    ['avec_position_pct', 'Avec position'], ['precision_gps_50m_pct', 'GPS ≤ 50 m'], ['avec_description_pct', 'Description ≥ 20 car.'],
                    ['avec_photo_pct', 'Avec photo'],
                  ].map(([k, l]) => (
                    <div key={k} title={s.qualite.definitions[k]}>
                      <p className="text-xs text-texte-doux">{l}</p>
                      <p className="font-titre text-xl font-extrabold">{pct(s.qualite[k])}</p>
                      <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-surface-douce"><div className="h-full rounded-full bg-marque-600" style={{ width: `${s.qualite[k]}%` }} /></div>
                    </div>
                  ))}
                  <div>
                    <p className="text-xs text-texte-doux">Doublons potentiels</p>
                    <p className="font-titre text-xl font-extrabold">{s.qualite.doublons_potentiels}</p>
                    {s.qualite.doublons_potentiels > 0 && <Link className="lien text-xs" to="/supervision/incidents?doublons=true">Examiner</Link>}
                  </div>
                </div>
              )}
            </Carte>
          </div>

          <section className="mt-5" aria-label="Administration">
            <h2 className="mb-3 text-[15px] font-bold">Administration</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4">
              {ADMINISTRATION.filter((a) => national || !a.national).map((a) => (
                <Link key={a.a} to={a.a} className="carte group flex items-center gap-3 p-4 transition hover:-translate-y-0.5">
                  <a.icone className="h-5 w-5 shrink-0 text-marque-600" aria-hidden />
                  <div className="min-w-0 flex-1"><p className="truncate text-sm font-bold">{a.titre}</p><p className="truncate text-xs text-texte-doux">{comptesAdmin[a.cle]}</p></div>
                  <ArrowRight className="h-4 w-4 shrink-0 text-texte-pale transition group-hover:translate-x-0.5" aria-hidden />
                </Link>
              ))}
            </div>
          </section>

          <details className="carte mt-5 p-5 text-sm">
            <summary className="flex cursor-pointer items-center gap-2 font-semibold"><Info className="h-4 w-4" aria-hidden /> Définition des indicateurs</summary>
            <dl className="mt-3 grid gap-2 sm:grid-cols-2">
              {Object.entries(def).map(([k, v]) => <div key={k}><dt className="font-mono text-xs text-marque-700">{k}</dt><dd className="text-texte-doux">{v}</dd></div>)}
            </dl>
            <p className="mt-3 flex flex-wrap items-center gap-2 text-xs text-texte-doux"><Database className="h-3.5 w-3.5" aria-hidden /> Calcul serveur à {new Date(s.genere_le).toLocaleTimeString('fr-FR')}. <AlertTriangle className="h-3.5 w-3.5" aria-hidden /> Les volumes reflètent les signalements reçus, pas la totalité des événements réels.</p>
          </details>
        </>
      )}
    </>
  );
}
