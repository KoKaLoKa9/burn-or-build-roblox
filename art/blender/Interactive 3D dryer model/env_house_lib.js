// Pack 2: Thai village houses + shared lived-in props.
import { THREE, V3, TAU, DEG, YUP, DS, rnd, rr, pick, clamp, lerp, cv, field, pbr, simpleSet, lib, makeNoise, blotch, specks, add, sub, pipe, beam, boxG, bboxG, cylG, alongX, alongZ, revolve, tubeG, curve, cardG, makeAsset, v3, frustumG } from './env_common.js';
import { FM } from './env_flora_lib.js';

/* ---------- house-specific materials ---------- */
const HM = {
  dark: simpleSet('EV_InteriorDark', 0x1d1b18, { rough: .95, dirt: false, bump: 10 }),
  alu: simpleSet('EV_AluminiumFrame', 0xb6b9bb, { rough: .35, metal: true, dirt: .08 }),
  meter: simpleSet('EV_MeterBox', 0x9aa09e, { rough: .5 }),
  shutter: (() => { const S = 512, c = field(S, S, (u, v, o) => { const rib = Math.sin(u * TAU * 16); const g = 118 + rib * 14; o[0] = g * .92; o[1] = g; o[2] = g * 1.04; }); const x = c.getContext('2d'); for (let i = 0; i < 18; i++) { const px = rnd() * S, L = rr(80, 400), g = x.createLinearGradient(0, 0, 0, L); g.addColorStop(0, 'rgba(126,62,24,.6)'); g.addColorStop(1, 'rgba(126,62,24,0)'); x.fillStyle = g; x.fillRect(px, rnd() * 100, rr(3, 8), L); }
    const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 128 + Math.sin(u * TAU * 16) * 100; }); return pbr('EV_ShutterSteel', { color: c, height: h, k: 2, roughBase: .5, roughAmp: .2, metal: true, uv: .5 }); })(),
  fridge: simpleSet('EV_FridgeBody', 0xc0392d, { rough: .35, dirt: .1 }),
  white: lib.whitePaint, red: lib.redPaint, gold: lib.gold,
  sack: simpleSet('EV_RiceSack', 0xd8d0b8, { rough: .92, bump: 90 }),
  bottleA: simpleSet('EV_BottleGreen', 0x2f7a3a, { rough: .2, dirt: false }), bottleB: simpleSet('EV_BottleAmber', 0x8a4a14, { rough: .2, dirt: false }), bottleC: simpleSet('EV_BottleClear', 0xcfd6d8, { rough: .15, dirt: false }),
  boxA: simpleSet('EV_GoodsBoxA', 0xd9a23a, { rough: .7 }), boxB: simpleSet('EV_GoodsBoxB', 0x3a6ea8, { rough: .7 }), boxC: simpleSet('EV_GoodsBoxC', 0xc8473a, { rough: .7 }),
  sign: (() => { const W = 1024, H = 256, c = cv(W, H), x = c.getContext('2d'); const g = x.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#1f5e9a'); g.addColorStop(1, '#174a7a'); x.fillStyle = g; x.fillRect(0, 0, W, H);
    x.strokeStyle = '#f3d23a'; x.lineWidth = 10; x.strokeRect(12, 12, W - 24, H - 24); x.fillStyle = '#ffffff'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '700 130px "IBM Plex Sans Condensed", sans-serif'; x.fillText('ร้านค้า', W * .36, H * .5);
    x.fillStyle = '#f3d23a'; x.font = '600 44px "IBM Plex Sans Condensed", sans-serif'; x.fillText('ของชำ · ข้าวสาร', W * .76, H * .38); x.fillText('เครื่องดื่มเย็น', W * .76, H * .66);
    blotch(x, W, H, 12, [120, 120, 110], 40, 140, .18); for (let i = 0; i < 20; i++) { const px = rnd() * W, L = rr(40, 160), gg = x.createLinearGradient(0, 0, 0, L); gg.addColorStop(0, 'rgba(110,60,30,.5)'); gg.addColorStop(1, 'rgba(110,60,30,0)'); x.fillStyle = gg; x.fillRect(px, H - L, 3, L); }
    const h = field(256, 64, (u, v, o) => { o[0] = o[1] = o[2] = 128; }); const hh = cv(W, H); hh.getContext('2d').drawImage(h, 0, 0, W, H); return pbr('EV_ShopSign', { color: c, height: hh, k: .5, roughBase: .45, roughAmp: .05, rep: false }); })(),
  fridgeSign: (() => { const W = 512, H = 128, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#f4f4f0'; x.fillRect(0, 0, W, H); x.fillStyle = '#c0392d'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '700 64px "IBM Plex Sans Condensed", sans-serif'; x.fillText('เย็นฉ่ำ', W / 2, H / 2 + 4);
    const hh = cv(W, H); hh.getContext('2d').fillStyle = '#808080'; hh.getContext('2d').fillRect(0, 0, W, H); return pbr('EV_FridgeSign', { color: c, height: hh, k: .5, roughBase: .4, roughAmp: .05, rep: false }); })(),
};

/* ---------- building helpers ---------- */
/** Wall spanning a0..a1 (along X if axis 'x', else Z) at plane coordinate p, height y0..y1, thickness t; holes [a0,a1,y0,y1]. */
function wall(g, m, axis, p, a0, a1, y0, y1, t, holes = []) {
  holes = [...holes].sort((a, b) => a[0] - b[0]); let c = a0;
  const pc = (xa, xb, ya, yb) => { if (xb - xa < 1e-3 || yb - ya < 1e-3) return; const ca = (xa + xb) / 2, cy = (ya + yb) / 2; if (axis === 'x') add(g, boxG(xb - xa, yb - ya, t), m, [ca, cy, p]); else add(g, boxG(t, yb - ya, xb - xa), m, [p, cy, ca]); };
  for (const [xa, xb, ya, yb] of holes) { pc(c, xa, y0, y1); pc(xa, xb, y0, ya); pc(xa, xb, yb, y1); c = xb; } pc(c, a1, y0, y1);
}
/** Local frame for an opening: origin at opening centre on the wall's outer face, local -Z = outward. */
const frameAt = (g, pos, outward) => { const ry = { '-z': 0, '+z': Math.PI, '-x': Math.PI / 2, '+x': -Math.PI / 2 }[outward]; return sub(g, pos, [0, ry, 0]); };
function louvreWindow(P, pos, outward, w, h, wallT) {
  const s = frameAt(P('Structure'), pos, outward), d = frameAt(P('Interior'), pos, outward), wood = lib.teak;
  add(d, boxG(w, h, .02), HM.dark, [0, 0, wallT + .2]);
  for (const sx of [-1, 1]) add(s, boxG(.12, h + .24, wallT + .1), wood, [sx * (w / 2 + .06), 0, wallT / 2 - .05]);
  for (const sy of [-1, 1]) add(s, boxG(w + .36, .14, wallT + .16), wood, [0, sy * (h / 2 + .07), wallT / 2 - .08]);
  add(s, boxG(w + .5, .08, .3), wood, [0, -h / 2 - .17, -.12]);
  const n = Math.floor(h / .22); for (let i = 0; i < n; i++) add(s, boxG(w, .2, .025), wood, [0, -h / 2 + .11 + i * (h - .1) / n, wallT * .5], [.6, 0, 0]);
  for (const sx of [-1, 1]) { const sh = sub(s, [sx * w / 2, 0, -.06], [0, sx * -1.65, 0]); add(sh, boxG(w / 2, h, .06), wood, [sx * w / 4, 0, 0]); for (let i = 1; i < 5; i++) add(sh, boxG(w / 2 - .12, .04, .03), wood, [sx * w / 4, -h / 2 + i * h / 5, -.04]); }
}
function slidingWindow(P, pos, outward, w, h, wallT) {
  const s = frameAt(P('Structure'), pos, outward), gl = frameAt(P('Glass'), pos, outward), ct = frameAt(P('Curtains_Tint'), pos, outward), d = frameAt(P('Interior'), pos, outward);
  add(d, boxG(w, h, .02), HM.dark, [0, 0, wallT + .4]);
  add(ct, boxG(w * .55, h * .95, .03), lib.fabricTint, [-w * .2, 0, wallT + .3]);
  for (const sx of [-1, 1]) add(s, boxG(.1, h, wallT), HM.alu, [sx * (w / 2 - .05), 0, wallT / 2]);
  for (const sy of [-1, 1]) add(s, boxG(w, .1, wallT), HM.alu, [0, sy * (h / 2 - .05), wallT / 2]);
  for (const k of [0, 1]) { const x = (k ? 1 : -1) * w * .22, z = wallT / 2 + (k ? .05 : -.05); add(gl, boxG(w * .52, h - .2, .02), lib.glass, [x, 0, z]); add(s, boxG(.06, h - .2, .05), HM.alu, [x + w * .26 * (k ? 1 : -1), 0, z]); add(s, boxG(.06, h - .2, .05), HM.alu, [x - w * .26 * (k ? 1 : -1), 0, z]); }
  add(s, boxG(w + .3, .1, .35), lib.concrete, [0, -h / 2 - .05, -.12]);
  const nb = Math.round(w / .3); for (let i = 1; i < nb; i++) add(s, boxG(.035, h, .035), lib.darkSteel, [-w / 2 + i * w / nb, 0, -.12]);
  for (const y of [-h / 2 + .05, 0, h / 2 - .05]) add(s, boxG(w, .05, .04), lib.darkSteel, [0, y, -.12]);
  for (const sy of [-1, 1]) for (const sx of [-1, 1]) add(s, boxG(.05, .05, .12), lib.darkSteel, [sx * (w / 2 - .02), sy * (h / 2 - .02), -.06]);
}
function plainShutterWindow(P, pos, outward, w, h, wallT) {
  const s = frameAt(P('Structure'), pos, outward), d = frameAt(P('Interior'), pos, outward); add(d, boxG(w, h, .02), HM.dark, [0, 0, wallT + .25]);
  for (const sx of [-1, 1]) add(s, boxG(.1, h + .2, wallT + .08), lib.woodRough, [sx * (w / 2 + .05), 0, wallT / 2 - .04]); for (const sy of [-1, 1]) add(s, boxG(w + .3, .1, wallT + .08), lib.woodRough, [0, sy * (h / 2 + .05), wallT / 2 - .04]);
  for (const sx of [-1, 1]) { const sh = sub(s, [sx * w / 2, 0, -.05], [0, sx * -1.8, 0]); add(sh, boxG(w / 2, h, .07), lib.woodRough, [sx * w / 4, 0, 0]); add(sh, boxG(w / 2 - .1, .06, .03), lib.woodRough, [sx * w / 4, h * .3, -.05]); add(sh, boxG(w / 2 - .1, .06, .03), lib.woodRough, [sx * w / 4, -h * .3, -.05]); }
}
function door(P, pos, outward, w, h, wallT, kind = 'teak') {
  const s = frameAt(P('Structure'), pos, outward), d = frameAt(P('Interior'), pos, outward), m = kind === 'plank' ? lib.woodRough : lib.teak;
  add(d, boxG(w, h, .02), HM.dark, [0, h / 2, wallT + .5]);
  for (const sx of [-1, 1]) add(s, boxG(.14, h + .14, wallT + .1), m, [sx * (w / 2 + .07), h / 2 + .07, wallT / 2 - .05]); add(s, boxG(w + .42, .16, wallT + .14), m, [0, h + .08, wallT / 2 - .07]);
  const leaf = (sx, open) => { const l = sub(s, [sx * w / 2, 0, wallT * .3], [0, sx * open, 0]); add(l, boxG(w / 2, h, .1), m, [-sx * w / 4, h / 2, 0]); for (const y of [h * .25, h * .72]) add(l, boxG(w / 2 - .2, h * .3, .03), m, [-sx * w / 4, y, -.06]); add(l, boxG(.04, .25, .06), lib.chrome, [-sx * (w / 2 - .12), h * .5, -.1]); };
  leaf(-1, 1.2); leaf(1, -.35);
}
function steps(g, m, x, z0, dz, w, rise, n, y0 = 0) { for (let i = 0; i < n; i++) add(g, boxG(w, rise * (i + 1), Math.abs(dz)), m, [x, y0 + rise * (i + 1) / 2, z0 + dz * (n - 1 - i) + dz / 2]); }
/** Gable roof with ridge along X; slab thickness t, roof material m (tintable). */
function gableX(g, m, x0, x1, zc, half, ridgeY, eaveY, t = .22, capM = m) { const L = Math.hypot(half, ridgeY - eaveY), a = Math.atan2(ridgeY - eaveY, half);
  for (const s of [-1, 1]) add(g, boxG(x1 - x0, t, L + .05), m, [(x0 + x1) / 2, (ridgeY + eaveY) / 2 + t / 2, zc + s * half / 2], [s * a, 0, 0]);
  add(g, alongXg(cylG(.22, .22, x1 - x0 - .1, 8, false, 0, Math.PI)), capM, [(x0 + x1) / 2, ridgeY + t * .9, zc]); }
const alongXg = gg => gg.rotateZ(Math.PI / 2);
function gableEnd(g, m, x, z0, z1, yBase, yApex, t) { const s = new THREE.Shape(); s.moveTo(z0, yBase); s.lineTo(z1, yBase); s.lineTo((z0 + z1) / 2, yApex); s.closePath(); const e = new THREE.ExtrudeGeometry(s, { depth: t, bevelEnabled: false }); e.rotateY(-Math.PI / 2); e.translate(x + t / 2, 0, 0); add(g, e, m); }
function sag(a, b, drop, n = 10) { a = v3(a); b = v3(b); const pts = []; for (let i = 0; i < n; i++) { const t = i / (n - 1); pts.push(a.clone().lerp(b, t).add(new V3(0, -drop * 4 * t * (1 - t), 0))); } return pts; }
const wire = (g, a, b, drop, r = .025) => add(g, tubeG(sag(a, b, drop, 12), Array(12).fill(r), 4, { uRep: 1 }), lib.rubber);

/* ---------- props ---------- */
export function waterJar(g, pos, s = 1) { add(g, revolve([[0, 0], [.55 * s, .02], [.95 * s, .6 * s], [1.05 * s, 1.3 * s], [.85 * s, 2.0 * s], [.5 * s, 2.35 * s], [.55 * s, 2.45 * s], [.47 * s, 2.45 * s], [.44 * s, 2.3 * s]], 20), lib.ceramic, pos);
  add(g, revolve([[.62 * s, 0], [.3 * s, .22 * s], [0, .3 * s]], 16), lib.steel, [pos[0], pos[1] + 2.45 * s, pos[2]]);
  for (let i = 0; i < 2; i++) add(g, new THREE.TorusGeometry((1.0 - i * .1) * s, .03 * s, 4, 20).rotateX(Math.PI / 2), lib.gold, [pos[0], pos[1] + (1.1 + i * .55) * s, pos[2]]); }
export function pottedPlant(g, pos, s = 1) { add(g, revolve([[0, 0], [.32 * s, 0], [.45 * s, .75 * s], [.5 * s, .8 * s], [.42 * s, .8 * s], [.4 * s, .7 * s], [0, .7 * s]], 14), lib.terracotta, pos);
  for (let i = 0; i < 7; i++) { const a = i / 7 * TAU + rr(-.3, .3), m = new THREE.Mesh(new THREE.PlaneGeometry(.9 * s, .9 * s), FM.bushLeaf); m.position.set(pos[0] + Math.cos(a) * .2 * s, pos[1] + (1.05 + rr(-.1, .25)) * s, pos[2] + Math.sin(a) * .2 * s); m.lookAt(m.position.x + Math.cos(a), m.position.y + .9, m.position.z + Math.sin(a)); g.add(m); } }
export function plasticChair(g, pos, ry = 0) { const s = sub(g, pos, [0, ry, 0]), m = lib.plasticTint;
  add(s, boxG(1.45, .1, 1.4), m, [0, 1.55, 0]); const bk = add(s, boxG(1.4, 1.5, .08), m, [0, 2.35, .7]); bk.rotation.x = -.15;
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) { const l = add(s, cylG(.06, .09, 1.55, 6), m, [sx * .62, .76, sz * .6]); l.rotation.z = sx * .08; l.rotation.x = -sz * .08; }
  for (const sx of [-1, 1]) add(s, boxG(.1, .08, 1.2), m, [sx * .72, 2.1, .05]); }
export function plasticTable(g, pos) { const s = sub(g, pos), m = lib.plasticTint; add(s, cylG(1.3, 1.3, .08, 20), m, [0, 2.45, 0]); for (let i = 0; i < 4; i++) { const a = i / 4 * TAU + Math.PI / 4; const l = add(s, cylG(.07, .1, 2.4, 6), m, [Math.cos(a) * .75, 1.2, Math.sin(a) * .75]); l.rotation.set(Math.sin(a) * .15, 0, -Math.cos(a) * .15); } }
function wheel(g, tm, hm, pos, r, w, axis = 'x') { const tg = new THREE.TorusGeometry(r, w, 6, 22), hg = cylG(r * .55, r * .55, w * 1.2, 12); if (axis === 'x') { tg.rotateY(Math.PI / 2); alongX(hg); } else alongZ(hg); add(g, tg, tm, pos); add(g, hg, hm, pos); }
export function motorbike(P, pos, ry = 0) { const s = sub(P('Motorbike'), pos, [0, ry, 0]), bt = sub(P('Motorbike_Tint'), pos, [0, ry, 0]);
  // local: length along Z (front at -Z), wheel radius .9 (17" scooter at 1 stud ≈ .28 m)
  wheel(s, lib.rubber, lib.chrome, [0, .9, -2.3], .78, .2, 'x'); wheel(s, lib.rubber, lib.chrome, [0, .9, 2.2], .78, .2, 'x');
  pipe(s, lib.darkSteel, [0, .9, -2.3], [0, 3.3, -1.55], .09, 8); for (const sx of [-1, 1]) pipe(s, lib.chrome, [sx * .16, .95, -2.3], [sx * .16, 2.6, -1.85], .06, 6);
  add(bt, bboxG(.9, 1.6, .9, .2), lib.plasticTint, [0, 2.75, -1.55], [-.35, 0, 0]); add(bt, bboxG(1.0, .5, 1.3, .2), lib.plasticTint, [0, 2.0, -2.25], [.2, 0, 0]);
  add(bt, bboxG(1.15, 1.1, 2.8, .3), lib.plasticTint, [0, 2.05, 1.3]); add(bt, bboxG(.7, .45, 1.6, .15), lib.plasticTint, [0, 1.25, -.2]);
  add(s, bboxG(1.0, .25, 2.2, .1), lib.black, [0, 2.7, 1.2]); add(s, bboxG(.7, .3, .7, .08), lib.darkSteel, [0, 1.3, 1.8]);
  pipe(s, lib.chrome, [-.95, 3.45, -1.5], [.95, 3.45, -1.5], .06, 6); for (const sx of [-1, 1]) { add(s, cylG(.07, .07, .4, 6), lib.black, [sx * 1.05, 3.45, -1.5], [0, 0, Math.PI / 2]); pipe(s, lib.chrome, [sx * .5, 3.45, -1.5], [sx * .7, 4.1, -1.6], .025, 4); add(s, cylG(.18, .18, .05, 10), lib.black, [sx * .72, 4.15, -1.6], [Math.PI / 2, 0, 0]); }
  add(s, cylG(.25, .3, .2, 12), lib.glass, [0, 3.0, -2.05], [Math.PI / 2 - .3, 0, 0]); add(s, boxG(.5, .2, .1), lib.redPaint, [0, 2.3, 2.75]);
  pipe(s, lib.chrome, [.35, 1.0, .9], [.35, 1.05, 2.9], .1, 8); pipe(s, lib.darkSteel, [-.25, .6, .8], [-.6, .1, 1.1], .04, 4); }
export function bicycle(g, pos, ry = 0) { const s = sub(g, pos, [0, ry, 0]), fm = lib.darkSteel;
  wheel(s, lib.rubber, lib.chrome, [0, 1.25, -1.9], 1.2, .06, 'x'); wheel(s, lib.rubber, lib.chrome, [0, 1.25, 1.75], 1.2, .06, 'x');
  for (const sp of [-1.9, 1.75]) for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI; pipe(s, lib.chrome, [0, 1.25 + Math.cos(a) * 1.15, sp + Math.sin(a) * 1.15], [0, 1.25 - Math.cos(a) * 1.15, sp - Math.sin(a) * 1.15], .012, 3); }
  const B = [0, 1.3, -.1], S0 = [0, 3.0, .6], H0 = [0, 3.1, -1.4]; pipe(s, fm, B, S0, .06, 6); pipe(s, fm, B, H0, .06, 6); pipe(s, fm, S0, H0, .05, 6); pipe(s, fm, B, [0, 1.25, 1.75], .04, 6); pipe(s, fm, S0, [0, 1.25, 1.75], .04, 6); pipe(s, fm, H0, [0, 1.25, -1.9], .05, 6);
  pipe(s, fm, S0, [0, 3.45, .75], .04, 6); add(s, bboxG(.45, .14, .8, .05), lib.black, [0, 3.5, .75]); pipe(s, lib.chrome, [-.7, 3.6, -1.5], [.7, 3.6, -1.5], .04, 6); pipe(s, fm, H0, [0, 3.6, -1.5], .05, 6);
  add(s, boxG(1.0, .55, .8), lib.woodRough, [0, 3.2, -2.05]); add(s, cylG(.35, .35, .08, 12), lib.chrome, B, [0, 0, Math.PI / 2]); }
export function laundry(P, a, b, n = 6) { const ln = sag(a, b, .25, 12); add(P('Props'), tubeG(ln, Array(12).fill(.02), 4, { uRep: 1 }), lib.rubber);
  for (let i = 0; i < n; i++) { const t = (i + .5) / n, p = ln[Math.floor(t * 11)], w = rr(.9, 1.5), h = rr(1.1, 2.0), dir = v3(b).sub(v3(a)).normalize(); const m = new THREE.Mesh(cardG(w, h, rr(-.1, .1), 2), lib.fabricTint); m.position.copy(p).add(new V3(0, -h, 0)); m.rotation.y = Math.atan2(dir.x, dir.z) + Math.PI / 2; P('Laundry_Tint').add(m); } }
export function spiritHouse(g, pos, ry = 0) { const s = sub(g, pos, [0, ry, 0]), W = HM.white, R = HM.red, G = HM.gold;
  add(s, boxG(1.3, .25, 1.3), lib.concrete, [0, .125, 0]); add(s, boxG(.5, 3.6, .5), W, [0, 2.05, 0]); add(s, boxG(2.4, .18, 2.4), W, [0, 3.9, 0]);
  for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; add(s, cylG(.04, .04, .35, 5), G, [Math.cos(a) * 1.1, 4.15, Math.sin(a) * 1.1]); } add(s, new THREE.TorusGeometry(1.1 * Math.SQRT2, .03, 3, 4).rotateX(Math.PI / 2).rotateY(Math.PI / 4), G, [0, 4.32, 0]);
  add(s, boxG(1.4, 1.3, 1.1), W, [0, 4.65, .1]); add(s, boxG(.5, .8, .05), G, [0, 4.55, -.47]); for (const sx of [-1, 1]) { add(s, cylG(.07, .07, 1.4, 6), G, [sx * .62, 4.7, -.5]); add(s, cylG(.07, .07, 1.4, 6), R, [sx * .62, 4.7, .62]); }
  for (let k = 0; k < 2; k++) { const y = 5.35 + k * .75, sc = 1 - k * .3; gableX(s, k ? G : R, -.95 * sc, .95 * sc, .05, .85 * sc, y + .7 * sc, y, .06, G); for (const sx of [-1, 1]) add(s, tubeG(curve([[sx * .97 * sc, y + .7 * sc, .05], [sx * 1.08 * sc, y + .95 * sc, .05], [sx * .98 * sc, y + 1.15 * sc, -.05]], 5), [.05, .04, .03, .02, .01], 4, { uRep: 1 }), G); }
  add(s, cylG(.02, .09, .6, 8), G, [0, 7.0, .05]);
  for (const sx of [-1, 1]) { add(s, cylG(.08, .1, .3, 8), G, [sx * .7, 4.14, -.95]); add(s, new THREE.SphereGeometry(.07, 6, 4), R, [sx * .7, 4.33, -.95]); }
  add(s, cylG(.05, .05, .3, 6), lib.chrome, [.2, 4.14, -.85]); for (let i = 0; i < 3; i++) add(s, cylG(.008, .008, .5, 3), lib.woodRough, [-.15 + i * .04, 4.3, -.8]);
  add(s, new THREE.TorusGeometry(.32, .05, 4, 14), G, [0, 4.0, -1.22]); }
export function meter(g, pos, outward = '-z') { const s = frameAt(g, pos, outward); add(s, bboxG(.7, 1.0, .35, .04), HM.meter, [0, 0, -.18]); add(s, cylG(.18, .18, .04, 14), lib.glass, [0, .12, -.37], [Math.PI / 2, 0, 0]); add(s, boxG(.3, .12, .05), lib.black, [0, -.28, -.37]); return s; }
export function dish(g, pos, ry = 0, tilt = .7, sc = 1) { const s = sub(g, pos, [0, ry, 0]); s.scale.setScalar(sc); add(s, boxG(.12, .12, .9), lib.steel, [0, 0, -.45]); const d = sub(s, [0, .2, -.95], [tilt, 0, 0]);
  add(d, revolve([[0, 0], [.4, .03], [.8, .13], [1.0, .22], [1.02, .23], [.8, .15], [.4, .05], [0, .02]], 20).rotateX(-Math.PI / 2), HM.white); pipe(d, lib.steel, [0, -.7, -.15], [0, -.05, -1.05], .03, 4); add(d, cylG(.08, .1, .25, 8), lib.black, [0, -.05, -1.1], [Math.PI / 2, 0, 0]); }

/* ---------- houses ---------- */
export function stiltHouse() {
  return makeAsset('EV_StiltHouse_A', 2101, P => {
    const st = P('Structure'), rf = P('Roof_Tint'), pr = P('Props'), fy = 6.0, wt = .16, wy0 = 6.15, wy1 = 11.5, zF = -3.5, zB = 7.3, xL = -10.4, xR = 10.4;
    const cols = [-10.2, -5.1, 0, 5.1, 10.2], rows = [-7.3, -3.5, 2.0, 7.3];
    for (const x of cols) for (const z of rows) { add(st, boxG(.55, fy, .55), lib.teak, [x, fy / 2, z]); add(st, boxG(1.0, .3, 1.0), lib.concrete, [x, .15, z]); }
    for (const z of rows) add(st, boxG(21.2, .35, .42), lib.teak, [0, fy - .17, z]); for (const x of cols) add(st, boxG(.35, .3, 15.2), lib.teak, [x, fy - .5, 0]);
    add(st, boxG(21.2, .15, 15.2), lib.teak, [0, fy + .075, 0]);
    // walls (teak boards) with openings
    const fwH = [[-7.0, -5.4, 7.4, 9.6], [-1.0, 1.0, wy0, 10.1], [3.6, 5.2, 7.4, 9.6], [7.0, 8.6, 7.4, 9.6]], bwH = [-7.5, -2.5, 2.5, 7.5].map(c => [c - .8, c + .8, 7.4, 9.6]), swH = [.2, 4.4].map(c => [c - .8, c + .8, 7.4, 9.6]);
    wall(st, lib.teak, 'x', zF, xL, xR, wy0, wy1, wt, fwH); wall(st, lib.teak, 'x', zB, xL, xR, wy0, wy1, wt, bwH); wall(st, lib.teak, 'z', xL, zF, zB, wy0, wy1, wt, swH); wall(st, lib.teak, 'z', xR, zF, zB, wy0, wy1, wt, swH);
    for (const [a, b] of [fwH[0], fwH[2], fwH[3]].map(h => [h[0], h[1]])) louvreWindow(P, [(a + b) / 2, 8.5, zF - wt / 2], '-z', b - a, 2.2, wt);
    for (const h of bwH) louvreWindow(P, [(h[0] + h[1]) / 2, 8.5, zB + wt / 2], '+z', 1.6, 2.2, wt);
    for (const h of swH) { louvreWindow(P, [xL - wt / 2, 8.5, (h[0] + h[1]) / 2], '-x', 1.6, 2.2, wt); louvreWindow(P, [xR + wt / 2, 8.5, (h[0] + h[1]) / 2], '+x', 1.6, 2.2, wt); }
    door(P, [0, wy0, zF - wt / 2], '-z', 2.0, 3.95, wt);
    for (const x of [xL, xR]) for (const z of [zF, zB]) add(st, boxG(.4, wy1 - wy0, .4), lib.teak, [x, (wy0 + wy1) / 2, z]);
    add(st, boxG(21.2, .3, .3), lib.teak, [0, wy1 + .1, zF]); add(st, boxG(21.2, .3, .3), lib.teak, [0, wy1 + .1, zB]);
    // main roof: steep gable, ridge along X
    const zc = (zF + zB) / 2, half = 6.3, ridgeY = wy1 + (zB - zF) / 2 + .02, eaveY = ridgeY - half;
    gableX(rf, lib.tile, -11.8, 11.8, zc, half, ridgeY, eaveY, .25);
    for (const x of [xL, xR]) gableEnd(st, lib.teak, x, zF, zB, wy1, wy1 + (zB - zF) / 2, wt);
    for (const sx of [-1, 1]) { for (const s of [-1, 1]) beam(st, lib.teak, [sx * 11.82, ridgeY + .2, zc], [sx * 11.82, eaveY + .15, zc + s * half], .1, .3);
      add(st, tubeG(curve([[sx * 11.8, ridgeY + .25, zc], [sx * 11.8, ridgeY + .7, zc - .15], [sx * 11.8, ridgeY + .92, zc - .55]], 6), [.12, .1, .08, .06, .04, .02], 5, { uRep: 1 }), lib.teak);
      for (const s of [-1, 1]) add(st, tubeG(curve([[sx * 11.8, eaveY + .15, zc + s * half], [sx * 11.8, eaveY + .45, zc + s * (half + .2)], [sx * 11.8, eaveY + .7, zc + s * (half + .15)]], 5), [.08, .07, .05, .03, .02], 4, { uRep: 1 }), lib.teak); }
    // veranda: lean-to roof, posts, balustrade, stair along the front
    for (const x of cols) add(st, boxG(.35, 3.5, .35), lib.teak, [x, wy0 + 1.75, -7.3]); add(st, boxG(21.2, .25, .3), lib.teak, [0, wy0 + 3.5, -7.3]);
    const vr = add(rf, boxG(21.2, .16, 4.3), lib.tile, [0, 9.9, -6.2]); vr.rotation.x = -.24;
    for (let x = -10.2; x < 8.4; x += .5) add(st, boxG(.08, .9, .08), lib.teak, [x, wy0 + .5, -7.42]); add(st, boxG(18.6, .12, .16), lib.teak, [-.9, wy0 + 1.0, -7.42]);
    const sw = 1.5, sz = -8.4, nst = 8, rise = fy / nst; for (let i = 0; i < nst; i++) add(st, boxG(.95, .1, sw), lib.teak, [9.6 - i * .95 - .47, fy - i * rise - rise + .05, sz]);
    for (const zz of [sz - sw / 2, sz + sw / 2]) beam(st, lib.teak, [10.1, fy, zz], [1.8, 0, zz], .12, .35);
    for (const x of [9.6, 5.8, 2.2]) add(st, boxG(.1, 1.0, .1), lib.teak, [x, fy - (9.6 - x) / .95 * rise + .4, sz - sw / 2]); beam(st, lib.teak, [9.6, fy + 1.0, sz - sw / 2], [2.2, 1.6, sz - sw / 2], .08, .1);
    // under the house: bench, hammock, jars, motorbike, chairs, laundry
    add(pr, boxG(4.2, .15, 2.4), lib.teak, [-6.0, 1.35, 4.6]); for (const sx of [-1, 1]) for (const sz2 of [-1, 1]) add(pr, boxG(.18, 1.3, .18), lib.teak, [-6.0 + sx * 1.9, .65, 4.6 + sz2 * 1.0]); add(pr, boxG(1.6, .02, 1.2), FM.mat, [-6.4, 1.44, 4.6]);
    const hp = []; for (let i = 0; i <= 12; i++) { const t = i / 12; hp.push(new V3(lerp(.3, 4.8, t), 3.9 - Math.sin(Math.PI * t) * 1.2, 2.0)); } add(pr, ribbon(hp, .7), FM.hammock); for (const e of [hp[0], hp[12]]) pipe(pr, lib.rubber, e, [e.x < 2 ? 0 : 5.1, 4.6, 2.0], .02, 4);
    waterJar(pr, [8.8, 0, 6.2], 1); waterJar(pr, [7.0, 0, 6.6], .85); pottedPlant(pr, [9.0, fy + .15, -6.6]); pottedPlant(pr, [-9.5, fy + .15, -6.6]); pottedPlant(pr, [1.2, 0, -8.3], 1.1); pottedPlant(pr, [-1.0, 0, -6.0], 1.2);
    motorbike(P, [3.2, 0, -1.4], .3); plasticChair(P('Chairs_Tint'), [-3.6, 0, 3.5], 2.6); plasticChair(P('Chairs_Tint'), [-8.6, 0, 2.0], -1.3);
    laundry(P, [-10.2, 4.3, 7.3], [-5.1, 4.3, 7.3], 5);
    spiritHouse(pr, [-7.8, 0, -8.25]);
    meter(pr, [10.2, 4.2, -7.58], '-z'); pipe(pr, lib.rubber, [10.2, 4.7, -7.6], [10.2, 6.0, -7.6], .03, 4); wire(pr, [10.2, 6.0, -7.6], [11.7, 8.6, -7.6], .25);
    dish(pr, [xR + .1, 10.6, 3.0], -Math.PI / 2, .55, .62);
  });
}
function ribbon(pts, w) { const pos = [], uv = [], idx = []; pts.forEach((p, i) => { pos.push(p.x, p.y, p.z - w / 2, p.x, p.y, p.z + w / 2); uv.push(i / (pts.length - 1) * 3, 0, i / (pts.length - 1) * 3, 1); }); for (let i = 0; i < pts.length - 1; i++) { const a = i * 2; idx.push(a, a + 2, a + 1, a + 1, a + 2, a + 3); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx); g.computeVertexNormals(); return g; }

export function concreteHouse() {
  return makeAsset('EV_ConcreteHouse_A', 2201, P => {
    const st = P('Structure'), wl = P('Walls_Tint'), rf = P('Roof_Tint'), pr = P('Props'), y0 = .6, y1 = 7.6, t = .3, xL = -9, xR = 9, zF = -4, zB = 6;
    add(st, boxG(18.6, y0, 10.6), lib.concrete, [0, y0 / 2, 1]); add(st, boxG(10.2, .5, 3.4), lib.concrete, [-4, .25, -5.7]); steps(st, lib.concrete, -4, -7.4, -.6, 3.0, .25, 1);
    const fH = [[-5.0, -3.2, y0, 6.4], [-1.2, 1.4, 2.8, 5.2], [3.6, 6.2, 2.8, 5.2]], bH = [[-5.5, -3.1, 2.8, 5.2], [2.4, 4.8, 2.8, 5.2]], sH = [[-.2, 2.2, 2.8, 5.2]];
    wall(wl, lib.render, 'x', zF - t / 2, xL, xR, y0, y1, t, fH); wall(wl, lib.render, 'x', zB + t / 2, xL, xR, y0, y1, t, bH); wall(wl, lib.render, 'z', xL - t / 2, zF - t, zB + t, y0, y1, t, sH); wall(wl, lib.render, 'z', xR + t / 2, zF - t, zB + t, y0, y1, t, sH);
    add(st, boxG(18.7, .2, .4), lib.concrete, [0, y0 + .1, zF - t - .05]);
    for (const h of fH.slice(1)) slidingWindow(P, [(h[0] + h[1]) / 2, 4.0, zF - t], '-z', h[1] - h[0], 2.4, t);
    for (const h of bH) slidingWindow(P, [(h[0] + h[1]) / 2, 4.0, zB + t], '+z', h[1] - h[0], 2.4, t);
    slidingWindow(P, [xL - t, 4.0, 1.0], '-x', 2.4, 2.4, t); slidingWindow(P, [xR + t, 4.0, 1.0], '+x', 2.4, 2.4, t);
    door(P, [-4.1, y0, zF - t], '-z', 1.8, 5.8, t);
    const zc = 1, half = 6.0, ridgeY = y1 + 5 * Math.tan(28 * DEG), eaveY = ridgeY - half * Math.tan(28 * DEG);
    gableX(rf, lib.tile, -10.95, 10.95, zc, half, ridgeY, eaveY, .22);
    for (const x of [xL - t / 2, xR + t / 2]) gableEnd(wl, lib.render, x, zF - t, zB + t, y1, y1 + 5.3 * Math.tan(28 * DEG), t);
    add(st, boxG(21.8, .3, .12), lib.whitePaint, [0, eaveY - .05, zc - half]); add(st, boxG(21.8, .3, .12), lib.whitePaint, [0, eaveY - .05, zc + half]);
    // porch: columns, lean-to roof, floor
    for (const x of [-8.7, -4.0, .7]) add(wl, boxG(.5, 6.4, .5), lib.render, [x, .5 + 3.2, -7.1]); add(wl, boxG(10.0, .5, .5), lib.render, [-4, 6.85, -7.1]);
    const pr2 = add(rf, boxG(10.6, .16, 3.4), lib.tile, [-4, 7.15, -6.0]); pr2.rotation.x = -.2;
    plasticChair(P('Chairs_Tint'), [-7.2, .5, -5.8], .3); plasticChair(P('Chairs_Tint'), [-1.4, .5, -5.6], -.4); plasticTable(P('Chairs_Tint'), [-4.3, .5, -5.2 + 1.2 * 0]);
    for (const [x, z] of [[-8.6, -7.8], [.6, -7.8], [-2.2, -7.9]]) pottedPlant(pr, [x, 0, z], 1.1); pottedPlant(pr, [-8.4, .5, -4.6], .9);
    waterJar(pr, [-10.0, 0, 4.4], 1); waterJar(pr, [-10.1, 0, 2.2], .9);
    motorbike(P, [4.8, 0, -6.0], -1.35); bicycle(pr, [9.75, 0, 1.0], 0);
    laundry(P, [-10.6, 4.6, -2.6], [-10.6, 4.6, 0.6], 4); for (const z of [-2.6, .6]) add(pr, cylG(.06, .06, 4.6, 6), lib.steel, [-10.6, 2.3, z]);
    spiritHouse(pr, [7.6, 0, -7.4], 0);
    meter(wl.parent ? pr : pr, [7.8, 4.0, zF - t], '-z'); pipe(pr, lib.rubber, [7.8, 4.5, zF - t - .2], [7.8, eaveY - .2, zF - t - .2], .03, 4); wire(pr, [7.8, eaveY - .2, zF - t - .2], [10.8, 9.0, -6.5], .3);
    dish(pr, [6.5, ridgeY - 1.2, 3.2], Math.PI * .85, .5); add(pr, boxG(.4, .4, .4), lib.steel, [6.5, ridgeY - 1.35, 3.2]);
  });
}

export function shophouse() {
  return makeAsset('EV_Shophouse_A', 2301, P => {
    const st = P('Structure'), wl = P('Walls_Tint'), rf = P('Roof_Tint'), pr = P('Props'), sh = P('Shutter'), x0 = -7.85, x1 = 7.85, zF = -6, zB = 8.12, t = .35, g1 = 9.2, g2 = 17.0, par = 18.6;
    add(st, boxG(15.7, .4, 14.9), lib.concrete, [0, .2, 1.3]); add(st, boxG(15.7, .2, 3.0), lib.concrete, [0, .1, -7.5]);
    wall(wl, lib.render, 'x', zF - t / 2, x0, x1, .4, par, t, [[-6.8, 6.8, .4, 7.9], [-5.6, -2.2, 12.0, 15.2], [2.2, 5.6, 12.0, 15.2]]);
    wall(wl, lib.render, 'x', zB + t / 2, x0, x1, .4, par, t, [[-1.4, 1.4, 12.2, 14.6]]);
    wall(wl, lib.render, 'z', x0 + t / 2, zF - t, zB + t, .4, par, t); wall(wl, lib.render, 'z', x1 - t / 2, zF - t, zB + t, .4, par, t);
    add(wl, boxG(15.7, .5, .55), lib.render, [0, g1, zF - t - .1]); add(wl, boxG(15.9, .3, .6), lib.render, [0, par + .1, zF - t / 2]);
    for (const x of [-4.0, 4.0]) slidingWindow(P, [x - (x > 0 ? -.1 : .1) * 0, 13.6, zF - t], '-z', 3.4, 3.2, t); slidingWindow(P, [0, 13.4, zB + t], '+z', 2.8, 2.4, t);
    add(st, boxG(15.0, .3, 14.2), lib.concrete, [0, g2, 1.3]);
    // shop interior: dark box, shelves with goods, counter, fridge
    const ins = P('Interior'); add(ins, boxG(13.6, 7.5, .05), HM.dark, [0, 4.15, 6.0]); add(ins, boxG(13.6, .05, 12), HM.dark, [0, 7.85, 0]); for (const sx of [-1, 1]) add(ins, boxG(.05, 7.5, 12), HM.dark, [sx * 6.85, 4.15, 0]);
    for (const sx of [-1, 1]) for (let k = 0; k < 4; k++) { const y = 1.2 + k * 1.5; add(st, boxG(1.2, .08, 9), lib.woodRough, [sx * 6.1, y, 1.0]); for (let b = 0; b < 9; b++) add(st, boxG(rr(.6, 1.0), rr(.5, 1.0), rr(.6, .9)), pick([HM.boxA, HM.boxB, HM.boxC, HM.sack]), [sx * 6.1, y + .4, -3.0 + b * 1.0]); }
    add(st, boxG(5.0, 2.4, 1.6), lib.woodRough, [1.0, 1.6, 2.5]); add(st, boxG(5.2, .1, 1.8), lib.teak, [1.0, 2.85, 2.5]);
    const fr = sub(st, [-4.9, .4, -4.6]); add(fr, bboxG(2.6, 6.6, 2.4, .1), HM.fridge, [0, 3.3, 0]); add(fr, boxG(2.2, .9, .04), HM.fridgeSign, [0, 6.05, -1.22]);
    add(P('Glass'), boxG(2.1, 4.6, .03), lib.glass, [-4.9, .4 + 3.2, -4.6 - 1.21]); for (let r = 0; r < 4; r++) { add(fr, boxG(2.0, .05, 2.0), lib.chrome, [0, 1.2 + r * 1.15, 0]); for (let b = 0; b < 7; b++) add(fr, cylG(.11, .11, .85, 8), pick([HM.bottleA, HM.bottleB, HM.bottleC]), [-.8 + b * .27, 1.65 + r * 1.15, -.7]); }
    // folding steel shutter, half open (stacked left, drawn across the right half)
    add(sh, boxG(13.8, .25, .3), lib.darkSteel, [0, 7.8, zF - t - .1]); add(sh, boxG(13.8, .08, .3), lib.darkSteel, [0, .44, zF - t - .1]);
    for (let i = 0; i < 24; i++) { const x = 1.2 + i * .23; add(sh, boxG(.3, 7.3, .03), HM.shutter, [x, 4.1, zF - t - .1 + (i % 2 ? .07 : -.07)], [0, i % 2 ? .5 : -.5, 0]); }
    for (let i = 0; i < 12; i++) add(sh, boxG(.3, 7.3, .03), HM.shutter, [-6.55 + i * .06, 4.1, zF - t - .12 + (i % 2) * .1], [0, 1.35 * (i % 2 ? 1 : -1), 0]);
    add(sh, boxG(.06, .5, .1), lib.chrome, [6.6, 3.8, zF - t - .2]);
    // sign board above the awning, awning on steel brackets
    add(st, boxG(14.4, 1.9, .12), HM.sign, [0, 10.6, zF - t - .2]); add(st, boxG(14.6, .1, .3), lib.darkSteel, [0, 11.6, zF - t - .2]); add(st, boxG(14.6, .1, .3), lib.darkSteel, [0, 9.6, zF - t - .2]);
    const aw = add(rf, boxG(15.6, .12, 3.3), lib.tin, [0, 8.05, -7.6]); aw.rotation.x = -.3;
    for (const x of [-7.2, -2.4, 2.4, 7.2]) { beam(st, lib.darkSteel, [x, 8.6, zF - t], [x, 7.5, -9.0], .08, .08); beam(st, lib.darkSteel, [x, 7.0, zF - t], [x, 7.6, -8.4], .06, .06); }
    // roof: parapet, water tank on stand, antenna, dish, laundry
    add(st, boxG(15.0, .2, 14.2), lib.concrete, [0, g2 + .25, 1.3]);
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) add(st, boxG(.2, 1.6, .2), lib.steel, [4.0 + sx * .9, g2 + 1.2, 6.0 + sz * .9]); add(st, boxG(2.2, .15, 2.2), lib.steel, [4.0, g2 + 2.0, 6.0]);
    add(pr, cylG(1.15, 1.15, 2.4, 20), lib.chrome, [4.0, g2 + 3.28, 6.0]); add(pr, revolve([[1.15, 0], [.6, .3], [0, .38]], 20), lib.chrome, [4.0, g2 + 4.48, 6.0]);
    add(pr, cylG(.05, .05, 4.6, 6), lib.steel, [-5.0, g2 + 2.6, 7.4]); for (let i = 0; i < 5; i++) add(pr, cylG(.025, .025, 2.4 - i * .3, 4), lib.steel, [-5.0, g2 + 3.4 + i * .35, 7.4], [Math.PI / 2, 0, 0]);
    dish(pr, [-5.4, par + .05, -5.6], Math.PI, .6); laundry(P, [-6.5, g2 + 2.0, 1.0], [-1.0, g2 + 2.0, 1.0], 5); for (const x of [-6.5, -1.0]) add(pr, cylG(.05, .05, 2.0, 6), lib.steel, [x, g2 + 1.2, 1.0]);
    // street front: chairs + table, crates, jar, plants, motorbike, bicycle, meter + wires
    plasticTable(P('Chairs_Tint'), [-3.0, .2, -7.8]); plasticChair(P('Chairs_Tint'), [-4.8, .2, -7.6], 1.6); plasticChair(P('Chairs_Tint'), [-1.3, .2, -7.5], -1.4);
    for (let k = 0; k < 3; k++) add(P('Chairs_Tint'), boxG(1.4, .9, 1.0), lib.plasticTint, [6.4, .65 + k * .92, -7.0]);
    waterJar(pr, [-7.0, .2, -8.2], .8); pottedPlant(pr, [-7.0, .2, -6.8], 1.0); motorbike(P, [2.8, .2, -7.8], Math.PI / 2 + .1);
    bicycle(pr, [7.25, 0, 3.0], 0);
    meter(pr, [7.0, 6.0, zF - t], '-z'); pipe(pr, lib.rubber, [7.0, 6.5, zF - t - .2], [7.0, 8.4, zF - t - .2], .03, 4); wire(pr, [7.0, 8.4, zF - t - .2], [7.9, 12.0, -8.8], .2);
  });
}

export function farmhouse() {
  return makeAsset('EV_Farmhouse_A', 2401, P => {
    const st = P('Structure'), rf = P('Roof_Tint'), pr = P('Props'), fy = 2.0, wt = .14, x0 = -4.5, x1 = 4.5, zF = -4, zB = 4, wy1 = 7.0;
    for (const x of [-4.4, 0, 4.4]) for (const z of [-3.9, 0, 3.9]) { add(st, boxG(.45, fy, .45), lib.woodRough, [x, fy / 2, z]); add(st, boxG(.8, .25, .8), lib.concrete, [x, .125, z]); }
    add(st, boxG(9.4, .15, 8.4), lib.teak, [0, fy + .075, 0]); for (const z of [-3.9, 0, 3.9]) add(st, boxG(9.4, .3, .35), lib.woodRough, [0, fy - .15, z]);
    const fH = [[-.9, .9, fy + .15, 6.2], [-3.6, -2.2, 3.8, 5.4], [2.2, 3.6, 3.8, 5.4]], bH = [[-2.8, -1.4, 3.8, 5.4], [1.4, 2.8, 3.8, 5.4]], sH = [[-.7, .7, 3.8, 5.4]];
    wall(st, lib.teak, 'x', zF, x0, x1, fy + .15, wy1, wt, fH); wall(st, lib.teak, 'x', zB, x0, x1, fy + .15, wy1, wt, bH); wall(st, lib.teak, 'z', x0, zF, zB, fy + .15, wy1, wt, sH); wall(st, lib.teak, 'z', x1, zF, zB, fy + .15, wy1, wt, sH);
    for (const h of fH.slice(1)) plainShutterWindow(P, [(h[0] + h[1]) / 2, 4.6, zF - wt / 2], '-z', 1.4, 1.6, wt); for (const h of bH) plainShutterWindow(P, [(h[0] + h[1]) / 2, 4.6, zB + wt / 2], '+z', 1.4, 1.6, wt);
    plainShutterWindow(P, [x0 - wt / 2, 4.6, 0], '-x', 1.4, 1.6, wt); plainShutterWindow(P, [x1 + wt / 2, 4.6, 0], '+x', 1.4, 1.6, wt);
    door(P, [0, fy + .15, zF - wt / 2], '-z', 1.8, 4.0, wt, 'plank'); add(st, boxG(3.0, .12, 1.4), lib.woodRough, [0, fy + .06, -4.7]); steps(st, lib.woodRough, 0, -5.4, -.45, 2.2, .5, 3);
    const half = 5.3, ridgeY = wy1 + 4.0 * Math.tan(30 * DEG), eaveY = ridgeY - half * Math.tan(30 * DEG);
    gableX(rf, lib.tin, -5.4, 5.4, 0, half, ridgeY, eaveY, .12); for (const x of [x0, x1]) gableEnd(st, lib.teak, x, zF, zB, wy1, wy1 + 4 * Math.tan(30 * DEG), wt);
    // lean-to shed (+X)
    for (const z of [-3.5, 0, 3.5]) add(st, boxG(.35, 5.0, .35), lib.woodRough, [8.4, 2.5, z]); add(st, boxG(.3, .3, 7.4), lib.woodRough, [8.4, 5.0, 0]);
    const lt = add(rf, boxG(4.5, .1, 8.2), lib.tin, [6.6, 5.9, 0]); lt.rotation.z = -Math.atan2(1.6, 4.1);
    add(st, boxG(3.2, .12, 1.3), lib.woodRough, [6.6, 2.4, 3.1]); for (const sx of [-1, 1]) for (const sz of [-1, 1]) add(st, boxG(.12, 2.4, .12), lib.woodRough, [6.6 + sx * 1.45, 1.2, 3.1 + sz * .5]);
    for (let k = 0; k < 5; k++) add(pr, bboxG(1.5, .7, 1.0, .25), HM.sack, [6.0 + (k % 2) * .4, .35 + Math.floor(k / 2) * .68, -2.6 + (k % 3) * .2], [0, rr(-.2, .2), 0]);
    const cart = sub(pr, [6.9, 0, -.4], [0, .2, 0]); add(cart, boxG(2.2, .7, 3.0), lib.woodRough, [0, 1.6, 0]); for (const sx of [-1, 1]) wheel(cart, lib.rubber, lib.darkSteel, [sx * 1.25, .9, .3], .8, .1, 'x'); pipe(cart, lib.darkSteel, [-1.3, .9, .3], [1.3, .9, .3], .05, 6); for (const sx of [-1, 1]) pipe(cart, lib.woodRough, [sx * .8, 1.4, -1.4], [sx * .8, .3, -3.2], .07, 6);
    for (const [x, z, ry] of [[8.0, 1.6, 0], [7.7, 2.0, .3], [8.1, 2.4, -.2]]) { const tl = sub(pr, [x, 0, z], [0, ry, -.25]); add(tl, cylG(.05, .05, 4.2, 6), lib.woodRough, [0, 2.1, 0]); add(tl, boxG(.8, .5, .06), lib.darkSteel, [0, .25, .05]); }
    // rice barn (yung khao) on posts, flared walls, tin roof
    const bx = -7.04, bz = -.5;
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) { add(st, boxG(.35, 2.6, .35), lib.woodRough, [bx + sx * 1.2, 1.3, bz + sz * 1.4]); add(st, boxG(.6, .2, .6), lib.concrete, [bx + sx * 1.2, .1, bz + sz * 1.4]); }
    add(st, boxG(2.9, .15, 3.3), lib.woodRough, [bx, 2.65, bz]); add(st, frustumG(2.7, 3.1, 3.2, 3.6, 3.0), lib.teak, [bx, 4.2, bz]);
    gableX(rf, lib.tin, bx - 1.75, bx + 1.75, bz, 2.25, 7.9, 5.6, .1); gableEnd(st, lib.teak, bx - 1.6, bz - 1.8, bz + 1.8, 5.7, 7.6, .1); gableEnd(st, lib.teak, bx + 1.7, bz - 1.8, bz + 1.8, 5.7, 7.6, .1);
    add(st, boxG(.9, 1.6, .06), lib.woodRough, [bx, 4.2, bz - 1.81]); for (const sx of [-1, 1]) pipe(st, lib.bamboo, [bx + sx * .35, 0, bz - 3.0], [bx + sx * .35, 3.4, bz - 1.9], .06, 6); for (let i = 1; i < 6; i++) { const tt = i / 6; add(st, alongX(cylG(.04, .04, .75, 4)), lib.bamboo, [bx, tt * 3.4, lerp(bz - 3.0, bz - 1.9, tt)]); }
    // props
    waterJar(pr, [-3.5, 0, 5.75], 1); waterJar(pr, [-1.6, 0, 5.8], .85); waterJar(pr, [3.6, 0, 5.8], .95);
    bicycle(pr, [-5.2, 0, -4.8], Math.PI / 2 + .2); plasticChair(P('Chairs_Tint'), [-2.2, 0, -6.0], .5); pottedPlant(pr, [1.8, 0, -6.2]); pottedPlant(pr, [-1.6, 0, -5.8], .8);
    laundry(P, [-4.4, 1.8, 3.9], [0, 1.8, 3.9], 4);
    meter(pr, [4.4, 1.2, -4.15], '-z'); pipe(pr, lib.rubber, [4.4, 1.7, -4.3], [4.4, eaveY - .3, -4.3], .03, 4); wire(pr, [4.4, eaveY - .3, -4.3], [8.6, 7.0, -6.0], .25);
    dish(pr, [3.0, ridgeY - .9, 2.0], Math.PI * .9, .6);
  });
}

export { wall, louvreWindow, slidingWindow, door, steps, gableX, gableEnd, frameAt, ribbon, wire };
