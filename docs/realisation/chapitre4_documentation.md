# CHAPITRE 4 — RÉALISATION DE L'APPLICATION SENALERT
## Documentation Technique Complète

> **Dossier préparatoire** pour la rédaction du Chapitre 4 du mémoire.
> Toutes les informations proviennent du code réel, des tests exécutés et de l'application telle qu'elle fonctionne en local.

---

## 4.1 Environnement de développement

### Système et outils

| Composant | Version | Notes |
|---|---|---|
| Système d'exploitation | macOS | Développement local |
| Python | 3.13.5 (miniconda) | Backend Django |
| Django | 6.0.6 | Framework web |
| Flutter SDK | 3.x | Application mobile |
| Dart | ≥ 3.0.0 | Langage mobile |
| Git | Installé | Contrôle de version |
| GitHub | github.com/massouda-dieng/senalert | Dépôt distant |

### Éditeurs utilisés
- VS Code / Cursor avec extensions Flutter, Python, Django
- Android Studio pour l'émulateur Android

### Packages backend (requirements.txt)
```
Django==6.0.6
djangorestframework==3.17.1
djangorestframework_simplejwt==5.5.1
django-cors-headers==4.9.0
python-decouple==3.8
pillow==12.2.0
firebase-admin==7.5.0
pandas==3.0.3
numpy==2.4.6
```

---

## 4.2 Architecture finale

```
┌─────────────────────────────────────────────────────────────┐
│                     APPLICATION MOBILE                       │
│                    Flutter (Dart) — iOS/Android              │
│  Citoyen : SOS, Signalement, Carte, Services, Premiers secours│
│  Agent   : Dashboard interventions, Mise à jour statuts      │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP/HTTPS + JWT
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    API REST DJANGO                           │
│              Django REST Framework + JWT Auth                │
│  /api/auth/    /api/incidents/    /api/alerts/               │
│  /api/analyse/ /dashboard/stats/                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │SQLite3   │ │ Firebase │ │ Groq AI  │
        │(démo)    │ │  Push    │ │Assistant │
        │PostgreSQL│ │Notifs    │ │          │
        │(prod)    │ └──────────┘ └──────────┘
        └──────────┘

┌─────────────────────────────────────────────────────────────┐
│                   DASHBOARD WEB ADMIN                        │
│             HTML + CSS + JavaScript + Leaflet                │
│  Statistiques, Carte incidents, Alertes SOS, Filtres         │
└─────────────────────────────────────────────────────────────┘
```

---

## 4.3 Structure des dossiers

```
senalert/
├── README.md                    ← Documentation principale
├── .gitignore                   ← Exclusions Git
├── backend/
│   ├── accounts/                ← Gestion des utilisateurs et rôles
│   │   ├── models.py            ← User (AbstractUser), Autorite, DeviceToken
│   │   ├── serializers.py       ← RegisterSerializer, UserSerializer
│   │   ├── views.py             ← Inscription, Profil, DeviceToken, Interventions agent
│   │   ├── urls.py              ← Routes auth
│   │   └── tests.py             ← Tests inscription/connexion
│   ├── alerts/
│   │   ├── models.py            ← AlerteSOS
│   │   ├── views.py             ← CreateSOSAlertView, ListSOSAlertView + Firebase push
│   │   ├── serializers.py       ← AlerteSOSSerializer
│   │   └── tests.py             ← Test création SOS
│   ├── incidents/
│   │   ├── models.py            ← Incident (type, statut, région, GPS, photo)
│   │   ├── views.py             ← CRUD incidents avec filtres
│   │   ├── permissions.py       ← IsOwnerOrAdminOrReadOnly
│   │   ├── serializers.py       ← IncidentSerializer
│   │   └── tests.py             ← Tests CRUD + permissions (8 tests)
│   ├── analyse/
│   │   ├── analyzer.py          ← Calcul score de risque par région
│   │   ├── views.py             ← ZonesRisqueView, AIAssistantView
│   │   └── tests.py             ← Tests score risque (7 tests unitaires)
│   ├── dashboard/
│   │   ├── views.py             ← DashboardStatsView — endpoint stats
│   │   └── urls.py              ← /dashboard/stats/
│   ├── config/
│   │   ├── settings.py          ← Configuration Django + JWT + Firebase
│   │   └── urls.py              ← Routage principal
│   ├── .env.example             ← Modèle de configuration
│   └── requirements.txt
├── dashboard/
│   └── index.html               ← Dashboard web administrateur (627 lignes)
├── mobile/
│   ├── pubspec.yaml             ← Dépendances Flutter
│   └── lib/
│       ├── main.dart            ← Point d'entrée
│       ├── app.dart             ← Routing GoRouter + ThemeData
│       ├── core/constants/
│       │   ├── app_colors.dart  ← Palette de couleurs SenAlert
│       │   └── api_constants.dart ← URL base de l'API
│       ├── features/
│       │   ├── splash/          ← Écran de démarrage
│       │   ├── onboarding/      ← Écran d'introduction
│       │   ├── auth/            ← Connexion + Inscription
│       │   ├── home/            ← Tableau de bord citoyen
│       │   ├── sos/             ← Déclenchement SOS (GPS + API)
│       │   ├── report/          ← Formulaire de signalement
│       │   ├── incidents/       ← Liste + Détail + Carte
│       │   ├── first_aid/       ← Guide premiers secours
│       │   ├── services/        ← Services de proximité
│       │   ├── profile/         ← Profil utilisateur
│       │   └── agent/           ← Dashboard agent de secours
│       └── services/
│           └── auth_service.dart ← Service d'authentification
└── docs/
    └── realisation/             ← Ce dossier de documentation
```

---

## 4.4 Configuration et démarrage du backend

### Installation

```bash
cd backend
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Éditer .env selon votre environnement
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

### Base de données

En développement, Django utilise SQLite3 (`backend/db.sqlite3`), créé automatiquement lors de la première migration.

Les migrations couvrent :
- `accounts` : 3 migrations (User, Autorite, DeviceToken)
- `alerts` : 2 migrations (AlerteSOS, modification user nullable)
- `incidents` : 1 migration (Incident complet)

---

## 4.5 Modèle de données

### Entité User (accounts)

```python
class User(AbstractUser):
    ROLE_CHOICES = [
        ('citoyen', 'Citoyen'),
        ('admin', 'Administrateur'),
        ('autorite', 'Autorité'),  # = Agent de secours
    ]
    role = CharField(max_length=20, choices=ROLE_CHOICES, default='citoyen')
    telephone = CharField(max_length=20, blank=True)
    region = CharField(max_length=100, blank=True)
```

### Entité Incident (incidents)

```python
class Incident(models.Model):
    type_incident  # accident, inondation, incendie, electricite, insecurite, autre
    description    # TextField
    photo          # ImageField (upload_to='incidents/')
    latitude       # FloatField
    longitude      # FloatField
    region         # 14 régions du Sénégal
    statut         # nouveau, en_cours, resolu
    citoyen        # ForeignKey(User)
    date_creation  # DateTimeField(auto_now_add=True)
```

### Entité AlerteSOS (alerts)

```python
class AlerteSOS(models.Model):
    user       # ForeignKey(User, null=True, blank=True)  ← anonyme possible
    latitude   # FloatField
    longitude  # FloatField
    date_creation  # DateTimeField(auto_now_add=True)
    statut     # nouveau, en_cours, traite
```

### Entité Autorite (accounts)

```python
class Autorite(models.Model):
    user = OneToOneField(User)
    type_autorite  # pompiers, police, sante, senelec, onas
    region         # Région couverte
    nom_service    # Nom du service

    # Mapping type d'incident → type d'autorité compétente
    TYPE_INCIDENT_MAP = {
        'pompiers': ['incendie'],
        'police': ['insecurite', 'accident'],
        'sante': ['accident', 'insecurite'],
        'senelec': ['electricite'],
        'onas': ['inondation'],
    }
```

---

## 4.6 API REST — Détail des endpoints

### Authentification

| Endpoint | Méthode | Corps | Réponse |
|---|---|---|---|
| `/api/auth/register/` | POST | `{username, password, role, telephone, region}` | `201 Created` |
| `/api/auth/login/` | POST | `{username, password}` | `{access, refresh}` |
| `/api/auth/token/refresh/` | POST | `{refresh}` | `{access}` |
| `/api/auth/profile/` | GET/PUT | — | Données utilisateur |

### Incidents

| Endpoint | Méthode | Auth | Description |
|---|---|---|---|
| `/api/incidents/` | GET | Non requis | Liste (filtrable) |
| `/api/incidents/` | POST | Requis | Créer |
| `/api/incidents/{id}/` | GET | Non requis | Détail |
| `/api/incidents/{id}/` | PATCH | Owner/Admin | Modifier statut |
| `/api/incidents/{id}/` | DELETE | Owner/Admin | Supprimer |

Filtres disponibles : `?region=dakar&type_incident=incendie&statut=nouveau`

### Alertes SOS

| Endpoint | Méthode | Auth | Description |
|---|---|---|---|
| `/api/alerts/sos/` | POST | Non requis | Déclencher SOS |
| `/api/alerts/sos/list/` | GET | Requis | Lister (admin/autorité) |

### Analyse

| Endpoint | Méthode | Auth | Description |
|---|---|---|---|
| `/api/analyse/zones-risque/` | GET | Requis | Score de risque par région |
| `/api/analyse/ai-assistant/` | POST | Non requis | Assistant IA Groq |

### Dashboard

| Endpoint | Méthode | Auth | Description |
|---|---|---|---|
| `/dashboard/stats/` | GET | Requis | Stats agrégées (incidents, alertes, citoyens) |

---

## 4.7 Score de risque — Méthode documentée

### Paramètres

| Type d'incident | Poids | Justification |
|---|---|---|
| Incendie | 5 | Risque vital et propagation rapide |
| Inondation | 4 | Impact étendu, déplacements |
| Insécurité | 4 | Menace directe aux personnes |
| Accident | 3 | Urgence médicale |
| Coupure électricité | 2 | Impact infrastructurel |
| Autre | 1 | Non classifié |

### Seuils de niveau

| Score | Niveau |
|---|---|
| ≥ 15 | Critique |
| ≥ 8 | Élevé |
| ≥ 3 | Moyen |
| < 3 | Faible |

### Facteur temporel

Les incidents survenus dans les **7 derniers jours** voient leur poids multiplié par **2.0**. Les incidents plus anciens ont un facteur **1.0**.

### Formule

```
score_région = Σ (poids(type) × facteur_temporel(date))
```

> **Limites** : Ce score est un indicateur descriptif basé sur les signalements enregistrés. Il ne constitue pas un système prédictif validé. Une zone sans signalement n'implique pas l'absence de risque.

---

## 4.8 Résultats des tests

```
Ran 22 tests in 23.372s — OK

✅ accounts.AccountAPITests.test_register_and_login_success
✅ alerts.AlertAPITests.test_create_sos_alert
✅ analyse.TestAnalyserZonesRisque.test_liste_vide
✅ analyse.TestAnalyserZonesRisque.test_tri_par_score
✅ analyse.TestAnalyserZonesRisque.test_une_region
✅ analyse.TestCalculerScoreRisque.test_incident_ancien
✅ analyse.TestCalculerScoreRisque.test_incident_recent
✅ analyse.TestCalculerScoreRisque.test_liste_vide
✅ analyse.TestDeterminerNiveau.test_critique
✅ analyse.TestDeterminerNiveau.test_eleve
✅ analyse.TestDeterminerNiveau.test_faible
✅ analyse.TestDeterminerNiveau.test_moyen
✅ incidents.DashboardStatsTests.test_stats_counts_match_database
✅ incidents.DashboardStatsTests.test_stats_requires_authentication
✅ incidents.DashboardStatsTests.test_stats_returns_correct_structure
✅ incidents.IncidentAPITests.test_create_incident
✅ incidents.IncidentAPITests.test_filter_incidents_by_region_or_status
✅ incidents.IncidentPermissionTests.test_admin_can_update_any_incident
✅ incidents.IncidentPermissionTests.test_any_user_can_read_incident
✅ incidents.IncidentPermissionTests.test_other_user_cannot_update_incident
✅ incidents.IncidentPermissionTests.test_owner_can_update_own_incident
✅ incidents.IncidentPermissionTests.test_unauthenticated_cannot_delete
```

---

## 4.9 Difficultés rencontrées et solutions

| Difficulté | Solution adoptée |
|---|---|
| Firebase Admin SDK — module non trouvé dans l'env miniconda | Gestion gracieuse avec try/except dans settings.py ; warning non bloquant |
| Dashboard web non React (mémoire l'annonce) | Utilisation d'HTML/CSS/JS vanilla + Leaflet fonctionnel pour la démo |
| PostgreSQL vs SQLite3 | SQLite3 pour le développement local ; configuration PostgreSQL préparée dans `.env.example` |
| Permissions trop permissives sur les incidents | Création de `IsOwnerOrAdminOrReadOnly` avec tests dédiés |
| `dashboard/views.py` vide | Remplacement complet par un endpoint JSON d'agrégation |

---

## 4.10 Limites et perspectives

### Limites actuelles
- Application non déployée en production (local uniquement)
- Firebase push : configuré mais nécessite les fichiers de credentials réels
- Base de données SQLite3 : non adaptée à plusieurs serveurs simultanés
- Score de risque : descriptif, pas prédictif

### Perspectives d'évolution
- Déploiement sur un serveur cloud (Heroku, Railway, AWS)
- Migration vers PostgreSQL en production
- Intégration de données réelles des services de secours
- Module de suivi des interventions en temps réel
- Tableau de bord offline pour les zones à faible connectivité
- Extension aux autres pays de la CEDEAO

---

## 4.11 Liste des captures d'écran pour le mémoire

| Fig. | Titre | Écran | Étapes de reproduction | Résultat attendu |
|---|---|---|---|---|
| 4.1 | Écran de connexion mobile | `/login` | Lancer l'app Flutter | Formulaire connexion avec logo SenAlert |
| 4.2 | Tableau de bord citoyen | `/home` | Connexion en tant que citoyen | Actions : SOS, Signalement, Carte, Services |
| 4.3 | Déclenchement SOS | `/sos` | Bouton SOS → maintenir | Animation pulse rouge, statut GPS |
| 4.4 | Formulaire de signalement | `/report` | Clic "Signaler" | Formulaire type, description, photo, localisation |
| 4.5 | Carte des incidents | `/map` | Menu "Carte" | Carte OpenStreetMap avec marqueurs incidents |
| 4.6 | Services de proximité | `/services` | Menu "Services" | Liste des services (police, pompiers, hôpitaux) |
| 4.7 | Guide premiers secours | `/first-aid` | Menu "Premiers secours" | Fiches consultables |
| 4.8 | Dashboard agent | `/agent-dashboard` | Connexion rôle autorité | Liste interventions assignées |
| 4.9 | Connexion dashboard admin | Dashboard web | Ouvrir `dashboard/index.html` | Formulaire login |
| 4.10 | Tableau de bord national | Dashboard web | Connexion admin | Statistiques, carte, incidents récents |
| 4.11 | Carte Leaflet incidents | Dashboard web | Section carte | Markers incidents sur carte Sénégal |
| 4.12 | Zones à risque | Dashboard web | Stats | Score par région |
| 4.13 | API — liste incidents | Navigateur | GET `/api/incidents/` | JSON incidents |
| 4.14 | Tests Django — 22 OK | Terminal | `python manage.py test` | Résultat 22 tests verts |

> **Important** : Toutes les captures doivent être réalisées avec des données synthétiques (pas de données personnelles réelles). Utiliser `python fixtures_demo.py` pour peupler la base de démo.
