import clsx from 'clsx';
import {
  ArrowDownRight, ArrowRight, ArrowUpRight, CheckCircle2, ClipboardList, FileDown, FileSpreadsheet, Hourglass, MapPin, Minus,
  Repeat, Siren, Star, Timer, UserCheck, UserPlus, Users,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Area, AreaChart, CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { telecharger } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import { Bandeau, Bouton, Chargement, EtatErreur, IndicateurSynchro, Onglets, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { COULEURS } from '../../lib/couleurs';
import { GRAVITES, date, duree, ilYa, isoJour, nombre, pct } from '../../lib/format';

const { principal: COULEUR_PRINCIPALE, sos: COULEUR_SOS } = COULEURS.graphiques;
const AXE = { fontSize: 12, fill: 'rgb(var(--c-texte-doux))' };
const GRILLE = 'rgb(var(--c-bord))';
const PERIODES = [
  { code: '7', libelle: '7 jours', granularite: 'jour' },
  { code: '30', libelle: '30 jours', granularite: 'jour' },
  { code: '90', libelle: '3 mois', granularite: 'semaine' },
  { code: '365', libelle: '12 mois', granularite: 'mois' },
];

function Infobulle({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-surface-bord bg-surface px-3 py-2 text-xs shadow-flottant">
      <p className="mb-1 font-semibold text-texte">{label}</p>
      {payload.map((p) => (
        <p key={p.dataKey} className="flex items-center gap-2 text-texte-doux">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color || p.stroke }} />{p.name} : <b className="text-texte">{nombre(p.value)}</b>
        </p>
      ))}
    </div>
  );
}

/** Écart avec la période précédente de même durée. */
function Ecart({ actuel, precedent }) {
  if (actuel == null || precedent == null) return null;
  const ecart = actuel - precedent;
  if (ecart === 0) return <span className="inline-flex items-center gap-1 text-xs text-white/70"><Minus className="h-3 w-3" aria-hidden />comme avant</span>;
  const Icone = ecart > 0 ? ArrowUpRight : ArrowDownRight;
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-white/15 px-2 py-0.5 text-xs font-semibold text-white">
      <Icone className="h-3 w-3" aria-hidden />{ecart > 0 ? '+' : '−'}{nombre(Math.abs(ecart))} vs période précédente
    </span>
  );
}

function Chiffre({ icone: Icone, libelle, valeur, detail, ton = 'marque', aide }) {
  const tons = { marque: 'bg-marque-50 text-marque-700', sos: 'bg-sos-clair text-sos-fonce', alerte: 'bg-alerte-clair text-alerte', succes: 'bg-succes-clair text-succes' };
  return (
    <div className="carte flex items-center gap-3.5 p-4" title={aide}>
      <span className={clsx('flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl', tons[ton])}><Icone className="h-5 w-5" aria-hidden /></span>
      <div className="min-w-0">
        <p className="text-[13px] text-texte-doux">{libelle}</p>
        <p className="font-titre text-2xl font-extrabold tabular-nums leading-tight text-texte">{valeur}</p>
        {detail && <p className="text-xs text-texte-doux">{detail}</p>}
      </div>
    </div>
  );
}

function Initiale({ nom }) {
  return <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-marque-100 text-sm font-bold text-marque-800" aria-hidden>{(nom || '?')[0].toUpperCase()}</span>;
}

function Vide({ children }) {
  return <p className="py-6 text-center text-sm text-texte-doux">{children}</p>;
}

/** Bloc central : qui sont les citoyens, combien participent, qui signale le plus. */
function Citoyens({ c, satisfaction, def, national, periode, region }) {
  // Courbe cumulée : nombre de citoyens inscrits à chaque date de la période.
  const serie = useMemo(() => {
    let cumul = c.total - c.nouveaux;
    return Object.entries(c.inscriptions).map(([k, n]) => { cumul += n; return { periode: date(k), citoyens: cumul }; });
  }, [c]);
  const maxRegion = Math.max(1, ...c.par_region.map((r) => r.total));
  const lienCitoyens = '/supervision/utilisateurs?role=citoyen';
  return (
    <section aria-labelledby="titre-citoyens" className="carte overflow-hidden">
      <div className="grid gap-6 bg-marque-800 p-5 text-white sm:p-6 lg:grid-cols-[minmax(0,300px)_1fr]">
        <div>
          <p className="inline-flex items-center gap-2 text-[13px] font-semibold text-white/80"><Users className="h-4 w-4" aria-hidden />Citoyens{region ? ' de la région' : ''}</p>
          <h2 id="titre-citoyens" className="mt-1 font-titre text-5xl font-extrabold tabular-nums">{nombre(c.total)}</h2>
          <p className="mt-1 text-sm text-white/80">{national ? 'comptes citoyens actifs' : 'citoyens ayant un dossier dans votre structure'}</p>
          <p className="mt-4 text-sm"><b className="text-lg">+{nombre(c.nouveaux)}</b> <span className="text-white/80">nouveaux inscrits sur {periode}</span></p>
          <div className="mt-1.5"><Ecart actuel={c.nouveaux} precedent={c.nouveaux_precedent} /></div>
          {national && <Link to={lienCitoyens} className="mt-5 inline-flex items-center gap-1.5 rounded-xl bg-white px-3.5 py-2 text-sm font-semibold text-marque-800 hover:bg-marque-50">Voir les citoyens <ArrowRight className="h-4 w-4" aria-hidden /></Link>}
        </div>
        <div className="min-w-0">
          <p className="text-[13px] font-semibold text-white/80">Nombre de citoyens inscrits</p>
          <div className="mt-2 h-40" role="img" aria-label={`Courbe du nombre de citoyens inscrits, de ${nombre(c.total - c.nouveaux)} à ${nombre(c.total)}`}>
            <ResponsiveContainer>
              <AreaChart data={serie} margin={{ top: 6, right: 6, left: -26, bottom: 0 }}>
                <defs>
                  <linearGradient id="degradeInscrits" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#fff" stopOpacity={0.45} /><stop offset="100%" stopColor="#fff" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="periode" tick={{ fontSize: 11, fill: 'rgba(255,255,255,.7)' }} tickLine={false} axisLine={false} minTickGap={36} />
                <YAxis tick={{ fontSize: 11, fill: 'rgba(255,255,255,.7)' }} tickLine={false} axisLine={false} allowDecimals={false} domain={['dataMin', 'auto']} />
                <Tooltip content={<Infobulle />} cursor={{ stroke: 'rgba(255,255,255,.4)' }} />
                <Area type="stepAfter" dataKey="citoyens" name="Citoyens inscrits" stroke="#fff" strokeWidth={2} fill="url(#degradeInscrits)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 divide-surface-bord border-b border-surface-bord sm:grid-cols-4 sm:divide-x">
        {[
          { icone: UserCheck, libelle: 'Citoyens actifs', valeur: nombre(c.actifs), detail: c.taux_participation == null ? '—' : `${pct(c.taux_participation)} des inscrits`, aide: def.citoyens_actifs },
          { icone: Repeat, libelle: 'Signalent souvent', valeur: nombre(c.reguliers), detail: c.signalements_par_actif ? `${String(c.signalements_par_actif).replace('.', ',')} signalements / actif` : 'au moins 2 signalements', aide: def.citoyens_reguliers },
          { icone: Star, libelle: 'Satisfaction', valeur: satisfaction?.moyenne ? `${satisfaction.moyenne.toFixed(1).replace('.', ',')} / 5` : '—', detail: satisfaction?.nombre ? `${nombre(satisfaction.nombre)} avis` : 'aucun avis', aide: def.satisfaction },
          { icone: CheckCircle2, libelle: 'Profils complets', valeur: c.profil_complet_pct == null ? '—' : pct(c.profil_complet_pct), detail: 'région et téléphone', aide: def.profil_complet_pct },
        ].map((x) => (
          <div key={x.libelle} className="p-4 sm:p-5" title={x.aide}>
            <p className="flex items-center gap-1.5 text-[13px] text-texte-doux"><x.icone className="h-4 w-4 text-marque-600" aria-hidden />{x.libelle}</p>
            <p className="mt-1 font-titre text-2xl font-extrabold tabular-nums">{x.valeur}</p>
            <p className="text-xs text-texte-doux">{x.detail}</p>
          </div>
        ))}
      </div>

      <div className="grid gap-px bg-surface-bord lg:grid-cols-3">
        <div className="bg-surface p-5">
          <h3 className="text-sm font-bold">Les plus actifs</h3>
          {c.plus_actifs.length === 0 ? <Vide>Aucun signalement de citoyen sur la période.</Vide> : (
            <ol className="mt-3 space-y-3">
              {c.plus_actifs.map((p) => (
                <li key={p.id} className="flex items-center gap-3">
                  <Initiale nom={p.nom} />
                  <div className="min-w-0 flex-1"><p className="truncate text-sm font-semibold">{p.nom}</p><p className="truncate text-xs text-texte-doux">{p.region || 'Région non renseignée'}</p></div>
                  <div className="text-right"><p className="text-sm font-bold tabular-nums">{nombre(p.signalements)}</p><p className="text-[11px] text-texte-doux">{nombre(p.resolus)} résolu{p.resolus > 1 ? 's' : ''}</p></div>
                </li>
              ))}
            </ol>
          )}
        </div>
        <div className="bg-surface p-5">
          <h3 className="text-sm font-bold">Derniers inscrits</h3>
          {c.derniers_inscrits.length === 0 ? <Vide>Aucun citoyen inscrit.</Vide> : (
            <ul className="mt-3 space-y-3">
              {c.derniers_inscrits.map((p) => (
                <li key={p.id} className="flex items-center gap-3">
                  <Initiale nom={p.nom} />
                  <div className="min-w-0 flex-1"><p className="truncate text-sm font-semibold">{p.nom}</p><p className="truncate text-xs text-texte-doux">{p.region || 'Région non renseignée'}</p></div>
                  <span className="shrink-0 text-xs text-texte-doux">{ilYa(p.date_inscription)}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
        <div className="bg-surface p-5">
          <h3 className="text-sm font-bold">Où habitent-ils ?</h3>
          {c.par_region.length === 0 ? <Vide>Aucune donnée.</Vide> : (
            <ul className="mt-3 space-y-2.5">
              {c.par_region.slice(0, 6).map((r) => (
                <li key={r.code || 'aucune'} className="text-sm">
                  <div className="flex items-center justify-between gap-2">
                    <span className={clsx('flex items-center gap-1.5 truncate', !r.code && 'text-texte-doux')}><MapPin className="h-3.5 w-3.5 shrink-0 text-texte-pale" aria-hidden />{r.libelle}</span>
                    <b className="tabular-nums">{nombre(r.total)}</b>
                  </div>
                  <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-surface-douce"><div className="h-full rounded-full bg-marque-600" style={{ width: `${(100 * r.total) / maxRegion}%` }} /></div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </section>
  );
}

export default function Supervision() {
  const config = useConfig();
  const { utilisateur } = useAuth();
  // Le superviseur d'une structure ne voit que sa structure (le serveur filtre déjà toutes les données).
  const national = utilisateur.role === 'superadmin';
  const toast = useToast();
  const [periode, setPeriode] = useState('30');
  const [region, setRegion] = useState('');
  const [exportEnCours, setExportEnCours] = useState(null);
  const choix = PERIODES.find((p) => p.code === periode);
  const filtres = {
    date_debut: isoJour(new Date(Date.now() - (Number(periode) - 1) * 86400000)), date_fin: isoJour(new Date()),
    region, granularite: choix.granularite,
  };
  const { donnees: s, chargement, erreur, recharger, derniereSynchro } = useRessource('/tableau-de-bord/statistiques/', filtres, { intervalle: 60000 });
  const sosOuverts = useRessource('/alertes/sos/', { statut: 'nouveau', taille: 5 }, { intervalle: 15000 });
  const incOuverts = useRessource('/incidents/', { statut: 'nouveau', taille: 5 }, { intervalle: 30000 });

  const serie = useMemo(() => {
    if (!s) return [];
    const cles = [...new Set([...Object.keys(s.evolution.incidents), ...Object.keys(s.evolution.sos)])].sort();
    return cles.map((k) => ({ periode: date(k), incidents: s.evolution.incidents[k] || 0, sos: s.evolution.sos[k] || 0 }));
  }, [s]);

  const exporter = async (format) => {
    setExportEnCours(format);
    try {
      await telecharger(`/tableau-de-bord/export/${format}/`, { date_debut: filtres.date_debut, date_fin: filtres.date_fin, region }, `senalert.${format}`);
      toast(`Export ${format.toUpperCase()} téléchargé.`);
    } catch (e) { toast(e.detail, 'erreur'); } finally { setExportEnCours(null); }
  };

  const r = s?.resume;
  const def = s?.definitions || {};
  const file = [...(sosOuverts.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(incOuverts.donnees?.results || [])].slice(0, 6);
  const maxCategorie = Math.max(1, ...(s?.par_categorie || []).map((x) => x.total));
  const libellePeriode = choix.code === '365' ? '12 mois' : choix.code === '90' ? '3 mois' : `${choix.code} jours`;

  return (
    <div className="mx-auto max-w-7xl">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-[13px] font-semibold text-marque-600">{national ? 'Supervision nationale' : utilisateur.structure_nom || 'Ma structure'}</p>
          <h1 className="font-titre text-2xl font-extrabold sm:text-3xl">{`Bonjour ${utilisateur.first_name || ''}`.trim()}</h1>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Onglets actif={periode} onChange={setPeriode} onglets={PERIODES} />
          {national && <Selecteur aria-label="Région" className="w-auto" valeur={region} onChange={setRegion} vide="Tout le Sénégal" options={config.regions} />}
        </div>
      </div>

      <EtatErreur erreur={erreur} onReessayer={recharger} />
      {s?.donnees_demo && <Bandeau type="alerte" className="mb-5">Des dossiers de démonstration « [DÉMO] » sont inclus dans ces chiffres.</Bandeau>}
      {!s && chargement ? <Chargement /> : s && (
        <div className="space-y-5">
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Chiffre icone={Hourglass} ton="alerte" libelle="À traiter" valeur={nombre(r.a_traiter)} detail={r.en_retard ? `dont ${nombre(r.en_retard)} en retard` : 'aucun retard'} aide={def.a_traiter} />
            <Chiffre icone={Timer} libelle="En cours" valeur={nombre(r.en_cours)} detail={`${nombre(r.agents_en_intervention)} agents sur le terrain`} aide={def.en_cours} />
            <Chiffre icone={Siren} ton="sos" libelle="Alertes SOS" valeur={nombre(r.total_sos)} detail={`sur ${libellePeriode}`} aide={def.total_sos} />
            <Chiffre icone={CheckCircle2} ton="succes" libelle="Résolus" valeur={r.taux_resolution == null ? '—' : pct(r.taux_resolution)}
              detail={r.delai_moyen_prise_en_charge_min == null ? `${nombre(r.resolus)} dossiers` : `pris en charge en ${duree(r.delai_moyen_prise_en_charge_min)}`} aide={def.taux_resolution} />
          </div>

          <Citoyens c={s.citoyens} satisfaction={s.satisfaction} def={def} national={national} periode={libellePeriode} region={region} />

          <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
            <section className="carte p-5" aria-labelledby="titre-signalements">
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <h2 id="titre-signalements" className="text-[15px] font-bold">Signalements reçus</h2>
                <p className="text-sm text-texte-doux"><b className="text-texte">{nombre(r.total_signalements)}</b> sur {libellePeriode}</p>
              </div>
              {serie.length === 0 || r.total_signalements === 0 ? <Vide>Aucun signalement sur la période.</Vide> : (
                <div className="mt-3 h-60" role="img" aria-label="Courbes du nombre d’incidents et d’alertes SOS">
                  <ResponsiveContainer>
                    <LineChart data={serie} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
                      <CartesianGrid stroke={GRILLE} vertical={false} />
                      <XAxis dataKey="periode" tick={AXE} tickLine={false} axisLine={{ stroke: GRILLE }} minTickGap={32} />
                      <YAxis tick={AXE} tickLine={false} axisLine={false} allowDecimals={false} />
                      <Tooltip content={<Infobulle />} />
                      <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} formatter={(v) => <span className="text-texte-doux">{v}</span>} />
                      <Line type="linear" dataKey="incidents" name="Incidents" stroke={COULEUR_PRINCIPALE} strokeWidth={2} dot={false} />
                      <Line type="linear" dataKey="sos" name="SOS" stroke={COULEUR_SOS} strokeWidth={2} strokeDasharray="5 3" dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              )}
              {s.par_categorie.length > 0 && (
                <ul className="mt-5 grid gap-x-6 gap-y-2.5 border-t border-surface-bord pt-4 sm:grid-cols-2">
                  {s.par_categorie.slice(0, 6).map((x) => (
                    <li key={x.code} className="text-sm">
                      <div className="flex justify-between gap-2"><span className="truncate">{x.libelle}</span><b className="tabular-nums">{nombre(x.total)}</b></div>
                      <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-surface-douce"><div className="h-full rounded-full bg-marque-600" style={{ width: `${(100 * x.total) / maxCategorie}%` }} /></div>
                    </li>
                  ))}
                </ul>
              )}
            </section>

            <section className="carte flex flex-col" aria-labelledby="titre-file">
              <header className="flex items-center justify-between gap-3 border-b border-surface-bord px-5 py-3.5">
                <h2 id="titre-file" className="text-[15px] font-bold">À traiter maintenant</h2>
                <Link to="/supervision/incidents" className="lien text-sm">Tout voir</Link>
              </header>
              {file.length === 0 ? <p className="flex items-center gap-2 p-5 text-sm text-texte-doux"><CheckCircle2 className="h-4 w-4 text-succes" aria-hidden /> Aucun dossier en attente.</p> : (
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
            </section>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-surface-bord pt-4">
            <IndicateurSynchro date={derniereSynchro} chargement={chargement} onRafraichir={recharger} />
            <div className="flex flex-wrap gap-2">
              <Bouton variante="fantome" taille="sm" icone={FileSpreadsheet} chargement={exportEnCours === 'csv'} onClick={() => exporter('csv')}>Exporter en CSV</Bouton>
              <Bouton variante="fantome" taille="sm" icone={FileDown} chargement={exportEnCours === 'pdf'} onClick={() => exporter('pdf')}>Rapport PDF</Bouton>
              {national && <Link to="/supervision/utilisateurs?role=citoyen" className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-[13px] font-semibold text-marque-700 hover:bg-surface-douce"><UserPlus className="h-4 w-4" aria-hidden />Gérer les comptes</Link>}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
