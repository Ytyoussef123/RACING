import json, struct, sys
f = open(sys.argv[1], 'rb').read()
magic, ver, length = struct.unpack('<4sII', f[:12])
print('magic', magic, 'version', ver, 'length', length, 'file', len(f))
off = 12; chunks = []
while off < len(f):
    cl, ct = struct.unpack('<I4s', f[off:off + 8]); chunks.append((ct, f[off + 8:off + 8 + cl])); off += 8 + cl
j = json.loads(chunks[0][1])
print('chunks', [(c[0], len(c[1])) for c in chunks])
print('asset', json.dumps(j.get('asset'), ensure_ascii=False)[:1500])
for k in ['extensionsUsed', 'extensionsRequired']: print(k, j.get(k))
for k in ['scenes', 'nodes', 'meshes', 'materials', 'textures', 'images', 'samplers', 'accessors', 'bufferViews', 'animations', 'skins', 'cameras']:
    print(k, len(j.get(k, [])))
json.dump(j, open(sys.argv[2], 'w'), indent=1)
