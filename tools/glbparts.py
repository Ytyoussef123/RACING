# parse the interior GLB, bake node transforms (glTF Y-up world, like three.js), split into connected parts
import json, struct, sys
import numpy as np
f = open(sys.argv[1], 'rb').read()
off = 12; ch = []
while off < len(f):
    cl, ct = struct.unpack('<I4s', f[off:off + 8]); ch.append(f[off + 8:off + 8 + cl]); off += 8 + cl
J = json.loads(ch[0]); BIN = ch[1]
def acc(i):
    a = J['accessors'][i]; bv = J['bufferViews'][a['bufferView']]
    o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]; dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a['componentType']]
    stride = bv.get('byteStride') or n * np.dtype(dt).itemsize
    isz = np.dtype(dt).itemsize
    if stride == n * isz: return np.frombuffer(BIN, dtype=dt, count=a['count'] * n, offset=o).reshape(a['count'], n).copy()
    raw = np.frombuffer(BIN, dtype=np.uint8, count=stride * (a['count'] - 1) + n * isz, offset=o)
    return np.array([np.frombuffer(raw[k * stride:k * stride + n * isz].tobytes(), dtype=dt) for k in range(a['count'])])
def nm(i):
    n = J['nodes'][i]
    return np.array(n['matrix'], dtype=np.float64).reshape(4, 4).T if 'matrix' in n else np.eye(4)
parent = {}
for i, n in enumerate(J['nodes']):
    for c in n.get('children', []): parent[c] = i
def world(i):
    m = nm(i)
    while i in parent: i = parent[i]; m = nm(i) @ m
    return m
out = {}
for ni, n in enumerate(J['nodes']):
    if 'mesh' not in n: continue
    pr = J['meshes'][n['mesh']]['primitives'][0]
    P = acc(pr['attributes']['POSITION']).astype(np.float64); N = acc(pr['attributes']['NORMAL']).astype(np.float64); UV = acc(pr['attributes']['TEXCOORD_0']); I = acc(pr['indices']).reshape(-1, 3)
    M = world(ni); P = (np.c_[P, np.ones(len(P))] @ M.T)[:, :3]; Nn = N @ np.linalg.inv(M[:3, :3]).T; Nn /= np.linalg.norm(Nn, axis=1, keepdims=True)
    out[n['name']] = dict(P=P, N=Nn, UV=UV, I=I)
    print(n['name'], 'verts', len(P), 'tris', len(I), 'bbox', P.min(0).round(3), P.max(0).round(3))
np.savez(sys.argv[2], **{k + '__' + a: v[a] for k, v in out.items() for a in v})
# connected parts of the interior: weld by position first
d = out['XJ220_3_default_0']; P, I = d['P'], d['I']
q = np.round(P / 1e-4).astype(np.int64); _, weld = np.unique(q, axis=0, return_inverse=True); weld = weld.ravel()
par = np.arange(weld.max() + 1)
def find(x):
    while par[x] != x: par[x] = par[par[x]]; x = par[x]
    return x
for a, b, c in weld[I]:
    ra, rb, rc = find(a), find(b), find(c)
    par[rb] = ra; par[find(rc)] = ra
root = np.array([find(x) for x in range(len(par))])
triComp = root[weld[I[:, 0]]]
comps, inv, cnt = np.unique(triComp, return_inverse=True, return_counts=True)
print('parts', len(comps))
order = np.argsort(-cnt)
rows = []
for k in order:
    t = np.where(inv == k)[0]; v = np.unique(I[t].ravel()); pp = P[v]
    rows.append((int(k), int(cnt[k]), pp.min(0).round(2).tolist(), pp.max(0).round(2).tolist()))
for r in rows[:60]: print(r)
np.save(sys.argv[3], inv)
