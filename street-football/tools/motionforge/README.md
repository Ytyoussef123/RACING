# MotionForge Studio (animation editor)

A single-file web tool for editing player animations, with and without the ball, on a phone or a PC.
It is not part of the Godot project: the `.gdignore` file keeps Godot from importing this folder.

- `motionforge.html`: the editor. Open it in Chrome (Android or desktop). It needs internet access once to load Three.js 0.160.0 from jsDelivr.
- `build_embedded.py`: builds a copy with a character model already inside, so it opens ready to use:
  `python3 build_embedded.py Running.fbx MotionForge_Studio.html`

**No character model is committed here.** Mixamo characters are licensed for use in projects, not for redistribution as raw files. Import your own model in the app, or build an embedded copy locally.

## What it does

- **Character**: import an FBX (Mixamo), GLB or glTF file. The model is scaled to metres and remembered by the browser (IndexedDB), so you don't re-import it on every launch.
- **Movements (clips)**: one project holds many movements. You can import more animations from other FBX/GLB files (bone names are matched automatically). You can also create a movement from the current pose, duplicate, rename or delete one, make a **left ↔ right mirror**, change its duration or speed, trim it, cut a segment out, or copy a segment into a new movement.
- **Body editing**: tap a joint in the 3D view (or use the quick buttons Bassin, Bras D, Pied G…), then rotate or move it with the handle or the sliders. Keys are written automatically by default. On dense motion-capture clips a change is blended smoothly over the neighbouring frames (the "Portée" setting), so one edit doesn't cause a one-frame glitch. Copy and paste a pose, or paste it mirrored.
- **Ball** (per movement: a movement has a ball track or it doesn't):
  - **automatic ball physics**: when you turn the ball on for a movement, it reacts to the player's toes, feet, shins, thighs, chest and head (gravity, bounces, rolling friction). Modes: *Conduite* (each foot touch sends the ball just ahead of the player, so it stays with them while running), *Libre* (pure physics, for kicks and juggling), or *Auto* (conduite if the player travels, otherwise libre). You can set the start point (where the foot strikes, in front of the player, or where the ball is now), the touch strength, the bounce and whether hands count (goalkeeper);
  - imported GLB/FBX files that already contain an animated ball (node named ball / ballon / soccer…, for example V5 or V6 exports) keep their ball motion;
  - drag the ball or use the sliders, and set ball keys;
  - **stick the ball** to a foot, hand, both hands, chest, head, knee or hips: "Au sol" (dribble: follows the foot along the ground and rolls) or "Collé" (follows the bone in 3D);
  - **pass / shot / lob**: between the two segment marks, with a height, a number of bounces and an optional curve;
  - automatic **rolling rotation** computed from the ball's movement;
  - the ball's path is drawn in the scene.
- **Text generator**: simple procedural movements from a sentence (run, walk, jump, crouch, turn, lean, fall, slide tackle, **kick / shot, pass, dribble**). Football actions also create and animate the ball. It is a starting point to refine, not a trained AI.
- **Undo / redo** (60 steps), **autosave** in the browser, **project file** (.json) to move between phone and PC (opens V5 files too: the imported clip and the ball keys).
- **GLB export** for Godot: the active movement or all of them, one animation each, with an optional `Ballon` node animated alongside the player.

## Phone layout

The 3D view stays at the top, with the transport bar and the timeline under it, and the tabs Mouvements / Corps / Ballon / Vue below. File actions are in **☰ Fichier**. Tap a joint to select it; turn on **Multi** to select several. The camera follows the player.

## PC shortcuts

Space play · ←/→ frame · , / . previous/next key · K key · Delete delete key · E rotate · W move · B ball · F frame camera · I / O segment start/end · Shift+click multi-select · Ctrl+Z / Ctrl+Y undo/redo · Ctrl+S save.

## Axes

Characters face +Z, their left is +X, and Y is up. One metre = one grid square on the pitch.
