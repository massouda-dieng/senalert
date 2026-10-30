# API SenAlert — référence

Documentation interactive générée : **http://127.0.0.1:8000/api/docs/** (Swagger) · schéma : `docs/openapi.yaml` (régénérer : `python manage.py spectacular --file ../docs/openapi.yaml`).

Conventions :
* Authentification : `Authorization: Bearer <access>` (JWT, 15 min). Renouvellement : `POST /api/auth/jeton/rafraichir/ {refresh}` (rotation : l'ancien jeton est révoqué).
* Pagination : `?page=N&taille=20` (max 100) → `{count, next, previous, results}`.
* Erreurs : `{"detail": "...", "code": "...", "champs": {...}}`. Codes : 400 validation, 401 non authentifié/session expirée, 403 rôle insuffisant, 404 inexistant **ou non visible**, 409 conflit de statut, 429 trop de requêtes, 503 service externe indisponible / non configuré.

## Authentification et compte

| Méthode | Chemin | Accès | Description |
|---|---|---|---|
| POST | `/api/auth/inscription/` | public (10/h) | Crée un compte **citoyen** (tout champ `role` est ignoré). Renvoie jetons + profil |
| POST | `/api/auth/connexion/` | public (10/min) | `{username: e-mail ou identifiant, password}` → `{access, refresh, utilisateur}` |
| POST | `/api/auth/jeton/rafraichir/` | public | Rotation du jeton de rafraîchissement |
| POST | `/api/auth/deconnexion/` | connecté | `{refresh}` révoque cette session ; `{tout: true}` révoque toutes les sessions |
| GET/PATCH | `/api/auth/profil/` | connecté | Profil ; `role` en lecture seule ; `preferences` validées |
| DELETE | `/api/auth/profil/` | citoyen, agent | `{mot_de_passe, confirmation: "SUPPRIMER"}` : anonymisation du compte |
| POST | `/api/auth/mot-de-passe/` | connecté | `{ancien, nouveau}` ; ferme les autres sessions |
| POST | `/api/auth/mot-de-passe/oubli/` | public (5/h) | Envoie un lien (réponse identique que le compte existe ou non) |
| POST | `/api/auth/mot-de-passe/reinitialiser/` | public | `{uid, token, nouveau}` (lien valable 1 h, usage unique) |
| POST | `/api/auth/google/` | public | `{id_token}` Google vérifié côté serveur → jetons. Nouveau compte = citoyen |
| POST/DELETE | `/api/auth/google/lier/` | connecté | Lier / délier Google au compte courant |
| POST/DELETE | `/api/auth/appareils/` | connecté | Enregistrer / retirer un jeton FCM `{token, plateforme}` |

## Dossiers : incidents (`/api/incidents/`) et SOS (`/api/alertes/sos/`)

| Méthode | Chemin | Accès | Description |
|---|---|---|---|
| GET | `…/` | connecté | Liste **selon la visibilité du rôle**. Filtres : `statut` (multiple), `region`, `gravite`, `type_incident`, `service`, `agent`, `date_debut`, `date_fin`, `q`, `actifs`, `affecte_a_moi`, `doublons`, `ordering` |
| POST | `/api/incidents/` | citoyen, superadmin (30/h) | JSON ou multipart : `type_incident`, `latitude`, `longitude`, `precision_gps`, `region`, `adresse`, `description`, `date_incident`, `infos_complementaires`, `client_request_id`, `photos[]` (≤ 5, ≤ 5 Mo, JPEG/PNG/WEBP) → 201, ou 200 si déjà reçu |
| POST | `/api/alertes/sos/` | connecté (10/h) | `latitude`/`longitude` facultatifs (jamais inventés), `precision_gps`, `message`, `client_request_id` → 201 `{…, deja_enregistree: false}` ou 200 `{…, deja_enregistree: true}` |
| GET | `…/{id}/` | visible | Détail (intervention, photos, contact du déclarant si autorisé) |
| GET | `…/{id}/evenements/` | visible | Chronologie (événements internes masqués au citoyen) |
| POST | `…/{id}/affecter/` | superadmin | `{agent, service?, message?}` affecte ou réaffecte |
| POST | `…/{id}/prendre-en-charge/` | agent (zone + service) | nouveau → accepte |
| POST | `…/{id}/accepter/` | agent affecté | affecte → accepte |
| POST | `…/{id}/decliner/` | agent affecté | `{motif}` affecte → nouveau |
| POST | `…/{id}/demarrer/` | agent affecté | accepte → en_cours |
| POST | `…/{id}/resoudre/` | agent affecté | `{compte_rendu, difficultes?}` → resolu |
| POST | `…/{id}/annuler/` | superadmin ; citoyen propriétaire si nouveau/affecte | `{motif}` → annule |
| POST | `…/{id}/rejeter/` | superadmin | `{motif}` nouveau → refuse |
| POST | `…/{id}/gravite/` | superadmin, agent affecté | `{gravite}` |
| POST | `…/{id}/note/` | agent, superadmin | `{message, visible_citoyen}` |
| POST | `/api/incidents/{id}/completer/` | citoyen propriétaire | `message` et/ou `photos[]` sur un dossier ouvert |
| GET | `/api/incidents/{id}/photos/{photo_id}/` | visible | Fichier image (jamais servi publiquement) |
| GET | `/api/incidents/carte/` | connecté | Vue publique minimale (`jours`, `type_incident`, `region`) |
| GET | `/api/incidents/resume/` | connecté | Compteurs par statut selon la visibilité |

## Notifications

| GET | `/api/notifications/?non_lues=1` · POST `/api/notifications/{id}/lire/` · POST `/api/notifications/tout-lire/` · GET `/api/notifications/compteur/` | uniquement les siennes |
|---|---|---|

## Analyse et assistant

| Méthode | Chemin | Accès | Description |
|---|---|---|---|
| GET | `/api/analyse/zones-risque/` | agent, superadmin | `date_debut`, `date_fin`, `type_incident`, `niveau`, `region`, `comparer=1` ; renvoie les 14 régions, la formule, la date de calcul et un avertissement |
| GET/POST | `/api/analyse/zones-risque/historique/` | GET agent/superadmin, POST superadmin | Instantanés `ZoneRisque` |
| POST | `/api/analyse/assistant/` | connecté (20/min, 200/jour) | `{message ≤ 1000 car., historique?}` → `{reponse, source: groq|secours_local, alerte_urgence, fiches}` |

## Supervision, gestion, référentiels

| Méthode | Chemin | Accès | Description |
|---|---|---|---|
| GET | `/api/tableau-de-bord/statistiques/` | superadmin | `date_debut`, `date_fin` (30 j par défaut), `region`, `type_incident`, `service`, `granularite=jour|semaine|mois` ; chaque indicateur a sa définition dans `definitions` |
| GET | `/api/tableau-de-bord/activite-agent/` | agent | Indicateurs personnels |
| GET | `/api/tableau-de-bord/export/csv/` · `/export/pdf/` | superadmin | Mêmes filtres que la liste ; sans données personnelles ; journalisé |
| GET | `/api/gestion/utilisateurs/` | superadmin | Filtres `role`, `is_active`, `service`, `zone`, `q` |
| POST | `/api/gestion/utilisateurs/agents/` | superadmin | Crée un agent (service, zones, mot de passe initial à changer) |
| PATCH | `/api/gestion/utilisateurs/{id}/` | superadmin | `role` (citoyen ↔ agent uniquement), `is_active`, `service`, `zones` ; jamais sur soi-même ni sur un superadmin |
| GET | `/api/gestion/utilisateurs/statistiques/` | superadmin | Effectifs par rôle |
| GET/POST/PATCH | `/api/services/`, `/api/categories/` | lecture : connecté ; écriture : superadmin | Pas de suppression (désactivation) ; journalisé |
| GET/PATCH | `/api/parametres/{cle}/` | superadmin | Valeur validée selon la structure par défaut ; journalisé |
| GET | `/api/audit/` | superadmin | Journal (filtres `action`, `acteur`, dates) |
| GET | `/api/configuration/` | public | Catégories actives, régions, statuts, **numéros d'urgence vérifiés uniquement**, Google actif |
| GET | `/api/fiches-secours/` | public | Fiches de premiers secours |
| GET | `/api/services-proximite/?lat=&lng=&rayon=&type=` | connecté (30/min) | Établissements OpenStreetMap (`hopital`, `clinique`, `pharmacie`, `police`, `pompiers`) |
