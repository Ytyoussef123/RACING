// full game with the imported interior: load time, errors, stills (centre / left / right) per device
const { chromium, devices } = require('playwright');
const serve = require('./serve.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const runs = [['land', { ...devices['Pixel 7 landscape'] }], ['port', { ...devices['Pixel 7'] }], ['desk', { viewport: { width: 1280, height: 720 } }]];
  const only = process.argv[2], hq = process.argv[3] === 'hq';
  for (const [name, opts] of runs) {
    if (only && only !== 'all' && only !== name) continue;
    const ctx = await b.newContext(opts); const p = await ctx.newPage();
    p.on('pageerror', e => console.log(name, 'pageerror', e.message));
    p.on('console', m => { if (m.type() === 'error') console.log(name, 'console', m.text().slice(0, 300)); });
    await p.addInitScript((hq) => { try { localStorage.setItem('corniche-hq', hq ? '1' : '0'); } catch (e) {} }, hq);
    if (process.argv[4] === 'nointerior') await p.route('**/interior.json', (r) => r.abort());
    const t0 = Date.now();
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 120000 });
    console.log(name, 'ready after', Date.now() - t0, 'ms, imported interior:', await p.evaluate(() => __ck && __ck.imported));
    await p.click('#playBtn'); await p.waitForTimeout(300);
    if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
    await p.evaluate(() => { __S.traffic.forEach(c => __scene.remove(c)); __S.traffic.length = 0; __S.speed = 120 / 3.6; __S.gear = 4; __S.x = 1.75; });
    await p.waitForTimeout(1500);
    await p.evaluate(() => { __S.mode = 'paused'; });
    for (const [tag, st] of [['c', 0], ['l', -1], ['r', 1]]) {
      await p.evaluate((st) => { const S = __S; S.steer = st; S.wheelAng = st * (0.72 + 0.5 / (1 + Math.pow(S.speed / 14, 1.4))); const lt = st * 8; S.lat = lt; S.yaw = Math.atan2(lt, S.speed); S.aLat = 0; S.roll = 0; }, st);
      await p.waitForTimeout(900);
      await p.screenshot({ path: `x-${name}-${tag}${hq ? '-hq' : ''}${process.argv[4] ? '-' + process.argv[4] : ''}.png` });
    }
    await ctx.close();
  }
  await b.close(); srv.close();
})();
