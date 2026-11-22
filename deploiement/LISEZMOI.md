# Application mobile en ligne

`mobile-web/` est la version web compilée de l'application Flutter (`mobile/`). Le serveur en ligne la sert à l'adresse `/mobile/`, et elle s'adresse alors toute seule à l'API du même site. Sur iPhone, ouvrez cette adresse dans Safari, puis **Partager → Sur l'écran d'accueil**.

Après une modification de `mobile/`, il faut recompiler cette copie et la recopier ici :

    cd mobile && flutter build web --release --base-href /mobile/
    rsync -a --delete build/web/ ../deploiement/mobile-web/

Dans `mobile-web/manifest.json` et `index.html`, gardez le nom « SenAlert ».
