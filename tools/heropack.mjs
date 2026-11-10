// The standard car (models/car-hero.json) drawn in fewer pieces: its fixed parts joined per material, so a phone draws
// it in about 50 draw calls instead of 108 (and as many again for its shadow). Nothing else changes: same geometry,
// same materials and textures (the .webp files stay as they are), the wheels and the steering wheel's turning parts kept
// apart under their own names (the game spins and steers them), Glass / License / Brakelight still found by material.
//   node heropack.mjs <car-hero.json in> <out dir>     (glTF-Transform 4.5.1, as for carpack.mjs; npm install in tools/)
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { join, prune, dedup, quantize } from '@gltf-transform/functions';
import fs from 'fs';
import path from 'path';

const [input, outDir] = process.argv.slice(2);
if (!input || !outDir) { console.error('usage: node heropack.mjs <car-hero.json> <out dir>'); process.exit(1); }
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const root = doc.getRoot(), scene = root.getDefaultScene() || root.listScenes()[0];
const prims = () => root.listMeshes().reduce((n, m) => n + m.listPrimitives().length, 0);
const tris = () => root.listMeshes().reduce((n, m) => n + m.listPrimitives().reduce((k, p) => k + (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3, 0), 0);
console.log('in:', prims(), 'primitives,', Math.round(tris()), 'triangles,', root.listMaterials().length, 'materials');

// the paint variants (pearl, graphite) are not used by the game: without them the parts can be joined
for (const e of root.listExtensionsUsed()) if (e.extensionName === 'KHR_materials_variants') e.dispose();

// kept apart: the four wheels (whole), the steering column's group and the steering handles (whole)
const top = scene.listChildren();
if (top.length !== 1) throw new Error('expected one top node, found ' + top.length);
const body = top[0];
const KEEP = /^(Wheel(Front|Rear)[LR]|InteriorSteeringCylinder|InteriorSteering(Wheel|Handle|Emblem).*)$/;
const kept = new Set();
const markKept = (n) => { kept.add(n); n.listChildren().forEach(markKept); };
body.listChildren().forEach((n) => { if (KEEP.test(n.getName())) markKept(n); });
console.log('kept apart:', body.listChildren().filter((n) => kept.has(n)).map((n) => n.getName()).join(', '));

// every other part with a mesh moves under one new node, its place baked into its own transform (relative to the body)
const inv = (m) => { // 4x4 column-major inverse (affine)
  const [a00, a01, a02, , a10, a11, a12, , a20, a21, a22, , a30, a31, a32] = m;
  const b01 = a22 * a11 - a12 * a21, b11 = -a22 * a10 + a12 * a20, b21 = a21 * a10 - a11 * a20;
  const det = a00 * b01 + a01 * b11 + a02 * b21, id = 1 / det;
  const r = [b01 * id, (-a22 * a01 + a02 * a21) * id, (a12 * a01 - a02 * a11) * id, 0,
    b11 * id, (a22 * a00 - a02 * a20) * id, (-a12 * a00 + a02 * a10) * id, 0,
    b21 * id, (-a21 * a00 + a01 * a20) * id, (a11 * a00 - a01 * a10) * id, 0, 0, 0, 0, 1];
  r[12] = -(a30 * r[0] + a31 * r[4] + a32 * r[8]); r[13] = -(a30 * r[1] + a31 * r[5] + a32 * r[9]); r[14] = -(a30 * r[2] + a31 * r[6] + a32 * r[10]);
  return r;
};
const mul = (a, b) => { const r = new Array(16).fill(0); for (let c = 0; c < 4; c++) for (let rr = 0; rr < 4; rr++) for (let k = 0; k < 4; k++) r[c * 4 + rr] += a[k * 4 + rr] * b[c * 4 + k]; return r; };
const bodyInv = inv(body.getWorldMatrix());
const moving = [];
const collect = (n) => { if (kept.has(n)) return; if (n.getMesh()) moving.push(n); n.listChildren().forEach(collect); };
body.listChildren().forEach(collect);
const fixed = doc.createNode('BodyFixed');
const locals = moving.map((n) => mul(bodyInv, n.getWorldMatrix()));   // (all worked out before anything moves)
moving.forEach((n, k) => {
  n.getParentNode().removeChild(n); fixed.addChild(n);
  n.setMatrix(locals[k]);
  n.setName(''); n.getMesh().setName('');                      // (unnamed, so that join may merge them)
});
for (const n of moving) for (const c of [...n.listChildren()]) n.removeChild(c);   // (their mesh children moved too)
body.addChild(fixed);
console.log('fixed parts moved:', moving.length);

await doc.transform(join({ keepNamed: true }), dedup(), prune(), quantize());
console.log('out:', prims(), 'primitives,', Math.round(tris()), 'triangles,', root.listMaterials().length, 'materials');

// write: the .json with its buffer inside as a data URI; the images keep their names (the existing .webp files)
fs.mkdirSync(outDir, { recursive: true });
const tmp = path.join(outDir, 'car-hero.tmp.gltf');
await io.write(tmp, doc);
const j = JSON.parse(fs.readFileSync(tmp, 'utf8'));
if (j.buffers.length !== 1) throw new Error('expected one buffer');
const binPath = path.join(outDir, j.buffers[0].uri);
j.buffers[0].uri = 'data:application/octet-stream;base64,' + fs.readFileSync(binPath).toString('base64');
fs.writeFileSync(path.join(outDir, 'car-hero.json'), JSON.stringify(j));
fs.unlinkSync(binPath); fs.unlinkSync(tmp);
console.log('images:', j.images.map((i) => i.uri).join(' '));
console.log('json', (fs.statSync(path.join(outDir, 'car-hero.json')).size / 1e6).toFixed(2), 'MB');
