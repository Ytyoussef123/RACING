# prep.json + ao.json -> models/interior.json (quantised, base64)
import json, base64
import numpy as np
prep = json.load(open('glb-in/prep.json')); ao = json.load(open('glb-in/ao.json'))
b64 = lambda a: base64.b64encode(a.tobytes()).decode()
out = {k: prep[k] for k in ['scale', 'credit', 'wheel', 'anchors', 'bounds']}
out['v'] = 1; out['groups'] = {}
for g, G in prep['groups'].items():
    p = np.array(G['pos'], dtype=np.float64); n = np.array(G['nor']); ix = np.array(G['idx'], dtype=np.uint16)
    lo = p.min(0); sz = np.maximum(p.max(0) - lo, 1e-6)
    qp = np.round((p - lo) / sz * 65535 - 32768).astype(np.int16)
    qn = np.round(np.clip(n, -1, 1) * 127).astype(np.int8)
    loc = np.array(ao[g]['loc']) / 255; glob = np.array(ao[g]['glob']) / 255
    a = np.clip(np.round(255 * loc ** 1.2 * (0.3 + 0.7 * np.sqrt(glob))), 0, 255).astype(np.uint8)
    e = {'n': len(p), 'q': lo.round(6).tolist() + sz.round(6).tolist(), 'pos': b64(qp), 'nor': b64(qn), 'ao': b64(a), 'idx': b64(ix)}
    if 'uv' in G: e['uv'] = b64(np.array(G['uv'], dtype=np.float32))
    if G.get('wheel'): e['wheel'] = True
    out['groups'][g] = e
json.dump(out, open('models/interior.json', 'w'), separators=(',', ':'))
import os; print('bytes', os.path.getsize('models/interior.json'))
