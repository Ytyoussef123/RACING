// V30: the loading screen (shown at once, nothing drawn behind it while loading, gone when ready); the stick keeps its
// thumb when another finger touches the left of the screen (real multi-touch through the browser's touch events), and a
// new touch takes it once that thumb is up; no slow motion on a touch screen on a very close pass at full speed (the
// bonus stays), still slow motion on a computer. Phone landscape, then a desktop window for the slow motion.
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const errs = [], out = {};
  const watch = (p) => { p.on('pageerror', (e) => errs.push('pageerror ' + e.message)); p.on('console', (m) => { if (m.type() === 'error' && !/fonts.googleapis/.test(m.text())) errs.push(m.text().slice(0, 160)); }); };
  // a very close pass at 160 km/h: a car just about to be passed, 0.3 m beside us
  const closePass = (p) => p.evaluate(() => {
    const S = __S; S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0;
    for (let i = 0; i < 40 && !S.traffic.length; i++) __update(1 / 60);
    const c = S.traffic[0], u = c.userData; S.traffic.length = 1;
    S.speed = 160 / 3.6; S.slowCd = 0; S.slowmo = 0; S.x = 1.75; S.lat = 0;
    c.position.set(S.x + (u.w + 1.9) / 2 + 0.3, -0.02, (u.l + 4.4) / 2 - 0.3); u.speed = u.cruise = 60 / 3.6; u.change = 0; u.lane = 3; u.laneX = c.position.x; u.passed = false;
    const near0 = S.near; let slow = 0;
    for (let i = 0; i < 6; i++) { __update(1 / 60); slow = Math.max(slow, S.slowmo); }
    return { passed: u.passed, near: S.near - near0, slowmo: +slow.toFixed(2) };
  });
  try {
    // the loading screen and the stick, on a phone
    const ctx = await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 });
    const p = await ctx.newPage(); watch(p);
    await p.addInitScript(() => { try { localStorage.clear(); } catch (e) {} });
    await p.route('**/models/car-hero.json', async (r) => { await new Promise((ok) => setTimeout(ok, 4000)); r.continue(); });   // (a slow network: loading lasts)
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => window.__renderer, null, { timeout: 60000 });
    const ld = () => p.evaluate(() => { const l = document.getElementById('loading'); return { shown: !l.hidden && !l.classList.contains('out'), frames: __renderer.info.render.frame, ready: document.getElementById('playBtn').dataset.ready === '1', pct: document.getElementById('ldPct').textContent }; });
    const l0 = await ld(); await p.waitForTimeout(1500); const l1 = await ld(); await p.screenshot({ path: 'loading-phone.png' });
    out.loading = { atStart: l0.shown, stillLoading: !l1.ready, framesWhileLoading: l1.ready ? null : l1.frames - l0.frames, pct: l1.pct };
    await p.waitForFunction(() => document.getElementById('playBtn').dataset.ready === '1', null, { timeout: 150000 });
    out.loading.letsTouchesThrough = await p.evaluate(() => getComputedStyle(document.getElementById('loading')).pointerEvents === 'none');
    out.loading.goneWhenReady = await p.waitForFunction(() => document.getElementById('loading').hidden, null, { timeout: 10000 }).then(() => true, () => false);
    await p.waitForFunction(() => __CARS.every((c) => c.ready), null, { timeout: 150000 }); await p.waitForTimeout(800);
    await p.click('#playBtn'); await p.waitForTimeout(400);
    if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
    await p.evaluate(() => { __S.traffic.forEach((c) => __scene.remove(c)); __S.traffic.length = 0; __S.speed = 120 / 3.6; });
    const cdp = await ctx.newCDPSession(p);
    const zone = await p.evaluate(() => { const r = document.getElementById('touchL').getBoundingClientRect(); return [r.left, r.top, r.width, r.height, __joyFull / 1.3]; });
    const [zx, zy, zw, zh, R] = zone, A0 = [zx + zw * 0.45, zy + zh * 0.6], B = [zx + zw * 0.12, zy + zh * 0.25];
    const touch = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map(([x, y, id]) => ({ x, y, id })) });
    const st = () => p.evaluate(() => ({ axis: +__input.axis.toFixed(2), on: __input.axisOn, left: document.getElementById('joy').style.left }));
    await touch('touchStart', [[A0[0], A0[1], 1]]);
    for (let k = 1; k <= 6; k++) await touch('touchMove', [[A0[0] + R * 0.6 * k / 6, A0[1], 1]]);
    await p.waitForTimeout(600); const s1 = await st();
    await touch('touchStart', [[A0[0] + R * 0.6, A0[1], 1], [B[0], B[1], 2]]);           // another finger on the left
    await p.waitForTimeout(250); const s2 = await st();
    for (let k = 1; k <= 4; k++) await touch('touchMove', [[A0[0] + R * (0.6 + 0.6 * k / 4), A0[1], 1], [B[0], B[1], 2]]);
    await p.waitForTimeout(250); const s3 = await st();
    await touch('touchEnd', [[A0[0] + R * 1.2, A0[1], 1]]);                              // the thumb lifts (finger 2 stays: the list is what is released)
    await p.waitForTimeout(250); const s4 = await st();
    await touch('touchMove', [[B[0] + R, B[1], 2]]); await p.waitForTimeout(250); const s5 = await st();
    await touch('touchEnd', []);
    await touch('touchStart', [[A0[0], A0[1], 3]]);                                      // a new touch: takes the stick
    for (let k = 1; k <= 4; k++) await touch('touchMove', [[A0[0] - R * 0.5 * k / 4, A0[1], 3]]);
    await p.waitForTimeout(250); const s6 = await st();
    await touch('touchEnd', []);
    out.stick = { thumb: s1, secondFinger: s2, thumbMovesOn: s3, thumbUp: s4, otherFingerMoves: s5, newTouch: s6 };
    out.phonePass = await closePass(p);
    await ctx.close();
    // the slow motion is still there on a computer
    const p2 = await (await b.newContext({ viewport: { width: 1280, height: 720 } })).newPage(); watch(p2);
    await p2.goto(url + 'test4.html');
    await p2.waitForFunction(() => document.getElementById('playBtn').dataset.ready === '1' && __CARS.every((c) => c.ready), null, { timeout: 150000 });
    await p2.waitForTimeout(800); await p2.click('#playBtn'); await p2.waitForTimeout(400);
    out.deskPass = await closePass(p2);
    await p2.context().close();
  } catch (e) { console.log('FAIL at', e.message.split('\n')[0], JSON.stringify(out), errs.join(' | ')); await b.close(); srv.close(); return; }
  const L = out.loading, T = out.stick;
  const ok = L.atStart && L.letsTouchesThrough && L.goneWhenReady && (L.framesWhileLoading === null || L.framesWhileLoading <= 2)
    && T.thumb.on && T.thumb.axis > 0.3 && T.secondFinger.left === T.thumb.left && T.secondFinger.axis >= T.thumb.axis
    && T.thumbMovesOn.axis > T.thumb.axis && !T.thumbUp.on && T.thumbUp.axis === 0 && T.otherFingerMoves.axis === 0
    && T.newTouch.on && T.newTouch.axis < -0.2
    && out.phonePass.passed && out.phonePass.near === 1 && out.phonePass.slowmo === 0 && out.deskPass.passed && out.deskPass.slowmo > 0;
  console.log(ok ? 'PASS' : 'FAIL', JSON.stringify(out), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
