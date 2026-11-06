// drive the real game code step by step (60 Hz) and log the steering response
const { chromium, devices } = require('playwright');
const serve = require('./serve.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await b.newContext({ viewport: { width: 640, height: 360 } }); const p = await ctx.newPage();
  p.on('pageerror', e => console.log('pageerror', e.message));
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 120000 });
  await p.click('#playBtn'); await p.waitForTimeout(300);
  const res = await p.evaluate(() => {
    const S = __S, I = __input, out = [];
    S.mode = 'paused';
    const clear = () => { S.traffic.forEach(c => __scene.remove(c)); S.traffic.length = 0; };
    const run = (kmh, x, plan, T) => {
      Object.assign(S, { speed: kmh / 3.6, gear: 4, x, lat: 0, steer: 0, steerV: 0, aLat: 0, roll: 0, rollV: 0 });
      const rows = [];
      for (let i = 0; i < T * 60; i++) {
        const t = i / 60, k = plan(t); I.left = k < 0; I.right = k > 0; S.speed = kmh / 3.6;
        clear(); __update(1 / 60); __bodyStep(1 / 60);
        if (i % 3 === 0) rows.push([t, k, S.steer, S.wheelAng * 57.3, S.lat, S.yaw * 57.3, S.x, S.roll * 57.3, S.hx * 100]);
      }
      I.left = I.right = false; return rows;
    };
    return {
      lane: run(120, 1.75, (t) => (t >= 0.1 && t < 0.7 ? -1 : 0), 1.5),
      rail: run(120, 5.0, (t) => (t >= 0.05 && t < 1.0 ? 1 : 0), 1.4),
    };
  });
  for (const k in res) {
    console.log(k, '    t   in  steer wheel°    lat   yaw°      x  roll° head(cm)');
    for (const r of res[k]) console.log(r.map((v, i) => v.toFixed(i === 0 ? 2 : 2).padStart(7)).join(''));
  }
  await ctx.close(); await b.close(); srv.close();
})();
