// game: cockpit view still + traffic density and speeds at 0, 2, 6 km (game code stepped at 60 Hz)
const { chromium, devices } = require('playwright');
const serve = require('./serve.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'] })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push('pageerror ' + e.message));
  p.on('console', m => { if ((m.type() === 'error' || m.type() === 'warning') && !m.text().includes('GPU stall')) errs.push('console ' + m.text().slice(0, 200)); });
  await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '0'); } catch (e) {} });
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
  await p.click('#playBtn'); await p.waitForTimeout(300);
  if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
  const start = await p.evaluate(() => ({ cars: __S.traffic.length, speeds: __S.traffic.map((c) => Math.round(c.userData.speed * 3.6)).sort((a, b) => a - b) }));
  console.log('start', JSON.stringify(start));
  await p.evaluate(() => { __S.speed = 120 / 3.6; __S.gear = 4; }); await p.waitForTimeout(1200);
  await p.evaluate(() => { __S.mode = 'paused'; }); await p.waitForTimeout(500);
  await p.screenshot({ path: 'g-cockpit.png' });
  // traffic at further distances: step the real update with the player kept in a free lane, far from cars
  const res = await p.evaluate(() => {
    const S = __S, out = [];
    for (const km of [2.05, 6.05, 12.05]) {
      S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0; S.dist = km * 1000; S.mode = 'play'; S.speed = 50 / 3.6;
      for (let i = 0; i < 60 * 25; i++) { S.x = 7; __update(1 / 60); if (S.mode !== 'play') break; S.speed = 50 / 3.6; }
      out.push({ km, level: S.lvl, cars: S.traffic.length, speeds: [...new Set(S.traffic.map((c) => Math.round(c.userData.cruise * 3.6)))].sort((a, b) => a - b).join(',') });
    }
    S.mode = 'paused'; return out;
  });
  for (const r of res) console.log(JSON.stringify(r));
  console.log(errs.length ? 'ERRORS\n' + errs.join('\n') : 'no errors');
  await b.close(); srv.close();
})();
