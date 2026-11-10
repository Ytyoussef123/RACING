// curves: cockpit and chase views along the route, a view from above, shader errors
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push('pageerror ' + e.message));
  p.on('console', m => { if (m.type() === 'error' && !m.text().includes('GPU stall') && !m.text().includes('stylesheet')) errs.push(m.text().slice(0, 300)); });
  await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '0'); } catch (e) {} });
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 150000 });
  await p.click('#playBtn'); await p.waitForTimeout(400);
  if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
  const at = async (d, name) => { await p.evaluate((d) => { __S.dist = d; __S.speed = 0; __S.x = 1.75; __S.lat = 0; __S.placeN = 99; }, d); await p.waitForTimeout(1800); await p.screenshot({ path: name }); };
  for (const d of (process.argv[2] || '300,1150,1450,2400,5600').split(',').map(Number)) await at(d, `cv-${d}.png`);
  await p.click('#camBtn'); await p.waitForTimeout(300);
  await at(2400, 'cv-chase-2400.png');
  await p.evaluate(() => { __scene.fog.near = 4000; __scene.fog.far = 6000; window.__camOverride = (c) => { c.position.set(0, 520, -330); c.up.set(0, 0, -1); c.lookAt(0, 0, -330); c.fov = 75; c.updateProjectionMatrix(); }; });
  await at(2400, 'cv-top-2400.png');
  await at(5600, 'cv-top-5600.png');
  console.log(errs.length ? 'ERRORS\n' + errs.join('\n') : 'no errors');
  await b.close(); srv.close();
})();
