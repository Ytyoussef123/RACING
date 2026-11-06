# date palm (evolveduk, CC BY 4.0) -> models/palm.json: same nodes, no tangents, small webp textures
import json, base64, io, os
import numpy as np
from PIL import Image
src = 'palm-in/x/'
J = json.load(open(src + 'scene.gltf')); BIN = open(src + 'scene.bin', 'rb').read()
out_bin = bytearray(); views = []; accs = []
def add_acc(i):
    a = J['accessors'][i]; bv = J['bufferViews'][a['bufferView']]
    comp = {5126: 4, 5125: 4, 5123: 2, 5121: 1}[a['componentType']]; n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    stride = bv.get('byteStride') or comp * n; off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    raw = b''.join(BIN[off + k * stride: off + k * stride + comp * n] for k in range(a['count'])) if stride != comp * n else BIN[off: off + a['count'] * comp * n]
    while len(out_bin) % 4: out_bin.append(0)
    views.append({'buffer': 0, 'byteOffset': len(out_bin), 'byteLength': len(raw)}); out_bin.extend(raw)
    na = {k: v for k, v in a.items() if k not in ('bufferView', 'byteOffset')}; na['bufferView'] = len(views) - 1
    accs.append(na); return len(accs) - 1
images, textures = [], []
def add_img(path, size, alpha=False):
    im = Image.open(src + path).convert('RGBA' if alpha else 'RGB')
    w, h = im.size; k = min(1.0, size / max(w, h)); im = im.resize((max(8, int(w * k)), max(8, int(h * k))), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, 'WEBP', quality=84, method=6)
    fn = f'palm-{len(images)}.webp'; open('models/' + fn, 'wb').write(buf.getvalue())
    images.append({'uri': fn}); textures.append({'source': len(images) - 1})
    print(path, im.size, len(buf.getvalue()), 'bytes'); return len(textures) - 1
uri = lambda ti: J['images'][J['textures'][ti]['source']]['uri']
materials = []
for m in J['materials']:
    pbr = m['pbrMetallicRoughness']; name = m['name']; frond = m.get('alphaMode') == 'MASK'
    nm = {'name': name, 'pbrMetallicRoughness': {'baseColorTexture': {'index': add_img(uri(pbr['baseColorTexture']['index']), 512, alpha=frond)}, 'metallicFactor': 0.0, 'roughnessFactor': 0.85}}
    if name in ('Tree_0Mat', 'Tree_2Mat') and 'normalTexture' in m: nm['normalTexture'] = {'index': add_img(uri(m['normalTexture']['index']), 256 if name == 'Tree_2Mat' else 512)}
    if frond: nm['alphaMode'] = 'MASK'; nm['alphaCutoff'] = m.get('alphaCutoff', 0.5)
    if frond or m.get('doubleSided'): nm['doubleSided'] = True
    materials.append(nm)
meshes = []
for m in J['meshes']:
    prims = []
    for p in m['primitives']:
        attrs = {k: add_acc(v) for k, v in p['attributes'].items() if k in ('POSITION', 'NORMAL', 'TEXCOORD_0')}
        prims.append({'attributes': attrs, 'indices': add_acc(p['indices']), 'material': p['material'], 'mode': p.get('mode', 4)})
    meshes.append({'name': m['name'], 'primitives': prims})
out = {'asset': {'version': '2.0', 'extras': {'title': 'Date Palm', 'author': 'evolveduk', 'license': 'CC-BY-4.0', 'source': 'https://sketchfab.com/3d-models/date-palm-11acf710e6c149daa8d6fb8cdc5d087f', 'modified': 'textures resized, roughness maps and tangents removed'}},
       'scene': 0, 'scenes': J['scenes'], 'nodes': J['nodes'], 'meshes': meshes, 'materials': materials, 'textures': textures, 'images': images,
       'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': len(out_bin), 'uri': 'data:application/octet-stream;base64,' + base64.b64encode(bytes(out_bin)).decode()}]}
json.dump(out, open('models/palm.json', 'w'), separators=(',', ':'))
print('buffer', len(out_bin), 'file', os.path.getsize('models/palm.json'))
