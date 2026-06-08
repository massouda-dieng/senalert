# 🔔 SenAlert — Plateforme Nationale d'Alertes Citoyennes

> Plateforme numérique intelligente pour améliorer la gestion des urgences au Sénégal 🇸🇳

## 👥 Équipe

| Membre | Rôle | Responsabilité principale |
|--------|------|--------------------------|
| **Massouda** 👑 | Chef de projet | Backend Django + API REST + Coordination |
| **Ngoné** | Développeuse Backend/Mobile | App Flutter + Signalement GPS |
| **Asmaou** | Développeuse Frontend | Dashboard Web + Carte Leaflet |
| **Dieynaba** | Développeuse Full Stack | Module IA + Tests + Documentation |

## 📋 Répartition détaillée des tâches

### 👑 Massouda — Backend Django + Coordination
**Code à écrire :**
- Modèle User (authentification JWT)
- Modèle Incident (signalement)
- API REST `/api/auth/` (register, login)
- API REST `/api/incidents/` (CRUD)
- Configuration PostgreSQL
- Déploiement et coordination GitHub

### 📱 Ngoné — Application Flutter Mobile
**Code à écrire :**
- Écran Splash + Onboarding
- Écran Accueil + Navigation
- Écran Connexion / Inscription
- Écran Signalement avec GPS
- Écran Liste des incidents
- Connexion à l'API Django

### 🖥️ Asmaou — Dashboard Web
**Code à écrire :**
- Interface HTML/CSS du dashboard
- Carte Leaflet interactive
- Filtres par région et type
- Graphiques Chart.js
- Tableau des incidents
- Connexion à l'API Django

### 🧠 Dieynaba — IA + Tests + Documentation
**Code à écrire :**
- Module IA (analyse zones à risque)
- API `/api/analyse/zones-risque/`
- Tests unitaires Django
- Tests Flutter
- Rédaction du README technique
- Aide au mémoire

## 🏗️ Architecture
## 🛠️ Technologies

- **Backend** : Python Django + PostgreSQL + JWT
- **Mobile** : Flutter (iOS & Android)
- **Dashboard** : HTML/CSS/JS + Leaflet.js
- **IA** : Python Pandas (analyse des zones à risque)

## 🚀 Installation

### Backend (Massouda)
```bash
cd backend
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt
python3 manage.py migrate
python3 manage.py runserver
```

### Mobile (Ngoné)
```bash
cd mobile
flutter pub get
flutter run
```

### Dashboard (Asmaou)
```bash
cd dashboard
# Ouvrir index.html dans le navigateur
```

### IA + Tests (Dieynaba)
```bash
cd backend
python3 manage.py test
python3 analyse/analyzer.py
```

## ❗ Problématique

Comment améliorer la gestion des urgences et la communication entre citoyens et autorités au Sénégal grâce à une plateforme numérique intelligente ?

## 📱 Fonctionnalités

- 📍 Signalement instantané avec GPS automatique
- 🗺️ Carte interactive en temps réel
- 🧠 Analyse IA des zones à risque
- 🏛️ Dashboard national pour les autorités
- 🔔 Notifications push aux citoyens
- 🔒 Authentification sécurisée JWT

## 🌿 Branches GitHub

| Branche | Responsable | Description |
|---------|-------------|-------------|
| `main` | Massouda | Code stable validé |
| `backend` | Massouda | Développement backend |
| `mobile` | Ngoné | Développement Flutter |
| `dashboard` | Asmaou | Développement dashboard |
| `ia-tests` | Dieynaba | Module IA et tests |

## 📄 Licence
Projet académique — Tous droits réservés © 2025 SenAlert
