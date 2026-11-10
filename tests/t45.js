// the round pedals on a phone and on a Chrome-like big-pixel screen, plus the cost of bending per frame
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const [name, dev] of [['phone', { ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 }], ['chrome1610', { viewport: { width: 1610, height: 720 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, userAgent: devices['Pixel 7'].userAgent }]]) {
    const p = await (await b.newContext(dev)).newPage(); const errs = [];
    p.on('pageerror', e => errs.push(e.message));
    await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '0'); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 150000 });
    await p.click('#playBtn'); await p.waitForTimeout(400);
    if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
    await p.evaluate(() => { __S.dist = 2300; __S.speed = 0; __S.placeN = 99; });
    await p.waitForTimeout(1500);
    const sizes = await p.evaluate(() => { const r = (sel) => { const e = document.querySelector(sel).getBoundingClientRect(); return [Math.round(e.width), Math.round(e.left), Math.round(e.top)]; }; return { gas: r('.tbtn.gas'), brake: r('.tbtn.brake'), nos: r('#nosBtn') }; });
    await p.screenshot({ path: `btn-${name}.png` });
    console.log(name, JSON.stringify(sizes), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
    await p.context().close();
  }
  await b.close(); srv.close();
})();
