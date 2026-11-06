// final check: turned portrait phone, landscape phone, desktop; steering through the on-screen wheel or the keyboard
const { chromium, devices } = require('playwright');
const serve = require('./serve.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const runs = [['port', { ...devices['Pixel 7'] }], ['land', { ...devices['Pixel 7 landscape'] }], ['desk', { viewport: { width: 1280, height: 720 } }]];
  for (const [name, opts] of runs) {
    if (process.argv[2] && process.argv[2] !== name) continue;
    const ctx = await b.newContext(opts); const p = await ctx.newPage(); const errs = [];
    p.on('pageerror', e => errs.push('pageerror ' + e.message));
    p.on('console', m => { if ((m.type() === 'error' || m.type() === 'warning') && !m.text().includes('GPU stall')) errs.push('console ' + m.text().slice(0, 160)); });
    await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '0'); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 120000 });
    const meta = await p.evaluate(() => ({ imported: __ck.imported, driver: !!__ck.driver, stage: document.getElementById('stage').className, ctrl: document.getElementById('ctrlText').textContent.slice(0, 40) }));
    await p.click('#playBtn'); await p.waitForTimeout(300);
    if (await p.evaluate(() => __S.cam) !== 'cockpit') await p.click('#camBtn');
    await p.evaluate(() => { __S.traffic.forEach(c => __scene.remove(c)); __S.traffic.length = 0; __S.speed = 120 / 3.6; __S.gear = 4; __S.x = 1.75; });
    let st;
    if (name !== 'desk') {
      const bb = await (await p.$('#swheel')).boundingBox(); const cx = bb.x + bb.width / 2, cy = bb.y + bb.height / 2, R = bb.width * 0.4;
      // the thumb on the wheel's top, turned toward the screen's left in the game's own frame: in the turned stage that is a different screen direction, so turn it by angle
      const pt = (deg) => [cx + Math.sin(deg * Math.PI / 180) * R, cy - Math.cos(deg * Math.PI / 180) * R];
      await p.mouse.move(...pt(0)); await p.mouse.down(); for (let a = 0; a >= -45; a -= 5) await p.mouse.move(...pt(a));
      await p.waitForTimeout(400);
      st = await p.evaluate(() => ({ axis: +__input.axis.toFixed(2), steer: +__S.steer.toFixed(2), wheelDeg: +(__S.wheelAng * 57.3).toFixed(1), rotor: document.getElementById('swRotor').getAttribute('transform') }));
      await p.screenshot({ path: `f-${name}.png` });
      await p.mouse.up();
    } else {
      await p.keyboard.down('ArrowLeft'); await p.waitForTimeout(500);
      st = await p.evaluate(() => ({ steer: +__S.steer.toFixed(2), wheelDeg: +(__S.wheelAng * 57.3).toFixed(1) }));
      await p.screenshot({ path: `f-${name}.png` });
      await p.keyboard.up('ArrowLeft');
    }
    await p.waitForTimeout(500);
    const after = await p.evaluate(() => +__S.steer.toFixed(3));
    console.log(name, JSON.stringify(meta), 'steering', JSON.stringify(st), 'after release', after, errs.length ? 'ERRORS ' + errs.join(' | ') : 'no errors');
    await ctx.close();
  }
  await b.close(); srv.close();
})();
