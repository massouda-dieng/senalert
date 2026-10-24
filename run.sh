#!/bin/bash
# =============================================================
# SenAlert — Script de lancement Flutter avec IA Groq activée
# Usage: bash run.sh            → lance sur Chrome
#        bash run.sh android    → lance sur Android
#        bash run.sh ios        → lance sur iOS Simulator
# =============================================================

FLUTTER=/Users/hannadiop/Documents/flutter/bin/flutter
ENV_FILE="$(dirname "$0")/backend/.env"
MOBILE_DIR="$(dirname "$0")/mobile"

# Lire la clé Groq depuis backend/.env
GROQ_KEY=""
if [ -f "$ENV_FILE" ]; then
  GROQ_KEY=$(grep -E "^GROQ_API_KEY=" "$ENV_FILE" | cut -d= -f2 | tr -d ' \r\n')
fi

if [ -z "$GROQ_KEY" ]; then
  echo "⚠️  Clé GROQ_API_KEY introuvable dans backend/.env — l'IA tournera en mode hors-ligne"
else
  echo "✅  Clé Groq chargée (${#GROQ_KEY} caractères)"
fi

DEVICE="${1:-chrome}"

echo "🚀  Lancement Flutter sur: $DEVICE"
cd "$MOBILE_DIR" || exit 1

exec $FLUTTER run \
  --dart-define=GROQ_API_KEY="$GROQ_KEY" \
  -d "$DEVICE"
