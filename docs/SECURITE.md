# Rapport de sécurité et de confidentialité

## ⚠️ Actions immédiates requises (hors de ma portée)

1. **Révoquer la clé Groq actuelle** (console.groq.com → API Keys) : elle a été publiée en clair dans l'historique Git (`mobile/lib/features/first_aid/first_aid_screen.dart`, commits `78a3b38` et `227adc0`, poussés sur `pff/main`). C'est la même clé que celle de `backend/.env`. Créer une nouvelle clé et la placer **uniquement** dans `backend/.env`. Supprimer la clé de l'historique ne suffit pas : elle doit être considérée comme compromise.
2. **Changer les mots de passe** des comptes existants `admin`, `citoyen1`, `agent1`, `mass`, `massouda` : des mots de passe de démonstration avaient été publiés dans la documentation du dépôt.
3. La `SECRET_KEY` de `backend/.env` a été remplacée par une valeur aléatoire (l'ancienne était la clé « django-insecure » visible dans le dépôt). Conséquence : les anciennes sessions sont invalidées.
4. `backend/firebase-adminsdk.json` (clé privée de compte de service) n'est pas versionné — vérifié. Les fichiers `google-services.json` / `GoogleService-Info.plist` sont versionnés : ce sont des identifiants **publics** d'application, sans secret, mais restreignez la clé d'API Firebase associée aux applications Android/iOS dans Google Cloud Console.

## Mesures en place

| Domaine | Mesure | Où |
|---|---|---|
| Rôles | Rôle attribué par le serveur ; inscription toujours citoyen ; Google ne donne jamais de rôle privilégié ; superadmin uniquement par `python manage.py creer_superadmin` ; un superadmin ne peut ni se modifier ni être modifié via l'API | `accounts/serializers.py`, `accounts/views.py`, `accounts/google.py` |
| Contrôle d'accès | Requêtes filtrées par rôle (un dossier non visible renvoie 404) ; chaque action de la machine à états vérifie rôle, affectation, zone et service | `incidents/workflow.py`, `dossier_views.py` |
| Sessions | JWT 15 min ; rafraîchissement 7 jours avec rotation et liste noire ; déconnexion révoque ; « tous les appareils » ; changement de mot de passe / désactivation / changement de rôle ferment toutes les sessions | `config/settings.py`, `accounts/views.py` |
| Stockage des jetons | Mobile : trousseau (Keychain/Keystore) ; web : accès en mémoire, rafraîchissement en `sessionStorage` | `mobile/lib/core/api.dart`, `web/src/api/client.js` |
| Mots de passe | Validateurs Django (8 car. min., courants, numériques) ; réinitialisation par lien signé à usage unique, 1 h, réponse identique que le compte existe ou non | `accounts/views.py` |
| Force brute / abus | Limitation : connexion 10/min, inscription 10/h, mot de passe 5/h, SOS 10/h, signalement 30/h, assistant 20/min et 200/jour, services 30/min | `REST_FRAMEWORK.DEFAULT_THROTTLE_RATES` |
| Google | ID token vérifié côté serveur (signature Google, émetteur, audience = nos identifiants, expiration, e-mail vérifié) ; liaison automatique seulement vers un compte citoyen ; compte agent/superadmin : liaison depuis une session authentifiée | `accounts/google.py` |
| Fichiers | Taille ≤ 5 Mo, ≤ 5 par dossier, JPEG/PNG/WEBP vérifiés par Pillow, ré-encodés en JPEG (EXIF et GPS supprimés), nom aléatoire, jamais servis publiquement (vue contrôlée) | `incidents/photos.py`, `views.py` |
| Injection | ORM uniquement ; échappement HTML dans les infobulles de carte ; React échappe par défaut | — |
| IA | Clé côté serveur ; e-mails et téléphones masqués avant envoi ; consignes système prioritaires et message utilisateur balisé comme donnée ; seuls les numéros vérifiés autorisés (filtre en sortie) ; repli local sans IA | `analyse/assistant.py` |
| CORS / CSRF | Aucune origine ouverte ; en développement seules `localhost`/`127.0.0.1` sont acceptées ; le web est servi en même origine | `config/settings.py` |
| HTTPS / en-têtes | En production (`DEBUG=False`) : redirection HTTPS, HSTS 1 an, cookies sécurisés, `X-Frame-Options: DENY`, `nosniff` ; `manage.py check --deploy` sans avertissement bloquant ; démarrage refusé sans `SECRET_KEY` | `config/settings.py` |
| Journaux | Filtre de masquage des mots de passe, jetons, clés `gsk_…` ; erreurs 500 génériques (détail uniquement côté serveur) | `core/logging.py`, `core/exceptions.py` |
| Audit | Inscriptions, échecs de connexion, connexions Google, réinitialisations, créations/modifications de comptes, affectations, annulations, rejets, modifications de configuration, exports, instantanés de score | `core.JournalAudit`, `/supervision/audit` |
| Mobile | Permissions minimales (localisation « pendant l'utilisation », caméra) ; suppression de `ACCESS_BACKGROUND_LOCATION` et du stockage externe ; textes d'usage iOS ajoutés ; aucun journal réseau | `AndroidManifest.xml`, `Info.plist` |

## Confidentialité (loi n° 2008-12, CDP)

* **Minimisation** : la position n'est collectée qu'à l'envoi d'un SOS / signalement ou d'une recherche de services (arrondie à ~1 km avant l'appel à OpenStreetMap) ; la carte citoyenne n'affiche ni description, ni photo, ni identité, et arrondit les positions à ~100 m ; le téléphone du déclarant n'est visible que de l'agent affecté et du superadmin ; les exports ne contiennent aucune donnée personnelle.
* **Droits des personnes** : modification du profil, préférences de notification, suppression du compte (anonymisation), historique de l'assistant conservé uniquement sur l'appareil.
* **Conservation** : paramètre `conservation.jours_avant_anonymisation` (730 jours par défaut) ; commande `python manage.py anonymiser_dossiers_anciens` (simulation par défaut, `--appliquer` pour exécuter). Les coordonnées sont conservées pour les statistiques.
* **Sous-traitants** : Groq (texte des questions, données personnelles masquées), Google (connexion), Firebase (jetons d'appareil), OpenStreetMap (position arrondie). À mentionner dans la politique de confidentialité.
* **Conformité** : ces mesures vont dans le sens de la loi n° 2008-12, mais **la conformité n'est pas acquise** : une déclaration ou demande d'autorisation auprès de la CDP, une politique de confidentialité, des mentions d'information et une analyse d'impact (données de localisation, situations d'urgence) restent à réaliser par le responsable du traitement.

## Risques résiduels

* Le jeton de rafraîchissement web en `sessionStorage` reste lisible par un script injecté (XSS). Amélioration : cookie `HttpOnly` + protection CSRF.
* Les envois push sont synchrones dans la requête (latence si FCM est lent). Amélioration : file de tâches (Celery/RQ).
* `android:usesCleartextTraffic="true"` est nécessaire pour l'API locale en HTTP ; à désactiver pour une version de production servie en HTTPS.
* Pas d'antivirus sur les images (le ré-encodage neutralise toutefois les fichiers polyglottes).
* Les comptes de test (`creer_comptes_test`) ne doivent jamais être créés en production.
