// car park (V26): load, swipe to the next car (covered: play refused), arrow keys back, play the standard car,
// pause -> car park, then the game over screen. Phone landscape, desktop, narrow window, phone held upright
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const confs = [
    ['phone', { ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 }],
    ['desk', { viewport: { width: 1280, height: 720 } }],
    ['narrow', { viewport: { width: 420, height: 760 } }],
    ['phoneUp', { ...devices['Pixel 7'], deviceScaleFactor: 1 }],
  ];
  for (const [name, ctx] of confs) {
    const p = await (await b.newContext(ctx)).newPage(); const errs = [];
    p.on('pageerror', e => errs.push('pageerror ' + e.message)); p.on('console', m => { if (m.type() === 'error' && !/fonts.googleapis/.test(m.text())) errs.push(m.text()); });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER', null, { timeout: 150000 });
    await p.waitForTimeout(4000);
    await p.screenshot({ path: `park-${name}-a.png` });
    const vp = p.viewportSize(), rot = await p.evaluate(() => document.getElementById('stage').classList.contains('rot'));
    // swipe toward the left of the stage (from 70 % to 25 % of its width); a turned stage runs along the screen's height
    const from = rot ? [vp.width * 0.5, vp.height * 0.7] : [vp.width * 0.7, vp.height * 0.45], to = rot ? [vp.width * 0.5, vp.height * 0.25] : [vp.width * 0.25, vp.height * 0.45];
    await p.mouse.move(...from); await p.mouse.down(); await p.mouse.move(...to, { steps: 8 }); await p.mouse.up();
    await p.waitForTimeout(2500);
    const s1 = await p.evaluate(() => ({ name: document.getElementById('carName').textContent, btn: document.getElementById('playBtn').textContent, dis: document.getElementById('playBtn').disabled }));
    await p.screenshot({ path: `park-${name}-b.png` });
    await p.evaluate(() => document.getElementById('playBtn').click()); await p.waitForTimeout(300);
    const modeAfterSoon = await p.evaluate(() => __S.mode);
    await p.keyboard.press('ArrowRight'); await p.waitForTimeout(200);
    const s2 = await p.evaluate(() => document.getElementById('carName').textContent);
    await p.keyboard.press('ArrowLeft'); await p.keyboard.press('ArrowLeft'); await p.waitForTimeout(1500);
    const s3 = await p.evaluate(() => ({ name: document.getElementById('carName').textContent, btn: document.getElementById('playBtn').textContent }));
    await p.click('#playBtn'); await p.waitForTimeout(1500);
    const play = await p.evaluate(() => ({ mode: __S.mode, car: __S.car, hud: !document.querySelector('.hud').hidden, menu: !document.getElementById('menu').hidden }));
    await p.screenshot({ path: `park-${name}-c.png` });
    await p.click('#pauseBtn'); await p.waitForTimeout(300); await p.click('#pauseGarage'); await p.waitForTimeout(1200);
    const back = await p.evaluate(() => ({ mode: __S.mode, hud: !document.querySelector('.hud').hidden, name: document.getElementById('carName').textContent }));
    await p.screenshot({ path: `park-${name}-d.png` });
    await p.evaluate(() => document.getElementById('playBtn').click()); await p.waitForTimeout(500);
    await p.evaluate(() => { __S.crashT = 0.01; __S.mode = 'crash'; });
    await p.waitForTimeout(800);
    await p.screenshot({ path: `park-${name}-e.png` });
    const over = await p.evaluate(() => ({ mode: __S.mode, overVisible: !document.getElementById('overScreen').hidden }));
    const ok = s1.name === 'VOITURE 2' && s1.dis && modeAfterSoon === 'menu' && s2 === 'VOITURE 3' && s3.btn === 'JOUER' && play.mode === 'play' && play.hud && back.mode === 'menu' && !back.hud && over.overVisible;
    console.log(name, ok ? 'PASS' : 'FAIL', JSON.stringify({ rot, s1, modeAfterSoon, s2, s3, play, back, over }), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
    await p.context().close();
  }
  await b.close(); srv.close();
})();
