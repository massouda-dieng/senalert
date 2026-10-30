# Guide équipe (v3)

La refonte v3 remplace l'ancienne organisation. Points clés pour travailler sur le dépôt :

* **Lancer** : `./run.sh backend`, `./run.sh web`, `./run.sh mobile [appareil]`, `./run.sh tests` (voir `docs/EXPLOITATION.md`).
* **Ne jamais** passer de clé (Groq ou autre) à Flutter ou au web : l'IA passe par `POST /api/analyse/assistant/`. L'ancienne clé Groq a fuité dans l'historique Git et doit être révoquée (`docs/SECURITE.md`).
* **Comptes de test** : `python manage.py creer_comptes_test` (mots de passe aléatoires dans `backups/comptes_test.txt`, jamais dans la documentation).
* **Données de démonstration** : `python manage.py donnees_demo` / `--supprimer` (préfixe « [DÉMO] »). L'ancien `fixtures_demo.py` supprimait toutes les données : il est archivé.
* **Rôles** : `citoyen`, `agent`, `superadmin` (anciens `autorite` et `admin` convertis par migration).
* **API** : nouveaux chemins en français (`/api/auth/connexion/`, `/api/alertes/sos/`…) — référence complète dans `docs/API.md` et sur `/api/docs/`.
* **Avant de pousser** : `./run.sh tests` doit être entièrement vert ; ajouter un test pour toute nouvelle règle métier.
