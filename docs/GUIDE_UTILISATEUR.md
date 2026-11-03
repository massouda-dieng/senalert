# Guide utilisateur

SenAlert ne remplace pas les services officiels de secours. En cas de danger immédiat, appelez directement les numéros affichés dans l'application (Police 17, Sapeurs-pompiers 18).

## Connexion

L'écran de connexion propose trois onglets : **Citoyen**, **Agent**, **Superviseur**. L'onglet ne donne aucun droit : le serveur vérifie le rôle réel du compte et, s'il ne correspond pas, refuse avec un message indiquant le bon onglet (uniquement si le mot de passe est correct). Création de compte : libre pour un citoyen ; un agent est créé par le superviseur de sa structure ; un superviseur de structure est créé par le superviseur national (superadministrateur, lui-même créé par `python manage.py creer_superadmin`). Le superviseur de structure et le superviseur national se connectent tous deux par l'onglet **Superviseur**.

## Citoyen (web : `/app/citoyen`, mobile)

**Langue** — boutons **FR / WO** en haut de l'écran (web) ou *Profil → Langue* (mobile) : l'espace citoyen (menu, SOS, statuts, catégories, suivi, évaluation) passe en wolof. Les traductions sont dans `traductions/wolof.json` (à faire relire par un locuteur natif ; après modification : `./run.sh traductions`).

**Suivi des secours** — quand l'agent partage sa position, la fiche du dossier affiche « Les secours sont en route » avec la distance et la position de l'agent sur la carte (mise à jour toutes les 15 s, masquée au bout de 10 min sans nouvelle position, effacée à la clôture).

**Évaluation** — après la résolution, notez l'intervention de 1 à 5 étoiles (une seule fois), avec un commentaire facultatif transmis au service.

**Créer un compte** — « Créer un compte citoyen » (e-mail + mot de passe) ou « Continuer avec Google » si le service est configuré. Le téléphone est facultatif ; il n'est visible que de l'agent chargé de votre dossier.

**Déclencher un SOS**
1. Touchez le grand bouton rouge **SOS**.
2. Un compte à rebours de 5 secondes démarre : **Annuler** si c'est une erreur, **Envoyer maintenant** pour gagner du temps. Votre position est recherchée en parallèle et sa précision est affichée.
3. À la confirmation, la référence `SOS-AAAA-NNNNNN` et le statut actuel s'affichent. Le SOS part automatiquement vers la structure de secours la plus proche ayant un agent disponible, et cet agent le reçoit directement ; sans agent disponible, le superviseur de la structure l'affecte. Tant qu'un agent n'a pas accepté l'alerte, aucune intervention n'est garantie : en cas de danger vital, appelez aussi les secours.
4. Si l'envoi échoue, l'écran l'indique clairement (« L'alerte n'a PAS été transmise ») avec les boutons d'appel et « Réessayer » (un nouvel essai ne crée jamais de doublon).

**Signaler un incident** — 5 étapes : catégorie → lieu (« Utiliser ma position » ou toucher la carte, repère facultatif) → **structure** (les structures du service compétent les plus proches, avec leur distance ; puis un agent disponible de la structure choisie, présenté par son prénom et sa fonction, ou « Laisser le superviseur choisir ») → détails (description, photos ≤ 5) → vérification → envoi. Le dossier n'est visible que par l'agent choisi et par le superviseur de la structure. Le brouillon est conservé sur l'appareil en cas de coupure. Vous recevez une référence `INC-AAAA-NNNNNN`.

**Suivre mes dossiers** — « Mes dossiers » : recherche par référence, vues **Tous** et **En cours**. L'accueil rappelle uniquement les dossiers en cours. Le détail montre l'historique horodaté (Nouveau → Affecté → Pris en charge → En cours → Résolu), le service intervenant et, à la clôture, le compte rendu. Vous pouvez **compléter** un dossier ouvert (texte, photos) ou l'**annuler** tant qu'il n'est pas pris en charge.

**Autres fonctions** — Carte des incidents récents (positions arrondies) ; Services proches (hôpitaux, cliniques, pharmacies, police, pompiers d'après OpenStreetMap, avec distance, téléphone si connu et itinéraire) ; Premiers secours (12 fiches consultables hors connexion) ; Assistant (questions de prévention et d'utilisation ; historique gardé sur votre appareil) ; Notifications ; Profil (préférences, mot de passe, déconnexion de tous les appareils, suppression du compte).

**Autour de moi** — incidents récents près de chez vous (après localisation), triés par distance. « Je le vois aussi » confirme un incident et aide les secours à prioriser ; les messages sont publics : n'y mettez aucune donnée personnelle.

**Carte interactive** — bouton « Couches » : fond plan / clair / satellite, incidents, carte de chaleur, zones à risque, alertes de zone. Les services proches ont leur propre page. Barre de recherche pour trouver un lieu, bouton « Me localiser ».

**Alertes de zone** — les alertes officielles de votre région apparaissent en bandeau (jaune : vigilance, rouge : danger) et en notification.

## Agent de secours (web : `/app/agent`, mobile)

**Obtenir un compte** — sur l'écran de connexion, « Demander un compte agent » (web : `/app/demande-agent`) : identité, e-mail professionnel, service, matricule, structure (commissariat, caserne…), zones d'intervention et mot de passe choisi. La demande est examinée par un superadministrateur ; la connexion n'est possible qu'après validation (un e-mail informe de la décision). Un superadministrateur peut aussi créer le compte directement depuis **Utilisateurs**.

Le compte est créé par le **superviseur de votre structure** (caserne, commissariat, hôpital, agence SENELEC ou ONAS) avec un mot de passe initial, à changer à la première connexion (bandeau d’invitation). Vous ne voyez que les dossiers qui vous sont **transmis** : choisis par un citoyen, désignés automatiquement pour un SOS, ou affectés par votre superviseur. Le bouton **Disponible / Indisponible** du tableau de bord indique si les citoyens peuvent vous choisir.

**Tableau de bord** — missions reçues à accepter, interventions en cours, résolues sur 7 jours, délai moyen de prise en charge (web) et liste « Mes interventions en cours ». Actualisation automatique (web) ou tirer pour rafraîchir (mobile).

**Interventions** — onglets Incidents / SOS avec le nombre de dossiers ouverts, puis trois vues : **Ouverts**, **Mes interventions**, **Tous** (y compris les dossiers clos). Le bouton **Filtres** ouvre catégorie, région, gravité et dates.

**Traiter une intervention**
| Situation | Action |
|---|---|
| Dossier **affecté** à vous | **Accepter** ou **Décliner** (motif obligatoire, le superviseur est prévenu) |
| **Pris en charge** | **Démarrer l'intervention** (équipe en route / sur place) |
| **En cours** | **Clôturer** avec un compte rendu (visible du citoyen) et les difficultés éventuelles (internes) |

**Partager ma position** (dossier accepté ou en cours) : le déclarant voit votre progression ; arrêt à tout moment, position effacée à la clôture. Le détail donne aussi la position et sa précision, l'**itinéraire** (Google Maps), les photos, le contact du déclarant (une fois le dossier pris en charge) et l'historique. Vous pouvez ajouter des **notes** (internes ou visibles du citoyen) et ajuster la **gravité**. Si un autre agent a agi entre-temps, un message « dossier modifié entre-temps » s'affiche et la fiche se recharge.

## Superviseur de structure (web : `/app/supervision`)

Chaque structure (caserne, commissariat, hôpital, agence) a son superviseur. Il ne voit que les dossiers orientés vers sa structure et ses propres agents.

**Ma structure** — indicateurs, carte et file « À traiter » limités à la structure ; exports CSV et PDF de la structure.

**Incidents / Alertes SOS** — les dossiers de la structure ; un dossier sans agent choisi (ou décliné) attend une **affectation** à un agent de la structure.

**Mes agents** — **Ajouter un agent** (prénom, nom, e-mail, mot de passe initial, fonction, matricule) : il est automatiquement rattaché à la structure ; modifier sa fonction, sa disponibilité, l'activer ou le désactiver. Le superviseur ne change ni le rôle ni la structure de ses agents.

## Superadministrateur — superviseur national (web uniquement : `/app/supervision`)

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

**Journal d'audit** — opérations sensibles filtrables par type et par date.

L'**administration technique** Django (`/admin/`) reste disponible pour la maintenance (journal en lecture seule).
