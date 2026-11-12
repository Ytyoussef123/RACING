// t57 (V32): steering at high speed on a phone.
// A. the bend's push: with the stick it stops growing at 0.8 m/s (200 km/h in the tightest bend: the car held straight
//    drifts out at 0.8 m/s, and full stick into the bend still moves it at about 6 m/s); with the keyboard it is as
//    before (about 3 m/s out, 3.8 m/s in); at 100 km/h both are the same.
// B. traffic: a car ahead does not start a lane change into the player's lane when the player is on it in less than
//    5 s; it does when far ahead, or into another lane.
// C. a touch outlives a lost focus: stick and gas held, the window loses focus: both stay on and the stick still
//    steers; lifting the fingers releases them.
// Phone landscape.
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const errs = [], out = {};
  try {
    const ctx = await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 });
    const p = await ctx.newPage();
    p.on('pageerror', (e) => errs.push('pageerror ' + e.message)); p.on('console', (m) => { if (m.type() === 'error' && !/fonts.googleapis/.test(m.text())) errs.push(m.text().slice(0, 160)); });
    await p.addInitScript(() => { try { localStorage.clear(); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => document.getElementById('playBtn').dataset.ready === '1' && __CARS.every((c) => c.ready), null, { timeout: 200000 });
    await p.waitForFunction(() => document.getElementById('loading').hidden, null, { timeout: 20000 });
    await p.click('#playBtn', { timeout: 120000 }); await p.waitForFunction(() => __S.mode === 'play' && __S.time > 0.05, null, { timeout: 120000 });
    // A
    out.bend = await p.evaluate(() => {
      const S = __S; let dPeak = 0, kPeak = 0;
      for (let d = 0; d < 7500; d += 5) { const k = __ROUTE.k(d); if (Math.abs(k) > Math.abs(kPeak)) { kPeak = k; dPeak = d; } }
      const held = (kmh, analog, axis) => {                  // lateral speed once settled, the car held at that place and speed
        S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0;
        S.x = 0; S.lat = 0; S.steer = 0; S.steerV = 0; S.analog = analog; __input.left = __input.right = false; __input.axisOn = analog; __input.axis = axis;
        if (!analog && axis) __input[axis > 0 ? 'right' : 'left'] = true;
        for (let i = 0; i < 90; i++) { S.dist = dPeak; S.speed = kmh / 3.6; S.x = 0; S.mode = 'play'; __update(1 / 60); S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0; }
        __input.left = __input.right = false; __input.axisOn = false; __input.axis = 0;
        return +S.lat.toFixed(2);
      };
      const inward = Math.sign(kPeak);                       // (k > 0: a right bend, pushing left: steer right to go in)
      return { kPeak: +kPeak.toFixed(4), stick200: held(200, true, 0), stick200in: held(200, true, inward), keys200: held(200, false, 0), keys200in: held(200, false, inward), stick100: held(100, true, 0), keys100: held(100, false, 0) };
    });
    // B
    out.cut = await p.evaluate(() => {
      const S = __S, LANES = [-5.25, -1.75, 1.75, 5.25], rnd = Math.random;
      const tryChange = (playerLane, carLane, z) => {
        S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0; S.dist = 100;
        Math.random = rnd; for (let i = 0; i < 200 && !S.traffic.some((c) => c.userData.inst && c.userData.inst.tpl === 0); i++) { S.speed = 30; __update(1 / 60); }
        const c = S.traffic.find((q) => q.userData.inst && q.userData.inst.tpl === 0), u = c.userData;
        S.traffic.forEach((q) => { if (q !== c) __scene.remove(q); }); S.traffic.length = 0; S.traffic.push(c);
        S.x = LANES[playerLane]; S.lat = 0; S.speed = 200 / 3.6; S.mode = 'play';
        c.position.set(LANES[carLane], c.position.y, z); u.lane = carLane; u.laneX = LANES[carLane]; u.change = 0; u.speed = u.cruise = 70 / 3.6;
        Math.random = () => 0;                               // (a change is tried, toward the lane on the left)
        try { __update(1 / 60); } finally { Math.random = rnd; }
        return u.change;
      };
      return { intoPlayerNear: tryChange(2, 3, -100), intoPlayerFar: tryChange(2, 3, -300), intoOtherLane: tryChange(3, 2, -100) };
    });
    // C
    await p.evaluate(() => { __S.traffic.forEach((c) => __scene.remove(c)); __S.traffic.length = 0; __S.speed = 80 / 3.6; __S.x = 1.75; __S.dist = 100; __S.mode = 'play'; });
    const cdp = await ctx.newCDPSession(p);
    const geo = await p.evaluate(() => { const r = document.getElementById('touchL').getBoundingClientRect(), g = document.querySelector('.tbtn.gas').getBoundingClientRect(); return { sx: r.left + r.width * 0.45, sy: r.top + r.height * 0.6, gx: g.left + g.width / 2, gy: g.top + g.height / 2, R: __joyFull / 1.3 }; });
    const touch = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map(([x, y, id]) => ({ x, y, id })) });
    const st = () => p.evaluate(() => ({ axisOn: __input.axisOn, axis: +__input.axis.toFixed(2), gas: __input.gas, mode: __S.mode }));
    await touch('touchStart', [[geo.sx, geo.sy, 1]]);
    await touch('touchStart', [[geo.sx, geo.sy, 1], [geo.gx, geo.gy, 2]]);
    await touch('touchMove', [[geo.sx + geo.R * 0.5, geo.sy, 1], [geo.gx, geo.gy, 2]]);
    await p.waitForFunction(() => __input.axis > 0.2 && __input.gas, null, { timeout: 20000 }).catch(() => {});
    const before = await st();
    await p.evaluate(() => window.dispatchEvent(new Event('blur'))); await p.waitForTimeout(200);
    const afterBlur = await st();
    await touch('touchMove', [[geo.sx - geo.R * 0.6, geo.sy, 1], [geo.gx, geo.gy, 2]]);
    await p.waitForFunction(() => __input.axis < -0.2, null, { timeout: 20000 }).catch(() => {});   // (the software renderer delivers the move late)
    const moved = await st();
    await touch('touchEnd', [[geo.sx - geo.R * 0.6, geo.sy, 1], [geo.gx, geo.gy, 2]]);
    await p.waitForFunction(() => !__input.axisOn && !__input.gas, null, { timeout: 20000 }).catch(() => {});
    out.blur = { before, afterBlur, moved, released: await st() };
    await ctx.close();
  } catch (e) { console.log('FAIL at', e.message.split('\n')[0], JSON.stringify(out), errs.join(' | ')); await b.close(); srv.close(); return; }
  const B = out.bend, C = out.cut, L = out.blur, near = (a, v, tol) => Math.abs(Math.abs(a) - v) <= tol;
  const ok = near(B.stick200, 0.8, 0.05) && Math.abs(B.stick200in) > 5.8 && near(B.keys200, 0.3 * Math.abs(B.kPeak) * Math.pow(200 / 3.6, 2), 0.1) && Math.abs(B.keys200in) < 4.2
    && near(B.stick100, Math.abs(B.keys100), 0.03) && Math.abs(B.stick100) < 0.8
    && C.intoPlayerNear === 0 && C.intoPlayerFar === 1 && C.intoOtherLane === 1
    && L.before.axisOn && L.before.axis > 0.2 && L.before.gas && L.afterBlur.axisOn && L.afterBlur.axis === L.before.axis && L.afterBlur.gas && L.afterBlur.mode === 'play'
    && L.moved.axis < -0.2 && L.moved.gas && !L.released.axisOn && L.released.axis === 0 && !L.released.gas;
  console.log(ok ? 'PASS' : 'FAIL', JSON.stringify(out), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
