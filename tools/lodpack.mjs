// The traffic car as it is drawn far away on a phone: models/car-traffic-far.json, the same car (same parts, same
// material names, same place and size) in a few hundred triangles instead of ten thousand. On a phone's screen a
// traffic car 30 m ahead is about 25 pixels wide, and most of the traffic is much farther: its ten thousand triangles
// were each far smaller than a pixel, and the phone still had to work through every one of them, in every car.
// The file carries no textures: the game gives its parts the materials of the full model, by name.
//   node lodpack.mjs <models dir>        (glTF-Transform 4.5.1 and meshoptimizer, as for carpack.mjs; npm install in tools/)
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dequantize, weld, prune, quantize } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2];
if (!dir) { console.error('usage: node lodpack.mjs <models dir>'); process.exit(1); }
// share of its triangles each part keeps (by material name): wheels are small and round, the body carries the shape
const KEEP = [[/^(Rim|Tire|Disc|Brake$|Hardware|Mechanical)/, 0.04], [/^Paint/, 0.17], [/^Glass$/, 0.32]], KEEP_ELSE = 0.3;
const ERROR = 1;                                           // (no early stop: each part goes down to its share)

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(path.join(dir, 'car-traffic.json')), root = doc.getRoot();
const tris = () => root.listMeshes().reduce((n, m) => n + m.listPrimitives().reduce((k, p) => k + p.getIndices().getCount() / 3, 0), 0);
await MeshoptSimplifier.ready;
await doc.transform(dequantize(), weld());
const before = tris();
for (const mesh of root.listMeshes()) for (const prim of mesh.listPrimitives()) {
  const name = prim.getMaterial() ? prim.getMaterial().getName() : '', keep = (KEEP.find(([re]) => re.test(name)) || [0, KEEP_ELSE])[1];
  const idx = new Uint32Array(prim.getIndices().getArray()), pos = new Float32Array(prim.getAttribute('POSITION').getArray());
  const target = Math.max(12, Math.round(idx.length / 3 * keep)) * 3;
  if (target >= idx.length) continue;
  // (the plain simplifier keeps every seam and edge of these parts and stops at 60 %: the "sloppy" one merges nearby
  // points whatever the seams, which is what a car a few pixels wide needs)
  const [out] = MeshoptSimplifier.simplifySloppy(idx, pos, 3, null, target, ERROR);
  if (out.length < 9) continue;                            // (a part that would vanish stays as it is)
  prim.setIndices(doc.createAccessor().setType('SCALAR').setArray(out).setBuffer(root.listBuffers()[0]));
  console.log(String(idx.length / 3).padStart(6), '->', String(out.length / 3).padStart(5), name || '(no name)');
}
// no textures in this file (the game uses the full model's materials), the points no longer used dropped
for (const m of root.listMaterials()) {
  m.setBaseColorTexture(null).setNormalTexture(null).setOcclusionTexture(null).setEmissiveTexture(null).setMetallicRoughnessTexture(null);
  for (const e of m.listExtensions()) for (const k of ['ClearcoatTexture', 'ClearcoatRoughnessTexture', 'ClearcoatNormalTexture', 'TransmissionTexture']) if (typeof e['set' + k] === 'function') e['set' + k](null);
}
await doc.transform(weld(), prune({ keepAttributes: true }), quantize());
console.log('triangles', Math.round(before), '->', Math.round(tris()));

const tmp = path.join(dir, 'car-traffic-far.tmp.gltf');
await io.write(tmp, doc);
const j = JSON.parse(fs.readFileSync(tmp, 'utf8'));
if (j.buffers.length !== 1) throw new Error('expected one buffer');
// (any texture still named, in an extension for instance, goes too: the file must not make the game fetch an image)
const strip = (o) => { if (o && typeof o === 'object') for (const k of Object.keys(o)) { if (/Texture$/.test(k)) delete o[k]; else strip(o[k]); } };
strip(j.materials); delete j.images; delete j.textures; delete j.samplers;
for (const k of ['extensionsUsed', 'extensionsRequired']) if (j[k]) { j[k] = j[k].filter((e) => !/texture/i.test(e)); if (!j[k].length) delete j[k]; }
const bin = path.join(dir, j.buffers[0].uri);
j.buffers[0].uri = 'data:application/octet-stream;base64,' + fs.readFileSync(bin).toString('base64');
fs.writeFileSync(path.join(dir, 'car-traffic-far.json'), JSON.stringify(j));
fs.unlinkSync(bin); fs.unlinkSync(tmp);
console.log('car-traffic-far.json', (fs.statSync(path.join(dir, 'car-traffic-far.json')).size / 1e3).toFixed(0), 'kB');
