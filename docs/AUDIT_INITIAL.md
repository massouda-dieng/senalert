# Rapport d'audit initial (29/10/2026, avant refonte)

## Périmètre examiné

* Mémoire : `SenAlert_Chapitres_1a3_Complet.docx` (chapitres 1 à 3, diagrammes UML inclus) et `Chapitre_4_SenAlert.docx` (**plan à compléter, sans contenu technique**). La conclusion, les références et les annexes ne sont pas encore rédigées.
* Dépôt `senalert/` (branche `main`, divergente de `pff/main` : 59/55 commits), avec des modifications indexées non commitées (sauvegardées dans `backups/changements-indexes-avant-refonte-*.patch`).
* Base SQLite locale : 5 comptes, 0 incident, 1 alerte SOS (sauvegardée dans `backups/db-avant-refonte-*.sqlite3`).

## Technologies réellement utilisées

| Partie | Constaté |
|---|---|
| Backend | Python 3.13, Django 6.0.6, DRF 3.17, SimpleJWT 5.5, SQLite uniquement (PostgreSQL prévu au mémoire mais non configurable), firebase-admin |
| Web | Deux fichiers HTML autonomes divergents (`dashboard/index.html` 785 lignes, `backend/dashboard/templates/dashboard/index.html` 671 lignes), Leaflet, Chart.js, `lucide@latest` non versionné. Le mémoire annonce React + Tailwind |
| Mobile | Flutter 3.24.5 / Dart 3.5.4, provider, go_router, dio + http (deux clients concurrents), flutter_map |

## Résultats des tests avant modification

* Backend : `python manage.py test` → **31 tests, 2 échecs, 1 erreur** (la vue des statistiques avait été remplacée par un stub dans les changements indexés).
* Flutter : `flutter analyze` → **1 erreur** (`SaGlassHeader` non défini dans `statistics_screen.dart`), 33 remarques ; `flutter test` → 12/12 (tests surtout de libellés).
* Web : aucun test.

## Failles de sécurité

| Gravité | Constat |
|---|---|
| **Critique** | Clé API Groq réelle commitée en clair dans `mobile/lib/features/first_aid/first_aid_screen.dart` (commits `78a3b38`, `227adc0`), présente sur `pff/main` ; c'est la même clé que dans `backend/.env`. **À révoquer.** |
| **Critique** | `run.sh` injectait la clé Groq dans l'application Flutter (`--dart-define`) : toute personne disposant de l'APK ou du site web pouvait l'extraire. |
| **Critique** | Inscription : le champ `role` était accepté → n'importe qui pouvait créer un compte `admin` ou `autorite`. L'écran d'inscription mobile proposait même « Citoyen / Agent ». |
| Élevée | Incidents lisibles sans authentification (`IsAuthenticatedOrReadOnly`), y compris descriptions et positions GPS de tous les citoyens. |
| Élevée | Liste de toutes les alertes SOS accessible à tout utilisateur connecté (citoyens compris). |
| Élevée | Tout « autorité » pouvait modifier n'importe quel incident (PUT/PATCH), sans notion de zone ni d'affectation ; un citoyen pouvait modifier le statut de son propre incident. |
| Élevée | SOS anonymes acceptés (`AllowAny`) ; coordonnées remplacées par Dakar (14.6928, -17.4467) quand absentes ou invalides. |
| Élevée | Assistant IA backend ouvert sans authentification ni limitation (coût Groq exploitable). |
| Moyenne | Photos servies publiquement via `/media/`, avec leurs métadonnées EXIF (position GPS du téléphone). Aucune validation de type ou de taille. |
| Moyenne | Jetons d'accès valables 24 h, pas de révocation ni de déconnexion côté serveur ; `pretty_dio_logger` journalisait en-têtes `Authorization` et corps. |
| Moyenne | `CORS_ALLOW_ALL_ORIGINS=True` ; `SECRET_KEY` par défaut « django-insecure » publiée dans le dépôt et utilisée dans `.env`. |
| Moyenne | Mots de passe de démonstration publiés dans `docs/DEMO_SOUTENANCE.md` (`senalert2026`) ; README citant `Papa / Papa`. |
| Faible | Aucune limitation de tentatives de connexion ; messages d'erreur internes renvoyés (`Exception Groq: …`). |

## Fonctions fictives ou trompeuses

* SOS mobile : message « coordonnées transmises au SAMU (15) & Pompiers (18) » alors qu'aucun service officiel n'est connecté ; position par défaut Dakar quand le GPS échoue.
* Services de proximité : liste codée en dur avec **distances inventées** (« 0.8 km »), statuts « Ouvert 24/7 », « Patrouille active ».
* Dashboard : « calcul d'ETA », « alarme », « bandeau d'alerte ANACIM » sans source de données.
* `IncidentProvider._demoData()` et insertion locale d'incidents « créés » même hors serveur ; statut mis à jour localement si le serveur refuse.
* Statistiques mobiles calculées côté client sur une liste partielle.

## Bugs constatés

* `push_service.dart` appelait `/api/api/auth/device-token/` (préfixe doublé) : aucun jeton FCM n'était jamais enregistré.
* La connexion mobile envoyait l'e-mail comme `username` : les comptes créés avec un identifiant différent ne pouvaient pas se connecter.
* `backend/dashboard/views.py` (indexé) : stub sans statistiques ; la version précédente utilisait `IsAuthenticated`, `timezone`, `timedelta` sans les importer.
* `alerts/serializers.py` : `serializers.ModelResourceSerializer` inexistant (repli fortuit).
* `fixtures_demo.py` **supprimait tous les incidents** avant d'insérer les données de démonstration.
* Un nouveau `Dio` créé à chaque appel (`get dio`), deux couches d'authentification concurrentes (`AuthService` avec SharedPreferences en clair et `AuthProvider`).
* Libellés de statuts incohérents entre mobile (`en_attente`, `traite`), SOS (`traite`) et incidents (`resolu`).
* Pas de pagination, pas de filtre combinable côté API, pas d'horodatage des transitions, pas d'affectation structurée.

## Écart avec le mémoire (chapitre 3)

| Exigence du mémoire | État avant refonte |
|---|---|
| Trois profils avec droits différenciés | Rôles présents mais auto-attribuables et non appliqués |
| Classe Intervention (affectation, clôture) | Absente |
| ZoneRisque (score, date de calcul) | Calcul à la volée seulement, sans date ni historique |
| Identifiants UUID | Entiers séquentiels |
| Gravité d'un incident | Absente |
| PostgreSQL | Non configurable |
| Dashboard React + Tailwind | HTML autonome |
| Notification de l'agent « le plus proche » puis du citoyen | Notification SOS aux autorités de la région uniquement, jetons jamais enregistrés |
| Fiches de premiers secours hors ligne | Texte codé en dur, en partie généré par l'IA |
