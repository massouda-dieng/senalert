#!/bin/bash
# =============================================================================
# SenAlert — lancement local (macOS)
#   ./run.sh backend          API + application web compilée  → http://127.0.0.1:8000/app/
#   ./run.sh web              serveur de développement React  → http://localhost:5173/app/
#   ./run.sh mobile [cible]   application Flutter (chrome par défaut, ou un id d'appareil)
#   ./run.sh tests            tous les tests (backend, web, mobile)
# Aucune clé secrète n'est transmise à l'application mobile : l'IA passe par le backend.
# =============================================================================
set -e
RACINE="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="${FLUTTER:-$(command -v flutter || echo /Users/hannadiop/Documents/flutter/bin/flutter)}"

case "${1:-backend}" in
  backend)
    cd "$RACINE/backend"
    [ -d env ] || python3 -m venv env
    source env/bin/activate
    pip install -q -r requirements.txt
    python manage.py migrate
    if [ ! -f "$RACINE/web/dist/index.html" ] && command -v npm >/dev/null; then
      (cd "$RACINE/web" && npm install --no-audit --no-fund && npm run build)
    fi
    echo "→ http://127.0.0.1:8000/app/   (API : http://127.0.0.1:8000/api/docs/)"
    python manage.py runserver 0.0.0.0:8000
    ;;
  web)
    cd "$RACINE/web" && npm install --no-audit --no-fund && npm run dev
    ;;
  mobile)
    cd "$RACINE/mobile"
    CIBLE="${2:-chrome}"
    API="${API_BASE_URL:-http://127.0.0.1:8000/api}"
    "$FLUTTER" pub get
    exec "$FLUTTER" run -d "$CIBLE" \
      --dart-define=API_BASE_URL="$API" \
      --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
      --dart-define=GOOGLE_IOS_CLIENT_ID="${GOOGLE_IOS_CLIENT_ID:-}"
    ;;
  tests)
    (cd "$RACINE/backend" && source env/bin/activate && python manage.py test)
    (cd "$RACINE/web" && npx vitest run)
    (cd "$RACINE/mobile" && "$FLUTTER" analyze && "$FLUTTER" test)
    ;;
  *)
    echo "Usage : ./run.sh [backend|web|mobile [cible]|tests]"; exit 1 ;;
esac
