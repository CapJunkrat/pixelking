  // ================= proposed new pieces =================
  let curPose = null;
  const KINGS = new Set(['king', 'war_king', 'shadow_king', 'shield_king']);
  const NEW_SPR = {
    courier: ["...ooo....","..obbho...","..obbbo...","...ooo....","..obbbooo.",".obbbbbbho",".obobbo...","...obbo...","..obobbo..",".obo..obo.",".osssssso.","oooooooooo"],
    tide_knight: ["......o.o.o",".....ohohoh","....oooooo.","..oobbhbo..",".obbbbbhbo.","obbobbbbbo.","obbbbbbbbo.",".oobsbbbbo.","...obbbbbo.","..obbbbbo..","..obbbbbbo.",".ossssssso.","ooooooooooo"],
    echo: ["...oooo...","..obbbbo..",".obhoohbo.",".obbbbbbo.",".obohhobo.","..obbbbo..",".oobbbboo.","obbbbbbbbo","o.obbbbo.o","..obbbbo..",".obbbbbbo.",".osssssso.","oooooooooo"],
    chameleon: ["..oooo.....",".obbhbo....","obohbbbo...","obbbbbbbo..",".oobbbbbbo.","...obbbbbbo","..obbbbbbo.",".obbbbbo.o.","..obbbbooho","...ooooo.o.",".osssssso..","oooooooooo."],
    sentry: ["........o.","...oooo.oho","..obbbbooo.","..ohoohbo..","..obbbbo...",".oobbbbooo.","obbbbbbbbo.","obobbbbobo.","..obbbbo.o.","..obbbbo...",".obbbbbbo..",".osssssso..","oooooooooo."],
    falconer: [".......ooo..","......obbho.","...oo..obo..","..obbo.oo...","..obbo.oo...","...oo.ob....","..obbbbo....",".obbbbo.....",".obobbo.....","...obbo.....","..obbbbo....",".osssssso...","oooooooooo.."],
    vanguard: ["......o...","...ooooh..","..obbbo.o.","..ohohbo...","..obbbbo...",".oobbboo...","obbbbbbo...","o.obbbo....","..obbbo....",".osssso....","oooooooo..."],
    squire: ["...ooo.....","..obhbo....","..oooooo...","..obbbo..o.",".oobbbooohh",".obbbbbo.o.","..obbbo....","..obobo....",".osssso....","oooooooo..."],
    stand_in: ["...oooo...","..obbbbo..","..ohbbho..","..obhhbo..","...oooo...","..obbbbo..",".obbbbbbo.","obbbbbbbbo",".obbbbbbo.","..obbbbo..",".osssssso.","oooooooooo"],
    powder_keg: [".....o....","....oho...","....o.....","..oooooo..",".obbbbbbo.",".osssssso.",".obbbbbbo.",".obbbbbbo.",".osssssso.",".obbbbbbo.","..oooooo..","..o....o..",".osssssso.","oooooooooo"],
    ember_bird: ["....o.o.....","...ohoho....","....obbo....","...obhbbo...","oo.obbbbo.oo","obo.obbbo.obo",".obooobbboobo","..obbbbbbbo..","...obbbbbo...","....obbbo....","...ooo.ooo...",".osssssssso..","oooooooooooo."],
    gargoyle: ["o..oooo..o","oo.obhbo.oo","obooboboobo","obbobbbobbo",".obbbbbbbo.","..obbbbbo..","..obbbbbo..",".obbobbobbo","..oo.oo.oo.",".osssssssso","oooooooooooo"],
    crystal_mage: ["....oo....","...ohho...","..ohbbho..","...ohho...","....oo....","..oooooo..","..obbbbo..",".obbhhbbo.",".obbbbbbo.","..obbbbo..",".obbbbbbo.",".osssssso.","oooooooooo"],
    ranger: ["...oooo...","..obbbbo..",".obboooo..",".obbobho..","..obbbbo..",".obbbbbbo.","obbbbbbbbo","o.obbbbo..",".obbobbo..","obbo.obbo.",".osssssso.","oooooooooo"],
    monk: ["...oooo...","..obhbbo..","..obbbbo..","...obbo...","..oooooo..",".obbhbbbo.","obbbhbbbbo",".obbbbbbo.","..obbbbo..",".obbbbbbo.",".osssssso.","oooooooooo"],
    antelope: ["o.......o.","oo.....oo.",".oo...oo..","..oo.oo...","...ooooo..","..obbhbbo.",".obobbbbo.",".obbbbbbo.","..obbsbbo.","...obbbbo.","..obbbbbo.",".osssssso.","oooooooooo"],
    war_king: ["....o......o","...oho....oho","..ooooo....o.","..obbbo....o.","..oooooo...o.",".obbbbbbo.ooo",".obbbbbbo..o.","..obbbbo..o..","..obbbbo.....",".obbbbbbo....",".osssssso....","oooooooooo..."],
    shadow_king: [".....oo.....","....obho....","...oobbooo..","....obho....","..oooooooo..",".obbbbbbbbo.","oobbbbbbbboo","o.obbbbbbo.o","..obbbbbbo..",".obbbbbbbbo.",".osssssssso.","oooooooooooo"],
    shield_king: [".....oo.....","....obho....","...oobbooo..","....obho....","..oooooooo..",".obbbbbooooo",".obbbbobhhbo","..obbbobhhbo","..obbbobhhbo",".obbbbboooo.",".osssssso...","oooooooooo.."],
    lantern_bearer: ["........ooo","...oo...oho","..obbo..ooo","..obbo...o.","...oo...o..","..obbbooo..",".obbbbo....","..obbbo....","..obbbo....",".obbbbbo...",".osssssso..","oooooooooo."],
    martyr: ["..ooooo...",".o.....o..","..oooo....",".obhhbo...",".obbbbo...","..oooo....",".obbbbbo..","obbhhbbbo.","obbhhbbbo.",".obbbbbo..",".osssssso.","oooooooooo"]
  };
  for (const n in NEW_SPR) {
    for (const side of ['w', 'k']) { S[n + side] = buildSprite(NEW_SPR[n], PAL[side]); S[n + side + '!'] = buildSprite(NEW_SPR[n], PAL[side], '#ffffff'); }
  }
  for (const n in Object.assign({}, SPR, NEW_SPR)) {
    const rows = NEW_SPR[n] || SPR[n];
    S[n + 'k&'] = buildSprite(rows, PAL.k, '#ff9a3c');
    S[n + 'k*'] = buildSprite(rows, PAL.k, '#fff6d8');
    if (!S[n + 'k#']) S[n + 'k#'] = buildSprite(rows, PAL.stone);
  }
  Object.assign(WEIGHT, { courier: 0, tide_knight: 1, echo: 1, chameleon: 1, sentry: 2, falconer: 0, vanguard: 0, squire: 0, stand_in: 0, powder_keg: 0, ember_bird: 1, gargoyle: 2, crystal_mage: 1, ranger: 0, monk: 1, antelope: 1, war_king: 2, shadow_king: 2, shield_king: 2, lantern_bearer: 0, martyr: 0 });
  Object.assign(VNAME, { courier: '疾风信使', tide_knight: '潮汐骑士', echo: '回声', chameleon: '变色龙', sentry: '哨兵', falconer: '鹰隼猎手', vanguard: '先锋', squire: '侍从', stand_in: '替身', powder_keg: '火药桶兵', ember_bird: '余烬鸟', gargoyle: '石像守卫', crystal_mage: '水晶法师', ranger: '游侠', monk: '日月僧侣', antelope: '羚羊', war_king: '战王', shadow_king: '隐王', shield_king: '护盾王', lantern_bearer: '提灯人', martyr: '殉道者' });
  Object.assign(STARTS, { courier: { x: 3, y: 5 }, tide_knight: { x: 3, y: 5 }, echo: { x: 2, y: 5 }, chameleon: { x: 3, y: 5 }, sentry: { x: 3, y: 4 }, falconer: { x: 3, y: 6 }, vanguard: { x: 2, y: 4 }, squire: { x: 2, y: 4 }, stand_in: { x: 3, y: 6 }, powder_keg: { x: 3, y: 4 }, ember_bird: { x: 5, y: 5 }, gargoyle: { x: 3, y: 5 }, crystal_mage: { x: 6, y: 3 }, ranger: { x: 0, y: 3 }, monk: { x: 4, y: 4 }, antelope: { x: 4, y: 6 }, war_king: { x: 4, y: 4 }, shadow_king: { x: 4, y: 4 }, shield_king: { x: 3, y: 4 }, lantern_bearer: { x: 3, y: 5 }, martyr: { x: 2, y: 4 } });
  Object.assign(HITNAME, { swallow: '吞噬', radiance: '圣光' });

  const ORANGE = '255,150,60', WATER = '120,190,255', GOLDC = '255,226,150', MOON = '160,200,255';
  // --- pose builders ---
  function dashPose(sp, { back = .25, windup = .3, dash = .22, contact = .55, squash = .1, settle = .3, hop = 1.5, white = 0, bob = 0 } = {}) {
    return function (u) {
      const { a, dx, dz } = G, c = V.cell, bk = { X: a.X - dx * c * back, Z: a.Z - dz * c * back }, C = toward(G.b, contact), o = O(sp);
      if (u < 0) return o;
      const t1 = windup, t2 = windup + dash, t3 = t2 + squash;
      if (u < t1) { const q = easeOut(u / t1); o.X = lerp(a.X, bk.X, q); o.Z = lerp(a.Z, bk.Z, q); o.sx = 1 + .08 * q; o.sy = 1 - .1 * q; o.white = white * q * (.7 + .3 * Math.sin(u * 50)); return o; }
      if (u < t2) { const q = (u - t1) / dash, e = easeIn(q); o.X = lerp(bk.X, C.X, e); o.Z = lerp(bk.Z, C.Z, e); o.sx = .92; o.sy = 1.08; o.trail = true; o.Y = bob * Math.abs(Math.sin(q * Math.PI * 3)); return o; }
      if (u < t3) { const q = (u - t2) / squash; o.X = C.X; o.Z = C.Z; o.sx = 1 + .2 * Math.sin(q * Math.PI); o.sy = 1 - .18 * Math.sin(q * Math.PI); return o; }
      return settleInto(o, C, u, t3, settle, hop);
    };
  }
  function leapPose(sp, { crouch = .22, air = .42, peak = 2.4, rot = .3 } = {}) {
    return function (u) {
      const { a, b, face } = G, c = V.cell, o = O(sp);
      if (u < 0) return o;
      if (u < crouch) { const s = Math.sin(u / crouch * Math.PI / 2); o.sy = 1 - .2 * s; o.sx = 1 + .12 * s; return o; }
      if (u < crouch + air) { const q = (u - crouch) / air; o.X = lerp(a.X, b.X, q); o.Z = lerp(a.Z, b.Z, q); o.Y = lerp(0, vicTopY(), q) + c * peak * 4 * q * (1 - q); o.rot = lerp(-rot, rot, q) * face; o.trail = q > .45; return o; }
      const q = clamp01((u - crouch - air) / .2), sq = Math.sin(clamp01((u - crouch - air) / .16) * Math.PI) * (1 - q * .3);
      o.X = b.X; o.Z = b.Z; o.Y = vicTopY(); o.rot = lerp(rot, 0, easeOut(q)) * face; o.sx = 1 + .25 * sq; o.sy = 1 - .22 * sq; return o;
    };
  }
  function rangedPose(sp, { windup = .4, recoil = .14, walkAt = 1.3, walk = .45, lean = .14 } = {}) {
    return function (u) {
      const { a, face } = G, o = O(sp);
      if (u < 0) return o;
      if (u < windup) { const s = Math.sin(clamp01(u / (windup * .9)) * Math.PI / 2); o.rot = -lean * s * face; o.sy = 1 + .05 * s; return o; }
      if (u < windup + recoil) { const q = (u - windup) / recoil; o.X -= G.dx * 2.5 * Math.sin(q * Math.PI); o.Z -= G.dz * 2.5 * Math.sin(q * Math.PI); o.rot = lerp(lean * .8, 0, q) * face; return o; }
      if (u < walkAt) return o;
      const q = clamp01((u - walkAt) / walk); o.X = lerp(a.X, G.b.X, smooth(q)); o.Z = lerp(a.Z, G.b.Z, smooth(q)); o.Y = Math.abs(Math.sin(q * Math.PI * 3)) * 2; return o;
    };
  }
  const handAt = (o, h = 9) => ({ X: o.X, Y: o.Y + pxToY(h), Z: o.Z });
  const vicCentre = (f = .5) => ({ X: G.b.X, Y: pxToY(S[vicKey + 'k'].h * f), Z: G.b.Z });
  const lerp3 = (p, q, k) => ({ X: lerp(p.X, q.X, k), Y: lerp(p.Y, q.Y, k), Z: lerp(p.Z, q.Z, k) });
  const px = (p, col, s = 1) => { const q = project(p.X, p.Y, p.Z); ctx.fillStyle = col; ctx.fillRect(Math.round(q.x) - (s >> 1), Math.round(q.y) - (s >> 1), s, s); };
  function bird(p, flap, col) { const q = project(p.X, p.Y, p.Z), x = Math.round(q.x), y = Math.round(q.y), w = flap > 0 ? -1 : 1; ctx.fillStyle = '#2a1e2e'; ctx.fillRect(x - 1, y - 1, 3, 3); ctx.fillStyle = col; ctx.fillRect(x, y, 1, 1); ctx.fillStyle = '#2a1e2e'; ctx.fillRect(x - 3, y + w, 2, 1); ctx.fillRect(x + 2, y + w, 2, 1); ctx.fillStyle = '#e0b45c'; ctx.fillRect(x + 2 * G.face, y, 1, 1); }
  function fallingStars(at, n, col) { for (let i = 0; i < n; i++) { const a = Math.random() * Math.PI * 2; parts.push({ X: at.X + Math.cos(a) * 4, Y: at.Y, Z: at.Z + Math.sin(a) * 2, vx: Math.cos(a) * 12, vy: rnd(20, 40), vz: 0, col, life: rnd(.5, .9), age: 0, sz: 1, bounced: 2, g: -10 }); } }

  // --- attacks ---
  Object.assign(ATK, {
    courier: {
      name: "COURIER DOUBLE STEP", hit: 'blunt', impact: .5, end: 1.9, hitstop: .07, shake: .5,
      title: "疾风信使 · 两步飞踢", desc: "信使一回合能走两步。第一步原地蹬地、轻快地跳到中间一格，脚一沾地立刻第二跳，借着冲劲一脚踢中目标，再弹回来落进格子。整套动作很快。",
      events: [{ at: .06, fn: () => puff(G.a.X, 1, G.a.Z, 4, .5) }, { at: .28, fn: () => { const m = lerp3({ X: G.a.X, Y: 0, Z: G.a.Z }, { X: G.b.X, Y: 0, Z: G.b.Z }, .5); puff(m.X, 1, m.Z, 4, .5); } }],
      pose(u) {
        const { a, b, face } = G, c = V.cell, m = { X: (a.X + b.X) / 2, Z: (a.Z + b.Z) / 2 }, C = toward(b, .4), o = O('courierw');
        if (u < 0) return o;
        if (u < .06) { o.sy = .85; o.sx = 1.1; return o; }
        if (u < .28) { const q = (u - .06) / .22; o.X = lerp(a.X, m.X, q); o.Z = lerp(a.Z, m.Z, q); o.Y = c * .5 * 4 * q * (1 - q); o.rot = .15 * face; return o; }
        if (u < .5) { const q = (u - .28) / .22; o.X = lerp(m.X, C.X, q); o.Z = lerp(m.Z, C.Z, q); o.Y = c * .4 * 4 * q * (1 - q) + c * .2 * q; o.rot = .5 * smooth(q) * face; o.trail = true; return o; }
        if (u < .7) { const q = (u - .5) / .2; o.X = lerp(C.X, C.X - G.dx * 3, q); o.Z = lerp(C.Z, C.Z - G.dz * 3, q); o.Y = c * .2 * (1 - q); o.rot = lerp(.5, 0, q) * face; return o; }
        return settleInto(o, { X: C.X - G.dx * 3, Z: C.Z - G.dz * 3 }, u, .85, .22, 3);
      },
      hitFx() { sparkBurst(G.b.X, 10, G.b.Z, 7, G.dx, G.dz, 40, .6); ring(G.b.X, G.b.Z, V.cell * .5, .25); }
    },
    tide_knight: {
      name: "TIDE KNIGHT WAVE RIDE", hit: 'slash', impact: .55, end: 2.1, hitstop: .11, shake: .8,
      title: "潮汐骑士 · 浪尖斩", desc: "脚下涌起一道浪，骑士踏着浪头冲过去，浪花一路飞溅；到目标面前时浪头拍下，骑士顺势一刀斜劈。刀光带着水花，落地后浪退去，骑士站进格子。",
      events: [],
      pose(u) {
        const { a, face } = G, c = V.cell, C = toward(G.b, .5), o = O('tide_knightw');
        if (u < 0) return o;
        if (u < .2) { const s = Math.sin(u / .2 * Math.PI / 2); o.Y = c * .25 * s; o.rot = -.2 * s * face; return o; }
        if (u < .55) { const q = (u - .2) / .35; o.X = lerp(a.X, C.X, easeIn(q)); o.Z = lerp(a.Z, C.Z, easeIn(q)); o.Y = c * .25 + c * .35 * Math.sin(q * Math.PI); o.rot = lerp(-.2, .35, q) * face; o.trail = true; return o; }
        if (u < .8) { const q = (u - .55) / .25; o.X = C.X; o.Z = C.Z; o.Y = c * .25 * (1 - easeIn(q)); o.rot = .35 * face * (1 - q); return o; }
        return settleInto(o, C, u, .8, .3, 1);
      },
      fx(o, u) { if (u > .02 && u < .8) { const n = u < .55 ? 3 : 1; for (let i = 0; i < n; i++) parts.push({ X: o.X + rnd(-5, 5), Y: Math.max(0, o.Y - 2), Z: o.Z + rnd(-2, 2), vx: rnd(-15, 15) - G.dx * 20, vy: rnd(10, 40), vz: rnd(-5, 5), col: Math.random() < .5 ? '#9fd4ff' : '#e6f6ff', life: rnd(.3, .5), age: 0, sz: 1, bounced: 2, g: 200 }); } },
      hitFx() { slash = { age: 0, life: .5 }; sparkBurst(G.b.X, 9, G.b.Z, 14, G.dx, G.dz, 60, .8, WATER); ring(G.b.X, G.b.Z, V.cell * .9, .4, WATER); }
    },
    echo: null, // filled below from the knight stomp
    chameleon: {
      name: "CHAMELEON TONGUE", hit: 'swallow', impact: .5, end: 2.2, hitstop: .08, shake: .4,
      title: "变色龙 · 长舌吞噬", desc: "变色龙伏低身子，眼睛一转锁定目标；舌头“啪”地弹出去黏住目标，把它一路卷回来、整个吞下。吞完它身上一阵变色闪烁（学到了对方的走法），然后慢悠悠爬进格子。",
      events: [{ at: 1.0, fn: () => { ring(G.a.X, G.a.Z, V.cell * .55, .35, '150,230,150'); sparkBurst(G.a.X, 8, G.a.Z, 8, 0, 0, 0, .4, '150,230,150'); } }],
      pose(u) {
        const { face } = G, o = O('chameleonw');
        if (u < 0) return o;
        if (u < .3) { const s = smooth(u / .3); o.sy = 1 - .12 * s; o.sx = 1 + .08 * s; o.white = .3 * (u > .2 ? 1 : 0); return o; }
        if (u < .95) { o.sy = .88; o.sx = 1.08; o.rot = .05 * face; return o; }
        if (u < 1.15) { const q = (u - .95) / .2, w = Math.sin(q * Math.PI); o.sx = 1 + .2 * w; o.sy = 1 - .1 * w; return o; }
        if (u < 1.3) { o.white = .4 * Math.abs(Math.sin(u * 40)); return o; }
        const q = clamp01((u - 1.3) / .6); o.X = lerp(G.a.X, G.b.X, smooth(q)); o.Z = lerp(G.a.Z, G.b.Z, smooth(q)); o.Y = Math.abs(Math.sin(q * Math.PI * 4)) * 1; return o;
      },
      fx(o, u) {
        if (u < .3 || u > 1.0) return;
        const mouth = { X: o.X + G.dx * 5, Y: o.Y + pxToY(7), Z: o.Z + G.dz * 5 };
        let tip;
        if (!impacted) tip = lerp3(mouth, vicCentre(.55), easeOut(clamp01((u - .3) / .2)));
        else tip = SWALLOW.at();
        const p0 = project(mouth.X, mouth.Y, mouth.Z), p1 = project(tip.X, tip.Y, tip.Z);
        ctx.strokeStyle = '#d4607a'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
        ctx.fillStyle = '#f08aa0'; ctx.fillRect(Math.round(p1.x) - 1, Math.round(p1.y) - 1, 3, 3);
      },
      hitFx() { sparkBurst(G.b.X, 9, G.b.Z, 4, 0, 0, 0, .3, '240,138,160'); },
      react: () => SWALLOW
    },
    sentry: {
      name: "SENTRY HALBERD THRUST", hit: 'pierce', impact: .44, end: 2.0, hitstop: .1, shake: .8,
      title: "哨兵 · 戟刺", desc: "哨兵不会主动走到空格上，只守着身边一圈。敌人一进范围，它沉肩、收戟，然后一记直刺把目标捅穿，顺势踏进目标格。动作短促、很稳。",
      events: [],
      pose: dashPose('sentryw', { back: .12, windup: .3, dash: .14, contact: .5, settle: .3, hop: 0 }),
      fx(o, u) { if (u < 0 || (impacted && rt > .25)) return; const h = handAt(o, 8), tip = { X: h.X + G.dx * 13, Y: h.Y, Z: h.Z + G.dz * 13 }, p = project(h.X, h.Y, h.Z), q = project(tip.X, tip.Y, tip.Z); pixLine(p.x, p.y, q.x, q.y, '#cfc2a0'); ctx.fillStyle = '#ffffff'; ctx.fillRect(Math.round(q.x), Math.round(q.y), 1, 1); },
      hitFx() { sparkBurst(G.b.X, 8, G.b.Z, 10, G.dx, G.dz, 90, .7); ring(G.b.X, G.b.Z, V.cell * .7, .3); }
    },
    falconer: {
      name: "FALCONER HUNT", hit: 'pierce', impact: .62, end: 2.0, hitstop: .08, shake: .45,
      title: "鹰隼猎手 · 放鹰", desc: "猎手站在原地不动，抬起手臂放出鹰。鹰绕个弧线飞过去，收翅俯冲，用爪子击中目标；随后鹰飞回猎手的手臂上。猎手全程不离开自己的格子。",
      events: [],
      pose: (u) => { const o = O('falconerw'); if (u < 0) return o; if (u < .3) { o.rot = -.12 * smooth(u / .3) * G.face; o.sy = 1 + .05 * smooth(u / .3); return o; } if (u < .45) { o.rot = lerp(-.12, 0, (u - .3) / .15) * G.face; return o; } if (u > 1.05 && u < 1.2) { o.sy = 1 - .06 * Math.sin((u - 1.05) / .15 * Math.PI); } return o; },
      birdAt(u) {
        const arm = { X: G.a.X + G.face * 4, Y: pxToY(11), Z: G.a.Z }, vc = vicCentre(.6), top = { X: (arm.X + vc.X) / 2, Y: V.cell * 2.2, Z: (arm.Z + vc.Z) / 2 };
        if (u < .3) return arm;
        if (u < .62) { const q = (u - .3) / .32, a1 = lerp3(arm, top, q), a2 = lerp3(top, vc, q); return lerp3(a1, a2, easeIn(q)); }
        if (u < .75) return { X: vc.X, Y: vc.Y + (u - .62) * 30, Z: vc.Z };
        if (u < 1.1) { const q = (u - .75) / .35, from = { X: vc.X, Y: vc.Y + 4, Z: vc.Z }; return { ...lerp3(from, arm, smooth(q)), Y: lerp(from.Y, arm.Y, q) + V.cell * 1.2 * 4 * q * (1 - q) }; }
        return arm;
      },
      fx(o, u) { if (u < 0) return; bird(this.birdAt(u), Math.sin(u * 40), '#c8a070'); },
      hitFx() { sparkBurst(G.b.X, 10, G.b.Z, 7, G.dx, G.dz, 40, .5); ring(G.b.X, G.b.Z, V.cell * .45, .25); }
    },
    vanguard: {
      name: "VANGUARD SPEAR JAB", hit: 'pierce', impact: .4, end: 1.9, hitstop: .08, shake: .55,
      title: "先锋 · 突刺", desc: "先锋只能往前打。它压低身子、长枪前指，向斜前方一个短冲刺，枪尖刺穿目标，然后收枪站进格子。",
      events: [],
      pose: dashPose('vanguardw', { back: .15, windup: .24, dash: .16, contact: .5, settle: .28, hop: 1 }),
      fx(o, u) { if (u < 0 || (impacted && rt > .2)) return; const h = handAt(o, 7), tip = { X: h.X + G.dx * 11, Y: h.Y - 1, Z: h.Z + G.dz * 11 }, p = project(h.X, h.Y, h.Z), q = project(tip.X, tip.Y, tip.Z); pixLine(p.x, p.y, q.x, q.y, '#cfc2a0'); },
      hitFx() { sparkBurst(G.b.X, 8, G.b.Z, 8, G.dx, G.dz, 80, .6); }
    },
    squire: {
      name: "SQUIRE LEVEL UP", hit: 'slash', impact: .42, end: 2.3, hitstop: .1, shake: .5,
      title: "侍从 · 斩击并升级", desc: "侍从小跑上前，举起小剑用力一砍。吃掉目标后，它脚下亮起一圈金光，头顶冒出向上的箭头和星星，表示升了一级（走法变强）。",
      events: [{ at: 1.0, fn: () => { ring(G.b.X, G.b.Z, V.cell * .7, .45, GOLDC); ring(G.b.X, G.b.Z, V.cell * .4, .3, GOLDC); fallingStars({ X: G.b.X, Y: pxToY(12), Z: G.b.Z }, 10, '#ffe08a'); } }],
      pose: dashPose('squirew', { back: .1, windup: .22, dash: .2, contact: .5, settle: .3, hop: 2.5 }),
      fx(o, u) { if (u < 1.0 || u > 1.8) return; const k = (u - 1.0) / .8, p = project(o.X, o.Y + pxToY(16) + k * 8, o.Z), x = Math.round(p.x), y = Math.round(p.y); ctx.fillStyle = `rgba(255,226,120,${1 - k})`; ctx.fillRect(x, y, 1, 5); ctx.fillRect(x - 1, y + 1, 3, 1); ctx.fillRect(x - 2, y + 2, 5, 1); },
      hitFx() { slash = { age: 0, life: .4 }; sparkBurst(G.b.X, 9, G.b.Z, 7, G.dx, G.dz, 50, .6); }
    },
    stand_in: {
      name: "STAND-IN KNIFE THROW", hit: 'pierce', impact: .58, end: 2.0, hitstop: .08, shake: .45,
      title: "替身 · 双飞刀", desc: "替身的本领是关键时刻和王换位置，打人时比较朴素：一甩披风，两把飞刀一前一后飞出去，扎进目标，然后它快步走进格子。",
      events: [],
      pose: rangedPose('stand_inw', { windup: .38, recoil: .14, walkAt: 1.15, walk: .4, lean: .18 }),
      fx(o, u) {
        if (u < .38 || impacted) return;
        for (const lag of [0, .07]) { const q = clamp01((u - .38 - lag) / .2); if (q <= 0) continue; const h = { X: G.a.X, Y: pxToY(9), Z: G.a.Z }, vc = vicCentre(.5 + lag), p = lerp3(h, vc, q), pr = lerp3(h, vc, Math.max(0, q - .08)); const a = project(p.X, p.Y, p.Z), b2 = project(pr.X, pr.Y, pr.Z); pixLine(b2.x, b2.y, a.x, a.y, '#dfe6f0'); ctx.fillStyle = '#ffffff'; ctx.fillRect(Math.round(a.x), Math.round(a.y), 1, 1); }
      },
      hitFx() { sparkBurst(G.b.X, 9, G.b.Z, 8, G.dx, G.dz, 70, .6); }
    },
    powder_keg: {
      name: "POWDER KEG BUMP", hit: 'blunt', impact: .5, end: 2.0, hitstop: .08, shake: .7,
      title: "火药桶兵 · 撞击", desc: "一只长着小短腿的火药桶，引信滋滋冒火星。它摇摇晃晃地冲过去，用桶身一撞把目标撞倒。（它被吃掉时才会爆炸，可以在受击方选它来看。）",
      events: [],
      pose: dashPose('powder_kegw', { back: .18, windup: .28, dash: .22, contact: .55, settle: .3, hop: 1, bob: 2 }),
      fx(o, u) { if (u < 0) return; const f = handAt(o, 13); if (Math.random() < .6) parts.push({ X: f.X + rnd(-1, 1), Y: f.Y, Z: f.Z, vx: rnd(-15, 15), vy: rnd(15, 40), vz: 0, col: Math.random() < .5 ? '#ffd27a' : '#ff8a3c', life: rnd(.15, .3), age: 0, sz: 1, bounced: 2, g: 80 }); },
      hitFx() { sparkBurst(G.b.X, 8, G.b.Z, 8, G.dx, G.dz, 40, .6); ring(G.b.X, G.b.Z, V.cell * .6, .3); puff(G.b.X, 2, G.b.Z, 6, .9); }
    },
    ember_bird: {
      name: "EMBER BIRD FIRE DIVE", hit: 'crush', impact: .62, end: 2.4, hitstop: .11, shake: 1.0,
      title: "余烬鸟 · 烈焰俯冲", desc: "余烬鸟展翅升空，身后拖着一串火星；在目标上方翻身，裹着火焰笔直俯冲砸下去，落点炸开一圈火花。",
      events: [{ at: .14, fn: () => puff(G.a.X, 1, G.a.Z, 6, .8) }],
      pose(u) {
        const { a, b, face } = G, c = V.cell, high = c * 2.2, o = O('ember_birdw');
        if (u < 0) return o;
        if (u < .14) { o.sy = .85; o.sx = 1.1; return o; }
        if (u < .45) { const q = (u - .14) / .31; o.X = lerp(a.X, b.X, smooth(q)); o.Z = lerp(a.Z, b.Z, smooth(q)); o.Y = high * easeOut(q); o.sy = 1 + .1 * Math.sin(u * 45); o.trail = true; return o; }
        o.X = b.X; o.Z = b.Z;
        if (u < .5) { o.Y = high; o.rot = .3 * face; return o; }
        if (u < .62) { const q = (u - .5) / .12; o.Y = lerp(high, vicTopY(), easeIn(q)); o.rot = .5 * face; o.sx = .85; o.sy = 1.2; o.trail = true; o.white = .3; return o; }
        const q = clamp01((u - .62) / .25); o.Y = vicTopY(); o.rot = lerp(.5, 0, easeOut(q)) * face; return o;
      },
      fx(o, u) { if (u < .14 || u > .7) return; for (let i = 0; i < 2; i++) parts.push({ X: o.X + rnd(-3, 3), Y: o.Y + pxToY(rnd(2, 10)), Z: o.Z, vx: rnd(-10, 10), vy: rnd(-5, 15), vz: 0, col: ['#ffd27a', '#ff8a3c', '#ff5a2a'][(Math.random() * 3) | 0], life: rnd(.25, .45), age: 0, sz: 1, bounced: 2, g: -20 }); },
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.2, .45, ORANGE); puff(b.X, 2, b.Z, 10, 1.2); sparkBurst(b.X, 4, b.Z, 16, 0, 0, 0, .9, ORANGE); crackDecal(b.X, b.Z, 6, V.cell * .9); }
    },
    gargoyle: {
      name: "GARGOYLE DROP", hit: 'crush', impact: .7, end: 2.6, hitstop: .13, shake: 1.5,
      title: "石像守卫 · 坠石", desc: "沉重的石像蹲伏蓄力，展开石翅笨重地跃起，在空中划一道高弧，整个砸在目标头顶，棋盘被砸出裂纹、尘土四起。",
      events: [{ at: .26, fn: () => { puff(G.a.X, 1, G.a.Z, 8, 1); shake = Math.max(shake, .3); } }],
      pose: leapPose('gargoylew', { crouch: .28, air: .42, peak: 1.8, rot: .15 }),
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.4, .5); ring(b.X, b.Z, V.cell * .8, .32); puff(b.X, 2, b.Z, 14, 1.4); crackDecal(b.X, b.Z, 9, V.cell * 1.1); sparkBurst(b.X, 4, b.Z, 8, 0, 0, 0, .7); }
    },
    crystal_mage: {
      name: "CRYSTAL MAGE SHARDS", hit: 'pierce', impact: .66, end: 2.2, hitstop: .1, shake: .6,
      title: "水晶法师 · 晶刺齐射", desc: "法师头顶的水晶亮起，三枚晶刺在身边绕圈成形，然后一枚接一枚射向目标，最后一枚贯穿。（它自己很脆，被吃时会碎成彩色玻璃，可以在受击方选它来看。）",
      events: [],
      pose: rangedPose('crystal_magew', { windup: .5, recoil: .16, walkAt: 1.3, walk: .45, lean: .08 }),
      shard(i, u) { const ang = u * 9 + i * 2.1, home = { X: G.a.X + Math.cos(ang) * 7, Y: pxToY(13) + Math.sin(ang * .7) * 2, Z: G.a.Z + Math.sin(ang) * 3 }, start = .5 + i * .055; if (u < start) return home; const q = clamp01((u - start) / .11); return lerp3(home, vicCentre(.5), easeIn(q)); },
      fx(o, u) { if (u < .1 || impacted) return; const k = clamp01((u - .1) / .2); for (let i = 0; i < 3; i++) { const p = this.shard(i, u), q = project(p.X, p.Y, p.Z), x = Math.round(q.x), y = Math.round(q.y); ctx.globalAlpha = k; ctx.fillStyle = '#bff3ff'; ctx.fillRect(x, y - 1, 1, 3); ctx.fillRect(x - 1, y, 3, 1); ctx.fillStyle = '#ffffff'; ctx.fillRect(x, y, 1, 1); ctx.globalAlpha = 1; } },
      hitFx() { sparkBurst(G.b.X, 9, G.b.Z, 12, G.dx, G.dz, 80, .7, '191,243,255'); ring(G.b.X, G.b.Z, V.cell * .6, .3, '191,243,255'); }
    },
    ranger: {
      name: "RANGER EDGE DASH", hit: 'slash', hitstop: .11, shake: .7, end: 2.2,
      get impact() { const past = this.past(), d1 = Math.hypot(G.b.X - G.a.X, G.b.Z - G.a.Z), d2 = Math.hypot(past.X - G.a.X, past.Z - G.a.Z); return .25 + .2 * (d1 / d2); },
      past() { return { X: G.b.X + G.dx * V.cell * .7, Z: G.b.Z + G.dz * V.cell * .7 }; },
      title: "游侠 · 疾掠", desc: "游侠擅长贴着棋盘边缘飞奔。它从边上压低身子起跑，像一阵风掠过目标，擦身而过时一刀划开，冲出去半格后急停、回身站进格子。",
      events: [{ at: .22, fn: () => puff(G.a.X, 1, G.a.Z, 6, .7) }],
      pose(u) {
        const { a, face } = G, past = this.past(), o = O('rangerw');
        if (u < 0) return o;
        if (u < .25) { const s = smooth(u / .25); o.sy = 1 - .15 * s; o.rot = .2 * s * face; return o; }
        if (u < .45) { const q = (u - .25) / .2; o.X = lerp(a.X, past.X, q); o.Z = lerp(a.Z, past.Z, q); o.sx = 1.15; o.sy = .85; o.rot = .2 * face; o.trail = true; return o; }
        if (u < .75) { o.X = past.X; o.Z = past.Z; o.rot = lerp(.2, -.15, easeOut((u - .45) / .3)) * face; return o; }
        return settleInto(o, past, u, .75, .3, 2);
      },
      hitFx() { slash = { age: 0, life: .45 }; sparkBurst(G.b.X, 9, G.b.Z, 9, G.dx, G.dz, 70, .7); }
    },
    monk: {
      name: "MONK SUN-MOON PALM", hit: 'blunt', impact: .42, end: 2.1, hitstop: .12, shake: .9,
      title: "日月僧侣 · 日月掌", desc: "僧侣平时靠瞬移在同色格之间行动，出手却很近：它闭眼凝气，身上交替亮起金色和银蓝色的光，然后一掌推出，掌风化成一金一蓝两圈冲击波，把目标震飞。",
      events: [],
      pose: dashPose('monkw', { back: .05, windup: .3, dash: .12, contact: .6, settle: .3, hop: 1, white: .5 }),
      hitFx() { ring(G.b.X, G.b.Z, V.cell * 1.0, .45, GOLDC); ring(G.b.X, G.b.Z, V.cell * .65, .35, MOON); sparkBurst(G.b.X, 8, G.b.Z, 8, G.dx, G.dz, 40, .6, GOLDC); sparkBurst(G.b.X, 8, G.b.Z, 8, G.dx, G.dz, 40, .6, MOON); }
    },
    antelope: {
      name: "ANTELOPE BOUND", hit: 'crush', impact: .66, end: 2.5, hitstop: .11, shake: 1.1,
      title: "羚羊 · 长跃顶撞", desc: "羚羊的跳法比马更远（三格加一格）。它后腿一蹬，高高跃过中间的棋子，在空中低头，用双角朝下狠狠砸在目标身上。",
      events: [{ at: .24, fn: () => puff(G.a.X, 1, G.a.Z, 7, .9) }],
      pose: leapPose('antelopew', { crouch: .24, air: .42, peak: 2.6, rot: .35 }),
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.1, .45); puff(b.X, 2, b.Z, 10, 1.1); crackDecal(b.X, b.Z, 6, V.cell * .85); sparkBurst(b.X, 5, b.Z, 7, 0, 0, 0, .6); }
    },
    war_king: {
      name: "WAR KING CLEAVE", hit: 'slash', impact: .63, end: 2.3, hitstop: .14, shake: 1.2,
      title: "战王 · 王者劈斩", desc: "战王亲自上阵。他把大剑高高举过头顶，剑身发出金光，向前踏出一大步，一剑从上往下劈开目标，落地时震起一圈金色尘浪。",
      events: [],
      pose: dashPose('war_kingw', { back: .1, windup: .45, dash: .18, contact: .5, settle: .35, hop: 1, white: .5 }),
      hitFx() { slash = { age: 0, life: .55 }; ring(G.b.X, G.b.Z, V.cell * 1.2, .45, GOLDC); sparkBurst(G.b.X, 9, G.b.Z, 12, G.dx, G.dz, 60, .8, GOLDC); }
    },
    shadow_king: {
      name: "SHADOW KING ECLIPSE", hit: 'slash', impact: .66, end: 2.2, hitstop: .13, shake: .8,
      title: "隐王 · 蚀影", desc: "隐王化成一团黑影原地消散，几道影子从不同方向朝目标汇聚，在目标身后重新凝成王的样子，反手一刺。之后他从容地走进格子。",
      events: [{ at: .16, fn: () => puff(G.a.X, 3, G.a.Z, 10, .9) }, { at: .4, fn: () => { const c = V.cell; puff(G.b.X + G.dx * c * .6, 3, G.b.Z + G.dz * c * .6, 8, .8); } }],
      pose(u) {
        const { b, dx, dz, face } = G, c = V.cell, bk = { X: b.X + dx * c * .6, Z: b.Z + dz * c * .6 }, o = O('shadow_kingw');
        if (u < 0) return o;
        if (u < .16) { const s = u / .16; o.alpha = 1 - .5 * s; o.sy = 1 + .1 * s; o.sx = 1 - .2 * s; return o; }
        if (u < .4) { o.alpha = 0; return o; }
        o.X = bk.X; o.Z = bk.Z;
        if (u < .52) { const q = (u - .4) / .12; o.alpha = q; return o; }
        if (u < .66) { const q = (u - .52) / .14; o.rot = lerp(.25, -.35, easeIn(q)) * -face; o.X -= dx * 2 * q; o.Z -= dz * 2 * q; o.white = .3; return o; }
        if (u < 1.1) { const q = clamp01((u - .66) / .25); o.X -= dx * 2 * (1 - q); o.Z -= dz * 2 * (1 - q); o.rot = .35 * face * (1 - q); return o; }
        return settleInto(o, bk, u, 1.1, .35, 1);
      },
      fx(o, u) { if (u < .16 || u > .42) return; const q = (u - .16) / .26; for (let i = 0; i < 4; i++) { const ang = i / 4 * Math.PI * 2 + .6, r = V.cell * 1.6 * (1 - q), p = { X: G.b.X + Math.cos(ang) * r, Y: pxToY(6), Z: G.b.Z + Math.sin(ang) * r }; drawSprite(S['shadow_kingk'], p.X, 0, p.Z, 1, 1, 0, .35 * (1 - q * .5)); } },
      hitFx() { slash = { age: 0, life: .45 }; sparkBurst(G.b.X, 9, G.b.Z, 8, -G.dx, -G.dz, 50, .6, '180,150,220'); }
    },
    shield_king: {
      name: "SHIELD KING BASH", hit: 'blunt', impact: .56, end: 2.3, hitstop: .11, shake: 1.3,
      title: "护盾王 · 圣盾冲撞", desc: "护盾王身上浮现一层半透明的护罩，他把圆盾横在胸前，稳步加速冲过去，用盾面把目标正面撞飞。护罩在撞击瞬间闪亮一下。",
      events: [],
      pose: dashPose('shield_kingw', { back: .2, windup: .34, dash: .22, contact: .55, settle: .32, hop: 1 }),
      fx(o, u) { if (u > .7) return; const a = u < .1 ? u / .1 : u < .5 ? 1 : 1 - (u - .5) / .2, p = project(o.X, o.Y + pxToY(7), o.Z); ctx.strokeStyle = `rgba(170,215,255,${.5 * a})`; ctx.lineWidth = 1; ctx.beginPath(); ctx.ellipse(Math.round(p.x), Math.round(p.y), 10, 11, 0, 0, Math.PI * 2); ctx.stroke(); ctx.fillStyle = `rgba(170,215,255,${.08 * a})`; ctx.fill(); },
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.3, .5, '170,215,255'); ring(b.X, b.Z, V.cell * .7, .3); puff(b.X, 2, b.Z, 9, 1.2); sparkBurst(b.X, 7, b.Z, 8, G.dx, G.dz, 40, .7, '170,215,255'); }
    },
    lantern_bearer: {
      name: "LANTERN BEARER RADIANCE", hit: 'radiance', impact: .62, end: 2.4, hitstop: .08, shake: .4,
      title: "提灯人 · 照灭", desc: "提灯人把灯笼高高举起，灯火越烧越亮，一束暖光照向目标。被照住的棋子先被染成白色，然后从头到脚化成光点飘散。之后提灯人走进格子。",
      events: [],
      pose: rangedPose('lantern_bearerw', { windup: .5, recoil: .12, walkAt: 1.45, walk: .45, lean: .06 }),
      fx(o, u) {
        if (u < .1 || (impacted && rt > .7)) return;
        const l = { X: G.a.X + G.face * 5, Y: pxToY(12), Z: G.a.Z }, lp = project(l.X, l.Y, l.Z), glow = clamp01((u - .1) / .4);
        ctx.fillStyle = `rgba(255,220,130,${.25 * glow})`; ctx.beginPath(); ctx.arc(lp.x, lp.y, 3 + 4 * glow, 0, Math.PI * 2); ctx.fill();
        if (u > .45) { const vc = vicCentre(.5), q = project(vc.X, vc.Y, vc.Z), a = impacted ? 1 - rt / .7 : clamp01((u - .45) / .17); ctx.fillStyle = `rgba(255,236,170,${.22 * a})`; ctx.beginPath(); ctx.moveTo(lp.x, lp.y); ctx.lineTo(q.x - 7, q.y - 8); ctx.lineTo(q.x + 7, q.y + 8); ctx.closePath(); ctx.fill(); }
      },
      hitFx() { ring(G.b.X, G.b.Z, V.cell * .8, .4, GOLDC); },
      react: () => RADIANCE()
    },
    martyr: {
      name: "MARTYR STAFF BLOW", hit: 'blunt', impact: .44, end: 1.9, hitstop: .07, shake: .4,
      title: "殉道者 · 杖击", desc: "殉道者本身不善战斗，只是举起手杖敲一下，把目标打倒。（它的特点在于被吃掉的时候，可以在受击方选它来看。）",
      events: [],
      pose: dashPose('martyrw', { back: .12, windup: .26, dash: .18, contact: .5, settle: .3, hop: 1.5 }),
      hitFx() { sparkBurst(G.b.X, 10, G.b.Z, 6, G.dx, G.dz, 30, .5); ring(G.b.X, G.b.Z, V.cell * .5, .25); }
    }
  });
  ATK.echo = Object.assign({}, ATK.knight, {
    name: "ECHO REPLAY", title: "回声 · 回放",
    desc: "回声会照着我方上一个移动的棋子的走法行动。这里假设上一步走的是马：它的身体变成半透明的残影，原样“回放”马的腾跃踏击，一路留下淡紫色的重影。",
    pose(u) { const o = ATK.knight.pose(u); o.sp = 'echow'; o.alpha = .65 + .25 * Math.sin(u * 30); o.white = .15; o.trail = o.trail || (u > 0 && u < .9); return o; }
  });

  // --- reactions ---
  const SWALLOW = { name: '被舌头卷走吞下', desc: '被舌头黏住后，整个棋子被拖离地面、一边打转一边缩小，被拉到变色龙嘴边“咕嘟”一声吞掉，地上只剩一点碎屑。越重的棋子被拖得越慢。',
    get split() { return [.45, .55, .7][WEIGHT[vicKey]]; },
    at() { const q = easeIn(clamp01(rt / this.split)), mouth = { X: (curPose ? curPose.X : G.a.X) + G.dx * 5, Y: (curPose ? curPose.Y : 0) + pxToY(7), Z: (curPose ? curPose.Z : G.a.Z) + G.dz * 5 }; return lerp3(vicCentre(.5), mouth, q); },
    draw(white) { const bs = base(), q = clamp01(rt / this.split), p = this.at(), sc = 1 - .85 * easeIn(q); drawCentered(white ? S[vicKey + 'k!'] : bs, p.X, p.Y, p.Z, sc, sc, q * q * 6 * G.face); },
    onSplit() { const m = { X: G.a.X + G.dx * 5, Z: G.a.Z + G.dz * 5 }; debris(base().pixels, base().w / 2, base().h - 1, m.X, 2, m.Z, { every: 6, vy: 10, spread: 12, life: [.4, .7] }); } };

  const KEG = { name: '爆炸，连吃它的棋子一起炸飞', desc: '吃掉火药桶的一瞬间它就炸了：火光、冲击波和黑烟一起爆开，火药桶炸成碎片，吃它的那个棋子也被炸飞、在空中碎掉。周围一圈的棋子都会被波及（王除外）。',
    split: .1, hold: 1.6, overlay() {},
    onSplit() {
      const bs = base(), b = G.b;
      debris(bs.pixels, bs.w / 2, bs.h - 1, b.X, 0, b.Z, { vy: 90, spread: 70, radial: 6 });
      sparkBurst(b.X, 8, b.Z, 26, 0, 0, 0, 1.3, ORANGE); sparkBurst(b.X, 8, b.Z, 12, 0, 0, 0, .9, '255,230,140');
      ring(b.X, b.Z, V.cell * 1.8, .55, ORANGE); ring(b.X, b.Z, V.cell * 1.1, .4, '255,230,140'); ring(b.X, b.Z, V.cell * .6, .3, ORANGE);
      puff(b.X, 4, b.Z, 20, 1.8); crackDecal(b.X, b.Z, 10, V.cell * 1.3); flash = 1; shake = 1.9; punch = 1;
      const p = curPose, m = masked(S[p.sp], () => true);
      bodies.push(bodyFrom(m, p.X, p.Z, { vx: -G.dx * 120 - G.face * 20, vz: -G.dz * 120, vy: 130, vr: -12 * G.face, grav: 300, shatterGround: true, poof: true }));
      R.attackerGone = true;
    } };

  const EMBER = { name: '化作余烬，留下火种', desc: '被吃掉时全身烧成橙红色，碎成一团向上飘的火星；火星落定后，格子里留下一枚发着光的蛋，一闪一闪地跳动——两回合后它会从起始格重生。',
    split: .3, hold: 1.8,
    draw(white) { const q = clamp01(rt / .3), j = Math.round(rnd(-1, 1) * q); drawSprite(white ? S[vicKey + 'k!'] : base(), G.b.X + j, 0, G.b.Z); drawSprite(S[vicKey + 'k&'], G.b.X + j, 0, G.b.Z, 1, 1, 0, .7 * q); },
    onSplit() { const bs = base(); debris(bs.pixels, bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 30, spread: 25, grav: -50, life: [.8, 1.4], radial: 1.5, col: null }); for (const p of parts.slice(-bs.pixels.length)) p.col = ['#ffd27a', '#ff8a3c', '#ff5a2a', '#fff0b0'][(Math.random() * 4) | 0]; sparkBurst(G.b.X, 6, G.b.Z, 14, 0, 0, 0, .7, ORANGE); ring(G.b.X, G.b.Z, V.cell * .8, .4, ORANGE); },
    after() { if (!R.split) return; const k = clamp01((rt - .7) / .4); if (k <= 0) return; const p = project(G.b.X, 0, G.b.Z), x = Math.round(p.x), y = Math.round(p.y), pulse = .6 + .4 * Math.sin(rt * 8); ctx.globalAlpha = k; ctx.fillStyle = `rgba(255,150,60,${.3 * pulse})`; ctx.beginPath(); ctx.arc(x, y - 4, 6, 0, Math.PI * 2); ctx.fill(); ctx.fillStyle = '#2a1e2e'; ctx.fillRect(x - 2, y - 8, 5, 8); ctx.fillStyle = '#ffb35c'; ctx.fillRect(x - 1, y - 7, 3, 6); ctx.fillStyle = '#fff0b0'; ctx.fillRect(x - 1, y - 6, 1, 2); ctx.globalAlpha = 1; } };

  const SHELL = { name: '外壳碎裂，挺住了', desc: '第一次被吃掉时，石像外面的一层石壳崩开、碎块四散，但本体还立在原地，身上布满裂纹；进攻的棋子被弹回自己原来的格子。要再被吃一次，它才会真正消失。',
    split: Infinity, repel: true, hold: 1.2,
    tick() { if (R.shellDone) return; R.shellDone = true; const bs = base(), edge = bs.pixels.filter(p => [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([a, c]) => !bs.set.has((p.x + a) + ',' + (p.y + c)))); R.inner = masked(bs, (x, y) => !edge.some(p => p.x === x && p.y === y)); debris(edge, bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vx: G.dx * 30, vz: G.dz * 30, vy: 40, spread: 35, radial: 2.5 }); puff(G.b.X, 3, G.b.Z, 8, 1); },
    draw(white) { const bs = base(), { x0, y0 } = footXY(), j = rt < .25 ? Math.round(rnd(-1, 1)) : 0; drawSprite(white ? S[vicKey + 'k!'] : (R.inner || bs), G.b.X + j, 0, G.b.Z); const n = Math.floor(clamp01(rt / .3) * R.web.length * .7); for (let i = 0; i < n; i++) { const w = R.web[i]; if (!(R.inner || bs).pixels.some(p => p.x === w.x && p.y === w.y)) continue; ctx.fillStyle = '#0b0710'; ctx.fillRect(x0 + j + w.x, y0 + w.y, 1, 1); } },
    onSplit() {} };

  const GLASS = { name: '碎成彩色玻璃', desc: '一被击中就“叮”地一声碎裂：整个棋子炸成一片闪着彩光的玻璃碎屑，碎片在空中旋转反光，慢慢落下，在地上闪烁一会儿才消失。',
    split: .08, overlay() {},
    onSplit() { const bs = base(), cols = ['#bff3ff', '#e6c8ff', '#fff3c4', '#c8ffd9', '#ffffff']; debris(bs.pixels, bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vx: G.dx * 30, vz: G.dz * 30, vy: 45, spread: 50, radial: 3, grav: 150, life: [1.4, 2.2] }); for (const p of parts.slice(-bs.pixels.length)) p.col = cols[(Math.random() * cols.length) | 0]; sparkBurst(G.b.X, 8, G.b.Z, 14, 0, 0, 0, .8, '230,250,255'); ring(G.b.X, G.b.Z, V.cell * .8, .35, '230,250,255'); },
    tick() { if (R.split) for (const p of parts) if (Math.random() < .02 && p.col && p.col[0] === '#') p.sz = p.sz === 2 ? 1 : 2; } };

  function RADIANCE(color = '#fff6d8', halo = false) {
    return { name: halo ? '化作圣光，庇护同伴' : '化作光点飘散', desc: halo ? '被吃掉时没有挣扎，身体被暖光笼罩、从头到脚化成金色光点升上天空；同时，它附近的友军头顶各亮起一圈金色光环——下一回合它们受到保护。' : '被灯光照住后，棋子先被一层层染成白色，然后从头顶开始化成光点，一粒粒向上飘散，最后什么也不剩。',
      split: .75, halo, hold: halo ? 1.6 : 0,
      draw(white) { const bs = base(), { x0, y0 } = footXY(), q = clamp01(rt / .3); const m = clamp01((rt - .25) / .5), k = Math.floor(m * bs.h); if (k >= bs.h) return; ctx.drawImage(bs.c, 0, k, bs.w, bs.h - k, x0, y0 + k, bs.w, bs.h - k); ctx.globalAlpha = .75 * q; ctx.drawImage(S[vicKey + 'k*'].c, 0, k, bs.w, bs.h - k, x0, y0 + k, bs.w, bs.h - k); ctx.globalAlpha = 1; },
      tick() { if (R.split || rt < .25) return; const bs = base(), k = Math.floor(clamp01((rt - .25) / .5) * bs.h), row = bs.pixels.filter(p => p.y === k); for (let i = 0; i < 2 && row.length; i++) { const p = row[(Math.random() * row.length) | 0]; debris([{ x: p.x, y: p.y, col: Math.random() < .5 ? color : '#ffe08a' }], bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 25, spread: 6, grav: -40, life: [.6, 1], radial: 0 }); } },
      onSplit() { ring(G.b.X, G.b.Z, V.cell * .6, .4, GOLDC); } };
  }

  const VICTIM_REACT = { powder_keg: () => KEG, ember_bird: () => EMBER, gargoyle: () => SHELL, crystal_mage: () => GLASS, martyr: () => RADIANCE('#ffe08a', true) };
