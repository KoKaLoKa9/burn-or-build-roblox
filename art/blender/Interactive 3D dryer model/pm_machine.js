// PelletMill (ring-die pellet line) builder. Shares textures, materials and helpers with the power pack.
import { THREE, V3, TAU, DEG, YUP, DS, rnd, rr, setSeed, mat, decalMat, v3, boxG, bboxG, cylG, hexG, alongX, alongZ, revolve, latheX, latheZ, ringProf, frustumG, tubeG, helixG, add, orient, pipe, beam, sub, duct, plane, cv, texFrom, normalFrom } from './power_lib.js';
import { T, M, finish, nut, boltRing, anchor, gland, flat, sticker, prismXY, louvre, dialFace, label, lcd, grpOf, root } from './power_machines.js';
export { M };
const PI = Math.PI;

/* ---------- extra textures ---------- */
{ const S = 512, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#3e2a17'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < 2600; i++) { const px = rnd() * S, py = rnd() * S, L = rr(14, 28), w = 10, l = rr(.75, 1.15); x.save(); x.translate(px, py); x.rotate(rnd() * PI);
    x.fillStyle = `rgb(${124 * l | 0},${86 * l | 0},${50 * l | 0})`; x.beginPath(); x.roundRect(-L / 2, -w / 2, L, w, 5); x.fill(); x.fillStyle = 'rgba(255,228,186,.16)'; x.fillRect(-L / 2 + 2, -w / 2 + 1, L - 4, 3); x.restore(); }
  T.pellet = texFrom(c); }
{ const S = 512, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#8f9496'; x.fillRect(0, 0, S, S); h.fillStyle = '#c4c4c4'; h.fillRect(0, 0, S, S);
  for (let i = 0; i < 900; i++) { x.fillStyle = `rgba(${rnd() < .5 ? '235,238,240' : '70,72,74'},${rr(.04, .12)})`; x.fillRect(0, rnd() * S, S, rr(.5, 2)); }
  const n = 12, st = S / n;
  for (let j = 0; j < n; j++) for (let i = 0; i <= n; i++) { const px = (i + (j % 2) * .5) * st, py = (j + .5) * st;
    for (const ox of [0, -S]) { const X = px + ox; x.fillStyle = '#121212'; x.beginPath(); x.arc(X, py, st * .26, 0, TAU); x.fill(); x.strokeStyle = 'rgba(214,218,220,.7)'; x.lineWidth = 2; x.beginPath(); x.arc(X, py, st * .34, 0, TAU); x.stroke();
      h.fillStyle = '#1a1a1a'; h.beginPath(); h.arc(X, py, st * .28, 0, TAU); h.fill(); } }
  for (let i = 0; i < 60; i++) { const g = x.createRadialGradient(rnd() * S, rnd() * S, 0, rnd() * S, rnd() * S, rr(20, 80)); g.addColorStop(0, 'rgba(110,80,48,.18)'); g.addColorStop(1, 'rgba(110,80,48,0)'); x.fillStyle = g; x.fillRect(0, 0, S, S); }
  T.die = texFrom(c); T.dieN = normalFrom(hc, 2.5); }
{ const S = 256, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#6f7476'; x.fillRect(0, 0, S, S); h.fillStyle = '#808080'; h.fillRect(0, 0, S, S);
  for (let i = 0; i < 32; i++) { x.fillStyle = i % 2 ? '#a9aeb0' : '#4c5052'; x.fillRect(i * 8, 0, 4, S); h.fillStyle = i % 2 ? '#f0f0f0' : '#202020'; h.fillRect(i * 8, 0, 4, S); }
  T.roller = texFrom(c); T.rollerN = normalFrom(hc, 3); }
T.stencil = (() => { const W = 512, H = 160, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = 'rgba(28,24,20,.85)'; x.font = '700 110px "IBM Plex Sans Condensed",sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText('PELLET', W / 2, H / 2 + 6);
  x.globalCompositeOperation = 'destination-out'; for (let i = 0; i < 5; i++) x.fillRect(W * (.14 + i * .17), 0, 6, H); for (let i = 0; i < 400; i++) { x.globalAlpha = rr(.2, .7); x.beginPath(); x.arc(rnd() * W, rnd() * H, rr(.6, 2.4), 0, TAU); x.fill(); } return texFrom(c, true, false); })();
function signTex(title, sub, kind) { const W = 384, H = 448, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#f4f3ee'; x.fillRect(0, 0, W, H); x.strokeStyle = '#111'; x.lineWidth = 10; x.strokeRect(8, 8, W - 16, H - 16);
  const cx = W / 2;
  if (kind === 'blue') { x.fillStyle = '#1d5fa8'; x.beginPath(); x.arc(cx, 150, 110, 0, TAU); x.fill(); x.strokeStyle = '#fff'; x.lineWidth = 14; x.beginPath(); x.arc(cx, 165, 62, PI, 0); x.stroke(); x.fillStyle = '#fff'; for (const s of [-1, 1]) { x.beginPath(); x.roundRect(cx + s * 62 - 22, 150, 44, 70, 14); x.fill(); } }
  else { x.fillStyle = '#111'; x.beginPath(); x.moveTo(cx, 40); x.lineTo(cx + 125, 255); x.lineTo(cx - 125, 255); x.closePath(); x.fill(); x.fillStyle = '#f1c40f'; x.beginPath(); x.moveTo(cx, 76); x.lineTo(cx + 96, 238); x.lineTo(cx - 96, 238); x.closePath(); x.fill();
    x.strokeStyle = '#111'; x.lineWidth = 9;
    if (kind === 'hot') for (const o of [-28, 0, 28]) { x.beginPath(); x.moveTo(cx + o, 225); x.bezierCurveTo(cx + o - 18, 195, cx + o + 18, 165, cx + o, 130); x.stroke(); }
    else { x.beginPath(); x.arc(cx - 26, 185, 30, 0, TAU); x.stroke(); x.beginPath(); x.arc(cx + 26, 185, 30, 0, TAU); x.stroke(); x.fillStyle = '#111'; x.beginPath(); x.moveTo(cx + 40, 120); x.lineTo(cx + 64, 150); x.lineTo(cx + 30, 150); x.closePath(); x.fill(); } }
  x.fillStyle = '#111'; x.textAlign = 'center'; const fit = (t, px, wt, y) => { let p = px; do { x.font = `${wt} ${p}px "IBM Plex Sans Condensed",sans-serif`; p -= 2; } while (x.measureText(t).width > W - 50 && p > 10); x.fillText(t, cx, y); };
  fit(title, 58, 700, 330); fit(sub, 34, 500, 388); return texFrom(c, true, false); }
const P = {
  pellet: mat('PelletFill', 'PelletFill', { map: T.pellet, roughness: .8 }, 1.4),
  pelletSolid: mat('Pellet', 'Pellet', { color: 0x7b5533, roughness: .7 }),
  die: mat('DieSteel', 'RingDieSteel', { map: T.die, normalMap: T.dieN, roughness: .3, metalness: .85 }, 2.2),
  roller: mat('Roller', 'PressRollerShell', { map: T.roller, normalMap: T.rollerN, roughness: .38, metalness: .85 }, 1),
  stencil: decalMat('Stencil', 'StencilPellet', T.stencil),
  grating: mat('Grating', 'FloorGrating', { map: T.mesh, color: 0x9aa0a0, alphaTest: .5, side: DS, metalness: .6, roughness: .45 }, 4),
  levelWin: mat('LevelWindow', 'LevelWindowDark', { color: 0x2c3436, roughness: .08, metalness: .4 }),
  hot: label('SignHotSurface', signTex('HOT SURFACE', 'ผิวร้อน ห้ามสัมผัส', 'hot')),
  rot: label('SignRotating', signTex('ROTATING PARTS', 'ระวังชิ้นส่วนหมุน', 'rot')),
  ear: label('SignEar', signTex('WEAR EAR PROTECTION', 'สวมที่ครอบหู', 'blue')),
  name: label('Nameplate', T.namePlate('COOP PELLET MILL 01', 'Ring die Ø 2.3 · 6 mm · 1.5 t/h', 'Main drive 132 kW · S/N 2026-0101', '#c9ccc8', '#1f6f6c'), { metalness: .6, roughness: .35 }),
};

/* ---------- builder ---------- */
export function buildPelletMill() {
  setSeed(707); const R = root('PelletMill'), G = grpOf(R, 'PM_');
  const Fo = G('Foundation'), In = G('Infeed'), Cd = G('Conditioner'), Pr = G('Press'), Di = G('Die'), Dr = G('Drive'), Co = G('Cooler'), Sc = G('Screen'), Ou = G('Outfeed'), Pl = G('Platform'), Ho = G('Hoist'), Ct = G('Controls'), De = G('Details'), St = G('Straw'), Pe = G('Pellets'), Em = G('Emissive'), Gl = G('Glass');
  const PT = .3, pel = () => cylG(.028, .028, .1, 6);

  // ---- foundation ----
  add(Fo, bboxG(18, PT, 16, .08), M.concrete, [0, PT / 2, 0]);
  for (const s of [-1, 1]) { add(Fo, boxG(17.6, .006, .2), M.hazard, [0, PT + .003, s * 7.75]); add(Fo, boxG(.2, .006, 15.1), M.hazard, [s * 8.75, PT + .003, 0]); }
  for (const [x, z] of [[-8.6, -7.6], [8.6, -7.6], [-8.6, 7.6], [8.6, 7.6], [0, -7.6], [0, 7.6], [-4.3, 7.6], [4.3, -7.6], [4.3, 7.6], [-4.3, -7.6], [-8.6, 4], [8.6, 4], [-8.6, -4], [8.6, -4]]) anchor(Fo, x, PT, z);
  add(Fo, bboxG(4.2, .15, 5.2, .04), M.concrete, [0, PT + .075, .1]); add(Fo, bboxG(2.6, .15, 3.8, .04), M.concrete, [0, PT + .075, 4.95]);
  add(Fo, flat(3.2, 2.0), M.oil, [.3, .454, -.6]); add(Fo, flat(1.6, 1.2), M.oil, [.6, .454, 4.4]); add(Fo, flat(3.4, 3.4), M.dust, [-7.1, PT + .005, .3]); add(Fo, flat(2.2, 2.0), M.rust, [7.6, PT + .005, -1.6]);

  // ---- infeed: hopper at IN, inclined screw ----
  const hz = 1.2, fl = x => 1.1 - (x + 9) * (.55 / 1.4), tp = x => 1.32 + (x + 9) * (1.73 / 2.18);
  prismXY(In, M.galv, [[-9, 1.1], [-7.6, .55], [-7.6, .59], [-9, 1.14]], -hz, hz);
  add(In, boxG(.8, .04, 2.4), M.galv, [-7.2, .55, 0]); add(In, boxG(.04, 2.5, 2.48), M.teal, [-6.8, 1.8, 0]);
  for (const s of [-1, 1]) { const z0 = s > 0 ? hz : -hz - .04; prismXY(In, M.teal, [[-9, 1.1], [-7.6, .51], [-6.82, .51], [-6.82, 3.05], [-9, 1.32]], z0, z0 + .04);
    beam(In, M.teal, [-8.97, 1.34, s * 1.22], [-6.84, 3.07, s * 1.22], .06, .06);
    for (const x of [-8.2, -7.5]) { add(In, boxG(.06, tp(x) - .55, .05), M.teal, [x, .55 + (tp(x) - .55) / 2, s * 1.265]); nut(In, [x, tp(x) - .2, s * 1.29], [0, 0, s], .025, .02); }
    add(In, boxG(1.4, .05, .05), M.teal, [-7.6, .95, s * 1.265]);
    for (const x of [-8.6, -7.2]) { beam(In, M.galv, [x, PT, s * 1.05], [x, fl(x) - .02, s * 1.05], .08, .08); add(In, boxG(.2, .02, .2), M.galv, [x, PT + .01, s * 1.05]); } }
  add(In, boxG(.06, .06, 2.48), M.teal, [-8.97, 1.3, 0]);
  const A = new V3(-7.2, 1.05, 0), B = new V3(-5.25, 8.75, -2.7), d = B.clone().sub(A), dn = d.clone().normalize();
  pipe(In, M.teal, A, B, .3, 36);
  { const s = sub(In, A, dn); add(s, helixG(.26, .03, 3, -.38, 0, 90, 6), M.steel); add(s, cylG(.06, .06, .45, 10), M.steel, [0, -.2, 0]); }
  for (const t of [.12, .3, .48, .66, .84]) { const p = A.clone().addScaledVector(d, t); orient(add(In, revolve(ringProf(.3, .42, .07, .01), 36), M.teal, p), dn); boltRing(In, p.clone().addScaledVector(dn, .035), dn, .37, 8, .022, .02); }
  add(In, bboxG(.8, .6, .8, .03), M.teal, [B.x, 8.9, B.z]); add(In, boxG(.4, .12, .4), M.teal, [B.x, 8.55, B.z]);
  add(In, bboxG(.36, .4, .4, .03), M.iron, [B.x, 8.9, B.z + .6]); add(In, alongX(cylG(.2, .2, .6, 24)), M.teal, [B.x + .5, 8.9, B.z + .6]); add(In, latheX([[.2, 0], [.2, .08], [.12, .12], [0, .13]], 20), M.teal, [B.x + .8, 8.9, B.z + .6]);
  add(In, bboxG(.16, .14, .16, .02), M.teal, [B.x + .45, 9.17, B.z + .6]);
  for (const t of [.35, .65]) { const p = A.clone().addScaledVector(d, t); add(In, boxG(.12, p.y - .32 - PT, .12), M.galv, [p.x, PT + (p.y - .32 - PT) / 2, p.z]); add(In, boxG(.5, .06, .3), M.galv, [p.x, p.y - .32, p.z]); add(In, boxG(.26, .02, .26), M.galv, [p.x, PT + .01, p.z]); anchor(In, p.x + .08, PT + .02, p.z + .08); }
  sticker(In, P.rot, .3, .35, A.clone().addScaledVector(d, .22).add(new V3(.07, 0, -.31)), PI);

  // ---- straw heap over the hopper rim ----
  add(St, new THREE.SphereGeometry(1, 32, 16), M.straw, [-7.85, 1.15, 0], [0, 0, 0], [1.0, .55, 1.05]);
  for (let i = 0; i < 520; i++) { const th = Math.acos(rr(.05, 1)), ph = rr(0, TAU), r = rr(.92, 1.06); let x = -7.85 + Math.cos(ph) * Math.sin(th) * r, y = 1.15 + Math.cos(th) * .55 * r, z = Math.sin(ph) * Math.sin(th) * 1.05 * r;
    x = Math.max(-8.8, Math.min(-6.9, x)); z = Math.max(-1.14, Math.min(1.14, z)); add(St, boxG(rr(.14, .32), .012, .022), M.straw, [x, y, z], [rr(-.6, .6), rr(0, PI), rr(-.6, .6)]); }
  for (let i = 0; i < 70; i++) add(St, boxG(rr(.12, .3), .01, .02), M.straw, [rr(-8.7, -6.2), PT + .012, rr(-2.4, 2.4)], [0, rr(0, PI), 0]);

  // ---- feeder screw + conditioner ----
  const cz = -2.9, cdy = 6.0, fdy = 7.3;
  add(Cd, alongX(cylG(.36, .36, 4.0, 36)), M.teal, [-3.6, fdy, cz]);
  for (const x of [-5.6, -1.6]) add(Cd, alongX(cylG(.42, .42, .06, 36)), M.teal, [x, fdy, cz]);
  for (const x of [-4.6, -3.6, -2.6]) { add(Cd, revolve(ringProf(.36, .44, .06, .01), 36).rotateZ(PI / 2), M.teal, [x, fdy, cz]); boltRing(Cd, [x + .03, fdy, cz], [1, 0, 0], .4, 8, .02, .02); }
  add(Cd, frustumG(.8, .8, 1.0, .8, .8), M.teal, [-5.1, 8.08, cz]); add(Cd, boxG(1.04, .05, .84), M.teal, [-5.1, 8.5, cz]);
  add(Cd, bboxG(.4, .5, .55, .03), M.iron, [-5.85, fdy, cz]); add(Cd, alongX(cylG(.26, .26, .7, 28)), M.teal, [-6.4, fdy, cz]); add(Cd, latheX([[.26, 0], [.26, .1], [.16, .14], [0, .15]], 24).rotateY(PI), M.teal, [-6.75, fdy, cz]);
  for (let i = 0; i < 12; i++) { const a = i / 12 * PI; add(Cd, boxG(.6, .025, .06), M.teal, [-6.4, fdy + Math.sin(a) * .27, cz + Math.cos(a) * .27], [a - PI / 2, 0, 0]); }
  add(Cd, bboxG(.2, .16, .2, .02), M.teal, [-6.4, fdy + .33, cz]);
  sticker(Cd, label('VsdLabel', T.label('VARIABLE SPEED', '#e8e8e2')), .5, .12, [-6.4, fdy - .05, cz - .262], PI);
  add(Cd, boxG(.4, .39, .4), M.teal, [-2.0, 6.745, cz]);
  add(Cd, alongX(cylG(.55, .55, 6.0, 48)), M.teal, [-2.0, cdy, cz]);
  for (const s of [-1, 1]) add(Cd, latheX(s > 0 ? [[.55, 0], [.5, .1], [.3, .16], [0, .18]] : [[0, 0], [.3, .02], [.5, .08], [.55, .18]], 40), M.teal, [s > 0 ? 1.0 : -5.18, cdy, cz]);
  for (const x of [-4.0, -2.0, 0]) add(Cd, revolve(ringProf(.55, .62, .05, .01), 48).rotateZ(PI / 2), M.teal, [x, cdy, cz]);
  for (const x of [-5.3, 1.3]) { add(Cd, bboxG(.24, .3, .4, .02), M.iron, [x, cdy, cz]); pipe(Cd, M.steel, [x - .2, cdy, cz], [x + .2, cdy, cz], .06, 12); }
  add(Cd, bboxG(.36, .46, .5, .03), M.iron, [-5.6, cdy, cz]); add(Cd, alongX(cylG(.3, .3, .65, 28)), M.teal, [-6.1, cdy, cz]); add(Cd, latheX([[.3, 0], [.3, .1], [.18, .15], [0, .16]], 24).rotateY(PI), M.teal, [-6.43, cdy, cz]);
  for (const x of [-4.0, -2.4, -.8]) { add(Cd, bboxG(.6, .5, .06, .02), M.teal, [x, cdy, cz - .575]); for (const k of [-1, 1]) { add(Cd, boxG(.06, .08, .08), M.steel, [x + k * .33, cdy, cz - .62]); add(Cd, boxG(.03, .16, .03), M.steel, [x + k * .33, cdy - .06, cz - .67]); } add(Cd, boxG(.5, .03, .04), M.steel, [x, cdy + .26, cz - .6]); }
  add(Cd, boxG(.5, 1.0, .5), M.teal, [0, 4.95, cz]); add(Cd, alongZ(cylG(.18, .18, .35, 20)), M.teal, [.42, 5.1, cz]);
  for (const x of [-1.2, .9]) { beam(Cd, M.galv, [x, 4.6, -2.25], [x, 5.48, cz + .1], .1, .1); add(Cd, boxG(.18, .06, .7), M.galv, [x, 5.45, cz + .15]); }
  add(Cd, boxG(.14, 5.15 - PT, .14), M.galv, [-4.4, PT + (5.15 - PT) / 2, cz]); add(Cd, boxG(.3, .3, .9), M.galv, [-4.4, 5.3, cz]); add(Cd, boxG(.3, .02, .3), M.galv, [-4.4, PT + .01, cz]); anchor(Cd, -4.32, PT + .02, cz + .08);
  sticker(Cd, P.hot, .38, .44, [-3.2, cdy, cz - .556], PI);
  // steam inlet: lagged pipe, valve, gauge, trap
  const sx = -3.9;
  duct(Cd, M.lag, [[sx, cdy, cz + .53], [sx, cdy, -1.5], [sx, .75, -1.5], [sx, .75, -.35]], .1, .3, 20, 8);
  add(Cd, alongZ(cylG(.18, .18, .05, 24)), M.iron, [sx, .75, -.35]); boltRing(Cd, [sx, .75, -.33], [0, 0, 1], .14, 6, .02, .02);
  add(Cd, new THREE.SphereGeometry(.17, 18, 12), M.iron, [sx, 4.2, -1.5]); for (const y of [4.0, 4.4]) add(Cd, cylG(.17, .17, .05, 20), M.iron, [sx, y, -1.5]);
  pipe(Cd, M.steel, [sx, 4.2, -1.5], [sx + .38, 4.2, -1.5], .02, 8); add(Cd, new THREE.TorusGeometry(.18, .025, 8, 24).rotateY(PI / 2), M.red, [sx + .38, 4.2, -1.5]); for (let i = 0; i < 3; i++) add(Cd, boxG(.02, .36, .03), M.red, [sx + .38, 4.2, -1.5], [i * PI / 3, 0, 0]);
  pipe(Cd, M.steel, [sx, 4.95, -1.6], [sx, 4.95, -1.86], .02, 8); add(Cd, alongZ(cylG(.18, .18, .08, 32)), M.dark, [sx, 4.95, -1.9]); add(Cd, new THREE.TorusGeometry(.175, .018, 6, 32), M.brass, [sx, 4.95, -1.94]);
  dialFace(Cd, 'DialSteam', T.dial('bar', 10, .8), [sx, 4.95, -1.941], .16, [0, 0, -1], Gl);
  pipe(Cd, M.steel, [sx, .65, -1.5], [sx, .5, -1.5], .05, 10); add(Cd, cylG(.1, .1, .14, 18), M.iron, [sx, .42, -1.5]); add(Cd, boxG(.24, .06, .1), M.iron, [sx, .42, -1.5]); pipe(Cd, M.steel, [sx + .12, .42, -1.5], [sx + .35, .36, -1.5], .02, 8);

  // ---- press: gearbox, die chamber, door, discharge chute ----
  const g0 = .45, gt = 4.6, gz0 = -2.2, gz1 = 2.4;
  add(Pr, bboxG(3.6, gt - g0, gz1 - gz0, .12), M.teal, [0, (g0 + gt) / 2, (gz0 + gz1) / 2]); add(Pr, boxG(3.9, .1, 4.9), M.teal, [0, g0 + .05, .1]);
  for (const a of [-1, 1]) for (const b of [-1, 1]) for (const k of [0, 1]) nut(Pr, [a * 1.85, g0 + .1, b * 2.35 + .1 - b * k * .7], [0, 1, 0], .045, .04);
  add(Pr, boxG(3.7, .08, 4.7), M.teal, [0, 3.0, .1]); for (let i = 0; i < 9; i++) for (const s of [-1, 1]) { nut(Pr, [s * 1.85, 3.04, -2.0 + i * .52], [0, 1, 0], .035, .03); nut(Pr, [-1.6 + i * .4, 3.04, s * 2.35 + .1], [0, 1, 0], .035, .03); }
  for (const s of [-1, 1]) for (let k = 0; k < 10; k++) add(Pr, boxG(.16, 3.0, .035), M.teal, [s * 1.88, 2.45, .05 + k * .24]);
  add(Pr, bboxG(2.4, .12, 3.0, .03), M.teal, [0, gt + .06, .3]); for (const z of [-.8, 1.4]) add(Pr, new THREE.TorusGeometry(.1, .03, 8, 18), M.steel, [0, gt + .2, z]);
  add(Pr, cylG(.06, .06, .14, 12), M.dark, [.8, gt + .19, 1.2]); add(Pr, new THREE.SphereGeometry(.08, 12, 8), M.dark, [.8, gt + .29, 1.2]);
  add(Pr, alongX(cylG(.12, .12, .04, 24)), M.brass, [1.82, 1.4, -1.2]); dialFace(Pr, 'OilSight', T.label('OIL', '#d8b04a'), [1.84, 1.4, -1.2], .09, [1, 0, 0], Gl);
  add(Pr, alongZ(cylG(1.45, 1.45, 1.35, 72, true)), M.teal, [0, 3.0, -2.875]); add(Pr, alongZ(cylG(1.4, 1.4, 1.34, 72, true)), M.holeBack, [0, 3.0, -2.875]);
  add(Pr, new THREE.CircleGeometry(1.4, 48).rotateY(PI), M.hole, [0, 3.0, -2.205]);
  add(Pr, latheZ(ringProf(1.38, 1.55, .06, .01), 72), M.teal, [0, 3.0, -3.58]);
  for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; if (Math.sin(a) < -.3) continue; add(Pr, boxG(.06, .3, 1.3), M.teal, [1.58 * Math.cos(a), 3.0 + 1.58 * Math.sin(a), -2.87], [0, 0, a - PI / 2]); }
  add(Pr, latheZ(ringProf(1.0, 1.5, .12, .03), 72), M.teal, [0, 3.0, -3.67]); boltRing(Pr, [0, 3.0, -3.73], [0, 0, -1], 1.1, 18, .03, .025);
  add(Pr, new THREE.TorusGeometry(1.01, .025, 8, 64), M.rubber, [0, 3.0, -3.735]);
  add(Gl, new THREE.CircleGeometry(1.02, 64).rotateY(PI), M.glass, [0, 3.0, -3.66]);
  for (const y of [2.3, 3.7]) { add(Pr, cylG(.06, .06, .3, 14), M.steel, [1.58, y, -3.67]); add(Pr, boxG(.18, .2, .06), M.steel, [1.46, y, -3.67]); }
  for (const a of [150, 180, 210]) { const r = a * DEG, x = 1.42 * Math.cos(r), y = 3.0 + 1.42 * Math.sin(r); add(Pr, boxG(.1, .12, .1), M.steel, [x, y, -3.72]); pipe(Pr, M.steel, [x, y, -3.74], [x, y, -3.86], .02, 8); pipe(Pr, M.black, [x, y - .08, -3.86], [x, y + .08, -3.86], .025, 8); }
  add(Pr, bboxG(.8, .25, .7, .03), M.teal, [0, 1.42, -2.9]); add(Pr, plane(.6, .5).rotateX(PI / 2), M.hole, [0, 1.294, -2.9]);
  const chz = [-3.15, -2.65]; prismXY(Pr, M.galv, [[-.35, 1.07], [1.95, .85], [1.95, .89], [-.35, 1.11]], chz[0], chz[1]);
  for (const z of chz) prismXY(Pr, M.galv, [[-.35, 1.07], [1.95, .85], [1.95, 1.1], [-.35, 1.32]], z - (z < -2.9 ? .03 : 0), z + (z < -2.9 ? 0 : .03));
  for (const x of [.2, 1.5]) for (const z of chz) add(Pr, boxG(.06, 1.05 - (x - -.35) * .096 - PT - .01, .06), M.galv, [x, PT + (1.05 - (x + .35) * .096 - PT) / 2, z]);

  // ---- die: ring die + two rollers, origin on axis (axis Z) ----
  Di.position.set(0, 3.0, -2.9);
  add(Di, latheZ(ringProf(.85, 1.15, .6, .03), 112), P.die);
  add(Di, latheZ(ringProf(1.0, 1.3, .1, .02), 112), M.steel, [0, 0, .35]); boltRing(Di, [0, 0, .3], [0, 0, -1], 1.22, 20, .035, .03);
  add(Di, latheZ([[0, -.3], [.18, -.3], [.18, .3], [0, .3]], 24), M.steel); add(Di, hexG(.14, .08).rotateX(PI / 2), M.bolt, [0, 0, -.34]);
  add(Di, latheZ([[.15, .22], [.62, .22], [.62, .3], [.15, .3]], 48), M.iron);
  for (const a of [PI / 6, PI / 6 + PI]) { const x = .49 * Math.cos(a), y = .49 * Math.sin(a);
    add(Di, latheZ(ringProf(.1, .36, .46, .02), 56), P.roller, [x, y, 0]); add(Di, latheZ([[0, -.28], [.22, -.28], [.22, -.24], [0, -.24]], 32), M.steel, [x, y, 0]);
    for (let k = 0; k < 4; k++) { const b = k / 4 * TAU; add(Di, hexG(.025, .02).rotateX(PI / 2), M.bolt, [x + .15 * Math.cos(b), y + .15 * Math.sin(b), -.29]); }
    add(Di, latheZ([[0, -.24], [.1, -.24], [.1, .25], [0, .25]], 16), M.steel, [x, y, 0]); }
  for (const a of [PI / 2 + PI / 6, -PI / 2 + PI / 6]) add(Di, boxG(.04, .3, .4), M.steel, [.72 * Math.cos(a), .72 * Math.sin(a), 0], [0, 0, a]);

  // ---- drive: main motor, coupling + guard ----
  const my = 1.85;
  add(Dr, alongZ(cylG(1.05, 1.05, 2.8, 64)), M.teal, [0, my, 4.8]);
  for (let i = 0; i < 44; i++) { const a = i / 44 * TAU; if (Math.sin(a) < -.6) continue; add(Dr, boxG(.03, .15, 2.6), M.teal, [1.12 * Math.cos(a), my + 1.12 * Math.sin(a), 4.8], [0, 0, a - PI / 2]); }
  add(Dr, latheZ([[.5, 0], [.9, .12], [1.05, .25]], 56), M.teal, [0, my, 3.15]);
  add(Dr, latheZ([[1.08, 0], [1.08, .3], [.92, .42], [0, .46]], 56), M.teal, [0, my, 6.2]); for (let i = 0; i < 16; i++) { const a = i / 16 * TAU; add(Dr, boxG(.03, .3, .02), M.hole, [.6 * Math.cos(a), my + .6 * Math.sin(a), 6.65], [0, 0, a]); }
  for (const s of [-1, 1]) { add(Dr, bboxG(.35, .5, 2.4, .03), M.teal, [s * .75, .7, 4.8]); for (const z of [3.9, 5.7]) nut(Dr, [s * .75, .95, z], [0, 1, 0], .045, .04); }
  add(Dr, bboxG(.6, .45, .7, .03), M.teal, [.55, 3.1, 4.3]); gland(Dr, [.55, 3.325, 4.1], [0, 1, 0], .05); gland(Dr, [.55, 3.325, 4.5], [0, 1, 0], .05);
  for (const z of [3.8, 5.8]) add(Dr, new THREE.TorusGeometry(.1, .03, 8, 18), M.steel, [-.4, my + 1.12, z]);
  sticker(Dr, label('MotorPlate', T.namePlate('MAIN MOTOR', '132 kW · 400 V · 1480 rpm', 'IE3 · IP55 · class F', '#c9ccc8', '#1f6f6c')), .5, .25, [.856, 3.1, 4.3], PI / 2);
  pipe(Dr, M.steel, [0, my, gz1], [0, my, 3.16], .14, 18);
  for (const z of [2.6, 2.82]) add(Dr, latheZ([[.14, 0], [.38, 0], [.38, .15], [.14, .15]], 32), M.iron, [0, my, z]); boltRing(Dr, [0, my, 2.75], [0, 0, 1], .3, 8, .03, .03);
  add(Dr, alongZ(cylG(.55, .55, .75, 32, true, PI / 2, PI)), M.yellow, [0, my, 2.78]); for (const s of [-1, 1]) add(Dr, plane(.75, .55), M.guard, [s * .55, my - .27, 2.78], [0, PI / 2, 0]);
  add(Dr, boxG(1.15, .04, .75), M.yellow, [0, my - .56, 2.78]); for (const s of [-1, 1]) add(Dr, boxG(.04, .56, .04), M.yellow, [s * .55, my - .28, 2.42]);
  sticker(Dr, P.rot, .26, .3, [.556, my + .02, 2.78], PI / 2);

  // ---- cooler line: bucket elevator, cooler, airlock, fan, duct, cyclone, vent stack ----
  const ex = 2.4, ez = -3.0;
  add(Co, bboxG(.9, 1.0, 1.1, .03), M.teal, [ex, .8, ez]); add(Co, plane(.4, .3), M.hole, [1.948, .88, ez], [0, -PI / 2, 0]);
  add(Co, boxG(.6, 11.6, .9), M.teal, [ex, 7.1, ez]); for (let y = 2.0; y < 12.8; y += 1.2) add(Co, boxG(.68, .06, .98), M.teal, [ex, y, ez]);
  for (const y of [2.6, 11.6]) { add(Co, bboxG(.04, .5, .5, .01), M.teal, [ex - .32, y, ez]); for (const a of [-1, 1]) for (const b of [-1, 1]) nut(Co, [ex - .34, y + a * .2, ez + b * .2], [-1, 0, 0], .02, .015); }
  add(Co, bboxG(.9, .65, 1.1, .03), M.teal, [ex, 13.225, ez]); add(Co, alongZ(cylG(.45, .45, 1.1, 24, false, PI / 2, PI)), M.teal, [ex, 13.55, ez]);
  add(Co, boxG(.5, .06, .6), M.galv, [ex + .7, 12.95, ez]); add(Co, bboxG(.35, .4, .4, .03), M.iron, [ex + .62, 13.2, ez]); add(Co, alongX(cylG(.2, .2, .55, 24)), M.teal, [ex + 1.05, 13.2, ez]); add(Co, latheX([[.2, 0], [.2, .06], [0, .1]], 18), M.teal, [ex + 1.32, 13.2, ez]);
  pipe(Co, M.teal, [2.95, 12.95, -2.8], [4.2, 7.95, -1.4], .13, 20);
  for (const y of [4.0, 6.5]) beam(Co, M.galv, [2.7, y, -2.6], [3.05, y, -1.95], .08, .08); beam(Co, M.galv, [2.1, 9.3, -3.3], [1.78, 9.3, -3.86], .08, .08);
  add(Co, bboxG(2.4, 4.8, 2.4, .04), M.teal, [4.2, 5.0, -.8]); for (const y of [3.8, 5.0, 6.2]) add(Co, boxG(2.48, .06, 2.48), M.teal, [4.2, y, -.8]);
  add(Co, boxG(.45, 1.9, .03), M.teal, [4.7, 5.2, -2.01]); add(Co, plane(.33, 1.78), P.levelWin, [4.7, 5.2, -2.027], [0, PI, 0]);
  for (const y of [4.0, 6.6]) add(Co, alongZ(cylG(.06, .06, .15, 14)), M.dark, [3.6, y, -2.07]);
  louvre(Co, [2.995, 3.2, -.8], 2.0, .6, [-1, 0], M.teal); louvre(Co, [5.405, 3.2, -.8], 2.0, .6, [1, 0], M.teal);
  add(Co, frustumG(.5, .5, 2.4, 2.4, .8), M.teal, [4.2, 2.2, -.8]); add(Co, bboxG(.5, .25, .5, .02), M.iron, [4.2, 1.675, -.8]); add(Co, alongZ(cylG(.1, .1, .25, 14)), M.teal, [4.2, 1.675, -.4]);
  for (const [x, z] of [[3.05, -2.05], [5.35, -2.05], [3.05, .45], [5.35, .45]]) { add(Co, boxG(.14, 2.6 - PT, .14), M.galv, [x, PT + 1.15, z]); add(Co, boxG(.28, .02, .28), M.galv, [x, PT + .01, z]); anchor(Co, x, PT + .02, z + (z > 0 ? .09 : -.09)); beam(Co, M.galv, [x, 2.55, z], [x + (x < 4 ? .2 : -.2), 2.6, z + (z > 0 ? -.2 : .2)], .06, .06); }
  add(Co, bboxG(.6, .4, .6, .03), M.iron, [4.2, 7.6, -1.4]); add(Co, alongX(cylG(.12, .12, .3, 16)), M.teal, [4.65, 7.6, -1.4]);
  duct(Co, M.galv, [[5.0, 7.42, -.2], [5.0, 8.4, -.2], [5.0, 8.4, -4.75], [-1.3, 8.4, -4.75], [-1.3, 6.9, -4.75]], .22, .35, 24, 8);
  add(Co, alongX(cylG(.4, .4, .7, 36)), M.teal, [3.6, 8.4, -4.75]); for (const x of [3.25, 3.95]) add(Co, alongX(cylG(.46, .46, .05, 36)), M.teal, [x, 8.4, -4.75]);
  add(Co, alongZ(cylG(.22, .22, .5, 24)), M.teal, [3.6, 8.4, -5.35]); add(Co, boxG(.14, 7.6 - PT, .14), M.galv, [3.6, PT + (7.6 - PT) / 2, -4.75]); add(Co, boxG(.5, .06, .5), M.galv, [3.6, 7.97, -4.75]); add(Co, boxG(.28, .02, .28), M.galv, [3.6, PT + .01, -4.75]);
  for (const x of [-1.0, 1.5]) add(Co, boxG(.06, 9.4 - 8.65, .06), M.galv, [x, 9.025, -4.75]);
  sticker(Co, label('FanLabel', T.label('EXHAUST FAN', '#1f6f6c', '#fff')), .45, .11, [3.6, 8.4, -5.155], PI);
  add(Co, boxG(.9, .5, .3), M.teal, [-1.75, 6.65, -4.75]);
  const cx = -2.4, ccz = -5.2;
  add(Co, cylG(.6, .6, 2.0, 48), M.teal, [cx, 6.2, ccz]); add(Co, cylG(.6, .15, 1.4, 48, true), M.teal, [cx, 4.5, ccz]); add(Co, bboxG(.4, .4, .4, .03), M.iron, [cx, 3.6, ccz]); add(Co, alongX(cylG(.1, .1, .25, 14)), M.teal, [cx + .32, 3.6, ccz]);
  pipe(Co, M.galv, [cx, 3.4, ccz], [cx, 1.2, ccz], .1, 14); add(Co, cylG(.35, .35, .9, 28), M.galv, [cx, PT + .45, ccz]);
  add(Co, new THREE.TorusGeometry(.64, .035, 6, 40).rotateX(PI / 2), M.galv, [cx, 5.6, ccz]);
  for (let i = 0; i < 4; i++) { const a = PI / 4 + i * PI / 2, x = cx + .66 * Math.cos(a), z = ccz + .66 * Math.sin(a); beam(Co, M.galv, [x, PT, z], [x, 5.6, z], .08, .08); add(Co, boxG(.2, .02, .2), M.galv, [x, PT + .01, z]); }
  add(Co, cylG(.3, .3, 5.0, 40, true), M.galv, [cx, 9.7, ccz]); add(Co, cylG(.27, .27, 1.0, 40, true), M.holeBack, [cx, 11.7, ccz]); add(Co, new THREE.RingGeometry(.27, .3, 40).rotateX(-PI / 2), M.galv, [cx, 12.2, ccz]);
  for (const y of [7.25, 9.0, 11.0]) { add(Co, revolve(ringProf(.3, .38, .05, .01), 40), M.galv, [cx, y, ccz]); boltRing(Co, [cx, y + .025, ccz], [0, 1, 0], .34, 8, .02, .02); }
  for (let i = 0; i < 3; i++) { const a = i / 3 * TAU; beam(Co, M.galv, [cx + .3 * Math.cos(a), 12.18, ccz + .3 * Math.sin(a)], [cx + .42 * Math.cos(a), 12.62, ccz + .42 * Math.sin(a)], .03, .03); }
  add(Co, cylG(0, .55, .25, 36), M.galv, [cx, 12.75, ccz]); add(Co, cylG(.55, .55, .04, 36, true), M.galv, [cx, 12.61, ccz]);
  beam(Co, M.galv, [cx + .25, 9.8, ccz - .18], [-1.7, 9.4, -6.92], .04, .04);
  add(Co, cylG(.305, .305, .8, 40, true), M.sootCh, [cx, 11.8, ccz]);
  sticker(Co, P.hot, .38, .44, [3.6, 4.4, -2.012], PI);

  // ---- vibrating screen + fines return ----
  const sa = -4 * DEG, scx = 4.5, scy = 1.1, scz = -.55, sbot = x => scy - .175 + (x - scx) * Math.tan(sa);
  { const s = sub(Sc, [scx, scy, scz]); s.rotation.z = sa;
    for (const k of [-1, 1]) { add(s, boxG(3.0, .35, .06), M.teal, [0, 0, k * .83]); for (let i = 0; i < 6; i++) nut(s, [-1.25 + i * .5, .1, k * .865], [0, 0, k], .025, .02); }
    add(s, flat(2.9, 1.6), M.guard, [0, .05, 0]); add(s, boxG(2.9, .03, 1.6), M.dark, [0, -.12, 0]); add(s, boxG(.06, .35, 1.66), M.teal, [-1.5, 0, 0]); add(s, boxG(.15, .04, 1.6), M.teal, [1.55, .02, 0]);
    for (const k of [-1, 1]) { add(s, alongZ(cylG(.15, .15, .3, 20)), M.teal, [0, 0, k * 1.01]); add(s, boxG(.2, .2, .04), M.iron, [0, 0, k * .88]); } }
  for (const x of [3.2, 5.8]) for (const z of [-1.3, .2]) { const top = sbot(x) - .2; add(Sc, boxG(.12, top - PT, .12), M.galv, [x, PT + (top - PT) / 2, z]); add(Sc, helixG(.08, .014, 5, top, sbot(x), 80, 5), M.steel, [x, 0, z]); add(Sc, boxG(.24, .02, .24), M.galv, [x, PT + .01, z]); }
  add(Sc, frustumG(.3, .3, .9, .9, .32), M.teal, [4.0, sbot(4.0) - .16, scz]); pipe(Sc, M.galv, [4.0, sbot(4.0) - .32, scz], [4.0, .6, scz], .08, 12);
  add(Sc, tubeG([[4.0, .6, scz], [3.7, .52, -1.5], [3.25, .58, -2.4], [2.87, .75, -2.95]], .08, 12, .3), M.galv);
  sticker(Sc, label('ScreenLabel', T.label('VIBRATING SCREEN', '#e8e8e2')), .6, .13, [4.5, scy, scz - .865], PI);

  // ---- outfeed belt + crate at OUT ----
  const T0 = new V3(5.7, .88, 0), T1 = new V3(8.15, 2.05, 0), bd = T1.clone().sub(T0), bL = bd.length(), ba = Math.atan2(bd.y, bd.x), bm = T0.clone().lerp(T1, .5);
  { const s = sub(Ou, bm); s.rotation.z = ba;
    add(s, boxG(bL, .03, .6), M.rubber, [0, 0, 0]); for (const k of [-1, 1]) { add(s, boxG(bL, .18, .04), M.teal, [0, -.09, k * .36]); add(s, boxG(bL, .1, .03), M.yellow, [0, .09, k * .33]); }
    for (let i = 0; i < 5; i++) add(s, alongZ(cylG(.045, .045, .66, 12)), M.steel, [-bL / 2 + .3 + i * .52, -.06, 0]);
    for (const k of [-1, 1]) { add(s, alongZ(cylG(.1, .1, .62, 18)), M.iron, [k * bL / 2, -.085, 0]); add(s, alongZ(cylG(.025, .025, .8, 8)), M.steel, [k * bL / 2, -.085, 0]); }
    add(s, bboxG(.25, .25, .25, .02), M.iron, [bL / 2 - .15, -.1, .52]); add(s, alongX(cylG(.12, .12, .35, 16)), M.teal, [bL / 2 - .5, -.1, .52]);
    for (let i = 0; i < 3; i++) add(s, flat(.3, .3), label('Chevron', T.label('›', '#e2ae14', '#e2ae14')), [-bL / 2 + .6 + i * .7, .017, 0]); }
  const by = x => T0.y + (x - T0.x) * Math.tan(ba) - .2;
  for (const x of [5.9, 7.25]) for (const k of [-1, 1]) { add(Ou, boxG(.08, by(x) - PT, .08), M.galv, [x, PT + (by(x) - PT) / 2, k * .36]); add(Ou, boxG(.16, .02, .16), M.galv, [x, PT + .01, k * .36]); }
  { const s = sub(Ou, [8.15, PT, 0]);
    for (const a of [-1, 1]) for (const b of [-1, 1]) add(s, boxG(.1, 1.4, .1), M.timber, [a * .7, .7, b * .7]);
    for (const y of [.18, .52, .86, 1.2]) for (const k of [-1, 1]) { add(s, boxG(1.5, .2, .04), M.timber, [0, y, k * .73], [rr(-.01, .01), 0, rr(-.006, .006)]); add(s, boxG(.04, .2, 1.42), M.timber, [k * .73, y, 0]); }
    add(s, boxG(1.4, .06, 1.4), M.timber, [0, .05, 0]); for (const z of [-.6, 0, .6]) add(s, boxG(1.5, .08, .12), M.timber, [0, -.0 + .04, z]);
    for (const a of [-1, 1]) for (const b of [-1, 1]) for (const y of [.18, .86]) nut(s, [a * .7, y, b * .755], [0, 0, b], .02, .01);
    add(s, plane(.9, .28), P.stencil, [0, .7, -.754], [0, PI, 0]); }

  // ---- pellets ----
  add(Pe, flat(1.38, 1.38), P.pellet, [8.15, PT + 1.25, 0]);
  const pz = (x, z) => .12 * Math.max(0, 1 - (x * x + z * z) / .5);
  for (let i = 0; i < 380; i++) { const x = rr(-.64, .64), z = rr(-.64, .64); add(Pe, pel(), P.pelletSolid, [8.15 + x, PT + 1.28 + pz(x, z) + rr(0, .02), z], [PI / 2 + rr(-.3, .3), 0, rr(0, PI)]); }
  for (let i = 0; i < 12; i++) { const t = i / 11; add(Pe, pel(), P.pelletSolid, [8.27 + t * .12 + rr(-.03, .03), 2.0 - t * .55, rr(-.08, .08)], [rr(0, PI), rr(0, PI), 0]); }
  for (let i = 0; i < 46; i++) { const t = rr(.05, .95), p = T0.clone().lerp(T1, t); add(Pe, pel(), P.pelletSolid, [p.x - Math.sin(ba) * .045, p.y + Math.cos(ba) * .045, rr(-.24, .24)], [PI / 2, 0, rr(0, PI)]); }
  for (let i = 0; i < 14; i++) add(Pe, pel(), P.pelletSolid, [rr(-.08, .08), 1.27 - i * .013, -2.9 + rr(-.08, .08)], [rr(0, PI), rr(0, PI), 0]);
  for (let i = 0; i < 36; i++) { const x = rr(-.25, 1.85); add(Pe, pel(), P.pelletSolid, [x, 1.11 - (x + .35) * .096 + .03, rr(-3.08, -2.72)], [PI / 2, 0, rr(0, PI)]); }
  for (let i = 0; i < 26; i++) add(Pe, pel(), P.pelletSolid, [rr(7.2, 8.9), PT + .028, rr(-1.0, 1.0) + (rnd() < .5 ? -0 : 0)], [PI / 2, 0, rr(0, PI)]);
  for (let i = 0; i < 18; i++) add(Pe, pel(), P.pelletSolid, [rr(3.5, 5.6), PT + .028, rr(-1.6, .2)], [PI / 2, 0, rr(0, PI)]);

  // ---- platform + ladder ----
  const px0 = -7.2, px1 = -3.4, pz0 = -5.6, pz1 = -3.8, py = 5.4;
  for (const z of [pz0, pz1]) add(Pl, boxG(px1 - px0, .15, .08), M.galv, [(px0 + px1) / 2, py - .075, z]); for (const x of [px0, px1]) add(Pl, boxG(.08, .15, pz1 - pz0), M.galv, [x, py - .075, (pz0 + pz1) / 2]);
  add(Pl, flat(px1 - px0 - .08, pz1 - pz0 - .08), P.grating, [(px0 + px1) / 2, py - .004, (pz0 + pz1) / 2]); for (let x = px0 + .5; x < px1; x += .5) add(Pl, boxG(.03, .1, pz1 - pz0 - .08), M.galv, [x, py - .06, (pz0 + pz1) / 2]);
  for (const [x, z] of [[px0, pz0], [px1, pz0], [px0, pz1], [px1, pz1]]) { add(Pl, boxG(.12, py - .15 - PT, .12), M.galv, [x, PT + (py - .15 - PT) / 2, z]); add(Pl, boxG(.26, .02, .26), M.galv, [x, PT + .01, z]); anchor(Pl, x + (x < -5 ? -.08 : .08), PT + .02, z); }
  beam(Pl, M.galv, [px0, .6, pz0], [px1, py - .2, pz0], .06, .06); beam(Pl, M.galv, [px1, .6, pz0], [px0, py - .2, pz0], .06, .06);
  const rail = (a, b) => { const A = v3(a), Bp = v3(b), L = A.distanceTo(Bp), n = Math.max(1, Math.round(L / 1.2));
    for (let i = 0; i <= n; i++) { const p = A.clone().lerp(Bp, i / n); add(Pl, boxG(.05, 1.1, .05), M.yellow, [p.x, py + .55, p.z]); }
    for (const y of [py + 1.1, py + .55]) pipe(Pl, M.yellow, [A.x, y, A.z], [Bp.x, y, Bp.z], .025, 8); const c = A.clone().lerp(Bp, .5); add(Pl, boxG(Math.abs(Bp.x - A.x) + .02, .1, Math.abs(Bp.z - A.z) + .02), M.yellow, [c.x, py + .05, c.z]); };
  rail([px0, 0, pz0], [px1, 0, pz0]); rail([px1, 0, pz0], [px1, 0, pz1]); rail([px0, 0, pz0], [px0, 0, -5.0]); rail([px0, 0, -4.4], [px0, 0, pz1]); rail([px0, 0, pz1], [-6.0, 0, pz1]); rail([-4.6, 0, pz1], [px1, 0, pz1]);
  const lx = -7.35; for (const z of [-4.95, -4.45]) add(Pl, boxG(.06, 6.5 - PT, .06), M.yellow, [lx, PT + (6.5 - PT) / 2, z]);
  for (let y = .6; y < py; y += .3) pipe(Pl, M.galv, [lx, y, -4.95], [lx, y, -4.45], .018, 8);
  for (let y = 2.6; y < 6.5; y += .7) add(Pl, new THREE.TorusGeometry(.4, .02, 4, 18, PI).rotateX(PI / 2).rotateY(-PI / 2), M.yellow, [lx, y, -4.7]);
  for (const [x, z] of [[lx - .4, -4.7], [lx, -5.1], [lx, -4.3]]) add(Pl, boxG(.04, 3.9, .04), M.yellow, [x, 4.55, z]);

  // ---- hoist gantry over the die ----
  for (const [x, z] of [[-1.7, -7.0], [1.7, -7.0], [-1.7, -3.9], [1.7, -3.9]]) { add(Ho, boxG(.18, 9.4 - PT, .16), M.yellow, [x, PT + (9.4 - PT) / 2, z]); add(Ho, boxG(.36, .03, .36), M.yellow, [x, PT + .015, z]); for (const a of [-1, 1]) anchor(Ho, x + a * .13, PT + .03, z + a * .13); }
  for (const z of [-7.0, -3.9]) { add(Ho, boxG(3.58, .25, .18), M.yellow, [0, 9.275, z]); for (const s of [-1, 1]) beam(Ho, M.yellow, [s * 1.7, 8.6, z], [s * 1.1, 9.15, z], .08, .08); }
  add(Ho, boxG(.25, .03, 3.5), M.yellow, [0, 9.135, -5.5]); add(Ho, boxG(.03, .34, 3.5), M.yellow, [0, 8.95, -5.5]); add(Ho, boxG(.25, .03, 3.5), M.yellow, [0, 8.765, -5.5]); for (const z of [-7.2, -3.8]) add(Ho, boxG(.25, .15, .04), M.red, [0, 8.68, z]);
  const hz0 = -5.6;
  for (const s of [-1, 1]) { add(Ho, boxG(.03, .32, .36), M.red, [s * .17, 8.72, hz0]); for (const k of [-1, 1]) add(Ho, alongX(cylG(.05, .05, .05, 14)), M.steel, [s * .135, 8.83, hz0 + k * .12]); }
  add(Ho, boxG(.34, .05, .3), M.red, [0, 8.55, hz0]); add(Ho, bboxG(.34, .4, .3, .04), M.yellow, [0, 8.3, hz0]); add(Ho, alongX(cylG(.18, .18, .06, 24)), M.red, [.2, 8.3, hz0]); add(Ho, new THREE.TorusGeometry(.22, .015, 6, 28).rotateY(PI / 2), M.steel, [.27, 8.3, hz0]);
  sticker(Ho, label('HoistCap', T.label('SWL 2 t', '#e2ae14')), .3, .08, [0, 8.3, hz0 - .152], PI);
  for (let i = 0; i < 18; i++) { const y = 8.08 - i * .07; add(Ho, new THREE.TorusGeometry(.035, .011, 5, 12).rotateY(i % 2 ? PI / 2 : 0), M.steel, [0, y, hz0]); }
  add(Ho, bboxG(.14, .2, .1, .02), M.yellow, [0, 6.7, hz0]); add(Ho, new THREE.TorusGeometry(.1, .03, 8, 18, 1.5 * PI).rotateZ(-PI / 4), M.steel, [0, 6.5, hz0]);
  for (const k of [-1, 1]) add(Ho, tubeG([[.27, 8.3 - .22, hz0 + k * .02], [.27, 7.0, hz0 + k * .14], [.27, 6.2, hz0 + k * .14]], .01, 4), M.steel);
  add(Ho, new THREE.TorusGeometry(.14, .01, 4, 16).rotateY(PI / 2), M.steel, [.27, 6.2 - .0, hz0]);

  // ---- controls + cable trays ----
  add(Ct, boxG(2.5, .1, .8), M.concrete, [5.6, PT + .05, 3.0]); add(Ct, bboxG(2.4, 2.2, .7, .03), M.teal, [5.6, 1.5, 3.0]);
  add(Ct, boxG(.9, .5, .02), M.black, [5.6, 2.15, 2.64]); sticker(Em, lcd('Screen', T.lcd(['AMPS  182 A', 'DIE   74 °C'], '#0b1a20', '#7cf0c0')), .82, .41, [5.6, 2.15, 2.628], PI);
  [M.emG, M.emA, M.emR].forEach((m, i) => { const x = 5.1 + i * .3; add(Ct, alongZ(cylG(.07, .07, .03, 18)), M.steel, [x, 1.7, 2.64]); add(Em, latheZ([[0, 0], [.05, 0], [.05, .015], [0, .035]], 16).rotateY(PI), m, [x, 1.7, 2.625]); });
  add(Ct, alongZ(cylG(.13, .13, .02, 24)), M.yellow, [6.4, 1.55, 2.64]); add(Ct, latheZ([[0, 0], [.1, 0], [.11, .04], [.1, .08], [0, .09]], 20).rotateY(PI), M.red, [6.4, 1.55, 2.63]);
  for (const x of [6.2, 6.55]) { add(Ct, alongZ(cylG(.06, .06, .04, 16)), M.black, [x, 2.15, 2.635]); add(Ct, boxG(.02, .08, .03), M.steel, [x, 2.15, 2.61]); }
  add(Ct, boxG(.05, .35, .05), M.steel, [4.55, 1.5, 2.62]); for (const y of [.8, 2.2]) add(Ct, cylG(.03, .03, .2, 8), M.steel, [6.82, y, 2.66]);
  sticker(Ct, label('SignHVc', T.signHV), .5, .375, [5.6, 1.0, 2.643], PI); louvre(Ct, [4.395, 1.0, 3.0], .5, .5, [-1, 0], M.teal);
  for (const dx of [-.5, 0, .5]) gland(Ct, [5.6 + dx, 2.6, 3.1], [0, 1, 0], .05);
  const tray = (a, b) => { const A = v3(a), Bp = v3(b), dv = Bp.clone().sub(A), L = dv.length(), hzA = Math.abs(dv.y) < .01, sideV = hzA ? (Math.abs(dv.x) > .01 ? new V3(0, 0, 1) : new V3(1, 0, 0)) : new V3(1, 0, 0);
    for (const k of [-1, 1]) beam(Ct, M.galv, A.clone().addScaledVector(sideV, k * .2), Bp.clone().addScaledVector(sideV, k * .2), .02, .08);
    const n = Math.floor(L / .3); for (let i = 1; i < n; i++) { const p = A.clone().lerp(Bp, i / n); add(Ct, sideV.z ? boxG(.03, .015, .4) : boxG(.4, .015, .03), M.galv, [p.x, p.y - (hzA ? .03 : 0), p.z]); } };
  tray([5.6, 2.7, 3.0], [5.6, 4.8, 3.0]); tray([5.6, 4.8, 3.0], [-3.0, 4.8, 3.0]); tray([-3.0, 4.8, 3.0], [-3.0, 4.8, -1.8]);
  for (const [x, z] of [[3.6, 3.0], [1.4, 3.0], [-2.2, 3.0], [-3.0, 1.2], [-3.0, -1.6]]) { add(Ct, boxG(.08, 4.75 - PT, .08), M.galv, [x, PT + (4.75 - PT) / 2, z + (x === -3.0 ? 0 : .3)]); add(Ct, boxG(.08, .06, .5), M.galv, [x, 4.74, z + (x === -3.0 ? 0 : .15)]); add(Ct, boxG(.2, .02, .2), M.galv, [x, PT + .01, z + (x === -3.0 ? 0 : .3)]); }
  for (const k of [-1, 0, 1]) add(Ct, tubeG([[5.6 + k * .08, 2.7, 3.0], [5.6 + k * .08, 4.82, 3.0 + k * .06], [-2.9, 4.82, 3.0 + k * .06], [-3.0 + k * .06, 4.82, -1.7]], .025, 6, .05), M.cable);
  add(Ct, tubeG([[.55, 4.78, 3.0], [.55, 4.1, 3.5], [.55, 3.42, 4.1]], .04, 8), M.cable);
  add(Ct, tubeG([[-3.0, 4.82, -1.7], [-3.4, 5.6, -2.0], [-5.2, 6.4, -2.15], [-6.1, 6.33, -2.6]], .03, 8, .3), M.cable); add(Ct, tubeG([[-3.0, 4.82, -1.75], [-3.8, 6.4, -2.1], [-6.0, 7.6, -2.3], [-6.4, 7.63, -2.75]], .03, 8, .3), M.cable);

  // ---- details: spare die on pallet, signs ----
  { const s = sub(De, [7.0, PT, 6.0]); for (let i = 0; i < 5; i++) add(s, boxG(1.6, .03, .25), M.timber, [0, .135, -.68 + i * .34]); for (const a of [-1, 0, 1]) for (const b of [-1, 0, 1]) add(s, boxG(.2, .1, .2), M.timber, [a * .7, .07, b * .7]); for (const b of [-1, 0, 1]) add(s, boxG(1.6, .02, .2), M.timber, [0, .01, b * .7]);
    add(s, revolve(ringProf(.85, 1.15, .6, .03), 80), P.die, [0, .45, 0]); for (const k of [-1, 1]) add(s, boxG(.05, .62, 2.34), M.red, [k * .25, .45, 0]); for (const k of [-1, 1]) add(s, boxG(.05, .01, .2), M.red, [k * .25, .76, 0]);
    sticker(s, label('DieTag', T.label('SPARE DIE 6 mm', '#e8e8e2')), .4, .1, [0, .45, -1.152], PI); }
  sticker(De, P.name, 1.0, .5, [-1.811, 3.7, -1.2], -PI / 2); sticker(De, P.ear, .5, .58, [1.966, 3.7, -1.25], PI / 2);
  sticker(De, P.hot, .44, .51, [-1.2, 4.25, -3.74], PI);
  add(De, flat(1.6, 1.6), M.dust, [8.0, PT + .006, -.3]);

  return finish(R);
}
export const SPEC = { id: 'PelletMill', pfx: 'PM_', size: [18, 14, 16], tri: [70000, 110000], stack: [-2.4, 12.2, -5.2],
  groups: ['Foundation', 'Infeed', 'Conditioner', 'Press', 'Die', 'Drive', 'Cooler', 'Screen', 'Outfeed', 'Platform', 'Hoist', 'Controls', 'Details', 'Straw', 'Pellets', 'Emissive', 'Glass'],
  solids: [['PM_Press', [-1.8, .45, -2.2], [1.8, 4.6, 2.4]], ['PM_Cooler', [3.0, 2.6, -2.0], [5.4, 7.4, .4]], ['PM_Controls', [4.4, .4, 2.65], [6.8, 2.6, 3.35]], ['PM_Drive', [-.74, 1.1, 3.4], [.74, 2.6, 6.2]], ['PM_Conditioner', [-4.9, 5.55, -3.35], [.9, 6.45, -2.45]]] };
