// full screen button: menu and game bar, in a normal page and inside a frame that does not allow it
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const [name, dev] of [['land', devices['Pixel 7 landscape']], ['port', devices['Pixel 7']]]) {
    const p = await (await b.newContext({ ...dev, deviceScaleFactor: 1 })).newPage(); const errs = [];
    p.on('pageerror', e => errs.push(e.message));
    await p.addInitScript(() => { try { localStorage.setItem('corniche-hq', '0'); } catch (e) {} });
    await p.goto(url + 'test4.html');
    await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 150000 });
    const st = () => p.evaluate(() => ({ fs: !!document.fullscreenElement, label: document.getElementById('fsMenuLabel').textContent, on: document.getElementById('fsBtn').classList.contains('on') }));
    await p.screenshot({ path: `fs-menu-${name}.png` });
    await p.click('#fsMenuBtn'); await p.waitForTimeout(600); const a = await st();
    await p.click('#fsMenuBtn'); await p.waitForTimeout(600); const c = await st();
    await p.click('#playBtn'); await p.waitForTimeout(500);
    const bar = await p.evaluate(() => { const r = document.getElementById('fsBtn').getBoundingClientRect(), q = document.getElementById('pauseBtn').getBoundingClientRect(); return { fs: [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)], pause: [Math.round(q.left), Math.round(q.top)] }; });
    await p.click('#fsBtn'); await p.waitForTimeout(600); const d = await st();
    await p.screenshot({ path: `fs-play-${name}.png` });
    await p.click('#fsBtn'); await p.waitForTimeout(600); const e2 = await st();
    console.log(name, 'menu enter', JSON.stringify(a), '| exit', JSON.stringify(c), '| bar', JSON.stringify(bar), '| play enter', JSON.stringify(d), '| exit', JSON.stringify(e2), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
    await p.context().close();
  }
  // inside a frame without permission: the button explains instead of doing nothing
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
  await p.goto(url + 'iframe-nofs.html');
  const f = p.frames().find(fr => fr.url().includes('test4.html'));
  await f.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 150000 });
  await f.click('#fsMenuBtn'); await p.waitForTimeout(500);
  console.log('frame without permission:', JSON.stringify(await f.evaluate(() => ({ enabled: document.fullscreenEnabled, fs: !!document.fullscreenElement, note: document.getElementById('fsNote').hidden ? '(hidden)' : document.getElementById('fsNote').textContent }))));
  await p.screenshot({ path: 'fs-frame.png' });
  await b.close(); srv.close();
})();
