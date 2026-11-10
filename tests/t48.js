// stats shown in the car park, for every delivered car (fixed 1/60 s steps, on the straight, no traffic):
// top speed without nitro, 0-100 km/h at full throttle, braking distance from 100 km/h. Copy the numbers into CARS[].stats
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 150000 });
  await p.click('#playBtn'); await p.waitForTimeout(400);
  const r = await p.evaluate(() => __CARS.map((car, i) => {
    if (car.soon) return { id: car.id, soon: true };
    __useCar(i, false);
    const S = __S, I = __input, hold = () => { S.traffic.length = 0; S.dist = 0; S.x = 1.75; S.lat = 0; };   // stay on the straight, in lane
    S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0;
    Object.assign(S, { speed: 0, gear: 1, rpm: 900, thr: 0, brk: 0, shiftT: 0, nitro: 0 }); I.gas = true; I.brake = false;
    let t = 0, t100 = null, vmax = 0;
    while (t < 90) { hold(); __update(1 / 60); t += 1 / 60; const k = S.speed * 3.6; vmax = Math.max(vmax, k); if (t100 === null && k >= 100) t100 = t; }
    I.gas = false; Object.assign(S, { speed: 100 / 3.6, gear: 3, rpm: 5000, thr: 0, brk: 0 }); I.brake = true; let d = 0, tb = 0;
    while (S.speed > 0.05 && tb < 10) { hold(); const v0 = S.speed; __update(1 / 60); tb += 1 / 60; d += (v0 + S.speed) / 2 / 60; }
    I.brake = false;
    return { id: car.id, vmax: Math.round(vmax), t100: +t100.toFixed(1), b100: Math.round(d) };
  }));
  console.log(JSON.stringify(r));
  await b.close(); srv.close();
})();
