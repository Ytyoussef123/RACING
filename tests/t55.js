// t55 (V31): the car park's rhythm on simulated phones (drawing stubbed out, a simulated clock and screen, a picture
// that costs less at a lower resolution: 80 % of it is per pixel). A finger keeps the row moving for 20 s, then lets
// go: the rhythm while it moves (gaps between pictures over the last 8 s, in screen refreshes: an even rhythm has one
// value), what it learnt (time of a picture, resolution while moving), then at rest: pictures in 5 s (a touch screen's
// car park at rest is a fixed picture, drawn again once a second), the resolution back to full, the first picture
// after the stop at full resolution. Phones: 60 Hz at 10 ms, 28 ms, 80 ms a picture; 120 Hz at 12 and 25 ms.
const { chromium, devices } = require('playwright'); const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname); const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.addInitScript(() => { try { localStorage.clear(); } catch (e) {} });
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => document.getElementById('playBtn').dataset.ready === '1' && __CARS.every((c) => c.ready), null, { timeout: 150000 });
  await p.waitForTimeout(1500);
  await p.evaluate(() => {
    __renderer.render = () => {};
    window.__T = performance.now(); window.__Q = []; performance.now = () => window.__T;
    window.requestAnimationFrame = (cb) => { window.__Q.push(cb); return 1; };
  });
  await p.waitForTimeout(500);                                             // (the real pending frame re-requests through ours)
  const res = {};
  for (const [name, hz, ms] of [['60 Hz, 10 ms', 60, 10], ['60 Hz, 28 ms', 60, 28], ['60 Hz, 80 ms', 60, 80], ['120 Hz, 12 ms', 120, 12], ['120 Hz, 25 ms', 120, 25]]) {
    res[name] = await p.evaluate(([hz, ms]) => {
      const P = __PACE, vs = 1000 / hz, pr0 = __renderer.getPixelRatio();
      Object.assign(P, { vs, n: 1, lastDraw: 0, prevSkip: false, gi: 16.7, gs: 1, gMoving: false, gt: 0, gf: 0, gl: 0, gcalm: 0, gwait: 5000, gprobe: false }); P.gaps.length = 0;
      let busy = 0, last = 0, t0 = window.__T, moving = true, firstStill = null, restDraws = 0; const hist = {};
      __G.dragStart(300);
      while (window.__T - t0 < 30000) {
        window.__T += vs; const T = window.__T, s = (T - t0) / 1000;
        if (moving && s >= 20) { moving = false; __G.dragEnd(); }
        if (T < busy) continue;
        if (moving) __G.dragMove(300 + 90 * Math.sin(T / 400));
        const q = window.__Q.splice(0); for (const cb of q) cb(T);
        if (P.lastDraw !== T) continue;
        const pr = __renderer.getPixelRatio(), k = pr / pr0;
        if (moving && s > 12 && last) { const g = Math.round((T - last) / vs); hist[g] = (hist[g] || 0) + 1; }
        if (!moving && firstStill === null && __G.idle()) firstStill = +k.toFixed(2);
        if (s >= 25) restDraws++;
        last = T; busy = T + ms * (0.8 * k * k + 0.2);
      }
      return { gapsMoving: hist, learnt: { gi: +P.gi.toFixed(1), gs: +P.gs.toFixed(2) }, restPicturesIn5s: restDraws, firstPictureAtRest: firstStill, ratioAtRest: +(__renderer.getPixelRatio() / pr0).toFixed(2), vs: +P.vs.toFixed(2) };
    }, [hz, ms]);
  }
  // even: at least 80 % of the gaps of one value; 60 Hz at 10 ms: every refresh, full resolution; 28 ms: every 2 (30 a
  // second), full resolution; 80 ms: lower resolution while moving, 20 or 30 a second; 120 Hz at 12 ms: every 2 (60 a
  // second); 25 ms: every 4 (30 a second). At rest: a few pictures in 5 s, full resolution, from the first one
  const share = (o, k) => (o.gapsMoving[k] || 0) / Math.max(1, Object.values(o.gapsMoving).reduce((a, x) => a + x, 0));
  const r = res, rest = Object.values(r).every((o) => o.restPicturesIn5s <= 7 && o.ratioAtRest === 1 && o.firstPictureAtRest === 1);
  const ok = share(r['60 Hz, 10 ms'], 1) >= 0.95 && r['60 Hz, 10 ms'].learnt.gs === 1
    && share(r['60 Hz, 28 ms'], 2) >= 0.8 && r['60 Hz, 28 ms'].learnt.gs === 1
    && r['60 Hz, 80 ms'].learnt.gs < 1 && Math.max(share(r['60 Hz, 80 ms'], 2), share(r['60 Hz, 80 ms'], 3)) >= 0.8
    && share(r['120 Hz, 12 ms'], 2) >= 0.95 && share(r['120 Hz, 25 ms'], 4) >= 0.8 && rest;
  console.log(ok ? 'PASS' : 'FAIL', JSON.stringify(res), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
