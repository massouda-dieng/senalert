# SenAlert 🚨 — Plateforme Nationale d'Urgences Citoyennes

> Projet de fin de formation · ISEP Amadou Traoré de Diamniadio, Sénégal
> Promotion 2025–2026

[![Tests](https://img.shields.io/badge/tests-22%20passed-brightgreen)]()
[![Django](https://img.shields.io/badge/Django-6.0-green)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)]()
[![License](https://img.shields.io/badge/license-Academic-orange)]()

---

## 🎯 Présentation

SenAlert est une plateforme d'urgences citoyennes pour le Sénégal, composée de :

- **Application mobile Flutter** — pour les citoyens et les agents de secours
- **Dashboard web** — pour les administrateurs nationaux (HTML/JS/CSS + Leaflet)
- **Backend API REST** — Django REST Framework, authentification JWT, SQLite3 (démo) / PostgreSQL (production)

---

## 👥 Équipe

| Membre | Rôle | Branche de travail |
|---|---|---|
| Massouda Dieng | Cheffe de projet, coordination | `feature/massouda-coordination-dashboard` |
| Ndeye Ngone Fall | Backend API | `feature/ndeye-backend-api` |
| Dieynaba Deme | Mobile citoyen | `feature/dieynaba-mobile-citoyen` |
| Asmaou Balde | Mobile agent + tests | `feature/asmaou-mobile-agent-tests` |

---

## 🏗️ Architecture

```
senalert/
├── backend/          ← Django REST Framework (Python 3.13)
│   ├── accounts/     ← Utilisateurs, rôles, authentification
│   ├── alerts/       ← Alertes SOS + notifications Firebase
│   ├── incidents/    ← Signalements + permissions + filtres
│   ├── analyse/      ← Score de risque par région + IA Groq
│   ├── dashboard/    ← Endpoint stats pour le dashboard
│   └── config/       ← Settings, URLs, WSGI
├── dashboard/        ← Dashboard administrateur web (HTML/JS/CSS + Leaflet)
├── mobile/           ← Application Flutter (citoyens + agents)
└── docs/             ← Documentation technique
```

---

## ⚡ Installation rapide

### Prérequis

- Python 3.10+ (testé sur 3.13)
- Flutter SDK 3.x
- Git

### 1. Cloner le dépôt

```bash
git clone https://github.com/massouda-dieng/senalert.git
cd senalert
```

### 2. Backend Django

```bash
cd backend

# Créer l'environnement virtuel
python3 -m venv env
source env/bin/activate  # macOS/Linux
# env\Scripts\activate   # Windows

# Installer les dépendances
pip install -r requirements.txt

# Configurer l'environnement
cp .env.example .env
# Éditer .env avec vos valeurs

# Appliquer les migrations
python manage.py migrate

# Créer un compte administrateur
python manage.py createsuperuser

# Lancer le serveur de développement
python manage.py runserver
```

L'API sera disponible sur `http://127.0.0.1:8000/`

### 3. Dashboard Web (administrateur)

Ouvrir directement dans un navigateur :
```
senalert/dashboard/index.html
```

> **Note** : Le dashboard se connecte par défaut à `http://127.0.0.1:8000`. Assurez-vous que le backend est lancé.

### 4. Application Mobile Flutter

```bash
cd mobile

# Installer les dépendances Flutter
flutter pub get

# Vérifier la configuration
flutter doctor

# Lancer sur un émulateur ou appareil
flutter run
```

> Par défaut, le mobile pointe vers `http://10.0.2.2:8000` (émulateur Android) ou `http://127.0.0.1:8000` (iOS Simulator). Modifier dans `lib/core/constants/api_constants.dart`.

---

## 🔑 Variables d'environnement

Copier `backend/.env.example` en `backend/.env` :

| Variable | Description | Exemple |
|---|---|---|
| `SECRET_KEY` | Clé secrète Django | `django-insecure-...` |
| `DEBUG` | Mode debug | `True` |
| `ALLOWED_HOSTS` | Hôtes autorisés | `127.0.0.1,localhost` |
| `FIREBASE_CREDENTIALS_PATH` | Chemin credentials Firebase | `firebase-adminsdk.json` |
| `GROQ_API_KEY` | Clé API Groq (IA assistant) | `gsk_...` |

---

## 🛢️ Base de données

- **Développement / Démo** : SQLite3 (configuré par défaut, aucune installation requise)
- **Production recommandée** : PostgreSQL (voir `.env.example` pour la configuration)

> ⚠️ Le mémoire annonce PostgreSQL. Pour la soutenance, SQLite3 est utilisé en démonstration locale. La migration vers PostgreSQL ne nécessite que de changer les variables d'environnement.

---

## 🔔 Firebase (Notifications Push)

1. Créer un projet sur [Firebase Console](https://console.firebase.google.com)
2. Ajouter une application Android et/ou iOS
3. Télécharger `google-services.json` (Android) → `mobile/android/app/`
4. Télécharger `GoogleService-Info.plist` (iOS) → `mobile/ios/Runner/`
5. Télécharger le fichier Admin SDK (JSON) → `backend/firebase-adminsdk.json`

> ⚠️ Ne jamais committer ces fichiers dans Git. Ils sont dans `.gitignore`.

---

## 🧪 Tests

### Backend

```bash
cd backend
python manage.py test --verbosity=2
```

**Résultat attendu :** 22 tests, 0 erreur

Modules couverts :
- `accounts` : inscription, connexion JWT
- `alerts` : création alerte SOS
- `analyse` : score de risque (7 tests unitaires)
- `incidents` : CRUD, filtres, permissions (8 tests)
- `dashboard` : stats API (3 tests)

### Flutter (analyse statique)

```bash
cd mobile
flutter analyze
flutter test
```

---

## 📡 API — Endpoints principaux

| Méthode | Endpoint | Accès | Description |
|---|---|---|---|
| POST | `/api/auth/register/` | Public | Inscription |
| POST | `/api/auth/login/` | Public | Connexion JWT |
| POST | `/api/auth/token/refresh/` | Public | Rafraîchir le token |
| GET/PUT | `/api/auth/profile/` | Authentifié | Profil utilisateur |
| POST | `/api/alerts/sos/` | Public | Déclencher une alerte SOS |
| GET | `/api/alerts/sos/list/` | Authentifié | Lister les alertes SOS |
| GET/POST | `/api/incidents/` | Public(lire)/Auth(créer) | Incidents |
| GET/PATCH/DELETE | `/api/incidents/{id}/` | Owner/Admin | Détail incident |
| GET | `/api/analyse/zones-risque/` | Authentifié | Score de risque par région |
| POST | `/api/analyse/ai-assistant/` | Public | Assistant IA Groq |
| GET | `/dashboard/stats/` | Authentifié | Stats dashboard |

---

## 🗂️ Branches de travail

| Branche | Responsable | Périmètre |
|---|---|---|
| `main` | Massouda | Intégration finale, code stable |
| `feature/massouda-coordination-dashboard` | Massouda | Dashboard web, intégration, documentation |
| `feature/ndeye-backend-api` | Ndeye | Backend API, modèles, migrations, sécurité |
| `feature/dieynaba-mobile-citoyen` | Dieynaba | Écrans citoyens (SOS, signalement, carte, services) |
| `feature/asmaou-mobile-agent-tests` | Asmaou | Écrans agent, tests unitaires, validation |

---

## ⚠️ Limites du prototype

- **SQLite3 en démo** : base de données locale, non partagée entre plusieurs serveurs
- **Firebase** : configuré mais nécessite les fichiers de credentials pour les notifications push
- **Déploiement** : l'application fonctionne uniquement en local (démo)
- **Services de proximité** : données représentatives, non exhaustives
- **Premiers secours** : fiches pédagogiques à sources documentées

---

## 🔒 Sécurité

- Authentification JWT (access 1j, refresh 7j)
- Permissions par rôle (citoyen, autorité, admin)
- Permissions d'ownership sur les ressources
- CORS configuré selon DEBUG
- Secrets exclus du dépôt Git via `.gitignore`

> ⚠️ **Action requise** : si des clés ont été exposées dans l'historique git, les révoquer et renouveler sur les consoles respectives (Groq, Firebase).

---

## 📋 Données de démonstration

Pour créer des données de test :

```bash
cd backend
python fixtures_demo.py
```

> Ces données sont synthétiques, destinées à la démonstration uniquement. Aucune donnée personnelle réelle n'est utilisée.

---

## 📄 Documentation

Voir `docs/` pour la documentation technique détaillée et les diagrammes UML.

---

*Projet académique — ISEP Amadou Traoré de Diamniadio — 2025–2026*
