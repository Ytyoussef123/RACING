// t56 (V32): the car park's slide on a slow phone ("lite": the cars' stored reliefs instead of the cars while the row
// moves). Phone landscape, real time, in the software renderer (slow: the game must choose lite by itself).
// - lite chosen when the loading screen lifts, the reliefs taken (two bays' worth for each car in view);
// - a slide drawn with the reliefs is much quicker than the same slide with the real cars (gaps between pictures);
// - no shader built by the first slide; at rest the picture is the real one, the same as with lite off;
// - a real swipe (touch events) moves to the next car, reliefs on screen meanwhile; the game then starts as usual.
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
const { PNG } = (() => { try { return require('pngjs'); } catch (e) { return {}; } })();
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const errs = [], out = {};
  try {
    const ctx = await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 });
    const p = await ctx.newPage();
    p.on('pageerror', (e) => errs.push('pageerror ' + e.message)); p.on('console', (m) => { if (m.type() === 'error' && !/fonts.googleapis/.test(m.text())) errs.push(m.text().slice(0, 160)); });
    await p.addInitScript(() => { try { localStorage.clear(); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => document.getElementById('playBtn').dataset.ready === '1' && __CARS.every((c) => c.ready), null, { timeout: 200000 });
    await p.waitForFunction(() => document.getElementById('loading').hidden, null, { timeout: 20000 });
    out.lite = await p.evaluate(() => __G.lite);
    out.reliefs = await p.evaluate(() => __G.sprites.views.map((v) => v.map((c) => (c ? c[2] : 0))));
    // the row dragged back and forth for n pictures: the gaps between them
    const slide = (n) => p.evaluate((n) => new Promise((res) => {
      __G.dragStart(400); const g = []; let last = 0, k = 0;
      const tick = (t) => { if (last) g.push(Math.round(t - last)); last = t; __G.dragMove(400 - 150 * Math.abs(Math.sin(k++ / 5))); if (g.length < n) requestAnimationFrame(tick); else { __G.dragEnd(); res(g.sort((a, b) => a - b)[n >> 1]); } };
      requestAnimationFrame(tick);
    }), n);
    const rest = async (name) => {
      await p.waitForFunction(() => __G.idle(), null, { timeout: 60000 }); await p.waitForTimeout(1500);
      await p.evaluate(() => { __G.render(1); });
      const buf = await p.locator('#game').screenshot(); return buf;
    };
    await p.evaluate(() => { __PACE.gi = 16.7; __PACE.gs = 1; });
    const progs0 = await p.evaluate(() => __renderer.info.programs.length);
    out.liteGap = await slide(10); out.drawn = await p.evaluate(() => __G.sprites.drawn);
    out.builtBySlide = (await p.evaluate(() => __renderer.info.programs.length)) - progs0;
    await p.evaluate(() => __G.set(0, true)); const A = await rest('lite');
    await p.evaluate(() => { __G.lite = false; __PACE.gi = 16.7; __PACE.gs = 1; });
    out.realGap = await slide(6);
    await p.evaluate(() => __G.set(0, true)); const B = await rest('real');
    out.restSame = Buffer.compare(A, B) === 0;
    // a real swipe to the next car, with the reliefs
    await p.evaluate(() => { __G.lite = true; __PACE.gi = 16.7; __PACE.gs = 1; });
    await p.waitForFunction(() => __G.idle(), null, { timeout: 60000 });
    const cdp = await ctx.newCDPSession(p), vp = p.viewportSize(), y = vp.height * 0.42;
    const touch = (type, x) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
    await touch('touchStart', vp.width * 0.7);
    for (let k = 1; k <= 8; k++) { await touch('touchMove', vp.width * (0.7 - 0.045 * k)); await p.waitForTimeout(60); }
    out.swipeDrawn = await p.evaluate(() => __G.sprites.drawn); out.movingMid = await p.evaluate(() => __G.moving());
    await touch('touchEnd');
    await p.waitForFunction(() => __G.idle(), null, { timeout: 60000 });
    out.carAfterSwipe = await p.evaluate(() => __G.idx);
    await p.click('#playBtn', { timeout: 120000 }); await p.waitForFunction(() => __S.mode === 'play' && __S.time > 0.05, null, { timeout: 120000 });
    out.plays = await p.evaluate(() => ({ mode: __S.mode, car: __S.car, ratio: __renderer.getPixelRatio() }));
    await ctx.close();
  } catch (e) { console.log('FAIL at', e.message.split('\n')[0], JSON.stringify(out), errs.join(' | ')); await b.close(); srv.close(); return; }
  const ok = out.lite === true && out.reliefs.flat().filter((n) => n > 500).length >= 6 && out.drawn >= 2 && out.builtBySlide === 0
    && out.liteGap < 0.6 * out.realGap && out.restSame && out.swipeDrawn >= 2 && out.movingMid === true && out.carAfterSwipe === 1 && out.plays.mode === 'play' && out.plays.car === 1;
  console.log(ok ? 'PASS' : 'FAIL', JSON.stringify(out), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
