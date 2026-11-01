#!/bin/bash
# Restaure une sauvegarde créée par sauvegarde.sh. ARRÊTEZ le serveur avant.
# Usage : ./scripts/restauration.sh backups/AAAAMMJJ-HHMMSS
set -e
SOURCE="$(cd "${1:?Indiquez le dossier de sauvegarde}" && pwd)"
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RACINE/backend"
read -r -p "Remplacer la base actuelle par $SOURCE ? (oui/non) " R
[ "$R" = "oui" ] || exit 1
# Sauvegarde de sécurité de l'état actuel avant écrasement
"$RACINE/scripts/sauvegarde.sh"
if [ -f "$SOURCE/senalert.dump" ]; then
  lire() { grep -E "^$1=" .env | cut -d= -f2-; }
  PGPASSWORD="$(lire DB_PASSWORD)" pg_restore --clean --if-exists -h "$(lire DB_HOST)" -p "$(lire DB_PORT)" -U "$(lire DB_USER)" -d "$(lire DB_NAME)" "$SOURCE/senalert.dump"
else
  cp "$SOURCE/db.sqlite3" db.sqlite3
fi
[ -f "$SOURCE/media.tar.gz" ] && tar -xzf "$SOURCE/media.tar.gz"
source env/bin/activate && python manage.py migrate
echo "Restauration terminée."
