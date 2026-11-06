
    // ---- materials ----
    const C = (h) => new THREE.Color(h).convertSRGBToLinear();
    const ns = (s) => new V2(s, s);
    const std = (h, o = {}) => new THREE.MeshStandardMaterial(Object.assign({ color: C(h), roughness: 0.8, metalness: 0, envMapIntensity: 0.55 }, o));
    const M = {
      dash: std(0x2b2b2d, { roughness: 0.52, normalMap: leatherN, normalScale: ns(0.42), vertexColors: true, envMapIntensity: 0.75 }),
      plastic: std(0x232428, { roughness: 0.78, vertexColors: true, normalMap: suedeN, normalScale: ns(0.15) }),
      suede: std(0x2f3033, { roughness: 1, normalMap: suedeN, normalScale: ns(0.45), envMapIntensity: 0.25, vertexColors: true }),
      gloss: new THREE.MeshPhysicalMaterial({ color: C(0x050607), roughness: 0.16, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.05, envMapIntensity: 1.0 }),
      alu: std(0xbfc4ca, { metalness: 1, roughness: 0.3, envMapIntensity: 1 }),
      chrome: std(0xe6e9ed, { metalness: 1, roughness: 0.12, envMapIntensity: 1.1 }),
      rubber: std(0x131416, { roughness: 0.92 }),
      wheel: std(0xffffff, { roughness: 0.52, normalMap: leatherN, normalScale: ns(0.55), vertexColors: true, envMapIntensity: 0.65 }),
      glove: std(0x3b3d42, { roughness: 0.62, normalMap: gloveN, normalScale: ns(0.4), envMapIntensity: 0.55 }),
      pad: std(0x63666b, { roughness: 0.8, normalMap: suedeN, normalScale: ns(0.25) }),
      sleeve: std(0xb8b8b8, { map: camoTex, roughness: 0.97, normalMap: fabricN, normalScale: ns(1.0), envMapIntensity: 0.2 }),
      stitch: std(0xffffff, { map: stitchTex, alphaTest: 0.5, roughness: 0.6, envMapIntensity: 0.4 }),
      paint: new THREE.MeshPhysicalMaterial({ color: C(opt.paint || 0xe8562a), metalness: 0.5, roughness: 0.3, clearcoat: 1, clearcoatRoughness: 0.05 }),
    };
    // the imported interior has one grey material: each group gets its own finish here
    const XM = XI ? {
      shell: std(0x34353a, { roughness: 0.56, normalMap: leatherN, normalScale: ns(0.32), vertexColors: true, envMapIntensity: 0.7 }),
      dashtop: std(0x232427, { roughness: 0.86, normalMap: leatherN, normalScale: ns(0.22), vertexColors: true, envMapIntensity: 0.4 }),
      trim: std(0x2b2c2f, { roughness: 1, normalMap: suedeN, normalScale: ns(0.4), vertexColors: true, envMapIntensity: 0.25 }),
      carpet: std(0x1b1b1c, { roughness: 1, normalMap: fabricN, normalScale: ns(0.7), vertexColors: true, envMapIntensity: 0.15 }),
      seat: std(0x3a3b3f, { roughness: 0.5, normalMap: leatherN, normalScale: ns(0.5), vertexColors: true, envMapIntensity: 0.75 }),
      visor: std(0x2e2f32, { roughness: 1, normalMap: suedeN, normalScale: ns(0.45), vertexColors: true, envMapIntensity: 0.25 }),
      door: std(0x37383c, { roughness: 0.58, normalMap: leatherN, normalScale: ns(0.35), vertexColors: true, envMapIntensity: 0.7 }),
      console: std(0x313236, { roughness: 0.5, normalMap: leatherN, normalScale: ns(0.3), vertexColors: true, envMapIntensity: 0.7 }),
      black: std(0x111214, { roughness: 0.7, vertexColors: true }),
      switch: std(0x1c1d20, { roughness: 0.38, vertexColors: true, envMapIntensity: 0.8 }),
      gauge: std(0x0b0c0d, { roughness: 0.3, vertexColors: true }),
      metal: std(0xc9cdd3, { metalness: 1, roughness: 0.26, vertexColors: true, envMapIntensity: 1 }),
      alu: std(0xb9bdc3, { metalness: 1, roughness: 0.38, vertexColors: true, envMapIntensity: 1 }),
      pedal: std(0x5a5e64, { metalness: 0.7, roughness: 0.55, vertexColors: true, envMapIntensity: 0.25 }),
      grille: std(0x131415, { roughness: 0.9, normalMap: fabricN, normalScale: ns(0.9), vertexColors: true }),
      mirrorBody: std(0x161718, { roughness: 0.45, vertexColors: true }),
      wheelRim: std(0x1d1e20, { roughness: 0.48, normalMap: leatherN, normalScale: ns(0.6), vertexColors: true, envMapIntensity: 0.75 }),
      wheelHub: std(0x202124, { roughness: 0.42, normalMap: leatherN, normalScale: ns(0.25), vertexColors: true, envMapIntensity: 0.7 }),
    } : null;
    const parts = { dash: [], plastic: [], suede: [], gloss: [], alu: [], chrome: [], rubber: [], paint: [], stitch: [] };
    const add = (k, g) => { parts[k].push(g); return g; };

    // ---- dashboard: one lofted skin whose profile morphs into the instrument hood in front of the driver ----
    const DRV = -0.37;                       // driver centre line
    let STACK = null, onStack = null;
    if (!XI) {
    const BIN = [-0.6, -0.14];               // instrument hood x-range
    const dashN = [[-1.10, 0.915], [-0.96, 0.936], [-0.80, 0.957], [-0.66, 0.970], [-0.57, 0.974], [-0.515, 0.968], [-0.49, 0.950], [-0.484, 0.925], [-0.488, 0.900], [-0.497, 0.860], [-0.505, 0.815], [-0.503, 0.770], [-0.488, 0.725], [-0.455, 0.670], [-0.425, 0.610], [-0.44, 0.565], [-0.56, 0.52]];
    const dashB = [[-1.10, 0.915], [-0.96, 0.940], [-0.80, 0.968], [-0.66, 0.996], [-0.56, 1.014], [-0.49, 1.014], [-0.461, 1.000], [-0.467, 0.979], [-0.54, 0.965], [-0.606, 0.938], [-0.610, 0.838], [-0.560, 0.803], [-0.505, 0.790], [-0.480, 0.745], [-0.445, 0.672], [-0.43, 0.575], [-0.56, 0.52]];
    function crEval(P, t) {
      const n = P.length - 1, f = clamp(t, 0, 1) * n, i = Math.min(n - 1, Math.floor(f)), s = f - i, s2 = s * s, s3 = s2 * s;
      const p0 = P[Math.max(0, i - 1)], p1 = P[i], p2 = P[i + 1], p3 = P[Math.min(n, i + 2)];
      const h = (a, b, c, d) => 0.5 * (2 * b + (-a + c) * s + (2 * a - 5 * b + 4 * c - d) * s2 + (-a + 3 * b - 3 * c + d) * s3);
      return [h(p0[0], p1[0], p2[0], p3[0]), h(p0[1], p1[1], p2[1], p3[1])];
    }
    const binW = (x) => sstep(BIN[0], BIN[0] + 0.04, x) * (1 - sstep(BIN[1] - 0.04, BIN[1], x));
    let dashCacheX = null, dashCacheP = null;
    function dashProfile(x) {
      if (x === dashCacheX) return dashCacheP;
      const b = binW(x), ax = Math.abs(x), dz = 0.075 * sstep(0.42, 0.88, ax), dy = -0.018 * sstep(0.5, 0.88, ax);
      const P = dashN.map((q, k) => { const r = dashB[k]; return [lerp(q[0], r[0], b) + dz * (k > 2 ? 1 : 0.3), lerp(q[1], r[1], b) + dy]; });
      dashCacheX = x; dashCacheP = P; return P;
    }
    const dashAt = (x, v) => crEval(dashProfile(x), v);
    function faceZ(x, y) { // z of the dash face at height y (face = lower 60 % of the profile)
      let best = 1e9, z = -0.5;
      for (let i = 0; i <= 60; i++) { const q = dashAt(x, 0.4 + i / 60 * 0.55); const d = Math.abs(q[1] - y); if (d < best) { best = d; z = q[0]; } }
      return z;
    }
    {
      const g = param(116, 84, (u, v, o) => { const x = lerp(-0.88, 0.88, u), q = dashAt(x, v); o.set(x, q[1], q[0]); }, { su: 1.76 * 7, sv: 0.9 * 7, flip: true });
      add('dash', shade(g, (P, N) => {
        const cav = binW(P.x) * sstep(-0.52, -0.58, P.z) * sstep(0.79, 0.83, P.y) * (1 - sstep(0.95, 0.98, P.y));
        return (0.32 + 0.68 * sstep(0.52, 0.86, P.y)) * (N.y < -0.35 ? 0.55 : 1) * (1 - 0.55 * cav) * lerp(0.55, 1, sstep(-1.09, -0.97, P.z));
      }));
    }
    // contrast stitching along the dash lip and the instrument hood brow
    function stitch(x0, x1, v0) {
      const P = new V3(), A = new V3(), Bq = new V3(), du = new V3(), dv = new V3();
      const S = (x, v, out) => { const q = dashAt(x, v); return out.set(x, q[1], q[0]); };
      return param(90, 1, (u, w, o) => {
        const x = lerp(x0, x1, u), v = v0 + (w - 0.5) * 0.0055;
        S(x, v, P); S(x + 0.002, v, A); S(x - 0.002, v, Bq); du.subVectors(A, Bq);
        S(x, v + 0.002, A); S(x, v - 0.002, Bq); dv.subVectors(A, Bq);
        o.copy(P).addScaledVector(du.cross(dv).normalize().negate(), 0.0008);
      }, { su: (x1 - x0) / 0.0065, flip: true });
    }
    for (const [x0, x1] of [[-0.85, -0.645], [BIN[0] + 0.05, BIN[1] - 0.05], [-0.095, 0.85]]) { add('stitch', stitch(x0, x1, 6 / 16)); if (x0 !== BIN[0] + 0.05) add('stitch', stitch(x0, x1, 8.6 / 16)); }
    // air vents: bezel ring + slats, sitting on the dash face
    function vent(x, y, w, h, tilt = 0) {
      const z = faceZ(x, y) + 0.004, m = M4(new V3(x, y, z), [-0.1, tilt, 0]);
      const outer = rrect(w + 0.016, h + 0.016, 0.012), hole = rrect(w, h, 0.007); outer.holes.push(hole);
      add('alu', xf(slab(outer, 0.006, 0.002, 2), m));
      add('rubber', xf(new THREE.PlaneGeometry(w, h).translate(0, 0, -0.0028), m));
      for (let i = 0; i < 4; i++) add('plastic', xf(new THREE.BoxGeometry(w - 0.004, 0.0022, 0.005).applyMatrix4(M4(null, [0.35, 0, 0])).translate(0, -h / 2 + (i + 0.5) * h / 4, 0), m));
      add('alu', xf(new THREE.BoxGeometry(0.008, 0.004, 0.01).translate(0, -h / 2 + 0.375 * h, 0.002), m));
    }
    vent(-0.715, 0.862, 0.11, 0.04, 0.22);
    vent(0.715, 0.862, 0.11, 0.04, -0.22);
    // passenger-side brushed trim strip and a fine seam
    {
      const g = param(60, 6, (u, v, o) => { const x = lerp(0.16, 0.80, u), y = lerp(0.792, 0.808, v); o.set(x, y, faceZ(x, y) + 0.003); }, { su: 4 });
      add('alu', g);
    }

    // ---- centre stack (piano black) with screen, vents and climate panel ----
    STACK = { y: 0.755, z: -0.468, tilt: -0.2 };
    const stackM = M4(new V3(0, STACK.y, STACK.z), [STACK.tilt, 0, 0]);
    add('gloss', xf(slab(rrect(0.29, 0.33, 0.035), 0.05, 0.012), M4(new V3(0, STACK.y, STACK.z - 0.03), [STACK.tilt, 0, 0])));
    onStack = (x, y, z) => new V3(x, y, z).applyMatrix4(stackM);
    for (const sx of [-1, 1]) { // centre vents above the screen
      const outer = rrect(0.118, 0.034, 0.01); outer.holes.push(rrect(0.104, 0.022, 0.006));
      const m = M4(onStack(sx * 0.066, 0.135, 0.008), [STACK.tilt, 0, 0]);
      add('alu', xf(slab(outer, 0.005, 0.0015, 2), m));
      add('rubber', xf(new THREE.PlaneGeometry(0.104, 0.022).translate(0, 0, -0.0004), m));
      for (let i = 0; i < 3; i++) add('plastic', xf(new THREE.BoxGeometry(0.1, 0.002, 0.004).applyMatrix4(M4(null, [0.3, 0, 0])).translate(0, -0.011 + (i + 0.5) * 0.022 / 3, 0.001), m));
    }

    // ---- console tunnel with armrest and gear selector ----
    {
      const yTop = (z) => lerp(0.588, 0.606, sstep(-0.5, 0.0, z)) + 0.03 * sstep(0.12, 0.2, z);
      const prof = [[-0.128, 0.30], [-0.128, 0.50], [-0.126, 0.55], [-0.118, 0.575], [-0.098, 0.586], [0, 0.588], [0.098, 0.586], [0.118, 0.575], [0.126, 0.55], [0.128, 0.50], [0.128, 0.30]];
      const g = param(80, 40, (u, v, o) => {
        const z = lerp(-0.60, 0.55, u), q = crEval(prof, v), yt = yTop(z);
        o.set(q[0], q[1] <= 0.5 ? q[1] : 0.5 + (q[1] - 0.5) / 0.088 * (yt - 0.5), z);
      }, { su: 8, sv: 3 });
      add('dash', shade(g, (P) => 0.5 + 0.5 * sstep(0.45, 0.6, P.y)));
      add('gloss', xf(slab(rrect(0.2, 0.25, 0.03), 0.012, 0.004), M4(new V3(0, 0.594, -0.43), [-Math.PI / 2 + 0.03, 0, 0])));
    }
    }
