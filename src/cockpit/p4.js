
    // ================= steering wheel, column and gloved hands =================
    const WC = XI ? new V3(...XI.wheel.centre) : new V3(DRV, 0.835, -0.28);  // wheel centre
    const WR = XI ? XI.wheel.R : 0.183, TILT = XI ? XI.wheel.tilt : -0.384;     // rim radius, column angle
    const wheelBase = new THREE.Group(); wheelBase.position.copy(WC); wheelBase.rotation.x = TILT;
    const wheelRot = new THREE.Group(); wheelBase.add(wheelRot);
    const HAND = 1.08;                                                        // hands at 10 and 2
    const gripW = (th) => { let d = Math.abs(((th + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI); d = Math.abs(d - HAND); return Math.exp(-(d * d) / 0.12); };
    const rimRa = (th) => 0.0150 + 0.0027 * gripW(th), rimRz = (th) => 0.0185 + 0.0037 * gripW(th);
    const W = { plastic: [], alu: [], glove: [], pad: [], rubber: [] };
    const rim = param(160, 18, (u, v, o) => {
      const th = u * Math.PI * 2, a = v * Math.PI * 2, ra = rimRa(th) * (Math.cos(a) < 0 ? 0.86 : 1), rz = rimRz(th);
      const s = Math.sin(th), c = Math.cos(th), rr = WR + Math.cos(a) * ra;
      o.set(s * rr, c * rr, Math.sin(a) * rz);
    }, { closeU: true, closeV: true, flip: true, su: 26, sv: 2 });
    {
      const p = rim.attributes.position, cl = new Float32Array(p.count * 3), base = C(0x27282b), perf = C(0x202124), stripe = C(0xd99a1a);
      for (let i = 0; i < p.count; i++) {
        const th = Math.atan2(p.getX(i), p.getY(i)), k = Math.abs(th) < 0.05 ? stripe : gripW(th) > 0.4 ? perf : base;
        cl[i * 3] = k.r; cl[i * 3 + 1] = k.g; cl[i * 3 + 2] = k.b;
      }
      rim.setAttribute('color', new THREE.BufferAttribute(cl, 3));
    }
    // horizontal spokes, hub, V lower spoke
    for (const s of [-1, 1]) {
      const sh = new THREE.Shape(); sh.moveTo(0.04, -0.034); sh.lineTo(0.17, -0.022); sh.quadraticCurveTo(0.176, -0.004, 0.17, 0.016); sh.lineTo(0.04, 0.028); sh.lineTo(0.04, -0.034);
      let g = xf(slab(sh, 0.016, 0.005), M4(new V3(0, -0.004, -0.004)));
      W.plastic.push(s < 0 ? mirrorX(toIndexed(g)) : g);
      const fr = rrect(0.074, 0.036, 0.008); fr.holes.push(rrect(0.066, 0.028, 0.005));
      W.alu.push(xf(slab(fr, 0.003, 0.0008, 1), M4(new V3(s * 0.098, -0.002, 0.0115))));
      W.plastic.push(xf(slab(rrect(0.05, 0.058, 0.016), 0.004, 0.001, 1), M4(new V3(s * 0.126, -0.004, -0.04))));  // shift paddles behind
    }
    for (const s of [-1, 1]) {
      const sh = new THREE.Shape(); sh.moveTo(s * 0.016, -0.05); sh.lineTo(s * 0.03, -0.05); sh.lineTo(s * 0.05, -0.168); sh.lineTo(s * 0.034, -0.17); sh.lineTo(s * 0.016, -0.05);
      const g = xf(slab(sh, 0.011, 0.0025, 2), M4(new V3(0, 0, -0.004)));
      W.alu.push(s < 0 ? g : g);
    }
    W.plastic.push(xf(slab(rrect(0.108, 0.09, 0.032), 0.026, 0.011, 4), M4(new V3(0, -0.01, 0.012))));
    W.alu.push(new THREE.CylinderGeometry(0.0175, 0.0175, 0.003, 32).rotateX(Math.PI / 2).translate(0, -0.006, 0.0372));
    // column shroud and stalks (do not turn)
    const B = { plastic: [], rubber: [] };
    B.plastic.push(param(30, 20, (u, v, o) => {
      const z = lerp(-0.03, -0.32, u), a = v * Math.PI * 2, k = sstep(0, 1, u), hx = lerp(0.037, 0.058, k), hy = lerp(0.034, 0.052, k);
      const c = Math.cos(a), s = Math.sin(a), e = 0.55;
      o.set(Math.sign(c) * Math.pow(Math.abs(c), e) * hx, Math.sign(s) * Math.pow(Math.abs(s), e) * hy - 0.004 - 0.02 * k, z);
    }, { closeV: true, flip: false, su: 2, sv: 2 }));
    for (const s of [-1, 1]) {
      const st = sweep(cr3([[s * 0.04, 0.012, -0.075], [s * 0.1, 0.004, -0.07], [s * 0.16, -0.008, -0.062]]), 12, 10, (u) => [capR(u, 0.122, 0.0068, 0.0058), capR(u, 0.122, 0.0068, 0.0058)], { ref: new V3(0, 0, 1) });
      B.rubber.push(st);
    }

    // ---- gloved hands ----
    // Built in the grip frame: x along the rim (toward 12 o'clock for the left hand), y away from the wheel centre,
    // z toward the driver. A hand can roll around the rim tube (about x) without letting go, so every frame it rolls
    // until the wrist lines up with the forearm: the wrist never folds back on itself.
    const gripM = (th) => {
      const s = Math.sin(th), c = Math.cos(th);
      return new THREE.Matrix4().makeBasis(new V3(c, -s, 0), new V3(s, c, 0), new V3(0, 0, 1)).setPosition(WR * s, WR * c, 0);
    };
    const RA = XI ? XI.wheel.ra : 0.0165, RZ = XI ? XI.wheel.rz : 0.0205;       // rim tube half sizes where the hands hold it
    const DEG = Math.PI / 180, BETA0 = 52 * DEG;                                 // wrist direction of the hand as built
    const cs = (x, phi, d) => [x, (RA + d) * Math.cos(phi), (RZ + d) * Math.sin(phi)];
    const wdir = (x, d) => [x, Math.cos(BETA0) * d, Math.sin(BETA0) * d];
    const handParts = [];
    {
      const X = new V3(1, 0, 0), sup = (c, e) => Math.pow(Math.max(Math.abs(c), 1e-4), e - 1);
      // back of the hand and palm: domed on the back (+sin side, away from the rim), flatter against the rim,
      // a little wider at the knuckles than at the wrist; it wraps the outer side of the rim, then runs to the wrist
      const pc = cr3([cs(0, -14 * DEG, 0.0105), cs(0, 10 * DEG, 0.0122), cs(0, 30 * DEG, 0.015), wdir(0, 0.054), wdir(0, 0.074)]);
      handParts.push(sweep(pc, 28, 28, (u, a) => {
        const w = lerp(0.0372, 0.0285, sstep(0.3, 1, u)) * (1 - 0.1 * Math.pow(1 - u, 8)), t = lerp(0.0096, 0.0162, sstep(0, 0.85, u));
        const sa = Math.sin(a); return [w * sup(Math.cos(a), 0.8), t * (sa > 0 ? 1 : 0.72) * sup(sa, 0.95)];
      }, { ref: X, su: 3, sv: 2 }));
      // knuckles: a row of four small bumps where the fingers start
      for (const x0 of [0.0255, 0.0086, -0.0088, -0.025]) handParts.push(new THREE.SphereGeometry(x0 < -0.02 ? 0.0072 : 0.0082, 12, 8).translate(...cs(x0, -9 * DEG, 0.0168)));
      // fingers: index finger next to the thumb (+x), little finger at -x; over the front of the rim to its inner side
      const F = [[0.0262, 0.0084, -214], [0.0088, 0.0089, -224], [-0.0092, 0.0084, -214], [-0.0262, 0.0073, -196]];
      for (const [x0, fr, endDeg] of F) {
        const pts = [];
        for (let i = 0; i <= 14; i++) { const s = i / 14, phi = lerp(-10, endDeg, s) * DEG; pts.push(cs(x0 * (1 - 0.08 * s), phi, fr + 0.0009 + 0.0022 * Math.pow(1 - s, 3))); }
        const cu = cr3(pts), L = cu.getLength();
        handParts.push(sweep(cu, 36, 12, (u) => {
          const k = 1 + 0.08 * Math.exp(-((u - 0.4) ** 2) / 0.003) + 0.06 * Math.exp(-((u - 0.7) ** 2) / 0.0022);   // finger joints
          const r = capR(u, L, fr * 1.04, fr * 0.8) * k; return [r, r];
        }, { ref: X, su: 3, sv: 2 }));
      }
      // thumb: from the heel of the hand over the driver's side of the rim, pointing along it
      const th = cr3([cs(0.016, 48 * DEG, 0.026), cs(0.03, 80 * DEG, 0.0165), cs(0.042, 112 * DEG, 0.011), cs(0.051, 136 * DEG, 0.0094)]), TL = th.getLength();
      handParts.push(sweep(th, 22, 12, (u) => { const r = capR(u, TL, 0.0116, 0.0086); return [r, r]; }, { ref: X, su: 2, sv: 2 }));
      // glove cuff, into the sleeve
      handParts.push(sweep(cr3([wdir(0, 0.066), wdir(0, 0.08), wdir(0, 0.094)]), 6, 20, () => [0.0295, 0.021], { ref: X }));
    }
    const handGeo = merge(handParts);
    const wristLocal = new V3(...wdir(0, 0.092));                              // forearm starts here (hand space)
    const hands = [0, 1].map((side) => {
      const hg = new THREE.Group(); hg.matrixAutoUpdate = false;
      hg.matrix.copy(side ? new THREE.Matrix4().makeScale(-1, 1, 1).multiply(gripM(-HAND)) : gripM(-HAND));
      const rg = new THREE.Group(); hg.add(rg); wheelRot.add(hg);
      return { hg, rg, elb: null };
    });
    // forearm sleeve: unit tube along +Z, oriented each frame from wrist to elbow
    const sleeveGeo = param(22, 20, (u, v, o) => {
      const a = v * Math.PI * 2, r = lerp(0.027, 0.04, sstep(0, 1, u)) * (1 + 0.08 * Math.sin(u * 30 + a * 2) * sstep(0.02, 0.25, u) * (1 - 0.6 * u) + 0.03 * Math.sin(a * 3 + u * 9));
      o.set(Math.cos(a) * r * 1.1, Math.sin(a) * r * 0.92, u);
    }, { closeV: true, flip: true, su: 5, sv: 6 });
    // upper arm (elbow to shoulder) and a rounded elbow, seen only at the edge of the view in big turns
    const upperGeo = param(12, 16, (u, v, o) => {
      const a = v * Math.PI * 2, r = lerp(0.041, 0.05, u) * (1 + 0.03 * Math.sin(a * 3 + u * 7));
      o.set(Math.cos(a) * r * 1.08, Math.sin(a) * r * 0.95, u);
    }, { closeV: true, flip: true, su: 4, sv: 6 });
    const elbowGeo = new THREE.SphereGeometry(0.042, 16, 12);
