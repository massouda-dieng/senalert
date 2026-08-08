# 🔔 SenAlert — Plateforme Nationale de Signalement et de Gestion des Urgences au Sénégal

> **Projet de Soutenance & Commandement National des Urgences**  
> SenAlert est une solution technologique complète (Web Dashboard, Backend REST API et Application Mobile Flutter) permettant le signalement en temps réel, la géolocalisation, l'analyse prédictive par IA des zones de risque, et le déploiement coordonné des services de secours au Sénégal (**Sapeurs-Pompiers, Police/Gendarmerie, SAMU, SENELEC, ONAS**).

---

## 🌟 Architecture Globale de la Solution

```
                            +-----------------------------------+
                            |    Application Mobile (Flutter)   |
                            |   Signalement Citoyen & Cartes    |
                            +-----------------+-----------------+
                                              |
                                              v  (REST API / JWT)
+----------------------------------+  +-------+-------------------------+
|   Dashboard Commandement Web     |  |     Backend Django REST API     |
|   (Leaflet, Chart.js, Dispatch)  |<===> (Incidents, Auth, Risk Engine)|
+----------------------------------+  +---------------------------------+
```

---

## 🚀 Composants de la Plateforme

### 1. 📊 **Dashboard Web de Commandement (`dashboard/index.html`)**
- **Cartographie Interactive Leaflet** : Géolocalisation dynamique avec marqueurs d'urgence et popups régionaux.
- **Tableau de Bord KPI** : Suivi en direct du total d'urgences, urgences en attente, interventions en cours et incidents résolus.
- **Gestion des Incidents & Alertes** : Filtres avancés (14 régions du Sénégal, types d'incidents, statuts), recherche textuelle, modification du statut à la volée.
- **Centre de Mobilisation & Dispatch** : Modale d'affectation des unités de secours (**SP-18, POL-17, SAMU-1515, SENELEC, ONAS**) avec calcul d'ETA en minutes.
- **Moteur d'Analyse des Risques IA** : Détection des zones critiques par algorithme de pondération temporel.
- **Rapports & Expatriation** : Exportation instantanée de rapports au format **CSV** et impression de synthèses **PDF**.
- **Alertes Sonores & Météorologiques** : Alarme synthétisée Web Audio API et bandeau d'alerte ANACIM.

### 2. 🐍 **Backend Django REST API (`backend/`)**
- **Authentification Sécurisée JWT** : Inscription & Connexion avec jetons de rafraîchissement (`rest_framework_simplejwt`).
- **Endpoints REST (`/api/incidents/`)** : Gestion CRUD complète des alertes nationales.
- **Module d'Analyse IA (`/api/analyse/zones-risque/`)** : Algorithme d'évaluation des menaces régionales (`POIDS_GRAVITE` * facteur de récence).
- **Administration Django (`/admin/`)** : Console de gestion des utilisateurs, rôles (Citoyen, Administrateur, Autorité) et autorités régionales.

### 3. 📱 **Application Mobile (`mobile/`)**
- Développée avec **Flutter & Dart**.
- Écrans d'inscription/connexion, formulaire de signalement géolocalisé avec photo, carte des alertes et suivi d'interventions.

---

## 🎓 Guide de Démonstration pour la Soutenance (Présentation au Jury)

### 1️⃣ **Présentation Générale (2 min)**
> *"Monsieur le Président, Membres du Jury, nous vous présentons **SenAlert**, la plateforme nationale de réponse aux urgences du Sénégal. Face aux défis majeurs tels que les inondations, les incendies de marché et les accidents de la route, SenAlert interconnecte les citoyens, le centre de commandement et les unités de secours en temps réel."*

### 2️⃣ **Démonstration du Dashboard de Commandement (5 min)**
1. **Ouverture du Dashboard** : `http://127.0.0.1:8000/dashboard/` (Connexion administrateur `Papa` / `Papa`).
2. **Consultation de la Carte du Sénégal** : Montrer la répartition géolocalisée des 20 incidents de démonstration.
3. **Signalement d'un Incident** : Cliquer sur **`+ Signaler Incident`** (ex: *Incendie au Marché de Thiès*), vérifier la création instantanée.
4. **Mobilisation des Secours** : Dans l'onglet **`🛠️ Interventions`**, cliquer sur **`📢 Mobiliser l'équipe`** sur Sapeurs-Pompiers Dakar, attribuer l'incident avec un ETA de 10 min.
5. **Démonstration du Moteur IA** : Dans l'onglet **`📈 Statistiques & IA`**, montrer la détection automatique de la zone **Dakar (Score 36 pts - CRITIQUE)** avec les consignes de déploiement préconisées.
6. **Exportation des Rapports** : Cliquer sur **`📥 Exporter Rapport CSV`** pour démontrer l'extraction de données officielles.

### 3️⃣ **Démonstration de l'Administration & API (3 min)**
1. Accéder à l'Administration Django via le bouton **`🔑 Admin Django ↗`** (`http://127.0.0.1:8000/admin/`).
2. Montrer la gestion des utilisateurs, la table des autorités et la structure REST API JSON.

---

## ⚙️ Installation & Démarrage Rapide

### Prérequis
- Python 3.10+ & Virtualenv
- Flutter SDK (optionnel pour le mobile)

### Démarrer le Backend Django
```bash
cd backend
venv\Scripts\activate
python manage.py migrate
python fixtures_demo.py
python manage.py runserver 8000
```

### Ouvrir le Dashboard Web
- Directement dans le navigateur : `dashboard/index.html`
- Via le serveur Django : `http://127.0.0.1:8000/dashboard/`

---

## 👤 Auteur & Crédits
- **Projet SenAlert** — Sénégal Urgences & Commandement
- **Dépôt GitHub** : [https://github.com/massouda-dieng/senalert](https://github.com/massouda-dieng/senalert)
