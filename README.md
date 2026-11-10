# Corniche Rush

Jeu de conduite en vue cockpit sur la corniche de Casablanca (Casa Port → Aïn Diab). Three.js r128, interface en français, jouable sur téléphone en paysage.

- `game/index.html` : le jeu (version actuelle : V28 ; parking avec 3 voitures, deux modes au choix : COURSE (contre l'IA) et LIBRE (sans course, aux points)). `game/models/` : modèles 3D et textures utilisés au chargement.
- `JOURNAL.md` : mémoire du projet, découpée par sujet. **À lire avant toute modification, section concernée seulement.**
- `src/cockpit/` : sources du cockpit (p1 à p6), incluses dans `index.html`.
- `tools/` : conversion des modèles ; `tools/carpack.mjs` convertit une voiture Sketchfab au format du jeu. `tests/` : tests Playwright (voir JOURNAL, section Tests).
- `versions/` : copies de versions antérieures, pour revenir en arrière. `vN.html` est le jeu juste avant la version N+1 ; `v28.html` = actuelle.
- `incoming/cars/` : dossier où déposer le zip des nouvelles voitures (voir son README).
- `CLAUDE.md` : règles de travail pour Claude (modèles à utiliser).

Lancer : servir `game/` avec un serveur statique (`npx serve game`) et ouvrir `index.html`. Les modèles se chargent par `fetch`, il faut donc un serveur.
Jouer en ligne (artifact Claude, privé, partage depuis le menu Partager de la page) : https://claude.ai/artifact/8vXQWpYdzaMUAEekkbYdMt
Les gros fichiers sources `.glb` ne sont pas dans ce dépôt (voir JOURNAL, Modèles 3D).
