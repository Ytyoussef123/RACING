// HD (post effects) along a bend + the place-name messages
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push('pageerror ' + e.message));
  p.on('console', m => { if (m.type() === 'error' && !m.text().includes('GPU stall') && !m.text().includes('stylesheet')) errs.push(m.text().slice(0, 300)); });
  await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '1'); } catch (e) {} });
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
  await p.click('#playBtn');
  if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
  const toasts = [];
  for (const d of [40, 1720, 5080]) {
    await p.evaluate((d) => { __S.dist = d; __S.speed = 25; }, d);
    await p.waitForFunction(() => document.getElementById('toast').classList.contains('show') && /CASA|SQALA|HANK/.test(document.getElementById('toast').textContent), null, { timeout: 60000 }).catch(() => {});
    toasts.push(await p.evaluate(() => document.getElementById('toast').textContent));
    if (d === 1720) await p.screenshot({ path: 'hd-sqala.png' });
  }
  console.log('hq', await p.evaluate(() => document.getElementById('hqBtn').textContent), '| toasts:', toasts.join(' / '));
  console.log(errs.length ? 'ERRORS\n' + errs.join('\n') : 'no errors');
  await b.close(); srv.close();
})();
