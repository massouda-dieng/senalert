# SCRIPT DE DÉMONSTRATION — SOUTENANCE SENALERT
> ISEP Amadou Traoré de Diamniadio · Promotion 2025–2026  
> Durée estimée : 8–10 minutes

---

## AVANT LA SOUTENANCE (la veille)

### Fenêtre Terminal 1 — Lancer le serveur
```bash
cd ~/Documents/PFF/senalert/backend
/opt/miniconda3/bin/python3.13 manage.py migrate
/opt/miniconda3/bin/python3.13 manage.py runserver
```
Résultat attendu : `Starting development server at http://127.0.0.1:8000/`

### Fenêtre Terminal 2 — Vérifier les tests
```bash
cd ~/Documents/PFF/senalert/backend
/opt/miniconda3/bin/python3.13 manage.py test --verbosity=1
```
Résultat attendu : `Ran 25 tests ... OK`

### Créer les comptes de démonstration (une seule fois)
```bash
cd ~/Documents/PFF/senalert/backend
/opt/miniconda3/bin/python3.13 manage.py shell
```
Dans le shell Python :
```python
from accounts.models import User
User.objects.create_superuser(username='admin', password='senalert2026', email='admin@senalert.sn', role='admin')
User.objects.create_user(username='citoyen1', password='senalert2026', role='citoyen', phone_number='+221770000001')
User.objects.create_user(username='agent1', password='senalert2026', role='autorite', phone_number='+221770000002')
print("OK")
exit()
```

### Ouvrir le dashboard dans Chrome
```
file:///Users/hannadiop/Documents/PFF/senalert/dashboard/index.html
```

---

## DÉROULÉ (8–10 minutes)

### Acte 1 — Architecture (1 min, à l'oral)
« SenAlert est une plateforme nationale d'urgences citoyennes composée de :
- Un backend Django REST Framework (6 endpoints sécurisés, 25 tests automatisés)
- Un dashboard web consulté par les autorités en temps réel
- Une application Flutter utilisée par les citoyens et les agents de terrain »

---

### Acte 2 — Le citoyen signale une urgence (2 min)

Étape A — Connexion et récupération du token :
```bash
curl -s -X POST http://127.0.0.1:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"citoyen1","password":"senalert2026"}' | python3 -m json.tool
```
Copiez la valeur du champ "access".

Étape B — Signalement (remplacez TOKEN) :
```bash
curl -s -X POST http://127.0.0.1:8000/api/incidents/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"type_incident":"incendie","description":"Départ de feu au marché de Pikine","latitude":14.7547,"longitude":-17.3939,"region":"dakar"}' \
  | python3 -m json.tool
```
Résultat attendu : `201 Created` avec l'incident et son identifiant.

---

### Acte 3 — Le dashboard reçoit l'alerte (2 min)

1. Connectez-vous sur le dashboard avec admin / senalert2026
2. Montrez les 4 cartes de statistiques (Total, En attente, Résolus, SOS)
3. L'incident apparaît dans le tableau ET sur la carte Leaflet (marqueur rouge sur Dakar)
4. Démontrez les filtres : région = Dakar, type = Incendie

Point à souligner : « Les statistiques proviennent de l'endpoint /api/dashboard/stats/ qui agrège les données en temps réel depuis PostgreSQL. »

---

### Acte 4 — L'agent traite l'incident (2 min)

Connexion agent :
```bash
curl -s -X POST http://127.0.0.1:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"agent1","password":"senalert2026"}' | python3 -m json.tool
```

Prise en charge (remplacez TOKEN_AGENT et ID) :
```bash
curl -s -X PATCH http://127.0.0.1:8000/api/incidents/ID/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN_AGENT" \
  -d '{"statut":"en_cours"}' | python3 -m json.tool
```

Résolution :
```bash
curl -s -X PATCH http://127.0.0.1:8000/api/incidents/ID/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN_AGENT" \
  -d '{"statut":"resolu"}' | python3 -m json.tool
```

Rechargez le dashboard : le badge passe Nouveau → En cours → Résolu.

---

### Acte 5 — Alerte SOS (1 min)
```bash
curl -s -X POST http://127.0.0.1:8000/api/alerts/sos/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN_CITOYEN" \
  -d '{"latitude":14.6928,"longitude":-17.4467}' | python3 -m json.tool
```
La carte SOS du dashboard s'incrémente.

---

### Acte 6 — Sécurité (1 min)
Un citoyen ne peut pas modifier l'incident d'un autre :
```bash
curl -s -X PATCH http://127.0.0.1:8000/api/incidents/1/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN_CITOYEN" \
  -d '{"statut":"resolu"}' | python3 -m json.tool
```
Résultat : 403 Forbidden — prouve la sécurité du système.

---

## RÉPONSES AUX QUESTIONS DU JURY

Q : Pourquoi Django REST Framework ?
R : Sérialisation automatique, tokens JWT natifs, permissions par objet. Idéal pour une API consommée par mobile et web.

Q : Comment est sécurisée l'API ?
R : JWT expirables + permission IsOwnerOrAdminOrReadOnly : seul le propriétaire ou un admin peut modifier un incident. Les agents peuvent changer le statut mais pas supprimer.

Q : Que se passe-t-il si le serveur est hors ligne ?
R : Le mobile affiche un message d'erreur explicite. Pas de mode hors ligne dans cette version — c'est une limite documentée du prototype.

Q : Comment fonctionnent les notifications push ?
R : Firebase Cloud Messaging (FCM). L'endpoint /api/alerts/sos/ déclenche une notification vers les agents via Firebase Admin SDK.

Q : Axes d'amélioration ?
R : Mode hors ligne (SQLite local + sync différée), WebSocket pour le dashboard, graphiques analytiques, déploiement sur serveur local sénégalais.

---

## COMMANDES DE SECOURS

Relancer le serveur :
```bash
cd ~/Documents/PFF/senalert/backend && /opt/miniconda3/bin/python3.13 manage.py runserver
```

Voir les incidents en base :
```bash
cd ~/Documents/PFF/senalert/backend
/opt/miniconda3/bin/python3.13 manage.py shell -c "
from incidents.models import Incident
for i in Incident.objects.all(): print(i.id, i.type_incident, i.statut, i.region)
"
```

Repartir de zéro :
```bash
cd ~/Documents/PFF/senalert/backend
rm db.sqlite3 && /opt/miniconda3/bin/python3.13 manage.py migrate
```
