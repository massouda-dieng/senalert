#!/bin/bash
# Sauvegarde de la base SenAlert et des pièces jointes dans backups/AAAAMMJJ-HHMMSS/
# Usage : ./scripts/sauvegarde.sh
set -e
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
CIBLE="$RACINE/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$CIBLE"
cd "$RACINE/backend"
MOTEUR=$(grep -E '^DB_ENGINE=' .env 2>/dev/null | cut -d= -f2)
if [ "$MOTEUR" = "postgresql" ]; then
  lire() { grep -E "^$1=" .env | cut -d= -f2-; }
  PGPASSWORD="$(lire DB_PASSWORD)" pg_dump -h "$(lire DB_HOST)" -p "$(lire DB_PORT)" -U "$(lire DB_USER)" -Fc "$(lire DB_NAME)" > "$CIBLE/senalert.dump"
else
  sqlite3 db.sqlite3 ".backup '$CIBLE/db.sqlite3'"
fi
[ -d media ] && tar -czf "$CIBLE/media.tar.gz" media
chmod -R go-rwx "$CIBLE"
echo "Sauvegarde : $CIBLE"
