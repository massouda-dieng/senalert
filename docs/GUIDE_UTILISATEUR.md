# Guide utilisateur

SenAlert ne remplace pas les services officiels de secours. En cas de danger immédiat, appelez directement les numéros affichés dans l'application (Police 17, Sapeurs-pompiers 18).

## Connexion

L'écran de connexion est le même pour tous : **identifiant et mot de passe**, sans choix de profil. Le serveur reconnaît le rôle du compte (citoyen, agent, superviseur de structure, administrateur de la plateforme) et ouvre directement l'espace correspondant. Création de compte : libre pour un citoyen ; un agent est créé par le superviseur de sa structure ; un superviseur de structure est créé par l'administrateur de la plateforme (lui-même créé par `python manage.py creer_superadmin`), qui le rattache à sa structure.

## Citoyen (web : `/app/citoyen`, mobile)

**Langue** — boutons **FR / WO** en haut de l'écran (web) ou *Profil → Langue* (mobile) : l'espace citoyen (menu, SOS, statuts, catégories, suivi, évaluation) passe en wolof. Les traductions sont dans `traductions/wolof.json` (à faire relire par un locuteur natif ; après modification : `./run.sh traductions`).

**Suivi des secours** — quand l'agent partage sa position, la fiche du dossier affiche « Les secours sont en route » avec la distance et la position de l'agent sur la carte (mise à jour toutes les 15 s, masquée au bout de 10 min sans nouvelle position, effacée à la clôture).

**Évaluation** — après la résolution, notez l'intervention de 1 à 5 étoiles (une seule fois), avec un commentaire facultatif transmis au service.

**Créer un compte** — « Créer un compte citoyen » (e-mail + mot de passe) ou « Continuer avec Google » si le service est configuré. Le téléphone est facultatif ; il n'est visible que de l'agent chargé de votre dossier.

**Déclencher un SOS**
1. Touchez le bouton rouge **SOS**, toujours visible en bas à droite de chaque écran citoyen (web et mobile).
2. Un compte à rebours de 5 secondes démarre : **Annuler** si c'est une erreur, **Envoyer maintenant** pour gagner du temps. Votre position est recherchée en parallèle et sa précision est affichée. Facultatif : touchez le **type d'urgence** (Urgence médicale, Incendie, Accident, Agression ou danger) pour envoyer aussitôt vers le bon service.
3. La confirmation ne s'affiche qu'une fois l'alerte enregistrée par le serveur : référence `SOS-AAAA-NNNNNN`, type d'urgence, date et heure, position, **structure prévenue** et statut. Le SOS part vers la structure du service concerné la plus proche (tous les services de secours si le type n'est pas précisé) ; son **superviseur** est prévenu immédiatement et l'affecte à un de ses agents. Sur l'écran de confirmation, vous pouvez **choisir une autre structure** tant que l'alerte n'est pas affectée et **ajouter des photos**. Le SOS se distingue du signalement par sa rapidité : un seul geste, sans formulaire. Chaque SOS est conservé : « Historique de mes SOS » et sa page de détail. Tant qu'un agent n'a pas accepté l'alerte, aucune intervention n'est garantie : en cas de danger vital, appelez aussi les secours.
4. Si l'envoi échoue, l'écran l'indique clairement (« L'alerte n'a PAS été transmise ») avec les boutons d'appel et « Réessayer » (un nouvel essai ne crée jamais de doublon).

**Signaler un incident** — 5 étapes : **type** → **détails** (description, photos facultatives) → **lieu** (votre position actuelle est prise automatiquement ; si l'incident a lieu ailleurs, recherchez l'adresse ou déplacez la carte) → **structure concernée** → **envoi**. À l'étape « structure », SenAlert propose les structures compétentes pour le type d'incident (incendie → sapeurs-pompiers, etc.), les plus proches d'abord, et **présélectionne** la plus proche dotée d'un superviseur ; vous pouvez en choisir une autre. Le signalement n'apparaît que chez le **superviseur de cette structure**, qui l'affecte à un de ses agents : le dossier reste « Nouveau » tant que cette affectation n'est pas faite. La date, l'heure et la région sont enregistrées automatiquement. Vous recevez une référence `INC-AAAA-NNNNNN`.

**Suivre mes dossiers** — « Mes dossiers » : recherche par référence, vues **Tous** et **En cours**. Le détail montre l'historique horodaté (Nouveau → Affecté → Pris en charge → En cours → Résolu), la structure qui traite le dossier et, à la clôture, le compte rendu. Le citoyen **n'agit pas** sur le dossier (pas d'affectation, pas de modification) : il est notifié à chaque étape et **donne son avis** une fois le dossier résolu.

**Autres fonctions** — Carte des incidents récents (positions arrondies) ; Services proches (hôpitaux, cliniques, pharmacies, police, pompiers d'après OpenStreetMap, avec distance, téléphone si connu et itinéraire) ; Premiers secours (12 fiches consultables hors connexion) ; Assistant (questions de prévention et d'utilisation ; historique gardé sur votre appareil) ; Notifications ; Profil (préférences, mot de passe, déconnexion de tous les appareils, suppression du compte).

**Autour de moi** — incidents récents près de chez vous (après localisation), triés par distance. « Je le vois aussi » confirme un incident et aide les secours à prioriser ; les messages sont publics : n'y mettez aucune donnée personnelle.

**Carte** — un seul choix en haut : **Incidents récents** ou un **service** (santé, police, pompiers, SENELEC, ONAS). Pour un service, les structures les plus proches s'affichent sur la carte et dans une liste triée par distance (appel et itinéraire). Bouton de recherche d'un lieu et bouton « Utiliser ma position actuelle » ; sans localisation, la liste se calcule autour du centre de la carte. (Mobile ; la carte web garde ses couches.)

**Alertes de zone** — les alertes officielles de votre région apparaissent en bandeau (jaune : vigilance, rouge : danger) et en notification.

## Agent de secours (web : `/app/agent`, mobile)

Le compte est créé par le **superviseur de votre structure** (caserne, commissariat, hôpital, agence SENELEC ou ONAS) avec un mot de passe initial, à changer à la première connexion. Vous ne voyez que les dossiers que votre superviseur vous a **affectés**. À chaque affectation, vous recevez une **notification** et une alerte apparaît en direct (web et mobile, sans recharger la page). Le bouton **Disponible / Indisponible** indique à votre superviseur si vous pouvez recevoir un dossier.

**Tableau de bord** — missions reçues à accepter, interventions en cours, résolues sur 7 jours, délai moyen de prise en charge (web) et liste « Mes interventions en cours ». Actualisation automatique (web) ou tirer pour rafraîchir (mobile).

**Interventions** — onglets Incidents / SOS avec le nombre de dossiers ouverts, puis trois vues : **Ouverts**, **Mes interventions**, **Tous** (y compris les dossiers clos). Le bouton **Filtres** ouvre catégorie, région, gravité et dates.

**Traiter une intervention**
| Situation | Action |
|---|---|
| Dossier **affecté** à vous | **Prendre en charge** ou **Décliner** (motif obligatoire, le superviseur est prévenu) |
| **Pris en charge** | **Démarrer l'intervention** (équipe en route / sur place) |
| **En cours** | **Clôturer** avec un compte rendu (visible du citoyen) et les difficultés éventuelles (internes) |

**Partager ma position** (dossier accepté ou en cours) : le déclarant voit votre progression ; arrêt à tout moment, position effacée à la clôture. Le détail donne aussi la position et sa précision, l'**itinéraire** (Google Maps), les photos, le contact du déclarant (une fois le dossier pris en charge) et l'historique. Vous pouvez ajouter des **commentaires** (internes ou visibles du citoyen) et ajuster la **gravité**. L'espace agent ne contient pas les fiches de premiers secours (réservées aux citoyens). Si un autre agent a agi entre-temps, un message « dossier modifié entre-temps » s'affiche et la fiche se recharge.

## Superviseur de structure (web : `/app/supervision`)

Chaque structure (caserne, commissariat, hôpital, agence) a son superviseur. Il ne voit que les dossiers orientés vers sa structure et ses propres agents.

**Ma structure** — indicateurs, carte et file « À traiter » limités à la structure ; exports CSV et PDF de la structure.

**Incidents / Alertes SOS** — uniquement les dossiers adressés à votre structure. Un nouveau dossier (ou un dossier décliné) attend une **affectation** : la liste proposée ne contient que les agents de votre structure, les disponibles d'abord. L'agent choisi est notifié, et le citoyen est notifié de chaque changement de statut.

**Mes agents** — **Ajouter un agent** (prénom, nom, e-mail, mot de passe initial, fonction, matricule) : il est automatiquement rattaché à la structure ; modifier sa fonction, sa disponibilité, l'activer ou le désactiver. Le superviseur ne change ni le rôle ni la structure de ses agents.

**Centre de supervision** — onglet **Aujourd'hui** : 4 chiffres (SOS, en attente d'un agent, en cours, terminées), la file « À traiter maintenant », la carte et l'activité récente ; onglet **Statistiques** : filtres de période, courbes, répartitions et qualité des données.

## Administrateur de la plateforme (web uniquement : `/app/supervision`)

**Supervision** — indicateurs calculés en direct (filtres période, région, catégorie, granularité), évolution, répartition par catégorie et par région, qualité des données (position, précision GPS, description, photos, doublons). Survolez un indicateur pour sa définition ; la section « Définition des indicateurs » les détaille.

**Alertes de zone** — « Nouvelle alerte » : titre, message, consignes, niveau, régions (aucune = tout le pays), fin éventuelle. Les citoyens et agents concernés sont notifiés ; « Terminer » met fin à l'alerte.

**Communauté** — confirmations et messages des citoyens sur les incidents ; modération des messages (masquer / rétablir), journalisée.

**Incidents / Alertes SOS** — tableau paginé, filtres combinables (référence, statut, catégorie, région, gravité, dates, doublons potentiels), panneau de détail. Actions : **Affecter / Réaffecter** (agents actifs couvrant la région, filtrables par service), **Rejeter** (signalement non fondé), **Annuler**, gravité, notes. Exports **CSV** (tableur, sans données personnelles) et **Rapport PDF**.

**Zones de risque** — score par région selon la méthode du mémoire, classement, comparaison avec la période précédente, « Enregistrer un instantané » (historique), lien « Voir sur la carte » qui ouvre la carte interactive avec la couche des zones à risque. La mention « données insuffisantes » signale un niveau peu fiable.

**Satisfaction** — sur la page Supervision : note moyenne des citoyens, taux de réponse et moyenne par service.

**Structures** — les casernes, commissariats et hôpitaux du Sénégal (OpenStreetMap), plus une agence SENELEC et une agence ONAS par région placées au chef-lieu (« à confirmer ») ; recherche par service, région et nom ; corriger la position, le téléphone, désactiver ou ajouter une structure.

**Utilisateurs** — recherche et filtres ; **Créer un superviseur** de structure et **Ajouter un agent** (dans une structure choisie) ; modifier rôle (citoyen, agent, superviseur de structure), structure, disponibilité, activer/désactiver (ferme les sessions). Le rôle superadministrateur ne se donne qu'en ligne de commande : `python manage.py creer_superadmin email@exemple.sn`.

**Services & catégories** — ajout, modification, désactivation (pas de suppression, pour préserver l'historique).

**Paramètres** — numéros d'urgence (seuls les numéros « Vérifié » sont affichés aux citoyens), délais de prise en charge (retards), détection des doublons, règles du cycle de vie, conservation des données, fonctionnalités (assistant, Google, carte publique). Toute modification est journalisée.

**Journal d'audit** — pour chaque opération : date et heure (Dakar), utilisateur et son rôle, action en clair, élément concerné. Rubriques : connexions, comptes et permissions, signalements et SOS (créations, envois), traitement des dossiers (affectations, prises en charge, changements de statut, clôtures), structures et configuration. Consultable par le superadministrateur seulement ; aucune entrée ne peut être modifiée ni supprimée.

L'**administration technique** Django (`/admin/`) reste disponible pour la maintenance (journal en lecture seule).
