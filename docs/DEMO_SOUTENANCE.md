# Script de démonstration — soutenance SenAlert

Durée : 10 minutes. Matériel : MacBook (navigateur), éventuellement un téléphone ou l'application Flutter dans Chrome.

## La veille

```bash
cd ~/Documents/PFF/senalert
./run.sh tests                                   # backend 119, web 11, Flutter 12 — tout doit être vert
cd backend && source env/bin/activate
python manage.py creer_comptes_test              # mots de passe dans backups/comptes_test.txt
python manage.py donnees_demo --supprimer && python manage.py donnees_demo --nombre 40
```
Préparer trois fenêtres de navigation privée (citoyen, agent, superadmin) sur http://127.0.0.1:8000/app/connexion.

Le jour J : `./run.sh backend` (et `./run.sh mobile` si l'application Flutter est montrée).

## Déroulé

1. **Contexte (1 min)** — numéros séparés (17, 18, SAMU), pas de position transmise, pas de carte commune ; SenAlert réunit signalement, coordination et analyse. Préciser : SenAlert ne remplace pas les secours officiels.
2. **Citoyen (3 min)** — se connecter (`citoyen.test@…`).
   * Signaler un **incendie** : choisir la catégorie, placer le point sur la carte, décrire, joindre une photo, vérifier, envoyer → référence `INC-…` (insister : le service destinataire est déterminé automatiquement).
   * Montrer le **SOS** : compte à rebours annulable, précision GPS ; envoyer (ou annuler) et montrer la référence réelle et le statut.
   * Fiches de premiers secours (hors connexion), services proches (OpenStreetMap), assistant (indiquer s'il répond par l'IA ou en mode secours).
3. **Superadmin (3 min)** — `superadmin.test@…`.
   * Supervision : indicateurs définis, bandeau « données de démonstration », évolution, carte.
   * Incidents : retrouver la référence, ouvrir le détail, **Affecter** à l'agent pompier (seuls les agents couvrant la zone sont proposés) ; montrer un doublon potentiel s'il apparaît.
   * Carte & risques : formule du mémoire, classement, comparaison de période, avertissement « indicateur descriptif ».
   * Export CSV / PDF ; journal d'audit (l'affectation y figure).
4. **Agent (2 min)** — `agent.pompiers@…` : notification d'affectation, **Accepter**, **Démarrer**, itinéraire, **Clôturer** avec compte rendu.
5. **Retour citoyen (1 min)** — le dossier est « Résolu », historique horodaté, compte rendu, notifications.
6. **Sécurité (30 s)** — un citoyen qui ouvre `/app/supervision` est renvoyé vers son espace ; l'API répond 403 (démonstration possible sur `/api/docs/`).

## Questions probables du jury

| Question | Réponse |
|---|---|
| Comment le rôle est-il vérifié ? | À chaque requête : le jeton JWT identifie l'utilisateur, le rôle est lu en base, chaque vue et chaque action de la machine à états vérifient rôle, zone, service et affectation. Les écrans cachés ne sont qu'un confort. |
| Un citoyen peut-il devenir agent ? | Non : l'inscription force le rôle citoyen (testé). Les agents sont créés par le superadmin ; le superadmin uniquement en ligne de commande. |
| Que se passe-t-il sans réseau ou si le GPS échoue ? | Le SOS part sans position (jamais de position inventée) et l'écran le dit ; si l'envoi échoue, l'écran affiche « non transmise » et les numéros d'appel ; un nouvel essai ne crée pas de doublon (clé d'idempotence). |
| Le score de risque est-il prédictif ? | Non, c'est l'indicateur descriptif du mémoire (poids × facteur 7 jours), reproductible et testé à chaque seuil ; peu de signalements ne signifie pas zone sûre. |
| Et si l'IA tombe en panne ? | L'assistant répond en mode secours à partir des fiches ; le SOS et les fiches ne dépendent jamais de l'IA (testé). |
| Les données personnelles ? | Minimisation (positions arrondies sur la carte publique, contact visible du seul agent affecté, exports anonymes, EXIF supprimé), suppression de compte, journal d'audit ; démarches CDP restant à faire. |
