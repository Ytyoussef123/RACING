
    const mirrorUV = (g, u0, u1, v0, v1) => { const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, lerp(u0, u1, uv.getX(i)), lerp(v0, v1, uv.getY(i))); return g; };
    let mirrorGlass = null, rearFrame = null, rearFrameTex = null, sideGlass = [], band = null, bandTex = null;
    if (!XI) {
    // ---- doors (left built, right mirrored) ----
    {
      const flatP = [[-0.805, 0.32], [-0.802, 0.46], [-0.792, 0.58], [-0.786, 0.63], [-0.783, 0.67], [-0.781, 0.71], [-0.779, 0.76], [-0.777, 0.82], [-0.779, 0.88], [-0.782, 0.925], [-0.797, 0.953], [-0.828, 0.962], [-0.858, 0.952]];
      const armP = [[-0.805, 0.32], [-0.80, 0.48], [-0.772, 0.588], [-0.728, 0.616], [-0.718, 0.652], [-0.742, 0.684], [-0.768, 0.72], [-0.776, 0.80], [-0.779, 0.88], [-0.782, 0.925], [-0.797, 0.953], [-0.828, 0.962], [-0.858, 0.952]];
      const door = param(64, 36, (u, v, o) => {
        const z = lerp(-1.0, 0.8, u), a = sstep(-0.62, -0.42, z) * (1 - sstep(0.5, 0.7, z));
        const P = flatP.map((q, k) => [lerp(q[0], armP[k][0], a), q[1]]), q = crEval(P, v);
        const front = sstep(-0.78, -1.0, z);                       // door meets the dash end
        o.set(q[0] - front * 0.02, q[1], z);
      }, { su: 12, sv: 5, flip: true });
      const ao = (P) => (0.3 + 0.7 * sstep(0.45, 0.92, P.y)) * lerp(0.6, 1, sstep(-0.98, -0.8, P.z));
      add('dash', shade(door, ao)); add('dash', shade(mirrorX(door), ao));
      // suede insert and chrome handle on each door
      const ins = param(50, 10, (u, v, o) => { const z = lerp(-0.5, 0.45, u), y = lerp(0.73, 0.875, v); o.set(-0.772 + 0.002 * Math.sin(v * Math.PI), y, z); }, { su: 6, sv: 1.2, flip: true });
      add('suede', shade(ins, () => 0.9)); add('suede', shade(mirrorX(ins), () => 0.9));
      const handle = new THREE.CylinderGeometry(0.009, 0.009, 0.11, 10).rotateX(Math.PI / 2);
      for (const s of [1, -1]) add('chrome', xf(handle.clone(), M4(new V3(s * 0.755, 0.79, -0.33))));
    }

    // ---- A-pillars, roof header, rails, headliner, visors ----
    const pillarL = cr3([[-0.795, 0.935, -1.04], [-0.758, 1.075, -0.76], [-0.716, 1.192, -0.52], [-0.672, 1.262, -0.31]]);
    const pillar = sweep(pillarL, 40, 20, (u, a) => [(0.036 - u * 0.004) * (Math.cos(a) > 0 ? 0.75 : 1), 0.068 - u * 0.012], { su: 3, sv: 1 });
    const pAo = (P) => 0.75 + 0.25 * sstep(0.95, 1.2, P.y);
    add('suede', shade(pillar, pAo)); add('suede', shade(mirrorX(pillar), pAo));
    const header = sweep(cr3([[-0.69, 1.258, -0.305], [0, 1.27, -0.335], [0.69, 1.258, -0.305]]), 40, 14, () => [0.06, 0.03], { ref: new V3(0, 0, 1), su: 6 });
    add('suede', shade(header, () => 0.8));
    const rail = sweep(cr3([[-0.672, 1.262, -0.31], [-0.69, 1.268, 0.2], [-0.69, 1.27, 0.8]]), 24, 12, () => [0.035, 0.042], { ref: new V3(1, 0, 0), su: 5 });
    add('suede', shade(rail, () => 0.8)); add('suede', shade(mirrorX(rail), () => 0.8));
    add('suede', shade(param(20, 24, (u, v, o) => { const x = lerp(-0.70, 0.70, u); o.set(x, 1.279 + 0.014 * (1 - (x / 0.7) ** 2), lerp(-0.31, 0.9, v)); }, { su: 8, sv: 8 }), () => 0.75));
    for (const s of [-1, 1]) add('suede', xf(slab(rrect(0.34, 0.15, 0.03), 0.018, 0.006), M4(new V3(s * 0.36, 1.246, -0.205), [Math.PI / 2, 0, 0])));
    // window "sail" triangles where the door mirrors mount
    {
      const tri = new THREE.Shape(); tri.moveTo(0, 0); tri.lineTo(0.2, 0); tri.lineTo(0.02, 0.13); tri.lineTo(0, 0);
      for (const s of [-1, 1]) add('plastic', shade(xf(slab(tri, 0.012, 0.004), M4(new V3(s * 0.785, 0.95, -0.99), [0, -Math.PI / 2, 0])), () => 0.7));
    }

    // ---- rear-view mirror with a live image of the road behind ----
    const mirror = new THREE.Group();
    mirror.position.set(0.0, 1.19, -0.35);
    mirror.lookAt(new V3(DRV, 1.13, 0.30));
    mirror.updateMatrix();
    add('rubber', xf(slab(rrect(0.27, 0.078, 0.032), 0.03, 0.006), mirror.matrix));
    add('rubber', xf(new THREE.CylinderGeometry(0.008, 0.01, 0.07, 8).translate(0, 0.045, -0.02), mirror.matrix));
    add('rubber', xf(new THREE.BoxGeometry(0.06, 0.02, 0.07), M4(new V3(0, 1.262, -0.36))));
    mirrorGlass = xf(mirrorUV(new THREE.PlaneGeometry(0.256, 0.066).translate(0, 0, 0.0215), 0, 1, 0, 1), mirror.matrix);
    // rear window outline seen in the mirror (rear pillars, headrests)
    rearFrameTex = tex(cv(512, 128, (x, w, h) => {
      x.clearRect(0, 0, w, h); x.fillStyle = 'rgba(14,15,17,0.97)';
      x.beginPath(); x.rect(0, 0, w, h); x.moveTo(44, 18); x.quadraticCurveTo(256, 4, 468, 18); x.lineTo(500, 122); x.lineTo(12, 122); x.closePath(); x.fill('evenodd');
      x.fillStyle = 'rgba(20,21,24,0.98)';
      for (const cx of [120, 392]) { x.beginPath(); x.ellipse(cx, 128, 62, 34, 0, Math.PI, 0); x.fill(); }
      x.fillRect(0, 116, w, 12);
    }), { clamp: true });
    rearFrame = xf(new THREE.PlaneGeometry(0.256, 0.066).translate(0, 0, 0.0222), mirror.matrix);

    // ---- door mirrors (body colour) ----
    sideGlass = [];
    for (const s of [-1, 1]) {
      const c = new V3(s * 1.0, 0.985, -0.63);
      const shell = param(24, 16, (u, v, o) => {
        const a = u * Math.PI * 2, b = v * Math.PI * 0.485;              // half ellipsoid opening backwards
        o.set(c.x + Math.cos(a) * Math.cos(b) * 0.088, c.y + Math.sin(a) * Math.cos(b) * 0.056, c.z - Math.sin(b) * 0.07);
      }, { closeU: true, flip: true });
      add('paint', shell);
      add('rubber', xf(new THREE.BoxGeometry(0.12, 0.03, 0.05), M4(new V3(s * 0.9, 0.955, -0.63))));
      const gl = mirrorUV(new THREE.PlaneGeometry(0.16, 0.098), s < 0 ? 0.0 : 0.62, s < 0 ? 0.38 : 1.0, 0.15, 0.85);
      gl.applyMatrix4(M4(new V3(c.x, c.y, c.z + 0.002), [0, -s * 0.42, 0]));
      sideGlass.push(gl);
    }

    // ---- windshield shade band (top tint) ----
    bandTex = tex(cv(8, 128, (x, w, h) => { const g = x.createLinearGradient(0, 0, 0, h); g.addColorStop(0, 'rgba(40,70,95,0.62)'); g.addColorStop(0.16, 'rgba(40,70,95,0.30)'); g.addColorStop(0.24, 'rgba(40,70,95,0)'); g.addColorStop(1, 'rgba(40,70,95,0)'); x.fillStyle = g; x.fillRect(0, 0, w, h); }), { clamp: true });
    band = param(24, 4, (u, v, o) => { const x = lerp(-0.72, 0.72, u), vv = lerp(0.72, 1, v); o.set(x, lerp(0.915, 1.262, vv), lerp(-1.10, -0.31, vv) + 0.06 * (x / 0.72) ** 2 - 0.012); });
    }
