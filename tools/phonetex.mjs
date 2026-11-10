// Phone copies of the models' textures: game/models/m/<same name>.webp. A phone draws the cars a few hundred pixels
// wide, so the big textures are reduced: at most 512 px, but 1024 for a car's paint, livery and badges (their colour
// map), and the glass maps tiny (the game puts its own glass in their place). Small textures are copied as they are.
// The game loads these on a phone instead of the full ones (models/ -> models/m/): about a third of the graphics memory.
//   node phonetex.mjs <models dir>        (sharp, as for carpack.mjs; npm install in tools/)
import sharp from 'sharp';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2];
if (!dir) { console.error('usage: node phonetex.mjs <models dir>'); process.exit(1); }
const out = path.join(dir, 'm');
fs.mkdirSync(out, { recursive: true });

// what each image is used for, from the models that use textures: [material name, slot]
const uses = new Map();
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.json'))) {
  const j = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
  if (!j.images || !j.textures || !j.materials) continue;
  const src = (t) => { const x = j.textures[t.index]; return x.source !== undefined ? x.source : (x.extensions && x.extensions.EXT_texture_webp || {}).source; };
  for (const m of j.materials) {
    const pbr = m.pbrMetallicRoughness || {};
    for (const [slot, t] of [['base', pbr.baseColorTexture], ['mr', pbr.metallicRoughnessTexture], ['norm', m.normalTexture], ['emis', m.emissiveTexture], ['occ', m.occlusionTexture]]) {
      if (!t) continue;
      const uri = (j.images[src(t)] || {}).uri; if (!uri) continue;
      if (!uses.has(uri)) uses.set(uri, []);
      uses.get(uri).push([m.name || '', slot]);
    }
  }
}
let before = 0, after = 0;
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.webp')).sort()) {
  const u = uses.get(f) || [], meta = await sharp(path.join(dir, f)).metadata(), side = Math.max(meta.width, meta.height);
  const glassOnly = u.length > 0 && u.every(([n]) => /^glass$/i.test(n));
  const paint = u.some(([n, slot]) => slot === 'base' && /liv|livery|badge|paint/i.test(n));
  const cap = glassOnly ? 16 : paint ? 1024 : 512;
  const mem = (w, h) => w * h * 4 * 1.33;
  before += mem(meta.width, meta.height);
  if (side <= cap) { fs.copyFileSync(path.join(dir, f), path.join(out, f)); after += mem(meta.width, meta.height); continue; }
  const k = cap / side, w = Math.max(1, Math.round(meta.width * k)), h = Math.max(1, Math.round(meta.height * k));
  await sharp(path.join(dir, f)).resize(w, h, { kernel: 'lanczos3' }).webp({ quality: 88, alphaQuality: 100 }).toFile(path.join(out, f));
  after += mem(w, h);
  console.log(f, `${meta.width}x${meta.height} -> ${w}x${h}`, u.map(([n, s]) => n + ':' + s).slice(0, 3).join(', ') || '(unused)');
}
console.log('graphics memory if all used:', (before / 1e6).toFixed(0), 'MB ->', (after / 1e6).toFixed(0), 'MB');
