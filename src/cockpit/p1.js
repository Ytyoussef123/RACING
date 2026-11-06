  // ================= procedural cockpit (rendered in its own pass, car-local coordinates) =================
  // car frame: origin at the car centre on the ground, forward -Z, right +X, up +Y. Driver sits on the left.
  function makeCockpit(opt) {
    const V3 = THREE.Vector3, V2 = THREE.Vector2;
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
    const sstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
    // imported interior (models/interior.json): quantised groups, already in car coordinates
    const XI = opt.interior ? decodeXI(opt.interior) : null;
    function decodeXI(J) {
      const b64 = (s) => { const b = atob(s), u = new Uint8Array(b.length); for (let i = 0; i < b.length; i++) u[i] = b.charCodeAt(i); return u.buffer; };
      const UVK = { shell: 9, dashtop: 11, trim: 12, carpet: 16, seat: 7, visor: 12, door: 9, console: 9, wheelRim: 16, wheelHub: 12 };
      const groups = {};
      for (const name in J.groups) {
        const e = J.groups[name], n = e.n, q = e.q, k = UVK[name] || 10;
        const qp = new Int16Array(b64(e.pos)), qn = new Int8Array(b64(e.nor)), ao = new Uint8Array(b64(e.ao)), ix = new Uint16Array(b64(e.idx));
        const pos = new Float32Array(n * 3), nor = new Float32Array(n * 3), col = new Float32Array(n * 3), uv = new Float32Array(n * 2);
        for (let i = 0; i < n; i++) {
          let nx = qn[i * 3] / 127, ny = qn[i * 3 + 1] / 127, nz = qn[i * 3 + 2] / 127; const l = Math.hypot(nx, ny, nz) || 1; nx /= l; ny /= l; nz /= l;
          const x = q[0] + (qp[i * 3] + 32768) / 65535 * q[3], y = q[1] + (qp[i * 3 + 1] + 32768) / 65535 * q[4], z = q[2] + (qp[i * 3 + 2] + 32768) / 65535 * q[5];
          pos.set([x, y, z], i * 3); nor.set([nx, ny, nz], i * 3);
          const a = ao[i] / 255; col.set([a, a, a], i * 3);
          // box projection in metres, so leather and carpet grain keep one size everywhere
          const ax = Math.abs(nx), ay = Math.abs(ny), az = Math.abs(nz);
          if (ax >= ay && ax >= az) uv.set([z * k, y * k], i * 2); else if (ay >= az) uv.set([x * k, z * k], i * 2); else uv.set([x * k, y * k], i * 2);
        }
        if (e.uv) uv.set(new Float32Array(b64(e.uv)));
        const g = new THREE.BufferGeometry();
        g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
        g.setAttribute('color', new THREE.BufferAttribute(col, 3)); g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
        g.setIndex(new THREE.BufferAttribute(ix, 1)); g.userData.wheel = !!e.wheel;
        groups[name] = g;
      }
      return { groups, wheel: J.wheel, anchors: J.anchors, bounds: J.bounds };
    }
    let seed = 7;
    const rnd = () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };

    // ---- geometry helpers ----
    // parametric surface fn(u, v, out); normals from finite differences so seams stay smooth
    function param(nu, nv, fn, o = {}) {
      const cu = !!o.closeU, cv = !!o.closeV, flip = !!o.flip, n = (nu + 1) * (nv + 1);
      const pos = new Float32Array(n * 3), nor = new Float32Array(n * 3), uv = new Float32Array(n * 2);
      const p = new V3(), a = new V3(), b = new V3(), du = new V3(), dv = new V3();
      const f = (u, v, t) => { u = cu ? ((u % 1) + 1) % 1 : clamp(u, 0, 1); v = cv ? ((v % 1) + 1) % 1 : clamp(v, 0, 1); fn(u, v, t); return t; };
      let k = 0;
      for (let j = 0; j <= nv; j++) for (let i = 0; i <= nu; i++, k++) {
        const u = i / nu, v = j / nv;
        f(u, v, p); pos[k * 3] = p.x; pos[k * 3 + 1] = p.y; pos[k * 3 + 2] = p.z;
        let e = 1e-3, nn = null;
        for (let tries = 0; tries < 3; tries++, e *= 8) {
          f(u + e, v, a); f(u - e, v, b); du.subVectors(a, b);
          f(u, v + e, a); f(u, v - e, b); dv.subVectors(a, b);
          du.cross(dv); if (du.lengthSq() > 1e-16) { nn = du.normalize(); break; }
        }
        if (!nn) nn = du.set(0, 1, 0);
        if (flip) nn.negate();
        nor[k * 3] = nn.x; nor[k * 3 + 1] = nn.y; nor[k * 3 + 2] = nn.z;
        uv[k * 2] = u * (o.su || 1); uv[k * 2 + 1] = v * (o.sv || 1);
      }
      const idx = [];
      for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) {
        const a0 = j * (nu + 1) + i, a1 = a0 + 1, b0 = a0 + nu + 1, b1 = b0 + 1;
        if (flip) idx.push(a0, b0, a1, a1, b0, b1); else idx.push(a0, a1, b0, a1, b1, b0);
      }
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
      g.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
      g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
      g.setIndex(idx);
      return g;
    }
    // tube around a 3D curve; sec(u, angle) -> [radius along N, radius along B]
    function sweep(curve, nu, nv, sec, o = {}) {
      const ref = o.ref || new V3(0, 1, 0), T = new V3(), N = new V3(), B = new V3(), C = new V3();
      return param(nu, nv, (u, v, out) => {
        curve.getPointAt(u, C); curve.getTangentAt(u, T);
        B.crossVectors(T, ref).normalize(); N.crossVectors(B, T).normalize();
        const a = v * Math.PI * 2, r = sec(u, a);
        out.copy(C).addScaledVector(N, Math.cos(a) * r[0]).addScaledVector(B, Math.sin(a) * r[1]);
      }, Object.assign({ closeV: true, flip: true }, o));
    }
    const cr3 = (pts, closed) => new THREE.CatmullRomCurve3(pts.map((q) => new V3(q[0], q[1], q[2])), !!closed, 'centripetal');
    // rounded capsule radius profile: r(u) for a tube of length L with hemispherical ends
    const capR = (u, L, r0, r1) => { const s = u * L, r = lerp(r0, r1 === undefined ? r0 : r1, u); const e = Math.min(s, L - s); return e >= r ? r : Math.sqrt(Math.max(0, r * r - (r - e) * (r - e))); };
    function toIndexed(g) { if (!g.index) { const n = g.attributes.position.count, ix = []; for (let i = 0; i < n; i++) ix.push(i); g.setIndex(ix); } return g; }
    function merge(geos) {
      geos = geos.map(toIndexed);
      const hasCol = geos.some((g) => g.attributes.color);
      let nv = 0, ni = 0; for (const g of geos) { nv += g.attributes.position.count; ni += g.index.count; }
      const pos = new Float32Array(nv * 3), nor = new Float32Array(nv * 3), uv = new Float32Array(nv * 2), cl = hasCol ? new Float32Array(nv * 3) : null, idx = new Uint32Array(ni);
      let ov = 0, oi = 0;
      for (const g of geos) {
        const n = g.attributes.position.count;
        pos.set(g.attributes.position.array.subarray(0, n * 3), ov * 3);
        if (!g.attributes.normal) g.computeVertexNormals();
        nor.set(g.attributes.normal.array.subarray(0, n * 3), ov * 3);
        if (g.attributes.uv) uv.set(g.attributes.uv.array.subarray(0, n * 2), ov * 2);
        if (cl) { if (g.attributes.color) cl.set(g.attributes.color.array.subarray(0, n * 3), ov * 3); else cl.fill(1, ov * 3, (ov + n) * 3); }
        const gi = g.index.array; for (let i = 0; i < gi.length; i++) idx[oi + i] = gi[i] + ov;
        ov += n; oi += gi.length;
      }
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.BufferAttribute(nor, 3)); g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
      if (cl) g.setAttribute('color', new THREE.BufferAttribute(cl, 3));
      g.setIndex(new THREE.BufferAttribute(idx, 1));
      return g;
    }
    // baked ambient occlusion as a vertex colour (fn returns 0..1)
    function shade(g, fn) {
      g = toIndexed(g);
      const p = g.attributes.position, nn = g.attributes.normal, c = new Float32Array(p.count * 3), P = new V3(), N = new V3();
      for (let i = 0; i < p.count; i++) { P.fromBufferAttribute(p, i); N.fromBufferAttribute(nn, i); const v = clamp(fn(P, N), 0, 1); c[i * 3] = c[i * 3 + 1] = c[i * 3 + 2] = v; }
      g.setAttribute('color', new THREE.BufferAttribute(c, 3)); return g;
    }
    function mirrorX(g) {
      g = g.clone(); g.applyMatrix4(new THREE.Matrix4().makeScale(-1, 1, 1));
      const ix = g.index.array; for (let i = 0; i < ix.length; i += 3) { const t = ix[i + 1]; ix[i + 1] = ix[i + 2]; ix[i + 2] = t; }
      g.index.needsUpdate = true; return g;
    }
    const xf = (g, m) => { g.applyMatrix4(m); return g; };
    const M4 = (p, r, s) => new THREE.Matrix4().compose(p || new V3(), new THREE.Quaternion().setFromEuler(new THREE.Euler(...(r || [0, 0, 0]))), s || new V3(1, 1, 1));
    // rounded rectangle shape centred on 0
    function rrect(w, h, r) {
      const s = new THREE.Shape(), x = -w / 2, y = -h / 2;
      s.moveTo(x + r, y); s.lineTo(x + w - r, y); s.quadraticCurveTo(x + w, y, x + w, y + r); s.lineTo(x + w, y + h - r); s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
      s.lineTo(x + r, y + h); s.quadraticCurveTo(x, y + h, x, y + h - r); s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y); return s;
    }
    const slab = (shape, depth, bevel, seg = 3) => { const g = new THREE.ExtrudeGeometry(shape, { depth, bevelEnabled: bevel > 0, bevelThickness: bevel, bevelSize: bevel, bevelSegments: seg, curveSegments: 10 }); g.translate(0, 0, -depth / 2); return g; };

    // ---- textures ----
    const cv = (w, h, draw) => { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); return c; };
    const tex = (c, o = {}) => {
      const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = o.clamp ? THREE.ClampToEdgeWrapping : THREE.RepeatWrapping;
      if (o.srgb !== false) t.encoding = THREE.sRGBEncoding; t.anisotropy = opt.aniso || 4; return t;
    };
    function normalTex(N, hf, k) {
      const H = new Float32Array(N * N); for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) H[y * N + x] = hf(x, y);
      return tex(cv(N, N, (c) => {
        const img = c.createImageData(N, N), d = img.data;
        for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
          const dx = H[y * N + (x + 1) % N] - H[y * N + (x - 1 + N) % N], dy = H[((y + 1) % N) * N + x] - H[((y - 1 + N) % N) * N + x];
          const nx = -dx * k, ny = dy * k, l = Math.hypot(nx, ny, 1), i = (y * N + x) * 4;
          d[i] = (nx / l * 0.5 + 0.5) * 255; d[i + 1] = (ny / l * 0.5 + 0.5) * 255; d[i + 2] = (1 / l * 0.5 + 0.5) * 255; d[i + 3] = 255;
        }
        c.putImageData(img, 0, 0);
      }), { srgb: false });
    }
    // tileable cellular grain (leather pebbles), returns F2-F1 in 0..~1
    function cells(N, n) {
      const pts = []; for (let i = 0; i < n * n; i++) pts.push([rnd(), rnd()]);
      return (x, y) => {
        const u = x / N * n, v = y / N * n, ci = Math.floor(u), cj = Math.floor(v); let f1 = 9, f2 = 9;
        for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) {
          const ii = ((ci + di) % n + n) % n, jj = ((cj + dj) % n + n) % n, p = pts[jj * n + ii];
          const d = Math.hypot(ci + di + p[0] - u, cj + dj + p[1] - v);
          if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d;
        }
        return f2 - f1;
      };
    }
    const leatherC = cells(256, 26);
    const leatherN = normalTex(256, (x, y) => sstep(0, 0.32, leatherC(x, y)) * 0.8 + rnd() * 0.12, 1.6);
    const fineC = cells(128, 20);
    const gloveN = normalTex(128, (x, y) => sstep(0, 0.3, fineC(x, y)) * 0.7 + rnd() * 0.1, 1.2);
    // fabric weave for the sleeves (twill) with slow folds
    const fabricN = normalTex(256, (x, y) => 0.35 * Math.sin((x + y) * Math.PI * 2 / 8) * Math.sin((x - y) * Math.PI * 2 / 16) + 0.25 * Math.sin(y * Math.PI * 2 / 64 + Math.sin(x * Math.PI * 2 / 128) * 2) + rnd() * 0.15, 1.4);
    const suedeN = normalTex(128, () => rnd(), 0.6);
    // tileable woodland camo for the sleeves
    const camoTex = tex(cv(256, 256, (x, N) => {
      x.fillStyle = '#3d4130'; x.fillRect(0, 0, N, N);
      for (const col of ['#55553d', '#2d3125', '#1f201b', '#5c5643']) {
        x.fillStyle = col;
        for (let i = 0; i < 13; i++) {
          const cx = rnd() * N, cy = rnd() * N, r = 9 + rnd() * 20, pts = [];
          for (let a = 0; a < 12; a++) { const t = a / 12 * Math.PI * 2, rr = r * (0.55 + rnd() * 0.7); pts.push([Math.cos(t) * rr * 1.5, Math.sin(t) * rr]); }
          for (const ox of [-N, 0, N]) for (const oy of [-N, 0, N]) { x.beginPath(); pts.forEach((q, k) => (k ? x.lineTo(cx + ox + q[0], cy + oy + q[1]) : x.moveTo(cx + ox + q[0], cy + oy + q[1]))); x.closePath(); x.fill(); }
        }
      }
    }));
    const stitchTex = tex(cv(16, 8, (x) => { x.clearRect(0, 0, 16, 8); x.fillStyle = '#c3c6cc'; x.fillRect(3, 2, 10, 4); }));
