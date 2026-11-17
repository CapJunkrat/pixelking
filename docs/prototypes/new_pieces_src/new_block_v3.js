  // ---------- v3: fusion-only pieces ----------
  const V3_SPR = {
    stone_giant: ["....ooooo....","...obbhbbo...","...obobobo...","..oobbbbboo..",".obbbbbbbbbo.","obbhbbbbbhbbo","obbobbbbbobbo","obbobbbbbobbo","ohhoobbbooho.","oooo.obo.ooo.","....obobo....","...obo.obo...",".osssssssso..","ooooooooooooo"],
    blast_catapult: ["...........h..","..........oho.",".........obsbo",".........obsbo","........oobbo.",".......obo....","......obo.....",".....obo......","..ooobo.......",".obbobboooooo.",".obbbbbbbbbbho",".ossssssssssso","oobo......oboo","obhbo....obhbo",".ooo......ooo."],
    sky_archer: ["..o..oo....o.",".oh.obho...oh","ohh.obbo...o.h","ohho.oo....o.h","ohhbobbbo..o.h",".ohbbbbbbooooh","..obobbbbo...h","....obbo...o.h","....obbo...o.h","...obbbho..oh.","..obbbbbhooo..","..osssssso....",".oooooooooo..."],
    flame_phoenix: ["...o.o.o......","....ohoho.....","o....obbo....o","oo..obhbbo..oo","obo.obbbbo.obo","obboobbbbboobo",".obbbbbbbbbbo.","..obbbbbbbbo..","...obbbbbbo...","....obbbbo....","...oobooboo...","..obo.oo.obo..",".osssssssssso.","oooooooooooooo"],
    thousand_faces: ["...ooooo...","..obbbhho..",".obbobhoho.",".obbbbhhho.",".obboooho..","..obbbhho..",".ooooooooo.","obbbbbhhhho","obbbbbhhhho",".obbbbhhho.",".obbbbhhho.",".ossssssso.","ooooooooooo"]
  };
  for (const n in V3_SPR) {
    for (const side of ['w', 'k']) { S[n + side] = buildSprite(V3_SPR[n], PAL[side]); S[n + side + '!'] = buildSprite(V3_SPR[n], PAL[side], '#ffffff'); }
    S[n + 'k&'] = buildSprite(V3_SPR[n], PAL.k, '#ff9a3c');
    S[n + 'k*'] = buildSprite(V3_SPR[n], PAL.k, '#fff6d8');
    S[n + 'k#'] = buildSprite(V3_SPR[n], PAL.stone);
  }
  Object.assign(WEIGHT, { stone_giant: 2, blast_catapult: 2, sky_archer: 1, flame_phoenix: 1, thousand_faces: 1 });
  Object.assign(VNAME, { stone_giant: '石巨人', blast_catapult: '爆破投石车', sky_archer: '天鹰射手', flame_phoenix: '炎凰', thousand_faces: '千面者' });
  Object.assign(STARTS, { stone_giant: { x: 3, y: 6 }, blast_catapult: { x: 3, y: 7 }, sky_archer: { x: 0, y: 6 }, flame_phoenix: { x: 2, y: 6 }, thousand_faces: { x: 3, y: 5 } });
  Object.assign(HITNAME, { flatten: '压扁', blast: '爆破', skewer: '贯穿', inferno: '火柱', mimic: '夺形' });
  for (const h of ['flatten', 'blast', 'skewer', 'inferno', 'mimic']) NEW_HITS.add(h);
  const FIRE = ['#fff0b0', '#ffd27a', '#ff8a3c', '#ff5a2a'];
  const fireCol = () => FIRE[(Math.random() * FIRE.length) | 0];
  const STONEC = '190,188,196', VIOLET = '200,160,255';

  Object.assign(ATK, {
    stone_giant: {
      name: "STONE GIANT HAMMER FISTS", hit: 'flatten', impact: 1.0, end: 2.7, hitstop: .16, shake: 1.8,
      title: "石巨人 · 双拳锤地", desc: "石巨人一步一震地走到目标跟前，每一步都让棋盘抖一下、扬起尘土。停下后它身体拔高，两只石拳高高举过头顶，然后整个身子往前一扑，双拳从目标头顶砸下去，把目标一点点锤成扁饼、再碎在地上。石拳收回后，它沉重地踏进格子。",
      stand() { return toward(G.b, 1.0); },
      events: [0, 1, 2].map(i => ({ at: .1 + i * .22, fn: () => { const C = ATK.stone_giant.stand(), k = (i + 1) / 3, X = lerp(G.a.X, C.X, k), Z = lerp(G.a.Z, C.Z, k); puff(X, 1, Z, 6, .9); shake = Math.max(shake, .45); } })),
      pose(u) {
        const { a, face } = G, c = V.cell, C = this.stand(), o = O('stone_giantw');
        if (u < 0) return o;
        if (u < .1) { o.sy = .92; o.sx = 1.05; return o; }
        if (u < .76) { const q = (u - .1) / .66, step = Math.min(2, Math.floor(q * 3)), local = q * 3 - step, k = (step + smooth(local)) / 3; o.X = lerp(a.X, C.X, k); o.Z = lerp(a.Z, C.Z, k); o.Y = Math.sin(local * Math.PI) * 2.5; o.rot = (step % 2 ? .06 : -.06) * face * Math.sin(local * Math.PI); const land = local > .85 ? (local - .85) / .15 : 0; o.sy = 1 - .08 * land; o.sx = 1 + .05 * land; return o; }
        o.X = C.X; o.Z = C.Z;
        if (u < .9) { const s2 = smooth((u - .76) / .14); o.sy = 1 + .15 * s2; o.sx = 1 - .06 * s2; o.white = .15 * s2; return o; }
        if (u < 1.0) { const q = easeIn((u - .9) / .1); o.sy = lerp(1.15, .9, q); o.sx = lerp(.94, 1.1, q); o.X += G.dx * 3 * q; o.Z += G.dz * 3 * q; return o; }
        if (u < 1.75) { o.sy = .9; o.sx = 1.1; o.X += G.dx * 3; o.Z += G.dz * 3; return o; }
        if (u < 1.95) { const q = smooth((u - 1.75) / .2); o.sy = lerp(.9, 1, q); o.sx = lerp(1.1, 1, q); o.X += G.dx * 3 * (1 - q); o.Z += G.dz * 3 * (1 - q); return o; }
        return settleInto(o, C, u, 2.0, .45, 0);
      },
      fists(o, u) {
        if (u < .76 || u > 1.95) return null;
        const c = V.cell, sh = { X: o.X, Y: o.Y + pxToY(14), Z: o.Z }, overhead = { X: o.X, Y: o.Y + pxToY(22), Z: o.Z };
        const top = { X: G.b.X, Y: pxToY(base().h * (impacted ? FLATTEN.sy() : 1) + 1), Z: G.b.Z };
        let p;
        if (u < .9) p = lerp3(sh, overhead, smooth((u - .76) / .14));
        else if (u < 1.0) { const q = easeIn((u - .9) / .1); p = lerp3(overhead, top, q); p.Y += c * .8 * Math.sin(q * Math.PI); }
        else if (u < 1.75) p = top;
        else p = lerp3(top, sh, smooth((u - 1.75) / .2));
        return p;
      },
      fx(o, u) {
        const p = this.fists(o, u); if (!p) return;
        for (const side of [-1, 1]) { const q = project(p.X + side * 3, p.Y, p.Z), x = Math.round(q.x) - 2, y = Math.round(q.y) - 4; ctx.fillStyle = '#26252b'; ctx.fillRect(x - 1, y - 1, 6, 6); ctx.fillStyle = '#8f8d93'; ctx.fillRect(x, y, 4, 4); ctx.fillStyle = '#bdbbc1'; ctx.fillRect(x, y, 4, 1); ctx.fillRect(x, y, 1, 4); }
      },
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.6, .55, STONEC); ring(b.X, b.Z, V.cell * .9, .35); crackDecal(b.X, b.Z, 11, V.cell * 1.3); sparkBurst(b.X, 14, b.Z, 10, 0, 0, 0, .7, STONEC); },
      react: () => FLATTEN
    },
    blast_catapult: {
      name: "BLAST CATAPULT POWDER LOB", hit: 'blast', impact: 1.05, end: 2.6, hitstop: .16, shake: 2.0,
      title: "爆破投石车 · 火药弹", desc: "投石车原地不动。它把投臂往后压到底，然后猛地一甩，抛出一只点着引信的火药桶；火药桶在空中翻着跟头划出一道很高的弧线，地上的影子越来越大，目标周围一圈格子开始闪红光预警。落地瞬间轰然爆炸，目标和它周围一圈的敌人（王除外）一起被炸碎。",
      near: [{ x: 4, y: 2 }, { x: 2, y: 3 }],
      events: [{ at: .42, fn: () => { puff(G.a.X, 4, G.a.Z, 6, .8); shake = Math.max(shake, .4); } }],
      pose(u) {
        const o = O('blast_catapultw'); if (u < 0) return o;
        if (u < .4) { const s = smooth(u / .4); o.sx = 1 + .06 * s; o.sy = 1 - .1 * s; o.rot = -.07 * s * G.face; return o; }
        if (u < .52) { const q = (u - .4) / .12; o.rot = lerp(-.07, .1, easeOut(q)) * G.face; o.sy = 1.05; return o; }
        if (u < .8) { o.rot = .1 * G.face * (1 - (u - .52) / .28); }
        return o;
      },
      shell(u) { if (u < .42 || u > this.impact) return null; const q = (u - .42) / (this.impact - .42), src = { X: G.a.X, Y: pxToY(15), Z: G.a.Z }, dst = { X: G.b.X, Y: pxToY(4), Z: G.b.Z }, p = lerp3(src, dst, q); p.Y += V.cell * 3.2 * 4 * q * (1 - q); return { p, q }; },
      groundFx(o, u) {
        const s = this.shell(u);
        if (!impacted) for (const n of this.near) { const w = cellW(n.x, n.y); shadow(w.X, w.Z, 0, 10); drawSprite(S.pawnk, w.X, 0, w.Z); }
        let a = 0;
        if (impacted) a = .55 * Math.max(0, 1 - rt / .9);
        else if (s && s.q > .35) a = .18 + .18 * Math.sin(u * 40);
        if (a > 0) for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) poly(cellPoly(TARGET.x + dx, TARGET.y + dy, 1), `rgba(255,${impacted ? 140 : 80},50,${a})`);
        if (s) groundEllipse(s.p.X, s.p.Z, 1.5 + 3 * s.q, `rgba(0,0,0,${.15 + .3 * s.q})`);
      },
      fx(o, u) {
        const s = this.shell(u); if (!s) return;
        const pr = project(s.p.X, s.p.Y, s.p.Z), x = Math.round(pr.x), y = Math.round(pr.y), flip = Math.floor(u * 20) % 2;
        ctx.fillStyle = '#2a1e2e'; ctx.fillRect(x - 2, y - 2, 5, 5); ctx.fillStyle = '#8a5a3a'; ctx.fillRect(x - 1, y - 1, 3, 3); ctx.fillStyle = '#e0b45c'; ctx.fillRect(flip ? x - 1 : x, y - 1, 1, 3);
        parts.push({ X: s.p.X, Y: s.p.Y + 3, Z: s.p.Z, vx: rnd(-10, 10), vy: rnd(0, 15), vz: 0, col: fireCol(), life: rnd(.15, .3), age: 0, sz: 1, bounced: 2, g: 60 });
      },
      hitFx() {
        const b = G.b; flash = 1;
        ring(b.X, b.Z, V.cell * 2.0, .6, ORANGE); ring(b.X, b.Z, V.cell * 1.3, .45, '255,230,140'); ring(b.X, b.Z, V.cell * .7, .3, ORANGE);
        sparkBurst(b.X, 8, b.Z, 30, 0, 0, 0, 1.4, ORANGE); puff(b.X, 4, b.Z, 22, 2.0); crackDecal(b.X, b.Z, 12, V.cell * 1.5);
        for (const n of this.near) { const w = cellW(n.x, n.y), bs = S.pawnk; debris(bs.pixels, bs.w / 2, bs.h - 1, w.X, 0, w.Z, { vx: (w.X - b.X) * 4, vz: (w.Z - b.Z) * 4, vy: 80, spread: 45, radial: 4 }); for (const p of parts.slice(-bs.pixels.length)) if (Math.random() < .5) p.col = fireCol(); sparkBurst(w.X, 6, w.Z, 10, 0, 0, 0, .9, ORANGE); puff(w.X, 3, w.Z, 8, 1.2); }
      },
      react: () => BLAST
    },
    sky_archer: {
      name: "SKY ARCHER HEAVEN DIVE", hit: 'skewer', impact: 1.2, end: 2.5, hitstop: .14, shake: 1.1,
      title: "天鹰射手 · 天鹰贯日", desc: "射手原地单膝下蹲，弓口朝天，一箭射上高空不见了；片刻之后，目标头顶的天上亮起一颗金星，一只由金光化成的鹰收拢双翼、笔直俯冲而下，像一支巨箭把目标从头到脚钉穿在地上。目标从中间裂成左右两半倒下，金色羽毛慢慢飘落。射手全程不离开自己的格子。",
      events: [{ at: .45, fn: () => sparkBurst(G.a.X, 14, G.a.Z, 6, 0, 0, 0, .5, GOLDC) }],
      pose(u) {
        const o = O('sky_archerw'); if (u < 0) return o;
        if (u < .4) { const s = smooth(u / .4); o.sy = 1 - .12 * s; o.sx = 1 + .05 * s; o.rot = -.15 * s * G.face; return o; }
        if (u < .45) { o.sy = .88; o.rot = -.15 * G.face; return o; }
        if (u < .65) { const q = (u - .45) / .2; o.sy = lerp(.86, 1, smooth(q)); o.rot = -.15 * G.face * (1 - q); return o; }
        return o;
      },
      fx(o, u) {
        const c = V.cell;
        if (u > .45 && u < .72) { const q = (u - .45) / .27, y = pxToY(14) + q * c * 7, p = project(G.a.X, y, G.a.Z), p2 = project(G.a.X, y - 10, G.a.Z); pixLine(p2.x, p2.y, p.x, p.y, '#ffe08a'); ctx.fillStyle = '#ffffff'; ctx.fillRect(Math.round(p.x), Math.round(p.y), 1, 1); }
        if (u > .68 && u < .9) { const k = Math.sin((u - .68) / .22 * Math.PI), p = project(G.b.X, c * 5, G.b.Z), x = Math.round(p.x), y = Math.round(p.y), r = Math.round(1 + 3 * k); ctx.fillStyle = '#fff3c4'; ctx.fillRect(x - r, y, 2 * r + 1, 1); ctx.fillRect(x, y - r, 1, 2 * r + 1); }
        if (u > .86 && !impacted) {
          const q = clamp01((u - .86) / (this.impact - .86)), Y = lerp(c * 5, pxToY(base().h + 2), easeIn(q)), p = project(G.b.X, Y, G.b.Z), x = Math.round(p.x), y = Math.round(p.y);
          ctx.strokeStyle = 'rgba(255,226,150,.45)'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(x, y - 30); ctx.lineTo(x, y); ctx.stroke();
          ctx.fillStyle = '#ffd27a'; for (let i = 1; i <= 7; i++) { ctx.fillRect(x - i, y - 2 - i, 1, 1); ctx.fillRect(x + i, y - 2 - i, 1, 1); }
          ctx.fillStyle = '#fff3c4'; ctx.fillRect(x, y - 6, 1, 7); ctx.fillRect(x - 1, y - 6, 3, 2);
        }
      },
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.3, .5, GOLDC); ring(b.X, b.Z, V.cell * .6, .3, '255,250,230'); sparkBurst(b.X, 4, b.Z, 14, 0, 0, 0, .8, GOLDC); for (let i = 0; i < 14; i++) parts.push({ X: b.X + rnd(-8, 8), Y: pxToY(rnd(12, 24)), Z: b.Z + rnd(-3, 3), vx: rnd(-8, 8), vy: rnd(-4, 4), vz: 0, col: Math.random() < .5 ? '#ffe08a' : '#fff6d8', life: rnd(1.2, 1.8), age: 0, sz: 1, bounced: 2, g: 12 }); },
      react: () => SKEWER
    },
    flame_phoenix: {
      name: "FLAME PHOENIX INFERNO", hit: 'inferno', impact: .78, end: 2.6, hitstop: .12, shake: 1.2,
      title: "炎凰 · 凤火燎原", desc: "炎凰升到半空，张开一对熊熊燃烧的火翼；接着压低身子贴着棋盘高速滑翔，从目标身上一穿而过，沿途在地上留下一道火痕。被穿过的目标脚下猛地喷起一根火柱，身体被烧得发白、化成火星往上飘散。炎凰在空中绕回来，收起火翼落进格子。",
      events: [{ at: .2, fn: () => { ring(G.a.X, G.a.Z, V.cell * .8, .4, ORANGE); puff(G.a.X, 1, G.a.Z, 6, .8); } }],
      past() { return { X: G.b.X + G.dx * V.cell * 1.1, Z: G.b.Z + G.dz * V.cell * 1.1 }; },
      pose(u) {
        const { a, b, face } = G, c = V.cell, o = O('flame_phoenixw'), past = this.past();
        if (u < 0) return o;
        if (u < .45) { const s = smooth(u / .45); o.Y = c * 1.1 * s; o.sy = 1 + .1 * Math.sin(u * 30); o.white = .25 * s; o.wings = s; return o; }
        if (u < .86) { const q = (u - .45) / .41, e = easeIn(q); o.X = lerp(a.X, past.X, e); o.Z = lerp(a.Z, past.Z, e); o.Y = lerp(c * 1.1, c * .3, e); o.rot = .25 * face; o.sx = 1.15; o.sy = .9; o.trail = true; o.wings = 1; o.white = .35; o.glide = true; return o; }
        if (u < 1.5) { const q = (u - .86) / .64, k = smooth(q); o.X = lerp(past.X, b.X, k); o.Z = lerp(past.Z, b.Z, k); o.Y = c * .3 + c * 1.2 * Math.sin(q * Math.PI); o.rot = lerp(.25, -.15, q) * face; o.wings = 1 - .4 * q; return o; }
        o.X = b.X; o.Z = b.Z;
        if (u < 1.75) { const q = (u - 1.5) / .25; o.Y = c * .3 * (1 - easeIn(q)); o.rot = -.15 * face * (1 - q); o.wings = .6 * (1 - q); return o; }
        if (u < 1.9) { const q = (u - 1.75) / .15, w = Math.sin(q * Math.PI); o.sy = 1 - .15 * w; o.sx = 1 + .12 * w; }
        return o;
      },
      fx(o, u) {
        if (o.wings > 0) {
          const flap = Math.sin(u * 22) * 2;
          for (const side of [-1, 1]) for (let i = 2; i <= 10; i++) { const k = i / 10, p = project(o.X + side * i * o.wings, o.Y + pxToY(8 + (5 * Math.sin(k * Math.PI) + flap * k) * o.wings), o.Z); ctx.fillStyle = FIRE[Math.min(3, (i / 3) | 0)]; ctx.fillRect(Math.round(p.x), Math.round(p.y), 1, 2); }
          if (Math.random() < .8) parts.push({ X: o.X + rnd(-9, 9) * o.wings, Y: o.Y + pxToY(rnd(6, 12)), Z: o.Z, vx: rnd(-6, 6), vy: rnd(5, 20), vz: 0, col: fireCol(), life: rnd(.2, .4), age: 0, sz: 1, bounced: 2, g: -30 });
        }
        if (o.glide) for (let i = 0; i < 2; i++) parts.push({ X: o.X + rnd(-2, 2), Y: 0, Z: o.Z + rnd(-2, 2), vx: rnd(-3, 3), vy: rnd(8, 20), vz: 0, col: fireCol(), life: rnd(.4, .8), age: 0, sz: 1, bounced: 2, g: -25 });
      },
      hitFx() { const b = G.b; ring(b.X, b.Z, V.cell * 1.3, .5, ORANGE); ring(b.X, b.Z, V.cell * .7, .35, '255,230,140'); sparkBurst(b.X, 6, b.Z, 18, G.dx, G.dz, 40, 1, ORANGE); },
      react: () => INFERNO
    },
    thousand_faces: {
      name: "THOUSAND FACES SKIN THIEF", hit: 'mimic', impact: .95, get end() { return this.absorbAt() + 1.5; }, hitstop: .08, shake: .5,
      title: "千面者 · 千面夺形", desc: "千面者一边走向目标，一边在马、象、车等学过的样子之间闪烁变换，最后在目标前一格停下，以原形和目标对视，两者之间泛起一道镜面般的闪光。随后目标的样子化作一个发光的白色幻影，从它身上剥离、飘进千面者体内；目标只剩一具灰色石壳，从上往下塌成粉尘。千面者吸收幻影后变成目标的模样（白色）亮相片刻，再闪回原形，走进格子。",
      forms: ['knightw', 'bishopw', 'rookw'],
      events: [],
      stand() { return toward(G.b, 1.05); },
      absorbAt() { return this.impact + MIMIC.split; },
      pose(u) {
        const { a } = G, C = this.stand(), o = O('thousand_facesw');
        if (u < 0) return o;
        if (u < .6) { const q = u / .6, idx = Math.floor(u / .1); o.X = lerp(a.X, C.X, smooth(q)); o.Z = lerp(a.Z, C.Z, smooth(q)); if (idx % 2) o.sp = this.forms[(idx >> 1) % 3]; o.white = (u % .1) < .03 ? .8 : 0; o.Y = Math.abs(Math.sin(q * Math.PI * 3)) * 1.5; return o; }
        o.X = C.X; o.Z = C.Z;
        const ab = this.absorbAt();
        if (u < ab) { if (u > .75) o.rot = .05 * G.face * Math.sin(u * 12); return o; }
        if (u < ab + .7) { o.sp = vicKey + 'w'; o.white = Math.max(0, 1 - (u - ab) / .2); return o; }
        if (u < ab + .85) { o.white = 1 - (u - ab - .7) / .15; return o; }
        return settleInto(o, C, u, ab + .95, .35, 1);
      },
      fx(o, u) {
        if (u > .7 && u < 1.0) { const m = { X: (o.X + G.b.X) / 2, Z: (o.Z + G.b.Z) / 2 }; for (let i = 0; i < 16; i++) { if (Math.random() < .3) continue; const p = project(m.X, pxToY(i), m.Z); ctx.fillStyle = i % 3 ? 'rgba(200,180,255,.7)' : 'rgba(255,255,255,.9)'; ctx.fillRect(Math.round(p.x) - 2, Math.round(p.y), 5, 1); } }
        if (impacted && !R.split) { const q = clamp01(rt / MIMIC.split), from = { X: G.b.X, Y: 0, Z: G.b.Z }, to = { X: o.X, Y: 0, Z: o.Z }, lift = pxToY(base().h + 4) * smooth(clamp01(q / .35)), k = smooth(clamp01((q - .35) / .65)), p = lerp3(from, to, k); p.Y = lift * (1 - k) + pxToY(4) * k + V.cell * .5 * Math.sin(k * Math.PI); const sc = 1 - .2 * k; drawSprite(S[vicKey + 'k*'], p.X, p.Y, p.Z, sc, sc, 0, .55 + .3 * clamp01(q / .35)); }
        const ab = this.absorbAt();
        if (u > ab && u < ab + .3 && Math.random() < .6) sparkBurst(o.X, 8, o.Z, 2, 0, 0, 0, .4, VIOLET);
      },
      hitFx() { ring(G.b.X, G.b.Z, V.cell * .8, .45, VIOLET); sparkBurst(G.b.X, 8, G.b.Z, 8, 0, 0, 0, .5, VIOLET); },
      react: () => MIMIC
    }
  });

  // --- v3 reactions ---
  const FLATTEN = { name: '被锤扁', desc: '石拳压在头顶，目标被一点点往下压，身体越来越扁、往两边鼓出来，最后像一张饼一样摊在地上，再沿着地面碎裂四散。越重的棋子撑得越久。',
    get split() { return [.55, .65, .75][WEIGHT[vicKey]]; },
    sy() { return lerp(1, .2, easeOut(clamp01(rt / (this.split - .05)))); },
    draw(white) { const sy = this.sy(), sx = lerp(1, 1.7, (1 - sy) / .8), j = Math.round(rnd(-1, 1) * (1 - sy)); drawSprite(white ? S[vicKey + 'k!'] : base(), G.b.X + j, 0, G.b.Z, sx, sy); },
    tick() { if (Math.random() < .3) puff(G.b.X + rnd(-6, 6), 1, G.b.Z, 1, .5); },
    onSplit() { const bs = base(); debris(bs.pixels, bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 6, spread: 45, radial: 3.5, grav: 300, rot: 0 }); for (const p of parts.slice(-bs.pixels.length)) p.Y = Math.min(p.Y, pxToY(3)); puff(G.b.X, 1, G.b.Z, 12, 1.4); shake = Math.max(shake, .8); } };

  const BLAST = { name: '炸成碎片', desc: '火药桶在脚下爆开，目标瞬间被炸成无数碎片，一半带着火光向四面八方飞散；周围一圈的敌人也被一起炸碎。',
    split: .02, overlay() {},
    onSplit() { const bs = base(); debris(bs.pixels, bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 110, spread: 70, radial: 5, grav: 260 }); for (const p of parts.slice(-bs.pixels.length)) if (Math.random() < .45) p.col = fireCol(); } };

  const SKEWER = { name: '被钉穿，裂成两半', desc: '金鹰从头顶贯穿下来，把目标钉在地上；目标僵住抖了一下，随即从正中间裂开，左右两半各自向外倒下摔碎。一支金色的光箭留在格子中央，慢慢淡去。',
    get split() { return [.28, .36, .45][WEIGHT[vicKey]]; },
    draw(white) { const j = rt < .2 ? Math.round(rnd(-1, 1)) : 0; drawSprite(white ? S[vicKey + 'k!'] : base(), G.b.X + j, 0, G.b.Z); },
    onSplit() { const bs = base(), half = bs.w / 2; const L = masked(bs, x => x < half), Rr = masked(bs, x => x >= half);
      bodies.push(bodyFrom(L, G.b.X, G.b.Z, { vx: -35, vy: 30, vr: -4, grav: 260, shatterGround: true }));
      bodies.push(bodyFrom(Rr, G.b.X, G.b.Z, { vx: 35, vy: 30, vr: 4, grav: 260, shatterGround: true })); },
    after() { if (!impacted || rt > 1.6) return; const a = rt < 1 ? 1 : 1 - (rt - 1) / .6, h = base().h, p0 = project(G.b.X, 0, G.b.Z), p1 = project(G.b.X, pxToY(h + 8), G.b.Z); ctx.globalAlpha = a; pixLine(p0.x, p0.y, p1.x, p1.y, '#ffe08a'); ctx.fillStyle = '#fff6d8'; ctx.fillRect(Math.round(p1.x) - 1, Math.round(p1.y), 3, 1); ctx.fillRect(Math.round(p1.x) - 2, Math.round(p1.y) + 1, 5, 1); ctx.globalAlpha = 1; } };

  const INFERNO = { name: '火柱焚尽', desc: '脚下猛地喷起一根火柱，把目标整个吞没；目标在火里被烧得越来越白，从头到脚化成火星，跟着火柱一起往上飘散。越重的棋子烧得越久。',
    get split() { return [.45, .6, .75][WEIGHT[vicKey]]; },
    draw(white) { const q = clamp01(rt / this.split), j = Math.round(rnd(-1, 1) * q); drawSprite(white ? S[vicKey + 'k!'] : base(), G.b.X + j, 0, G.b.Z); drawSprite(S[vicKey + 'k&'], G.b.X + j, 0, G.b.Z, 1, 1, 0, .6 * clamp01(q * 2)); drawSprite(S[vicKey + 'k*'], G.b.X + j, 0, G.b.Z, 1, 1, 0, clamp01(q * 2 - 1)); },
    tick() { if (Math.random() < .9) parts.push({ X: G.b.X + rnd(-5, 5), Y: pxToY(rnd(0, 6)), Z: G.b.Z + rnd(-2, 2), vx: rnd(-4, 4), vy: rnd(30, 60), vz: 0, col: fireCol(), life: rnd(.3, .6), age: 0, sz: 1, bounced: 2, g: -20 }); },
    after() {
      if (!impacted) return; const end = this.split + .5; if (rt > end) return;
      const grow = clamp01(rt / .15), fade = rt > this.split ? 1 - (rt - this.split) / .5 : 1, Hh = 30 * grow, p = project(G.b.X, 0, G.b.Z), x0 = Math.round(p.x), y0 = Math.round(p.y);
      for (let dx = -5; dx <= 5; dx++) { const h = Math.round(Hh * (1 - Math.abs(dx) / 6) * (.75 + .25 * Math.sin(rt * 35 + dx * 1.7))); ctx.fillStyle = `rgba(255,${Math.abs(dx) < 2 ? 230 : Math.abs(dx) < 4 ? 160 : 90},60,${.55 * fade})`; ctx.fillRect(x0 + dx, y0 - h, 1, h); }
    },
    onSplit() { const bs = base(); debris(bs.pixels, bs.w / 2, bs.h - 1, G.b.X, 0, G.b.Z, { vy: 40, spread: 12, grav: -60, life: [.5, .9], radial: .8 }); for (const p of parts.slice(-bs.pixels.length)) p.col = Math.random() < .5 ? '#fff6d8' : fireCol(); } };

  const MIMIC = { name: '样子被剥走，只剩石壳', desc: '目标的样子化作一个发光的白色幻影，从身上剥离、飘向千面者；目标本体随之褪成灰色石壳，幻影一被吸走，石壳就从上往下塌成粉尘。越重的棋子被剥得越久。',
    get split() { return [.75, .9, 1.05][WEIGHT[vicKey]]; },
    draw(white) { const q = clamp01(rt / this.split); drawSprite(white ? S[vicKey + 'k!'] : base(), G.b.X, 0, G.b.Z, 1, 1, 0, 1 - clamp01(q * 1.6)); drawSprite(S[vicKey + 'k#'], G.b.X, 0, G.b.Z, 1, 1, 0, clamp01(q * 1.6)); },
    onSplit() { const st = S[vicKey + 'k#']; debris(st.pixels, st.w / 2, st.h - 1, G.b.X, 0, G.b.Z, { vy: 6, spread: 14, radial: .6, grav: 220, life: [.8, 1.3] }); puff(G.b.X, 2, G.b.Z, 8, .8); } };

  // stone giant when captured: loses a chunk but stays (needs 3 captures per battle)
  const CHIP = { name: '崩掉一块，还站着', desc: '石巨人被吃时不会倒下：身上一大块岩石崩落、滚到地上摔碎，本体依旧立着；头顶的三颗石头标记熄灭一颗（这场还剩两次）。进攻的棋子被弹回原来的格子。',
    split: Infinity, repel: true, hold: 1.4,
    tick() { if (R.chipDone) return; R.chipDone = true; const bs = base(), cut = (x, y) => x < bs.w * .5 && y < bs.h * .5; R.inner = masked(bs, (x, y) => !cut(x, y)); bodies.push(bodyFrom(masked(bs, cut), G.b.X, G.b.Z, { vx: -G.dz * 25 - 20, vz: G.dx * 25, vy: 70, vr: -7, grav: 300, shatterGround: true, poof: true })); puff(G.b.X, 6, G.b.Z, 8, 1); sparkBurst(G.b.X, 10, G.b.Z, 8, 0, 0, 0, .6, STONEC); },
    draw(white) { const j = rt < .25 ? Math.round(rnd(-1, 1)) : 0; drawSprite(white ? S[vicKey + 'k!'] : (R.inner || base()), G.b.X + j, 0, G.b.Z); },
    after() { if (!impacted) return; const p = project(G.b.X, pxToY(base().h + 4), G.b.Z); for (let i = 0; i < 3; i++) { const x = Math.round(p.x) - 4 + i * 4, y = Math.round(p.y), lost = i === 0 && rt > .35; ctx.fillStyle = '#0d0a14'; ctx.fillRect(x - 1, y - 1, 3, 3); ctx.fillStyle = lost ? '#3a3540' : '#bdbbc1'; ctx.fillRect(x, y, 1, 1); } },
    onSplit() {} };

  // flame phoenix when captured: becomes a fireball, reborn next turn
  const REBIRTH = { name: '化作火球，1 回合后重生', desc: '炎凰被吃的瞬间整个燃成一团火球，“嗖”地冲上半空，划一道火弧飞回己方底线角落，落地后变成一团跳动的火焰，上面亮着一个点——一回合后它就从这里重生。',
    split: .25, hold: 1.8,
    dest() { return cellW(7, 0); },
    draw(white) { const q = clamp01(rt / .25), j = Math.round(rnd(-1, 1) * q); drawSprite(white ? S[vicKey + 'k!'] : base(), G.b.X + j, 0, G.b.Z); drawSprite(S[vicKey + 'k&'], G.b.X + j, 0, G.b.Z, 1, 1, 0, .8 * q); },
    onSplit() { sparkBurst(G.b.X, 8, G.b.Z, 16, 0, 0, 0, .8, ORANGE); ring(G.b.X, G.b.Z, V.cell * .8, .4, ORANGE); },
    ball() { const q = clamp01((rt - .25) / .8), d = this.dest(), p = lerp3({ X: G.b.X, Y: pxToY(8), Z: G.b.Z }, { X: d.X, Y: pxToY(5), Z: d.Z }, smooth(q)); p.Y += V.cell * 3 * Math.sin(q * Math.PI); return { p, q }; },
    after() {
      if (!R.split) return; const { p, q } = this.ball();
      if (q < 1) { const pr = project(p.X, p.Y, p.Z), x = Math.round(pr.x), y = Math.round(pr.y); ctx.fillStyle = 'rgba(255,150,60,.35)'; ctx.beginPath(); ctx.arc(x, y, 5, 0, Math.PI * 2); ctx.fill(); ctx.fillStyle = '#ff8a3c'; ctx.fillRect(x - 2, y - 2, 5, 5); ctx.fillStyle = '#fff0b0'; ctx.fillRect(x - 1, y - 1, 3, 3); parts.push({ X: p.X, Y: p.Y, Z: p.Z, vx: rnd(-6, 6), vy: rnd(-4, 8), vz: 0, col: fireCol(), life: rnd(.25, .45), age: 0, sz: 1, bounced: 2, g: -10 }); if (q > .97 && !R.landed) { R.landed = true; const d = this.dest(); ring(d.X, d.Z, V.cell * .6, .4, ORANGE); sparkBurst(d.X, 4, d.Z, 10, 0, 0, 0, .6, ORANGE); } return; }
      const d = this.dest(), pr = project(d.X, 0, d.Z), x = Math.round(pr.x), y = Math.round(pr.y), pulse = .6 + .4 * Math.sin(rt * 9);
      ctx.fillStyle = `rgba(255,150,60,${.3 * pulse})`; ctx.beginPath(); ctx.arc(x, y - 4, 6, 0, Math.PI * 2); ctx.fill();
      for (let i = -2; i <= 2; i++) { const h = Math.round((6 - Math.abs(i) * 2) * (.8 + .2 * Math.sin(rt * 20 + i))); ctx.fillStyle = Math.abs(i) < 1 ? '#fff0b0' : '#ff8a3c'; ctx.fillRect(x + i, y - h, 1, h); }
      ctx.fillStyle = '#0d0a14'; ctx.fillRect(x - 1, y - 12, 3, 3); ctx.fillStyle = '#ffd27a'; ctx.fillRect(x, y - 11, 1, 1);
    } };

  VICTIM_REACT.stone_giant = () => CHIP;
  VICTIM_REACT.flame_phoenix = () => REBIRTH;
