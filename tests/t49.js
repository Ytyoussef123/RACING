// the race (V28): COURSE from the car park, countdown (pause keeps it), launch, the other driver, a whole race driven
// by a simple bot (both times), a win, a 2nd place, a crash into the back of a car, back to the car park.
// Screenshots: race-countdown, race-driving, race-arch, race-result. Phone landscape.
const { chromium, devices } = require('playwright');
const serve = require('./serve-csp.js');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ ...devices['Pixel 7 landscape'], deviceScaleFactor: 1 })).newPage(); const errs = [];
  p.on('pageerror', (e) => errs.push('pageerror ' + e.message)); p.on('console', (m) => { if (m.type() === 'error' && !/fonts.googleapis/.test(m.text())) errs.push(m.text().slice(0, 160)); });
  await p.addInitScript(() => { try { localStorage.removeItem('corniche-race1'); localStorage.removeItem('corniche-car'); } catch (e) {} });
  await p.goto(url + 'test4.html');
  await p.waitForFunction(() => (b => b.dataset.ready === '1' || b.textContent === 'JOUER')(document.getElementById('playBtn')) && __CARS.every((c) => c.ready), null, { timeout: 150000 });
  const out = {};
  try {
  // COURSE: countdown, race readings shown, the other driver on the grid beside us
  await p.click('#raceBtn'); await p.waitForTimeout(700);
  out.countdown = await p.evaluate(() => ({ mode: __S.mode, racing: document.getElementById('stage').classList.contains('racing'), launch: !document.getElementById('launch').hidden,
    opp: __RC.o.name, oppOnRoad: __RC.o.root.parent === __scene, oppX: __RC.o.x, me: __S.x, speed: __S.speed }));
  await p.keyboard.down('ArrowUp'); await p.waitForTimeout(500);
  out.revs = await p.evaluate(() => Math.round(__S.rpm));
  await p.screenshot({ path: 'race-countdown.png' });
  await p.keyboard.up('ArrowUp');
  // pause in the countdown, then back: still the countdown
  await p.click('#pauseBtn'); await p.waitForTimeout(200);
  const paused = await p.evaluate(() => __S.mode);
  await p.click('#resumeBtn'); await p.waitForTimeout(200);
  out.pause = [paused, await p.evaluate(() => __S.mode)];
  // the launch: needle at 5000 rpm when the count reaches zero = perfect start
  await p.evaluate(() => { __S.rpm = 5000; __input.gas = true; __RC.count = 0.001; });
  await p.waitForTimeout(400);
  out.launch = await p.evaluate(() => ({ mode: __S.mode, speedKmh: Math.round(__S.speed * 3.6), toast: document.getElementById('toast').textContent }));
  // a whole race at game speed (fixed 1/60 s steps), the player driven by a bot: throttle on, steer toward the lane with
  // the most room, nitro when there is room, brake when boxed in. Both finishing times, crashes, the other driver's lanes
  out.race = await p.evaluate(() => {
    const S = __S, I = __input, RC = __RC, L = [-5.25, -1.75, 1.75, 5.25];
    // the next car ahead in a lane (traffic and the other driver): [gap, its speed]
    const look = (lx) => { let g = 1e9, sp = 99;
      for (const c of S.traffic) { const u = c.userData; if (Math.abs(c.position.x - lx) > (u.w + 1.9) / 2 + 0.4 && Math.abs(u.laneX - lx) > 1) continue; const d = -c.position.z - (u.l + 4.4) / 2; if (d > -4 && d < g) { g = d; sp = u.speed; } }
      if (RC.o && Math.abs(RC.o.x - lx) < 2.3) { const d = RC.o.dist - S.dist - 4.4; if (d > -4 && d < g) { g = d; sp = RC.o.speed; } } return [g, sp]; };
    let target = 1.75, lanes = new Set(), t = 0, crashes = 0, maxGap = 0, minGap = 0;
    while (t < 180 && S.mode === 'play') {
      // toward the lane with the most room (a neighbour lane only, and only for clearly more room)
      const cur = look(target)[0];
      if (cur < 150) for (const x of L) { if (Math.abs(x - target) > 3.6) continue; const r = look(x)[0]; if (r > cur + 25 && r > 35) target = x; }
      I.axisOn = true; I.axis = Math.max(-1, Math.min(1, (target - S.x) * 0.5 - S.lat * 0.12));
      // brake for the car ahead with room to spare for the speed difference, nitro on an open road
      const [g, sp] = look(S.x), need = 10 + Math.max(0, S.speed - sp) * 1.6;
      I.brake = g < need; I.gas = g > need + 6; I.nitro = S.nitro > 0.5 && g > 160;
      __update(1 / 60); __bodyStep(1 / 60); t += 1 / 60; lanes.add(RC.o.lane);
      const d = S.dist - RC.o.dist; maxGap = Math.max(maxGap, d); minGap = Math.min(minGap, d);
    }
    I.axisOn = false; I.gas = I.brake = I.nitro = false;
    return { mode: S.mode, gameS: +t.toFixed(1), myTime: S.mode === 'finish' ? +RC.time.toFixed(1) : null, won: RC.won, oppTime: RC.o.done ? +RC.o.done.toFixed(1) : null,
      oppDistAtEnd: Math.round(RC.o.dist), oppLanesUsed: [...lanes].sort().join(''), leadMax: Math.round(maxGap), behindMax: Math.round(-minGap), avgKmh: Math.round(S.dist / t * 3.6), top: Math.round(S.top * 3.6) };
  });
  await p.waitForFunction(() => __S.mode === 'raceover', null, { timeout: 60000 }).catch(() => {});
  out.result1 = await p.evaluate(() => ({ mode: __S.mode, title: document.getElementById('rTitle').textContent, time: document.getElementById('rTime').textContent, gap: document.getElementById('rGapEnd').textContent, best: document.getElementById('rBest').textContent, stored: localStorage.getItem('corniche-race1') }));
  await p.screenshot({ path: 'race-result.png' });
  // REVANCHE, a 2nd place: the other driver over the line first
  await p.click('#raceAgain'); await p.waitForTimeout(300);
  await p.evaluate(() => { __RC.count = 0.001; }); await p.waitForTimeout(300);
  await p.evaluate(() => { const S = __S, RC = __RC; S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0; S.dist = __RACE.len - 400; RC.o.dist = __RACE.len - 330; RC.o.x = -1.75; RC.o.speed = 62; S.speed = 50; S.gear = 5; RC.t = 70; });
  await p.waitForTimeout(1500);
  await p.screenshot({ path: 'race-driving.png' });
  await p.evaluate(() => { const S = __S; S.dist = __RACE.len - 260; });
  await p.waitForTimeout(800);
  await p.screenshot({ path: 'race-arch.png' });
  out.second = await p.evaluate(() => { const S = __S, RC = __RC; let t = 0; while (t < 40 && S.mode === 'play') { S.traffic.length = 0; __input.gas = true; __update(1 / 60); t += 1 / 60; } __input.gas = false; return { mode: S.mode, won: RC.won, gapT: +RC.gapT.toFixed(1), oppDone: RC.o.done > 0 }; });
  await p.waitForFunction(() => __S.mode === 'raceover', null, { timeout: 60000 }).catch(() => {});
  out.result2 = await p.evaluate(() => ({ title: document.getElementById('rTitle').textContent, gap: document.getElementById('rGapEnd').textContent }));
  // a crash in the race: our nose into the back of a car ahead
  await p.click('#raceAgain'); await p.waitForTimeout(300);
  await p.evaluate(() => { __RC.count = 0.001; }); await p.waitForTimeout(300);
  out.crash = await p.evaluate(() => { const S = __S; S.traffic.forEach((c) => __scene.remove(c)); S.traffic.length = 0; for (let i = 0; i < 30 && !S.traffic.length; i++) __update(1 / 60);
    const c = S.traffic[0]; c.position.set(S.x, -0.02, -(c.userData.l + 4.4) / 2 + 1.2); c.userData.speed = 10; c.userData.cruise = 10; c.userData.lane = 2; c.userData.laneX = 1.75; c.userData.change = 0; S.speed = 30; S.mode = 'play'; for (let i = 0; i < 5 && S.mode === 'play'; i++) __update(1 / 60); return S.mode; });
  await p.waitForFunction(() => __S.mode === 'raceover', null, { timeout: 30000 }).catch(() => {});
  out.result3 = await p.evaluate(() => document.getElementById('rTitle').textContent);
  // back to the car park: no race left on the road
  await p.click('#raceGarage'); await p.waitForTimeout(500);
  out.garage = await p.evaluate(() => ({ mode: __S.mode, racing: document.getElementById('stage').classList.contains('racing'), oppGone: !__RC.o, record: document.getElementById('bestMenu').textContent }));
  } catch (e) { console.log('FAIL at', e.message.split('\n')[0], JSON.stringify(out), errs.join(' | ')); await b.close(); srv.close(); return; }
  const ok = out.countdown.mode === 'countdown' && out.countdown.racing && out.countdown.launch && out.countdown.oppOnRoad && out.countdown.speed === 0 && out.revs > 1000
    && out.pause[0] === 'paused' && out.pause[1] === 'countdown' && out.launch.mode === 'play' && out.launch.speedKmh >= 19 && /PARFAIT/.test(out.launch.toast)
    && out.race.mode === 'finish' && out.result1.mode === 'raceover' && /VICTOIRE|2e PLACE/.test(out.result1.title) && out.result1.stored
    && out.second.mode === 'finish' && !out.second.won && out.second.gapT < 0 && out.result2.title === '2e PLACE' && out.crash === 'crash' && out.result3 === 'ACCIDENT !'
    && out.garage.mode === 'menu' && !out.garage.racing && out.garage.oppGone && /course/.test(out.garage.record);
  console.log(ok ? 'PASS' : 'FAIL', JSON.stringify(out), errs.length ? 'ERR ' + errs.join(' | ') : 'no errors');
  await b.close(); srv.close();
})();
