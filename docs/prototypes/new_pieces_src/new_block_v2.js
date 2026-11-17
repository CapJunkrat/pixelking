  // ---------- v2: reworked attacks after review ----------
  Object.assign(STARTS, { martyr: { x: 3, y: 5 }, echo: { x: 3, y: 6 } });
  Object.assign(HITNAME, { resonance: '共振', burn: '灼烧', erupt: '地刺', toss: '挑飞' });
  const windStreaks = (o) => { for (let i = 0; i < 3; i++) { const p = project(o.X - G.dx * rnd(4, 14), o.Y + pxToY(rnd(2, 12)), o.Z - G.dz * rnd(4, 14)), sd = G.screenDir, l = rnd(4, 8); ctx.strokeStyle = 'rgba(230,245,255,.55)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - sd.x * l, p.y - sd.y * l); ctx.stroke(); } };

  Object.assign(ATK, {
    courier: {
      name: "COURIER GALE CUT", hit: 'slash', impact: .44, end: 2.0, hitstop: .11, shake: .6,
      title: "疾风信使 · 两步疾风斩", desc: "第一步轻跳到中间一格，脚刚落地就化作一阵风，身后拖着白色风痕笔直冲到目标面前，借冲势横斩一刀；冲过头半步急停，再退回站进格子。身体始终立着，只在冲刺时被风压得略微前倾。",
      events: [{ at: .06, fn: () => puff(G.a.X, 1, G.a.Z, 4, .5) }, { at: .26, fn: () => { const m = { X: (G.a.X + G.b.X) / 2, Z: (G.a.Z + G.b.Z) / 2 }; puff(m.X, 1, m.Z, 6, .7); } }],
      pose(u) {
        const { a, b, face } = G, c = V.cell, m = { X: (a.X + b.X) / 2, Z: (a.Z + b.Z) / 2 }, C = toward(b, .45), over = { X: C.X + G.dx * 4, Z: C.Z + G.dz * 4 }, o = O('courierw');
        if (u < 0) return o;
        if (u < .06) { o.sy = .88; o.sx = 1.08; return o; }
        if (u < .26) { const q = (u - .06) / .2; o.X = lerp(a.X, m.X, q); o.Z = lerp(a.Z, m.Z, q); o.Y = c * .4 * 4 * q * (1 - q); return o; }
        if (u < .3) { o.X = m.X; o.Z = m.Z; o.sy = .85; o.sx = 1.1; return o; }
        if (u < .44) { const q = (u - .3) / .14; o.X = lerp(m.X, C.X, easeIn(q)); o.Z = lerp(m.Z, C.Z, easeIn(q)); o.rot = .08 * face; o.sx = 1.12; o.sy = .92; o.trail = true; o.windy = true; return o; }
        if (u < .58) { const q = (u - .44) / .14; o.X = lerp(C.X, over.X, easeOut(q)); o.Z = lerp(C.Z, over.Z, easeOut(q)); o.rot = .08 * face * (1 - q); return o; }
        return settleInto(o, over, u, .75, .25, 1.5);
      },
      fx(o, u) { if (o.windy || (u > .44 && u < .55)) windStreaks(o); },
      hitFx() { slash = { age: 0, life: .45 }; sparkBurst(G.b.X, 9, G.b.Z, 9, G.dx, G.dz, 60, .7, '230,245,255'); }
    },
    tide_knight: {
      name: "TIDE KNIGHT WAVE CHARGE", hit: 'blunt', impact: .62, end: 2.3, hitstop: .12, shake: 1.2,
      title: "潮汐骑士 · 巨浪冲锋", desc: "骑士人立长嘶，脚下卷起一道浪；它骑着浪头全速冲锋，浪越涌越高，连人带浪正面撞上目标，浪头“轰”地炸成一片水花，把目标冲飞。冲锋余势让它多冲出半步，浪退后才站进格子。",
      events: [{ at: .22, fn: () => { ring(G.a.X, G.a.Z, V.cell * .6, .35, WATER); } }],
      pose(u) {
        const { a, face } = G, c = V.cell, C = toward(G.b, .5), o = O('tide_knightw');
        if (u < 0) return o;
        if (u < .25) { const s = Math.sin(u / .25 * Math.PI); o.rot = -.32 * s * face; o.Y = c * .15 * s; return o; }
        if (u < .62) { const q = (u - .25) / .37, e = easeIn(q); o.X = lerp(a.X, C.X, e); o.Z = lerp(a.Z, C.Z, e); o.Y = c * .18 * q + Math.abs(Math.sin(q * Math.PI * 3)) * 2; o.rot = .1 * face; o.trail = q > .3; o.wave = q; return o; }
        if (u < .8) { const q = (u - .62) / .18; o.X = C.X + G.dx * 5 * easeOut(q); o.Z = C.Z + G.dz * 5 * easeOut(q); o.Y = c * .18 * (1 - q); o.rot = .1 * face * (1 - q); return o; }
        return settleInto(o, { X: C.X + G.dx * 5, Z: C.Z + G.dz * 5 }, u, .9, .3, 1);
      },
      fx(o, u) {
        if (o.wave === undefined) return; const q = o.wave, sd = G.screenDir, base = project(o.X, 0, o.Z), h = 3 + 7 * q;
        for (let i = -9; i <= 4; i++) { const x = base.x - sd.x * i * 1.5, y = base.y - sd.y * i * 1.5, top = Math.round(y - h * Math.max(0, 1 - Math.abs(i + 2) / 8)); ctx.fillStyle = 'rgba(80,150,230,.85)'; ctx.fillRect(Math.round(x), top, 1, Math.round(y) - top + 1); ctx.fillStyle = '#e6f6ff'; ctx.fillRect(Math.round(x), top, 1, 1); }
        if (Math.random() < .8) parts.push({ X: o.X + rnd(-4, 4), Y: pxToY(h), Z: o.Z, vx: rnd(-20, 20) - G.dx * 30, vy: rnd(20, 50), vz: rnd(-6, 6), col: Math.random() < .5 ? '#9fd4ff' : '#e6f6ff', life: rnd(.3, .5), age: 0, sz: 1, bounced: 2, g: 220 });
      },
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.3, .5, WATER); ring(b.X, b.Z, V.cell * .7, .32, '230,246,255'); sparkBurst(b.X, 8, b.Z, 18, G.dx, G.dz, 60, 1, WATER); for (let i = 0; i < 30; i++) parts.push({ X: b.X + rnd(-5, 5), Y: pxToY(rnd(2, 10)), Z: b.Z, vx: rnd(-50, 50) + G.dx * 40, vy: rnd(40, 110), vz: rnd(-20, 20), col: Math.random() < .5 ? '#9fd4ff' : '#e6f6ff', life: rnd(.5, .9), age: 0, sz: Math.random() < .3 ? 2 : 1, bounced: 2, g: 260 }); }
    },
    echo: {
      name: "ECHO RESONANCE", hit: 'resonance', impact: .72, end: 2.3, hitstop: .06, shake: .5,
      title: "回声 · 共鸣震碎", desc: "回声原地张开双臂，身上一圈圈泛起声波。一道道声波沿着棋盘传向目标，越靠近越密；声波把目标团团围住时，它开始跟着嗡嗡共振、越抖越厉害，身上裂开一道道横纹，最后整个被震碎。",
      events: [],
      pose: rangedPose('echow', { windup: .3, recoil: .1, walkAt: 1.55, walk: .45, lean: -.06 }),
      fx(o, u) {
        if (u < .05 || (impacted && rt > .6)) return;
        const src = { X: G.a.X, Y: pxToY(8), Z: G.a.Z }, dst = vicCentre(.5);
        for (let i = 0; i < 6; i++) { const ph = (u * 2.2 - i * .17); if (ph < 0 || ph > 1) continue; const p = lerp3(src, dst, Math.min(ph, 1)), pr = project(p.X, p.Y, p.Z), r = 3 + 5 * ph; ctx.strokeStyle = `rgba(190,170,255,${.8 * (1 - Math.abs(ph - .5))})`; ctx.lineWidth = 1; ctx.beginPath(); ctx.ellipse(Math.round(pr.x), Math.round(pr.y), r, r * .7, 0, 0, Math.PI * 2); ctx.stroke(); }
        if (impacted) { const pr = project(dst.X, dst.Y, dst.Z); for (let i = 0; i < 2; i++) { const r = 6 + ((rt * 40 + i * 6) % 12); ctx.strokeStyle = `rgba(190,170,255,${.6 * (1 - rt / .6)})`; ctx.beginPath(); ctx.ellipse(Math.round(pr.x), Math.round(pr.y), r, r * .7, 0, 0, Math.PI * 2); ctx.stroke(); } }
      },
      hitFx() { ring(G.b.X, G.b.Z, V.cell * .7, .35, '190,170,255'); },
      react: () => RESONANCE
    },
    stand_in: {
      name: "STAND-IN GRAPPLE KICK", hit: 'blunt', impact: .7, end: 2.2, hitstop: .11, shake: .8,
      title: "替身 · 飞爪飞踢", desc: "替身甩出一只带绳子的飞爪，飞爪“咔”地钩住目标；它借绳子猛地一拉，整个人被拽离地面平飞过去，借着拉力一脚踢中目标。身子保持直立、被拉得略长，落地后收回飞爪，站进格子。",
      events: [{ at: .46, fn: () => sparkBurst(G.b.X, 9, G.b.Z, 4, 0, 0, 0, .3) }],
      hand(o) { return { X: o.X + G.face * 3, Y: o.Y + pxToY(8), Z: o.Z }; },
      pose(u) {
        const { a, face } = G, c = V.cell, C = toward(G.b, .5), o = O('stand_inw');
        if (u < 0) return o;
        if (u < .25) { const s = smooth(u / .25); o.rot = -.15 * s * face; return o; }
        if (u < .5) { o.rot = lerp(-.15, .05, (u - .25) / .25) * face; return o; }
        if (u < .54) { o.sy = .85; o.sx = 1.1; return o; }
        if (u < .7) { const q = (u - .54) / .16, e = easeIn(q); o.X = lerp(a.X, C.X, e); o.Z = lerp(a.Z, C.Z, e); o.Y = c * .45 * Math.sin(q * Math.PI * .9); o.sx = 1.15; o.sy = .9; o.trail = true; return o; }
        if (u < .86) { const q = (u - .7) / .16; o.X = C.X - G.dx * 4 * Math.sin(q * Math.PI * .5); o.Z = C.Z - G.dz * 4 * Math.sin(q * Math.PI * .5); o.Y = c * .1 * (1 - q); return o; }
        return settleInto(o, { X: C.X - G.dx * 4, Z: C.Z - G.dz * 4 }, u, .95, .28, 2);
      },
      fx(o, u) {
        if (u < .25 || u > .72) return;
        const h = this.hand(o), vc = vicCentre(.6), hook = u < .46 ? lerp3(h, vc, easeOut((u - .25) / .21)) : vc;
        const ph = project(h.X, h.Y, h.Z), pk = project(hook.X, hook.Y, hook.Z), sag = u < .5 ? 3 : 0;
        ctx.strokeStyle = '#8a7a5a'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(ph.x, ph.y); ctx.quadraticCurveTo((ph.x + pk.x) / 2, (ph.y + pk.y) / 2 + sag, pk.x, pk.y); ctx.stroke();
        const x = Math.round(pk.x), y = Math.round(pk.y); ctx.fillStyle = '#dfe6f0'; ctx.fillRect(x - 1, y - 1, 3, 1); ctx.fillRect(x - 1, y, 1, 2); ctx.fillRect(x + 1, y, 1, 2);
      },
      hitFx() { sparkBurst(G.b.X, 10, G.b.Z, 9, G.dx, G.dz, 60, .7); ring(G.b.X, G.b.Z, V.cell * .7, .3); puff(G.b.X, 2, G.b.Z, 6, .8); }
    },
    squire: {
      name: "SQUIRE TWIN JAB", hit: 'pierce', impact: .52, end: 2.4, hitstop: .09, shake: .5,
      title: "侍从 · 连刺并升级", desc: "侍从还是个孩子，打法很拼：冲到目标面前，用小剑“噗噗”连戳两下，第一下把对方戳得一晃，第二下刺穿。吃掉目标后脚下亮起金光、头顶冒出升级箭头和星星。",
      events: [{ at: .4, fn: () => { sparkBurst(G.b.X, 9, G.b.Z, 4, G.dx, G.dz, 40, .4); R.wobbleT = t; } }, { at: 1.05, fn: () => { ring(G.b.X, G.b.Z, V.cell * .7, .45, GOLDC); ring(G.b.X, G.b.Z, V.cell * .4, .3, GOLDC); fallingStars({ X: G.b.X, Y: pxToY(12), Z: G.b.Z }, 10, '#ffe08a'); } }],
      pose(u) {
        const { a } = G, C = toward(G.b, .5), o = O('squirew');
        if (u < 0) return o;
        if (u < .14) { o.sy = .9; o.sx = 1.06; return o; }
        if (u < .34) { const q = (u - .14) / .2; o.X = lerp(a.X, C.X, q); o.Z = lerp(a.Z, C.Z, q); o.Y = Math.abs(Math.sin(q * Math.PI * 2)) * 2; return o; }
        const jab = (s, e) => { const q = clamp01((u - s) / (e - s)); return Math.sin(q * Math.PI); };
        const k = u < .44 ? jab(.34, .44) : jab(.44, .56);
        o.X = C.X + G.dx * 3 * k; o.Z = C.Z + G.dz * 3 * k; o.sx = 1 + .08 * k; o.sy = 1 - .06 * k;
        if (u < .75) return o;
        return settleInto(o, C, u, .75, .25, 2);
      },
      fx(o, u) {
        if (u > .3 && u < .6) { const h = handAt(o, 7), tip = { X: h.X + G.dx * 8, Y: h.Y, Z: h.Z + G.dz * 8 }, p = project(h.X, h.Y, h.Z), q = project(tip.X, tip.Y, tip.Z); pixLine(p.x, p.y, q.x, q.y, '#dfe6f0'); }
        if (u < 1.05 || u > 1.85) return; const k = (u - 1.05) / .8, p = project(o.X, o.Y + pxToY(16) + k * 8, o.Z), x = Math.round(p.x), y = Math.round(p.y); ctx.fillStyle = `rgba(255,226,120,${1 - k})`; ctx.fillRect(x, y, 1, 5); ctx.fillRect(x - 1, y + 1, 3, 1); ctx.fillRect(x - 2, y + 2, 5, 1);
      },
      hitFx() { sparkBurst(G.b.X, 9, G.b.Z, 9, G.dx, G.dz, 80, .6); }
    },
    ember_bird: {
      name: "EMBER BIRD FIRE FEATHERS", hit: 'burn', impact: .7, hitstop: .08, shake: .5,
      title: "余烬鸟 · 火羽连射", desc: "余烬鸟原地展翅，每扇一下翅膀就射出一根燃烧的羽毛，三根火羽一根接一根钉进目标。火从羽毛处烧起来，顺着身体往上蔓延，把目标烧得焦黑，最后塌成一堆灰烬。之后余烬鸟扇着翅膀飞进格子。",
      events: [],
      pose(u) {
        const { a, b } = G, c = V.cell, o = O('ember_birdw');
        if (u < 0) return o;
        o.sy = 1 + .1 * Math.sin(u * 28) * (u < .75 ? 1 : 0); o.sx = 1 - .05 * Math.sin(u * 28) * (u < .75 ? 1 : 0); o.Y = u < .75 ? c * .12 * smooth(clamp01(u / .2)) : 0;
        const fly = .75 + this.burnT() + .2;
        if (u < fly) return o;
        const q = clamp01((u - fly) / .5); o.X = lerp(a.X, b.X, smooth(q)); o.Z = lerp(a.Z, b.Z, smooth(q)); o.Y = c * .9 * Math.sin(q * Math.PI); o.sy = 1 + .1 * Math.sin(u * 40); return o;
      },
      burnT() { return [.6, .8, 1.0][WEIGHT[vicKey]]; },
      get end() { return .75 + this.burnT() + 1.4; },
      feather(i, u) { const s = .3 + i * .14, q = clamp01((u - s) / .26); if (u < s) return null; const src = { X: G.a.X + G.face * 2, Y: pxToY(9), Z: G.a.Z }, dst = vicCentre(.3 + i * .2); const p = lerp3(src, dst, q); p.Y += V.cell * .4 * 4 * q * (1 - q); return { p, q }; },
      fx(o, u) {
        for (let i = 0; i < 3; i++) { const f = this.feather(i, u); if (!f) continue; if (f.q >= 1 && (!impacted || rt > .5)) continue; const pr = project(f.p.X, f.p.Y, f.p.Z), x = Math.round(pr.x), y = Math.round(pr.y); ctx.fillStyle = '#ff5a2a'; ctx.fillRect(x - 1, y, 3, 1); ctx.fillStyle = '#ffd27a'; ctx.fillRect(x, y, 1, 1); if (f.q < 1 && Math.random() < .7) parts.push({ X: f.p.X, Y: f.p.Y, Z: f.p.Z, vx: rnd(-8, 8), vy: rnd(0, 10), vz: 0, col: Math.random() < .5 ? '#ff8a3c' : '#ffd27a', life: rnd(.15, .3), age: 0, sz: 1, bounced: 2, g: -20 }); }
      },
      hitFx() { sparkBurst(G.b.X, 8, G.b.Z, 8, 0, 0, 0, .5, ORANGE); },
      react: () => BURN
    },
    gargoyle: {
      name: "GARGOYLE QUAKE", hit: 'erupt', impact: .66, end: 2.6, hitstop: .12, shake: 1.2,
      title: "石像守卫 · 裂地石刺", desc: "石像守卫不用移动：它挺身高举双拳，重重捶向地面，一道裂缝顺着棋盘飞快窜向目标；裂缝到达的瞬间，一圈石刺从目标脚下猛地顶出来，把它掀上半空摔碎。之后石像迈着沉重的步子走进格子。",
      events: [{ at: .38, fn: () => { puff(G.a.X, 1, G.a.Z, 10, 1.1); ring(G.a.X, G.a.Z, V.cell * .9, .4); shake = Math.max(shake, .8); } }],
      pose(u) {
        const { a, b } = G, c = V.cell, o = O('gargoylew');
        if (u < 0) return o;
        if (u < .3) { const s = smooth(u / .3); o.sy = 1 + .12 * s; o.Y = c * .1 * s; return o; }
        if (u < .38) { const q = (u - .3) / .08; o.Y = c * .1 * (1 - q); o.sy = 1.12 - .32 * q; o.sx = 1 + .2 * q; return o; }
        if (u < .55) { const q = (u - .38) / .17; o.sy = .8 + .2 * q; o.sx = 1.2 - .2 * q; return o; }
        if (u < 1.5) return o;
        const q = clamp01((u - 1.5) / .6), step = Math.floor(q * 2), local = q * 2 - step; o.X = lerp(a.X, b.X, (step + smooth(local)) / 2); o.Z = lerp(a.Z, b.Z, (step + smooth(local)) / 2); o.Y = Math.sin(local * Math.PI) * 3; return o;
      },
      groundFx(o, u) {
        if (u < .38 || (impacted && rt > 1.2)) return; const q = clamp01((u - .38) / .28), n = Math.floor(q * 40), fade = impacted ? 1 - rt / 1.2 : 1;
        ctx.fillStyle = `rgba(14,9,6,${.85 * fade})`;
        for (let i = 0; i < n; i++) { const k = i / 40, w = Math.sin(i * 1.7) * 2.5, p = project(lerp(G.a.X, G.b.X, k) + G.dz * w, 0, lerp(G.a.Z, G.b.Z, k) - G.dx * w); ctx.fillRect(Math.round(p.x), Math.round(p.y), 1, 1); }
      },
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.2, .45); puff(b.X, 2, b.Z, 12, 1.3); crackDecal(b.X, b.Z, 8, V.cell * .9); },
      react: () => ERUPT
    },
    antelope: {
      name: "ANTELOPE HORN TOSS", hit: 'toss', impact: .74, end: 2.4, hitstop: .1, shake: .9,
      title: "羚羊 · 跃角挑飞", desc: "羚羊后腿一蹬，高高跃过中间的棋子，轻巧地落在目标面前；落地瞬间压低脑袋，双角往下一勾再猛地向上一挑，把目标整个挑上天，翻着跟头飞出去摔碎。",
      events: [{ at: .22, fn: () => puff(G.a.X, 1, G.a.Z, 7, .9) }, { at: .6, fn: () => { const C = toward(G.b, .55); puff(C.X, 1, C.Z, 6, .8); } }],
      pose(u) {
        const { a, face } = G, c = V.cell, C = toward(G.b, .55), o = O('antelopew');
        if (u < 0) return o;
        if (u < .22) { const s = Math.sin(u / .22 * Math.PI / 2); o.sy = 1 - .2 * s; o.sx = 1 + .1 * s; return o; }
        if (u < .6) { const q = (u - .22) / .38; o.X = lerp(a.X, C.X, q); o.Z = lerp(a.Z, C.Z, q); o.Y = c * 2.4 * 4 * q * (1 - q); o.rot = lerp(-.25, .2, q) * face; o.trail = q > .3; return o; }
        o.X = C.X; o.Z = C.Z;
        if (u < .66) { const q = (u - .6) / .06; o.sy = 1 - .15 * Math.sin(q * Math.PI); o.sx = 1 + .1 * Math.sin(q * Math.PI); return o; }
        if (u < .74) { const q = (u - .66) / .08; o.rot = .35 * q * face; o.sy = .92; return o; }
        if (u < .9) { const q = (u - .74) / .16; o.rot = lerp(.35, -.3, easeOut(q)) * face; o.Y = c * .15 * Math.sin(q * Math.PI); return o; }
        if (u < 1.05) { o.rot = -.3 * face * (1 - (u - .9) / .15); return o; }
        return settleInto(o, C, u, 1.2, .3, 2);
      },
      hitFx() { sparkBurst(G.b.X, 6, G.b.Z, 8, G.dx, G.dz, 40, .6); puff(G.b.X, 2, G.b.Z, 6, .8); },
      react: () => TOSS
    },
    ranger: {
      name: "RANGER BOOMERANG", hit: 'slash', impact: .58, end: 2.3, hitstop: .1, shake: .6,
      title: "游侠 · 回旋镖", desc: "游侠侧身一甩，回旋镖旋转着画一道弧线飞出去，从目标身上横切而过，在空中拐个弯又飞回来，被游侠单手接住。然后游侠沿着棋盘边快步走进格子。",
      events: [],
      pose(u) {
        const { a, face } = G, o = O('rangerw');
        if (u < 0) return o;
        if (u < .3) { const s = smooth(u / .3); o.rot = -.22 * s * face; o.sx = 1 + .05 * s; return o; }
        if (u < .42) { const q = (u - .3) / .12; o.rot = lerp(-.22, .18, easeOut(q)) * face; return o; }
        if (u < .6) { o.rot = .18 * face * (1 - (u - .42) / .18); return o; }
        if (u > 1.05 && u < 1.2) { o.sy = 1 - .06 * Math.sin((u - 1.05) / .15 * Math.PI); }
        if (u < 1.35) return o;
        const q = clamp01((u - 1.35) / .5); o.X = lerp(a.X, G.b.X, smooth(q)); o.Z = lerp(a.Z, G.b.Z, smooth(q)); o.Y = Math.abs(Math.sin(q * Math.PI * 3)) * 2; return o;
      },
      boom(u) {
        const hand = { X: G.a.X + G.face * 3, Y: pxToY(9), Z: G.a.Z }, vc = vicCentre(.5), side = { X: -G.dz * V.cell * 1.2, Z: G.dx * V.cell * 1.2 };
        if (u < .38 || u > 1.12) return null;
        const q = (u - .38) / .74, ang = q * Math.PI * 2, along = (1 - Math.cos(ang)) / 2, out = Math.sin(ang);
        return { X: lerp(hand.X, vc.X + G.dx * 6, along) + side.X * out * .5, Y: lerp(hand.Y, vc.Y, Math.min(1, along * 1.2)) + 3 * Math.sin(ang), Z: lerp(hand.Z, vc.Z + G.dz * 6, along) + side.Z * out * .5 };
      },
      fx(o, u) { const p = this.boom(u); if (!p) return; const pr = project(p.X, p.Y, p.Z), x = Math.round(pr.x), y = Math.round(pr.y), r = u * 40; ctx.fillStyle = '#c8a070'; const pts = [[0, 0], [Math.cos(r), Math.sin(r)], [Math.cos(r) * 2, Math.sin(r) * 2], [Math.cos(r + 1.6), Math.sin(r + 1.6)], [Math.cos(r + 1.6) * 2, Math.sin(r + 1.6) * 2]]; for (const [dx, dy] of pts) ctx.fillRect(Math.round(x + dx), Math.round(y + dy), 1, 1); ctx.fillStyle = 'rgba(230,220,190,.35)'; ctx.fillRect(x - 2, y - 2, 5, 5); },
      hitFx() { slash = { age: 0, life: .45 }; sparkBurst(G.b.X, 9, G.b.Z, 8, G.dx, G.dz, 50, .6); }
    },
    war_king: {
      name: "WAR KING SKYFALL CLEAVE", hit: 'slash', impact: .68, end: 2.5, hitstop: .15, shake: 1.6,
      title: "战王 · 天坠斩", desc: "战王双手握剑、剑身亮起金光，屈膝一跃跳到目标正上方，在空中把剑高举过头，然后连人带剑笔直劈落。剑落地时砸出一圈金色冲击波和放射状的裂纹，整个棋盘都在震。",
      events: [{ at: .28, fn: () => puff(G.a.X, 1, G.a.Z, 8, 1) }],
      pose(u) {
        const { a, b, face } = G, c = V.cell, C = toward(b, .45), o = O('war_kingw');
        if (u < 0) return o;
        if (u < .28) { const s = smooth(u / .28); o.sy = 1 - .15 * s; o.sx = 1 + .08 * s; o.white = .5 * s * (.7 + .3 * Math.sin(u * 50)); return o; }
        if (u < .55) { const q = (u - .28) / .27; o.X = lerp(a.X, C.X, q); o.Z = lerp(a.Z, C.Z, q); o.Y = c * 2.2 * easeOut(q); o.rot = -.15 * face; o.white = .5; return o; }
        if (u < .6) { o.X = C.X; o.Z = C.Z; o.Y = c * 2.2; o.rot = -.2 * face; o.white = .6; return o; }
        if (u < .68) { const q = (u - .6) / .08; o.X = C.X; o.Z = C.Z; o.Y = c * 2.2 * (1 - easeIn(q)); o.rot = .2 * face; o.sy = 1.15; o.sx = .9; o.trail = true; return o; }
        o.X = C.X; o.Z = C.Z;
        if (u < .85) { const q = (u - .68) / .17, w = Math.sin(q * Math.PI); o.sx = 1 + .25 * w; o.sy = 1 - .2 * w; o.rot = .2 * face * (1 - q); return o; }
        return settleInto(o, C, u, 1.0, .3, 1);
      },
      hitFx() { const b = G.b; slash = { age: 0, life: .55 }; ring(b.X, b.Z, V.cell * 1.6, .55, GOLDC); ring(b.X, b.Z, V.cell * .9, .35, GOLDC); puff(b.X, 2, b.Z, 12, 1.3); crackDecal(b.X, b.Z, 10, V.cell * 1.3); sparkBurst(b.X, 6, b.Z, 16, 0, 0, 0, .9, GOLDC); }
    },
    monk: {
      name: "MONK SUN AND MOON PALMS", hit: 'blunt', impact: .62, end: 2.3, hitstop: .13, shake: 1.0,
      title: "日月僧侣 · 日月双掌", desc: "僧侣沉腰凝气，右掌亮起金光、左掌亮起银蓝光。第一掌（日）拍在目标身上，金色冲击波把对方震得一晃；紧接着侧身换手，第二掌（月）跟上，银蓝色冲击波把目标彻底打飞。",
      events: [{ at: .4, fn: () => { ring(G.b.X, G.b.Z, V.cell * .8, .35, GOLDC); sparkBurst(G.b.X, 8, G.b.Z, 10, G.dx, G.dz, 40, .6, GOLDC); R.wobbleT = t; hs = .06; shake = Math.max(shake, .5); } }],
      pose(u) {
        const { a, face } = G, C = toward(G.b, .6), o = O('monkw');
        if (u < 0) return o;
        if (u < .28) { const s = smooth(u / .28); o.sy = 1 - .1 * s; o.sx = 1 + .06 * s; o.white = .35 * s * (.6 + .4 * Math.sin(u * 40)); return o; }
        if (u < .4) { const q = (u - .28) / .12; o.X = lerp(a.X, C.X, easeIn(q)); o.Z = lerp(a.Z, C.Z, easeIn(q)); o.sx = 1.1; o.rot = .1 * face; return o; }
        o.X = C.X; o.Z = C.Z;
        if (u < .52) { const q = (u - .4) / .12; o.rot = lerp(.1, -.18, smooth(q)) * face; o.X -= G.dx * 2 * Math.sin(q * Math.PI); o.Z -= G.dz * 2 * Math.sin(q * Math.PI); return o; }
        if (u < .62) { const q = (u - .52) / .1; o.rot = lerp(-.18, .16, easeIn(q)) * face; o.sx = 1 + .12 * q; o.X += G.dx * 2 * q; o.Z += G.dz * 2 * q; return o; }
        if (u < .85) { const q = (u - .62) / .23; o.rot = .16 * face * (1 - q); o.X += G.dx * 2 * (1 - q); o.Z += G.dz * 2 * (1 - q); return o; }
        return settleInto(o, C, u, .9, .28, 1);
      },
      fx(o, u) { if (u > .3 && u < .62) { const k = u < .45 ? '#ffe08a' : '#a0c8ff', h = handAt(o, 7), p = project(h.X + G.dx * 5, h.Y, h.Z + G.dz * 5); ctx.fillStyle = k; ctx.fillRect(Math.round(p.x) - 1, Math.round(p.y) - 1, 3, 3); } },
      hitFx() { ring(G.b.X, G.b.Z, V.cell * 1.2, .45, MOON); ring(G.b.X, G.b.Z, V.cell * .6, .3, '230,240,255'); sparkBurst(G.b.X, 8, G.b.Z, 12, G.dx, G.dz, 60, .8, MOON); }
    },
    martyr: {
      name: "MARTYR CENSER SWING", hit: 'blunt', impact: .6, end: 2.2, hitstop: .08, shake: .5,
      title: "殉道者 · 香炉挥击", desc: "殉道者不会冲上去打人。它在原地抡起一只拴着长链的香炉，香炉绕着身体转两圈、拖出一道烟，然后被甩出去划一道大弧砸在目标身上，冒出一团香烟；链子收回后，殉道者才缓步走进格子。",
      events: [],
      pose: rangedPose('martyrw', { windup: .45, recoil: .15, walkAt: 1.3, walk: .45, lean: .1 }),
      censer(u) {
        const hand = { X: G.a.X + G.face * 3, Y: pxToY(8), Z: G.a.Z };
        if (u < .1) return hand;
        if (u < .45) { const ang = (u - .1) / .35 * Math.PI * 4, r = 6; return { X: hand.X + Math.cos(ang) * r, Y: hand.Y + 2 + Math.sin(ang) * 2, Z: hand.Z + Math.sin(ang) * r * .6 }; }
        const vc = vicCentre(.6);
        if (u < .6) { const q = easeIn((u - .45) / .15), p = lerp3(hand, vc, q); p.Y += V.cell * .6 * Math.sin(q * Math.PI); return p; }
        if (u < .9) { const q = smooth((u - .6) / .3); return lerp3(vc, hand, q); }
        return hand;
      },
      fx(o, u) {
        if (u < .08 || u > .95) return; const hand = { X: G.a.X + G.face * 3, Y: pxToY(8), Z: G.a.Z }, c = this.censer(u), ph = project(hand.X, hand.Y, hand.Z), pc = project(c.X, c.Y, c.Z);
        ctx.strokeStyle = '#b8a070'; ctx.lineWidth = 1; ctx.setLineDash([1, 1]); ctx.beginPath(); ctx.moveTo(ph.x, ph.y); ctx.lineTo(pc.x, pc.y); ctx.stroke(); ctx.setLineDash([]);
        const x = Math.round(pc.x), y = Math.round(pc.y); ctx.fillStyle = '#2a1e2e'; ctx.fillRect(x - 2, y - 1, 5, 4); ctx.fillStyle = '#e0b45c'; ctx.fillRect(x - 1, y, 3, 2);
        if (Math.random() < .5) smoke.push({ X: c.X, Y: c.Y, Z: c.Z, vx: rnd(-4, 4), vy: rnd(4, 10), vz: 0, r: rnd(1, 1.8), age: 0, life: rnd(.4, .7) });
      },
      hitFx() { sparkBurst(G.b.X, 10, G.b.Z, 7, G.dx, G.dz, 30, .5, GOLDC); puff(G.b.X, 6, G.b.Z, 10, .9); ring(G.b.X, G.b.Z, V.cell * .6, .3, GOLDC); }
    }
  });

  // --- v2 reactions ---
  const RESONANCE = { name: '共振震碎', desc: '被声波包围后开始嗡嗡共振，越抖越快、幅度越来越大，身上从下往上裂开一道道横纹；裂纹爬满全身的一刻，整个棋子沿着裂纹一层层震散。越重的棋子撑得越久。',
    get split() { return [.45, .6, .8][WEIGHT[vicKey]]; },
    draw(white) { const bs = base(), { x0, y0 } = footXY(), q = clamp01(rt / this.split), j = Math.round(Math.sin(rt * (60 + 80 * q)) * (.5 + 2 * q)); ctx.drawImage((white ? S[vicKey + 'k!'] : bs).c, x0 + j, y0); const bands = Math.floor(q * bs.h / 3); ctx.fillStyle = '#0b0710'; for (let i = 0; i < bands; i++) { const yy = bs.h - 2 - i * 3; for (const p of bs.pixels) if (p.y === yy && (p.x + i) % 2 === 0) ctx.fillRect(x0 + j + p.x, y0 + p.y, 1, 1); } },
    onSplit() { const bs = base(); for (let row = 0; row < bs.h; row += 3) debris(bs.pixels.filter(p => p.y >= row && p.y < row + 3), bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 20 + row * 2, spread: 35, radial: 3 }); ring(G.b.X, G.b.Z, V.cell * 1.1, .45, '190,170,255'); sparkBurst(G.b.X, 8, G.b.Z, 10, 0, 0, 0, .6, '190,170,255'); shake = Math.max(shake, .6); } };

  const BURN = { name: '燃烧成灰', desc: '火羽钉住的地方先冒出火苗，火焰顺着身体从下往上爬，烧过的部分变得焦黑；全身烧透后，整个棋子塌成一堆灰烬，飘起一缕黑烟。越重的棋子烧得越久。',
    get split() { return ATK.ember_bird.burnT(); },
    draw(white) { const bs = base(), { x0, y0 } = footXY(), q = clamp01(rt / this.split), k = Math.floor((1 - q) * bs.h); ctx.drawImage((white ? S[vicKey + 'k!'] : bs).c, x0, y0); if (k < bs.h) { ctx.globalAlpha = .85; ctx.drawImage(S[vicKey + 'k#'].c, 0, k, bs.w, bs.h - k, x0, y0 + k, bs.w, bs.h - k); ctx.globalAlpha = .55; ctx.drawImage(S[vicKey + 'k&'].c, 0, Math.max(0, k - 2), bs.w, 3, x0, y0 + Math.max(0, k - 2), bs.w, 3); ctx.globalAlpha = 1; } },
    tick() { if (R.split) return; const bs = base(), k = Math.floor((1 - clamp01(rt / this.split)) * bs.h), row = bs.pixels.filter(p => Math.abs(p.y - k) <= 1); for (let i = 0; i < 2 && row.length; i++) { const p = row[(Math.random() * row.length) | 0]; debris([{ x: p.x, y: p.y, col: ['#ffd27a', '#ff8a3c', '#ff5a2a'][(Math.random() * 3) | 0] }], bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 25, spread: 6, grav: -60, life: [.2, .4], radial: 0 }); } },
    onSplit() { const bs = base(); debris(bs.pixels, bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 5, spread: 12, grav: 120, life: [1.2, 1.8], radial: .6 }); for (const p of parts.slice(-bs.pixels.length)) p.col = ['#3a3540', '#5d5862', '#2a262e'][(Math.random() * 3) | 0]; for (let i = 0; i < 6; i++) smoke.push({ X: G.b.X + rnd(-3, 3), Y: pxToY(6), Z: G.b.Z, vx: rnd(-3, 3), vy: rnd(10, 20), vz: 0, r: rnd(1.5, 2.5), age: 0, life: rnd(.6, 1) }); } };

  const ERUPT = { name: '地刺掀飞', desc: '裂缝到达脚下的瞬间，一圈石刺从地里猛地顶出来，把目标整个掀上半空；它在空中翻滚着落下，砸在地上摔碎，石刺再慢慢缩回地里。',
    split: .05, overlay() {},
    onSplit() { const w = WEIGHT[vicKey]; bodies.push(bodyFrom(masked(base(), () => true), G.b.X, G.b.Z, { vx: G.dx * 15, vz: G.dz * 15, vy: [190, 165, 140][w], vr: 9 * G.face, grav: 300, shatterGround: true, poof: true })); },
    after() { if (!impacted || rt > 1.1) return; const k = rt < .12 ? rt / .12 : rt < .7 ? 1 : 1 - (rt - .7) / .4; for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2, r = V.cell * (i % 2 ? .22 : .32), base0 = project(G.b.X + Math.cos(a) * r, 0, G.b.Z + Math.sin(a) * r), h = Math.round((i % 2 ? 7 : 10) * k); for (let y = 0; y < h; y++) { const wdt = Math.max(1, Math.round((h - y) / 3)); ctx.fillStyle = y === h - 1 ? '#bdbbc1' : '#6b6970'; ctx.fillRect(Math.round(base0.x) - (wdt >> 1), Math.round(base0.y) - y, wdt, 1); } } } };

  const TOSS = { name: '被角挑飞', desc: '被双角从下往上一挑，整个棋子被抛上高空，翻着跟头越过羚羊头顶向后飞出去，重重摔在地上碎开。越重的棋子飞得越低、越近。',
    split: .03, overlay() {},
    onSplit() { const w = WEIGHT[vicKey]; bodies.push(bodyFrom(masked(base(), () => true), G.b.X, G.b.Z, { vx: -G.dx * [70, 55, 40][w], vz: -G.dz * [70, 55, 40][w], vy: [200, 175, 150][w], vr: -14 * G.face, grav: 320, shatterGround: true, poof: true })); } };
