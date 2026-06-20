# SenAlert Mobile

Plateforme d'alertes citoyennes pour la gestion des urgences au Sénégal.

## Screens implémentées

1. **Splash Screen** – Animation de chargement avec logo SenAlert
2. **Écran d'accueil** – Boutons d'action, liste des alertes récentes
3. **Connexion** – Email + mot de passe, lien inscription
4. **Inscription** – Formulaire complet avec conditions d'utilisation
5. **Signaler une urgence** – Type d'incident, description, **localisation automatique**, photo
6. **Carte des incidents** – Carte interactive avec marqueurs colorés par type
7. **Détails d'une alerte** – Description, localisation, mini-carte, photo, bouton "Marquer comme traité"
8. **Dashboard Administrateur** – Sidebar de navigation, stats, tableau des alertes récentes
9. **Profil utilisateur** – Avatar, infos, menu, déconnexion

## Installation

### Prérequis
- Flutter SDK ≥ 3.0.0
- Android Studio / VS Code avec extension Flutter
- Java 11+

### Étapes

```bash
cd senalert_mobile
flutter pub get
flutter run
```

### Configuration Google Maps (optionnel pour la carte réelle)

1. Obtenir une clé API Google Maps sur https://console.cloud.google.com
2. Remplacer `YOUR_GOOGLE_MAPS_API_KEY` dans `android/app/src/main/AndroidManifest.xml`
3. Pour iOS, ajouter dans `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_KEY_HERE")
```

### Permissions requises

- `ACCESS_FINE_LOCATION` – Géolocalisation précise pour le signalement
- `ACCESS_COARSE_LOCATION` – Localisation approximative
- `CAMERA` – Prise de photo lors du signalement
- `READ_EXTERNAL_STORAGE` – Sélection de photo depuis la galerie
- `INTERNET` – Communication avec l'API backend

## Architecture

```
lib/
├── main.dart              # Point d'entrée, thème global
├── constants.dart         # Couleurs, styles, types d'incidents
├── models/
│   └── alert_model.dart   # Modèle de données AlertModel
└── screens/
    ├── splash_screen.dart
    ├── home_screen.dart
    ├── login_screen.dart
    ├── register_screen.dart
    ├── report_screen.dart          # Avec géolocalisation
    ├── incidents_map_screen.dart
    ├── alert_detail_screen.dart
    ├── admin_dashboard_screen.dart
    └── profile_screen.dart
```

## Design System

| Token | Valeur |
|-------|--------|
| Primary | `#CC1414` (rouge SenAlert) |
| Dark | `#1A1A2E` |
| Navy | `#16213E` (sidebar admin) |
| Warning | `#F59E0B` |
| Success | `#10B981` |
| Info | `#3B82F6` |

## Groupes - SenAlert

- Dieynaba
- Massouda  
- Asmaou
- Khady
- Ngone
