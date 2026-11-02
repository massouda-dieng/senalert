"""Extrait les services de secours du Sénégal depuis un fichier OpenStreetMap (.osm.pbf).

Produit backend/core/data/services_osm.json, utilisé par « Services proches » quand les
serveurs Overpass sont indisponibles. Les données restent celles d'OpenStreetMap (ODbL) :
rien n'est ajouté ni inventé.

Mise à jour (une fois de temps en temps) :
    curl -L -o senegal.osm.pbf https://download.geofabrik.de/africa/senegal-and-gambia-latest.osm.pbf
    pip install osmium
    python scripts/extraire_services_osm.py senegal.osm.pbf
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import osmium

AMENITES = {'hospital', 'clinic', 'pharmacy', 'police', 'fire_station'}
ETIQUETTES = ('amenity', 'name', 'name:fr', 'phone', 'contact:phone', 'opening_hours', 'emergency',
              'addr:housenumber', 'addr:street', 'addr:city')
SORTIE = Path(__file__).resolve().parents[1] / 'backend' / 'core' / 'data' / 'services_osm.json'


class Extracteur(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.elements = []

    def _garder(self, type_, obj, lat, lon):
        tags = {k: obj.tags[k] for k in ETIQUETTES if k in obj.tags}
        if tags.get('name', '').startswith('#'):  # mot-dièse saisi par erreur à la place du nom
            del tags['name']
        self.elements.append({'type': type_, 'id': obj.id, 'lat': round(lat, 6), 'lon': round(lon, 6), 'tags': tags})

    def node(self, n):
        if n.tags.get('amenity') in AMENITES and n.location.valid():
            self._garder('node', n, n.location.lat, n.location.lon)

    def way(self, w):
        # Bâtiment dessiné comme une surface : sa position est le centre de ses points.
        if w.tags.get('amenity') not in AMENITES:
            return
        points = [(nd.lat, nd.lon) for nd in w.nodes if nd.location.valid()]
        if points:
            self._garder('way', w, sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points))


def main(fichier):
    ex = Extracteur()
    ex.apply_file(fichier, locations=True)
    SORTIE.write_text(json.dumps({
        'source': '© contributeurs OpenStreetMap (ODbL), extrait Geofabrik',
        'extrait_le': datetime.now(timezone.utc).date().isoformat(),
        'elements': ex.elements,
    }, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'{len(ex.elements)} établissements écrits dans {SORTIE}')


if __name__ == '__main__':
    main(sys.argv[1])
