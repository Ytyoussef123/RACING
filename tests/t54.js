// t54 (V30): the rhythm of the pictures on simulated phones (drawing stubbed out, a simulated clock and screen): 90 Hz with pictures
// taking 8-15 ms (uneven), 90 Hz at 9 ms, 120 Hz at 6 ms. For each, 120 s of play: pictures a second, the gaps between
// pictures over the last 60 s (in screen refreshes: an even rhythm has one value), the rhythm's changes
const { chromium, devices } = require('playwright'); const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname); const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => document.getElementById('playBtn').dataset.ready === '1' && __CARS.every((c) => c.ready), null, { timeout: 150000 });
  await p.click('#playBtn'); await p.waitForTimeout(1500);
  await p.evaluate(() => {
    __renderer.render = () => {}; __S.traffic.forEach((c) => __scene.remove(c)); __S.traffic.length = 0;
    window.__T = performance.now(); window.__Q = []; performance.now = () => window.__T;
    window.requestAnimationFrame = (cb) => { window.__Q.push(cb); return 1; };
  });
  await p.waitForTimeout(500);                                             // (the real pending frame re-requests through ours)
  const res = {};
  for (const [name, hz, lo, hi] of [['90 Hz, 8-15 ms', 90, 8, 15], ['90 Hz, 9 ms', 90, 9, 9], ['120 Hz, 6 ms', 120, 6, 6]]) {
    const out = await p.evaluate(([hz, lo, hi, secs]) => {
      const P = __PACE, vs = 1000 / hz; P.vs = vs; P.gaps.length = 0; P.n = 1; P.probe = false; P.calm = 0; P.wait = 15000; P.t = P.frames = P.late = 0; P.lastDraw = 0;
      let busy = 0, last = 0, draws = 0, seed = 7, t0 = window.__T; const hist = {}, ns = [];
      const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
      while (window.__T - t0 < secs * 1000) {
        window.__T += vs; const T = window.__T;
        if (T < busy) continue;
        const q = window.__Q.splice(0); for (const cb of q) cb(T);
        if (P.lastDraw === T) { draws++; if (last && T - t0 > (secs - 60) * 1000) { const k = Math.round((T - last) / vs); hist[k] = (hist[k] || 0) + 1; } last = T; busy = T + lo + (hi - lo) * rnd(); }
        if ((T - t0) % 1000 < vs) ns.push(P.n);
      }
      const runs = []; let prev = null; ns.forEach((n, s) => { if (n !== prev) runs.push(s + 's:1/' + n); prev = n; });
      return { fps: +(draws / secs).toFixed(1), gapsLast60s: hist, rhythm: runs.slice(0, 12), vs: +P.vs.toFixed(2) };
    }, [hz, lo, hi, 120]);
    res[name] = out;
  }
  // an even rhythm: 45 a second on the uneven 90 Hz phone (at least 95 % of gaps of 2 refreshes), 90 at 9 ms, 60 on 120 Hz
  const share = (o, k) => (o.gapsLast60s[k] || 0) / Object.values(o.gapsLast60s).reduce((a, x) => a + x, 0);
  const a = res['90 Hz, 8-15 ms'], c = res['90 Hz, 9 ms'], d = res['120 Hz, 6 ms'];
  const ok = Math.abs(a.fps - 45) < 2 && share(a, 2) >= 0.95 && Math.abs(c.fps - 90) < 1 && share(c, 1) === 1 && Math.abs(d.fps - 60) < 1 && share(d, 2) === 1;
  console.log(ok ? 'PASS' : 'FAIL', JSON.stringify(res));
  await b.close(); srv.close();
})();
