// car park (V27): the three cars. Load, wait for the two other cars to come out from under their covers, swipe to
// the Giulia, ← → keys, drive the Giulia (it is the car on the road, its brake lights work), pause -> car park,
// drive the R34, then the game over screen. Phone landscape, desktop, narrow window, phone held upright.
// Screenshots: park-<screen>-a (car park), -b (Giulia shown), -c (Giulia driving, chase view), -d (R34 driving), -e (game over)
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const confs = [
    ['phone', { ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 }],
    ['desk', { viewport: { width: 1280, height: 720 } }],
    ['narrow', { viewport: { width: 420, height: 760 } }],
    ['phoneUp', { ...devices['Pixel 7'], deviceScaleFactor: 1 }],
  ];
  const card = (p) => p.evaluate(() => ({ name: document.getElementById('carName').textContent, btn: document.getElementById('playBtn').textContent, dis: document.getElementById('playBtn').disabled }));
  for (const [name, ctx] of confs) {
    if (process.argv[2] && process.argv[2] !== name) continue;
    const p = await (await b.newContext(ctx)).newPage(); const errs = [];
    p.on('pageerror', e => errs.push('pageerror ' + e.message)); p.on('console', m => { if (m.type() === 'error' && !/fonts.googleapis/.test(m.text())) errs.push(m.text()); });
    await p.addInitScript(() => { try { localStorage.removeItem('corniche-car'); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
    await p.waitForFunction(() => __CARS.every((c) => c.ready), null, { timeout: 150000 });
    await p.waitForTimeout(4000);
    await p.screenshot({ path: `park-${name}-a.png` });
    const vp = p.viewportSize(), rot = await p.evaluate(() => document.getElementById('stage').classList.contains('rot'));
    // swipe toward the left of the stage (from 70 % to 25 % of its width); a turned stage runs along the screen's height
    const from = rot ? [vp.width * 0.5, vp.height * 0.7] : [vp.width * 0.7, vp.height * 0.45], to = rot ? [vp.width * 0.5, vp.height * 0.25] : [vp.width * 0.25, vp.height * 0.45];
    await p.mouse.move(...from); await p.mouse.down(); await p.mouse.move(...to, { steps: 8 }); await p.mouse.up();
    await p.waitForTimeout(2500);
    const s1 = await card(p);
    await p.screenshot({ path: `park-${name}-b.png` });
    await p.keyboard.press('ArrowRight'); await p.waitForTimeout(200);
    const s2 = await card(p);
    await p.keyboard.press('ArrowLeft'); await p.waitForTimeout(1500);
    // drive the Giulia, seen from behind
    await p.click('#playBtn'); await p.waitForTimeout(600);
    if (await p.evaluate(() => __S.cam) !== 'chase') await p.click('#camBtn');
    await p.evaluate(() => { __S.traffic.forEach(c => __scene.remove(c)); __S.traffic.length = 0; __S.speed = 110 / 3.6; __S.gear = 4; __input.brake = true; });
    await p.waitForTimeout(400);
    const giulia = await p.evaluate(() => ({ mode: __S.mode, car: __S.car, onRoad: __CARS[1].root.parent === __scene, others: [0, 2].map((i) => !!(__CARS[i].root && __CARS[i].root.parent === __scene)), braking: __CARS[1].root.userData.braking, tails: __CARS[1].root.userData.tails.length, hud: !document.querySelector('.hud').hidden }));
    await p.evaluate(() => { __input.brake = false; }); await p.waitForTimeout(600);
    await p.screenshot({ path: `park-${name}-c.png` });
    // back to the car park, then the R34
    await p.click('#pauseBtn'); await p.waitForTimeout(300); await p.click('#pauseGarage'); await p.waitForTimeout(1200);
    const back = await p.evaluate(() => ({ mode: __S.mode, hud: !document.querySelector('.hud').hidden, name: document.getElementById('carName').textContent }));
    await p.keyboard.press('ArrowRight'); await p.waitForTimeout(1200);
    await p.click('#playBtn'); await p.waitForTimeout(600);
    await p.evaluate(() => { __S.traffic.forEach(c => __scene.remove(c)); __S.traffic.length = 0; __S.speed = 110 / 3.6; __S.gear = 4; });
    await p.waitForTimeout(800);
    const r34 = await p.evaluate(() => ({ car: __S.car, onRoad: __CARS[2].root.parent === __scene, giuliaGone: __CARS[1].root.parent !== __scene, wheelsTurn: __CARS[2].wheels.length }));
    await p.screenshot({ path: `park-${name}-d.png` });
    await p.evaluate(() => { __S.crashT = 0.01; __S.mode = 'crash'; });
    await p.waitForTimeout(800);
    await p.screenshot({ path: `park-${name}-e.png` });
    const over = await p.evaluate(() => !document.getElementById('overScreen').hidden);
    const stored = await p.evaluate(() => localStorage.getItem('corniche-car'));
    const ok = s1.name === 'GIULIA GTAm' && s1.btn === 'JOUER' && !s1.dis && s2.name === 'SKYLINE R34' && giulia.mode === 'play' && giulia.car === 1 && giulia.onRoad && !giulia.others.some(Boolean)
      && giulia.braking && giulia.tails > 0 && back.mode === 'menu' && !back.hud && back.name === 'GIULIA GTAm' && r34.car === 2 && r34.onRoad && r34.giuliaGone && r34.wheelsTurn === 4 && over && stored === 'r34';
    console.log(name, ok ? 'PASS' : 'FAIL', JSON.stringify({ rot, s1, s2, giulia, back, r34, over, stored }), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
    await p.context().close();
  }
  await b.close(); srv.close();
})();
