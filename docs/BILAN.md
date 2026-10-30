# Bilan de la refonte v3

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
