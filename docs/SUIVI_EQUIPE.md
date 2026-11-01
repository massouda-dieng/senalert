# Guide équipe (v3)

La refonte v3 remplace l'ancienne organisation. Points clés pour travailler sur le dépôt :

* **Lancer** : `./run.sh backend`, `./run.sh web`, `./run.sh mobile [appareil]`, `./run.sh tests` (voir `docs/EXPLOITATION.md`).
* **Ne jamais** passer de clé (Groq ou autre) à Flutter ou au web : l'IA passe par `POST /api/analyse/assistant/`. L'ancienne clé Groq a fuité dans l'historique Git et doit être révoquée (`docs/SECURITE.md`).
* **Comptes de test** : `python manage.py creer_comptes_test` (mots de passe aléatoires dans `backups/comptes_test.txt`, jamais dans la documentation).
* **Données de démonstration** : `python manage.py donnees_demo` / `--supprimer` (préfixe « [DÉMO] »). L'ancien `fixtures_demo.py` supprimait toutes les données : il est archivé.
* **Rôles** : `citoyen`, `agent`, `superadmin` (anciens `autorite` et `admin` convertis par migration).
* **API** : nouveaux chemins en français (`/api/auth/connexion/`, `/api/alertes/sos/`…) — référence complète dans `docs/API.md` et sur `/api/docs/`.
* **Avant de pousser** : `./run.sh tests` doit être entièrement vert ; ajouter un test pour toute nouvelle règle métier.

## Démarrer (nouvelle organisation)

La branche de travail commune est `test`. On ne pousse jamais directement sur `main`.

```bash
git clone -b test https://github.com/massouda-dieng/senalert.git
cd senalert
git fetch origin
git switch <ta-branche>        # voir le tableau ci-dessous
```

Ensuite, `./run.sh backend` prépare et lance le serveur, puis `python manage.py creer_comptes_test` crée les comptes de test (voir `docs/EXPLOITATION.md`). Le fichier `.env`, la base de données et `firebase-adminsdk.json` ne sont pas sur GitHub : chacun garde les siens en local.

## Répartition du travail

| Personne | Branche | Périmètre |
|---|---|---|
| Massouda | `feature/massouda-coordination-dashboard` | Coordination, espace superviseur (`web/src/pages/admin/`), accueil public, `docs/`, `design/` |
| Ndeye | `feature/ndeye-backend-api` | Serveur et API (`backend/`), sécurité, tests backend |
| Dieynaba | `feature/dieynaba-mobile-citoyen` | Parcours citoyen : `mobile/lib/features/citoyen/`, `web/src/pages/citoyen/` |
| Asmaou | `feature/asmaou-mobile-agent-tests` | Parcours agent : `mobile/lib/features/agent/`, `web/src/pages/agent/`, tests mobile (`mobile/test/`) |

Pour un dossier partagé (`mobile/lib/ui/`, `mobile/lib/core/`, `web/src/components/`), prévenir l'équipe avant de le modifier.

## Règles de travail

1. Avant de commencer : `git fetch origin && git merge origin/test`.
2. Après ton travail : `./run.sh tests`, puis `git push origin <ta-branche>`.
3. Ouvrir une pull request vers `test`, jamais vers `main`.
4. Le code mobile doit compiler avec Flutter 3.24 : utiliser `withOpacity` et non `withValues`, et ne pas utiliser `CardThemeData`.
