# SenAlert

Plateforme de prévention, de signalement et de suivi des urgences au Sénégal — projet de fin de formation, ISEP Amadou Traoré de Diamniadio, Analyse de Performance Digitale (promotion 6).

> SenAlert ne remplace pas les services officiels de secours. En cas de danger immédiat : **Police 17 · Sapeurs-pompiers 18**.

| Composant | Technologies | Utilisateurs |
|---|---|---|
| `backend/` | Python 3.13, Django 6, Django REST Framework, JWT, PostgreSQL / SQLite | API commune |
| `web/` | React 18, Vite, Tailwind CSS, Leaflet, Recharts | citoyens, agents, **superadministrateurs** |
| `mobile/` | Flutter 3.24 | **citoyens** et **agents de secours** |

## Démarrage rapide (macOS)

**Serveur** (terminal 1) — aucune activation d'environnement nécessaire :
```bash
cd ~/Documents/PFF/senalert/backend
python manage.py runserver          # → http://127.0.0.1:8000/app/
```
**Application mobile** (terminal 2) :
```bash
cd ~/Documents/PFF/senalert/mobile
flutter run                         # s'ouvre dans Chrome
```
**Simulateur mobile** (téléphone iPhone / Android affiché dans le navigateur) : `./run.sh simulateur` une fois, puis http://127.0.0.1:8000/app/simulateur (serveur lancé).

`manage.py` utilise automatiquement l'environnement Python du projet (`backend/env`), même si un autre Python (conda) est actif.

Autre méthode, tout-en-un :

```bash
cd ~/Documents/PFF/senalert
./run.sh backend                 # installe, migre, compile le web si besoin, lance http://127.0.0.1:8000/app/
```
Dans un autre terminal (une seule fois) :
```bash
cd backend && source env/bin/activate
python manage.py creer_comptes_test      # comptes de test des 3 rôles → backups/comptes_test.txt
python manage.py donnees_demo            # optionnel : incidents de démonstration « [DÉMO] »
```
Application mobile dans Chrome : `./run.sh mobile` · tests : `./run.sh tests`.

Détails : [docs/EXPLOITATION.md](docs/EXPLOITATION.md).

## Fonctionnalités

* **Vitrine publique** illustrée de photos réelles sous licence libre (crédits affichés), aux couleurs du Sénégal, avec les chiffres réels de la plateforme.
* **Alertes de zone**, **communauté « Autour de moi »** et **carte avancée** (satellite, carte de chaleur, zones à risque, recherche d'adresse) pour tous les rôles.

* **Citoyen** : SOS géolocalisé (5 s pour annuler, précision GPS, confirmation réelle), signalement en 4 étapes avec photos et brouillon, suivi des dossiers et historique, carte des incidents, services de proximité (OpenStreetMap), fiches de premiers secours hors ligne, assistant IA avec mode secours, notifications, profil et confidentialité, connexion Google.
* **Agent de secours** : tableau de bord, interventions de sa zone et de son service, prise en charge / acceptation / refus / démarrage / clôture avec compte rendu, itinéraire, notes, carte opérationnelle.
* **Superadministrateur** : centre de supervision (indicateurs définis, évolution, catégories, régions, carte, qualité des données), gestion des incidents et SOS (affectation, réaffectation, rejet, doublons), exports CSV/PDF, score de risque par région (méthode du mémoire), utilisateurs et agents, services et catégories, paramètres, journal d'audit.

## Documentation

| Document | Contenu |
|---|---|
| [docs/AUDIT_INITIAL.md](docs/AUDIT_INITIAL.md) | État du projet avant la refonte |
| [docs/TRACABILITE.md](docs/TRACABILITE.md) | Exigences du mémoire ↔ écrans, modèles, endpoints, permissions, tests |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture, modèle de données, cycle de vie, score de risque, design |
| [docs/API.md](docs/API.md) | Endpoints (+ Swagger sur `/api/docs/`) |
| [docs/SECURITE.md](docs/SECURITE.md) | Rapport de sécurité et confidentialité — **actions à faire** |
| [docs/CONFIGURATION_EXTERNE.md](docs/CONFIGURATION_EXTERNE.md) | Google, Firebase, Groq, PostgreSQL, SMTP |
| [docs/GUIDE_UTILISATEUR.md](docs/GUIDE_UTILISATEUR.md) | Guide par rôle |
| [docs/EXPLOITATION.md](docs/EXPLOITATION.md) | Démarrage, tests et résultats, sauvegarde/restauration |
| [docs/BILAN.md](docs/BILAN.md) | Conservé / ajouté / corrigé / fusionné / supprimé, limites, suites |
| [docs/DEMO_SOUTENANCE.md](docs/DEMO_SOUTENANCE.md) | Script de démonstration |
