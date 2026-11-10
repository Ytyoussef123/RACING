// collision rules: nose into a car's back = crash; side swipe and a car hitting our back = knock, the game goes on
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')), null, { timeout: 150000 });
  for (const kind of ['rear-end (our nose into its back)', 'side swipe from the left', 'side swipe from the right', 'car behind runs into us', 'corner clip while changing lane']) {
    await p.click('#playBtn').catch(() => {}); await p.waitForTimeout(300);
    const r = await p.evaluate((kind) => {
      const S = __S, I = __input;
      if (S.mode !== 'play') return 'not playing: ' + S.mode;
      S.traffic.forEach(c => __scene.remove(c)); const keep = S.traffic.splice(0);
      Object.assign(S, { dist: 100, speed: 150 / 3.6, x: 1.75, lat: 0, steer: 0, steerV: 0, shake: 0 }); I.gas = true; I.axisOn = false; I.axis = 0;
      const c = keep[0]; __scene.add(c); S.traffic.push(c); const u = c.userData; u.change = 0; u.passed = false; u.hitT = 0; c.rotation.y = 0;
      const L = __S ? 1.75 : 0; u.lane = 2;
      if (kind.startsWith('rear-end')) { c.position.set(1.75, c.position.y, -8); u.speed = u.cruise = 80 / 3.6; }
      else if (kind === 'side swipe from the left') { c.position.set(1.75 - 1.8, c.position.y, -1); u.lane = 1; u.speed = u.cruise = 140 / 3.6; }
      else if (kind === 'side swipe from the right') { c.position.set(1.75 + 1.8, c.position.y, 0.5); u.lane = 3; u.speed = u.cruise = 145 / 3.6; }
      else if (kind === 'car behind runs into us') { c.position.set(1.75, c.position.y, 6); u.speed = u.cruise = 190 / 3.6; }
      else { c.position.set(1.75 + 1.75, c.position.y, -4.55); u.lane = 3; u.speed = u.cruise = 120 / 3.6; I.axisOn = true; I.axis = 0.9; }
      const v0 = S.speed;
      let hit = null;
      for (let k = 0; k < 90 && S.mode === 'play'; k++) { __update(1 / 60); if (!hit && S.shake > 0.3) hit = k; }
      const out = `${kind}: mode ${S.mode}${hit !== null ? ', knocked at frame ' + hit : ''}, speed ${Math.round(v0 * 3.6)} → ${Math.round(S.speed * 3.6)} km/h, gap across ${(Math.abs(c.position.x - S.x) - (u.w + 1.9) / 2).toFixed(2)} m, along ${(Math.abs(c.position.z) - (u.l + 4.4) / 2).toFixed(2)} m`;
      I.axisOn = false; I.axis = 0;
      if (S.mode === 'crash') { S.crashT = 0; }
      return out;
    }, kind);
    console.log(r);
    await p.waitForTimeout(400);
    // back to a fresh game
    await p.evaluate(() => { if (__S.mode === 'play') { __S.mode = 'over'; } });
    await p.waitForTimeout(300);
    await p.evaluate(() => { for (const id of ['overScreen', 'menu']) { const e = document.getElementById(id); if (e) e.hidden = id !== 'menu'; } });
  }
  console.log(errs.length ? 'ERRORS ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
