// a phone driver that refuses part of the shader: the game must still draw the road (normal, level 1, level 0)
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const mode of (process.argv[2] || 'none,normals,all').split(',')) {
    const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage(); const errs = [];
    p.on('pageerror', e => errs.push('pageerror ' + e.message));
    p.on('console', m => { if (m.type() === 'error' && !m.text().includes('GPU stall') && !m.text().includes('stylesheet')) errs.push(m.text().slice(0, 120)); });
    await p.addInitScript((mode) => {
      try { localStorage.setItem('corniche-hq', '0'); localStorage.removeItem('corniche-bend-v23'); } catch (e) {}
      const bad = mode === 'normals' ? (s) => s.includes('#define BEND_NRM') && s.includes('vec3 bN = ') : mode === 'all' ? (s) => s.includes('bendPos') : () => false;
      for (const C of [window.WebGLRenderingContext, window.WebGL2RenderingContext]) {
        if (!C) continue; const o = C.prototype.shaderSource;
        C.prototype.shaderSource = function (sh, src) { if (bad(src)) src += '\nthis line is not glsl'; return o.call(this, sh, src); };
      }
    }, mode);
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
    const gfx = await p.evaluate(() => { const g = document.getElementById('gfxMode'); return g.hidden ? 'level 2 (full)' : g.textContent; });
    await p.click('#playBtn'); await p.waitForTimeout(400);
    if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
    await p.evaluate(() => { __S.dist = 2400; __S.speed = 0; __S.placeN = 99; }); await p.waitForTimeout(2500);
    const failed = await p.evaluate(() => (__renderer.info.programs || []).filter(pr => pr.diagnostics && pr.diagnostics.runnable === false).length);
    await p.screenshot({ path: `drv-${mode}.png` });
    console.log(mode, '|', gfx, '| failed programs in use:', failed, '| reloaded:', await p.evaluate(() => performance.getEntriesByType('navigation')[0].type), '|', errs.length, 'console errors');
    await p.context().close();
  }
  await b.close(); srv.close();
})();
