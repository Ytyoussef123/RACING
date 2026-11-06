// curve driving at 200 km/h (fixed steps) + draw calls per frame (all passes), new build vs V20
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const page of (process.argv[2] ? process.argv[2].split(',') : ['test-v20.html', 'test4.html'])) {
    const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage(); const errs = [];
    p.on('pageerror', e => errs.push(e.message));
    await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '0'); } catch (e) {} });
    await p.goto(url + page);
    await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
    await p.click('#playBtn'); await p.waitForTimeout(400);
    if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
    await p.waitForTimeout(800);
    const calls = await p.evaluate(() => new Promise(res => { const R = __renderer; R.info.autoReset = false; R.info.reset(); let n = 0;
      const tick = () => { if (++n < 5) return requestAnimationFrame(tick); const c = R.info.render.calls / 4, t = R.info.render.triangles / 4; R.info.autoReset = true; res({ callsPerFrame: Math.round(c), trisPerFrame: Math.round(t) }); };
      requestAnimationFrame(() => { R.info.reset(); requestAnimationFrame(tick); }); }));
    let drive = null;
    if (page === 'test4.html') drive = await p.evaluate(() => {
      const S = __S, I = __input, out = [];
      const run = (sec) => { for (let i = 0; i < Math.round(sec * 60); i++) { S.traffic.length = 0; __update(1 / 60); } };
      for (const [name, d0, ax] of [['big left bend (La Sqala)', 2300, 0], ['big left bend (La Sqala)', 2300, -0.3], ['S-bend left (Bd des Almohades)', 1140, -0.45], ['El Hank', 5500, -0.33]]) {
        S.traffic.forEach(c => __scene.remove(c)); S.traffic.length = 0;
        Object.assign(S, { dist: d0, speed: 200 / 3.6, gear: 6, x: 1.75, lat: 0, steer: 0, steerV: 0 }); I.gas = true; I.axisOn = ax !== 0; I.axis = ax;
        run(2); out.push(`${name}, stick ${ax}: lane drift ${(S.x - 1.75).toFixed(2)} m in 2 s (x ${S.x.toFixed(2)}), curvature 1/${Math.round(1 / Math.abs(__ROUTE.k(d0)))} m`);
      }
      I.axisOn = false; I.axis = 0; return out;
    });
    console.log(page, JSON.stringify(calls), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
    if (drive) console.log(drive.join('\n'));
    await p.context().close();
  }
  await b.close(); srv.close();
})();
