# Image de production de SenAlert (utilisée par Render).
# 1) Le site React est compilé ; 2) Django le sert avec WhiteNoise, derrière gunicorn.

FROM node:20.18.1-alpine AS web
WORKDIR /app/web
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY web/ ./
# Le site lit les couleurs et les traductions partagées avec l'application mobile
COPY design/ /app/design/
COPY traductions/ /app/traductions/
RUN npm run build

FROM python:3.13.1-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app/backend
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ ./
COPY --from=web /app/web/dist /app/web/dist
# Application mobile (version web de Flutter, compilée à l'avance), servie à l'adresse /mobile/
COPY deploiement/mobile-web/ /app/simulateur-mobile/
# Fichiers statiques collectés à la construction (la clé ci-dessous ne sert qu'à cette étape)
RUN DEBUG=False SECRET_KEY=construction-uniquement python manage.py collectstatic --noinput

EXPOSE 8000
# Au démarrage : migrations, comptes définis par les variables d'environnement, puis le serveur
CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py preparer_en_ligne && gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 2 --timeout 120"]
