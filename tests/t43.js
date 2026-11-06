// braking from 250 km/h (fixed 1/60 s steps): time and distance to 80 and to 0, gears on the way; this build vs V23
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const page of ['test-v23.html', 'test4.html']) {
    const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage(); const errs = [];
    p.on('pageerror', e => errs.push(e.message));
    await p.goto(url + page);
    await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
    await p.click('#playBtn'); await p.waitForTimeout(400);
    const r = await p.evaluate(() => {
      const S = __S, I = __input;
      S.traffic.forEach(c => __scene.remove(c)); S.traffic.length = 0;
      Object.assign(S, { dist: 0, speed: 250 / 3.6, gear: 6, rpm: 7000, thr: 1, brk: 0, x: 1.75, lat: 0 }); I.gas = false; I.brake = true;
      let t = 0, d = 0, t80 = null, d80 = null, gears = [S.gear], minAcc = 0, rpmMin = 9999;
      while (S.speed > 0.3 && t < 15) { S.traffic.length = 0; const v0 = S.speed; __update(1 / 60); t += 1 / 60; d += (v0 + S.speed) / 2 / 60; minAcc = Math.min(minAcc, (S.speed - v0) * 60); if (gears[gears.length - 1] !== S.gear) gears.push(S.gear); if (S.speed * 3.6 > 30) rpmMin = Math.min(rpmMin, S.rpm); if (t80 === null && S.speed * 3.6 <= 80) { t80 = t; d80 = d; } }
      I.brake = false;
      return `250→80 km/h: ${t80.toFixed(2)} s, ${d80.toFixed(0)} m | 250→0: ${t.toFixed(2)} s, ${d.toFixed(0)} m | peak ${(-minAcc / 9.81).toFixed(2)} g | gears ${gears.join('→')} | lowest rpm above 30 km/h ${Math.round(rpmMin)}`;
    });
    console.log(page, '|', r, errs.length ? 'ERR ' + errs.join(' | ') : '');
    await p.context().close();
  }
  await b.close(); srv.close();
})();
