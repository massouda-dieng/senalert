# 📘 README Technique — Module IA SenAlert
**Auteure : Dieynaba Demé | Branche : `ia-tests`**

---

## 🧠 1. Rôle de ma partie dans le projet

Mon rôle dans SenAlert est d'analyser les incidents signalés par les citoyens
pour identifier automatiquement les zones géographiques les plus à risque au Sénégal.

### Les fichiers que j'ai créés :
- `backend/analyse/analyzer.py` → l'algorithme IA
- `backend/analyse/views.py` → l'endpoint API
- `backend/analyse/urls.py` → le routage URL
- `backend/analyse/tests.py` → les tests unitaires Django
- `backend/analyse/test_flutter.dart` → les tests Flutter

---

## 🧠 2. L'algorithme IA

### Comment ça marche ?

1. On récupère tous les incidents de la base de données
2. On les groupe par région
3. On calcule un score pour chaque région
4. On trie les régions du plus risqué au moins risqué

### Les poids de gravité

| Type d'incident | Poids |
|----------------|-------|
| Incendie | 5 |
| Inondation | 4 |
| Insécurité | 4 |
| Accident | 3 |
| Coupure électricité | 2 |
| Autre | 1 |

### Le facteur récence

Un incident des **7 derniers jours** est multiplié par **2**.
Un incident plus ancien garde son poids normal.

### Les niveaux de risque

| Niveau | Score |
|--------|-------|
| 🔴 Critique | ≥ 15 |
| 🟠 Élevé | ≥ 8 |
| 🟡 Moyen | ≥ 3 |
| 🟢 Faible | < 3 |

---

## 🔌 3. Mon API

### Endpoint
GET /api/analyse/zones-risque/

### Authentification
JWT requis → Authorization: Bearer token

### Paramètres optionnels

| Paramètre | Exemple | Description |
|-----------|---------|-------------|
| `niveau` | `?niveau=critique` | Filtrer par niveau de risque |
| `region` | `?region=dakar` | Filtrer par région |

### Exemple de réponse

{
  "status": "success",
  "total_zones_analysees": 2,
  "zones": [
    {
      "region": "dakar",
      "score": 22.0,
      "niveau": "critique",
      "total_incidents": 8,
      "types_predominants": ["inondation", "incendie"],
      "incidents_recents": 5
    },
    {
      "region": "thies",
      "score": 9.0,
      "niveau": "eleve",
      "total_incidents": 3,
      "types_predominants": ["accident"],
      "incidents_recents": 2
    }
  ]
}

---

## ✅ 4. Mes tests

### Lancer les tests Django

cd backend
python manage.py test analyse --verbosity=2

### Résultat

Ran 10 tests in 0.019s
OK

### Ce que les tests vérifient

| Test | Ce qui est vérifié |
|------|--------------------|
| `test_incident_recent` | Un incident récent a un score x2 |
| `test_incident_ancien` | Un incident ancien garde son poids normal |
| `test_liste_vide` | Une liste vide retourne 0 |
| `test_critique` | Score ≥ 15 → niveau critique |
| `test_eleve` | Score ≥ 8 → niveau élevé |
| `test_moyen` | Score ≥ 3 → niveau moyen |
| `test_faible` | Score < 3 → niveau faible |
| `test_une_region` | Un incident à Dakar → 1 zone retournée |
| `test_tri_par_score` | Les zones sont triées du plus risqué au moins risqué |
| `test_liste_vide` | Sans incident → liste vide retournée |

---

## 🚀 5. Comment installer et tester ma partie

### Étape 1 — Cloner le projet

git clone https://github.com/massouda-dieng/senalert.git
cd senalert
git checkout ia-tests

### Étape 2 — Installer les dépendances

cd backend
pip install -r requirements.txt

### Étape 3 — Lancer le serveur

python manage.py migrate
python manage.py runserver

### Étape 4 — Tester l'API

GET http://127.0.0.1:8000/api/analyse/zones-risque/

### Étape 5 — Lancer les tests

python manage.py test analyse --verbosity=2

---

*SenAlert © 2025 — Projet académique ISEP Diamniadio*
*Auteure : Dieynaba Demé*