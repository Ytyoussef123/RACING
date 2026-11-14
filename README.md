# Corniche Rush

Jeu de conduite en vue cockpit sur la corniche de Casablanca (Casa Port → Aïn Diab). Three.js r128, interface en français, jouable sur téléphone en paysage.

- `game/index.html` : le jeu (version actuelle : V25). `game/models/` : modèles 3D et textures utilisés au chargement.
- `JOURNAL.md` : mémoire du projet, découpée par sujet. **À lire avant toute modification, section concernée seulement.**
- `src/cockpit/` : sources du cockpit (p1 à p6), incluses dans `index.html`.
- `tools/` : conversion des modèles. `tests/` : tests Playwright (voir JOURNAL, section Tests).
- `versions/` : copies de versions antérieures, pour revenir en arrière. `vN.html` est le jeu juste avant la version N+1 ; `v25.html` = actuelle.

Lancer : servir `game/` avec un serveur statique (`npx serve game`) et ouvrir `index.html`. Les modèles se chargent par `fetch`, il faut donc un serveur.
Les gros fichiers sources `.glb` ne sont pas dans ce dépôt (voir JOURNAL, Modèles 3D).

---
Ce dépôt contient aussi un second jeu, **Street Football 5v5** (Godot, Android) : voir `street-football/README.md`.
