# Nouvelles voitures (dépôt des fichiers)

Reçu le 2026-11-06 : Alfa Romeo Giulia GTAm (P2) et Nissan Skyline R34 (P3), intégrées en V27.

Dépose ici les **deux nouvelles voitures** du parking (places P2 et P3), en fichier `.zip`.

## Quoi mettre dans le zip
- Le modèle 3D de chaque voiture : `.glb` de préférence, sinon `.gltf` (avec ses textures), `.fbx` ou `.obj` (avec ses textures).
- La licence et l'auteur de chaque modèle (par exemple le lien de la page Sketchfab). C'est obligatoire : le jeu affiche les crédits.
- Facultatif : un petit fichier texte avec le nom de chaque voiture et comment elle doit se conduire (plus rapide, plus d'adhérence, freins plus forts…).

## Comment l'envoyer sur GitHub
1. Ouvre le dépôt sur GitHub et choisis la branche `claude/zealous-hopper-j88yto`.
2. Ouvre le dossier `incoming/cars`.
3. **Add file → Upload files**, glisse le zip, puis **Commit changes**.
4. Dis à Claude : « les voitures sont dans incoming/cars ».

Taille : GitHub refuse les fichiers de plus de **25 Mo** envoyés par le site. Si le zip est plus gros, fais un zip par voiture. Au-delà de 100 Mo par fichier, GitHub refuse complètement : dis-le à Claude.

## Ensuite
Claude convertit les modèles (outils dans `tools/`), les place dans le parking (P2 et P3), mesure leurs performances avec la physique du jeu et ajoute les crédits. Le zip d'origine pourra ensuite être retiré du dépôt pour le garder léger, seulement avec ton accord (garde une copie ailleurs).

---

**English:** put a `.zip` with the two new cars here (3D model, preferably `.glb`, plus each model's licence and author). On GitHub: branch `claude/zealous-hopper-j88yto` → folder `incoming/cars` → *Add file → Upload files* → *Commit changes*. Files over 25 MB: one zip per car. Then tell Claude the cars are uploaded.
