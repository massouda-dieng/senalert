# Architecture de SenAlert (v3)

## Vue d'ensemble

```
 Application mobile Flutter          Application web React           Administration technique
 (citoyens, agents)                  (citoyens, agents, supervision)  (Django admin, /admin/)
          │  HTTPS + JWT                      │ même origine (/app → /api)        │
          └──────────────┬────────────────────┴───────────────────────────────────┘
                         ▼
              Backend Django REST Framework  (/api/…)
     accounts · incidents · alerts · notifications · analyse · dashboard · core
                         │
          PostgreSQL (production) / SQLite (développement)
                         │
   Services externes (optionnels, toujours avec repli) :
   Firebase Cloud Messaging · Google OpenID Connect · Groq (IA) · OpenStreetMap (Overpass, tuiles)
```

Les deux clients partagent **le même backend et les mêmes règles** : toute autorisation est décidée côté serveur. Les gardes de navigation des clients servent seulement l'ergonomie.

## Backend (`backend/`)

| App | Rôle |
|---|---|
| `core` | Référentiels administrables (`Service`, `Categorie`), `Parametre` (règles métier modifiables), `JournalAudit`, `FicheSecours`, constantes (régions, statuts, rôles), format d'erreur, pagination, permissions, géométrie, services de proximité (OSM), commandes d'administration |
| `accounts` | `User` (rôle : `citoyen` / `agent` / `superadmin`), `AgentProfil` (service + zones), `CompteExterne` (Google), `DeviceToken` (FCM), JWT, réinitialisation du mot de passe, gestion des comptes |
| `incidents` | `Incident`, `PieceJointe`, `Intervention`, `EvenementDossier`, machine à états (`workflow.py`), actions communes aux dossiers |
| `alerts` | `AlerteSOS` (même cycle de vie que les incidents) |
| `notifications` | `Notification` (historique + état d'envoi push), service d'envoi FCM |
| `analyse` | Score de risque (méthode de référence du mémoire), historique `ZoneRisque`, assistant IA |
| `dashboard` | Statistiques de supervision, activité agent, exports CSV/PDF, service de l'application web compilée |

### Modèle de données (correspondance avec le diagramme de classes du chapitre 3)

| Classe UML | Implémentation |
|---|---|
| Utilisateur (+ Citoyen, AgentSecours, Administrateur) | `accounts.User` avec champ `role` ; `AgentProfil.service` = attribut `service` d'AgentSecours |
| Incident (id UUID, type, description, lat/lng, photoUrl, gravite, dateSignalement) | `incidents.Incident` : `uuid` + `reference` lisible (INC-AAAA-NNNNNN), `type_incident`, `gravite`, photos dans `PieceJointe` (plusieurs) |
| AlerteSOS (id, lat/lng, statut, dateEnvoi) | `alerts.AlerteSOS` : position facultative (jamais inventée), `precision_gps`, `reference` SOS-AAAA-NNNNNN |
| Intervention (statut, dateAffectation, dateCloture) | `incidents.Intervention` (1 par dossier) : agent, service, dates d'affectation/acceptation/début/fin, compte rendu. Le statut est porté par le dossier (source unique de vérité) |
| ZoneRisque (nomZone, scoreRisque, dateCalcul) | `analyse.ZoneRisque` : instantanés historisés + calcul à la demande |

Champs communs Incident / SOS (classe abstraite `core.dossier.Dossier`) : `uuid`, `reference`, `citoyen`, position + précision, région, adresse, `statut`, `gravite`, `service`, `client_request_id` (idempotence), dates de création / prise en charge / clôture, motif de clôture.

### Cycle de vie d'un dossier

```
 nouveau ──affecter (superadmin)──▶ affecte ──accepter (agent)──▶ accepte ──demarrer──▶ en_cours ──resoudre (+ compte rendu)──▶ resolu
    │  └──prendre en charge (agent de la zone et du service)──────────▲                        │
    │                     affecte ──decliner (motif)──▶ nouveau                                 │
    │        réaffecter : affecte / accepte / en_cours ──▶ affecte (nouvel agent)               │
    ├──rejeter (superadmin, motif) ──▶ refuse                                                    │
    └──annuler (superadmin, ou citoyen tant que nouveau/affecte, motif) ──▶ annule ◀──────────────┘
```

Chaque action : verrouillage de la ligne (`select_for_update`), contrôle du statut courant (sinon **409 Conflit**, ce qui règle les modifications simultanées), événement horodaté, notifications envoyées **après** validation de la transaction. Les règles « prise en charge directe par un agent », « annulation par le citoyen » et « compte rendu obligatoire » sont des paramètres modifiables (`Parametre workflow`).

### Visibilité des dossiers

| Rôle | Voit |
|---|---|
| Citoyen | uniquement ses propres dossiers ; la carte publique (positions arrondies ~100 m, sans description ni photo) |
| Agent | les dossiers qui lui sont affectés + les dossiers **nouveaux** de ses zones (incidents : seulement ceux de son service ; SOS : tous les services) |
| Superadmin | tout |

Les coordonnées du déclarant ne sont visibles que de l'agent affecté et du superadmin. Le citoyen voit le service intervenant, pas l'identité de l'agent.

### Idempotence et doublons

* `client_request_id` (UUID généré par le client) unique par citoyen : un double clic ou un renvoi après coupure renvoie le dossier existant (200) au lieu d'en créer un second.
* SOS : un SOS actif du même citoyen créé il y a moins de 2 minutes est renvoyé tel quel (anti-déclenchements répétés).
* Doublons potentiels d'incidents : même catégorie, ≤ 300 m, ≤ 120 min (paramétrable) → signalés au superadmin, jamais fusionnés automatiquement.

### Score de risque (méthode de référence du mémoire)

`score_région = Σ poids(catégorie) × facteur_temporel`

* poids : incendie 5, inondation 4, insécurité 4, accident 3, électricité 2, autre 1 ; une catégorie absente du tableau (agression, urgence médicale, nouvelle catégorie) compte **1**, comme « autre » ;
* facteur temporel : 2 si l'incident a moins de 7 jours (7 × 24 h, borne incluse) par rapport à la date de référence (fin de la période analysée), sinon 1 ;
* niveaux : ≥ 15 critique, ≥ 8 élevé, ≥ 3 moyen, < 3 faible ;
* ajustement documenté : les signalements **rejetés ou annulés** sont exclus (un faux signalement ne doit pas augmenter le risque) ;
* contexte fourni : nombre d'incidents utilisés, incidents récents, catégories dominantes, date de calcul, indicateur `donnees_insuffisantes` (< 3 incidents), comparaison avec la période précédente, instantanés historisés.

Ce score est un **indicateur descriptif**, pas un modèle prédictif validé. Toutes les bornes sont couvertes par des tests (`analyse/tests.py`).

### Notifications

`notifications.service.notifier()` crée une ligne `Notification` par destinataire (dédupliquée par clé d'événement) puis tente FCM. États distincts : enregistrée (la ligne existe), `envoyee` (acceptée par FCM — **pas** une preuve de lecture), `echec`, `non_configure`, `aucun_appareil`, `desactivee`, et `lue` (ouverte par l'utilisateur). Une erreur d'envoi n'annule jamais le dossier.

Temps réel : pas de WebSocket (nécessiterait Channels + Redis) ; le web actualise toutes les 15–60 s avec indicateur « Synchronisé il y a… », le mobile par tirer-pour-rafraîchir et suivi périodique du SOS (10 s).

### Sécurité (résumé — voir SECURITE.md)

JWT court (15 min) + rafraîchissement 7 jours avec rotation et liste noire (déconnexion réelle, « déconnecter tous les appareils ») ; limitation de débit par portée ; validation et ré-encodage des images (EXIF/GPS supprimés) ; pièces jointes servies uniquement via une vue contrôlée ; CORS limité aux origines locales en développement ; journal d'audit ; masquage des secrets dans les logs ; erreurs génériques sans détail interne.

## Application web (`web/`)

React 18 + Vite 5 + Tailwind CSS 3 + react-leaflet (OpenStreetMap, regroupement des marqueurs) + Recharts. Servie par Django sous `/app/` après `npm run build` (assets sous `/static/`), ou par Vite en développement (`/app/`, proxy `/api` → Django : même origine, pas de CORS).

* `src/api/client.js` : jeton d'accès en mémoire, rafraîchissement en `sessionStorage` (fermé avec l'onglet), renouvellement automatique sur 401, rejeu des seules lectures en cas de coupure réseau.
* `src/components/` : système de design (`ui.jsx`), mise en page par rôle (`Layout.jsx`), carte (`Carte.jsx`), liste filtrable paginée (`ListeDossiers.jsx`), détail + actions de la machine à états (`DossierDetail.jsx`).
* Espaces : `/citoyen/*`, `/agent/*`, `/supervision/*`, plus `/notifications` et `/profil`. La supervision (Recharts) est chargée à la demande.

## Application mobile (`mobile/`)

Flutter 3.24 / Dart 3.5, `provider` + `go_router`.

* `core/api.dart` : client Dio unique, jetons dans le trousseau sécurisé, renouvellement en file (`QueuedInterceptor`), aucune journalisation des en-têtes/corps, POST jamais rejoués automatiquement.
* `state/session.dart` (rôle lu depuis le serveur), `state/configuration.dart` (catégories, régions, numéros vérifiés, mise en cache hors ligne).
* Navigation : citoyen (Accueil, Dossiers, Carte, Secours, Profil), agent (Tableau, Interventions, Carte, Secours, Profil). Le superadmin est redirigé vers l'application web.
* Fiches de premiers secours embarquées (`assets/data/fiches_secours.json`, même source que le backend) → disponibles hors ligne dès l'installation.

## Système de design commun

| Jeton | Valeur | Usage |
|---|---|---|
| Vert drapeau | `#00853F` (gamme `#00210F` → `#ECF8F1`) | identité, navigation, actions principales |
| Jaune drapeau | `#FDEF42` | accents, étoile, alertes de vigilance |
| Rouge drapeau | `#E31B23` | **réservé** au SOS, au danger et à l'urgence critique |
| Surfaces | `#FFFFFF`, `#F8F7F1`, bordures `#E7E4D8` | zones de travail |
| Orange | `#C2410C` / `#EA580C` | avertissements, retards |
| Photos | 9 images Wikimedia Commons sous licence libre, créditées (`web/src/lib/credits-photos.json`, `mobile/assets/images/photos/credits.json`) | illustration uniquement |
| Typographie | Plus Jakarta Sans (titres), Inter (texte) | |

Statuts : chaque badge associe couleur **et** libellé/icône (jamais la couleur seule). Graphiques : incidents `#00853F` / SOS `#E31B23` (trait pointillé) validés par script (contraste, daltonisme ΔE 8,5).
