# -*- coding: utf-8 -*-
import io, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
s = io.open('../special_strikes.html', encoding='utf-8').read()
blk = io.open('new_block.js', encoding='utf-8').read() + io.open('new_block_v2.js', encoding='utf-8').read() + io.open('new_block_v3.js', encoding='utf-8').read()

def rep(a, b):
    global s
    assert a in s, a[:70]
    s = s.replace(a, b, 1)

rep(u"<title>PixelKing 特殊棋子动画</title>", u"<title>PixelKing 新棋子动画</title>")
rep(u"<h1>PIXELKING · SPECIAL STRIKES</h1>", u"<h1>PIXELKING · NEW PIECES</h1>")
a0 = s.index(u'<p class="sub">'); a1 = s.index(u'</p>', a0) + 4
s = s[:a0] + u'<p class="sub">计划新增的 26 个棋子（含 5 个融合限定棋子，标“融合”）：每个的攻击动画，以及其中 7 个“被吃时有特殊效果”的受击动画。选攻击方和受击方，点画面重播。小像素棋子只是示意，进游戏后用正式贴图。</p>' + s[a1:]

NEW = [('courier', u'疾风信使', u'两步疾风斩'), ('tide_knight', u'潮汐骑士', u'巨浪冲锋'), ('echo', u'回声', u'共鸣震碎'), ('chameleon', u'变色龙', u'长舌吞噬'), ('sentry', u'哨兵', u'戟刺'), ('falconer', u'鹰隼猎手', u'放鹰'), ('vanguard', u'先锋', u'突刺'), ('squire', u'侍从', u'连刺升级'), ('stand_in', u'替身', u'飞爪飞踢'), ('powder_keg', u'火药桶兵', u'撞击'), ('ember_bird', u'余烬鸟', u'火羽连射'), ('gargoyle', u'石像守卫', u'裂地石刺'), ('crystal_mage', u'水晶法师', u'晶刺齐射'), ('ranger', u'游侠', u'回旋镖'), ('monk', u'日月僧侣', u'日月双掌'), ('antelope', u'羚羊', u'跃角挑飞'), ('war_king', u'战王', u'天坠斩'), ('shadow_king', u'隐王', u'蚀影'), ('shield_king', u'护盾王', u'圣盾冲撞'), ('lantern_bearer', u'提灯人', u'照灭'), ('martyr', u'殉道者', u'香炉挥击'), ('stone_giant', u'石巨人', u'融合 · 双拳锤地'), ('blast_catapult', u'爆破投石车', u'融合 · 火药弹'), ('sky_archer', u'天鹰射手', u'融合 · 天鹰贯日'), ('flame_phoenix', u'炎凰', u'融合 · 凤火燎原'), ('thousand_faces', u'千面者', u'融合 · 千面夺形')]
names = dict((k, n) for k, n, _ in NEW)

a0 = s.index(u'<div class="seg" id="segAtkSpecial">'); a1 = s.index(u'</div>', a0)
btns = u''.join(u'\n        <button type="button" id="a-%s" data-k="%s">%s<small>%s</small></button>' % (k, k, n, m) for k, n, m in NEW)
s = s[:a0] + u'<div class="seg" id="segAtkSpecial">' + btns + u'\n      ' + s[a1:]
rep(u'<span class="label">攻击方（白）· 特殊棋子</span>', u'<span class="label">攻击方（白）· 新棋子</span>')
rep(u'<span class="label">攻击方（白）· 标准棋子（已完成，可以用来看特殊棋子挨打）</span>', u'<span class="label">攻击方（白）· 标准棋子（已完成，可以用来看新棋子挨打）</span>')

W = {'courier': u'轻', 'tide_knight': u'中', 'echo': u'中', 'chameleon': u'中', 'sentry': u'重', 'falconer': u'轻', 'vanguard': u'轻', 'squire': u'轻', 'stand_in': u'轻', 'powder_keg': u'轻 · 特效', 'ember_bird': u'中 · 特效', 'gargoyle': u'重 · 特效', 'crystal_mage': u'中 · 特效', 'ranger': u'轻', 'monk': u'中', 'antelope': u'中', 'war_king': u'重', 'shadow_king': u'重', 'shield_king': u'重', 'lantern_bearer': u'轻', 'martyr': u'轻 · 特效', 'stone_giant': u'重 · 特效', 'blast_catapult': u'重', 'sky_archer': u'中', 'flame_phoenix': u'中 · 特效', 'thousand_faces': u'中'}
special = ['powder_keg', 'ember_bird', 'gargoyle', 'crystal_mage', 'martyr', 'stone_giant', 'flame_phoenix']
order = special + [k for k, _, _ in NEW if k not in special]
v0 = s.index(u'<div class="seg" id="segVic">'); v1 = s.index(u'</div>', v0)
vb = u''.join(u'\n        <button type="button" id="v-%s" data-k="%s">%s<small>%s</small></button>' % (k, k, names[k], W[k]) for k in order)
vb += u'\n        <button type="button" id="v-pawn" data-k="pawn">兵<small>轻</small></button>\n        <button type="button" id="v-knight" data-k="knight">马<small>中</small></button>\n        <button type="button" id="v-rook" data-k="rook">车<small>重</small></button>'
s = s[:v0] + u'<div class="seg" id="segVic">' + vb + u'\n      ' + s[v1:]

rows = [('courier', u'疾风信使', u'轻', u'两步疾风斩', u'斩击', u'按规则表'), ('tide_knight', u'潮汐骑士', u'中', u'巨浪冲锋', u'冲击', u'按规则表'), ('echo', u'回声', u'中', u'共鸣震碎（站着放声波）', u'共振（新）', u'越抖越厉害，沿横向裂纹震散'), ('chameleon', u'变色龙', u'中', u'长舌吞噬', u'吞噬（新）', u'被舌头卷回来吞掉，越重拖得越慢'), ('sentry', u'哨兵', u'重', u'戟刺', u'穿刺', u'按规则表'), ('falconer', u'鹰隼猎手', u'轻', u'放鹰（自己不动）', u'穿刺', u'按规则表'), ('vanguard', u'先锋', u'轻', u'突刺', u'穿刺', u'按规则表'), ('squire', u'侍从', u'轻', u'连刺两下 + 升级光效', u'穿刺', u'按规则表'), ('stand_in', u'替身', u'轻', u'飞爪钩住后借力飞踢', u'冲击', u'按规则表'), ('powder_keg', u'火药桶兵', u'轻', u'撞击', u'冲击', u'特效：爆炸，连吃它的棋子一起炸飞'), ('ember_bird', u'余烬鸟', u'中', u'火羽连射（站着放）', u'灼烧（新）', u'攻击时对手烧成灰；自己被吃时化作火星、留下发光的蛋'), ('gargoyle', u'石像守卫', u'重', u'捶地裂缝 + 石刺', u'地刺（新）', u'攻击时对手被石刺掀飞；自己被吃时外壳碎裂但挺住'), ('crystal_mage', u'水晶法师', u'中', u'晶刺齐射（站着放）', u'穿刺', u'特效：碎成彩色玻璃'), ('ranger', u'游侠', u'轻', u'回旋镖（站着放）', u'斩击', u'按规则表'), ('monk', u'日月僧侣', u'中', u'金掌震晃 + 蓝掌打飞', u'冲击', u'按规则表'), ('antelope', u'羚羊', u'中', u'跃到面前，用角挑飞', u'挑飞（新）', u'被挑上天，翻过头顶摔碎'), ('war_king', u'战王', u'重', u'跃起天坠斩 + 金色冲击波', u'斩击', u'按规则表'), ('shadow_king', u'隐王', u'重', u'蚀影', u'斩击', u'按规则表'), ('shield_king', u'护盾王', u'重', u'圣盾冲撞', u'冲击', u'按规则表'), ('lantern_bearer', u'提灯人', u'轻', u'照灭（站着放）', u'圣光（新）', u'被染白，化成光点飘散'), ('martyr', u'殉道者', u'轻', u'甩出链子香炉', u'冲击', u'特效：化作圣光，附近友军获得光环'), ('stone_giant', u'石巨人（融合）', u'重', u'一步一震走近，双拳锤扁', u'压扁（新）', u'攻击时对手被锤成饼；自己被吃时崩掉一块但还站着（每场要吃 3 次）'), ('blast_catapult', u'爆破投石车（融合）', u'重', u'原地抛出火药桶', u'爆破（新）', u'目标和周围一圈的敌人一起炸碎'), ('sky_archer', u'天鹰射手（融合）', u'中', u'射箭上天，金鹰从天而降', u'贯穿（新）', u'被钉在地上，裂成左右两半'), ('flame_phoenix', u'炎凰（融合）', u'中', u'火翼滑翔穿身而过', u'火柱（新）', u'攻击时对手被火柱焚尽；自己被吃时化作火球飞回底线角落，1 回合后重生'), ('thousand_faces', u'千面者（融合）', u'中', u'变身闪烁，化作对手的镜像', u'夺形（新）', u'样子被抽走，只剩灰色空壳碎成粉尘')]
tr = u''.join(u'\n          <tr data-k="%s"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>' % r for r in rows)
t0 = s.index(u'<section class="rules">'); t1 = s.index(u'</section>', t0) + len(u'</section>')
s = s[:t0] + u'''<section class="rules">
    <h2>新棋子一览</h2>
    <div class="table-wrap">
      <table id="specTable">
        <thead><tr><th>棋子</th><th>体型</th><th>攻击</th><th>打击类型</th><th>受击</th></tr></thead>
        <tbody>''' + tr + u'''
        </tbody>
      </table>
    </div>
    <p>“按规则表”表示沿用已确认的“打击类型 × 受击方体型”受击效果。标“特效”的 7 个棋子，不论被谁吃，都优先播放自己的受击特效。规则草案还没定稿，动画会随最终规则微调。</p>
  </section>''' + s[t1:]

rep(u"  let atkKey = 'gryphon', vicKey = 'bowman', speed = 1, variant = 'line';", u"  let atkKey = 'courier', vicKey = 'knight', speed = 1, variant = 'line';")
rep(u"  function pickReact() {\n    const atk = A(), wv = WEIGHT[vicKey], wa = WEIGHT[atkKey];\n",
    blk + u"\n  function pickReact() {\n    const atk = A(), wv = WEIGHT[vicKey], wa = WEIGHT[atkKey];\n    if (VICTIM_REACT[vicKey]) return VICTIM_REACT[vicKey]();\n")
rep(u"    if (u > atk.end) { endHold += dt; if (endHold > 1.0) reset(); }", u"    if (u > Math.max(atk.end, atk.impact + (RX.hold || 0) + .8)) { endHold += dt; if (endHold > 1.0) reset(); }")
rep(u"    const u = t - PRE, o = atk.pose(u), b = G.b, imp = project(b.X, 8, b.Z);", u"""    const u = t - PRE, o = atk.pose(u), b = G.b, imp = project(b.X, 8, b.Z);
    if (impacted && RX.repel) { const p0 = atk.pose(atk.impact), k = smooth(clamp01((rt - .3) / .45)); Object.assign(o, p0); o.X = lerp(p0.X, G.a.X, k); o.Z = lerp(p0.Z, G.a.Z, k); o.Y = lerp(p0.Y, 0, k) + V.cell * .5 * Math.sin(k * Math.PI); o.rot = p0.rot * (1 - k); o.trail = false; o.white = 0; }
    if (R.attackerGone) o.alpha = 0;
    curPose = o;""")
rep(u"const statics = STATIC.filter(s => !(s.t === 'king' && ((s.s === 'w' && atkKey === 'king') || (s.s === 'k' && vicKey === 'king'))))",
    u"const statics = STATIC.filter(s => !(s.t === 'king' && ((s.s === 'w' && KINGS.has(atkKey)) || (s.s === 'k' && KINGS.has(vicKey)))))")
rep(u"""      for (const bd of bodies) {
        if (bd.Y > pxToY(2)) shadow(bd.X + bd.ox, bd.Z, bd.Y, 9);""", u"""      if (RX.after) RX.after();
      for (const bd of bodies) {
        if (bd.Y > pxToY(2)) shadow(bd.X + bd.ox, bd.Z, bd.Y, 9);""")
rep(u"statics.sort((a, c) => a.w.Z - c.w.Z).forEach(({ s, w }) => { ctx.globalAlpha = 1 - .62 * focus; shadow(w.X, w.Z, 0, 10); drawSprite(S[s.t + s.s], w.X, 0, w.Z); ctx.globalAlpha = 1; });",
    u"statics.sort((a, c) => a.w.Z - c.w.Z).forEach(({ s, w }) => { ctx.globalAlpha = 1 - .62 * focus; shadow(w.X, w.Z, 0, 10); drawSprite(S[s.t + s.s], w.X, 0, w.Z); ctx.globalAlpha = 1;\n        if (RX.halo && R.split && s.s === 'k' && Math.hypot(w.X - b.X, w.Z - b.Z) <= V.cell * 2.3) { const k = clamp01((rt - RX.split) / .3), p = project(w.X, pxToY(S[s.t + s.s].h + 3), w.Z); ctx.strokeStyle = `rgba(255,226,150,${k * (.7 + .3 * Math.sin(rt * 8))})`; ctx.lineWidth = 1; ctx.beginPath(); ctx.ellipse(Math.round(p.x), Math.round(p.y), 5, 2, 0, 0, Math.PI * 2); ctx.stroke(); } });")
rep(u"const NEW_HITS = new Set(['portal', 'grab', 'poison', 'arcane', 'petrify']);", u"const NEW_HITS = new Set(['portal', 'grab', 'poison', 'arcane', 'petrify', 'swallow', 'radiance', 'resonance', 'burn', 'erupt', 'toss']);")
rep(u"      <dt>受击</dt><dd>${rx.desc}</dd>${under}</dl>`;", u"      <dt>受击</dt><dd>${VICTIM_REACT[vicKey] ? '<span class=\"chip new\">' + VNAME[vicKey] + '被吃时的特效</span>' : ''}${rx.desc}</dd>${under}</dl>`;")
io.open('../new_pieces.html', 'w', encoding='utf-8').write(s)
js = s[s.index(u'<script>') + 8:s.rindex(u'</script>')]
pass
print('ok')
