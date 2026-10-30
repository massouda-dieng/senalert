# Installer SenAlert sur un vrai téléphone Android

Durée : environ 45 minutes (dont téléchargements). À faire une seule fois sur le Mac.

## 1. Installer Android Studio

1. Télécharger Android Studio (gratuit) : https://developer.android.com/studio — version compatible macOS 12.
   Ou en terminal : `brew install --cask android-studio`
2. Ouvrir Android Studio → « Next » jusqu'au bout de l'assistant (installation « Standard »). Il télécharge le SDK Android (~3 Go).
3. **Accepter les licences** (étape que vous seule pouvez valider) :
   ```bash
   flutter doctor --android-licenses      # répondre « y » à chaque licence
   flutter config --enable-android
   flutter doctor                         # « Android toolchain » doit être coché
   ```

## 2. Préparer le téléphone

1. Réglages → À propos du téléphone → toucher **7 fois** « Numéro de build » (active le mode développeur).
2. Réglages → Options pour les développeurs → activer **Débogage USB**.
3. Brancher le téléphone en USB au Mac → accepter « Autoriser le débogage USB » sur le téléphone.
4. Vérifier : `flutter devices` doit afficher le téléphone.

## 3. Lancer l'application sur le téléphone

Le téléphone et le Mac doivent être sur le **même Wi-Fi**.

```bash
# Terminal 1 — serveur accessible depuis le réseau local
cd ~/Documents/PFF/senalert/backend
IP=$(ipconfig getifaddr en0); echo "IP du Mac : $IP"
# ajouter l'IP aux hôtes autorisés (une fois) : ALLOWED_HOSTS=127.0.0.1,localhost,10.0.2.2,<IP> dans backend/.env
python manage.py runserver 0.0.0.0:8000

# Terminal 2 — application
cd ~/Documents/PFF/senalert/mobile
flutter run -d <id-du-téléphone> --dart-define=API_BASE_URL=http://$(ipconfig getifaddr en0):8000/api
```

## 4. Fichier APK à partager (installer sans câble)

```bash
cd ~/Documents/PFF/senalert/mobile
flutter build apk --release --dart-define=API_BASE_URL=http://<IP-du-Mac>:8000/api
# → build/app/outputs/flutter-apk/app-release.apk (à envoyer par WhatsApp / e-mail, « sources inconnues » à autoriser)
```

Remarque : `android/app/` contient à la fois `build.gradle` et `build.gradle.kts` ; si la première compilation échoue sur ce point, supprimer `build.gradle.kts` (ancien fichier) et relancer.

## 5. Notifications push réelles

Elles fonctionnent sur un vrai téléphone dès que le Firebase du projet est configuré (voir `CONFIGURATION_EXTERNE.md` §2). La variante de débogage porte l'identifiant `com.senalert.senalert_mobile.debug` : l'ajouter comme application Android dans la console Firebase, sinon le push reste désactivé (l'application fonctionne quand même).

## Sans téléphone Android

- **Simulateur intégré** : http://127.0.0.1:8000/app/simulateur (cadres iPhone / Android).
- **Application installable (PWA)** : sur n'importe quel téléphone, ouvrir `http://<IP-du-Mac>:8000/app/` dans Chrome → menu → « Installer l'application » / « Ajouter à l'écran d'accueil ». (Les navigateurs exigent HTTPS pour l'installation hors `localhost` : pour une vraie diffusion, déployer derrière HTTPS.)
