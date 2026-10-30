# Matrice de traçabilité — mémoire ↔ réalisation

Légende statut : ✅ réalisé et testé · 🟡 réalisé, dépend d'une configuration externe · ⛔ non réalisé.
Tests : `B:` backend (`python manage.py test`), `W:` web (`npx vitest run`), `F:` Flutter (`flutter test`), `E2E:` parcours navigateur réel (Chrome, voir EXPLOITATION.md).

| # | Exigence (source) | Écran(s) | Modèle | Endpoint | Permission | Test de validation | Statut |
|---|---|---|---|---|---|---|---|
| 1 | Créer un compte (cas d'utilisation citoyen) | Web `/inscription` · Mobile `InscriptionScreen` | `User` (role=citoyen) | `POST /api/auth/inscription/` | public, limité | B: `test_inscription_cree_toujours_un_citoyen` | ✅ |
| 2 | S'authentifier, JWT (ch. 1 objectifs, ch. 3 §5b) | `/connexion` · `ConnexionScreen` | `User`, liste noire JWT | `POST /api/auth/connexion/`, `/jeton/rafraichir/`, `/deconnexion/` | public, 10/min | B: `SessionsTests`, `test_limitation_tentatives_connexion` · W: `client.test.js` | ✅ |
| 3 | Trois profils différenciés (ch. 1, ch. 3 §2a) | 3 espaces web, 2 espaces mobile | `User.role`, `AgentProfil` | toutes | `core.permissions`, `workflow.filtre_visibilite` | B: `VisibiliteTests`, `GestionUtilisateursTests`, `test_scenarios_1_a_6` (6) · W: garde de rôle · F: `accueilPour` | ✅ |
| 4 | Administrateur gère les comptes (ch. 4 §1b) | `/supervision/utilisateurs` | `User`, `AgentProfil`, `JournalAudit` | `/api/gestion/utilisateurs/…` | superadmin | B: `test_creation_agent`, `test_role_superadmin_non_attribuable_par_api` · E2E | ✅ |
| 5 | Déclencher un SOS en un minimum d'actions (ch. 1 obj. 1) | Web Accueil citoyen · Mobile `SosScreen` | `AlerteSOS` | `POST /api/alertes/sos/` | connecté, 10/h | B: `SOSTests` (GPS, sans GPS, idempotence, répétition) · E2E | ✅ |
| 6 | Transmettre sa position GPS (« include » du SOS) | idem + précision affichée | `latitude`, `longitude`, `precision_gps`, `source_position` | idem | — | B: `test_sos_sans_gps_sans_position_inventee` | ✅ |
| 7 | Notifier l'agent puis le citoyen (diagramme de séquence) | Notifications web/mobile | `Notification`, `DeviceToken` | `/api/notifications/…`, FCM | destinataire seulement | B: `test_agents_de_la_zone_et_superadmin_notifies`, `test_parcours_complet` | 🟡 historique ✅ ; push FCM : nécessite configuration Firebase des apps |
| 8 | Signaler un incident (type, photo, description, position) (ch. 1 obj. 2) | Web `/citoyen/signaler` · Mobile `SignalerScreen` | `Incident`, `PieceJointe` | `POST /api/incidents/` | citoyen | B: `CreationIncidentTests` (photos, EXIF, idempotence, validation) · E2E scénario 1 | ✅ |
| 9 | Ajouter une photo / renseigner une description | idem | `PieceJointe` | idem, `/completer/` | propriétaire | B: `test_photo_reencodee_sans_exif`, `test_fichier_non_image_refuse` | ✅ |
| 10 | Services de proximité (police, hôpitaux, casernes, pharmacies) (ch. 1 obj. 3) | Web `/citoyen/services` · Mobile `ServicesScreen` | — (OpenStreetMap) | `GET /api/services-proximite/` | connecté | B: `ServicesProximiteTests` (tri, indisponibilité 503) | ✅ (données OSM réelles, complétude variable) |
| 11 | Fiches de premiers secours hors ligne (ch. 1 obj. 4) | Web `/citoyen/secours` (cache local) · Mobile (embarquées) | `FicheSecours` + `core/data/fiches_secours.json` | `GET /api/fiches-secours/` | public | B: `test_fiches_secours_publiques` · E2E mobile | ✅ contenu à faire **valider par un professionnel de santé** |
| 12 | Mode Agent : recevoir, prendre en charge, mettre à jour le statut (ch. 1 obj. 5, ch. 3 a.3) | Web `/agent/*` · Mobile Tableau/Interventions | `Intervention`, `EvenementDossier` | `…/{id}/prendre-en-charge|accepter|decliner|demarrer|resoudre/` | agent affecté / zone + service | B: `WorkflowTests` (concurrence 409, compte rendu obligatoire) · E2E scénario 3 | ✅ |
| 13 | Suivi des interventions par l'administrateur (ch. 3 §2f) | `/supervision/incidents`, `/sos` | `Intervention` | `…/affecter/`, `/rejeter/`, `/annuler/` | superadmin | B: `test_reaffectation`, `test_rejet_par_superadmin` · E2E scénario 2 | ✅ |
| 14 | Carte interactive Leaflet filtrable par gravité, type, région (ch. 1 obj. 6) | `/supervision` (carte), `/citoyen/carte`, `/agent/carte` | — | listes filtrées, `/incidents/carte/` | selon rôle | B: `test_carte_minimale_et_arrondie` · E2E | ✅ |
| 15 | Score de risque par zone (ch. 1 obj. 7, formule de référence) | `/supervision/risques` | `ZoneRisque` | `GET /api/analyse/zones-risque/`, `/historique/` | agent, superadmin | B: `TestFormuleReference` (poids, seuils exacts, borne 7 jours), `TestEndpointZonesRisque` | ✅ |
| 16 | Consulter alertes / incidents / filtrer (cas administrateur) | `/supervision/*` | — | filtres combinables + pagination | superadmin | B: `test_superadmin_liste_tout`, `test_filtres_appliques` | ✅ |
| 17 | Indicateurs de supervision calculés depuis la base | `/supervision` | — | `GET /api/tableau-de-bord/statistiques/` | superadmin | B: `StatistiquesTests` · E2E scénario 5 | ✅ |
| 18 | Notifications temps réel via Firebase Admin SDK (ch. 1 obj. 9) | — | `Notification.statut_push` | FCM | — | B: `test_statut_push_non_configure_trace`, `test_echec_notification_ne_supprime_pas_le_dossier` | 🟡 |
| 19 | Backend modulaire accounts/incidents/alerts/analyse/dashboard + API documentée (ch. 1 résultats) | — | — | `/api/docs/` | — | B: `test_documentation_openapi` | ✅ (+ `core`, `notifications`) |
| 20 | PostgreSQL (ch. 3 §3, §5c) | — | — | — | — | B: suite complète exécutée sur PostgreSQL 15 (119/119) | ✅ |
| 21 | Dashboard React + Tailwind (ch. 3 §5a) | `web/` | — | — | — | W: 11 tests · E2E | ✅ |
| 22 | Identifiants UUID (diagramme de classes) | références affichées | `uuid` + `reference` | — | — | B: `test_creation_avec_reference_service_et_historique` | ✅ (UUID public, PK entière interne) |
| 23 | Gravité de l'incident (diagramme de classes) | badge + sélecteur | `gravite` | `…/gravite/` | superadmin, agent affecté | B: indirect (`WorkflowTests`) | ✅ |
| 24 | Connexion Google (cahier des charges) | bouton web (GIS) + mobile (`google_sign_in`) | `CompteExterne` | `POST /api/auth/google/`, `/google/lier/` | public | B: `GoogleTests` (9 cas, jeton simulé) · F: affichage non configuré | 🟡 code complet ; **non testé avec un vrai identifiant Google** |
| 25 | Assistant IA avec repli (cahier des charges) | `/citoyen/assistant` · `AssistantScreen` | — | `POST /api/analyse/assistant/` | connecté, 20/min | B: `TestAssistant` · appel Groq réel vérifié le 29/10/2026 | ✅ |
| 26 | Exports CSV / PDF | `/supervision/incidents` | — | `/export/csv/`, `/export/pdf/` | superadmin | B: `test_export_csv_sans_donnees_personnelles`, `test_export_pdf` | ✅ |
| 27 | Journal d'audit des opérations sensibles | `/supervision/audit` | `JournalAudit` | `GET /api/audit/` | superadmin | B: plusieurs assertions `JournalAudit` | ✅ |
| 28 | Réduction du délai signalement → prise en charge (ch. 1 résultats attendus) | indicateur « délai moyen de prise en charge » | `date_prise_en_charge` | statistiques | superadmin | B: `test_indicateurs_coherents_avec_la_base` | 🟡 mesurable ; la comparaison avec un appel téléphonique nécessite une étude terrain |
| 29 | Connexion future aux systèmes SAMU / Gendarmerie / ANASER (ch. 1 résultats attendus) | — | — | — | — | — | ⛔ hors périmètre (aucune API officielle disponible) |

### Extensions v3.1 (hors mémoire, demandées au cours du projet)

| # | Fonction | Écran(s) | Modèle | Endpoint | Permission | Test | Statut |
|---|---|---|---|---|---|---|---|
| 30 | Alertes de zone | `/supervision/alertes-zone`, bandeaux web/mobile, couches de carte | `AlerteZone` | `/api/alertes/zones/` | lecture publique, écriture superadmin | B: `AlertesZoneTests` · E2E | ✅ |
| 31 | Communauté / entraide | `/citoyen/communaute`, onglet mobile « Autour » | `Confirmation`, `Commentaire` | `/api/incidents/communaute/…` | citoyens confirment ; modération superadmin | B: `CommunauteTests` · E2E | ✅ |
| 32 | Carte avancée | `/…/carte` (3 rôles), `CarteScreen` mobile | — | `/api/geocodage/`, `/api/analyse/niveaux-regions/` + existants | connecté | B: `CarteEtVitrineTests` · E2E (chaleur, satellite) | ✅ |
| 33 | Page vitrine | `/app/` | — | `/api/statistiques-publiques/` | public | B: `test_chiffres_publics_reels` · W: crédits photos · E2E | ✅ |

## Points du mémoire à mettre à jour

* Ch. 3 §2b « position transmise automatiquement **à l'agent le plus proche** » : l'implémentation notifie **tous les agents de la région** (et du service pour un incident). La distance à l'agent n'est pas connue (pas de suivi de position des équipes, choix de confidentialité). Formulation proposée : « transmise aux agents de secours couvrant la zone ».
* Ch. 3 §2a « chaque utilisateur crée un compte et se voit attribuer un rôle » : seuls les citoyens s'inscrivent ; les agents sont créés par le superadministrateur ; le superadministrateur est provisionné en ligne de commande.
* Ch. 4 : les captures et extraits demandés sont tous disponibles (voir GUIDE_UTILISATEUR.md et les fichiers cités ci-dessus). `docs/realisation/chapitre4_documentation.md` décrit encore les anciens endpoints (`/api/auth/register/`…) et doit être actualisé à partir de `API.md`.
