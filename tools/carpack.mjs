// A Sketchfab car (scene.gltf + scene.bin + textures/) to the game's car format: models/car-<id>.json (glTF with its
// buffer inside as a data URI, quantised) and models/car-<id>-N.webp (textures as separate files: the artifact
// sandbox blocks fetch() of data: URLs, see JOURNAL section 7).
//   npm install            (once, in tools/: glTF-Transform 4.5.1, meshoptimizer, sharp)
//   node carpack.mjs <id> <scene.gltf> <out dir>
// What it does to a car, from CARS[id] below:
// - real size and place: scaled to its real length, nose toward +z, centred, tyres on y = 0
// - wheels: the four wheel groups renamed WheelFrontL / WheelFrontR / WheelRearL / WheelRearR from where they sit
//   (front = +z, left = +x), so the game can spin and steer them
// - materials: windows renamed 'Glass' (the game puts its own see-through glass), rear lamp lenses 'Brakelight'
//   (lit when braking), body paint glossed with a clear coat; cut-out textures drawn as cut-outs instead of blended
//   (no sorting trouble); transmission and specular dropped (three.js r128 draws neither)
// - lighter: identical data merged, parts merged per material and parent, welded, simplified a little, quantised
// - textures: shrunk (sizes per texture below) and turned into webp
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, EXTTextureWebP, KHRMaterialsClearcoat } from '@gltf-transform/extensions';
import { dedup, prune, flatten, join, weld, simplify, quantize, textureCompress, getBounds } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';
import fs from 'fs';
import path from 'path';

const CARS = {
  giulia: {
    length: 4.67, wheels: /^3DWheel (Front|Rear) [LR]$/,
    glass: /^uv1MAT_Glass_002$/, brake: /^red_glass$/, paint: /^uv1MAT_GiuliaGTAm_Base1$/,
    textures: [[/./, 1024]], simplify: 0.75,
    credit: { title: '2021 Alfa Romeo Giulia GTAm', author: 'Ddiaz Design', license: 'CC-BY-NC-SA-4.0', source: 'https://sketchfab.com/3d-models/2021-alfa-romeo-giulia-gtam-0809eafd171c497d82fa5d8735873f32' },
  },
  r34: {
    length: 4.6, wheels: /^W[1-4]$/,
    glass: /^windows$/, brake: /^red_glass$/, paint: /^CarPaint_N$/,
    textures: [[/Liv_Color/, 2048], [/A_Livery|Badges|interior_baseColor/, 1024], [/Engine|chassis|plastic|interior/, 512], [/./, 1024]], simplify: 0.75,
    credit: { title: "Eddie's Nissan Skyline R34 NFS Underground", author: 'Ddiaz Design', license: 'CC-BY-NC-SA-4.0', source: 'https://sketchfab.com/3d-models/eddies-nissan-skyline-r34-nfs-underground-9a6bc4ed690546a1bf02832764f1c888' },
  },
};

const [id, input, outDir] = process.argv.slice(2);
const C = CARS[id];
if (!C || !input || !outDir) { console.error('usage: node carpack.mjs <' + Object.keys(CARS).join('|') + '> <scene.gltf> <out dir>'); process.exit(1); }
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const root = doc.getRoot(), scene = root.getDefaultScene() || root.listScenes()[0];
const log = (...a) => console.log(id + ':', ...a);
const tris = () => root.listMeshes().reduce((n, m) => n + m.listPrimitives().reduce((k, p) => k + (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3, 0), 0);
log('in:', root.listMeshes().length, 'meshes,', Math.round(tris()), 'triangles,', root.listTextures().length, 'textures');

// ---- real size and place: one new root node over the whole car ----
const b = getBounds(scene), size = b.max.map((v, k) => v - b.min[k]);
if (size[2] < size[0]) throw new Error('the car is not lengthwise along z: ' + size);
const s = C.length / size[2], cx = (b.min[0] + b.max[0]) / 2, cz = (b.min[2] + b.max[2]) / 2;
const carRoot = doc.createNode('Car').setScale([s, s, s]).setTranslation([-cx * s, -b.min[1] * s, -cz * s]);
for (const n of scene.listChildren()) { scene.removeChild(n); carRoot.addChild(n); }
scene.addChild(carRoot);
log('size (m):', size.map((v) => +(v * s).toFixed(2)).join(' x '), '| scale', +s.toFixed(4));

// ---- wheels, named from where they sit (their parts are regrouped once the car is flat, below) ----
const wheels = root.listNodes().filter((n) => C.wheels.test(n.getName()));
if (wheels.length !== 4) throw new Error('expected 4 wheel groups, found ' + wheels.map((n) => n.getName()));
const wheelParts = new Map();                          // wheel name -> { its mesh nodes, its centre }
for (const n of wheels) {
  const wb = getBounds(n), centre = [0, 1, 2].map((k) => (wb.min[k] + wb.max[k]) / 2);
  const name = 'Wheel' + (centre[2] > 0 ? 'Front' : 'Rear') + (centre[0] > 0 ? 'L' : 'R');
  log('wheel', JSON.stringify(n.getName()), '->', name, 'at x', centre[0].toFixed(2), 'z', centre[2].toFixed(2), 'radius', ((wb.max[1] - wb.min[1]) / 2).toFixed(3));
  const parts = []; n.traverse((c) => { if (c.getMesh()) parts.push(c); });
  wheelParts.set(name, { parts, centre });
  n.setName(name + '_old');
}
if ([...wheelParts.keys()].sort().join() !== 'WheelFrontL,WheelFrontR,WheelRearL,WheelRearR') throw new Error('wheels do not make a car: ' + [...wheelParts.keys()]);

// ---- materials ----
const clearcoat = doc.createExtension(KHRMaterialsClearcoat);
for (const m of root.listMaterials()) {
  const n = m.getName() || '';
  if (C.glass.test(n)) { m.setName('Glass'); continue; }
  if (C.brake.test(n)) { m.setName('Brakelight'); continue; }
  if (C.paint.test(n)) {
    m.setName('Paint 1 ' + id).setMetallicFactor(0.45).setRoughnessFactor(0.32);
    m.setExtension('KHR_materials_clearcoat', clearcoat.createClearcoat().setClearcoatFactor(1).setClearcoatRoughnessFactor(0.05));
  }
  // blended parts that are not glass (badges, decals, grilles, cut-outs): drawn as cut-outs
  if (m.getAlphaMode() === 'BLEND' && !/glass/i.test(n) && m.getBaseColorTexture()) m.setAlphaMode('MASK').setAlphaCutoff(0.4);
}
for (const e of root.listExtensionsUsed()) if (['KHR_materials_transmission', 'KHR_materials_specular', 'KHR_materials_emissive_strength'].includes(e.extensionName)) e.dispose();

// ---- flat: every part straight under the scene (its place baked in), each wheel's parts under one node at the
// wheel's centre, so that parts can be merged per material and a wheel can still turn about its own axle ----
root.listSkins().forEach((k) => k.dispose());          // (an unused skeleton would keep its nodes from flattening)
await doc.transform(dedup(), prune(), flatten());
for (const [name, w] of wheelParts) {
  const wn = doc.createNode(name).setTranslation(w.centre); scene.addChild(wn);
  for (const p of w.parts) {
    const t = p.getTranslation(); scene.removeChild(p); wn.addChild(p);
    p.setTranslation([t[0] - w.centre[0], t[1] - w.centre[1], t[2] - w.centre[2]]);
  }
}
// ---- lighter ----
await doc.transform(
  prune(),
  join({ keepNamed: false }),            // parts merged per material among siblings: the body, and each wheel apart
  weld(),
  simplify({ simplifier: MeshoptSimplifier, ratio: C.simplify, error: 0.0004 }),
  prune(), quantize(),
);
// ---- textures: shrunk per name, then webp ----
doc.createExtension(EXTTextureWebP).setRequired(true);
for (const t of root.listTextures()) {                     // name each texture after its file, for the size rules
  if (!t.getName()) t.setName(path.basename(t.getURI() || '', path.extname(t.getURI() || '')));
}
const done = new Set();
for (const [re, px] of C.textures) {
  const pick = root.listTextures().filter((t) => !done.has(t) && re.test(t.getName()));
  pick.forEach((t) => done.add(t));
  if (!pick.length) continue;
  const names = new Set(pick.map((t) => t.getName()));
  await doc.transform(textureCompress({ encoder: sharp, targetFormat: 'webp', quality: 84, resize: [px, px], pattern: new RegExp('^(' + [...names].map((x) => x.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|') + ')$') }));
}
root.listTextures().forEach((t, i) => t.setURI(`car-${id}-${i}.webp`));
root.getAsset().generator = 'glTF-Transform v4.5.1';
root.getAsset().extras = Object.assign({}, C.credit, { modified: 'scaled to real size, wheels named, glass and lamps adapted, simplified, quantised, textures reduced to webp' });
log('out:', root.listMeshes().length, 'meshes,', Math.round(tris()), 'triangles,', root.listMaterials().length, 'materials,', root.listTextures().length, 'textures');

// ---- write: .gltf + .bin + .webp, then the .bin goes inside the JSON as a data URI ----
fs.mkdirSync(outDir, { recursive: true });
const tmp = path.join(outDir, `car-${id}.tmp.gltf`);
await io.write(tmp, doc);
const j = JSON.parse(fs.readFileSync(tmp, 'utf8'));
if (j.buffers.length !== 1) throw new Error('expected one buffer');
const binPath = path.join(outDir, j.buffers[0].uri);
j.buffers[0].uri = 'data:application/octet-stream;base64,' + fs.readFileSync(binPath).toString('base64');
fs.writeFileSync(path.join(outDir, `car-${id}.json`), JSON.stringify(j));
fs.unlinkSync(binPath); fs.unlinkSync(tmp);
const out = fs.readdirSync(outDir).filter((f) => f.startsWith(`car-${id}`));
log('files:', out.length, '| json', (fs.statSync(path.join(outDir, `car-${id}.json`)).size / 1e6).toFixed(2), 'MB | webp', (out.filter((f) => f.endsWith('.webp')).reduce((n, f) => n + fs.statSync(path.join(outDir, f)).size, 0) / 1e6).toFixed(2), 'MB');
