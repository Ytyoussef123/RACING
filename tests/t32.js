// does each model load under a strict CSP (as on the real artifact page)?
const { chromium, devices } = require('playwright');
const serve = require(process.argv[2] === 'csp' ? './serve-csp.js' : './serve.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'] })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push('pageerror ' + e.message));
  p.on('console', m => { if ((m.type() === 'error' || m.type() === 'warning') && !m.text().includes('GPU stall')) errs.push(m.text().slice(0, 160)); });
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
  const r = await p.evaluate(() => { let palmModel = false; __scene.traverse((o) => { if (o.isMesh && /Tree_/.test(o.material.name || '')) palmModel = true; }); return { interior: __ck.imported, driver: !!__ck.driver, palmModel }; });
  console.log(process.argv[2] || 'no-csp', JSON.stringify(r)); for (const e of errs.slice(0, 6)) console.log('  ', e);
  await b.close(); srv.close();
})();
