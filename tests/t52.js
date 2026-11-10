// shaders built at the wrong moment (V28): compiling one the first time it is drawn can freeze a phone for a moment.
// A: every car in, then the car park, a drive, back, a second drive, back, a race: no shader is built at any switch.
// B: a game started before the other cars are in: no shader is built while driving, even when a car comes in
//    meanwhile; its shaders are built on the way back to the car park. Phone landscape.
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const errs = [], out = {};
  const page = async () => {
    const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
    p.on('pageerror', (e) => errs.push('pageerror ' + e.message)); p.on('console', (m) => { if (m.type() === 'error' && !/fonts.googleapis/.test(m.text())) errs.push(m.text().slice(0, 160)); });
    await p.addInitScript(() => { try { localStorage.clear(); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => document.getElementById('playBtn').dataset.ready === '1', null, { timeout: 150000 });
    return p;
  };
  const n = (p) => p.evaluate(() => __renderer.info.programs.length);
  const toPark = async (p) => { await p.click('#pauseBtn'); await p.click('#pauseGarage'); await p.waitForTimeout(2000); };
  try {
    // A
    let p = await page();
    await p.waitForFunction(() => __CARS.every((c) => c.ready), null, { timeout: 150000 }); await p.waitForTimeout(2500);
    let prev = await n(); const built = {};
    const step = async (k) => { const now = await n(); built[k] = now - prev; prev = now; };
    out.ready = prev;
    await p.evaluate(() => __G.set(1, true)); await p.waitForTimeout(1500); await step('showGiulia');
    await p.evaluate(() => __G.set(2, true)); await p.waitForTimeout(1500); await step('showR34');
    await p.evaluate(() => __G.set(1, true)); await p.waitForTimeout(800);
    await p.click('#playBtn'); await p.waitForTimeout(1500); await step('drive1');
    await p.click('#camBtn'); await p.waitForTimeout(1000); await step('chase');
    await p.click('#camBtn'); await toPark(p); await step('park1');
    await p.click('#playBtn'); await p.waitForTimeout(1500); await step('drive2');
    await toPark(p); await step('park2');
    await p.click('#raceBtn'); await p.waitForTimeout(600); await p.evaluate(() => { __RC.count = 0.001; }); await p.waitForTimeout(1500); await step('race');
    out.A = built;
    await p.context().close();
    // B
    p = await page();
    const B = { othersIn: await p.evaluate(() => __CARS.slice(1).map((c) => !!c.ready)) };
    await p.click('#playBtn'); await p.waitForTimeout(300);
    B.mode = await p.evaluate(() => __S.mode); B.atStart = await n();
    await p.waitForFunction(() => __CARS.every((c) => c.ready), null, { timeout: 150000 }); await p.waitForTimeout(1500);
    B.whileDriving = (await n()) - B.atStart; B.stillDriving = await p.evaluate(() => __S.mode === 'play');
    await toPark(p);
    B.allWarm = await p.evaluate(() => __CARS.every((c) => c.warm));
    const atPark = await n();
    for (const i of [1, 2]) { await p.evaluate((k) => __G.set(k, true), i); await p.waitForTimeout(1200); }
    B.showingAfter = (await n()) - atPark;
    out.B = B;
    await p.context().close();
  } catch (e) { console.log('FAIL at', e.message.split('\n')[0], JSON.stringify(out), errs.join(' | ')); await b.close(); srv.close(); return; }
  const A = out.A, B = out.B;
  // (B is only a real test when a car was still on its way at the start; else it says so)
  const late = B.othersIn.some((x) => !x);
  const ok = Object.values(A).every((k) => k === 0) && B.mode === 'play' && B.stillDriving && B.whileDriving === 0 && B.allWarm && B.showingAfter === 0;
  console.log(ok ? 'PASS' : 'FAIL', late ? '' : '(B: the other cars were already in, nothing came in during the game)', JSON.stringify(out), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
