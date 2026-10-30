import {
  AlertTriangle, CheckCircle2, ClipboardList, Clock, Database, Hourglass, Info, Siren, Star, Timer, Users,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Bar, BarChart, CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useRessource } from '../../api/hooks';
import Photo from '../../components/Photo';
import { Bandeau, Carte, Chargement, EnTetePage, EtatErreur, IndicateurSynchro, Indicateur, Selecteur } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { date, duree, isoJour, nombre, pct } from '../../lib/format';

// Palette validée (validate_palette.js : vert et rouge du drapeau, ΔE daltonisme 8,5 ; SOS en pointillé en plus).
const COULEUR_INCIDENTS = '#00853F';
const COULEUR_SOS = '#E31B23';
const AXE = { fontSize: 12, fill: '#5B6680' };

function Infobulle({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-surface-bord bg-surface px-3 py-2 text-xs shadow-flottant">
      <p className="mb-1 font-semibold text-texte">{label}</p>
      {payload.map((p) => (
        <p key={p.dataKey} className="flex items-center gap-2 text-texte-doux">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />{p.name} : <b className="text-texte">{nombre(p.value)}</b>
        </p>
      ))}
    </div>
  );
}

export default function Supervision() {
  const config = useConfig();
  const [periode, setPeriode] = useState('30');
  const [region, setRegion] = useState('');
  const [categorie, setCategorie] = useState('');
  const [granularite, setGranularite] = useState('jour');
  const fin = new Date();
  const debut = new Date(Date.now() - (Number(periode) - 1) * 86400000);
  const filtres = { date_debut: isoJour(debut), date_fin: isoJour(fin), region, type_incident: categorie, granularite };
  const { donnees: s, chargement, erreur, recharger, derniereSynchro } = useRessource('/tableau-de-bord/statistiques/', filtres, { intervalle: 60000 });

  const serie = useMemo(() => {
    if (!s) return [];
    const cles = [...new Set([...Object.keys(s.evolution.incidents), ...Object.keys(s.evolution.sos)])].sort();
    return cles.map((k) => ({ periode: date(k), incidents: s.evolution.incidents[k] || 0, sos: s.evolution.sos[k] || 0 }));
  }, [s]);

  const r = s?.resume;
  const def = s?.definitions || {};

  return (
    <>
      <div className="relative mb-6 overflow-hidden rounded-3xl text-white">
        <Photo nom="dakar-cote" className="absolute inset-0 h-full w-full" alt="" credit={false} />
        <div className="absolute inset-0 bg-gradient-to-r from-black/80 via-black/50 to-black/5" aria-hidden />
        <div className="relative flex flex-wrap items-end justify-between gap-4 px-6 py-8 sm:px-8">
          <div>
            <p className="text-sm font-semibold uppercase tracking-widest text-or">Supervision nationale</p>
            <h1 className="font-titre text-3xl font-extrabold">Centre de supervision</h1>
            <p className="mt-1 text-white/80">Indicateurs calculés en direct depuis la base SenAlert.</p>
          </div>
          <div className="rounded-xl bg-surface/90 text-texte"><IndicateurSynchro date={derniereSynchro} chargement={chargement} onRafraichir={recharger} /></div>
        </div>
      </div>

      <div className="carte mb-5 flex flex-wrap items-center gap-3 p-3">
        <Selecteur aria-label="Période" className="w-auto" vide={null} valeur={periode} onChange={setPeriode}
          options={[{ code: '7', libelle: '7 derniers jours' }, { code: '30', libelle: '30 derniers jours' }, { code: '90', libelle: '90 derniers jours' }, { code: '365', libelle: '12 derniers mois' }]} />
        <Selecteur aria-label="Région" className="w-auto" valeur={region} onChange={setRegion} vide="Toutes régions" options={config.regions} />
        <Selecteur aria-label="Catégorie" className="w-auto" valeur={categorie} onChange={setCategorie} vide="Toutes catégories" options={config.categories} />
        <Selecteur aria-label="Granularité" className="w-auto" vide={null} valeur={granularite} onChange={setGranularite}
          options={[{ code: 'jour', libelle: 'Par jour' }, { code: 'semaine', libelle: 'Par semaine' }, { code: 'mois', libelle: 'Par mois' }]} />
        <span className="ml-auto text-xs text-texte-pale">{s && `Du ${date(s.periode.debut)} au ${date(s.periode.fin)}`}</span>
      </div>

      <EtatErreur erreur={erreur} onReessayer={recharger} />
      {s?.donnees_demo && <Bandeau type="alerte" className="mb-5" titre="Données de démonstration présentes">Des incidents étiquetés « [DÉMO] » sont inclus dans ces indicateurs. Ils ne correspondent à aucun événement réel.</Bandeau>}
      {!s && chargement ? <Chargement /> : s && (
        <>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
            <Indicateur libelle="Incidents" valeur={nombre(r.total_incidents)} icone={ClipboardList} aide={def.total_incidents} />
            <Indicateur libelle="Alertes SOS" valeur={nombre(r.total_sos)} icone={Siren} ton="sos" aide={def.total_sos} />
            <Indicateur libelle="Nouveaux" valeur={nombre(r.nouveaux)} icone={Hourglass} aide={def.nouveaux} />
            <Indicateur libelle="En cours" valeur={nombre(r.en_cours)} icone={Timer} ton="alerte" aide={def.en_cours} sous={`${r.en_attente} en attente d’acceptation`} />
            <Indicateur libelle="Résolus" valeur={nombre(r.resolus)} icone={CheckCircle2} ton="succes" aide={def.resolus} sous={`Taux : ${pct(r.taux_resolution)}`} />
            <Indicateur libelle="En retard" valeur={nombre(r.en_retard)} icone={Clock} ton={r.en_retard ? 'sos' : 'neutre'} aide={def.en_retard} />
          </div>
          <div className="mt-3 grid grid-cols-2 gap-3 md:grid-cols-4">
            <Indicateur libelle="Prise en charge moyenne (incidents)" valeur={duree(s.incidents.delai_moyen_prise_en_charge_min)} icone={Timer} ton="neutre" aide={def.delai_moyen_prise_en_charge_min} />
            <Indicateur libelle="Prise en charge moyenne (SOS)" valeur={duree(s.sos.delai_moyen_prise_en_charge_min)} icone={Siren} ton="neutre" aide={def.delai_moyen_prise_en_charge_min} />
            <Indicateur libelle="Citoyens inscrits" valeur={nombre(r.citoyens)} icone={Users} ton="neutre" aide={def.citoyens} />
            <Indicateur libelle="Agents actifs" valeur={nombre(r.agents)} icone={Users} ton="neutre" aide={def.agents} />
          </div>

          <div className="mt-5 grid gap-5 xl:grid-cols-[1.4fr_1fr]">
            <Carte titre="Évolution des signalements">
              {serie.length === 0 ? <p className="py-16 text-center text-sm text-texte-doux">Aucun signalement sur la période.</p> : (
                <div className="h-72" role="img" aria-label="Courbe du nombre d’incidents et de SOS par période">
                  <ResponsiveContainer>
                    <LineChart data={serie} margin={{ top: 8, right: 12, left: -16, bottom: 0 }}>
                      <CartesianGrid stroke="#EEF1F6" vertical={false} />
                      <XAxis dataKey="periode" tick={AXE} tickLine={false} axisLine={{ stroke: '#E1E7F2' }} minTickGap={24} />
                      <YAxis tick={AXE} tickLine={false} axisLine={false} allowDecimals={false} />
                      <Tooltip content={<Infobulle />} cursor={{ stroke: '#94A3B8', strokeDasharray: '3 3' }} />
                      <Legend iconType="circle" wrapperStyle={{ fontSize: 12, color: '#5B6680' }} />
                      <Line type="linear" dataKey="incidents" name="Incidents" stroke={COULEUR_INCIDENTS} strokeWidth={2} dot={false} activeDot={{ r: 5, stroke: '#fff', strokeWidth: 2 }} />
                      <Line type="linear" dataKey="sos" name="SOS" stroke={COULEUR_SOS} strokeWidth={2} strokeDasharray="5 3" dot={false} activeDot={{ r: 5, stroke: '#fff', strokeWidth: 2 }} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Carte>
            <Carte titre="Incidents par catégorie">
              {s.par_categorie.length === 0 ? <p className="py-16 text-center text-sm text-texte-doux">Aucune donnée.</p> : (
                <div style={{ height: Math.max(160, s.par_categorie.length * 34) }} role="img" aria-label="Barres du nombre d’incidents par catégorie">
                  <ResponsiveContainer>
                    <BarChart data={s.par_categorie} layout="vertical" margin={{ top: 0, right: 28, left: 8, bottom: 0 }}>
                      <XAxis type="number" hide allowDecimals={false} />
                      <YAxis type="category" dataKey="libelle" width={130} tick={AXE} tickLine={false} axisLine={false} />
                      <Tooltip content={<Infobulle />} cursor={{ fill: '#F3F6FC' }} />
                      <Bar dataKey="total" name="Incidents" fill={COULEUR_INCIDENTS} radius={[0, 4, 4, 0]} barSize={16} label={{ position: 'right', fontSize: 12, fill: 'rgb(var(--c-texte))' }} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Carte>
          </div>

          <div className="mt-5 grid items-start gap-5 xl:grid-cols-[1.4fr_1fr]">
            <div className="space-y-5">
              <Carte titre="Satisfaction des citoyens (dossiers résolus de la période)">
                {!s.satisfaction?.nombre ? (
                  <p className="text-sm text-texte-doux">Aucune évaluation sur la période. Après la résolution d’un dossier, le déclarant peut noter l’intervention de 1 à 5.</p>
                ) : (
                  <div className="grid gap-6 md:grid-cols-[220px_1fr]">
                    <div title={def.satisfaction}>
                      <p className="flex items-center gap-2 font-titre text-4xl font-extrabold">{s.satisfaction.moyenne.toFixed(1).replace('.', ',')}<Star className="h-7 w-7 fill-or text-or-vif" /></p>
                      <p className="text-sm text-texte-doux">sur 5 · {nombre(s.satisfaction.nombre)} avis</p>
                      <p className="mt-1 text-xs text-texte-pale">Taux de réponse : {pct(s.satisfaction.taux_reponse)}</p>
                    </div>
                    <ul className="space-y-2.5">
                      {s.satisfaction.par_service.map((x) => (
                        <li key={x.service} className="grid grid-cols-[minmax(0,180px)_1fr_auto] items-center gap-3 text-sm" title={`${x.moyenne} / 5 sur ${x.nombre} avis`}>
                          <span className="truncate">{x.service}</span>
                          <span className="h-2 overflow-hidden rounded-full bg-surface-douce"><span className="block h-full rounded-[4px] bg-marque-600" style={{ width: `${(x.moyenne / 5) * 100}%` }} /></span>
                          <span className="font-semibold tabular-nums">{x.moyenne.toFixed(1).replace('.', ',')} <span className="font-normal text-texte-pale">({x.nombre})</span></span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </Carte>
            <Carte titre="Qualité et complétude des données (incidents de la période)">
              {s.qualite.total === 0 ? <p className="text-sm text-texte-doux">Aucun incident sur la période.</p> : (
                <div className="grid gap-4 grid-cols-2 sm:grid-cols-3">
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
            <Carte titre="Répartition par région" action={<Link to="/supervision/carte" className="lien text-sm">Voir sur la carte →</Link>} corpsClassName="max-h-[480px] overflow-y-auto p-0">
              <table className="w-full text-sm">
                <thead className="sticky top-0 bg-surface-douce text-left text-xs uppercase text-texte-doux">
                  <tr><th className="px-4 py-2">Région</th><th className="px-4 py-2 text-right">Incidents</th><th className="px-4 py-2 text-right">SOS</th></tr>
                </thead>
                <tbody className="divide-y divide-surface-bord">
                  {s.par_region.map((x) => (
                    <tr key={x.code}>
                      <td className="px-4 py-2">{x.libelle}</td>
                      <td className="px-4 py-2 text-right tabular-nums">{x.incidents}</td>
                      <td className="px-4 py-2 text-right tabular-nums">{x.sos}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Carte>
          </div>

          <details className="carte mt-5 p-5 text-sm">
            <summary className="flex cursor-pointer items-center gap-2 font-semibold"><Info className="h-4 w-4" /> Définition des indicateurs</summary>
            <dl className="mt-3 grid gap-2 sm:grid-cols-2">
              {Object.entries(def).map(([k, v]) => <div key={k}><dt className="font-mono text-xs text-marque-700">{k}</dt><dd className="text-texte-doux">{v}</dd></div>)}
            </dl>
            <p className="mt-3 flex items-center gap-2 text-xs text-texte-pale"><Database className="h-3.5 w-3.5" /> Calcul serveur à {new Date(s.genere_le).toLocaleTimeString('fr-FR')}. <AlertTriangle className="h-3.5 w-3.5" /> Les volumes reflètent les signalements reçus, pas la totalité des événements réels.</p>
          </details>
        </>
      )}
    </>
  );
}
