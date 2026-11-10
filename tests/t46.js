// cost of the bend per frame (JS time), and draw calls per frame, in a bend with traffic
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 150000 });
  await p.click('#playBtn'); await p.waitForTimeout(600);
  await p.evaluate(() => { __S.dist = 2300; __S.speed = 0; });
  await p.waitForTimeout(800);
  const r = await p.evaluate(() => new Promise(res => {
    const t0 = performance.now(); for (let i = 0; i < 200; i++) { __updateBend(2300 + i); __bendForRender(true); __bendForRender(false); } const per = (performance.now() - t0) / 200;
    const R = __renderer; R.info.autoReset = false; R.info.reset(); let n = 0;
    const tick = () => { if (++n < 5) return requestAnimationFrame(tick); const c = R.info.render.calls / 4; R.info.autoReset = true; res({ bendMsPerFrame: +per.toFixed(3), drawCallsPerFrame: Math.round(c), traffic: __S.traffic.length }); };
    requestAnimationFrame(() => { R.info.reset(); requestAnimationFrame(tick); });
  }));
  console.log(JSON.stringify(r));
  await b.close(); srv.close();
})();
