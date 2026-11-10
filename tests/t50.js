// where the frame goes (V28): draw calls and triangles per frame in the car park, in the cockpit and in chase view, with
// and without traffic and shadows (phone settings: SD, 10 traffic cars at 4.2 km). Also the JS time of one game step and
// of the road bend. V27: cockpit 541 calls / 281k triangles, chase 771 / 538k; V28: 394 / 240k and 645 / 508k
const { chromium, devices } = require('playwright'); const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname); const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
  await p.goto(url + 'test4.html'); await p.waitForFunction(() => window.__CARS && __CARS.every((c) => c.ready), null, { timeout: 150000 });
  const count = () => p.evaluate(() => new Promise((res) => { const R = __renderer; R.info.autoReset = false; let n = 0; R.info.reset();
    const tick = () => { if (++n <= 4) return requestAnimationFrame(tick); const r = { calls: Math.round(R.info.render.calls / 4), tris: Math.round(R.info.render.triangles / 4) }; R.info.autoReset = true; res(r); }; requestAnimationFrame(tick); }));
  const out = {};
  await p.waitForTimeout(2500); out.park = await count();
  await p.evaluate(() => { __renderer.shadowMap.enabled = false; }); out.parkNoShadow = await count(); await p.evaluate(() => { __renderer.shadowMap.enabled = true; });
  await p.click('#playBtn'); await p.waitForTimeout(500);
  // fill the road with traffic at the density of 4 km (level 2) and let it settle
  await p.evaluate(() => { __S.dist = 4200; for (let i = 0; i < 40; i++) { if (__S.traffic.length >= 10) break; __update(1 / 60); } __S.speed = 120 / 3.6; });
  await p.waitForTimeout(1500);
  out.trafficCars = await p.evaluate(() => __S.traffic.length);
  out.cockpit = await count();
  await p.evaluate(() => { __S.traffic.forEach((c) => (c.visible = false)); }); out.cockpitNoTraffic = await count();
  await p.evaluate(() => { __S.traffic.forEach((c) => (c.visible = true)); __renderer.shadowMap.enabled = false; }); out.cockpitNoShadow = await count();
  await p.evaluate(() => { __renderer.shadowMap.enabled = true; }); await p.click('#camBtn'); await p.waitForTimeout(500);
  out.chase = await count();
  await p.evaluate(() => { __S.traffic.forEach((c) => (c.visible = false)); }); out.chaseNoTraffic = await count(); await p.evaluate(() => { __S.traffic.forEach((c) => (c.visible = true)); });
  out.meshesPerTrafficCar = await p.evaluate(() => __S.traffic.map((c) => { let n = 0; c.traverse((o) => { if (o.isMesh) n++; }); return n; }));
  out.js = await p.evaluate(() => { const t0 = performance.now(); for (let i = 0; i < 300; i++) { __S.traffic.length && 0; __update(1 / 60); __bodyStep(1 / 60); } const a = (performance.now() - t0) / 300; const t1 = performance.now(); for (let i = 0; i < 100; i++) { __updateBend(__S.dist + i); __bendForRender(true); __bendForRender(false); } return { updateMs: +a.toFixed(3), bendMs: +((performance.now() - t1) / 100).toFixed(3) }; });
  console.log(JSON.stringify(out)); await b.close(); srv.close();
})();
