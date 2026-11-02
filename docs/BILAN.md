# Bilan de la refonte v3

## Version 3.7 (02/11/2026) : carte, services proches, Android

* **Carte** : ouverture sur la position du citoyen et de l'agent avec le repère « Vous êtes ici », nombre de signalements récents à moins de 5 km et distance du plus proche ; fond « Plan » par défaut (le fond clair n'a pas de détail partout au Sénégal).
* **Déclarant** : sur la carte, le superviseur et l'agent affecté voient « Déclaré par … » ; le citoyen voit « Votre signalement » sur les siens, les autres restent anonymes (`est_le_mien`, sans donnée personnelle).
* **Services proches** : extrait OpenStreetMap embarqué (1 600 établissements, `backend/core/data/services_osm.json`, script `scripts/extraire_services_osm.py`) utilisé quand Overpass est indisponible ; délai total limité à 8 s et pause de 10 min après une panne.
* **Assistant** : la mise en forme Markdown du modèle (`**`, `#`, puces `*`) est retirée côté serveur.
* **Mobile** : nouvel écran d'accueil (logo et anneaux sur le dégradé de la marque) ; simulateur compilé sans CDN (`--no-web-resources-cdn`).
* **Android** : un seul jeu de fichiers Gradle (`.kts`), plugin Google Services pour les notifications, `geolocator_android` fixé à 4.6.1 (compatible Flutter 3.24). APK : `flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=http://<IP-du-Mac>:8000/api`.
* **Configuration** : connexion Google web (`GOOGLE_CLIENT_ID_WEB`) et SMS de secours activables sans code, dans `.env` et dans Paramètres.

## Version 3.6 (01/11/2026) : identité institutionnelle bleu marine

* **Palette** : bleu marine `#102A43`, bleu professionnel `#1D4E89`, rouge `#E63946` (urgences et SOS uniquement), orange `#F59E0B` (vigilance), vert `#16A36A` (réussite), gris clair `#F1F5F9`, gris foncé `#334155`.
* **Système centralisé** : `design/couleurs.json` est la source unique. Le web le lit directement ; `node scripts/appliquer_couleurs.mjs` le propage à Flutter (`jetons.g.dart`), au favicon et aux manifestes.
* **Contraste** : le blanc n'atteint pas 4,5:1 sur le rouge et le vert de la palette. Le bouton SOS garde `#E63946` (grand texte) ; les petits textes et boutons utilisent `#C81E2C` et `#0E7C50`. Les graphiques utilisent `#2F6DB5`, `#1D4E89` étant hors de la plage de lisibilité d'un tracé.
* **Sens des couleurs** : statuts sans violet ni bleu ciel, boutons non urgents retirés du rouge, notifications colorées selon leur importance (web et mobile), missions classées par gravité avec liseré, répartition par niveau d'urgence en supervision.
* **Conservé** : API, authentification, données et fonctionnalités. Seul changement backend d'identité : la couleur des tableaux du rapport PDF.
* **Non modifié** : les couleurs des catégories d'incident, stockées en base et modifiables dans « Services et catégories ».

## Version 3.5 (31/10/2026) : refonte professionnelle

* **Identité** : vert profond `#075B45`, vert secondaire `#12805C`, rouge urgence `#DC2626`, orange vigilance `#F59E0B`, gris clair `#F5F7FA`, sur le web, le mobile, les icônes et les rapports PDF. Slogan « Ensemble, protégeons des vies ».
* **Accueil public** refait : en-tête fixe et menu mobile, héros, présentation, fonctionnalités, fonctionnement, trois espaces, pied de page complet.
* **Citoyen** : tableau de bord à deux colonnes, suivi par étapes, carte de la région, alertes de proximité, notifications, services ; barre d'onglets sur téléphone.
* **Agent** : colonnes Nouvelles alertes / En attente / En cours, actions directes (prendre en charge, accepter, décliner, démarrer, clôturer), carte, historique.
* **Superviseur** : indicateurs comparés à la période précédente, délai moyen global, agents mobilisés, grande carte, file à traiter, évolution des interventions, comparaison des périodes, activité récente, accès à l'administration, exports.
* **Assistant** : conseils de prévention adaptés au Sénégal et orientation vers le bon écran, aussi en mode secours.
* **Mobile** : écran de démarrage animé, connexion, accueils citoyen et agent, icônes natives.
* **Données de démonstration** : tout le cycle de vie, avec des délais plausibles, étiquetées et supprimables.
* **Corrigé** : injection de formules dans l'export CSV, images tronquées (erreur 500), paramètres invalides (erreurs 500), date sans fuseau sur le flux temps réel, signalement hors zone sans destinataire, session perdue par un rechargement, documentation de l'API publique en production, comptes de test possibles en production, compatibilité avec Flutter 3.41.
* **Tests** : 159 backend, 20 web, 18 Flutter, et un parcours à trois rôles joué dans Chrome avec un contrôle sur ordinateur, tablette et téléphone.

## Version 3.2 (30/10/2026)

* **Démonstration guidée** (`/app/supervision/demo`) : parcours SOS → signalement → affectation → acceptation → intervention → clôture, joué avec les comptes de test et la vraie machine à états, narration pour le jury, lecture automatique. Données « [DÉMO] » supprimables. Désactivée hors développement (`DEMO_GUIDEE`).
* **Alertes en direct** (agents, superadmin) : nouveau SOS / signalement détecté en ≈ 5 s (interrogation périodique de `/api/tableau-de-bord/flux/`, pas de WebSocket), sirène générée par le navigateur, carte d'alerte rouge, notifications du navigateur, bouton pour couper le son.
* **Mode sombre** web (bouton dans la barre supérieure, choix dans le profil) et mobile (Profil → Apparence : système / clair / sombre).
* **Application installable (PWA)** : manifeste, icônes, service worker (pages et fichiers disponibles hors connexion, jamais l'API), bouton « Installer l'application ». Vérifié : aucune erreur d'installabilité dans Chrome.
* **SOS par SMS de secours** : quand l'envoi échoue, bouton « Envoyer le SOS par SMS » avec position GPS, vers le numéro du paramètre `sms_secours` (inactif par défaut : il faut un numéro de réception réel).
* **Simulateur mobile** (`/app/simulateur`) : l'app Flutter dans un cadre iPhone / Android.
* Guide Android pas à pas : `docs/ANDROID.md`.
* Non réalisés car ils dépendent de vous : vos propres photos (à me transmettre), traductions wolof / pulaar validées par des locuteurs, installation d'Android Studio (licences à accepter), identifiants Google Cloud.

## Version 3.1 (30/10/2026)

* **Nouvelle identité « Sénégal vibrant »** (web + mobile) : vert `#00853F`, jaune `#FDEF42` et rouge `#E31B23` du drapeau (rouge toujours réservé au SOS), bande tricolore, étoile, logo redessiné. Graphiques : couple vert/rouge validé pour le daltonisme (ΔE 8,5) avec trait pointillé pour les SOS.
* **9 photos réelles sous licence libre** (Wikimedia Commons : Brigade nationale des sapeurs-pompiers, Croix-Rouge du Sénégal, ambulance, Dakar, rue inondée) avec auteur et licence affichés sur chaque image et une page « Crédits photos ». Elles illustrent l'application et ne représentent aucun incident réel.
* **Page vitrine publique** (`/app/`) : héros photo, chiffres **réels** de la base, fonctionnalités, « comment ça marche » (scénario illustré, présenté comme tel), alertes en cours. Pas de faux témoignages ni de faux chiffres.
* **Alertes de zone** : publication par le superadmin (niveau, régions, consignes, fin), bandeau chez les citoyens et agents concernés, notification ciblée, couche sur les cartes.
* **Communauté « Autour de moi »** : incidents récents triés par distance, confirmation « je le vois aussi » (nombre visible des agents et du superadmin), messages publics modérables.
* **Carte avancée** : fonds plan / clair / satellite, recherche d'adresse, « me localiser », couches incidents, carte de chaleur (web), zones à risque, alertes de zone, dossiers ouverts et SOS (agents, superadmin), chaque dossier ouvert n'y figurant qu'une fois ; les services proches ont leur page dédiée.
* **Mobile** : écran de bienvenue en carrousel photo avant connexion, accueil et tableau agent illustrés, onglet « Autour », carte à couches.
* Tests : 130 backend, 13 web, 13 Flutter.

## Conservé

* Stack du mémoire : Django REST + JWT, Flutter, Leaflet/OpenStreetMap, Firebase, Groq.
* Données existantes : 5 comptes (rôles convertis `admin`→`superadmin`, `autorite`→`agent`), l'alerte SOS existante (référence `SOS-2026-000001`), jetons d'appareils. Migrations historiques intactes ; nouvelles migrations réversibles pour les rôles et les statuts.
* Formule du score de risque du mémoire (poids, facteur 7 jours, seuils) — inchangée, tests existants conservés et complétés.
* Charte visuelle de la refonte précédente (bleu nuit, rouge SOS, `AppColors`), étendue au web.

## Ajouté

* **Cycle de vie complet** : `Intervention`, affectation / réaffectation, prise en charge, acceptation, refus motivé, démarrage, clôture avec compte rendu, annulation, rejet, gravité, notes ; historique horodaté (`EvenementDossier`) ; contrôle de concurrence (409).
* Références lisibles (`INC-…`, `SOS-…`) et UUID ; idempotence (`client_request_id`) ; anti-répétition SOS ; détection de doublons potentiels ; retards de prise en charge.
* Services et catégories administrables (8 catégories dont Agression et Urgence médicale, 5 services) ; paramètres métier modifiables et journalisés ; journal d'audit.
* Comptes : connexion par e-mail ou identifiant, réinitialisation du mot de passe, changement de mot de passe, déconnexion d'un ou de tous les appareils, suppression/anonymisation du compte, préférences de notification, **connexion Google** (web + mobile, vérification serveur), création d'agents par le superadmin.
* Notifications en base (historique, lu/non lu, statut push distinct) avec FCM en option.
* Statistiques de supervision avec définitions, filtres et séries complètes ; activité agent ; qualité des données ; exports CSV et PDF.
* Score de risque : 14 régions, comparaison de périodes, données insuffisantes, instantanés historisés (`ZoneRisque`).
* Services de proximité réels (OpenStreetMap / Overpass, cache 1 h).
* 12 fiches de premiers secours sourcées (IFRC 2020, Croix-Rouge), embarquées dans l'app mobile pour le hors ligne.
* Assistant : Groq côté serveur, masquage des données personnelles, anti-injection, filtre des numéros non vérifiés, mode secours local.
* PostgreSQL configurable ; documentation OpenAPI (`/api/docs/`) ; commandes `creer_superadmin`, `creer_comptes_test`, `donnees_demo`, `anonymiser_dossiers_anciens` ; scripts de sauvegarde/restauration.
* **Application web React + Tailwind** (exigence du mémoire) : 3 espaces, ~20 écrans.
* **Application mobile réécrite** : client API unique, renouvellement de session, SOS fiable, formulaire progressif avec brouillon, suivi, carte, services, fiches hors ligne, assistant, notifications, profil ; espace agent complet.
* Tests : 119 backend (dont scénarios de bout en bout), 11 web, 12 Flutter, parcours navigateur réel.

## Corrigé

Voir AUDIT_INITIAL.md : rôle auto-attribuable, données publiques, SOS anonymes et coordonnées inventées, faux messages « transmis au SAMU », distances inventées, clé Groq exposée, photos publiques avec EXIF, jetons 24 h non révocables, journalisation des jetons, chemin d'enregistrement FCM doublé, connexion par e-mail cassée, statistiques en échec, script de démonstration destructeur, permissions mobiles excessives, descriptions d'usage iOS absentes.

## Fusionné

* Deux dashboards HTML concurrents → une seule application web React (`web/`).
* Deux clients HTTP mobiles (`http` + `AuthService` et `dio` + `AuthProvider`) → un client (`core/api.dart`).
* Statuts SOS (`traite`) et incidents (`resolu`, `en_attente` côté mobile) → un seul référentiel de 7 statuts partagé.
* Modèle `Autorite` → `AgentProfil` (données copiées par migration).

## Supprimé (après vérification des usages)

| Élément | Raison | Où retrouver |
|---|---|---|
| `dashboard/index.html`, template Django du dashboard | remplacés par `web/` | `docs/archives/` |
| `backend/fixtures_demo.py` | supprimait toutes les données ; remplacé par `donnees_demo` | `docs/archives/…_DESTRUCTIF.py` |
| `backend/analyse/test_flutter.dart` | test Dart placé dans le backend, jamais exécuté | `docs/archives/` |
| Écran Statistiques mobile (indexé, non commité, ne compilait pas) | statistiques calculées côté client sur une liste partielle ; remplacées par les statistiques serveur (web) et l'activité agent (mobile) | `backups/changements-indexes-avant-refonte-*.patch` |
| Écrans mobiles d'onboarding/splash animés, kit `sa_ui.dart` (silhouettes, robot) | décoratifs ; remplacés par un kit sobre (`ui/kit.dart`) | historique Git |
| Son d'alerte, `audioplayers`, `fluttertoast`, `http`, `pretty_dio_logger`, `fl_chart` | inutiles ou risqués (journalisation des jetons) | — |
| Endpoints `/api/auth/register|login|mes-incidents|device-token`, `/api/alerts/sos/list/`, `/dashboard/stats/` | remplacés (voir API.md) | — |

## Fonctionnalités partielles ou bloquées

| Fonction | État | Ce qui manque |
|---|---|---|
| Connexion Google | code complet, testé avec jetons simulés | identifiants OAuth Google Cloud (voir CONFIGURATION_EXTERNE.md) |
| Push FCM sur téléphone | backend prêt et testé en simulation | compilation Android/iOS, variante debug dans Firebase, clé APNs |
| Applications Android / iOS compilées | code et manifestes prêts, analysés | Android SDK / Xcode absents de ce Mac |
| Numéro du SAMU | masqué | confirmation officielle (15 ou 1515) |
| Fiches de premiers secours | rédigées et sourcées | validation par un professionnel de santé (`valide_par`) |
| Temps réel | actualisation périodique + indicateur de synchronisation | WebSocket (Channels + Redis) si nécessaire |
| E-mails | affichés dans la console | serveur SMTP |
| Conformité CDP | mesures techniques en place | démarches administratives, politique de confidentialité |
| Intégration officielle SAMU / Police / ANASER | hors périmètre | aucune API officielle disponible |
| Langues locales | interface en français, textes centralisés | traductions validées (wolof, pulaar…) |

## Services externes

| Service | Usage | Obligatoire ? |
|---|---|---|
| OpenStreetMap (tuiles + Overpass) | cartes, services de proximité | oui pour les cartes (public, sans clé) |
| Groq | assistant IA | non (mode secours) |
| Firebase Cloud Messaging | push | non (historique in-app) |
| Google OAuth / OIDC | connexion Google | non |
| SMTP | e-mails de réinitialisation | non en démonstration |
| PostgreSQL | base de production | recommandé en production |

## Fonctions évaluées et écartées (pour l'instant)

* **SMS** : coût par message et contrat opérateur nécessaires ; à étudier avec Orange/Free (USSD/SMS de repli quand il n'y a pas de données mobiles).
* **Géorepérage / alertes territoriales** : nécessite la position continue des citoyens (contraire à la minimisation) ou des abonnements par zone ; à concevoir avec la CDP.
* **Disponibilité réelle des équipes** : aucune source fiable ; afficher une disponibilité non maintenue serait trompeur.
* **Prédictions statistiques** : le volume de données ne permet pas de valider un modèle ; la méthode du mémoire reste un indicateur descriptif.
* **Synchronisation hors ligne des signalements** : partiellement couverte (brouillon conservé + idempotence) ; une file d'envoi différé automatique est une amélioration possible.

## Améliorations futures recommandées

1. Cookies `HttpOnly` pour la session web ; file de tâches (Celery/RQ) pour les envois push et les instantanés planifiés.
2. WebSocket pour les tableaux de bord des agents.
3. Position de l'agent (consentie, en service) pour proposer l'agent le plus proche, conforme au diagramme de séquence.
4. Envoi différé des signalements hors connexion (file locale) côté mobile.
5. Traductions validées en langues nationales ; mode sombre.
6. Tests d'intégration mobiles sur appareils réels (`integration_test`) et tests de charge.
7. Déploiement : conteneurisation, sauvegardes chiffrées hors site, supervision des erreurs (Sentry).
