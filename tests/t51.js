// race balance (V28): several whole races in a row, the player driven by a bot of a given skill (careful or good), the
// times of both drivers and the wins. Usage: node t51.js <careful|good> <races> <car index 0-2>
// V28 with the Concept against the Giulia: good bot 2 wins out of 5 (AI about 73-80 s), careful bot 0 out of 4
const { chromium, devices } = require('playwright'); const serve = require('./serve-csp.js');
const [skill = 'good', N = '4', car = '0'] = process.argv.slice(2);
(async () => {
  const { srv, url } = await serve(__dirname); const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage();
  await p.goto(url + 'test4.html'); await p.waitForFunction(() => document.getElementById('playBtn').textContent === 'JOUER' && __CARS.every((c) => c.ready), null, { timeout: 150000 });
  await p.evaluate((i) => __G.set(+i, true), car);
  const res = [];
  for (let r = 0; r < +N; r++) {
    await p.evaluate(() => (__S.mode === 'menu' ? document.getElementById('raceBtn') : document.getElementById('raceAgain')).click());
    await p.waitForTimeout(200); await p.evaluate(() => { __S.rpm = 5000; __RC.count = 0.001; }); await p.waitForTimeout(300);
    res.push(await p.evaluate((skill) => {
      const S = __S, I = __input, RC = __RC, L = [-5.25, -1.75, 1.75, 5.25], good = skill === 'good';
      const look = (lx) => { let g = 1e9, sp = 99;
        for (const c of S.traffic) { const u = c.userData; if (Math.abs(c.position.x - lx) > (u.w + 1.9) / 2 + 0.4 && Math.abs(u.laneX - lx) > 1) continue; const d = -c.position.z - (u.l + 4.4) / 2; if (d > -4 && d < g) { g = d; sp = u.speed; } }
        if (RC.o && Math.abs(RC.o.x - lx) < 2.3) { const d = RC.o.dist - S.dist - 4.4; if (d > -4 && d < g) { g = d; sp = RC.o.speed; } } return [g, sp]; };
      let target = 1.75, t = 0;
      while (t < 200 && S.mode === 'play') {
        const cur = look(target)[0];
        if (cur < (good ? 220 : 150)) for (const x of L) { if (Math.abs(x - target) > 3.6) continue; const r = look(x)[0]; if (r > cur + (good ? 15 : 25) && r > 30) target = x; }
        I.axisOn = true; I.axis = Math.max(-1, Math.min(1, (target - S.x) * 0.55 - S.lat * 0.12));
        const [g, sp] = look(S.x), need = (good ? 7 : 10) + Math.max(0, S.speed - sp) * (good ? 1.35 : 1.6);
        I.brake = g < need; I.gas = g > need + 4; I.nitro = S.nitro > (good ? 0.25 : 0.5) && g > (good ? 110 : 160);
        __update(1 / 60); __bodyStep(1 / 60); t += 1 / 60;
      }
      I.axisOn = false; I.gas = I.brake = I.nitro = false;
      return { end: S.mode, me: S.mode === 'finish' ? +RC.time.toFixed(1) : null, ai: RC.o.done ? +RC.o.done.toFixed(1) : null, won: S.mode === 'finish' && RC.won, avg: Math.round(S.dist / t * 3.6), opp: RC.o.name };
    }, skill));
    await p.waitForFunction(() => __S.mode === 'raceover', null, { timeout: 60000 }).catch(() => {});
  }
  console.log(skill, 'car', car, JSON.stringify(res), 'wins', res.filter((r) => r.won).length + '/' + res.length);
  await b.close(); srv.close();
})();
