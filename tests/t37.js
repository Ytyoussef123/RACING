// deterministic steering response: fixed 1/60 s steps through update(), no traffic
const { chromium } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ viewport: { width: 900, height: 420 } })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
  await p.click('#playBtn'); await p.waitForTimeout(300);
  const r = await p.evaluate(() => {
    const S = __S, I = __input, out = [];
    const reset = (kmh) => { S.traffic.forEach(c => __scene.remove(c)); S.traffic.length = 0; S.dist = 0; S.speed = kmh / 3.6; S.gear = 5; S.x = -1.75; S.lat = 0; S.steer = 0; S.steerV = 0; I.gas = true; };
    const run = (sec, f) => { const n = Math.round(sec * 60); for (let i = 0; i < n; i++) { f && f(i / 60); S.traffic.length = 0; __update(1 / 60); } };
    for (const kmh of [80, 200]) {
      for (const a of [0.15, 0.4, 1]) {
        reset(kmh); I.axisOn = true; I.axis = a; run(0.06); const lat60 = S.lat; run(0.44);
        const latHold = S.lat, x0 = S.x; I.axisOn = false; I.axis = 0; let tStop = null;
        for (let i = 0; i < 120; i++) { run(1 / 60); if (tStop === null && Math.abs(S.lat) < 0.05) tStop = (i + 1) / 60; }
        out.push(`${kmh} km/h stick ${a}: lat after 60 ms ${lat60.toFixed(2)} / held ${latHold.toFixed(2)} m/s | after release slides ${((S.x - x0) * 100).toFixed(0)} cm, stopped in ${tStop === null ? '>2' : (tStop * 1000).toFixed(0)} ms`);
      }
      // slow push to 50 % over 0.6 s, back to centre over 0.3 s (still touching)
      reset(kmh); I.axisOn = true; let xs = S.x, xBack = 0;
      run(0.6, t => { I.axis = 0.5 * t / 0.6; }); run(0.3, t => { I.axis = 0.5 * (1 - t / 0.3); }); I.axis = 0; xBack = S.x; run(1);
      out.push(`${kmh} km/h slow push: moved ${((xBack - xs)).toFixed(2)} m while pushing, then ${((S.x - xBack) * 100).toFixed(0)} cm more after the thumb is back in the centre`);
    }
    return out;
  });
  console.log(r.join('\n')); console.log(errs.length ? 'ERRORS ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
