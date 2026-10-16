# TABLEAU DE SUIVI ÉQUIPE — SENALERT
> Mis à jour le 15 octobre 2026 par Antigravity (Responsable Technique)

---

## Répartition des responsabilités

| Membre | Branche | Périmètre principal | Statut |
|---|---|---|---|
| **Massouda Dieng** | `feature/massouda-coordination-dashboard` | Dashboard web, intégration finale, documentation | 🟡 En cours |
| **Ndeye Ngone Fall** | `feature/ndeye-backend-api` | Backend API, modèles, sécurité | 🟢 Base stable |
| **Dieynaba Deme** | `feature/dieynaba-mobile-citoyen` | Écrans citoyens Flutter | 🟡 En cours |
| **Asmaou Balde** | `feature/asmaou-mobile-agent-tests` | Écran agent + tests | 🟡 En cours |

---

## MASSOUDA DIENG — Coordination & Dashboard

### Branche : `feature/massouda-coordination-dashboard`

### Fichiers concernés
- `dashboard/index.html` — Dashboard web complet (627 lignes HTML/JS/CSS)
- `README.md` — Documentation principale
- `docs/realisation/` — Documentation chapitre 4

### Objectifs
1. ✅ Vérifier que le dashboard se connecte à l'API réelle (`/dashboard/stats/`)
2. ✅ Activer la navigation entre les sections du dashboard (Alertes SOS, Interventions, Utilisateurs, Statistiques)
3. Réaliser les captures d'écran pour le chapitre 4
4. Coordonner les pull requests des autres membres vers `main`
5. Valider la cohérence visuelle entre le dashboard et le mobile

### Critères de réussite
- Dashboard se connecte au backend et affiche des données réelles
- Chaque item du menu navigue vers une section visible
- Les 14 captures du chapitre 4 sont réalisées

### Commandes utiles
```bash
# Tester le backend en local
cd backend && python manage.py runserver
# Ouvrir le dashboard
open dashboard/index.html
```

### ⚠️ Points de vigilance
- Ne pas modifier `backend/config/settings.py` ou `config/urls.py` sans coordination avec Ndeye
- Les secrets (`.env`, `firebase-adminsdk.json`) ne doivent jamais être commités
- L'URL API dans le dashboard doit pointer vers `http://127.0.0.1:8000`

---

## NDEYE NGONE FALL — Backend API

### Branche : `feature/ndeye-backend-api`

### Fichiers concernés
- `backend/accounts/` — Modèles, serializers, vues, tests
- `backend/alerts/` — Modèle AlerteSOS, vues, Firebase
- `backend/incidents/` — Modèle, vues, permissions, tests
- `backend/analyse/` — Score de risque, AI Groq
- `backend/dashboard/` — Endpoint stats
- `backend/config/settings.py` — Configuration

### Objectifs
1. ✅ Permission `IsOwnerOrAdminOrReadOnly` sur incidents (fait + 5 tests)
2. ✅ Endpoint `/dashboard/stats/` avec données réelles (fait + 3 tests)
3. Vérifier l'installation de `firebase_admin` dans l'environnement
4. Tester les endpoints manuellement avec `curl` ou Postman
5. Vérifier les migrations sur une base propre

### Critères de réussite
- `python manage.py test` : 22 tests verts (déjà OK)
- `python manage.py check` : 0 issues
- Tous les endpoints répondent correctement (tester avec Postman)

### Commandes de test
```bash
cd backend
source env/bin/activate
python manage.py test --verbosity=2
# Test manuel avec curl
curl -X POST http://127.0.0.1:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"votre_password"}'
```

### ⚠️ Points de vigilance
- Ne pas modifier les migrations existantes — créer de nouvelles migrations si nécessaire
- La `SECRET_KEY` dans `.env` est insécurisée (django-insecure) : acceptable pour la démo, à changer en production
- **ACTION URGENTE** : Révoquer et renouveler la clé Groq API (exposée dans l'historique git)
  - Aller sur https://console.groq.com → API Keys → Révoquer la clé actuelle → Créer une nouvelle → Mettre à jour `.env`

---

## DIEYNABA DEME — Mobile Citoyen

### Branche : `feature/dieynaba-mobile-citoyen`

### Fichiers concernés
- `mobile/lib/features/auth/` — Login, Register
- `mobile/lib/features/home/` — Tableau de bord citoyen
- `mobile/lib/features/sos/` — SosScreen (551 lignes, complet)
- `mobile/lib/features/report/` — Formulaire signalement
- `mobile/lib/features/incidents/` — Liste, détail, carte
- `mobile/lib/features/first_aid/` — Guide premiers secours
- `mobile/lib/features/services/` — Services de proximité
- `mobile/lib/core/constants/api_constants.dart` — URL API

### Objectifs
1. Vérifier que la connexion fonctionne sur émulateur (mot de passe JWT reçu)
2. Vérifier que le formulaire de signalement envoie à `/api/incidents/`
3. Vérifier que la carte affiche les incidents depuis l'API
4. Vérifier le guide premiers secours (contenu des fiches + mode offline)
5. Vérifier les services de proximité (données, vérifier si statiques ou API)

### Critères de réussite
- Connexion JWT fonctionnelle sur émulateur
- Création d'un incident depuis l'app (visible sur le dashboard)
- Déclenchement SOS enregistré en base

### Commandes utiles
```bash
cd mobile
flutter pub get
flutter analyze         # Vérification statique
flutter run             # Lancement sur émulateur
```

### ⚠️ Points de vigilance
- `api_constants.dart` : utiliser `10.0.2.2:8000` pour Android, `127.0.0.1:8000` pour iOS
- `firebase_core` est dans pubspec.yaml mais `google-services.json` doit être présent pour iOS/Android
- Le fichier `google-services.json` est détecté dans `mobile/android/app/` mais n'est pas commité (normal, dans gitignore)
- Ne pas inclure de données personnelles réelles dans les tests

---

## ASMAOU BALDE — Mobile Agent + Tests

### Branche : `feature/asmaou-mobile-agent-tests`

### Fichiers concernés
- `mobile/lib/features/agent/` — AgentDashboardScreen
- `mobile/lib/features/profile/` — ProfileScreen
- `mobile/test/` — Tests unitaires Flutter
- `backend/` — Vérification tests existants

### Objectifs
1. Vérifier le fonctionnement de l'écran agent (connexion avec rôle `autorite`)
2. Tester la mise à jour de statut d'un incident (PATCH `/api/incidents/{id}/`)
3. Vérifier que seuls les incidents de la région et du type de l'autorité apparaissent
4. Écrire ou compléter les tests Flutter dans `mobile/test/`
5. Documenter les résultats des tests dans le rapport

### Critères de réussite
- L'agent voit uniquement les incidents de sa compétence (type + région)
- La mise à jour de statut est persistée et visible après rechargement
- Les tests Flutter (au moins `flutter analyze` sans erreur)

### Commandes utiles
```bash
# Créer un compte autorité pour les tests
curl -X POST http://127.0.0.1:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"pompier1","password":"Pompier123!","role":"autorite","region":"dakar"}'

# Tester la liste d'incidents de l'autorité
curl -H "Authorization: Bearer <TOKEN>" \
  http://127.0.0.1:8000/api/auth/mes-incidents/

# Tests Flutter
cd mobile
flutter test
flutter analyze
```

### ⚠️ Points de vigilance
- Les tests de permission ont été écrits côté backend (`incidents/tests.py`) — les vérifier
- L'autorité peut PATCH (modifier statut) mais pas DELETE (c'est intentionnel)
- Documenter honnêtement dans le rapport ce qui est testé vs ce qui est démontré

---

## POINTS D'INTÉGRATION

Pour éviter les conflits, respecter les règles suivantes :

### ✅ Coordination des merges
1. **Ndeye** push `feature/ndeye-backend-api` → Pull Request vers `main` → **Massouda** valide et merge
2. **Dieynaba** push `feature/dieynaba-mobile-citoyen` → PR vers `main` → **Massouda** valide
3. **Asmaou** push `feature/asmaou-mobile-agent-tests` → PR vers `main` → **Massouda** valide
4. **Massouda** est la seule à merger vers `main`

### ❌ Règles à respecter
- Ne jamais forcer un push (`git push --force`)
- Ne pas modifier les fichiers des autres membres sans coordination
- Toujours vérifier `git status` avant de commiter
- Ne jamais commiter `.env` ou `firebase-adminsdk.json`

### 📋 Checklist avant chaque commit
- [ ] `git status` : vérifier que seuls mes fichiers sont modifiés
- [ ] Pas de secrets dans les fichiers (`.env`, clés API dans le code)
- [ ] Tests passent : `python manage.py test` ou `flutter analyze`
- [ ] Message de commit explicite (ex: "🐛 Fix permission incidents autorité")

---

## CALENDRIER SUGGÉRÉ

| Semaine | Tâche | Responsable |
|---|---|---|
| S1 | Corrections backend (permissions, stats) — **Fait** | Ndeye + Antigravity |
| S1 | Documentation chapitre 4 | Massouda |
| S1-S2 | Tests mobile sur émulateur | Dieynaba + Asmaou |
| S2 | Navigation dashboard web | Massouda |
| S2 | Captures d'écran | Toute l'équipe |
| S2 | Intégration finale sur `main` | Massouda |
| S3 | Préparation soutenance | Toute l'équipe |

---

## Mise à jour du 16 octobre 2026 — corrections intégrées sur `main`

Dépôt officiel : https://github.com/massouda-dieng/senalert-pff

| Commit | Correction | Concerne |
|---|---|---|
| `1799363` | `db.sqlite3` retirée du dépôt public (`*.sqlite3` ignoré) | Toutes |
| `477d5b1` | Dashboard : carte « Alertes SOS » réelle via `/dashboard/stats/` (suppression du « 8.4 min » fictif) | Massouda |
| `c0475ee` | Mobile : le signalement envoie `region` + codes type/région valides ; erreur affichée au lieu d'un faux succès | Dieynaba |
| `2044df0` / `da61d50` | Mobile SOS : pas de crash si l'écran est quitté ; message honnête si GPS indisponible | Dieynaba |
| `ce65ce0` | Mobile agent : le changement de statut est synchronisé avec le serveur (PATCH) | Asmaou |

Vérifications : backend 22/22 tests · `flutter analyze` 0 erreur · `flutter test` 4/4.

### À faire par chaque membre avant de reprendre le travail
```bash
git clone https://github.com/massouda-dieng/senalert-pff.git   # première fois seulement
cd senalert-pff
git checkout feature/<votre-branche>
git pull origin main          # récupère les corrections ci-dessus
```

### Points ouverts
- Statut « refusé » (agent) : n'existe pas côté backend → reste local. À ajouter à `Incident.STATUT_CHOICES` si nécessaire (Ndèye).
- Type « Urgence médicale » (mobile) : envoyé comme `autre` faute de choix backend équivalent (Ndèye / Dieynaba).
- `backend/analyse/test_flutter.dart` : test Dart placé dans le backend ; à déplacer dans `mobile/test/` avec la dépendance `http` en dev (Asmaou).
