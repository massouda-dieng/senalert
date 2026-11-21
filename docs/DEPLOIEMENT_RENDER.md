# Mettre SenAlert en ligne sur Render (offre gratuite)

SenAlert est construit avec le `Dockerfile` : le site React est compilé, puis Django le sert avec gunicorn. Le fichier `render.yaml` décrit le service web et sa base PostgreSQL. Render met le site à jour à chaque envoi sur la branche `test`.

## 1. Envoyer le code sur GitHub

Dans VS Code, ouvrez l'onglet « Contrôle de code source », puis cliquez sur « Synchroniser les modifications ». La branche `test` de `massouda-dieng/senalert` doit contenir `Dockerfile` et `render.yaml`.

## 2. Créer le service sur Render

1. Allez sur https://render.com, puis cliquez sur **Get Started**. Connectez-vous avec **GitHub** et autorisez l'accès au dépôt `senalert`.
2. Cliquez sur **New +**, puis **Blueprint**. Choisissez le dépôt `massouda-dieng/senalert` et la branche **test**.
3. Render lit `render.yaml` et vous demande les valeurs secrètes :

| Variable | Valeur |
|---|---|
| `GROQ_API_KEY` | La clé Groq, à recopier depuis `backend/.env`. |
| `GOOGLE_CLIENT_ID_WEB` | L'identifiant Google, à recopier depuis `backend/.env`. |
| `SENALERT_ADMIN_EMAIL` | L'adresse e-mail du compte administrateur en ligne. |
| `SENALERT_ADMIN_MOT_DE_PASSE` | Son mot de passe : au moins 8 caractères, pas seulement des chiffres. |
| `SENALERT_MOT_DE_PASSE_DEMO` | Le mot de passe commun des comptes de démonstration (Awa, Cheikh, Moussa…). |

4. Cliquez sur **Apply**. La première construction dure environ 10 minutes.
5. L'adresse du site s'affiche en haut du service, par exemple `https://senalert-xxxx.onrender.com`. L'application est à cette adresse suivie de `/app/`.

## 3. Autoriser la connexion Google sur cette adresse

1. Ouvrez https://console.cloud.google.com, puis **API et services**, puis **Identifiants**.
2. Ouvrez le client OAuth de type **Application Web**.
3. Dans **Origines JavaScript autorisées**, cliquez sur **Ajouter un URI** et entrez l'adresse Render, sans `/app/`, par exemple `https://senalert-xxxx.onrender.com`.
4. Cliquez sur **Enregistrer**. Le changement peut prendre quelques minutes.

## 4. Comptes en ligne

Au premier démarrage, la commande `preparer_en_ligne` crée :
- **le compte administrateur**, défini par `SENALERT_ADMIN_EMAIL` et `SENALERT_ADMIN_MOT_DE_PASSE` ;
- **les comptes de démonstration**, tous avec le mot de passe `SENALERT_MOT_DE_PASSE_DEMO` :
  - citoyen : `citoyen.test@senalert.local` ;
  - agents : `agent.pompiers@senalert.local`, `agent2.pompiers@…`, `agent.police@…`, `agent.sante@…`, `agent.senelec@…`, `agent.onas@…` ;
  - superviseurs : `superviseur.pompiers@senalert.local`, `superviseur.police@…`, etc.

Un compte qui existe déjà n'est jamais modifié.

## 5. Limites de l'offre gratuite

- **Le site s'endort** après 15 minutes sans visite. La visite suivante le réveille en une minute environ. **Ouvrez le site 5 minutes avant la soutenance.**
- **La base PostgreSQL gratuite** expire 30 jours après sa création.
- **Les photos jointes aux signalements** sont effacées à chaque redémarrage, car le disque n'est pas conservé.
- **Les notifications push** demandent en plus le fichier Firebase, à déposer dans Render (**Environment**, puis **Secret Files**) sous le nom `firebase-adminsdk.json`. Il faut alors ajouter la variable `FIREBASE_CREDENTIALS_PATH=/etc/secrets/firebase-adminsdk.json`.
