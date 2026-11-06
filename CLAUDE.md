# Règles de travail pour Claude (Corniche Rush)

## Modèles et effort (demande de l'utilisateur, 2026-11-06)
- Lire ou écrire `JOURNAL.md` et `README.md` : confier le travail à un sous-agent **Sonnet**, effort **medium**.
- Lire du code pour le comprendre ou trouver où sont les choses : sous-agent **Sonnet**, effort **medium**, qui rend un résumé avec les numéros de lignes.
- Modifier le code : **Opus 5.5**, effort **max** (la session principale, ou un sous-agent Opus en effort max).
- Avant de modifier des lignes, relire soi-même ces lignes exactes : ne jamais modifier du code à partir d'un résumé seul.
- Publier le jeu en artifact oblige à avoir lu tout le fichier publié : dans ce cas, la session principale le lit elle-même.

## Rappels
- Avant toute modification : lire dans `JOURNAL.md` la section du sujet et celles de « Liens ». Après : une ligne datée dans la section (version + décision + raison).
- Chaque version publiée est copiée dans `versions/vN.html`.
- Tests : voir `JOURNAL.md`, section 10.
