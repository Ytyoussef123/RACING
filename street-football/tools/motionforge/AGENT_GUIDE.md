# MotionForge Studio: guide for an agent working on it

This file explains the app to a developer or AI agent who has to change it. For the user-facing feature list, see `README.md` in this folder.

## 1. What it is

MotionForge Studio is a **single-file web app** (`motionforge.html`, about 2,800 lines) for creating and editing **football player animations, with and without the ball**. The same file works on an Android phone and on a PC (Chrome).

It belongs to the **Street Football 5v5** project (Godot 4.7.2, Android) in `street-football/`, but it is **not part of the Godot game**:
- the folder has a `.gdignore`, so Godot never imports it;
- its output reaches the game as **GLB files** (one animation per movement, optional animated `Ballon` node).

The owner speaks French and tests on a phone. **All visible UI text is in French**, so keep new UI text in French. Code comments are in English.

It has two modes, switched at the top of the page:
- **✏️ Mouvement**: edit one movement (one animation clip) of one character, plus that movement's ball track.
- **👥 Scène**: several copies of the character on a pitch (J1, J2…) doing passes, receptions and plain movements in sequence, with one shared ball.

## 2. Files

| File | Role |
|---|---|
| `motionforge.html` | The whole app: HTML, CSS, one `<script type="module">`. No build step. |
| `build_embedded.py` | `python3 build_embedded.py <model.fbx> <out.html>` makes a copy with a character embedded as base64 (replaces the `<!--MF_EMBED-->` marker with `window.MF_EMBEDDED_MODEL = {name, b64}`). |
| `README.md` | User-facing features (English). |
| `AGENT_GUIDE.md` | This file. |
| `.gdignore` | Keeps Godot out of this folder. |

**Never commit a character model.** The user's character is a Mixamo FBX (license: use in projects, no redistribution of raw files). The embedded copy is built locally and given to the user directly. Rule 7 of `street-football/CLAUDE.md`: every committed asset must be free/original and listed in the README.

## 3. Dependencies and runtime

- **Three.js 0.160.0**, loaded through an import map from `cdn.jsdelivr.net` (needs internet on first load):
  `three`, `FBXLoader`, `GLTFLoader`, `OrbitControls`, `TransformControls`, `GLTFExporter`, `SkeletonUtils`.
  Pin the exact version. TransformControls in r160 is added directly to the scene (`scene.add(gizmo)`).
- No framework, no bundler. Plain DOM + one module script.
- **Storage**: IndexedDB database `motionforge`, store `kv`. Key `character` holds `{name, data: ArrayBuffer}` (the last imported model). Key `project` holds the autosaved project JSON. `localStorage` only keeps small preferences (`mf-tab`, `mf-autokey`, `mf-smartfix`). Every storage call is wrapped, because on Android a file opened from Downloads may have no working storage.
- Debug and test handle: `window.MF` exposes the state and the main functions (see the end of the script).

## 4. Units and axes (important)

- **Metres.** Mixamo FBX files are in centimetres (about 180 units tall). `installCharacter` scales the root by 0.01 when the model is taller than 3 units. The skeleton's *local* values (hips position track) stay in centimetres, under that scaled root.
- **Characters face +Z, their left is +X, Y is up.** The pitch is 40 × 24 m, centred on the origin, with 1 grid square = 1 m.
- `FPS = 30` is the editing frame rate (Mixamo exports at 30 fps). Times are snapped with `snapT`. Two times closer than `EPS = 1/120` s are "the same key".
- Measured on the Mixamo rig: rotating a thigh (`UpLeg`) by **+X moves the foot forward**; knee flexion is **−X** on `Leg`; **+X on the spine leans forward**; **+Y turns the body to its left**.
- **Mirror left ↔ right**: swap `Left`/`Right` in bone names, then quaternion `(x, y, z, w) → (x, −y, −z, w)` and position `(x, y, z) → (−x, y, z)`. This was verified exactly on the Mixamo rig (world positions mirror to 0.000).
- **FBXLoader nests two bones with the same name** (one per skinned mesh). The **outer one, found first, is the one animations drive**: `installCharacter` keeps only the first bone of each name. When a GLB exported by this app is re-imported, the inner duplicates come back with suffixes (`mixamorigHips_1`) and zero offset; they are skipped as aliases.
- FBXLoader and GLTFLoader **sanitize node names** (`mixamorig:Hips` becomes `mixamorigHips`). Track names use those sanitized names. `norm()` compares names loosely (lower case, `mixamorig\d*:` prefix removed, non-alphanumerics removed). It is used to retarget clips from other files.

## 5. Data model

### Global state `S`
```
S = {
  model, modelName, bones[], boneByName: Map, rest: Map(name -> {q,p,s}), hips,
  clips: [entry], active: index, time, playing,
  sel: Set<bone>, primary: bone, ballSel: bool, multi: bool,
  inT, outT,                 // segment marks [ ] on the timeline
  clipboard, dirty, ballRadius (0.11), undo[], redo[],
  mode: 'edit' | 'scene'
}
```

### A movement ("entry", shown to the user as "mouvement")
```
{
  name, duration,
  tracks: THREE.KeyframeTrack[]      // "<boneName>.quaternion" | "<boneName>.position"
  ball: null | { keys: [{t, p:[x,y,z], q:[x,y,z,w]}], sim: null | {mode} }
  base:  null | { [trackName]: KeyframeTrack }   // original curve before the first retouch
  ukeys: null | { [trackName]: [times] }         // times where the user set keys
  _bind, _times                                  // caches, rebuilt on demand
}
```
- `ball === null` means the movement has no ball. `ball.sim` is set when the keys come from the physics simulation. Dragging the ball then re-runs the simulation from the drop point.
- **Tracks are immutable.** Every edit builds new `KeyframeTrack` objects (`makeTrack`), and `base` / `ukeys` / ball key arrays are replaced, never mutated. This is what makes undo cheap: a snapshot only keeps references. **Keep this invariant.** If you mutate a track or an array in place, undo silently breaks.

### Scene data `SC.data` (saved inside the project)
```
{ players: [{x, z}],                       // start spots (root = hips ground position)
  actions: [                               // ordered: ball possession goes pass -> receive -> pass…
    {type:'pass', player, clip, target:{player}|{point:[x,z]}, speed (m/s), height (m, 0 = ground), delay, kickPct|null},
    {type:'receive', player, clip, runClip ('' = slide), runSpeed, control:'stop'|'left'|'right'|'front'|'behind', ctrlDist, ctrlPct|null},
    {type:'play', player, clip, delay, facing:'ball'|'keep'|'north'|'south'}
  ] }
```
`clip` and `runClip` are **movement names** from `S.clips`, and must be movements the user already loaded. The scene never generates movements.

### Project file (`.json`, version 6)
`serializeProject()` → `{app, version:6, fps, character, active, ballRadius, clips:[{name, duration, tracks:[{n,t,v}], base:[{n,t,v}]|null, ukeys, ball}], scene}`.
`loadProjectData()` also reads **V5** files (the user's older app): it recovers only the imported clip and the ball keys. V5 manual pose keys used per-session uuids and cannot be recovered.

## 6. Code map (inside the module script, in this order)

| Section | Main functions | Notes |
|---|---|---|
| Constants and helpers | `$`, `log`, `toast`, `idb`, `V3(x,y,z)`, `Q()`, `snapT`, `norm`, `smooth` | `V3` takes arguments. A version without arguments once broke the generator. |
| Scene | renderer, camera, `orbit` (OrbitControls), pitch, `gizmo` (TransformControls), joint markers, `ballMesh`, ball path line, ball shadow ring | |
| Character import | `sniffFormat` (by content: FBX/GLB/glTF/JSON), `parseModelBuffer`, `extractBall`, `installCharacter`, `clipToEntry`, `entriesFromClips`, `importAnimationFiles` | `extractBall` samples a ball node (named ball / ballon / soccer…) from imported files into `BALL_KEYS`, then removes it from the character. |
| Bones | `findBone([normalized names])`, `mirrorName`, `pickable`, `QUICK` (bone shortcut buttons), `selectBone`, `selectBall`, `updateGizmo`, `updateStatus` | |
| Evaluation | `bindEntry`, `restPose`, `applyPose(entry, t)`, `ballAt(entry, t)`, `applyBall`, `seek(t)` | **No AnimationMixer** in edit mode: the app uses its own interpolants, which is deterministic and lets it edit tracks freely. `seek` routes to `sceneSeek` in Scène mode. |
| Undo / autosave | `snapshot`, `restore`, `pushUndo`, `undo`, `redo`, `mutate(fn)`, `afterProjectChange`, `scheduleSave`, serialize / load | **Every change to project data goes through `mutate(fn)`** (or `pushUndo()` + change + `afterProjectChange()`). If `fn` returns `false`, the change is cancelled. |
| Writing keys | `falloffFrames`, `noteUserKey`, `writeKey`, `keyBones`, `smartCorrect`, `deleteKeys`, `onEdited` | See section 7. |
| Gizmo and picking | `dragging-changed` / `objectChange` handlers, ball drag (`BD`), `pick` | See section 8. |
| Body panel | `syncBoneUI`, rotation sliders (local Euler XYZ), position sliders (metres offset from rest) | |
| Ball editing | `keyBall`, `syncBallUI`, `updateBallPath`, `segment()`, `attachBall`, `flightBall`, `rollBall` | |
| Ball physics | `SIM`, `bodyColliders`, `autoBallStart`, `frontOfPlayer`, `simulateBall` | See section 9. |
| Clip operations | `newClipFromPose`, `cloneEntry`, `mirrorEntry`, `retime(e, fn, newDur, extra)` | `retime` drives speed, trim, cut segment and extract. It clears `base` / `ukeys`. |
| Procedural generator | `generate(text)` | Parses French and English keywords into rotations about the **character's axes**, converted to local rotations with the parent's base world orientation. It is rig-agnostic. Kick, pass and dribble also create ball keys. |
| Export / save | `exportGLB(all, withBall)`, `saveProject` | Exports the live model (temporarily re-parented into a group, rest pose) plus a ball node named `Ballon`. |
| Timeline | `renderTimeline` (canvas), `renderSceneTimeline`, `tlSeekFromEvent` | Lanes: "Tout", "⚽ Ballon", then the selected bones. In Scène mode: one lane per player plus the ball. |
| UI wiring | tabs, file menu, transport, panels, keyboard shortcuts | |
| SCÈNE | see section 10 | |
| Main loop / boot | `loop`, `boot` | `boot` reloads the remembered character (or the embedded one), then the autosaved project. |

## 7. Key editing rules

- `writeKey(e, trackName, t, value)` puts a key and **spreads the change over neighbouring frames** with a cosine falloff. The "Portée" setting decides how far: **Auto** = ±6 frames on dense mocap tracks (density ≥ 15 keys/s), a single key on sparse hand-made tracks. Without this, one edit on a Mixamo clip (a key on every frame) would be a one-frame glitch.
- `noteUserKey` remembers the **original track** (`e.base`) at the first retouch of a channel, and the user's key times (`e.ukeys`).
- `smartCorrect(e, {names, around, range, maxGap})`: between two consecutive user keys, each in-between frame becomes `original(t) ∘ blend(deltaA, deltaB, smooth(u))` (slerp for quaternions, lerp for positions). The user's retouches then blend smoothly while the mocap detail is kept. It runs automatically after `keyBones` (keys up to 2 s apart) when the "Correction douce" checkbox is on, and from the "Corriger les images entre mes clés" button.
- **Auto-key** (on by default): releasing the gizmo or a slider calls `onEdited()`, which writes keys. When it is off, the edit stays "dirty" until ◆ Clé is pressed. Seeking discards a dirty edit, with a toast.

## 8. Touch / pointer handling (the most fragile part)

Listener order on the canvas matters. Capture-phase listeners on the canvas run before OrbitControls and TransformControls (which listen in the bubble phase), and `stopImmediatePropagation()` keeps them from also reacting.
1. **Scene player drag** (capture, Scène mode only): pressing near a player selects and drags him on the ground plane.
2. **Ball drag** (capture, edit mode): pressing on or near the ball (screen-space radius, generous on touch) drags it. "Sol" mode moves it on a horizontal plane, "Hauteur" mode moves it up and down. There are no axis arrows for the ball (the user asked for that).
3. `pointerdown` capture records the press position and resets `gizmoDragged` / `gizmoChanged`.
4. On `pointerup`, **a tap (under 9 px, under 650 ms) always selects**, unless the gizmo actually changed something (`gizmoChanged`). This fixed a real phone bug: the selected joint's rotation rings cover most of the body, and taps used to hit the rings, so the selection never changed and empty keys were written.
5. `pick()`: the ball first, then the nearest joint **on screen** (34 px on touch), then a mesh raycast followed by the nearest joint to the hit point. Finger bones and `_End` bones are excluded unless "Inclure les doigts" is on.

- Gizmo size is 1.05 on touch and 0.85 with a mouse.
- On phones, file inputs have **no `accept` filter**: Android does not know the `.fbx` type and greys those files out. The type is sniffed from the file content instead (`sniffFormat`).
- The camera **follows the player** (orbit target and camera shifted by the hips' movement), because Mixamo clips have root motion. It aims at about 62 % of hip height (`bodyCenter`), so the feet and the ball are not hidden under the phone's bottom buttons.

## 9. Ball tools

- `attachBall`: bakes ball keys from a body part over the segment (or from now to the end). "Au sol" follows on the ground and rolls; "Collé" follows the bone in 3D.
- `flightBall`: pass, shot or lob between the two segment marks, with height, bounces (restitution 0.5) and curve.
- `rollBall(e, t0, t1)`: rolling-without-slipping rotation from horizontal displacement (axis = up × displacement, angle = distance / radius).
- `simulateBall(e, {mode, start, power, bounce, hands, t0})`: fixed step of 1/120 s; gravity, ground bounce 0.55, rolling deceleration 0.9 m/s², air drag. The colliders are spheres along bones (toe, foot, shin, thigh, chest, hips, head, optional hands).
  - **Mode `dribble`**: a leg touch sets the ball's speed to about 1.25 × the player's speed, along his running direction, steered back toward his line. In tests the ball stays 0.45 to 1 m ahead of the runner.
  - **Mode `free`**: impulse along the contact normal, blended toward the foot's direction when the foot moves faster than 3 m/s.
  - **Mode `auto`**: `dribble` when the hips travel more than 1.2 m/s on average.
  - **Start `auto`**: put the ball where a toe moves fastest near the ground, which is usually the kick.
- Turning the ball on for a movement (`selectBall` when `e.ball` is null) runs the simulation automatically.

## 10. Scène mode

- **Instances**: `makeInstance` makes a `SkeletonUtils.clone(S.model)` per player, with tinted material clones (`TEAM_COLORS`), a ground ring and a "J1" sprite label. Bones are **renamed `J<n>_<name>`** so exported names are unique. `inst.boneByName` keeps the **original** names for posing. The main `S.model` is hidden in Scène mode; it serves as a **probe** to measure clips (it sits at the origin with identity rotation, so world equals clip-local).
- **Analysis (cached per entry in `SC.cache`)**:
  - `footStrike(e, lo, hi)`: the moment a toe moves fastest within 0.3 m of the ground. That moment is treated as the kick or control touch. It returns `{t, toe (local), dir (local horizontal)}`.
  - `strikeAt(e, t)`: the same, at a time the user set by hand (`kickPct` / `ctrlPct`).
  - `hips0`, `hipsEnd`: local root positions. `clipSpeed`: root-motion speed, used to scale the run cycle's playback.
- **`planScene()`** walks the actions in order and produces `{players:[{segs}], ballKeys, duration, warn[], marks[]}`.
  - **Pass**: iterate the yaw so that the kick direction points at the target; place the ball in front of the toe at the kick; the ball leaves at `start + k.t`. On the ground the ball travels with rolling deceleration (if too slow to arrive, the speed is raised and a warning is added); a lob is a parabola at constant horizontal speed.
  - **Receive**: the receiver faces the incoming ball; the placement is solved so his toe at the control moment `c.t` is at the arrival point; the clip starts at `arrival − c.t`; a run segment from his current root to that start is inserted before it (warning if he would need more than 8.5 m/s). Then the ball goes where the control sends it.
  - **Play**: the clip played from the player's current root, facing the ball or another chosen direction.
  - Players without actions stand facing the ball.
  - Player position is tracked as the **root** (hips ground position). A segment's group origin is `root − R(yaw)·hipsLocal`, which keeps root motion continuous between segments.
- **Evaluation**: `evalPlayer(i, t)` finds the segment, poses with `poseInst` (run clips use `strip` = hips x/z frozen, and the group moves instead), and crossfades from the previous segment. **The crossfade never blends the hips' ground position and ends before the touch** (`blend = min(0.18, 0.6 × touch time)`). Blending the root once moved the foot up to 1.5 m off the ball.
- **Accuracy check used in the tests**: at every kick and control mark, the distance from the closest toe or foot bone to the ball centre is 0.08 to 0.24 m (ball radius 0.11 m).
- `exportSceneGLB()` bakes all players (group TRS + bone quaternions + hips position) and the ball at 30 fps into one clip, `Scene`.

## 11. How to test (headless, no phone needed)

The container used for this work had **no access to jsDelivr**, so the tests install `three@0.160.0` locally with npm and serve it through Playwright routing:

```js
const { chromium, devices } = require('playwright');
const ctx = await browser.newContext({ ...devices['Pixel 7'] });   // or { viewport: {width:1366, height:820} }
await ctx.route('https://cdn.jsdelivr.net/npm/three@0.160.0/**', r => {
  const rel = r.request().url().split('three@0.160.0/')[1];
  r.fulfill({ path: `${DEPS}/node_modules/three/${rel}`, contentType: 'application/javascript' });
});
await page.goto('file://' + EMBEDDED_HTML);   // built with build_embedded.py
await page.waitForFunction(() => window.MF && MF.S.model);
```

- Drive the app through `window.MF` (for example `MF.generate('frappe du pied droit')`, `MF.setAppMode('scene')`, `MF.addPass()`) or through real clicks.
- For **finger drags**, use CDP `Input.dispatchTouchEvent` (touchStart / touchMove / touchEnd). `page.touchscreen.tap` only taps.
- Checks used so far: falloff shape and undo; mirror exactness; kick contact (toe at ground level at contact); dribble gap; GLB export (parse the JSON chunk: animation names, channel counts, `Ballon` node); project round trip; reload restores from IndexedDB; phone layout has no horizontal scroll; tap-select; ball drag; scene touch accuracy; smart correction curve.
- Also look at screenshots, both desktop and Pixel 7. Several real bugs were only visible there: the phone grid being too wide, the ball hidden under buttons, the scene camera framing.

## 12. Conventions and pitfalls

- **UI text in French**, comments in English. Keep everything in the one HTML file: the user opens it directly on the phone.
- Keep **tracks and key arrays immutable** (section 5) and route data changes through `mutate` / `pushUndo`.
- After changing clips, call `afterProjectChange()` (it clears caches and re-plans the scene) and then `seek(S.time)`.
- In Scène mode, `seek`, `dur`, `togglePlay`, `jumpKey`, the timeline and the keyboard handler all branch on `S.mode`. Check that branch when touching any of them.
- `[hidden]` is forced to `display:none !important`, because buttons have their own `display` style.
- Phone layout (≤ 760 px wide): flex column (viewport ≈ 41 dvh, transport + 84 px timeline, then the tabbed panel). Every grid or flex child needs `min-width: 0`, or the page gets wider than the screen.
- The user's workflow: import Mixamo FBX files with **☰ Fichier → 📂 Ouvrir** (it asks: add the animations, or use the file as the character), edit, then **Exporter GLB** for Godot. Moving between phone and PC is done with the project `.json`.
- Git: this tool lives in `street-football/`; never touch the other game (Corniche Rush). Update `street-football/JOURNAL.md` after each feature, as the project rules require.

## 13. Known limits / ideas not done

- The text generator makes procedural, robotic motion; it is only a starting point.
- Scène actions are pass / receive / play only (no shot on goal, dribble or tackle action yet), with one ball and no opponents' reactions.
- Smart correction only knows keys made since it was added (older keys have no stored original curve).
- No in-app retargeting between different skeleton proportions (only bone names are matched).
- GLB files are large (≈ 8–9 MB) because the character mesh and textures are included in every export.
