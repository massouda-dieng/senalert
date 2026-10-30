# Guide utilisateur

SenAlert ne remplace pas les services officiels de secours. En cas de danger immédiat, appelez directement les numéros affichés dans l'application (Police 17, Sapeurs-pompiers 18).

## Connexion

L'écran de connexion propose trois onglets : **Citoyen**, **Agent**, **Superviseur**. L'onglet ne donne aucun droit : le serveur vérifie le rôle réel du compte et, s'il ne correspond pas, refuse avec un message indiquant le bon onglet (uniquement si le mot de passe est correct). Création de compte : libre pour un citoyen, sur demande validée pour un agent, jamais depuis l'application pour un superviseur (`python manage.py creer_superadmin`).

## Citoyen (web : `/app/citoyen`, mobile)

**Créer un compte** — « Créer un compte citoyen » (e-mail + mot de passe) ou « Continuer avec Google » si le service est configuré. Le téléphone est facultatif ; il n'est visible que de l'agent chargé de votre dossier.

**Déclencher un SOS**
1. Touchez le grand bouton rouge **SOS**.
2. Un compte à rebours de 5 secondes démarre : **Annuler** si c'est une erreur, **Envoyer maintenant** pour gagner du temps. Votre position est recherchée en parallèle et sa précision est affichée.
3. À la confirmation, la référence `SOS-AAAA-NNNNNN` et le statut actuel s'affichent. Tant qu'un agent n'a pas pris en charge l'alerte, aucune intervention n'est garantie : en cas de danger vital, appelez aussi les secours.
4. Si l'envoi échoue, l'écran l'indique clairement (« L'alerte n'a PAS été transmise ») avec les boutons d'appel et « Réessayer » (un nouvel essai ne crée jamais de doublon).

**Signaler un incident** — 4 étapes : catégorie → lieu (« Utiliser ma position » ou toucher la carte, repère facultatif) → détails (description, photos ≤ 5) → vérification → envoi. Le brouillon est conservé sur l'appareil en cas de coupure. Vous recevez une référence `INC-AAAA-NNNNNN`.

**Suivre mes dossiers** — « Mes dossiers » : recherche par référence, filtre par statut. Le détail montre l'historique horodaté (Nouveau → Affecté → Pris en charge → En cours → Résolu), le service intervenant et, à la clôture, le compte rendu. Vous pouvez **compléter** un dossier ouvert (texte, photos) ou l'**annuler** tant qu'il n'est pas pris en charge.

**Autres fonctions** — Carte des incidents récents (positions arrondies) ; Services proches (hôpitaux, cliniques, pharmacies, police, pompiers d'après OpenStreetMap, avec distance, téléphone si connu et itinéraire) ; Premiers secours (12 fiches consultables hors connexion) ; Assistant (questions de prévention et d'utilisation ; historique gardé sur votre appareil) ; Notifications ; Profil (préférences, mot de passe, déconnexion de tous les appareils, suppression du compte).

**Autour de moi** — incidents récents près de chez vous (après localisation), triés par distance. « Je le vois aussi » confirme un incident et aide les secours à prioriser ; les messages sont publics : n'y mettez aucune donnée personnelle.

**Carte interactive** — bouton « Couches » : fond plan / clair / satellite, incidents, carte de chaleur, zones à risque, alertes de zone, services proches (« Charger les services autour du centre »). Barre de recherche pour trouver un lieu, bouton « Me localiser ».

**Alertes de zone** — les alertes officielles de votre région apparaissent en bandeau (jaune : vigilance, rouge : danger) et en notification.

## Agent de secours (web : `/app/agent`, mobile)

**Obtenir un compte** — sur l'écran de connexion, « Demander un compte agent » (web : `/app/demande-agent`) : identité, e-mail professionnel, service, matricule, structure (commissariat, caserne…), zones d'intervention et mot de passe choisi. La demande est examinée par un superadministrateur ; la connexion n'est possible qu'après validation (un e-mail informe de la décision). Un superadministrateur peut aussi créer le compte directement depuis **Utilisateurs**.

Le compte est rattaché à un **service** (Police, Pompiers, Santé, SENELEC, ONAS…) et des **zones** (régions). S’il a été créé par le superadministrateur avec un mot de passe initial, changez-le à la première connexion (bandeau d’invitation).

**Tableau de bord** — nouvelles alertes accessibles, interventions en attente / en cours, résolues sur 7 jours, délai moyen de prise en charge, listes « Mes interventions en cours » et « Nouvelles alertes de ma zone ». Actualisation automatique (web) ou tirer pour rafraîchir (mobile).

**Traiter une intervention**
| Situation | Action |
|---|---|
| Dossier **nouveau** de votre zone/service | **Prendre en charge** |
| Dossier **affecté** à vous | **Accepter** ou **Décliner** (motif obligatoire, le superviseur est prévenu) |
| **Pris en charge** | **Démarrer l'intervention** (équipe en route / sur place) |
| **En cours** | **Clôturer** avec un compte rendu (visible du citoyen) et les difficultés éventuelles (internes) |

Le détail donne la position et sa précision, l'**itinéraire** (Google Maps), les photos, le contact du déclarant (une fois le dossier pris en charge) et l'historique. Vous pouvez ajouter des **notes** (internes ou visibles du citoyen) et ajuster la **gravité**. Si un autre agent a agi entre-temps, un message « dossier modifié entre-temps » s'affiche et la fiche se recharge.

## Superadministrateur (web uniquement : `/app/supervision`)

**Supervision** — indicateurs calculés en direct (filtres période, région, catégorie, granularité), évolution, répartition par catégorie et par région, carte des dossiers ouverts, qualité des données (position, précision GPS, description, photos, doublons). Survolez un indicateur pour sa définition ; la section « Définition des indicateurs » les détaille.

**Alertes de zone** — « Nouvelle alerte » : titre, message, consignes, niveau, régions (aucune = tout le pays), fin éventuelle. Les citoyens et agents concernés sont notifiés ; « Terminer » met fin à l'alerte.

**Communauté** — fil des incidents avec le nombre de confirmations ; modération des messages (masquer / rétablir), journalisée.

**Incidents / Alertes SOS** — tableau paginé, filtres combinables (référence, statut, catégorie, région, gravité, dates, doublons potentiels), panneau de détail. Actions : **Affecter / Réaffecter** (agents actifs couvrant la région, filtrables par service), **Rejeter** (signalement non fondé), **Annuler**, gravité, notes. Exports **CSV** (tableur, sans données personnelles) et **Rapport PDF**.

**Carte & risques** — score par région selon la méthode du mémoire, classement, carte, comparaison avec la période précédente, « Enregistrer un instantané » (historique). Un contour pointillé signale des données insuffisantes.

**Demandes d'accès** — demandes de compte agent (badge = nombre en attente). Vérifiez matricule et structure auprès du service, puis **Valider** (crée un compte agent limité au service et aux zones demandés ; le mot de passe reste celui choisi par l'agent) ou **Refuser** avec un motif. Tout est tracé dans le journal d'audit.

**Utilisateurs** — recherche et filtres ; **Créer un agent** (service, zones, mot de passe initial) ; modifier rôle (citoyen ↔ agent), service, zones, activer/désactiver (ferme les sessions). Le rôle superadministrateur ne se donne qu'en ligne de commande : `python manage.py creer_superadmin email@exemple.sn`.

**Services & catégories** — ajout, modification, désactivation (pas de suppression, pour préserver l'historique).

**Paramètres** — numéros d'urgence (seuls les numéros « Vérifié » sont affichés aux citoyens), délais de prise en charge (retards), détection des doublons, règles du cycle de vie, conservation des données, fonctionnalités (assistant, Google, carte publique). Toute modification est journalisée.

**Journal d'audit** — opérations sensibles filtrables par type et par date.

L'**administration technique** Django (`/admin/`) reste disponible pour la maintenance (journal en lecture seule).
