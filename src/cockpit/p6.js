
    // ================= assembly =================
    const scene = new THREE.Scene(), root = new THREE.Group(); scene.add(root);
    if (opt.env) scene.environment = opt.env;
    const mk = (geo, mat, parent = root, o = {}) => {
      if (mat.vertexColors && !geo.attributes.color) { const c = new Float32Array(geo.attributes.position.count * 3).fill(1); geo.setAttribute('color', new THREE.BufferAttribute(c, 3)); }
      const m = new THREE.Mesh(geo, mat); m.castShadow = o.cast !== false; m.receiveShadow = o.recv !== false; m.frustumCulled = false; parent.add(m); return m;
    };
    // instrument cluster plate, bezels and needles
    const clusterG = new THREE.Group(); root.add(clusterG);
    if (XI) {
      const A = XI.anchors.cluster, n = new V3(...A.n), up = new V3(...A.up);
      clusterG.position.set(...A.c).addScaledVector(n, 0.004);
      clusterG.quaternion.setFromRotationMatrix(new THREE.Matrix4().makeBasis(new V3().crossVectors(up, n).normalize(), up, n));
    } else { clusterG.position.set(DRV, 0.893, -0.594); clusterG.lookAt(DRV, 1.13, 0.30); }
    clusterG.updateMatrix();
    const kx = 0.36 / CL.px, ph = CL.py * kx;
    mk(new THREE.PlaneGeometry(0.36, ph), new THREE.MeshBasicMaterial({ map: faceTex, toneMapped: false, color: new THREE.Color(0.9, 0.9, 0.9) }), clusterG, { cast: false });
    const needleMat = new THREE.MeshBasicMaterial({ color: C(0xff5a1a), toneMapped: false });
    const needles = [];
    DIALS.forEach((d, i) => {
      const cx = (d.x - CL.px / 2) * kx, cy = (CL.py / 2 - d.y) * kx, r = d.r * kx;
      parts.alu.push(xf(new THREE.TorusGeometry(r + 0.0014, 0.0021, 8, 72), new THREE.Matrix4().makeTranslation(cx, cy, 0.0016).premultiply(clusterG.matrix)));
      if (d.info) return;
      const sh = new THREE.Shape(); sh.moveTo(-0.0017, -0.011); sh.lineTo(0.0017, -0.011); sh.lineTo(0.0005, r * 0.86); sh.lineTo(-0.0005, r * 0.86); sh.lineTo(-0.0017, -0.011);
      const piv = new THREE.Group(); piv.position.set(cx, cy, 0.0022); clusterG.add(piv);
      mk(new THREE.ShapeGeometry(sh), needleMat, piv, { cast: false });
      mk(new THREE.CircleGeometry(0.0062, 20).translate(0, 0, 0.0008), M.rubber, piv, { cast: false });
      needles.push({ piv, max: d.max, rpm: !!d.red });
    });
    const readMat = new THREE.MeshBasicMaterial({ map: readTex, toneMapped: false });
    const rdA = new THREE.PlaneGeometry(0.054, 0.027); mirrorUV(rdA, 0, 0.5, 0, 1);
    const rdB = new THREE.PlaneGeometry(0.054, 0.027); mirrorUV(rdB, 0.5, 1, 0, 1);
    mk(rdA.translate(0, -0.03, 0.0019), readMat, clusterG, { cast: false });
    mk(rdB.translate((812 - CL.px / 2) * kx, (CL.py / 2 - 172) * kx, 0.0019), readMat, clusterG, { cast: false });
    // centre stack displays
    if (!XI) {
    const scr = mk(new THREE.PlaneGeometry(0.236, 0.133), new THREE.MeshBasicMaterial({ map: scrTex, toneMapped: false, color: new THREE.Color(0.85, 0.85, 0.85) }), root, { cast: false });
    scr.position.copy(onStack(0, 0.045, 0.0082)); scr.rotation.x = STACK.tilt;
    const clim = mk(new THREE.PlaneGeometry(0.24, 0.06), new THREE.MeshStandardMaterial({ map: climateTex, roughness: 0.25, emissive: new THREE.Color(1, 1, 1), emissiveMap: climateTex, emissiveIntensity: 0.55 }), root, { cast: false });
    clim.position.copy(onStack(0, -0.074, 0.0082)); clim.rotation.x = STACK.tilt;
    }
    // gear selector
    if (!XI) {
      const g = new THREE.Group(); g.position.set(0.0, 0.604, -0.41); g.rotation.x = 0.15; root.add(g);
      const lathe = (pts, mat) => mk(new THREE.LatheGeometry(pts.map((p) => new V2(p[0], p[1])), 28), mat, g);
      lathe([[0.036, 0], [0.037, 0.004], [0.031, 0.008], [0.022, 0.0095]], M.alu);
      const boot = []; for (let i = 0; i <= 12; i++) { const h = 0.008 + i / 12 * 0.034; boot.push([0.022 - (h - 0.008) * 0.25 + 0.0018 * Math.sin(i * 1.6), h]); }
      lathe(boot, M.dash);
      lathe([[0.0105, 0.04], [0.017, 0.05], [0.0222, 0.066], [0.0236, 0.082], [0.0212, 0.096], [0.0142, 0.1045], [0.0001, 0.1065]], M.dash);
      mk(new THREE.TorusGeometry(0.0228, 0.0017, 8, 40).rotateX(Math.PI / 2).translate(0, 0.0705, 0), M.alu, g);
      const gate = mk(new THREE.PlaneGeometry(0.03, 0.06), new THREE.MeshBasicMaterial({ map: gateTex, toneMapped: false }), root, { cast: false });
      gate.position.set(0.05, 0.6052, -0.41); gate.rotation.x = -Math.PI / 2 + 0.03;
    }
    // wheel
    if (!XI) mk(rim, M.wheel, wheelRot);
    for (const k in W) if (W[k].length && !XI && k !== 'glove' && k !== 'pad') mk(merge(W[k]), M[k], wheelRot);
    for (const H of hands) mk(handGeo, M.glove, H.rg);
    if (!XI) {
      for (const k in B) if (B[k].length) mk(merge(B[k]), M[k], wheelBase);
      const btnMat = new THREE.MeshStandardMaterial({ map: buttonsTex, roughness: 0.35, envMapIntensity: 0.6 });
      for (const s of [-1, 1]) { const b = mk(new THREE.PlaneGeometry(0.066, 0.028), btnMat, wheelRot, { cast: false }); b.position.set(s * 0.098, -0.002, 0.0098); }
      const emb = mk(new THREE.CircleGeometry(0.0165, 32), new THREE.MeshStandardMaterial({ map: emblemTex, metalness: 0.6, roughness: 0.3 }), wheelRot, { cast: false }); emb.position.set(0, -0.006, 0.0388);
    }
    root.add(wheelBase);
    // imported interior: every group with its own finish, the wheel groups turn with the rim
    if (XI) {
      for (const name in XI.groups) {
        const g = XI.groups[name];
        if (name === 'visor') continue;                                        // no sun visors: they hid the road
        if (name === 'trim') continue;                                         // header, roof rails: nothing above the windscreen
        if (name === 'shell') {                                                // and no stubs of windscreen pillar left on the dash corners
          const ix = g.index.array, p = g.attributes.position, keep = [], cx = XI.bounds[0][0] / 2 + XI.bounds[1][0] / 2;
          for (let t = 0; t < ix.length; t += 3) {
            const x = (p.getX(ix[t]) + p.getX(ix[t + 1]) + p.getX(ix[t + 2])) / 3, y = (p.getY(ix[t]) + p.getY(ix[t + 1]) + p.getY(ix[t + 2])) / 3, z = (p.getZ(ix[t]) + p.getZ(ix[t + 1]) + p.getZ(ix[t + 2])) / 3;
            if (!(y > 0.975 && z < -0.2 && Math.abs(x - cx) > 0.5) && !(y > 0.94 && z < -0.35 && Math.abs(x - cx) > 0.56)) keep.push(ix[t], ix[t + 1], ix[t + 2]);
          }
          g.setIndex(keep);
        }
        if (name !== 'mirrorGlass' && name !== 'mirrorBody') mk(g, XM[name] || XM.shell, g.userData.wheel ? wheelRot : root);
      }
      // roof lining (the model is open on top), from the top of the windscreen header to the back wall
      const b = XI.bounds, tp = XI.groups.trim.attributes.position;
      let zf = 0; for (let i = 0; i < tp.count; i++) if (tp.getY(i) > b[1][1] - 0.03) zf = Math.min(zf, tp.getZ(i));
      const w = b[1][0] - b[0][0] + 0.06, d = b[1][2] - zf + 0.02;
      const roof = new THREE.PlaneGeometry(w, d).rotateX(Math.PI / 2).translate((b[0][0] + b[1][0]) / 2, b[1][1] + 0.003, (zf + b[1][2]) / 2);
      const ruv = roof.attributes.uv; for (let i = 0; i < ruv.count; i++) ruv.setXY(i, ruv.getX(i) * w * 12, ruv.getY(i) * d * 12);
      if (!XI) mk(roof, XM.trim, root);
      // faces for the small gauges in the side pods
      XI.anchors.dials.forEach((D, k) => {
        const n = new V3(...D.n), up = new V3(0, 1, 0).addScaledVector(n, -n.y).normalize();
        const m = mk(new THREE.CircleGeometry(D.r, 28), new THREE.MeshStandardMaterial({ map: auxTex(k), roughness: 0.25, emissive: new THREE.Color(1, 1, 1), emissiveMap: auxTex(k), emissiveIntensity: 0.25 }), root, { cast: false });
        m.position.set(...D.c).addScaledVector(n, 0.0015); m.quaternion.setFromRotationMatrix(new THREE.Matrix4().makeBasis(new V3().crossVectors(up, n).normalize(), up, n));
      });
    }
    // arms: shoulder, elbow, wrist. The hands hold the rim, and a two-bone solve places the elbows,
    // so turning the wheel lifts one elbow and pulls the other one down, like real arms doing the work.
    // The camera sits right of the driver's centre line, so the right shoulder is set further out than
    // anatomy would put it: that keeps the right forearm coming in from the lower right, not from below the eye.
    const sleeveL = mk(sleeveGeo, M.sleeve), sleeveR = mk(sleeveGeo, M.sleeve);
    const upper = [mk(upperGeo, M.sleeve), mk(upperGeo, M.sleeve)], elbowM = [mk(elbowGeo, M.sleeve), mk(elbowGeo, M.sleeve)];
    const ARMS = {
      land: { sh: [[-0.66, 0.9, 0.24], [0.05, 0.86, 0.12]], pole: [[-0.6, -0.8, 0], [0.6, -0.8, 0]], lu: 0.3, lf: 0.39 },
      port: { sh: [[-0.8, 0.8, 0.3], [0.16, 0.8, 0.24]], pole: [[-0.7, -0.7, 0], [0.7, -0.7, 0]], lu: 0.3, lf: 0.42 },
    };
    // mirrors
    const mirrorMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(0.8, 0.83, 0.86), toneMapped: false });
    if (XI) {
      const A = XI.anchors.mirror, mg = new THREE.Group(), c = new V3(...A.c); root.add(mg);
      mk(XI.groups.mirrorGlass, mirrorMat, mg, { cast: false }); mk(XI.groups.mirrorBody, XM.mirrorBody, mg);
      for (const o of mg.children) o.position.sub(c);                         // pivot at the glass centre
      mg.position.copy(c).add(new V3(0.035, 0.11, 0.0)); mg.scale.setScalar(0.78);
      mg.quaternion.setFromUnitVectors(new V3(...A.n), new V3(DRV, 1.15, 0.265).sub(mg.position).normalize());   // glass turned to the eye
    }
    else {
      mk(mirrorGlass, mirrorMat, root, { cast: false });
      mk(rearFrame, new THREE.MeshBasicMaterial({ map: rearFrameTex, transparent: true, toneMapped: false }), root, { cast: false, recv: false });
      for (const g of sideGlass) mk(g, mirrorMat, root, { cast: false });
      const bandM = mk(band, new THREE.MeshBasicMaterial({ map: bandTex, transparent: true, depthWrite: false }), root, { cast: false, recv: false });
      bandM.renderOrder = 5;
    }
    // static body parts, merged per material
    for (const k in parts) if (parts[k].length) mk(merge(parts[k]), M[k]);

    // ---- lights: own sun with a tight, sharp shadow map, sky fill ----
    scene.add(new THREE.HemisphereLight(C(0xf5f0e8), C(0x4f473d), 1.25));
    const fill = new THREE.DirectionalLight(C(0xfff8ee), 0.6); fill.position.set(0.3, 0.8, 1); scene.add(fill);
    const sunL = new THREE.DirectionalLight(C(0xfff0d8), 2.7);
    sunL.castShadow = true;
    const sc = sunL.shadow.camera; sc.left = -1.35; sc.right = 1.35; sc.top = 1.35; sc.bottom = -1.35; sc.near = 0.1; sc.far = 8;
    sunL.shadow.bias = -0.0004; sunL.shadow.normalBias = 0.0035;
    sunL.target.position.set(-0.1, 0.9, -0.3);
    scene.add(sunL, sunL.target);
    const setShadowSize = (n) => { sunL.castShadow = n > 0; if (n > 0) sunL.shadow.mapSize.set(n, n); if (sunL.shadow.map) { sunL.shadow.map.dispose(); sunL.shadow.map = null; } };   // 0: no cockpit shadows (phones, SD)
    setShadowSize(opt.hq ? 2048 : 1024);

    const cam = new THREE.PerspectiveCamera(52, 1, 0.02, 6);
    const EYE = XI ? new V3(DRV, 1.15, 0.265) : new V3(-0.205, 1.112, 0.30);        // the driver sits centred behind the wheel, eye well above the dash
    const eyeD = EYE.clone().sub(new V3(-0.205, 1.112, 0.30));
    const view = XI ? { land: [0, 0, 0, -0.12], portrait: [0, 0.02, 0.03, -0.2] } : { land: [0, 0, 0, -0.19], portrait: [-0.1, 0.05, 0.12, -0.27] };
    const wristW = new V3(), elbW = new V3(), ikA = new V3(), ikP = new V3(), hInv = new THREE.Matrix4(), hLoc = new V3();
    let rigs = null;
    // ---- imported driver (skinned): his shoulders sit behind the wheel, the arms are solved every frame so the
    // hands stay on the rim, and the fingers are curled around it once ----
    const dV = new V3();
    const DRV_A = opt.driver ? setupDriver(opt.driver) : null;
    function setupDriver(g) {
      const B = {};
      g.traverse((o) => { if (o.isBone) B[o.name.replace(/_\d+$/, '')] = o; if (o.isMesh) { o.frustumCulled = false; o.castShadow = true; o.receiveShadow = true; if (o.material) { o.material.envMapIntensity = 0.6; o.material.roughness = /Body/.test(o.material.name) ? 0.5 : 0.72; if (/Body/.test(o.material.name)) { o.material.map = null; o.material.color.setHex(0x484b51).convertSRGBToLinear(); o.material.envMapIntensity = 0.8; o.material.needsUpdate = true; } } } });   // hands: dark grey racing gloves (they stand out from the black rim)
      const need = ['LeftArm', 'LeftForeArm', 'LeftHand', 'RightArm', 'RightForeArm', 'RightHand', 'LeftHandMiddle1', 'LeftHandIndex1', 'LeftHandPinky1'];
      if (need.some((k) => !B[k])) { console.warn('driver rig not recognised'); return null; }
      const holder = new THREE.Group(); holder.add(g); root.add(holder); root.updateMatrixWorld(true);
      // slimmer sleeves: in the bind pose, pull every sleeve vertex toward its arm bone (the cloth only, the motion is untouched)
      g.traverse((o) => {
        if (!o.isSkinnedMesh) return;
        const sk = o.skeleton, idx = (n) => sk.bones.findIndex((b) => b.name.replace(/_\d+$/, '') === n);
        const segs = [];
        for (const s of ['Left', 'Right']) for (const [a, b, k] of [[s + 'Arm', s + 'ForeArm', 0.78], [s + 'ForeArm', s + 'Hand', 0.74]]) {
          const ia = idx(a), ib = idx(b); if (ia < 0 || ib < 0) continue;
          segs.push({ ia, ib, k, fore: /ForeArm$/.test(a), A: new V3().setFromMatrixPosition(sk.boneInverses[ia].clone().invert()), Bp: new V3().setFromMatrixPosition(sk.boneInverses[ib].clone().invert()) });
        }
        if (!segs.length || /Body/.test(o.material.name)) return;       // hands keep their shape
        const pos = o.geometry.attributes.position, si = o.geometry.attributes.skinIndex, sw = o.geometry.attributes.skinWeight;
        const toFore = new Map();
        sk.bones.forEach((b, k) => { const n = b.name.replace(/_\d+$/, ''), m = n.match(/^(Left|Right)Hand/); if (m) toFore.set(k, idx(m[1] + 'ForeArm')); });
        for (let v = 0; v < si.count; v++) for (let c = 0; c < 4; c++) {
          const get = ['getX', 'getY', 'getZ', 'getW'][c], set = ['setX', 'setY', 'setZ', 'setW'][c], b0 = si[get](v);
          if (toFore.has(b0)) si[set](v, toFore.get(b0));
        }
        si.needsUpdate = true;
        const bm = o.bindMatrix, bmi = o.bindMatrix.clone().invert(), P = new V3(), Cc = new V3(), AB = new V3();   // (bindMatrixInverse follows the live mesh)
        for (let v = 0; v < pos.count; v++) {
          let best = -1, wmax = 0;
          const ws = [sw.getX(v), sw.getY(v), sw.getZ(v), sw.getW(v)], is = [si.getX(v), si.getY(v), si.getZ(v), si.getW(v)];
          for (let c = 0; c < 4; c++) if (ws[c] > wmax) { wmax = ws[c]; best = is[c]; }
          let S = segs.find((q) => q.ia === best);
          if (!S) { const F = segs.find((q) => q.fore && q.ib === best); if (F) S = F; else continue; }
          P.fromBufferAttribute(pos, v).applyMatrix4(bm);
          AB.copy(S.Bp).sub(S.A); const t = clamp(P.clone().sub(S.A).dot(AB) / AB.lengthSq(), 0, 1);
          Cc.copy(S.A).addScaledVector(AB, t);
          const kk = S.fore ? lerp(S.k, 1, sstep(0.7, 1, t)) : S.k;               // no thinning at the cuff
          P.sub(Cc).multiplyScalar(lerp(1, kk, wmax)).add(Cc);
          if (S.fore) P.addScaledVector(AB, -0.045 * sstep(0.72, 1, t) / Math.sqrt(AB.lengthSq()));   // sleeve ends 4.5 cm earlier
          P.applyMatrix4(bmi);
          pos.setXYZ(v, P.x, P.y, P.z);
        }
        pos.needsUpdate = true; o.geometry.computeVertexNormals();
      });
      holder.rotation.y = Math.PI; holder.scale.setScalar(1.1);                // he faces forward (-z); arms long enough for the seat
      const wp = (b) => b.getWorldPosition(new V3()), wq = (b) => b.getWorldQuaternion(new THREE.Quaternion());
      // hands at a real size next to the 39 cm rim
      for (const s of ['Left', 'Right']) B[s + 'Hand'].scale.multiplyScalar(0.76);
      holder.updateMatrixWorld(true);
      // shoulders: centred on the wheel, just below and in front of the eye, close enough for relaxed arms
      // (elbows bent about 110 degrees and hanging down, like a driver at ease, not reaching with straight arms)
      const SC = new V3(WC.x, WC.y - 0.015, WC.z + 0.49), sc = wp(B.LeftArm).add(wp(B.RightArm)).multiplyScalar(0.5);
      holder.position.add(SC.clone().sub(sc)); holder.updateMatrixWorld(true);
      // hand frame at rest: hl wrist -> middle knuckle, ka little finger -> index, pn palm normal (toward the body)
      const frame = (s) => {
        const hp = wp(B[s + 'Hand']), hl = wp(B[s + 'HandMiddle1']).sub(hp).normalize();
        const ka = wp(B[s + 'HandIndex1']).sub(wp(B[s + 'HandPinky1'])); ka.addScaledVector(hl, -ka.dot(hl)).normalize();
        const pn = new V3().crossVectors(ka, hl); const toBody = new V3(SC.x, hp.y, hp.z).sub(hp); if (pn.dot(toBody) < 0) pn.negate();
        return { hl, ka, pn, kd: wp(B[s + 'HandMiddle1']).distanceTo(hp) };
      };
      const sides = ['Left', 'Right'].map((s, i) => {
        const arm = B[s + 'Arm'], fore = B[s + 'ForeArm'], hand = B[s + 'Hand'];
        const S0 = wp(arm), E0 = wp(fore), W0 = wp(hand);
        const u0 = E0.clone().sub(S0).normalize(), f0 = W0.clone().sub(E0).normalize(), n0 = new V3().crossVectors(u0, f0).normalize();
        const F = frame(s);
        // fingers: curled about the knuckle axis, joint by joint, so they wrap round the rim
        const kaxis = new V3().crossVectors(F.hl, F.pn).normalize();
        const curlB = (b, ang) => { const q = wq(b).invert(), ax = kaxis.clone().applyQuaternion(q).normalize(); b.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(ax, ang)); b.updateMatrixWorld(true); };
        const C = { Index: [72, 88, 62], Middle: [76, 90, 62], Ring: [78, 90, 60], Pinky: [80, 86, 56] };
        for (const f in C) for (let j = 1; j <= 3; j++) if (B[s + 'Hand' + f + j]) curlB(B[s + 'Hand' + f + j], C[f][j - 1] * Math.PI / 180);
        // the curled middle finger draws a circle: its centre is where the rim must run through the fist
        const J1 = wp(B[s + 'HandMiddle1']), J2 = wp(B[s + 'HandMiddle2']), J3 = wp(B[s + 'HandMiddle3']);
        const e1 = J2.clone().sub(J1), e2 = J3.clone().sub(J1), nn = new V3().crossVectors(e1, e2);
        const Cf = J1.clone().add(new V3().crossVectors(nn, e1).multiplyScalar(e2.lengthSq()).add(new V3().crossVectors(e2, nn).multiplyScalar(e1.lengthSq())).divideScalar(2 * nn.lengthSq()));
        const wv = W0.clone().sub(Cf), axial = wv.dot(kaxis), wperp = wv.clone().addScaledVector(kaxis, -axial), dw = wperp.length(); wperp.divideScalar(dw);
        const Arest = new THREE.Matrix4().makeBasis(kaxis, wperp, new V3().crossVectors(kaxis, wperp));
        // thumb: laid along the back of the rim (driver's side), reaching past the index finger, tip bent onto the rim
        if (B[s + 'HandThumb1'] && B[s + 'HandThumb4']) {
          const t1 = B[s + 'HandThumb1'], Pt = Cf.clone().addScaledVector(F.ka, 0.052).addScaledVector(wperp, 0.026).addScaledVector(F.pn, 0.004);
          const from = wp(B[s + 'HandThumb4']).sub(wp(t1)).normalize(), to = Pt.sub(wp(t1)).normalize();
          const qs = new THREE.Quaternion().setFromUnitVectors(from, to), qw = wq(t1);
          t1.quaternion.premultiply(t1.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(qs).multiply(t1.parent.getWorldQuaternion(new THREE.Quaternion())));
          t1.updateMatrixWorld(true);
          const tax = new V3().crossVectors(to, wperp).normalize();
          for (const j of [2, 3]) if (B[s + 'HandThumb' + j]) { const bj = B[s + 'HandThumb' + j], ax = tax.clone().applyQuaternion(wq(bj).invert()).normalize(); bj.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(ax, -0.18)); bj.updateMatrixWorld(true); }
        }
        const grip = i ? gripM(HAND) : gripM(-HAND), aT = new V3(i ? 1 : -1, 0, 0);
        return { arm, fore, hand, S: S0, Lu: S0.distanceTo(E0), Lf: E0.distanceTo(W0), u0, f0, n0, qA: wq(arm), qF: wq(fore), qH: wq(hand),
                 ArT: Arest.clone().transpose(), aT, axial, dw, beta: 0.9, grip, elb: null, pole: new V3(i ? 0.32 : -0.32, -0.92, 0.18).normalize() };
      });
      return { holder, sides, B };
    }
    const dM = new THREE.Matrix4(), dQ = new THREE.Quaternion(), dQ2 = new THREE.Quaternion(), dW = new V3(), dE = new V3();
    const dA = new V3(), dP = new V3(), dU = new V3(), dF = new V3(), dN = new V3(), dX = new V3(), dM1 = new THREE.Matrix4(), dM2 = new THREE.Matrix4();
    function solveDriver() {
      for (const A of DRV_A.sides) {
        // wrist target and hand orientation from the grip frame on the turning wheel
        dM.multiplyMatrices(wheelRot.matrixWorld, A.grip);
        if (A.elb) { dV.copy(A.elb).applyMatrix4(dM1.copy(dM).invert()); A.beta = clamp(Math.atan2(dV.z, dV.y), 0.6, 2.2); }
        const cb = Math.cos(A.beta), sb = Math.sin(A.beta);
        dX.set(0, cb, sb);                                                     // wrist direction from the rim, in the grip frame
        dW.copy(dX).multiplyScalar(A.dw).addScaledVector(A.aT, A.axial).applyMatrix4(dM);
        dM2.makeBasis(A.aT, dX, dV.crossVectors(A.aT, dX)).multiply(A.ArT);    // rest fist frame -> grip frame
        dM1.extractRotation(dM).multiply(dM2);
        dQ.setFromRotationMatrix(dM1).multiply(A.qH);                          // hand world rotation
        // two-bone arm: shoulder fixed, elbow placed with a pole that keeps it low and outside
        const S = A.S; dA.copy(dW).sub(S); let d = dA.length(); dA.divideScalar(d);
        d = clamp(d, Math.abs(A.Lu - A.Lf) + 1e-3, A.Lu + A.Lf - 1e-3);
        const a = (A.Lu * A.Lu - A.Lf * A.Lf + d * d) / (2 * d), h = Math.sqrt(Math.max(0, A.Lu * A.Lu - a * a));
        dP.copy(A.pole).addScaledVector(dA, -A.pole.dot(dA)).normalize();
        dE.copy(S).addScaledVector(dA, a).addScaledVector(dP, h); A.elb = (A.elb || new V3()).copy(dE);
        dU.copy(dE).sub(S).normalize(); dF.copy(S).addScaledVector(dA, d).sub(dE).normalize(); dN.crossVectors(dU, dF).normalize();
        // upper arm: the rest pair (direction, elbow hinge) turned onto the new pair
        dM1.makeBasis(A.u0, A.n0, dX.crossVectors(A.u0, A.n0)); dM2.makeBasis(dU, dN, dV.crossVectors(dU, dN));
        dM2.multiply(dM1.transpose());
        const qR1 = new THREE.Quaternion().setFromRotationMatrix(dM2), qArm = qR1.clone().multiply(A.qA);
        // forearm: after that turn it lies in the right plane, so only the elbow angle is left
        dV.copy(A.f0).applyQuaternion(qR1);
        const ang = Math.atan2(dX.crossVectors(dV, dF).dot(dN), dV.dot(dF));
        const qFore = dQ2.setFromAxisAngle(dN, ang).multiply(qR1).multiply(A.qF);
        // back to local rotations
        const pq = A.arm.parent.getWorldQuaternion(new THREE.Quaternion());
        A.arm.quaternion.copy(pq.invert().multiply(qArm));
        const qRel = qFore.clone().invert().multiply(dQ), ax = A.hand.position.clone().normalize();
        const pr = ax.dot(dX.set(qRel.x, qRel.y, qRel.z)), tw = new THREE.Quaternion(ax.x * pr, ax.y * pr, ax.z * pr, qRel.w).normalize();
        qFore.multiply(tw);                                                    // forearm takes the twist
        A.fore.quaternion.copy(qArm.clone().invert().multiply(qFore));
        A.hand.quaternion.copy(qFore.clone().invert().multiply(dQ));
      }
    }
    const makeRig = (c) => c.sh.map((s, i) => ({ sh: new V3(...s).add(eyeD), pole: new V3(...c.pole[i]).normalize(), lu: c.lu, lf: c.lf }));
    function elbowFor(r, w, out) {
      ikA.copy(w).sub(r.sh); const d0 = ikA.length(); ikA.divideScalar(d0);
      const d = clamp(d0, Math.abs(r.lu - r.lf) + 0.002, r.lu + r.lf - 0.002);
      const a = (r.lu * r.lu - r.lf * r.lf + d * d) / (2 * d), h = Math.sqrt(Math.max(0, r.lu * r.lu - a * a));
      ikP.copy(r.pole).addScaledVector(ikA, -r.pole.dot(ikA)).normalize();
      return out.copy(r.sh).addScaledVector(ikA, a).addScaledVector(ikP, h);
    }
    let tRead = 0, tScr = 0;
    function update(st) {
      if (!rigs) rigs = { land: makeRig(ARMS.land), port: makeRig(ARMS.port) };
      wheelRot.rotation.z = -st.wheel;
      wheelRot.position.set(st.wheelShake || 0, 0, 0);
      root.updateMatrixWorld(true);
      const rig = st.portrait ? rigs.port : rigs.land;
      if (DRV_A) solveDriver();
      else [sleeveL, sleeveR].forEach((m, i) => {
        // roll the hand around the rim so that its wrist points at the elbow (last frame's elbow is close enough)
        const H = hands[i];
        if (!H.elb) H.elb = rig[i].sh.clone().add(new V3(0, -0.22, -0.2));
        hInv.copy(H.hg.matrixWorld).invert(); hLoc.copy(H.elb).applyMatrix4(hInv);
        let want = Math.atan2(hLoc.z, hLoc.y) - BETA0; want = Math.atan2(Math.sin(want), Math.cos(want));
        H.rg.rotation.x = clamp(want, -1.1, 0.75); H.rg.updateMatrixWorld(true);
        wristW.copy(wristLocal).applyMatrix4(H.rg.matrixWorld);
        elbowFor(rig[i], wristW, elbW); H.elb.copy(elbW);
        m.position.copy(wristW); m.lookAt(elbW); m.scale.set(1, 1, wristW.distanceTo(elbW));
        upper[i].position.copy(elbW); upper[i].lookAt(rig[i].sh); upper[i].scale.set(1, 1, elbW.distanceTo(rig[i].sh));
        elbowM[i].position.copy(elbW);
      });
      for (const n of needles) {
        const v = n.rpm ? clamp(st.rpm / 1000, 0, 8) : clamp(st.kmh, 0, 320), a = A0 + (A1 - A0) * v / n.max;
        n.piv.rotation.z = -(a + Math.PI / 2);
      }
      tRead -= st.dt; tScr -= st.dt;
      if (tRead <= 0) { tRead = 0.08; drawReadout(Math.round(st.kmh), st.gear, st.nitro, st.clock, st.nitroOn); }
      if (tScr <= 0 && !XI) { tScr = 0.3; drawScreen(st.dist, Math.round(st.kmh)); }
      if (st.sun) sunL.position.copy(sunL.target.position).addScaledVector(st.sun, 4);
    }
    drawReadout(0, 'N', 0.5, '0:00', false); drawScreen(0, 0);
    const dispose = () => scene.traverse((o) => {
      if (o.geometry) o.geometry.dispose();
      if (o.material) for (const k of ['map', 'normalMap', 'emissiveMap']) { if (o.material[k]) o.material[k].dispose(); }
      if (o.material) o.material.dispose();
    });
    if (DRV_A) { for (const H of hands) H.hg.visible = false; for (const m of [sleeveL, sleeveR, ...upper, ...elbowM]) m.visible = false; }
    return { scene, cam, root, EYE, view, hands, driver: DRV_A, update, mirrorMat, setShadowSize, sunL, wheelRot, dispose, imported: !!XI };
  }
