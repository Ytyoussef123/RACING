# XJ220 interior (Gerhald, CC BY 4.0) -> game car frame, material groups, anchors. Output: glb-in/prep.json
import json, sys
import numpy as np
d = np.load('glb-in/geo.npz'); part = np.load('glb-in/tricomp.npy')
SH, WH = 'XJ220_3_default_0', 'weel_default_0'
P, N, I = d[SH + '__P'], d[SH + '__N'], d[SH + '__I']
PW, NW, IW = d[WH + '__P'], d[WH + '__N'], d[WH + '__I']
S = 0.36
AX = np.array([0.9063, 0.4226, 0.0]); AX /= np.linalg.norm(AX)
UPW = np.array([-0.4226, 0.9063, 0.0])
cW = np.array([-1.2981, 1.2822, 0.9318]) + AX * -0.014          # centre of the rim tube
WC = np.array([-0.37, 0.835, -0.28])                              # where the game wants the wheel centre
def toCar(p): q = (p - cW) * S; return np.c_[-q[:, 2], q[:, 1], q[:, 0]] + WC
def dirCar(n): return np.c_[-n[:, 2], n[:, 1], n[:, 0]]

G = {}
def put(k, ids):
    for i in ids: G[i] = k
put('seat', [185, 186, 190, 191, 192, 193, 198, 199, 194, 195, 196, 197])
put('visor', [159, 165, 167, 169])
put('mirrorBody', [152, 157])
put('black', list(range(0, 18)) + [19, 21] + list(range(29, 40)) + [41, 42, 47, 57, 64, 187, 188, 200, 168, 150, 151, 141, 142, 153, 154, 135, 136, 40])
put('pedal', [18] + list(range(22, 29)))
put('metal', [140, 144, 175, 176, 177, 179, 180, 181, 182, 183])
put('alu', [145])
put('console', [163, 162, 166, 170, 171, 172, 173, 178])
put('carpet', [20, 56, 147])
put('door', [146, 164, 184, 189, 174])
put('grille', [98, 119])
put('gauge', [87, 88, 89])

tri = I; pc = P[tri].mean(1); nc = N[tri].mean(1); nc /= np.linalg.norm(nc, axis=1, keepdims=True) + 1e-9
grp = []
for t in range(len(tri)):
    k = part[t]
    if k == 133:
        x, y, z = pc[t]; ny = nc[t][1]
        if y < 0.3 and ny > 0.6: g = 'carpet'
        elif y > 1.95: g = 'trim'
        elif ny > 0.5 and y > 1.3 and x < -1.75: g = 'dashtop'
        elif abs(z) > 1.8 and y < 1.6: g = 'door'
        else: g = 'shell'
    elif k == 160:
        g = 'mirrorBody'
    else:
        g = G.get(k, 'switch')
    grp.append(g)
grp = np.array(grp, dtype='<U16')
# mirror glass: the big flat face of part 160 that looks at the driver (local triangles 122-145)
m160 = np.where(part == 160)[0]
tri160 = P[I[m160]]; fn = np.cross(tri160[:, 1] - tri160[:, 0], tri160[:, 2] - tri160[:, 0]); fn /= np.linalg.norm(fn, axis=1, keepdims=True)
fn *= np.sign((fn * N[I[m160]].mean(1)).sum(1))[:, None]
gn = np.array([0.975, -0.043, 0.216]); gn /= np.linalg.norm(gn)
glass = np.array([m160[k] for k in range(122, 146) if fn[k] @ gn > 0.999])
grp[glass] = 'mirrorGlass'
print('mirror glass tris', len(glass))
out = {'scale': S, 'credit': 'Car interior by Gerhald (sketchfab.com/Gerhald), CC BY 4.0, modified', 'groups': {}}
Pc, Nc = toCar(P), dirCar(N)
for g in sorted(set(grp)):
    t = np.where(grp == g)[0]; used, ix = np.unique(I[t].ravel(), return_inverse=True)
    out['groups'][g] = {'pos': Pc[used].round(5).tolist(), 'nor': Nc[used].round(4).tolist(), 'idx': ix.tolist()}
    print(g, 'tris', len(t), 'verts', len(used))
# wheel in its own frame: origin at the rim centre, +z toward the driver, +y up along the wheel plane
zw = dirCar(AX[None])[0]; yw = dirCar(UPW[None])[0]; xw = np.cross(yw, zw)
R = np.stack([xw, yw, zw])                                         # rows
Wc = toCar(PW) - WC; Wl = Wc @ R.T; Wn = dirCar(NW) @ R.T
rr = np.hypot(Wl[:, 0], Wl[:, 1])
# per-vertex split: rim (leather) and the spokes/hub
wt = IW; rt = rr[wt].mean(1)
for g, sel in [('wheelRim', rt > 0.152), ('wheelHub', rt <= 0.152)]:
    t = np.where(sel)[0]; used, ix = np.unique(wt[t].ravel(), return_inverse=True)
    out['groups'][g] = {'pos': Wl[used].round(5).tolist(), 'nor': Wn[used].round(4).tolist(), 'idx': ix.tolist(), 'wheel': True}
    print(g, 'tris', len(t))
out['wheel'] = {'centre': WC.tolist(), 'tilt': float(-np.arcsin(AX[1])), 'R': 0.4855 * S, 'ra': 0.05 * S, 'rz': 0.0367 * S}
print('wheel', out['wheel'], 'rim radial range', rr[rr > 0.12].min().round(4), rr.max().round(4), 'axial', Wl[:, 2].min().round(4), Wl[:, 2].max().round(4))

def plane(ids, toward=np.array([1.0, 0, 0])):
    t = np.where(np.isin(part, ids))[0]; v = np.unique(I[t].ravel()); pp = toCar(P[v]); c = pp.mean(0); X = pp - c
    w, V = np.linalg.eigh(X.T @ X); n = V[:, 0]; tw = dirCar(toward[None])[0]
    if n @ tw < 0: n = -n
    up = np.array([0, 1.0, 0]) - n * n[1]; up /= np.linalg.norm(up)
    side = np.cross(up, n); ext = [float(np.ptp(X @ side)), float(np.ptp(X @ up))]
    return {'c': c.round(5).tolist(), 'n': n.round(5).tolist(), 'up': up.round(5).tolist(), 'size': ext}
anc = {'cluster': plane([64]), 'dials': []}
for k, r in [(155, 0.065), (156, 0.065), (137, 0.065), (138, 0.065), (89, 0.05), (87, 0.05), (88, 0.05)]:
    t = np.where(part == k)[0]; v = np.unique(I[t].ravel()); c = toCar(P[v]).mean(0); n = dirCar(N[v].mean(0)[None])[0]; n /= np.linalg.norm(n)
    anc['dials'].append({'id': int(k), 'c': c.round(5).tolist(), 'n': n.round(4).tolist(), 'r': r * S})
g = np.where(grp == 'mirrorGlass')[0]; v = np.unique(I[g].ravel()); pp = toCar(P[v]); c = pp.mean(0)
n = dirCar(N[v].mean(0)[None])[0]; n /= np.linalg.norm(n); up = np.array([0, 1.0, 0]) - n * n[1]; up /= np.linalg.norm(up); side = np.cross(up, n)
w_, h_ = float(np.ptp((pp - c) @ side)), float(np.ptp((pp - c) @ up))
anc['mirror'] = {'c': c.round(5).tolist(), 'n': n.round(4).tolist(), 'up': up.round(4).tolist(), 'w': w_, 'h': h_}
gg = out['groups']['mirrorGlass']; q = np.array(gg['pos']) - c
gg['uv'] = np.c_[(q @ side) / w_ + 0.5, (q @ up) / h_ + 0.5].round(4).tolist()
out['anchors'] = anc
print(json.dumps(anc)[:1500])
# whole-cabin bounds for the roof occluder used by the AO bake
allc = toCar(P); out['bounds'] = [allc.min(0).round(4).tolist(), allc.max(0).round(4).tolist()]
print('bounds', out['bounds'])
json.dump(out, open('glb-in/prep.json', 'w'))
