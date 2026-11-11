// floating joystick: touch in the lower left, slide by 10 %, 30 % and 100 % of the travel; landscape and turned portrait
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const [name, dev] of [['land', devices['Pixel 7 landscape']], ['port', devices['Pixel 7']], ['chrome1610', { viewport: { width: 1610, height: 720 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, userAgent: devices['Pixel 7'].userAgent }]]) {
    if (process.argv[2] && process.argv[2] !== name) continue;
    const p = await (await b.newContext({ ...dev })).newPage(); const errs = [];
    p.on('pageerror', e => errs.push('pageerror ' + e.message));
    p.on('console', m => { if (m.type() === 'error' && !m.text().includes('GPU stall') && !m.text().includes('stylesheet')) errs.push(m.text().slice(0, 160)); });
    await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '0'); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')) && (!window.__CARS || __CARS.every((c) => c.ready || c.failed)), null, { timeout: 150000 });
    await p.waitForTimeout(1500);
    // (V30: the car park opens with all its cars; on the 1610 px screen the software renderer draws it in about 1.4 s a
    // picture, and a click takes several pictures: more time for it)
    await p.click('#playBtn', { timeout: 120000 }); await p.waitForTimeout(300);
    if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
    await p.evaluate(() => { __S.traffic.forEach(c => __scene.remove(c)); __S.traffic.length = 0; __S.speed = 120 / 3.6; __S.gear = 4; __S.x = 1.75; });
    const g = await p.evaluate(() => { const z = document.getElementById('touchL'), r = z.getBoundingClientRect(); return { r: [r.left, r.top, r.right, r.bottom], w: z.offsetWidth, h: z.offsetHeight, R: __joyFull / 1.3, cls: document.getElementById('stage').className }; });
    const cw = g.cls.includes('rot') && g.cls.includes('cw') && !g.cls.includes('ccw');
    const scr = (lx, ly) => cw ? [g.r[2] - ly, g.r[1] + lx] : [g.r[0] + lx, g.r[1] + ly];   // local -> screen
    const lx0 = g.w * 0.45, ly0 = g.h * 0.6, out = [];
    await p.mouse.move(...scr(lx0, ly0)); await p.mouse.down();
    const placed = await p.evaluate(() => { const j = document.getElementById('joy'); return [j.style.left, j.style.top, j.classList.contains('on')]; });
    for (const f of [-0.1, -0.3, 1.0, 1.12, 1.32]) {
      const steps = 8; for (let k = 1; k <= steps; k++) await p.mouse.move(...scr(lx0 + f * g.R * k / steps, ly0 + 3));
      await p.waitForTimeout(350);
      out.push(f + ': ' + JSON.stringify(await p.evaluate(() => ({ axis: +__input.axis.toFixed(3), steer: +__S.steer.toFixed(3), lat: +__S.lat.toFixed(2) }))));
    }
    await p.screenshot({ path: `fj-${name}.png` });
    await p.mouse.up(); await p.waitForTimeout(400);
    const after = await p.evaluate(() => ({ axisOn: __input.axisOn, steer: +__S.steer.toFixed(3), lat: +__S.lat.toFixed(2), joyLeft: document.getElementById('joy').style.left || 'home' }));
    const sz = await p.evaluate(() => ({ full: Math.round(__joyFull), joy: document.getElementById('joy').offsetWidth, knob: document.getElementById('joyKnob').offsetWidth, gas: document.querySelector('.tbtn.gas').offsetHeight, brake: document.querySelector('.tbtn.brake').offsetWidth }));
    console.log(name, JSON.stringify(sz), g.cls || '(no turn)', 'stick placed at', JSON.stringify(placed), '|', out.join(' | '), '| released', JSON.stringify(after), errs.length ? 'ERRORS ' + errs.join(' | ') : 'no errors');
    await p.context().close();
  }
  await b.close(); srv.close();
})();
