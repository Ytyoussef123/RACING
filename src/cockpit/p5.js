
    // ================= instruments, screen and small printed parts =================
    const FONT = '"Saira Condensed", "Arial Narrow", Arial, sans-serif';
    const CL = { w: 0.37, h: 0.123, px: 1024, py: 340 };                      // cluster plate size (m) and canvas (px)
    const DIALS = [{ x: 212, y: 172, r: 148, max: 320, step: 20, lab: 40, unit: 'km/h' }, { x: 512, y: 172, r: 166, max: 8, step: 0.5, lab: 1, unit: 'x1000 tr/min', red: 7 }, { x: 812, y: 172, r: 148, info: true }];
    const A0 = Math.PI * 0.75, A1 = Math.PI * 2.25;                           // 270° sweep from lower left
    const faceTex = tex(cv(CL.px, CL.py, (x, w, h) => {
      x.fillStyle = '#030405'; x.fillRect(0, 0, w, h);
      for (const d of DIALS) {
        const g = x.createRadialGradient(d.x, d.y - 30, 10, d.x, d.y, d.r); g.addColorStop(0, '#15181c'); g.addColorStop(1, '#050607');
        x.fillStyle = g; x.beginPath(); x.arc(d.x, d.y, d.r, 0, Math.PI * 2); x.fill();
        x.strokeStyle = '#2b3036'; x.lineWidth = 3; x.stroke();
        x.textAlign = 'center'; x.textBaseline = 'middle';
        if (d.info) {
          // fuel and temperature arcs around a small digital window
          for (const [a0, a1, lab0, lab1] of [[Math.PI * 0.8, Math.PI * 1.2, 'E', 'F'], [Math.PI * 1.8, Math.PI * 2.2, 'C', 'H']]) {
            x.strokeStyle = '#d9dee4'; x.lineWidth = 3; x.beginPath(); x.arc(d.x, d.y, d.r - 26, a0, a1); x.stroke();
            for (let i = 0; i <= 4; i++) { const a = a0 + (a1 - a0) * i / 4; x.beginPath(); x.moveTo(d.x + Math.cos(a) * (d.r - 26), d.y + Math.sin(a) * (d.r - 26)); x.lineTo(d.x + Math.cos(a) * (d.r - (i % 2 ? 38 : 46)), d.y + Math.sin(a) * (d.r - (i % 2 ? 38 : 46))); x.stroke(); }
            x.fillStyle = '#c9d0d8'; x.font = '600 24px ' + FONT;
            x.fillText(lab0, d.x + Math.cos(a0) * (d.r - 66), d.y + Math.sin(a0) * (d.r - 66)); x.fillText(lab1, d.x + Math.cos(a1) * (d.r - 66), d.y + Math.sin(a1) * (d.r - 66));
          }
          x.fillStyle = '#0d1014'; x.fillRect(d.x - 62, d.y - 40, 124, 80); x.strokeStyle = '#262b31'; x.strokeRect(d.x - 62, d.y - 40, 124, 80);
          continue;
        }
        const n = Math.round(d.max / d.step);
        for (let i = 0; i <= n; i++) {
          const v = i * d.step, a = A0 + (A1 - A0) * v / d.max, big = Math.abs(v / d.lab - Math.round(v / d.lab)) < 1e-6;
          const r0 = d.r - (big ? 30 : 18);
          x.strokeStyle = d.red && v >= d.red ? '#ff3b1f' : '#eef2f6'; x.lineWidth = big ? 5 : 2.5;
          x.beginPath(); x.moveTo(d.x + Math.cos(a) * r0, d.y + Math.sin(a) * r0); x.lineTo(d.x + Math.cos(a) * (d.r - 6), d.y + Math.sin(a) * (d.r - 6)); x.stroke();
          if (big) { x.fillStyle = d.red && v >= d.red ? '#ff5a3a' : '#e9edf2'; x.font = `700 ${d.r > 160 ? 34 : 28}px ${FONT}`; x.fillText(v, d.x + Math.cos(a) * (d.r - 54), d.y + Math.sin(a) * (d.r - 54)); }
        }
        if (d.red) { x.strokeStyle = 'rgba(255,40,20,0.85)'; x.lineWidth = 7; x.beginPath(); x.arc(d.x, d.y, d.r - 10, A0 + (A1 - A0) * d.red / d.max, A1); x.stroke(); }
        x.fillStyle = '#8f9aa6'; x.font = '600 18px ' + FONT; x.fillText(d.unit, d.x, d.y + d.r * 0.62);
      }
    }), { clamp: true });
    const readCv = document.createElement('canvas'); readCv.width = 512; readCv.height = 128;
    const readTex = tex(readCv, { clamp: true });
    let readKey = '';
    function drawReadout(kmh, gear, nitro, clock, nitroOn) {
      const key = kmh + '|' + gear + '|' + Math.round(nitro * 20) + '|' + clock + '|' + nitroOn;
      if (key === readKey) return; readKey = key;
      const x = readCv.getContext('2d');
      x.fillStyle = '#05070a'; x.fillRect(0, 0, 512, 128);
      x.textAlign = 'center'; x.textBaseline = 'alphabetic';
      x.fillStyle = nitroOn ? '#8fb8ff' : '#ffffff'; x.font = '800 86px ' + FONT; x.fillText(kmh, 116, 96);
      x.fillStyle = '#8c98a5'; x.font = '600 20px ' + FONT; x.fillText('KM/H', 116, 120);
      x.fillStyle = '#ffb21e'; x.font = '800 64px ' + FONT; x.fillText(gear, 222, 90);
      // right window: nitro gauge and clock
      x.fillStyle = '#7f8b98'; x.font = '600 22px ' + FONT; x.fillText('NOS', 300, 44);
      x.fillStyle = '#1b2430'; x.fillRect(330, 28, 140, 18); x.fillStyle = '#4d8dff'; x.fillRect(330, 28, 140 * nitro, 18);
      x.fillStyle = '#e8edf2'; x.font = '700 48px ' + FONT; x.fillText(clock, 400, 104);
      readTex.needsUpdate = true;
    }
    // centre screen: navigation map that scrolls with the distance driven
    const scrCv = document.createElement('canvas'); scrCv.width = 512; scrCv.height = 288;
    const scrTex = tex(scrCv, { clamp: true });
    function drawScreen(dist, kmh) {
      const x = scrCv.getContext('2d'), w = 512, h = 288, off = (dist * 0.9) % 120;
      x.fillStyle = '#16202b'; x.fillRect(0, 0, w, h);
      x.fillStyle = '#0d3d52'; x.fillRect(0, 0, 150, h);                    // the ocean on the left
      x.fillStyle = '#d9c9a0'; x.globalAlpha = 0.25; x.fillRect(150, 0, 22, h); x.globalAlpha = 1;
      x.strokeStyle = '#2c3a48'; x.lineWidth = 10;
      for (let y = -120 + off; y < h + 120; y += 120) { x.beginPath(); x.moveTo(250, y); x.lineTo(w, y - 40); x.stroke(); x.beginPath(); x.moveTo(250, y + 60); x.lineTo(380, y + 110); x.stroke(); }
      x.strokeStyle = '#3d4d5e'; x.lineWidth = 34; x.beginPath(); x.moveTo(230, h + 10); x.lineTo(232, -10); x.stroke();
      x.strokeStyle = '#3d8bff'; x.lineWidth = 12; x.beginPath(); x.moveTo(231, 205); x.lineTo(232, -10); x.stroke();
      x.fillStyle = '#ffffff'; x.beginPath(); x.moveTo(231, 186); x.lineTo(246, 222); x.lineTo(231, 213); x.lineTo(216, 222); x.closePath(); x.fill();
      x.fillStyle = 'rgba(8,12,18,0.82)'; x.fillRect(0, 0, w, 34); x.fillRect(300, h - 74, 200, 62);
      x.fillStyle = '#e7edf3'; x.font = '600 20px ' + FONT; x.textBaseline = 'middle'; x.textAlign = 'left';
      x.fillText('Bd de la Corniche', 14, 17); x.textAlign = 'right'; x.fillText('24°C   17:42', w - 14, 17);
      x.textAlign = 'left'; x.font = '700 30px ' + FONT; x.fillText('↑ 2,4 km', 316, h - 52); x.font = '500 18px ' + FONT; x.fillStyle = '#9fb0c2'; x.fillText('Aïn Diab', 316, h - 24);
      x.textAlign = 'right'; x.fillStyle = '#e7edf3'; x.font = '700 22px ' + FONT; x.fillText(kmh + ' km/h', 488, h - 24);
      scrTex.needsUpdate = true;
    }
    const climateTex = tex(cv(512, 128, (x, w, h) => {
      x.fillStyle = '#040506'; x.fillRect(0, 0, w, h); x.textAlign = 'center'; x.textBaseline = 'middle';
      x.fillStyle = '#e8edf2'; x.font = '700 40px ' + FONT; x.fillText('21.5', 64, 62); x.fillText('22.0', 448, 62);
      x.strokeStyle = '#59636e'; x.lineWidth = 2;
      const icons = ['A/C', 'AUTO', '❄', '⟲', '▲'];
      icons.forEach((t, i) => { const cx = 152 + i * 52; x.strokeRect(cx - 22, 38, 44, 48); x.fillStyle = i === 1 ? '#ffb21e' : '#cfd6dd'; x.font = '600 18px ' + FONT; x.fillText(t, cx, 62); });
    }), { clamp: true });
    const buttonsTex = tex(cv(256, 112, (x, w, h) => {
      x.fillStyle = '#0b0c0e'; x.fillRect(0, 0, w, h);
      const lab = ['◀◀', '▶▶', '+', '−', '☎', 'OK', '▲', '▼'];
      for (let i = 0; i < 8; i++) { const cx = 32 + (i % 4) * 64, cy = 30 + Math.floor(i / 4) * 52;
        x.fillStyle = '#1c1e22'; x.beginPath(); x.ellipse(cx, cy, 26, 20, 0, 0, Math.PI * 2); x.fill(); x.strokeStyle = '#3a3e45'; x.lineWidth = 2; x.stroke();
        x.fillStyle = '#d5dbe2'; x.font = '600 20px Arial, sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText(lab[i], cx, cy + 1); }
    }), { clamp: true });
    const emblemTex = tex(cv(128, 128, (x) => {
      const g = x.createLinearGradient(0, 0, 128, 128); g.addColorStop(0, '#f2f4f7'); g.addColorStop(1, '#8d939b');
      x.fillStyle = '#121418'; x.beginPath(); x.arc(64, 64, 60, 0, Math.PI * 2); x.fill();
      x.strokeStyle = g; x.lineWidth = 7; x.beginPath(); x.arc(64, 64, 54, 0, Math.PI * 2); x.stroke();
      x.lineWidth = 6; x.beginPath(); x.arc(64, 70, 22, Math.PI, 0); x.stroke();
      x.beginPath(); x.moveTo(24, 86); x.bezierCurveTo(44, 74, 52, 98, 64, 86); x.bezierCurveTo(76, 74, 84, 98, 104, 86); x.stroke();
    }), { clamp: true });
    const auxTex = (k) => tex(cv(128, 128, (x, w, h) => {
      const g = x.createRadialGradient(64, 58, 6, 64, 64, 62); g.addColorStop(0, '#181b1f'); g.addColorStop(1, '#050607');
      x.fillStyle = g; x.beginPath(); x.arc(64, 64, 62, 0, Math.PI * 2); x.fill();
      x.strokeStyle = '#3a4048'; x.lineWidth = 3; x.stroke();
      const a0 = Math.PI * 0.8, a1 = Math.PI * 2.2;
      for (let i = 0; i <= 10; i++) { const a = a0 + (a1 - a0) * i / 10, big = i % 5 === 0; x.strokeStyle = i >= 9 && k % 2 ? '#ff4a2a' : '#e6ebf0'; x.lineWidth = big ? 4 : 2; x.beginPath(); x.moveTo(64 + Math.cos(a) * (big ? 40 : 46), 64 + Math.sin(a) * (big ? 40 : 46)); x.lineTo(64 + Math.cos(a) * 55, 64 + Math.sin(a) * 55); x.stroke(); }
      const an = a0 + (a1 - a0) * [0.42, 0.55, 0.3, 0.62, 0.5, 0.36, 0.7][k % 7];
      x.strokeStyle = '#ff6a1f'; x.lineWidth = 4; x.beginPath(); x.moveTo(64 - Math.cos(an) * 8, 64 - Math.sin(an) * 8); x.lineTo(64 + Math.cos(an) * 47, 64 + Math.sin(an) * 47); x.stroke();
      x.fillStyle = '#23272c'; x.beginPath(); x.arc(64, 64, 8, 0, Math.PI * 2); x.fill();
    }), { clamp: true });
    const gateTex = tex(cv(128, 256, (x, w, h) => {
      x.fillStyle = '#060708'; x.fillRect(0, 0, w, h); x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '700 34px ' + FONT;
      ['P', 'R', 'N', 'D'].forEach((t, i) => { x.fillStyle = t === 'D' ? '#ffb21e' : '#7c8692'; x.fillText(t, 104, 40 + i * 52); });
    }), { clamp: true });
