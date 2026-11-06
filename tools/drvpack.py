# race driver (BELAZ, CC BY 4.0) -> models/driver.json: skeleton + jacket + hands only, buffer and textures embedded
import json, base64, io, os, sys
import numpy as np
from PIL import Image
src = 'drv-in/x/'
J = json.load(open(src + 'scene.gltf')); BIN = open(src + 'scene.bin', 'rb').read()
KEEP = {5: 'hands', 8: 'jacket'}                          # mesh index -> role
out_bin = bytearray(); views = []; accs = []
def add_acc(i, drop=False):
    a = J['accessors'][i]; bv = J['bufferViews'][a['bufferView']]
    comp = {5126: 4, 5125: 4, 5123: 2, 5121: 1}[a['componentType']]; n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    stride = bv.get('byteStride') or comp * n; off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    raw = b''.join(BIN[off + k * stride: off + k * stride + comp * n] for k in range(a['count'])) if stride != comp * n else BIN[off: off + a['count'] * comp * n]
    while len(out_bin) % 4: out_bin.append(0)
    views.append({'buffer': 0, 'byteOffset': len(out_bin), 'byteLength': len(raw)}); out_bin.extend(raw)
    na = {k: v for k, v in a.items() if k not in ('bufferView', 'byteOffset')}; na['bufferView'] = len(views) - 1
    accs.append(na); return len(accs) - 1
meshes = []; mesh_map = {}
mats_used = {}
for mi, role in KEEP.items():
    m = J['meshes'][mi]; prims = []
    for p in m['primitives']:
        attrs = {k: add_acc(v) for k, v in p['attributes'].items() if k in ('POSITION', 'NORMAL', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0')}
        mat = p['material']; mats_used.setdefault(mat, len(mats_used))
        prims.append({'attributes': attrs, 'indices': add_acc(p['indices']), 'material': mats_used[mat], 'mode': p.get('mode', 4)})
    mesh_map[mi] = len(meshes); meshes.append({'name': role, 'primitives': prims})
# images -> webp data URIs (jacket colour 1024 -> 512 is plenty from the driver's seat)
images = []; textures = []; tex_map = {}
def add_tex(ti, size):
    if ti in tex_map: return tex_map[ti]
    uri = J['images'][J['textures'][ti]['source']]['uri']
    im = Image.open(src + uri).convert('RGB')
    if im.width > size: im = im.resize((size, size), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, 'WEBP', quality=86, method=6)
    fn = f'driver-{len(images)}.webp'; open('models/' + fn, 'wb').write(buf.getvalue())
    images.append({'uri': fn, 'name': os.path.basename(uri)})
    textures.append({'source': len(images) - 1}); tex_map[ti] = len(textures) - 1
    print('texture', uri, im.size, len(buf.getvalue()), 'bytes')
    return tex_map[ti]
materials = [None] * len(mats_used)
for old, new in mats_used.items():
    m = J['materials'][old]; sg = m.get('extensions', {}).get('KHR_materials_pbrSpecularGlossiness', {})
    pbr = {'metallicFactor': 0.0, 'roughnessFactor': 0.75}
    if 'diffuseTexture' in sg: pbr['baseColorTexture'] = {'index': add_tex(sg['diffuseTexture']['index'], 512)}
    if 'diffuseFactor' in sg: pbr['baseColorFactor'] = sg['diffuseFactor']
    nm = {'name': m.get('name'), 'pbrMetallicRoughness': pbr}
    if 'normalTexture' in m: nm['normalTexture'] = {'index': add_tex(m['normalTexture']['index'], 512)}
    materials[new] = nm
# nodes: keep the hierarchy, point the two mesh nodes at the new meshes, drop the others
nodes = []
for i, n in enumerate(J['nodes']):
    nn = {k: v for k, v in n.items() if k not in ('mesh', 'skin')}
    if 'mesh' in n and n['mesh'] in mesh_map: nn['mesh'] = mesh_map[n['mesh']]; nn['skin'] = 0
    nodes.append(nn)
skin = dict(J['skins'][0]); skin['inverseBindMatrices'] = add_acc(J['skins'][0]['inverseBindMatrices'])
out = {'asset': {'version': '2.0', 'extras': {'title': 'race driver', 'author': 'BELAZ', 'license': 'CC-BY-4.0', 'source': 'https://sketchfab.com/3d-models/race-driver-e4e97df9865d466c8359fbb23e757308', 'modified': 'only jacket and hands kept, textures resized'}},
       'scene': 0, 'scenes': J['scenes'], 'nodes': nodes, 'meshes': meshes, 'materials': materials, 'textures': textures, 'images': images,
       'skins': [skin], 'accessors': accs, 'bufferViews': views,
       'buffers': [{'byteLength': len(out_bin), 'uri': 'data:application/octet-stream;base64,' + base64.b64encode(bytes(out_bin)).decode()}]}
json.dump(out, open('models/driver.json', 'w'), separators=(',', ':'))
print('buffer', len(out_bin), 'file', os.path.getsize('models/driver.json'))
