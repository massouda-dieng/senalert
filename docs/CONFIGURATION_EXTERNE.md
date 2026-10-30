# Configuration des services externes

Toutes les valeurs vont dans `backend/.env` (modèle : `backend/.env.example`) ou en `--dart-define` pour Flutter. Aucun secret n'est placé dans le web ou le mobile.

## 1. Connexion Google (OpenID Connect)

État : **code complet et testé avec des jetons simulés ; non testé avec de vrais identifiants** (aucun projet Google Cloud fourni).

1. Google Cloud Console → créer (ou choisir) un projet → *API et services → Écran de consentement OAuth* : type « Externe », nom « SenAlert », portée **`openid`, `email`, `profile`** uniquement.
2. *Identifiants → Créer → ID client OAuth* :
   * **Application Web** « SenAlert web » :
     * Origines JavaScript autorisées : `http://localhost:8000`, `http://127.0.0.1:8000`, `http://localhost:5173` (+ votre domaine HTTPS en production).
     * Aucun URI de redirection n'est nécessaire (Google Identity Services en mode popup).
   * **Android** « SenAlert Android » : nom de paquet `com.senalert.senalert_mobile` (attention : la variante *debug* ajoute le suffixe `.debug`, à déclarer aussi) + empreinte SHA-1 (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).
   * **iOS** « SenAlert iOS » : bundle ID `com.senalert.senalertMobile`.
3. `backend/.env` :
   ```
   GOOGLE_CLIENT_ID_WEB=<id client Web>.apps.googleusercontent.com
   GOOGLE_CLIENT_IDS_MOBILE=<id Android>,<id iOS>
   ```
4. Mobile : `GOOGLE_SERVER_CLIENT_ID=<id client Web> GOOGLE_IOS_CLIENT_ID=<id iOS> ./run.sh mobile`. Sur iOS, ajouter aussi le *reversed client ID* comme URL scheme dans `ios/Runner/Info.plist` (`CFBundleURLTypes`).
5. Vérification : la page de connexion web affiche le bouton Google ; un nouveau compte apparaît en rôle **Citoyen** ; le journal d'audit trace `compte.inscription_google`.

Règles appliquées par le backend : audience obligatoirement égale à l'un des identifiants ci-dessus, e-mail vérifié, liaison automatique uniquement vers un compte citoyen existant, jamais de rôle privilégié.

## 2. Firebase Cloud Messaging (push)

État : **backend prêt** (compte de service présent localement, envoi et suivi des statuts testés en simulation). Les fichiers `google-services.json` et `GoogleService-Info.plist` existent dans le dépôt. **Non testé sur appareil** (pas de SDK Android ni Xcode sur ce Mac).

1. Firebase Console → projet → *Paramètres → Comptes de service → Générer une clé privée* → enregistrer en `backend/firebase-adminsdk.json` (jamais dans Git).
2. Applications Android/iOS du même projet : `google-services.json` dans `mobile/android/app/`, `GoogleService-Info.plist` dans `mobile/ios/Runner/`. Le fichier actuel ne déclare que `com.senalert.senalert_mobile` : la variante *debug* (`applicationIdSuffix ".debug"`) doit être ajoutée dans Firebase, sinon le push est désactivé en débogage (l'application continue de fonctionner). Note : `android/app/` contient à la fois `build.gradle` et `build.gradle.kts` ; n'en garder qu'un lors de la première compilation Android.
3. iOS : clé APNs (Apple Developer) importée dans Firebase → *Cloud Messaging*.
4. Vérification : se connecter sur un téléphone, accepter les notifications, affecter un dossier à cet agent ; dans `/admin/notifications/notification/`, `statut_push` doit passer à `envoyee`. Sinon le statut indique la cause (`non_configure`, `aucun_appareil`, `echec`).

Sans Firebase, les notifications restent consultables dans l'application (historique serveur) : rien n'est bloqué.

## 3. Assistant IA (Groq)

État : **fonctionnel**, appel réel vérifié le 29/10/2026 avec le modèle `qwen/qwen3.8-27b` (le modèle `llama-3.3-70b-versatile` n'est plus disponible pour ce compte).

1. **Révoquer l'ancienne clé** (voir SECURITE.md), en créer une nouvelle sur console.groq.com.
2. `backend/.env` : `GROQ_API_KEY=…`, éventuellement `GROQ_MODEL=…` (liste : `curl -H "Authorization: Bearer $GROQ_API_KEY" https://api.groq.com/openai/v1/models`).
3. Sans clé, ou si Groq ne répond pas, l'assistant répond en **mode secours** à partir des fiches de premiers secours (indiqué à l'utilisateur).

## 4. PostgreSQL

État : **suite de tests complète validée sur PostgreSQL 15** (instance temporaire).

```bash
createuser -P senalert            # choisir un mot de passe
createdb -O senalert senalert
```
`backend/.env` : `DB_ENGINE=postgresql`, `DB_NAME=senalert`, `DB_USER=senalert`, `DB_PASSWORD=…`, `DB_HOST=localhost`, `DB_PORT=5432`, puis `python manage.py migrate`.
Reprise des données SQLite : `python manage.py dumpdata --natural-foreign --exclude contenttypes --exclude auth.permission --exclude token_blacklist > dump.json` (avec l'ancienne configuration), puis `loaddata dump.json` sur PostgreSQL.

## 5. E-mail (réinitialisation du mot de passe)

Sans configuration, l'e-mail est **affiché dans le terminal du serveur** (pratique en démonstration). Pour un envoi réel : `EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend` et les variables `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL`, `FRONTEND_URL`.

## 6. OpenStreetMap

Tuiles `tile.openstreetmap.org` et API Overpass publiques, sans clé. Respecter leurs conditions d'usage (attribution affichée, usage modéré — le backend met en cache 1 h). Pour un déploiement réel : héberger un serveur de tuiles ou utiliser un fournisseur commercial, et une instance Overpass dédiée (`OVERPASS_URL`).

## 7. Numéros d'urgence

Paramètre `numeros_urgence` (Supervision → Paramètres). Vérifiés le 29/10/2026 : **17 Police**, **18 Sapeurs-pompiers** (mémoire ch. 1, voyage.gc.ca, senego.com). **SAMU : sources divergentes (15 ou 1515)** → marqué non vérifié, donc **non affiché**. Cocher « Vérifié » après confirmation auprès du SAMU national, en renseignant la source.
