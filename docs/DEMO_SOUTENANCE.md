# Guide de soutenance SenAlert

Ce document sert à préparer et dérouler la démonstration devant le jury : lancement, accès, comptes, fonctionnalités, scénario, réponses aux questions probables.

> **Slogan** : « Ensemble, protégeons des vies ».
> **À dire d'emblée** : SenAlert ne remplace pas les services officiels de secours. Toutes les données marquées « [DÉMO] » sont fictives : aucun incident réel n'est montré.

## 1. Lancer le projet (Windows)

**Une seule fois**, dans `senalert\backend` :

```bat
venv\Scripts\python -m pip install -r requirements.txt
```

**Terminal 1 : le serveur**

```bat
cd C:\Users\User\Downloads\PFF\PFF\senalert\backend
py manage.py runserver
```

**Terminal 2 : l'application mobile** (facultatif, le simulateur intégré suffit)

```bat
cd C:\Users\User\Downloads\PFF\PFF\senalert\mobile
flutter run -d chrome
```

## 2. Accès aux espaces

| Espace | Adresse |
|---|---|
| Page d'accueil publique | http://127.0.0.1:8000/app/ |
| Connexion (onglets Citoyen, Agent, Superviseur) | http://127.0.0.1:8000/app/connexion |
| Espace citoyen | http://127.0.0.1:8000/app/citoyen |
| Espace agent | http://127.0.0.1:8000/app/agent |
| Centre de supervision | http://127.0.0.1:8000/app/supervision |
| Démonstration guidée | http://127.0.0.1:8000/app/supervision/demo |
| Application mobile dans un cadre de téléphone | http://127.0.0.1:8000/app/simulateur |
| Documentation de l'API | http://127.0.0.1:8000/api/docs/ |

## 3. Comptes de démonstration

Les mots de passe ne sont **jamais** écrits dans Git. Ils sont dans `backups/comptes_test.txt`, fichier local ignoré par Git.

| Rôle | Identifiant | Nom affiché |
|---|---|---|
| Citoyen | `citoyen.test@senalert.local` | Awa Diop |
| Agent sapeur-pompier | `agent.pompiers@senalert.local` | Moussa Sarr |
| Agent police | `agent.police@senalert.local` | Fatou Ndiaye |
| Agent santé | `agent.sante@senalert.local` | Aminata Fall |
| Superadministrateur | `superadmin.test@senalert.local` | Superviseur Test |

Ces personnes sont fictives. Les agents de test couvrent les régions de Dakar et de Thiès.

Pour recréer les comptes (les mots de passe changent) :

```bat
cd backend
venv\Scripts\python manage.py creer_comptes_test
```

Ces commandes sont refusées quand `DEBUG=False` : elles ne peuvent pas créer de compte de test en production.

## 4. Données de démonstration

```bat
cd backend
venv\Scripts\python manage.py donnees_demo --supprimer
venv\Scripts\python manage.py donnees_demo --nombre 60
```

* Elles couvrent tout le cycle de vie : nouveau, affecté, pris en charge, en cours, résolu, rejeté, annulé.
* Chaque dossier commence par « [DÉMO] » et la supervision affiche un bandeau tant qu'il en existe.
* `--supprimer` ne retire que ces dossiers : les données réelles ne sont jamais touchées.

## 5. Fonctionnalités à mettre en avant

| Espace | Points forts |
|---|---|
| **Accueil** | Slogan, chiffres calculés depuis la base, fonctionnement, trois espaces, numéros d'urgence |
| **Citoyen** | Bouton SOS, signalement en 4 étapes, suivi par étapes, carte, alertes de proximité, services, notifications, assistant, français et wolof |
| **Agent** | Colonnes Nouvelles alertes / En attente / En cours, actions directes sur chaque mission, carte, historique, partage de position |
| **Superviseur** | Indicateurs avec comparaison à la période précédente, grande carte à couches, file « À traiter maintenant », graphiques, activité, administration, exports CSV et PDF |
| **Mobile** | Démarrage, connexion, SOS, signalement, carte, suivi, notifications, profil, mêmes couleurs que le web |

## 6. Scénario de démonstration (10 minutes)

**Préparation** : trois fenêtres de navigation privée, une par rôle, sur la page de connexion. Autorisez la géolocalisation pour `127.0.0.1`.

1. **Contexte (1 min).** Page d'accueil. Plusieurs numéros, position non transmise, pas de vue commune : SenAlert réunit le signalement, la coordination et l'analyse.
2. **Citoyen (3 min).** Connexion d'Awa.
   * Bouton **SOS** : compte à rebours annulable, précision GPS, puis « Envoyer maintenant ». Insister : la confirmation et la référence n'apparaissent qu'après la réponse du serveur.
   * **Signaler un incident** : Incendie, « Utiliser ma position », description, vérification, envoi. Le dossier part automatiquement vers les sapeurs-pompiers.
3. **Superviseur (3 min).** Connexion.
   * Centre de supervision : indicateurs, comparaison, carte (bouton Couches : chaleur, zones à risque), graphiques.
   * Le SOS et l'incendie sont dans « À traiter maintenant ». Ouvrir l'incendie, puis **Affecter** à Moussa Sarr.
   * Journal d'audit : l'affectation y figure. Rapport PDF.
4. **Agent (2 min).** Connexion de Moussa.
   * La mission est dans « En attente d'acceptation » : **Accepter**, **Démarrer**, partage de position, **Clôturer** avec un compte rendu.
5. **Retour citoyen (1 min).** Le dossier passe à « Résolu », avec historique, compte rendu, notifications et note de satisfaction.
6. **Sécurité (30 s).** Le citoyen ouvre `/app/supervision` : il est renvoyé vers son espace, et l'API répond 403.

**En cas d'imprévu** : la **Démonstration guidée** rejoue tout le parcours avec les comptes de test, depuis la supervision.

## 7. Points à vérifier la veille

* Lancer les tests : `py manage.py test` (backend), `npx vitest run` (web), `flutter test` (mobile).
* Vérifier la connexion Internet : les fonds de carte et l'assistant IA en dépendent. Sans Internet, l'assistant passe en mode secours local.
* Se connecter une fois avec chaque compte.

## 8. Questions probables du jury

| Question | Réponse |
|---|---|
| Comment le rôle est-il vérifié ? | À chaque requête : le jeton JWT identifie l'utilisateur, le rôle est lu en base, chaque vue et chaque action de la machine à états vérifient rôle, zone, service et affectation. Masquer un écran n'est qu'un confort. |
| Un citoyen peut-il devenir agent ? | Non : l'inscription force le rôle citoyen (testé). Les agents sont créés ou validés par le superviseur ; le superviseur uniquement en ligne de commande. |
| Sans réseau ou sans GPS ? | Le SOS part sans position, jamais avec une position inventée, et l'écran le dit. Si l'envoi échoue, l'écran affiche « non transmise » et les numéros d'appel ; un nouvel essai ne crée pas de doublon. |
| Le score de risque est-il prédictif ? | Non, c'est un indicateur descriptif : peu de signalements ne signifie pas qu'une zone est sûre. |
| Et si l'IA tombe en panne ? | L'assistant répond en mode secours à partir des fiches ; le SOS ne dépend jamais de l'IA. Il donne des conseils généraux et ne remplace ni un professionnel de santé ni les secours. |
| Les données personnelles ? | Positions arrondies sur la carte publique, contact visible du seul agent affecté et du superviseur, exports sans identité, métadonnées des photos supprimées, suppression du compte, journal d'audit. Les démarches auprès de la CDP restent à faire. |
| Les chiffres sont-ils réels ? | Ils sont calculés en direct depuis la base. Pendant la démonstration, la base contient des données fictives étiquetées, et l'écran l'indique. |
| Le temps réel ? | Actualisation périodique (5 à 30 s) sur le web, pas de WebSocket. Push mobile prêt côté serveur, à valider sur un téléphone réel. |

## 9. Limites à annoncer honnêtement

* Push Firebase : prêt côté serveur, non validé sur un téléphone réel (les notifications dans l'application fonctionnent).
* Applications Android et iOS : le code est prêt, seule la version web de Flutter a été compilée et testée.
* Connexion Google : nécessite des identifiants Google Cloud.
* E-mails : affichés dans la console tant qu'aucun serveur SMTP n'est configuré.
* Base de démonstration : SQLite ; PostgreSQL est configurable mais n'a pas été testé dans cette version.
* Aucune intégration officielle avec le SAMU, la police ou les pompiers.
* Fiches de premiers secours et traductions wolof : à faire valider par des professionnels et des locuteurs.
