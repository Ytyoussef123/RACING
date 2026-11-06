# JOURNAL DU PROJET : Corniche Rush

Règle : après chaque modification, ajouter une ligne datée dans la section du sujet (version + décision + raison). Pour travailler sur un sujet, lire sa section et celles listées dans « Liens ». Ne pas relire tout le fichier.

| Sujet | Liens |
|---|---|
| 1. Direction et joystick | 2, 4, 9 |
| 2. Voiture : physique, freins | 1, 3, 4 |
| 3. Route et virages de Casa | 2, 5, 8 |
| 4. Collisions et trafic | 2, 3 |
| 5. Graphismes et rendu | 3, 8 |
| 6. Cockpit, volant, mains | 1, 5 |
| 7. Modèles 3D et licences | 5, 6 |
| 8. Fluidité et performances | 3, 5 |
| 9. Écran, boutons, plein écran | 1 |
| 10. Tests et méthode | tous |
| 11. À faire | |

## 1. Direction et joystick
- Joystick flottant : la zone tactile est le bas gauche (46 % × 72 %), le stick apparaît sous le pouce. Réponse proportionnelle, zone morte 3 %.
- Sensibilité : **80 %** (V24). Braquage à fond à 1,3 rayon, courbe douce en fin de course. Cercle en pointillés = braquage à fond.
- Taille du stick et distance de braquage calculées depuis le **côté court de l'écran** (`joyFull = 0,22 × côté court`, 80 à 170 px), pas en pixels fixes : dans Chrome Android la page est affichée avec des pixels ~2× plus petits, et le braquage à fond arrivait à 7 mm (V24).
- Ressort critique exact sur `S.steer`. En mode analogique (`S.analog`), les réglages rapides **restent après le lâcher** : sinon la voiture glissait encore ~1 m à 200 km/h (corrigé V20). Ne pas revenir aux réglages clavier au lâcher.
- Un nouvel appui reprend toujours la main du stick, blur et visibilitychange le réinitialisent.
- Mesure : à 200 km/h, glissement après lâcher 26 cm à fond, 11 cm à mi-course.
- Historique : V16-V17 flèches ◀ ▶ puis pilule, V18 stick flottant, V19 90 %, V20 braquage plus loin, V24 80 % + tailles relatives.

## 2. Voiture : physique et freins
- Boîte auto 6 rapports, vitesse max ~236 km/h, nitro. Direction latérale : `latTarget = steer × min(6,8; 3,2 + 0,075 v) × grip`.
- Freins (V24) : décélération `12 + 0,0009 v²` m/s² (≈1,25 g en ville, ≈2 g à 250 km/h), montée en 1/14 s. 250→0 en 4,5 s sur 147 m. Rétrogradage anticipé en freinant fort avec coup de gaz, ABS qui vibre, plongée du nez.
- Joints de route espacés et doux à haute vitesse (V21).
- Le virage pousse la voiture vers l'extérieur : terme `-0,3 × courbure × v²` dans `latTarget`. À 200 km/h il faut ~30 % de stick dans les grands virages, ~45 % dans le serré.
- 2026-11-06, V26 : chaque voiture de la liste `CARS` a un `perf` {top, pull, lat, brake} qui multiplie les vitesses max par rapport (GEAR_TOP), les reprises (GEAR_PULL), l'adhérence latérale (`latTarget`) et les freins ; tout à 1 pour la voiture standard, donc conduite identique à V25. Raison : une physique propre à chaque voiture. Précision sur « ~236 km/h » : c'est la limite du 6e rapport / avec nitro ; mesuré sans nitro : 222 km/h. Stats de la fiche mesurées avec la physique du jeu par t48 (ligne droite, sans trafic) : standard « CONCEPT » = 222 km/h max sans nitro, 0-100 km/h en 5,5 s, freinage 100-0 en 28 m.
- 2026-11-06, V27 : multiplicateurs `perf` et stats mesurées par t48 (ligne droite) : Concept 1/1/1/1 → 222 km/h, 0-100 en 5,5 s, 100-0 en 28 m ; Giulia top 1,2, pull 1,12, lat 1,08, brake 1,2 → 247 km/h, 4,5 s, 25 m (la plus rapide, meilleurs freins et adhérence) ; R34 top 1, pull 1,45, lat 0,96, brake 1 → 238 km/h, 3,9 s, 28 m (la plus vive au départ, moins d'adhérence). Raison : chaque voiture a sa force. Taille de collision identique pour toutes (1,9 × 4,4 m).

## 3. Route et virages de Casa
- Le jeu tourne sur une route droite (x travers, z avance, voiture en z=0). Les virages sont une **déformation d'affichage** : le monde droit est courbé avant chaque image, trafic et collisions restent en repère droit.
- Trajet (7,5 km, boucle) : Av. des FAR, Casa Port, Bd des Almohades, La Sqala, mosquée Hassan II, El Hank, av. TanTan, Aïn Diab. 8 virages dans `ROUTE` (début, longueur, angle). Angles de la carte, resserrés pour être sentis à 200 km/h. Mer à droite (décor construit à gauche puis miroir `worldG.scale.x = -1`). Le soleil et le ciel tournent avec le cap.
- Noms de lieux annoncés avant les virages (toasts).
- **LEÇON V21-V23 : ne jamais courber la route dans un shader modifié (`onBeforeCompile`).** Le téléphone de l'utilisateur (Chrome Android) refusait le programme : écran vide, seuls le ciel et les aiguilles s'affichaient. Les émulateurs l'acceptaient.
- Solution actuelle (V25) : courbure calculée en JavaScript par image (`updateBend` points tous les 5 m, `bendForRender`) : bandes longues sommet par sommet (coupées tous les 6 m, mer et sol tous les 12 m, couture à 60 m de la route), objets déplacés et tournés puis remis en place, tirets et poteaux en `InstancedMesh`. Coût ≈0,3 ms/image.
- Le cockpit n'est jamais courbé.

## 4. Collisions et trafic
- Règle V25 : **seul le choc de l'avant de la voiture dans l'arrière d'une autre = accident (fin de partie)**. Choc de côté, accrochage d'un coin, ou voiture qui tape notre arrière : secousse, son, vibration, perte de vitesse, voitures écartées, la partie continue (`bump()`). Raison : l'utilisateur ne voit pas l'arrière.
- Distinction : chevauchement le long de la route plus petit que celui en travers = bout à bout.
- Trafic urbain : vitesses 60/70/80 km/h (camions 50-65). Peu de voitures au départ, plus dense tous les 2 km (`niveau = floor(dist/2000)`), écarts qui se resserrent. Ombres de contact sous chaque voiture.
- Frôlement : bonus, nitro, ralenti au-dessus de 130 km/h.

## 5. Graphismes et rendu
- Three.js r128, ciel peint une fois sur CPU (le ciel shader devenait noir sur certains téléphones), HD : bloom, flou de vitesse, FXAA ; SD : rendu direct.
- Palmiers : modèle importé de près, image (sprite) de loin, mipmaps qui conservent la couverture des feuilles.
- Ombres du monde recalculées **à chaque image** (V21) : un rafraîchissement 1 image sur 3 faisait sauter les ombres.
- Le mode SD sur téléphone : résolution 1,0, pas d'ombres dans le cockpit, rétroviseur 320×80 rafraîchi une image sur 2.
- 2026-11-06, V26 : parking dessiné dans une scène séparée (`G` dans le code), seule dessinée dans le menu (la route n'est ni dessinée ni courbée). Sol béton et lignes peintes, mur du fond peint (panneaux de places P1-P3, « CASA PORT », sortie « SORTIE → CORNICHE »), piliers rayés, un spot par place (celui de la voiture montrée monte, les autres baissent), une lumière principale dont les ombres ne sont recalculées que quand une voiture change, exposition 0,85 dans le parking. Caméra : vue trois-quarts avant, cadrée entre le titre et la fiche de la voiture, léger balancement ; un glissement déplace la rangée avec le doigt. Raison : demande de l'utilisateur (parking 3D), coût minimal.

## 6. Cockpit, volant, mains
- Intérieur importé (Gerhald XJ220), pilote importé (BELAZ), cockpit rendu dans une scène séparée avec profondeur effacée. Pilote centré derrière le volant, coudes naturels, poignets droits, gants gris foncé avec dos visibles.
- Sans visières ni toit dans la vue, montants coupés, rétroviseur en haut à droite.
- Le volant et les bras suivent le joystick instantanément.
- Pilote : os trouvés par `name.replace(/_\d+$/,'')`, IK 2 os, transfert de torsion de l'avant-bras, doigts fermés sur la jante, manches amincies via `bindMatrix.clone().invert()` (**pas** `bindMatrixInverse`).
- Repli procédural si les modèles ne chargent pas. Les sources sont dans `src/cockpit/p1..p6.js`.

## 7. Modèles 3D et licences
- `game/models/*.json + *.webp` : voiture héros, trafic, intérieur, pilote, palmier.
- **CSP de l'artifact : `fetch()` d'URL `data:` bloqué.** Les textures doivent être des fichiers .webp séparés, les buffers en data URI sont acceptés.
- Les `.glb` d'origine (≈28 Mo) ne sont pas dans ce dépôt. À conserver ailleurs. Outils de conversion : `tools/`.
- Crédits (affichés dans le menu) : Car Concept (Eric Chadwick, CC BY 4.0, d'après Unity Fan CC0), Car interior (Gerhald, CC BY 4.0), race driver (BELAZ, CC BY 4.0), Date Palm (evolveduk, CC BY 4.0). La statue « Race Car Driver » (tomkart) n'était **qu'une référence de posture**, jamais utilisée.
- 2026-11-06, V26 : dossier `incoming/cars/` (avec README) = endroit où l'utilisateur déposera le zip des 2 nouvelles voitures, pour les places P2 et P3. En attendant, ces places montrent des voitures sous housse (forme simple en tissu) et le bouton jouer affiche BIENTÔT (désactivé). Au chargement, la voiture standard sort de sa housse quand son modèle est chargé. `game/models/index.json` (liste d'exemples Khronos) et `game/models/pilot.json` (référence de posture, jamais utilisé) ne sont pas chargés par le jeu et ne sont pas publiés avec l'artifact.
- 2026-11-06, V27 : les 2 zips sont arrivés dans `incoming/cars/`. P2 = « GIULIA GTAm », d'après « 2021 Alfa Romeo Giulia GTAm » par Ddiaz Design ; P3 = « SKYLINE R34 », d'après « Eddie's Nissan Skyline R34 NFS Underground » par Ddiaz Design. Licence des deux : CC BY-NC-SA 4.0 (crédit obligatoire, pas d'usage commercial, versions modifiées sous la même licence). Crédits ajoutés dans l'écran « Règles ». Les noms internes des fichiers (« RewardRecycled », « TNR »…) laissent penser qu'ils viennent peut-être d'un jeu de course commercial : **garder Corniche Rush gratuit et non commercial.** Les zips (17 Mo) restent dans `incoming/cars/` jusqu'à l'accord de l'utilisateur pour les retirer.
- 2026-11-06, V27 : conversion par le nouveau `tools/carpack.mjs` (API glTF-Transform 4.5.1 ; `npm install` dans `tools/`, puis `node carpack.mjs <giulia|r34> <scene.gltf> <dossier de sortie>` ; réglages par voiture dans sa table CARS). Étapes : mise à la longueur réelle (4,67 / 4,6 m), nez vers +z, centrage, pneus sur y = 0 ; les 4 groupes de roues renommés WheelFrontL/FrontR/RearL/RearR d'après leur position (avant = +z, gauche = +x) ; voiture aplatie puis pièces de chaque roue regroupées sous un nœud au centre de la roue (les pièces fusionnent par matériau et les roues peuvent encore tourner) ; vitres renommées 'Glass', verres de feux arrière 'red_glass' renommés 'Brakelight' ; peinture avec vernis ; pièces texturées en transparence dessinées en découpe (MASK 0,4) ; extensions transmission/specular/emissive_strength retirées (three.js r128 ne les dessine pas) ; dedup, prune, flatten, join, weld, simplify 0,75 (erreur 0,0004), quantize ; textures réduites (Giulia 1024 ; R34 livrée 2048, décalques 1024, moteur/châssis/intérieur 512) puis webp qualité 84 ; buffer dans le JSON en data URI ; sortie `game/models/car-<id>.json` + `car-<id>-N.webp` ; `asset.extras` garde titre, auteur, licence, source. Résultats : Giulia 263 → 22 meshes, 95k → 75k triangles, 2,63 Mo + 0,49 Mo webp (27 fichiers) ; R34 110 → 44 meshes, 87k → 66k triangles, 2,75 Mo + 1,19 Mo webp (38 fichiers). L'ancienne chaîne des voitures (car-hero/car-traffic) n'a jamais été notée dans le dépôt ; `carpack.mjs` est maintenant la chaîne enregistrée.
- 2026-11-06, V27 : `carpack.mjs` retire les textures posées sur un 2e jeu d'UV (three.js r128 ne lit que le premier pour couleur, normale, métal/rugosité, lueur ; la lueur est coupée avec sa texture). Seul l'intérieur de la R34 était concerné (lueur du tableau de bord, qui apparaissait au mauvais endroit) : R34 = 37 textures au lieu de 38. La Giulia ressort identique à l'octet près (conversion reproductible).

## 8. Fluidité et performances
- Cause des saccades (V21) : ombres rafraîchies 1 image sur 3. Corrigé en les redessinant à chaque image, et en compensant : tirets et poteaux fusionnés en 2 objets.
- Objets dessinés par image : 805 (V20) → ≈480 (V25).
- Adaptation automatique de la résolution selon le temps d'image.
- Non mesuré sur le vrai téléphone : demander à l'utilisateur son ressenti.
- 2026-11-06, V27 : téléchargement de 7,6 Mo à environ 14,6 Mo (105 fichiers publiés) ; les 7 Mo des nouvelles voitures se chargent après le départ. Seule la voiture conduite est dessinée sur la route, et pas du tout en vue cockpit.

## 9. Écran, boutons, plein écran
- Paysage forcé : `#stage` tourné par CSS sur téléphone en portrait, détection par deviceorientation, bouton « retourner l'écran ».
- Bouton plein écran (V22) : menu + barre de jeu, touche F. Dans l'appli Claude il peut être bloqué (message affiché). Chrome Android : fonctionne.
- Boutons FREIN / GAZ / NOS (V25) : **ronds**, anneau translucide + disque (style eFootball), dimensionnés depuis le côté court de l'écran comme le stick.
- Règles : pas de pop-up, pas d'inscription.
- 2026-11-06, V26 : le jeu s'ouvre dans un parking couvert en 3D (Parking Casa Port, niveau -1), une place par voiture (3 places : P1, P2, P3). On passe d'une voiture à l'autre en glissant (ou flèches ‹ ›, points, touches ← →) ; JOUER part avec la voiture affichée. Choix mémorisé (localStorage `corniche-car`). Raison : demande de l'utilisateur (choisir la voiture dans un parking avant de jouer). Règles et crédits déplacés du menu vers un écran « Règles » (bouton en haut à droite du parking). Écrans pause et fin de partie : bouton « Parking » pour changer de voiture. HUD du jeu caché dans le parking. Sur téléphone à écran court, les stats de fin de partie passent en 3 colonnes pour tenir sans défilement.
- 2026-11-06, V26 : jeu publié en artifact Claude : https://claude.ai/artifact/8vXQWpYdzaMUAEekkbYdMt (fichiers publiés : la page + models/ sauf index.json et pilot.json, inutilisés). Pour une mise à jour, republier au même lien.
- 2026-11-06, V27 : les 2 nouvelles voitures se chargent l'une après l'autre quand le jeu est prêt (hors du % de chargement, elles ne retardent pas JOUER) ; chacune sort de sa housse une fois chargée ; pendant le chargement le bouton affiche « CHARGEMENT x % ». La voiture choisie est celle de la route (vue poursuite « Vue ») : roues qui tournent et braquent, feux de freinage allumés. En vue cockpit, l'intérieur commun sert pour toutes les voitures.

## 10. Tests et méthode
- Playwright + swiftshader. `python3 tests/mktest.py` fabrique `test4.html` avec des crochets (`__S`, `__input`, `__update`…) à partir de `index.html` (les chemins vers three.js y sont à adapter : il attend `dl/package/…`).
- Tests clés : t36 joystick (2 orientations + écran type Chrome), t37 réponse de direction, t43 freinage 250 km/h, t44 règles de choc, t38 captures des virages, t39 conduite en virage, t40 HD + noms de lieux, t41 plein écran, t26 clavier.
- Ne pas lancer plusieurs navigateurs en parallèle (délais).
- Avant publication : `node --check` du script principal.
- Piège connu : un commentaire `//` dans une instruction sur une seule ligne casse le script.
- 2026-11-06, V26 : nouveau t47 (parking : glisser vers la voiture sous housse = jeu refusé, flèches clavier, jouer la standard, pause → parking, fin de partie ; 4 écrans : téléphone paysage, bureau, fenêtre étroite, téléphone tenu droit) et t48 (stats de chaque voiture livrée, chiffres à copier dans `CARS[].stats`). `tests/mktest.py` expose aussi `__CARS`, `__useCar`, `__G`. t43 demande `test-v23.html`, fabriqué par `python3 tests/mktest.py versions/v23.html test-v23.html`.
- 2026-11-06, V26 : règle de travail (aussi dans `CLAUDE.md`) : lire/écrire le journal et le README, et lire du code pour le comprendre, passent par un sous-agent Sonnet en effort medium ; modifier du code = Opus 5.5 en effort max, qui relit les lignes exactes qu'il change. Raison : demande de l'utilisateur.
- 2026-11-06, V27 : t47 réécrit pour 3 voitures (attendre le chargement de toutes, glisser vers la Giulia, touches ← →, conduire la Giulia = seule sur la route + feux de freinage, pause → parking, conduire la R34 avec ses 4 roues, fin de partie, choix mémorisé ; 4 écrans). Nouveau `tests/iframe-nofs.html` pour t41 (cadre refusant le plein écran, `allow="fullscreen 'none'"`). t26 : seul `node t26.js desk` s'applique encore (ses parties téléphone cherchent le volant à l'écran #swheel retiré en V18). `.gitignore` ajouté (node_modules/).
- 2026-11-06, V27 : vérifié aussi : une voiture dont le modèle ne se télécharge pas garde sa housse et son bouton affiche « INDISPONIBLE » (désactivé).

## 11. À faire
- **Adversaire IA** (compte à rebours 3-2-1, régime moteur, course dans le trafic, position et distance). Estimé, **pas commencé : attendre l'accord de l'utilisateur.**
- **APK Android** (WebView plein écran paysage, hors connexion). L'utilisateur a demandé la faisabilité : réalisable, non construit.
- Vérifier sur téléphone : virages visibles (V25), fluidité, boutons ronds, ressenti des freins, parking (glisser, cadrage de la voiture).
- Demander à l'utilisateur s'il faut retirer les zips de `incoming/cars/` (17 Mo).
