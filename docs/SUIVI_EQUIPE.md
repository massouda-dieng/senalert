# 📋 Guide équipe — Branche `design/refonte-ui`

## 🚀 Démarrage rapide

### 1. Récupérer les changements
```bash
git fetch origin
git checkout design/refonte-ui
# ou si tu travailles déjà sur cette branche :
git pull origin design/refonte-ui
```

### 2. Lancer le backend Django
```bash
cd backend
source venv/bin/activate   # ou venv\Scripts\activate sur Windows
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
# → http://127.0.0.1:8000
```

### 3. Lancer l'app mobile Flutter
```bash
cd mobile
flutter pub get

# Avec l'IA activée (clé Groq dans le .env) :
flutter run --dart-define=GROQ_API_KEY=<VOTRE_CLE_GROQ> -d chrome

# Sans clé (mode hors-ligne, fallback local) :
flutter run -d chrome
```

### 4. Ouvrir le dashboard web admin
```bash
open dashboard/index.html
# ou simplement double-cliquer sur le fichier dans Finder
```

---

## 👥 Comptes de test (backend Django local)

| Rôle | Username | Mot de passe | Redirigé vers |
|---|---|---|---|
| Citoyen | `citoyen1` | *(voir admin Django)* | Accueil citoyen |
| Agent de secours | `agent1` | *(voir admin Django)* | Tableau de bord agent |
| Administrateur | `admin` | *(voir admin Django)* | Tableau de bord agent |

> 💡 Pour voir/changer les mots de passe :
> ```bash
> cd backend && python manage.py shell -c "
> from django.contrib.auth import get_user_model
> User = get_user_model()
> for u in User.objects.all():
>     print(u.username, u.role)
> "
> ```

---

## 🎨 Changements UI/UX (résumé)

### App mobile Flutter
| Écran | Ce qui a changé |
|---|---|
| **Splash** | Logo animé (fade + scale) sur fond navy |
| **Onboarding** | 3 slides avec dégradés navy/orange |
| **Login/Register** | Dark theme navy, segmented Citoyen/Agent |
| **Accueil** | Page hero cinématique, SOS rouge pulsant, grille types |
| **SOS** | Bouton hold 3 sec avec countdown animé et feedback haptique |
| **Signaler** | Formulaire 3 étapes avec stepper animé |
| **Liste incidents** | Filtres par type/statut, cartes colorées |
| **Carte** | Leaflet flutter_map avec marqueurs colorés par type |
| **Assistant IA** | Chat avec historique complet + fallback hors-ligne |
| **Services proches** | Hôpitaux, pompiers, police avec distance |
| **Profil** | Avatar initiale + badge rôle + déconnexion |
| **Agent dashboard** | Statistiques, liste incidents, actions rapides |

### Dashboard web admin
- Champs login maintenant visibles (texte sombre sur fond clair)
- Sidebar dark navy avec navigation
- Cartes statistiques avec dégradés
- Carte Leaflet avec incidents en temps réel
- Filtres région/type/statut

---

## 🐛 Bugs corrigés

### Signalement ne fonctionnait pas
- **Cause** : `regionToApi()` générait des codes avec accents (`thies` → ok, `Saint-Louis` → `saint-louis` invalide)
- **Fix** : Table de correspondance exacte (`Saint-Louis` → `saint_louis`)
- **Cause 2** : Le payload envoyait un champ `location` inexistant côté backend
- **Fix 2** : Payload nettoyé (seulement `type_incident`, `region`, `description`, `latitude`, `longitude`)

### Dashboard login invisible
- **Cause** : Inputs sans couleur de texte → héritage fond sombre
- **Fix** : `color: #0F172A; background: #F8FAFC` explicites

### Routing rôles
- **Fix** : `admin` et `autorite` → `/agent-dashboard`, `citoyen` → `/home`

---

## 🤖 Assistant IA — Mode de lancement

L'IA utilise l'API Groq (Llama-3.3-70B). La clé est dans `backend/.env`.

```bash
# Récupérer la clé depuis backend/.env (à partager en privé avec l'équipe)
# Lancer avec l'IA active :
flutter run --dart-define=GROQ_API_KEY=$(grep GROQ_API_KEY backend/.env | cut -d= -f2) -d chrome

# En production (APK) :
flutter build apk --dart-define=GROQ_API_KEY=<VOTRE_CLE_GROQ>
```

Sans la clé, l'assistant fonctionne en mode **hors-ligne** avec des réponses préenregistrées pour 8 urgences (RCP, incendie, inondation, serpent, électrocution, hémorragie, évanouissement, coup de chaleur).

---

## 📁 Structure des fichiers modifiés

```
senalert/
├── mobile/lib/
│   ├── app.dart                          ← Routing par rôle
│   ├── core/constants/
│   │   ├── app_colors.dart               ← Palette navy/orange + gradients
│   │   └── api_constants.dart            ← URLs API backend
│   ├── shared/widgets/sa_ui.dart         ← Kit UI partagé (30+ widgets)
│   └── features/
│       ├── home/screens/home_screen.dart ← 🆕 Hero animé
│       ├── first_aid/first_aid_screen.dart ← 🆕 IA contextuelle
│       ├── auth/providers/auth_provider.dart ← Rôles + isAdmin
│       └── incidents/providers/incident_provider.dart ← Payload fix
└── dashboard/index.html                  ← 🆕 Login visible + dark theme
```

---

*Dernière mise à jour : $(date +"%Y-%m-%d") — Branche : design/refonte-ui*
