// Water + steam pack: WaterPump, WaterTank, Boiler, SteamTurbine. Shares textures, materials and helpers with the power pack.
import { THREE, V3, TAU, DEG, DS, rnd, rr, setSeed, mat, v3, boxG, bboxG, cylG, alongX, alongZ, revolve, latheX, frustumG, tubeG, add, pipe, beam, sub, duct, plane, cv, texFrom } from './power_lib.js';
import { T, M, finish, nut, boltRing, anchor, pad, gland, flat, sticker, louvre, dialFace, label, lcd, grpOf, root, wireTop } from './power_machines.js';
export { M };
const PI = Math.PI, PT = .3;

function signTex(title, subt, kind) { const W = 384, H = 448, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#f4f3ee'; x.fillRect(0, 0, W, H); x.strokeStyle = '#111'; x.lineWidth = 10; x.strokeRect(8, 8, W - 16, H - 16);
  const cx = W / 2; x.fillStyle = '#111'; x.beginPath(); x.moveTo(cx, 40); x.lineTo(cx + 125, 255); x.lineTo(cx - 125, 255); x.closePath(); x.fill(); x.fillStyle = '#f1c40f'; x.beginPath(); x.moveTo(cx, 76); x.lineTo(cx + 96, 238); x.lineTo(cx - 96, 238); x.closePath(); x.fill();
  x.strokeStyle = '#111'; x.fillStyle = '#111'; x.lineWidth = 9;
  if (kind === 'rot') { x.beginPath(); x.arc(cx - 26, 185, 30, 0, TAU); x.stroke(); x.beginPath(); x.arc(cx + 26, 185, 30, 0, TAU); x.stroke(); x.beginPath(); x.moveTo(cx + 40, 120); x.lineTo(cx + 64, 150); x.lineTo(cx + 30, 150); x.closePath(); x.fill(); }
  else { x.beginPath(); x.arc(cx, 180, 44, 0, TAU); x.stroke(); x.lineWidth = 6; x.beginPath(); x.moveTo(cx, 180); x.lineTo(cx + 26, 160); x.stroke(); for (const o of [-34, 0, 34]) { x.beginPath(); x.moveTo(cx + o, 132); x.bezierCurveTo(cx + o - 10, 118, cx + o + 10, 104, cx + o, 92); x.stroke(); } }
  x.textAlign = 'center'; const fit = (t, px, wt, y) => { let p = px; do { x.font = `${wt} ${p}px "IBM Plex Sans Condensed","Sarabun",sans-serif`; p -= 2; } while (x.measureText(t).width > W - 50 && p > 10); x.fillText(t, cx, y); };
  fit(title, 58, 700, 330); fit(subt, 34, 500, 388); return texFrom(c, true, false); }
function scaleTex() { const W = 64, H = 512, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#f2f1ea'; x.fillRect(0, 0, W, H); x.fillStyle = '#111'; x.font = '600 18px "IBM Plex Mono",monospace';
  for (let i = 0; i <= 20; i++) { const y = H - 12 - i * (H - 24) / 20; x.fillRect(0, y - 1, i % 5 ? 18 : 30, 3); if (!(i % 5)) x.fillText(String(i), 34, y + 6); } return texFrom(c, true, false); }
const W = {
  blue: mat('BandBlue', 'PaintWaterBlue', { color: 0x1f5fa8, roughness: .45, metalness: .1 }),
  vessel: mat('Vessel', 'DiaphragmTankBlue', { map: T.iron, color: 0x5d8fe0, roughness: .35, metalness: .25 }, .6),
  water: mat('Water', 'WaterColumn', { color: 0x2f78b8, roughness: .15 }),
  roof: mat('Roof', 'TinRoof', { map: T.galv, normalMap: T.galvN, roughness: .5, metalness: .6, side: DS }, .6),
  ss: mat('Stainless', 'StainlessSteel', { color: 0xc9cdce, roughness: .25, metalness: .9 }),
  grating: mat('Grating', 'FloorGrating', { map: T.mesh, color: 0x9aa0a0, alphaTest: .5, side: DS, metalness: .6, roughness: .45 }, 4),
  scale: label('GaugeScale', scaleTex()),
  hp: label('SignHighPressure', signTex('HIGH PRESSURE STEAM', 'ไอน้ำแรงดันสูง', 'press')),
  rot: label('SignRotating', signTex('ROTATING PARTS', 'ระวังชิ้นส่วนหมุน', 'rot')),
  hot: label('SignHot', T.hot),
  zap: label('SignZap', T.zap),
};
const plateM = (n, a, b, c) => label(n, T.namePlate(a, b, c, '#c9ccc8', '#1f6f6c'), { metalness: .6, roughness: .35 });
const tag = (n, t, bg = '#e8e8e2', fg) => label(n, T.label(t, bg, fg));

/* ---------- shared parts ---------- */
// Port nozzle: local +Y = outward normal; flange face exactly at y = 0 (on the machine face); bolts behind it.
function nozzle(P, c, n, kind, len = .8) { const s = sub(P, c, n), band = kind === 'steam' ? M.red : W.blue;
  add(s, revolve([[.6, -.42], [.7, -.16], [.9, -.16], [.9, 0], [.585, 0], [.585, -.3]], 48), M.galv);
  add(s, new THREE.CircleGeometry(.585, 32).rotateX(-PI / 2), M.hole, [0, -.3, 0]);
  add(s, cylG(.6, .6, len - .42, 40, true), M.galv, [0, -(len + .42) / 2, 0]);
  add(s, cylG(.905, .905, .1, 48, true), band, [0, -.08, 0]);
  if (len >= .7) add(s, cylG(.612, .612, .2, 40, true), band, [0, -.55, 0]);
  for (let i = 0; i < 8; i++) { const a = (i + .5) / 8 * TAU; nut(s, [.79 * Math.cos(a), -.16, .79 * Math.sin(a)], [0, -1, 0], .055, .05); add(s, cylG(.026, .026, .12, 6), M.bolt, [.79 * Math.cos(a), -.27, .79 * Math.sin(a)]); }
  return s; }
function flangePair(g, c, d, r, n = 4) { const s = sub(g, c, d); for (const y of [-.03, .03]) add(s, cylG(r, r, .05, 24), M.iron, [0, y, 0]); boltRing(s, [0, .055, 0], [0, 1, 0], r * .78, n, .022, .02); boltRing(s, [0, -.055, 0], [0, -1, 0], r * .78, n, .022, .02); }
function handwheel(g, c, d, R, m = M.red) { const s = sub(g, c, d); add(s, new THREE.TorusGeometry(R, R * .1, 6, 28).rotateX(PI / 2), m); for (let i = 0; i < 3; i++) add(s, boxG(R * 2, R * .08, R * .1), m, [0, 0, 0], [0, i * PI / 3, 0]); add(s, cylG(R * .2, R * .2, R * .3, 12), m); return s; }
function gateValve(g, c, axis, bon, r = .2) { // body on a pipe along `axis`, bonnet + handwheel toward `bon`
  const A = v3(axis).normalize(), B = v3(bon).normalize(), C = v3(c);
  flangePair(g, C.clone().addScaledVector(A, -r * 1.05), A, r * 1.15); flangePair(g, C.clone().addScaledVector(A, r * 1.05), A, r * 1.15);
  const b = sub(g, C, A); add(b, cylG(r, r, r * 1.9, 24), M.iron); const t = sub(g, C, B); add(t, cylG(r * .55, r * .75, r * 2.2, 16), M.iron, [0, r * 1.5, 0]); add(t, cylG(r * .7, r * .7, .05, 16), M.iron, [0, r * 2.6, 0]);
  add(t, cylG(.022, .022, r * 1.4, 8), M.steel, [0, r * 3.2, 0]); handwheel(t, [0, r * 3.8, 0], [0, 1, 0], r * 1.1); }
function checkValve(g, c, axis, r = .2) { const A = v3(axis).normalize(), C = v3(c); flangePair(g, C.clone().addScaledVector(A, -r * 1.05), A, r * 1.15); flangePair(g, C.clone().addScaledVector(A, r * 1.05), A, r * 1.15);
  const b = sub(g, C, A); add(b, cylG(r, r, r * 1.9, 24), M.iron); add(b, boxG(r * 1.1, r * .5, r * 1.1), M.iron, [0, 0, r * .9]); }
function gaugeOn(g, Gl, part, c, n, unit, max, red, r = .15) { const s = sub(g, c, n); add(s, cylG(r + .02, r + .02, .08, 32), M.dark, [0, -.04, 0]); add(s, new THREE.TorusGeometry(r + .015, .012, 6, 32).rotateX(PI / 2), M.brass, [0, 0, 0]); dialFace(g, part, T.dial(unit, max, red), v3(c).addScaledVector(v3(n).normalize(), .001), r, n, Gl); }
function insulator(g, c, h = .32) { const prof = [[.04, 0]]; const n = 3; for (let i = 0; i < n; i++) { const y = .04 + i * (h - .06) / n; prof.push([.05, y], [.12, y + .03], [.05, y + .07]); } prof.push([.05, h], [0, h]); add(g, revolve(prof, 20), M.porcelain, c); }
function corrSheet(w, d, period, amp) { const nx = Math.round(w / period) * 4, g = new THREE.PlaneGeometry(w, d, nx, 1); g.rotateX(-PI / 2); const p = g.attributes.position; for (let i = 0; i < p.count; i++) p.setY(i, amp * Math.sin(p.getX(i) / period * TAU)); g.computeVertexNormals(); return g; }
function support(g, x, z, top, w = .3) { add(g, boxG(.1, top - PT - .03, .1), M.galv, [x, PT + (top - PT - .03) / 2, z]); add(g, boxG(w, .03, w * 1.3), M.galv, [x, top - .015, z]); add(g, boxG(.26, .02, .26), M.galv, [x, PT + .01, z]); anchor(g, x + .08, PT + .02, z + .08); anchor(g, x - .08, PT + .02, z - .08); }

/* ================= 1. Water pump ================= */
export function buildWaterPump() {
  setSeed(801); const R = root('WaterPump'), G = grpOf(R, 'WP_');
  const Pd = G('Pad'), Wh = G('Wellhead'), Pu = G('Pump'), Mo = G('Motor'), Fa = G('Fan'), Pi = G('Piping'), Rf = G('Roof'), Ct = G('Controls'), De = G('Details'), Po = G('PortOut'), Em = G('Emissive'), Gl = G('Glass');
  pad(Pd, 8, 8, PT, [[-3.6, -3.6], [3.6, -3.6], [-3.6, 3.6], [3.6, 3.6], [0, -3.6], [0, 3.6], [-3.6, 0]]);
  add(Pd, flat(2.4, 2.0), M.oil, [-2.3, PT + .004, .3]); add(Pd, flat(1.2, 1.0), M.rust, [-2.4, PT + .005, -.1]); add(Pd, flat(1.6, 1.3), M.oil, [3.0, PT + .004, .5]); add(Pd, flat(1.4, 1.4), M.dust, [1.0, PT + .006, -2.4]);
  // wellhead
  const wx = -2.4;
  add(Wh, cylG(.72, .8, .14, 40), M.concrete, [wx, PT + .07, 0]);
  add(Wh, cylG(.42, .42, .56, 32), M.galv, [wx, .72, 0]);
  add(Wh, cylG(.62, .62, .08, 40), M.iron, [wx, 1.04, 0]); boltRing(Wh, [wx, 1.08, 0], [0, 1, 0], .53, 8, .04, .035);
  add(Wh, cylG(.48, .55, .06, 32), M.iron, [wx, 1.11, 0]);
  add(Wh, cylG(.22, .22, .06, 24), M.iron, [wx, 1.17, 0]); boltRing(Wh, [wx, 1.2, 0], [0, 1, 0], .18, 4, .025, .02);
  pipe(Wh, M.galv, [wx + .3, 1.14, .22], [wx + .3, 1.38, .22], .03, 10); add(Wh, cylG(.02, .09, .06, 16), M.galv, [wx + .3, 1.41, .22]);
  gland(Wh, [wx - .28, 1.14, -.22], [0, 1, 0], .035); add(Wh, tubeG([[wx - .28, 1.24, -.22], [wx - .45, 1.3, -.5], [wx - .5, .4, -.75]], .018, 6), M.cable);
  sticker(Wh, M.rust, .5, .45, [wx, .7, .424], 0); sticker(Wh, M.rust, .4, .4, [wx + .424, .72, 0], PI / 2);
  // multistage pump
  const px = .3;
  add(Pu, boxG(.95, .06, .95), M.iron, [px, PT + .03, 0]); for (const a of [-1, 1]) for (const b of [-1, 1]) nut(Pu, [px + a * .4, .36, b * .4], [0, 1, 0], .035, .03);
  add(Pu, bboxG(.9, .52, .62, .05), M.iron, [px, .62, 0]);
  for (const s of [-1, 1]) { add(Pu, alongX(cylG(.22, .22, .06, 24)), M.iron, [px + s * .48, .7, 0]); boltRing(Pu, [px + s * .51, .7, 0], [s, 0, 0], .17, 4, .025, .02); }
  add(Pu, cylG(.4, .4, .12, 32), M.iron, [px, .94, 0]); add(Pu, cylG(.3, .3, 2.2, 40), W.ss, [px, 2.1, 0]);
  for (let y = 1.25; y < 3.2; y += .3) add(Pu, new THREE.TorusGeometry(.3, .018, 6, 40).rotateX(PI / 2), W.ss, [px, y, 0]);
  add(Pu, cylG(.4, .4, .25, 32), M.iron, [px, 3.325, 0]);
  for (let i = 0; i < 4; i++) { const a = PI / 4 + i * PI / 2, x = px + .36 * Math.cos(a), z = .36 * Math.sin(a); pipe(Pu, W.ss, [x, 1.0, z], [x, 3.2, z], .025, 8); nut(Pu, [x, 3.45, z], [0, 1, 0], .04, .035); nut(Pu, [x, 1.0, z], [0, 1, 0], .04, .035); }
  for (let i = 0; i < 4; i++) { const a = i * PI / 2 + PI / 4; add(Pu, boxG(.08, .4, .08), M.iron, [px + .33 * Math.cos(a), 3.65, .33 * Math.sin(a)]); }
  add(Pu, cylG(.36, .36, .4, 24, true), M.guard, [px, 3.65, 0]); add(Pu, cylG(.12, .12, .2, 16), M.iron, [px, 3.65, 0]); add(Pu, cylG(.04, .04, .4, 8), M.steel, [px, 3.65, 0]);
  sticker(Pu, plateM('PumpPlate', 'COOP BOREHOLE PUMP', '12 m³/h · 60 m head', '8 stages · S/N 2026-0401'), .32, .16, [px, 2.4, .302], 0);
  // motor
  add(Mo, cylG(.48, .48, .08, 48), M.teal, [px, 3.89, 0]); boltRing(Mo, [px, 3.93, 0], [0, 1, 0], .42, 4, .035, .03);
  add(Mo, cylG(.42, .42, 1.37, 48), M.teal, [px, 4.615, 0]);
  for (let i = 0; i < 28; i++) { const a = i / 28 * TAU; if (Math.cos(a) > .9 || Math.sin(a) > .9) continue; add(Mo, boxG(.035, 1.2, .09), M.teal, [px + .45 * Math.cos(a), 4.6, .45 * Math.sin(a)], [0, PI / 2 - a, 0]); }
  add(Mo, bboxG(.3, .34, .36, .03), M.teal, [px + .57, 4.4, 0]); gland(Mo, [px + .6, 4.23, 0], [0, -1, 0], .045); for (const a of [-1, 1]) for (const b of [-1, 1]) nut(Mo, [px + .72, 4.4 + a * .13, b * .14], [1, 0, 0], .02, .015);
  sticker(Mo, plateM('MotorPlate', 'MOTOR 7.5 kW', '400 V · 2900 rpm · IP55', 'IE3 · class F'), .3, .15, [px, 4.9, .425], 0);
  add(Mo, cylG(.5, .42, .05, 48), M.teal, [px, 5.325, 0]); add(Mo, cylG(.5, .5, .55, 48, true), M.teal, [px, 5.625, 0]);
  add(Mo, new THREE.CircleGeometry(.5, 40).rotateX(-PI / 2), M.guard, [px, 5.9, 0]); add(Mo, new THREE.TorusGeometry(.5, .02, 6, 48).rotateX(PI / 2), M.teal, [px, 5.9, 0]);
  for (let i = 0; i < 2; i++) add(Mo, boxG(1.0, .03, .04), M.teal, [px, 5.9, 0], [0, i * PI / 2, 0]);
  for (let i = 0; i < 6; i++) { const a = i / 6 * TAU; add(Mo, boxG(.1, .3, .02), M.hole, [px + .505 * Math.cos(a), 5.6, .505 * Math.sin(a)], [0, PI / 2 - a, 0]); }
  // fan (spins about Y, origin on axis)
  Fa.position.set(px, 5.62, 0); add(Fa, cylG(.08, .08, .12, 16), M.black);
  for (let i = 0; i < 8; i++) { const s = sub(Fa, [0, 0, 0]); s.rotation.y = -i / 8 * TAU; add(s, boxG(.34, .012, .11), M.black, [.25, 0, 0], [.5, 0, 0]); }
  // piping
  duct(Pi, M.galv, [[wx, 1.2, 0], [wx, 1.6, 0], [-.75, 1.6, 0], [-.75, .7, 0], [-.21, .7, 0]], .13, .25, 20, 8);
  flangePair(Pi, [-1.6, 1.6, 0], [1, 0, 0], .22); add(Pi, alongX(cylG(.22, .22, .05, 24)), M.iron, [-.24, .7, 0]);
  duct(Pi, M.galv, [[.81, .7, 0], [1.2, .7, 0], [1.2, 1.5, 0], [2.95, 1.5, 0]], .13, .25, 20, 8);
  add(Pi, alongX(cylG(.6, .13, .25, 40)), M.galv, [3.075, 1.5, 0]);
  checkValve(Pi, [1.85, 1.5, 0], [1, 0, 0], .19); add(Pi, cylG(.13, .13, .08, 16), M.iron, [1.85, 1.72, 0]);
  gateValve(Pi, [2.6, 1.5, 0], [1, 0, 0], [0, 1, 0], .19);
  pipe(Pi, M.steel, [1.45, 1.6, 0], [1.45, 2.0, 0], .035, 10); gaugeOn(Pi, Gl, 'WpGauge', [1.45, 2.18, .045], [0, 0, 1], 'bar', 10, .7, .14); add(Pi, alongZ(cylG(.16, .16, .1, 24)), M.dark, [1.45, 2.18, -.01]);
  duct(Pi, M.galv, [[2.15, 1.38, 0], [2.15, .95, 0], [2.15, .95, 1.28]], .06, .12, 12, 6);
  // diaphragm tank
  const vz = 1.82; for (let i = 0; i < 3; i++) { const a = i / 3 * TAU; pipe(Pi, M.galv, [2.15 + .38 * Math.cos(a), PT, vz + .38 * Math.sin(a)], [2.15 + .38 * Math.cos(a), .52, vz + .38 * Math.sin(a)], .03, 6); }
  add(Pi, cylG(.55, .55, 1.1, 40), W.vessel, [2.15, 1.05, vz]); add(Pi, revolve([[.55, 0], [.48, .14], [.3, .24], [0, .27]], 40), W.vessel, [2.15, 1.6, vz]); add(Pi, revolve([[0, -.27], [.3, -.24], [.48, -.14], [.55, 0]], 40), W.vessel, [2.15, .5, vz]);
  add(Pi, cylG(.04, .04, .08, 10), M.brass, [2.15, 1.91, vz]); sticker(Pi, tag('VesselLabel', 'PRESSURE TANK 100 L', '#e8e8e2'), .5, .12, [2.15, 1.15, vz + .555], 0);
  support(Pi, 3.45, 0, .9); support(Pi, 1.85, 0, 1.29); support(Pi, -1.6, 0, 1.47);
  // roof on two posts
  const ys = z => 6.96 - (z + 2.5) * .06;
  for (const x of [-1.7, 2.3]) { add(Rf, boxG(.14, ys(-2.1) - .24 - PT, .14), M.galv, [x, PT + (ys(-2.1) - .24 - PT) / 2, -2.1]); add(Rf, boxG(.34, .03, .34), M.galv, [x, PT + .015, -2.1]); for (const k of [-1, 1]) anchor(Rf, x + k * .12, PT + .03, -2.1 + k * .12);
    beam(Rf, M.galv, [x, ys(-2.5) - .18, -2.5], [x, ys(2.5) - .18, 2.5], .1, .12); beam(Rf, M.galv, [x, ys(-2.1) - .9, -2.1], [x, ys(-.9) - .22, -.9], .06, .06); }
  for (const z of [-2.2, -.7, .7, 2.2]) add(Rf, boxG(5.2, .08, .08), M.galv, [.3, ys(z) - .08, z]);
  add(Rf, corrSheet(5.2, 5.0, .26, .035), W.roof, [.3, ys(0), 0], [Math.atan(.06), 0, 0]);
  // controls
  add(Ct, bboxG(.7, .9, .3, .03), M.ctrl, [-1.7, 2.3, -1.88]); for (const y of [2.0, 2.6]) add(Ct, cylG(.02, .02, .08, 8), M.steel, [-2.06, y, -1.73]);
  add(Ct, boxG(.02, .8, .01), M.dark, [-1.7, 2.3, -1.728]);
  add(Em, revolve([[0, 0], [.05, 0], [.05, .015], [0, .035]], 16).rotateX(PI / 2), M.emG, [-1.5, 2.58, -1.728]); add(Ct, alongZ(cylG(.07, .07, .02, 18)), M.steel, [-1.5, 2.58, -1.73]);
  for (const [y, m] of [[2.3, M.emG], [2.1, M.red]]) add(Ct, alongZ(cylG(.045, .045, .04, 14)), m === M.emG ? M.black : M.red, [-1.5, y, -1.715]);
  gaugeOn(Ct, Gl, 'WpAmps', [-1.88, 2.45, -1.727], [0, 0, 1], 'A', 20, .8, .1);
  sticker(Ct, W.zap, .2, .2, [-1.88, 2.12, -1.728], 0); sticker(Ct, tag('StarterLabel', 'PUMP STARTER'), .4, .1, [-1.7, 2.68, -1.728], 0);
  for (const x of [-1.85, -1.55]) gland(Ct, [x, 1.85, -1.88], [0, -1, 0], .035);
  add(Ct, tubeG([[-1.55, 1.8, -1.88], [-1.55, .4, -1.9], [-.2, .37, -1.0], [.92, .4, -.3], [.95, 1.3, -.28], [.95, 3.5, -.28], [.9, 4.22, -.02]], .025, 6, .3), M.cable);
  add(Ct, tubeG([[-1.85, 2.78, -1.88], [-1.85, 6.0, -1.98], [-1.2, 6.4, -.4], [-1.0, 6.42, 0]], .02, 6, .3), M.cable);
  add(Ct, boxG(.08, .06, 1.5), M.galv, [-1.0, ys(0) - .15, 0]); insulator(Ct, [-1.0, 6.2, 0], .33);
  // details
  sticker(De, tag('WellTag', 'BOREHOLE 01 · 60 m', '#1f6f6c', '#fff'), .45, .11, [wx, .8, -.425], PI);
  add(De, flat(.6, .5), M.oil, [.3, PT + .006, .7]);
  nozzle(Po, [4, 1.5, 0], [1, 0, 0], 'water', .8);
  wireTop(R, 'WP_', [-1, 6.55, 0]);
  return finish(R);
}

/* ================= 2. Water tank ================= */
export function buildWaterTank() {
  setSeed(802); const R = root('WaterTank'), G = grpOf(R, 'WT_');
  const St = G('Stand'), Tk = G('Tank'), La = G('Ladder'), Pi = G('Piping'), Ga = G('Gauge'), Lv = G('Level'), Pin = G('PortIn'), Pout = G('PortOut'), De = G('Details'), Gl = G('Glass');
  pad(St, 8, 8, PT, [[-3.6, -3.6], [3.6, -3.6], [-3.6, 3.6], [3.6, 3.6]]);
  const L = 2.3, top = 5.6;
  for (const a of [-1, 1]) for (const b of [-1, 1]) { const x = a * L, z = b * L; add(St, boxG(.2, top - PT, .2), M.galv, [x, PT + (top - PT) / 2, z]); add(St, boxG(.5, .03, .5), M.galv, [x, PT + .015, z]); for (const k of [-1, 1]) for (const j of [-1, 1]) anchor(St, x + k * .18, PT + .03, z + j * .18); }
  for (const y of [.9, 3.2]) for (const s of [-1, 1]) { add(St, boxG(2 * L, .1, .1), M.galv, [0, y, s * L]); add(St, boxG(.1, .1, 2 * L), M.galv, [s * L, y, 0]); }
  for (const [y0, y1] of [[.9, 3.2], [3.2, 5.5]]) for (const s of [-1, 1]) for (const d of [-1, 1]) {
    pipe(St, M.steel, [-L + .1, y0 + .06, s * (L + .07)].map((v, i) => i === 0 ? d * (L - .1) : v), [d * -(L - .1), y1 - .06, s * (L + .07)], .022, 6);
    pipe(St, M.steel, [s * (L + .07), y0 + .06, d * (L - .1)], [s * (L + .07), y1 - .06, -d * (L - .1)], .022, 6); }
  for (const s of [-1, 1]) for (const y of [2.05, 4.35]) { add(St, alongX(cylG(.05, .05, .25, 8)), M.steel, [0, y, s * (L + .07)]); add(St, alongZ(cylG(.05, .05, .25, 8)), M.steel, [s * (L + .07), y, 0]); }
  for (const s of [-1, 1]) { add(St, boxG(2 * L + .2, .25, .16), M.galv, [0, 5.725, s * 2.43]); add(St, boxG(.16, .25, 2 * L + .2), M.galv, [s * 2.43, 5.725, 0]); add(St, boxG(4.7, .2, .12), M.galv, [0, 5.7, s * 1.0]); }
  add(St, boxG(5.2, .05, 5.2), M.galv, [0, 5.875, 0]);
  // tank
  const prof = []; for (let i = 0; i <= 52; i++) { const y = 5.9 + i * 3.3 / 52; prof.push([2.95 + .03 * Math.sin(i / 4 * TAU), y]); }
  add(Tk, revolve(prof, 32), M.galv);
  add(Tk, cylG(3.0, 3.0, .1, 40, true), M.galv, [0, 5.95, 0]); add(Tk, cylG(3.0, 3.0, .08, 40, true), M.galv, [0, 9.16, 0]);
  add(Tk, revolve([[3.02, 9.2], [3.02, 9.24], [.32, 9.82], [0, 9.82]], 40), M.galv);
  for (let i = 0; i < 16; i++) { const a = i / 16 * TAU; beam(Tk, M.galv, [2.98 * Math.cos(a), 9.255, 2.98 * Math.sin(a)], [.36 * Math.cos(a), 9.83, .36 * Math.sin(a)], .05, .04); }
  add(Tk, cylG(.2, .2, .1, 24), M.galv, [0, 9.87, 0]); add(Tk, cylG(.04, .32, .07, 24), M.galv, [0, 9.955, 0]);
  { const s = sub(Tk, [-1.2, 9.43, 1.95]); s.rotation.x = .21; add(s, boxG(.72, .12, .62), M.galv); add(s, boxG(.76, .04, .66), M.galv, [0, .08, 0]); add(s, alongX(cylG(.025, .025, .6, 8)), M.steel, [0, .08, -.34]); add(s, boxG(.2, .05, .04), M.steel, [0, .12, .3]); }
  for (let i = 0; i < 7; i++) { const a = -2.3 + i * .6, r = 2.995; sticker(Tk, M.rust, .35, rr(.6, 1.2), [r * Math.cos(a), rr(8.4, 8.8), r * Math.sin(a)], PI / 2 - a); }
  sticker(Tk, tag('TankLabel', 'WATER 20 m³ · น้ำ', '#1f6f6c', '#fff'), 1.4, .35, [-2.13, 8.2, 2.13], -PI / 4);
  // ladder + cage (south)
  const lz = 3.3, lx = -1.2;
  for (const x of [lx - .25, lx + .25]) add(La, boxG(.06, 9.85 - PT, .05), M.galv, [x, PT + (9.85 - PT) / 2, lz]);
  for (let y = .6; y < 9.7; y += .3) pipe(La, M.galv, [lx - .25, y, lz], [lx + .25, y, lz], .018, 5);
  for (const y of [5.8, 6.8, 8.6]) for (const x of [lx - .25, lx + .25]) add(La, boxG(.05, .06, y < 5.9 ? .7 : .38), M.galv, [x, y, y < 5.9 ? lz - .35 : lz - .19]);
  for (const x of [lx - .25, lx + .25]) add(La, boxG(.16, .02, .16), M.galv, [x, PT + .01, lz]);
  for (let y = 2.4; y <= 9.65; y += .725) { add(La, new THREE.TorusGeometry(.37, .02, 4, 20, PI).rotateX(PI / 2), M.galv, [lx, y, 3.6]); for (const k of [-1, 1]) pipe(La, M.galv, [lx + k * .37, y, 3.6], [lx + k * .25, y, lz], .018, 4); }
  for (const a of [30, 60, 90, 120, 150]) { const r = a * DEG; add(La, boxG(.04, 7.25, .02), M.galv, [lx + .37 * Math.cos(r), 6.025, 3.6 + .37 * Math.sin(r)]); }
  // gauge (south, x = 1)
  const gx = 1.0, gz = 3.15;
  for (const y of [6.17, 8.99]) { pipe(Ga, M.steel, [gx, y, 2.85], [gx, y, gz], .035, 8); add(Ga, boxG(.14, .14, .14), M.brass, [gx, y, gz]); add(Ga, boxG(.1, .03, .03), M.red, [gx + .12, y, gz + .02]); }
  for (let i = 0; i < 3; i++) { const a = PI / 2 + (i - 1) * 1.2; pipe(Ga, M.steel, [gx + .11 * Math.cos(a), 6.24, gz + .11 * Math.sin(a)], [gx + .11 * Math.cos(a), 8.92, gz + .11 * Math.sin(a)], .01, 4); }
  add(Ga, plane(.12, 2.68), W.scale, [gx - .2, 7.58, gz - .02]); add(Ga, boxG(.16, 2.72, .02), M.galv, [gx - .2, 7.58, gz - .035]); pipe(Ga, M.galv, [gx - .2, 7.58, gz - .05], [gx - .2, 7.58, 2.92], .02, 6);
  pipe(Ga, M.steel, [gx, 6.1, gz], [gx, 5.5, gz], .02, 6); add(Ga, cylG(.04, .04, .1, 8), M.brass, [gx, 5.45, gz]);
  add(Gl, cylG(.07, .07, 2.68, 20, true), M.glass, [gx, 7.58, gz]);
  Lv.position.set(gx, 6.24, gz); add(Lv, cylG(.055, .055, 2.68, 20).translate(0, 1.34, 0), W.water);
  // piping down the legs
  for (const s of [-1, 1]) {
    add(Pi, alongX(cylG(s < 0 ? .18 : .6, s < 0 ? .6 : .18, .3, 32)), M.galv, [s * 3.25, 1.5, 0]);
    duct(Pi, M.galv, [[s * 3.1, 1.5, 0], [s * 2.75, 1.5, 0], [s * 2.75, 5.2, 0], [s * 1.6, 5.2, 0], [s * 1.6, 5.92, 0]], .18, .3, 14, 6);
    gateValve(Pi, [s * 2.75, 2.5, 0], [0, 1, 0], [0, 0, 1], .2);
    for (const y of [3.2, 4.35]) { add(Pi, boxG(.36, .08, .08), M.galv, [s * 2.52, y, 0]); add(Pi, new THREE.TorusGeometry(.2, .02, 4, 16).rotateX(PI / 2), M.galv, [s * 2.75, y, 0]); }
    add(Pi, cylG(.28, .28, .05, 24), M.galv, [s * 1.6, 5.82, 0]); support(Pi, s * 3.35, 0, .9); }
  duct(Pi, M.galv, [[2.05, 9.0, -2.05], [2.62, 9.0, -2.62], [2.62, .65, -2.62], [2.95, .65, -2.95]], .08, .15, 12, 6);
  add(Pi, cylG(.13, .13, .06, 16), M.galv, [2.07, 9.0, -2.07]); for (const y of [2.0, 4.5, 7.0]) add(Pi, boxG(.18, .06, .18), M.galv, [2.5, y, -2.5]);
  add(Pi, boxG(.6, .08, .6), M.concrete, [2.98, PT + .04, -2.98]);
  // details
  sticker(De, plateM('TankPlate', 'COOP WATER TANK', '20 m³ · galvanised', 'S/N 2026-0402'), .5, .25, [-2.3, 1.6, 2.401], 0);
  add(De, flat(1.6, 1.6), M.oil, [2.6, PT + .004, -2.6]); add(De, flat(1.0, 1.0), M.rust, [-2.3, PT + .005, -2.3]);
  nozzle(Pin, [-4, 1.5, 0], [-1, 0, 0], 'water', .6); nozzle(Pout, [4, 1.5, 0], [1, 0, 0], 'water', .6);
  return finish(R);
}

/* ================= 3. Straw boiler ================= */
export function buildBoiler() {
  setSeed(803); const R = root('Boiler'), G = grpOf(R, 'BO_');
  const Fo = G('Foundation'), Fd = G('Feeder'), Fu = G('Furnace'), Sh = G('Shell'), Fi = G('Fittings'), Pm = G('Pump'), Ch = G('Chimney'), Cw = G('Catwalk'), Ct = G('Controls'), De = G('Details'), Pw = G('PortWater'), Po = G('PortOut'), Fr = G('Fire'), Em = G('Emissive'), Gl = G('Glass');
  pad(Fo, 14, 12, PT, [[-6.6, -5.6], [6.6, -5.6], [-6.6, 5.6], [6.6, 5.6], [-3, -5.6], [3, -5.6], [-3, 5.6], [3, 5.6], [6.6, -2.8], [6.6, 2.8], [-6.6, 3.2], [-6.6, -3.2]]);
  for (const x of [.2, 3.6]) add(Fo, bboxG(.5, 2.15, 3.0, .04), M.concrete, [x, PT + 1.075, 0]);
  add(Fo, bboxG(1.0, .6, 2.6, .04), M.concrete, [0, .6, -4.1]);
  add(Fo, flat(2.4, 1.6), M.dust, [-5.6, PT + .005, 2.2]); add(Fo, flat(2.0, 1.4), M.dust, [-2.5, PT + .005, 3.4]); add(Fo, flat(1.4, 1.6), M.oil, [.2, PT + .004, -4.1]);
  const cy = 4.6, r = 2.1;
  // shell
  add(Sh, alongX(cylG(r, r, 5.6, 128, true)), M.lag, [1.8, cy, 0]);
  for (const x of [-.55, .35, 1.25, 2.15, 3.05, 3.95]) { add(Sh, new THREE.TorusGeometry(r + .012, .022, 4, 96).rotateY(PI / 2), M.steel, [x, cy, 0]); add(Sh, boxG(.08, .1, .1), M.steel, [x, cy - .3, r + .02]); }
  add(Sh, boxG(5.6, .02, .05), M.steel, [1.8, cy + r * .707, -r * .707], [PI / 4, 0, 0]);
  for (const x of [.2, 3.6]) { add(Sh, alongX(cylG(2.16, 2.16, .42, 48, true, PI / 2 - .62, 1.24)), M.iron, [x, cy, 0]); add(Sh, boxG(.5, .06, 2.4), M.iron, [x, 2.46, 0]); for (const s of [-1, 1]) add(Sh, boxG(.04, .4, .4), M.iron, [x, 2.68, s * .9]); }
  add(Sh, alongX(cylG(2.15, 2.15, .7, 96)), M.iron, [4.95, cy, 0]); add(Sh, new THREE.TorusGeometry(2.15, .04, 6, 96).rotateY(PI / 2), M.iron, [4.6, cy, 0]);
  add(Sh, alongX(cylG(1.7, 1.7, .08, 64)), M.iron, [5.34, cy, 0]); for (const x of [4.68, 5.24]) boltRing(Sh, [x, cy, 0], [1, 0, 0], 2.17, 40, .03, .02); add(Sh, new THREE.TorusGeometry(1.7, .035, 6, 64).rotateY(PI / 2), M.iron, [5.38, cy, 0]);
  for (const y of [-1, 1]) add(Sh, alongX(cylG(.06, .06, .2, 10)), M.steel, [5.36, cy + y * 1.1, -1.75]);
  for (let i = 0; i < 6; i++) { const a = i / 6 * TAU + .3; add(Sh, boxG(.1, .1, .22), M.steel, [5.4, cy + 1.82 * Math.sin(a), 1.82 * Math.cos(a)], [-a, 0, 0]); }
  add(Sh, boxG(.06, .08, .5), M.steel, [5.42, cy, 1.0]);
  add(Sh, cylG(.32, .32, .3, 32), M.galv, [3.0, 6.75, 0]); add(Sh, cylG(.42, .42, .08, 32), M.iron, [3.0, 6.94, 0]); boltRing(Sh, [3.0, 6.98, 0], [0, 1, 0], .36, 12, .03, .025);
  // fittings: safety valves
  for (const x of [1.6, 2.2]) { add(Fi, cylG(.16, .16, .26, 20), M.iron, [x, 6.75, 0]); add(Fi, cylG(.22, .22, .05, 24), M.iron, [x, 6.9, 0]); boltRing(Fi, [x, 6.925, 0], [0, 1, 0], .17, 4, .025, .02);
    add(Fi, cylG(.17, .17, .3, 20), M.red, [x, 7.08, 0]); add(Fi, cylG(.11, .13, .45, 16), M.red, [x, 7.45, 0]); add(Fi, cylG(.07, .07, .1, 12), M.iron, [x, 7.73, 0]);
    add(Fi, boxG(.5, .04, .04), M.steel, [x + .2, 7.6, 0], [0, 0, -.25]); add(Fi, cylG(.04, .04, .1, 8), M.iron, [x + .42, 7.52, 0]);
    duct(Fi, M.galv, [[x, 7.05, -.15], [x, 7.05, -.55], [x, 8.3, -.55]], .07, .12, 12, 6);
    add(Fi, tubeG([[x + .15, 6.95, .1], [x + .3, 6.8, .6], [x + .3, 6.3, 1.6], [x + .3, 4.6, 2.25], [x + .3, .4, 2.3]], .025, 6, .3), M.galv); }
  // main steam valve + lagged line to OUT
  add(Fi, cylG(.2, .2, .3, 24), M.iron, [4.0, 6.75, 0]); add(Fi, cylG(.27, .27, .05, 24), M.iron, [4.0, 6.92, 0]); boltRing(Fi, [4.0, 6.945, 0], [0, 1, 0], .22, 6, .025, .02);
  add(Fi, new THREE.SphereGeometry(.27, 24, 16), M.iron, [4.0, 7.15, 0]); add(Fi, alongX(cylG(.27, .27, .05, 24)), M.iron, [4.3, 7.15, 0]);
  add(Fi, cylG(.16, .2, .4, 16), M.iron, [4.0, 7.55, 0]); for (const k of [-1, 1]) add(Fi, boxG(.04, .3, .04), M.iron, [4.0 + k * .1, 7.88, 0]); add(Fi, cylG(.025, .025, .5, 8), M.steel, [4.0, 7.95, 0]);
  handwheel(Fi, [4.0, 8.08, 0], [0, 1, 0], .3);
  duct(Fi, M.lag, [[4.33, 7.15, 0], [5.85, 7.15, 0], [5.85, 1.5, 0], [6.35, 1.5, 0]], .3, .5, 32, 10);
  for (const p of [[5.0, 7.15, 0], [5.85, 5.5, 0], [5.85, 3.5, 0]]) add(Fi, new THREE.TorusGeometry(.305, .015, 4, 32).rotateY(p[1] === 7.15 ? PI / 2 : 0).rotateX(p[1] === 7.15 ? 0 : PI / 2), M.steel, p);
  add(Fi, alongX(cylG(.6, .3, .15, 40)), M.galv, [6.425, 1.5, 0]); support(Fi, 5.85, 0, 1.2);
  // water gauge glass (south)
  for (const y of [3.95, 5.35]) { pipe(Fi, M.steel, [-.5, y, 1.9], [-.5, y, 2.42], .05, 10); add(Fi, boxG(.16, .16, .16), M.brass, [-.5, y, 2.42]); add(Fi, boxG(.2, .03, .03), M.red, [-.35, y, 2.48]); }
  for (let i = 0; i < 3; i++) { const a = PI / 2 + (i - 1) * 1.1; pipe(Fi, M.steel, [-.5 + .1 * Math.cos(a), 4.03, 2.42 + .1 * Math.sin(a)], [-.5 + .1 * Math.cos(a), 5.27, 2.42 + .1 * Math.sin(a)], .01, 4); }
  add(Gl, cylG(.06, .06, 1.24, 16, true), M.glass, [-.5, 4.65, 2.42]); add(Fi, cylG(.045, .045, .57, 12), W.water, [-.5, 4.315, 2.42]);
  add(Fi, tubeG([[-.5, 3.87, 2.42], [-.5, 3.4, 2.45], [-.5, .4, 2.5]], .02, 6), M.steel);
  for (const x of [.6, 1.4]) { pipe(Fi, M.steel, [x, 6.0, 1.45], [x, 6.3, 1.45], .03, 8); add(Fi, new THREE.TorusGeometry(.06, .015, 6, 12), M.steel, [x, 6.36, 1.45]); pipe(Fi, M.steel, [x, 6.42, 1.45], [x, 6.6, 1.6], .03, 8); }
  gaugeOn(Fi, Gl, 'BoGauge1', [.6, 6.6, 1.735], [0, 0, 1], 'bar', 16, .65, .17); gaugeOn(Fi, Gl, 'BoGauge2', [1.4, 6.6, 1.735], [0, 0, 1], 'bar', 16, .65, .17);
  duct(Fi, M.galv, [[4.2, 2.6, 0], [4.2, .7, 0], [4.9, .7, 0]], .07, .12, 12, 6); gateValve(Fi, [4.2, 1.4, 0], [0, 1, 0], [0, 0, 1], .12); add(Fi, flat(.5, .5), M.hole, [5.05, PT + .006, 0]);
  // furnace
  add(Fu, bboxG(3.0, 6.45, 4.6, .06), M.teal, [-2.5, PT + 3.225, 0]);
  for (const s of [-1, 1]) { for (const x of [-3.85, -1.15]) add(Fu, boxG(.12, 6.3, .08), M.teal, [x, 3.5, s * 2.34]); for (const y of [4.0, 5.6]) add(Fu, boxG(2.9, .12, .08), M.teal, [-2.5, y, s * 2.34]);
    for (const x of [-3.85, -1.15]) for (let i = 0; i < 9; i++) nut(Fu, [x, .8 + i * .7, s * 2.38], [0, 0, s], .03, .02); for (const y of [4.0, 5.6]) for (let i = 0; i < 6; i++) nut(Fu, [-3.5 + i * .4, y, s * 2.38], [0, 0, s], .03, .02); }
  for (const x of [-3.85, -1.15]) for (const z of [-2.2, 2.2]) add(Fu, new THREE.TorusGeometry(.1, .03, 6, 12).rotateY(PI / 2), M.steel, [x, 6.85, z]);
  add(Fu, cylG(.35, .35, .1, 24), M.iron, [-2.0, 6.8, -1.2]); add(Fu, boxG(.6, .04, .04), M.steel, [-1.75, 6.9, -1.2]); add(Fu, cylG(.08, .08, .14, 10), M.iron, [-1.47, 6.88, -1.2]);
  add(Fu, boxG(1.2, 1.2, .06), M.iron, [-2.5, 2.7, 2.33]); add(Fu, boxG(1.0, 1.0, .08), M.iron, [-2.5, 2.7, 2.41]);
  for (let i = 0; i < 12; i++) { const t = i / 12 * 4, x = t < 1 ? -2.95 + t * .9 : t < 2 ? -2.05 : t < 3 ? -2.05 - (t - 2) * .9 : -2.95, y = t < 1 ? 2.25 : t < 2 ? 2.25 + (t - 1) * .9 : t < 3 ? 3.15 : 3.15 - (t - 3) * .9; nut(Fu, [x, y, 2.45], [0, 0, 1], .025, .015); }
  add(Fu, new THREE.TorusGeometry(.15, .025, 8, 28), M.brass, [-2.5, 2.7, 2.455]);
  for (const y of [2.4, 3.0]) add(Fu, cylG(.05, .05, .2, 10), M.steel, [-3.04, y, 2.42]); add(Fu, boxG(.08, .4, .06), M.steel, [-2.12, 2.7, 2.48]); add(Fu, alongZ(cylG(.04, .04, .1, 8)), M.steel, [-2.12, 2.85, 2.46]);
  add(Fu, boxG(1.0, .7, .06), M.iron, [-2.5, 1.0, 2.33]); add(Fu, boxG(.9, .6, .08), M.iron, [-2.5, 1.0, 2.41]); add(Fu, boxG(.3, .05, .06), M.steel, [-2.5, 1.12, 2.48]); for (const x of [-2.95, -2.05]) add(Fu, cylG(.04, .04, .15, 8), M.steel, [x, 1.0, 2.42]);
  add(Fu, plane(2.4, 2.2), M.brick, [-4.004, 2.0, 0], [0, -PI / 2, 0]); add(Fu, plane(1.7, 1.6), M.hole, [-4.008, 1.95, 0], [0, -PI / 2, 0]); for (let j = 0; j < 9; j++) for (let i = 0; i < 4; i++) { const y = .95 + j * .24, z = -1.2 + i * .62 + (j % 2) * .3; if (z > 1.18) continue; if (Math.abs(z) < .95 && y < 2.8) continue; add(Fu, boxG(.04, .2, .58), M.brick, [-4.02, y + .12, z]); }
  gaugeOn(Fu, Gl, 'BoFlueTemp', [-1.5, 5.2, 2.41], [0, 0, 1], '°C x100', 8, .8, .13);
  // ash bin
  { const s = sub(Fu, [-2.5, PT, 3.4]); add(s, boxG(1.0, .05, .7), M.iron, [0, .2, 0]); for (const k of [-1, 1]) { add(s, boxG(1.0, .5, .04), M.iron, [0, .45, k * .33]); add(s, boxG(.04, .5, .7), M.iron, [k * .48, .45, 0]); }
    add(s, new THREE.SphereGeometry(1, 20, 10), M.ash, [0, .66, 0], [0, 0, 0], [.46, .18, .3]); for (const k of [-1, 1]) add(s, new THREE.TorusGeometry(.1, .035, 6, 14), M.black, [k * .35, .1, .37]); add(s, alongX(cylG(.02, .02, .8, 6)), M.steel, [0, .1, .37]);
    add(s, tubeG([[-.48, .65, 0], [-.75, .8, 0], [-.85, .82, 0]], .02, 6), M.steel); }
  // fire
  add(Fr, plane(1.08, 1.08), M.fire, [-2.5, 2.7, 2.364]); add(Fr, new THREE.CircleGeometry(.14, 24), M.fire, [-2.5, 2.7, 2.452]); add(Gl, new THREE.CircleGeometry(.14, 24), M.glass, [-2.5, 2.7, 2.458]);
  add(Fr, plane(.96, .66), M.coal, [-2.5, 1.0, 2.364]); add(Fr, plane(1.5, 1.3), M.fire, [-4.012, 1.9, 0], [0, -PI / 2, 0]); add(Fr, plane(1.5, .3), M.coal, [-4.014, 1.3, 0], [0, -PI / 2, 0]);
  // feeder (from IN at x = -7)
  add(Fd, boxG(3.0, .05, 2.6), M.galv, [-5.5, .875, 0]);
  add(Fd, new THREE.ExtrudeGeometry(new THREE.Shape([new THREE.Vector2(-7, 1.25), new THREE.Vector2(-6.3, .9), new THREE.Vector2(-6.3, .95), new THREE.Vector2(-7, 1.3)]), { depth: 2.5, bevelEnabled: false }).translate(0, 0, -1.25), M.galv);
  for (const s of [-1, 1]) add(Fd, boxG(3.0, 2.75, .06), M.teal, [-5.5, PT + 1.375, s * 1.33]);
  add(Fd, boxG(3.0, .06, 2.78), M.teal, [-5.5, 3.08, 0]);
  for (const x of [-6.95, -5.5]) { for (const s of [-1, 1]) add(Fd, boxG(.1, 2.8, .08), M.teal, [x, 1.7, s * 1.4]); add(Fd, boxG(.1, .08, 2.88), M.teal, [x, 3.15, 0]); }
  for (const [x, z] of [[-6.8, -1.1], [-6.8, 1.1], [-4.3, -1.1], [-4.3, 1.1]]) add(Fd, boxG(.08, .55, .08), M.galv, [x, .575, z]);
  add(Fd, boxG(.08, 2.05, 2.5), M.iron, [-4.6, 1.935, 0]);
  for (const s of [-1, 1]) { add(Fd, plane(2.2, .16), M.hole, [-5.6, 2.0, s * 1.362], [0, s > 0 ? 0 : PI, 0]); add(Fd, boxG(.12, .5, .36), M.iron, [-4.7, 2.0, s * 1.55]);
    add(Fd, alongX(cylG(.17, .17, 1.3, 24)), M.teal, [-6.15, 2.0, s * 1.62]); add(Fd, alongX(cylG(.06, .06, .85, 12)), M.steel, [-5.075, 2.0, s * 1.62]);
    for (const x of [-6.8, -5.5]) add(Fd, alongX(cylG(.2, .2, .06, 24)), M.teal, [x, 2.0, s * 1.62]); add(Fd, boxG(.2, .4, .3), M.iron, [-6.88, 2.0, s * 1.5]);
    for (const x of [-6.7, -5.6]) add(Fd, cylG(.04, .04, .1, 8), M.brass, [x, 1.79, s * 1.62]); }
  for (const s of [-1, 1]) add(Fd, boxG(.12, 4.4, .12), M.galv, [-4.15, PT + 2.2, s * 1.48]); add(Fd, boxG(.2, .16, 3.08), M.galv, [-4.15, 4.78, 0]);
  add(Fd, boxG(.06, 1.3, 2.7), M.iron, [-4.15, 3.85, 0]); add(Fd, cylG(.12, .12, .9, 16), M.teal, [-4.15, 5.3, 0]); add(Fd, cylG(.04, .04, .4, 8), M.steel, [-4.15, 4.65, 0]);
  add(Fd, bboxG(1.2, .7, .8, .04), M.teal, [-5.6, .65, -3.2]); add(Fd, alongX(cylG(.2, .2, .5, 24)), M.teal, [-5.4, 1.22, -3.2]); add(Fd, boxG(.25, .25, .25), M.iron, [-5.8, 1.13, -3.2]);
  add(Fd, cylG(.08, .08, .3, 12), M.iron, [-6.0, 1.15, -2.95]); gaugeOn(Fd, Gl, 'BoHydGauge', [-6.2, 1.15, -2.795], [0, 0, 1], 'bar', 250, .8, .07);
  for (const [x0, x1] of [[-5.9, -6.7], [-5.7, -5.6]]) add(Fd, tubeG([[x0, 1.05, -2.8], [x0 - .1, 1.7, -2.2], [x1, 1.82, -1.62]], .025, 6, .3), M.black);
  add(Fd, tubeG([[-4.0, 1.2, -3.2], [-4.6, 5.0, -1.2], [-4.27, 5.6, 0]], .02, 6, .3), M.black);
  for (let i = 0; i < 40; i++) add(Fd, boxG(rr(.15, .35), .012, .02), M.straw, [rr(-6.9, -4.8), .91, rr(-1.2, 1.2)], [0, rr(0, PI), 0]);
  add(Fd, bboxG(1.0, .9, 1.5, .08), M.straw, [-5.2, 1.36, 0]); for (let i = 0; i < 260; i++) { const f = rnd() * 4 | 0, y = f < 2 ? rr(.95, 1.78) : f === 2 ? 1.82 : rr(.95, 1.78), x = f === 0 ? -5.72 : f === 1 ? -4.68 : rr(-5.68, -4.72), z = f === 3 ? (rnd() < .5 ? -.77 : .77) : rr(-.72, .72); add(Fd, boxG(rr(.1, .3), .012, .022), M.straw, [x, y, z], [rr(-.8, .8), rr(0, PI), rr(-.8, .8)]); }
  for (const x of [-5.45, -4.95]) add(Fd, new THREE.TorusGeometry(.5, .012, 4, 24).rotateY(PI / 2).scale(1, .92, 1.52), M.yellow, [x, 1.36, 0]);
  // feed water pump (north) + port
  nozzle(Pw, [0, 1.5, -6], [0, 0, -1], 'water', .6);
  add(Pm, alongZ(cylG(.15, .6, .2, 40)), M.galv, [0, 1.5, -5.3]); add(Pm, alongZ(cylG(.15, .15, .15, 16)), M.galv, [0, 1.5, -5.12]); flangePair(Pm, [0, 1.5, -5.07], [0, 0, 1], .24);
  add(Pm, alongZ(cylG(.42, .42, .38, 40)), M.iron, [0, 1.5, -4.83]); add(Pm, boxG(.3, .3, .3), M.iron, [0, 1.75, -4.83]);
  add(Pm, cylG(.1, .1, .35, 16), M.iron, [0, 2.02, -4.83]); add(Pm, cylG(.18, .18, .05, 20), M.iron, [0, 2.2, -4.83]);
  add(Pm, alongZ(cylG(.18, .24, .3, 24)), M.iron, [0, 1.5, -4.49]); add(Pm, alongZ(cylG(.34, .34, 1.25, 40)), M.teal, [0, 1.5, -3.675]);
  for (let i = 0; i < 18; i++) { const a = i / 18 * TAU; if (Math.sin(a) < -.6 || Math.sin(a) > .9) continue; add(Pm, boxG(.035, .08, 1.1), M.teal, [.37 * Math.cos(a), 1.5 + .37 * Math.sin(a), -3.7], [0, 0, a - PI / 2]); }
  add(Pm, alongZ(cylG(.36, .36, .25, 40, true)), M.teal, [0, 1.5, -2.925]); add(Pm, new THREE.CircleGeometry(.36, 32), M.guard, [0, 1.5, -2.8]);
  add(Pm, bboxG(.25, .2, .3, .02), M.teal, [0, 1.94, -3.7]); gland(Pm, [.13, 1.94, -3.7], [1, 0, 0], .035);
  add(Pm, boxG(.8, .1, 2.4), M.iron, [0, .95, -4.05]); for (const z of [-4.8, -3.3]) add(Pm, boxG(.5, .2, .2), M.iron, [0, 1.1, z]); for (const a of [-1, 1]) for (const z of [-5.0, -3.1]) nut(Pm, [a * .32, 1.0, z], [0, 1, 0], .03, .025);
  duct(Pm, M.galv, [[0, 2.22, -4.83], [0, 4.6, -4.83], [0, 4.6, -2.06]], .1, .2, 16, 6);
  checkValve(Pm, [0, 2.9, -4.83], [0, 1, 0], .13); gateValve(Pm, [0, 3.7, -4.83], [0, 1, 0], [-1, 0, 0], .13); add(Pm, alongZ(cylG(.2, .2, .05, 20)), M.iron, [0, 4.6, -2.12]); boltRing(Pm, [0, 4.6, -2.15], [0, 0, -1], .15, 4, .02, .02);
  sticker(Pm, plateM('FeedPumpPlate', 'FEED PUMP', '3 kW · 2 m³/h · 12 bar', 'S/N 2026-0203'), .3, .15, [.345, 1.5, -3.7], PI / 2);
  // chimney: economiser + flue + stack
  add(Ch, bboxG(2.4, 2.25, 2.8, .05), M.teal, [-3.0, 7.875, 3.0]);
  for (const [x, z] of [[-4.1, 4.3], [-1.9, 4.3]]) { add(Ch, boxG(.14, 6.75 - PT, .14), M.galv, [x, PT + (6.75 - PT) / 2, z]); add(Ch, boxG(.3, .02, .3), M.galv, [x, PT + .01, z]); anchor(Ch, x + .1, PT + .02, z + .1); }
  beam(Ch, M.galv, [-4.1, 1.0, 4.3], [-1.9, 6.6, 4.3], .06, .06); add(Ch, boxG(2.3, .1, .1), M.galv, [-3.0, 3.5, 4.3]);
  add(Ch, bboxG(1.0, .8, .06, .02), M.iron, [-3.0, 7.9, 4.43]); for (let i = 0; i < 4; i++) add(Ch, boxG(.08, .08, .1), M.steel, [-3.5 + (i % 2), 7.55 + (i > 1 ? .7 : 0), 4.48]);
  for (const y of [7.2, 8.55]) { add(Ch, alongX(cylG(.12, .12, 2.6, 16)), M.iron, [-3.0, y, 4.55]); for (const x of [-4.05, -1.95]) add(Ch, alongZ(cylG(.1, .1, .15, 12)), M.iron, [x, y, 4.47]); }
  add(Ch, tubeG([[-1.8, 8.6, 2.0], [-1.2, 8.4, 1.4], [-.6, 7.0, .5], [-.4, 6.6, .4]], .08, 8, .3), M.iron);
  duct(Ch, M.iron, [[5.0, 6.4, .9], [5.0, 7.7, .9], [-.6, 7.7, .9], [-.6, 7.7, 3.0], [-1.8, 7.7, 3.0]], .4, .6, 32, 10);
  add(Ch, alongX(cylG(.46, .46, .2, 32)), M.iron, [2.0, 7.7, .9]); for (const x of [1.0, 3.4]) add(Ch, boxG(.1, .85, .3), M.galv, [x, 6.95, .9]);
  add(Ch, cylG(.45, .75, .5, 40), M.iron, [-3, 9.25, 3]); add(Ch, cylG(.45, .45, 3.5, 48, true), M.galv, [-3, 11.25, 3]);
  add(Ch, cylG(.43, .43, .8, 48, true), M.holeBack, [-3, 12.6, 3]); add(Ch, new THREE.RingGeometry(.43, .5, 48).rotateX(-PI / 2), M.galv, [-3, 13, 3]); add(Ch, cylG(.5, .5, .08, 48, true), M.galv, [-3, 12.96, 3]);
  add(Ch, cylG(.456, .456, .8, 48, true), M.sootCh, [-3, 12.5, 3]);
  for (const y of [10.4, 11.8]) { add(Ch, revolve([[.45, -.03], [.55, -.03], [.55, .03], [.45, .03]], 40), M.galv, [-3, y, 3]); boltRing(Ch, [-3, y + .03, 3], [0, 1, 0], .5, 8, .025, .02); }
  for (const x of [-3.25, -2.75]) add(Ch, boxG(.05, 3.6, .05), M.galv, [x, 11.0, 3.55]); for (let y = 9.4; y < 12.8; y += .3) pipe(Ch, M.galv, [-3.25, y, 3.55], [-2.75, y, 3.55], .015, 6); for (const y of [9.6, 11.2, 12.6]) for (const x of [-3.25, -2.75]) add(Ch, boxG(.04, .04, .12), M.galv, [x, y, 3.47]);
  for (const [x, z] of [[-4.1, 4.3], [-1.9, 4.3], [-4.1, 1.7]]) { const d = new V3(x + 3, 0, z - 3).normalize(); pipe(Ch, M.steel, [-3 + d.x * .5, 11.8, 3 + d.z * .5], [x, 9.0, z], .015, 4); }
  // catwalk + ladder
  add(Cw, flat(5.2, 1.1), W.grating, [1.8, 6.95, -1.475]); for (const z of [-2.05, -.9]) add(Cw, boxG(5.2, .12, .05), M.galv, [1.8, 6.89, z]);
  for (let x = -.8; x <= 4.41; x += .8) add(Cw, boxG(.04, .08, 1.15), M.galv, [x, 6.89, -1.475]);
  for (const x of [-.4, 1.2, 2.8, 4.2]) { beam(Cw, M.galv, [x, 5.75, -1.77], [x, 6.84, -2.0], .08, .08); add(Cw, boxG(.08, .08, 1.1), M.galv, [x, 6.82, -1.475]); }
  const rail = (a, b) => { const A = v3(a), B = v3(b), n = Math.max(1, Math.round(A.distanceTo(B) / 1.0)); for (let i = 0; i <= n; i++) { const p = A.clone().lerp(B, i / n); add(Cw, boxG(.05, 1.05, .05), M.yellow, [p.x, 7.475, p.z]); }
    for (const y of [8.0, 7.5]) pipe(Cw, M.yellow, [A.x, y, A.z], [B.x, y, B.z], .025, 8); };
  rail([-.8, 0, -2.06], [3.6, 0, -2.06]); rail([-.8, 0, -2.06], [-.8, 0, -.95]); rail([4.4, 0, -2.06], [4.4, 0, -.95]);
  for (const x of [3.75, 4.25]) { add(Cw, boxG(.06, 8.0 - PT, .05), M.yellow, [x, PT + (8 - PT) / 2, -2.3]); add(Cw, boxG(.16, .02, .16), M.galv, [x, PT + .01, -2.3]); }
  for (let y = .6; y < 6.95; y += .3) pipe(Cw, M.galv, [3.75, y, -2.3], [4.25, y, -2.3], .018, 6);
  // controls
  add(Ct, boxG(1.8, .1, .8), M.concrete, [5.3, .35, 4.4]); add(Ct, bboxG(1.6, 2.0, .6, .03), M.teal, [5.3, 1.4, 4.4]);
  add(Ct, boxG(.8, .44, .02), M.black, [5.0, 2.0, 4.71]); add(Em, plane(.72, .36), lcd('BoScreen', T.lcd(['STEAM  8.2 bar', 'LEVEL  OK'], '#0b1a20', '#7cf0c0')), [5.0, 2.0, 4.722]);
  [[5.65, M.emA, 'BURNER'], [5.95, M.emR, 'LOW WATER']].forEach(([x, m, t]) => { add(Ct, alongZ(cylG(.07, .07, .02, 18)), M.steel, [x, 2.1, 4.71]); add(Em, revolve([[0, 0], [.05, 0], [.05, .015], [0, .035]], 16).rotateX(PI / 2), m, [x, 2.1, 4.72]); sticker(Ct, tag('Lbl' + t, t), .26, .06, [x, 1.95, 4.703], 0); });
  add(Em, revolve([[0, 0], [.05, 0], [.05, .015], [0, .035]], 16).rotateX(PI / 2), M.emG, [5.65, 1.75, 4.72]);
  add(Ct, alongZ(cylG(.13, .13, .02, 24)), M.yellow, [5.9, 1.5, 4.71]); add(Ct, revolve([[0, 0], [.1, 0], [.11, .04], [.1, .08], [0, .09]], 20).rotateX(PI / 2), M.red, [5.9, 1.5, 4.72]);
  add(Ct, alongZ(cylG(.05, .05, .04, 12)), M.black, [5.6, 1.5, 4.72]); add(Ct, boxG(.04, .35, .05), M.steel, [4.6, 1.4, 4.73]); louvre(Ct, [6.105, 1.0, 4.4], .4, .5, [1, 0], M.teal);
  sticker(Ct, W.zap, .3, .3, [5.0, 1.1, 4.703], 0); gland(Ct, [5.3, 2.4, 4.4], [0, 1, 0], .05);
  add(Ct, tubeG([[5.3, .4, 4.1], [5.3, .33, 3.8], [6.35, .33, 2.6], [6.35, .33, -3.4], [5.05, .33, -3.95]], .04, 6, .2), M.cable);
  add(Ct, cylG(.07, .07, 8.5, 12), M.galv, [5, 4.55, -4]); add(Ct, boxG(.3, .03, .3), M.galv, [5, PT + .015, -4]); for (const k of [-1, 1]) anchor(Ct, 5 + k * .11, PT + .03, -4 + k * .11);
  add(Ct, boxG(.08, .08, .5), M.galv, [5, 8.75, -4]); insulator(Ct, [5, 8.8, -4], .3); add(Ct, bboxG(.4, .5, .25, .02), M.ctrl, [5, 1.6, -3.82]);
  add(Ct, tubeG([[5.05, 1.85, -3.85], [5.1, 5, -3.93], [5.08, 8.7, -3.93]], .02, 6), M.cable); add(Ct, tubeG([[4.9, 1.4, -3.82], [3, .4, -4.4], [.8, .4, -4.3], [.1, 1.9, -3.7]], .025, 6, .3), M.cable);
  // details
  sticker(De, plateM('BoilerPlate', 'COOP STRAW BOILER 01', 'Fire-tube · 10 bar · 2 t/h steam', 'Fuel: rice straw bales · S/N 2026-0201'), .9, .45, [-3.3, 4.6, 2.381], 0);
  sticker(De, W.hp, .6, .7, [3.4, 4.6, 2.13], 0); sticker(De, W.hot, .4, .4, [-1.55, 3.4, 2.381], 0); sticker(De, W.hp, .38, .44, [5.85, 3.0, .305], 0);
  sticker(De, tag('FeedLabel', 'STRAW IN ▶', '#e2ae14'), .7, .18, [-6.3, 2.6, 1.365], 0);
  nozzle(Po, [7, 1.5, 0], [1, 0, 0], 'steam', .5);
  wireTop(R, 'BO_', [5, 9.0, -4]);
  return finish(R);
}

/* ================= 4. Steam turbine ================= */
export function buildSteamTurbine() {
  setSeed(804); const R = root('SteamTurbine'), G = grpOf(R, 'ST_');
  const Bd = G('Bed'), In = G('Inlet'), Cs = G('Casing'), Gb = G('Gearbox'), Sf = G('Shaft'), Gd = G('Guard'), Ge = G('Generator'), Oi = G('Oil'), Ct = G('Controls'), De = G('Details'), Po = G('PortIn'), Em = G('Emissive'), Gl = G('Glass');
  const AY = 2.9, rc = x => 1.0 + (x + 3.3) / 2.6 * .35;
  pad(Bd, 14, 8, PT, [[-6.6, -3.6], [6.6, -3.6], [-6.6, 3.6], [6.6, 3.6], [-2, -3.6], [2, -3.6], [-2, 3.6], [2, 3.6], [6.6, 0]]);
  add(Bd, bboxG(11.0, .6, 4.4, .04), M.concrete, [.6, .6, 0]); add(Bd, new THREE.CircleGeometry(.6, 32).rotateX(-PI / 2), M.hole, [-1.4, .905, 0]);
  for (const [x, z] of [[-4.6, -2], [-4.6, 2], [5.8, -2], [5.8, 2], [1.0, -2], [1.0, 2]]) anchor(Bd, x, .9, z);
  add(Bd, flat(1.8, 1.4), M.oil, [1.0, .906, 1.2]); add(Bd, flat(1.6, 1.2), M.oil, [-.3, PT + .004, 3.0]);
  // inlet
  nozzle(Po, [-7, 1.5, 0], [-1, 0, 0], 'steam', .6);
  add(In, alongX(cylG(.3, .6, .2, 40)), M.galv, [-6.3, 1.5, 0]);
  duct(In, M.lag, [[-6.2, 1.5, 0], [-5.6, 1.5, 0], [-5.6, 4.9, 0], [-3.0, 4.9, 0], [-3.0, 4.5, 0]], .3, .4, 32, 10);
  for (const y of [2.65, 3.35]) { add(In, cylG(.38, .38, .06, 32), M.iron, [-5.6, y, 0]); boltRing(In, [-5.6, y + (y < 3 ? -.03 : .03), 0], [0, y < 3 ? -1 : 1, 0], .33, 8, .025, .02); }
  add(In, new THREE.SphereGeometry(.38, 24, 16), M.iron, [-5.6, 3.0, 0]); add(In, alongZ(cylG(.16, .2, .45, 16)), M.iron, [-5.6, 3.0, .6]); add(In, alongZ(cylG(.025, .025, .3, 8)), M.steel, [-5.6, 3.0, .95]);
  handwheel(In, [-5.6, 3.0, 1.05], [0, 0, 1], .3);
  for (const x of [-4.65, -3.95]) { add(In, alongX(cylG(.38, .38, .06, 32)), M.iron, [x, 4.9, 0]); boltRing(In, [x + (x < -4.3 ? -.03 : .03), 4.9, 0], [x < -4.3 ? -1 : 1, 0, 0], .33, 8, .025, .02); }
  add(In, alongX(cylG(.36, .36, .6, 32)), M.iron, [-4.3, 4.9, 0]); add(In, cylG(.14, .18, .4, 16), M.iron, [-4.3, 5.45, 0]); add(In, cylG(.22, .22, .6, 24), M.teal, [-4.3, 5.95, 0]); add(In, cylG(.24, .24, .05, 24), M.teal, [-4.3, 6.27, 0]);
  add(In, tubeG([[-4.1, 5.9, .2], [-3.9, 5.0, .6], [-3.75, 3.7, .75], [-3.75, 3.2, .4]], .02, 6), M.steel); add(In, tubeG([[-4.5, 6.1, -.2], [-5.0, 5.4, -.5], [-4.3, 3.0, -.7], [-4.25, 2.6, -.3]], .02, 6), M.copper);
  support(In, -5.6, 0, 1.2); add(In, cylG(.34, .34, .5, 32), M.iron, [-5.6, 2.0, 0]); add(In, alongZ(cylG(.18, .2, .35, 20)), M.iron, [-5.6, 1.95, -.45]); boltRing(In, [-5.6, 1.95, -.63], [0, 0, -1], .14, 6, .025, .02); for (const y of [1.78, 2.22]) { add(In, cylG(.4, .4, .05, 32), M.iron, [-5.6, y, 0]); boltRing(In, [-5.6, y, 0], [0, y > 2 ? 1 : -1, 0], .36, 10, .03, .025); } for (const p of [[-5.6, 4.0, 0], [-4.9, 4.9, 0]]) add(In, new THREE.TorusGeometry(.305, .015, 4, 32).rotateX(p[1] === 4.9 ? 0 : PI / 2).rotateY(p[1] === 4.9 ? PI / 2 : 0), M.steel, p);
  // casing (split horizontally, lagged)
  add(Cs, alongX(cylG(1.35, 1.0, 2.6, 96, false, PI, PI)), M.lag, [-2.0, AY, 0]); add(Cs, alongX(cylG(1.35, 1.0, 2.6, 96, false, 0, PI)), M.lag, [-2.0, AY, 0]);
  for (const s of [-1, 1]) { const sh = new THREE.Shape(); const pts = [[-3.3, s * .95], [-.7, s * 1.3], [-.7, s * 1.68], [-3.3, s * 1.33]]; if (s < 0) pts.reverse(); pts.forEach(([a, b], i) => i ? sh.lineTo(a, b) : sh.moveTo(a, b));
    add(Cs, new THREE.ExtrudeGeometry(sh, { depth: .16, bevelEnabled: false }).rotateX(PI / 2).translate(0, AY + .08, 0), M.iron);
    for (let i = 0; i < 20; i++) { const x = -3.2 + i * .1335, z = s * ((rc(x) + .14) + .08); nut(Cs, [x, AY + .08, z], [0, 1, 0], .04, .035); add(Cs, cylG(.018, .018, .1, 6), M.steel, [x, AY + .16, z]); nut(Cs, [x, AY - .08, z], [0, -1, 0], .04, .035); } }
  for (const x of [-2.9, -2.0, -1.1]) add(Cs, new THREE.TorusGeometry(rc(x) + .012, .018, 4, 64).rotateY(PI / 2), M.steel, [x, AY, 0]);
  add(Cs, bboxG(.8, .5, 1.0, .03), M.iron, [-3.0, 4.25, 0]); boltRing(Cs, [-3.0, 4.5, 0], [0, 1, 0], .3, 8, .025, .02);
  add(Cs, bboxG(.7, 2.25, 1.3, .04), M.iron, [-3.75, 2.025, 0]); add(Cs, alongX(cylG(.3, .3, .5, 24)), M.iron, [-3.75, AY + .05, 0]); add(Cs, bboxG(.3, .6, .6, .03), M.iron, [-4.25, 2.6, 0]);
  add(Cs, bboxG(.5, 2.25, 1.3, .04), M.iron, [-.35, 2.025, 0]); add(Cs, alongX(cylG(.28, .28, .45, 24)), M.iron, [-.35, AY + .05, 0]);
  for (const x of [-3.75, -.35]) for (const s of [-1, 1]) { nut(Cs, [x + .15, 3.2, s * .2], [0, 1, 0], .035, .03); nut(Cs, [x - .15, 3.2, s * .2], [0, 1, 0], .035, .03); nut(Cs, [x, .95, s * .55], [0, 1, 0], .05, .04); }
  pipe(Cs, M.steel, [-.6, AY, 0], [.2, AY, 0], .1, 16); add(Cs, alongX(cylG(.22, .22, .12, 24)), M.iron, [-.05, AY, 0]);
  add(Cs, cylG(.5, .5, 1.0, 32), M.lag, [-1.4, 1.4, 0]); for (let i = 0; i < 8; i++) add(Cs, new THREE.TorusGeometry(.52, .035, 8, 40).rotateX(PI / 2), M.steel, [-1.4, 1.08 + i * .05, 0]); add(Cs, cylG(.6, .6, .05, 32), M.iron, [-1.4, 1.5, 0]); boltRing(Cs, [-1.4, 1.525, 0], [0, 1, 0], .56, 10, .03, .025); add(Cs, cylG(.62, .62, .06, 32), M.iron, [-1.4, .93, 0]); boltRing(Cs, [-1.4, .96, 0], [0, 1, 0], .56, 10, .03, .025);
  add(Cs, cylG(.04, .04, .4, 8), M.steel, [-2.2, 1.5, .5]); add(Cs, cylG(.06, .06, .1, 8), M.red, [-2.2, 1.3, .5]);
  // gearbox
  add(Gb, bboxG(1.6, 2.9, 1.8, .06), M.teal, [1.0, 2.35, 0]);
  for (const s of [-1, 1]) for (let i = 0; i < 4; i++) add(Gb, boxG(.06, 2.6, .08), M.teal, [.4 + i * .4, 2.3, s * .93]);
  for (const s of [-1, 1]) { add(Gb, boxG(1.64, .1, .1), M.teal, [1.0, AY, s * .92]); for (let i = 0; i < 8; i++) { nut(Gb, [.3 + i * .2, AY + .05, s * .94], [0, 1, 0], .035, .03); nut(Gb, [.3 + i * .2, AY - .05, s * .94], [0, -1, 0], .035, .03); } for (let i = 0; i < 6; i++) add(Gb, boxG(1.5, .03, .08), M.teal, [1.0, 1.2 + i * .22, s * .93]); }
  add(Gb, boxG(.9, .06, .8), M.teal, [1.0, 3.83, 0]); boltRing(Gb, [1.0, 3.86, 0], [0, 1, 0], .4, 10, .03, .025);
  add(Gb, cylG(.05, .05, .2, 10), M.iron, [1.3, 3.96, .25]); add(Gb, cylG(.09, .09, .06, 12), M.iron, [1.3, 4.07, .25]);
  for (const x of [.15, 1.85]) add(Gb, alongX(cylG(.2, .2, .1, 24)), M.iron, [x, AY, 0]);
  for (const s of [-1, 1]) for (const x of [.35, 1.65]) nut(Gb, [x, .95, s * .8], [0, 1, 0], .05, .04);
  add(Gb, alongZ(cylG(.1, .1, .04, 20)), M.brass, [1.4, 1.4, .92]); dialFace(Gb, 'StOilSight', T.label('OIL', '#d8b04a'), [1.4, 1.4, .941], .08, [0, 0, 1], Gl);
  sticker(Gb, plateM('GearPlate', 'GEARBOX 6000:1500', 'ratio 4.0 · 60 kW', 'ISO VG 46'), .5, .25, [.8, 3.1, .905], 0);
  // shaft (spins about X, origin on axis)
  Sf.position.set(2.55, AY, 0);
  add(Sf, alongX(cylG(.11, .11, 1.5, 20)), M.steel);
  for (const s of [-1, 1]) { add(Sf, alongX(cylG(.3, .3, .24, 32)), M.iron, [s * .2, 0, 0]); for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; const g = sub(Sf, [s * .06, .24 * Math.sin(a), .24 * Math.cos(a)], [s, 0, 0]); add(g, cylG(.035, .035, .03, 6), M.bolt, [0, .015, 0]); } }
  add(Sf, alongX(cylG(.34, .34, .06, 32)), M.steel); add(Sf, alongX(cylG(.12, .12, .05, 6)), M.bolt, [-.72, 0, 0]); add(Sf, alongX(cylG(.12, .12, .05, 6)), M.bolt, [.72, 0, 0]);
  // guard
  add(Gd, alongX(cylG(.62, .62, 1.3, 32, true, PI, PI)), M.guard, [2.55, AY, 0]);
  for (const s of [-1, 1]) { add(Gd, plane(1.3, AY - .95), M.guard, [2.55, (AY + .95) / 2, s * .62], [0, s > 0 ? 0 : PI, 0]); for (const x of [1.9, 3.2]) add(Gd, boxG(.05, AY - .9, .05), M.yellow, [x, (AY + .9) / 2, s * .62]); add(Gd, boxG(1.35, .05, .05), M.yellow, [2.55, .93, s * .62]); add(Gd, boxG(1.35, .04, .04), M.yellow, [2.55, AY, s * .62]); }
  for (const x of [1.9, 3.2]) add(Gd, new THREE.TorusGeometry(.62, .025, 4, 24, PI).rotateY(PI / 2), M.yellow, [x, AY, 0]);
  add(Gd, boxG(1.0, .5, .02), M.yellow, [2.55, 1.3, .64]); sticker(Gd, W.rot, .38, .44, [2.55, 1.32, .652], 0);
  // generator
  add(Ge, alongX(cylG(1.6, 1.6, 2.8, 128)), M.teal, [5.0, AY, 0]); for (const x of [4.1, 5.0, 5.9]) add(Ge, new THREE.TorusGeometry(1.75, .05, 6, 96).rotateY(PI / 2), M.teal, [x, AY, 0]);
  for (const x of [3.42, 6.58]) boltRing(Ge, [x, AY, 0], [x < 5 ? -1 : 1, 0, 0], 1.45, 24, .035, .03);
  add(Ge, latheX([[.4, 0], [1.3, .12], [1.6, .3]], 128), M.teal, [3.3, AY, 0]); add(Ge, latheX([[1.6, 0], [1.3, .18], [.4, .3]], 128), M.teal, [6.4, AY, 0]);
  add(Ge, alongX(cylG(.35, .35, .1, 24)), M.iron, [3.28, AY, 0]);
  for (let i = 0; i < 80; i++) { const a = i / 80 * TAU; if (Math.sin(a) < -.45 || (Math.cos(a) > .96)) continue; add(Ge, boxG(2.7, .16, .04), M.teal, [5.0, AY + 1.68 * Math.sin(a), 1.68 * Math.cos(a)], [PI / 2 - a, 0, 0]); }
  add(Ge, alongX(cylG(1.55, 1.55, .3, 64, true)), M.teal, [6.85, AY, 0]); add(Ge, new THREE.CircleGeometry(1.55, 48).rotateY(PI / 2), M.guard, [6.995, AY, 0]); add(Ge, new THREE.TorusGeometry(1.55, .03, 6, 64).rotateY(PI / 2), M.teal, [6.965, AY, 0]);
  for (let i = 0; i < 4; i++) add(Ge, boxG(.03, 3.1, .05), M.teal, [6.98, AY, 0], [i * PI / 4, 0, 0]);
  for (const x of [3.9, 6.1]) for (const s of [-1, 1]) { add(Ge, boxG(.5, .3, .5), M.teal, [x, 1.05, s * 1.2]); add(Ge, boxG(.5, .75, .1), M.teal, [x, 1.55, s * 1.2]); for (const k of [-1, 1]) nut(Ge, [x + k * .16, 1.2, s * 1.3], [0, 1, 0], .04, .035); }
  add(Ge, bboxG(1.0, .9, .9, .04), M.teal, [5.0, 5.05, 0]); for (const z of [-.28, 0, .28]) { insulator(Ge, [5.0, 5.5, z], .72); add(Ge, cylG(.05, .05, .08, 10), M.copper, [5.0, 6.26, z]); }
  gland(Ge, [5.5, 5.05, .3], [1, 0, 0], .05); for (const x of [4.0, 6.0]) add(Ge, new THREE.TorusGeometry(.12, .035, 8, 16), M.steel, [x, AY + 1.84, 0]);
  add(Ge, boxG(.9, .5, .04), M.teal, [5.0, AY, 1.62]);
  // oil console
  add(Oi, bboxG(2.0, .9, 1.0, .04), M.teal, [-.3, .75, 3.1]);
  for (const x of [-.9, -.5]) { add(Oi, cylG(.14, .14, .45, 20), M.iron, [x, 1.43, 3.1]); add(Oi, cylG(.16, .16, .06, 20), M.iron, [x, 1.68, 3.1]); }
  add(Oi, alongX(cylG(.15, .15, .45, 20)), M.teal, [.35, 1.38, 3.1]); add(Oi, boxG(.2, .2, .2), M.iron, [.0, 1.33, 3.1]);
  pipe(Oi, M.steel, [-1.0, 1.2, 3.45], [-1.0, 1.95, 3.45], .03, 8); gaugeOn(Oi, Gl, 'StOilGauge', [-1.0, 2.05, 3.55], [0, 0, 1], 'bar', 4, .75, .12);
  add(Oi, boxG(.08, .4, .02), M.dark, [.4, .8, 3.61]); add(Oi, cylG(.06, .06, .12, 12), M.iron, [.5, 1.26, 2.8]);
  for (const pts of [[[-.6, 1.2, 2.7], [-1.5, 1.0, 2.0], [-3.4, 1.1, .8], [-3.75, 2.0, .66]], [[-.2, 1.2, 2.7], [-.3, 1.5, 1.5], [-.35, 2.0, .66]], [[.2, 1.2, 2.7], [.6, 1.5, 1.4], [.8, 2.0, .92]]]) add(Oi, tubeG(pts, .03, 6, .3), M.copper);
  // controls
  add(Ct, boxG(1.5, .1, .6), M.concrete, [5.2, .35, 3.2]); add(Ct, bboxG(1.4, 2.1, .5, .03), M.teal, [5.2, 1.45, 3.2]);
  add(Ct, boxG(.86, .46, .02), M.black, [5.0, 2.05, 3.455]); add(Em, plane(.78, .38), lcd('StScreen', T.lcd(['SPEED 1500 rpm', 'POWER  48 kW'], '#0b1a20', '#7cf0c0')), [5.0, 2.05, 3.467]);
  [[5.65, M.emG], [5.85, M.emA]].forEach(([x, m]) => { add(Ct, alongZ(cylG(.07, .07, .02, 18)), M.steel, [x, 2.2, 3.455]); add(Em, revolve([[0, 0], [.05, 0], [.05, .015], [0, .035]], 16).rotateX(PI / 2), m, [x, 2.2, 3.465]); });
  sticker(Ct, tag('RunLabel', 'RUN'), .2, .05, [5.65, 2.06, 3.452], 0);
  add(Ct, alongZ(cylG(.13, .13, .02, 24)), M.yellow, [5.75, 1.6, 3.455]); add(Ct, revolve([[0, 0], [.1, 0], [.11, .04], [.1, .08], [0, .09]], 20).rotateX(PI / 2), M.red, [5.75, 1.6, 3.465]);
  for (const x of [4.7, 5.0]) add(Ct, alongZ(cylG(.05, .05, .04, 12)), M.black, [x, 1.55, 3.47]); add(Ct, boxG(.04, .35, .05), M.steel, [4.55, 1.45, 3.48]);
  louvre(Ct, [5.905, 1.0, 3.2], .35, .45, [1, 0], M.teal); sticker(Ct, W.zap, .26, .26, [5.0, 1.0, 3.452], 0);
  add(Ct, tubeG([[5.2, 2.5, 3.2], [5.2, 3.4, 2.2], [5.25, 4.9, .46]], .04, 6, .3), M.cable);
  // details
  sticker(De, plateM('TurbinePlate', 'COOP STEAM TURBINE 50 kW', 'Single stage · 8 bar · 6000 rpm', 'Gen 400 V 50 Hz · S/N 2026-0301'), .8, .4, [5.0, AY, 1.645], 0);
  sticker(De, W.hot, .3, .3, [-3.0, 4.25, .505], 0); sticker(De, W.rot, .26, .3, [1.45, 3.3, .91], 0);
  sticker(De, tag('SteamIn', '◀ STEAM IN', '#b8281c', '#fff'), .6, .15, [-6.0, 2.4, .32], 0);
  wireTop(R, 'ST_', [5, 6.4, 0]);
  return finish(R);
}

const P = (g, c, n, kind) => ({ g, c, n, kind });
export const SPEC = {
  WaterPump: { pfx: 'WP_', s: [8, 7, 8], tri: [12000, 25000], wire: [-1, 6.6, 0], groups: ['Pad', 'Wellhead', 'Pump', 'Motor', 'Fan', 'Piping', 'Roof', 'Controls', 'Details', 'PortOut', 'Emissive', 'Glass', 'WireTop'],
    ports: [P('WP_PortOut', [4, 1.5, 0], [1, 0, 0], 'water')], solids: [['WP_Motor', [0, 4.0, -.3], [.6, 5.25, .3]], ['WP_Pump', [.1, 1.0, -.2], [.5, 3.1, .2]]] },
  WaterTank: { pfx: 'WT_', s: [8, 10, 8], tri: [10000, 20000], groups: ['Stand', 'Tank', 'Ladder', 'Piping', 'Gauge', 'Level', 'PortIn', 'PortOut', 'Details', 'Glass'],
    ports: [P('WT_PortIn', [-4, 1.5, 0], [-1, 0, 0], 'water'), P('WT_PortOut', [4, 1.5, 0], [1, 0, 0], 'water')], solids: [['WT_Tank', [-2, 6.0, -2], [2, 9.1, 2]]] },
  Boiler: { pfx: 'BO_', s: [14, 12, 12], hmax: 13, tri: [50000, 80000], wire: [5, 9, -4], straw: -7, groups: ['Foundation', 'Feeder', 'Furnace', 'Shell', 'Fittings', 'Pump', 'Chimney', 'Catwalk', 'Controls', 'Details', 'PortWater', 'PortOut', 'Fire', 'Emissive', 'Glass', 'WireTop'],
    ports: [P('BO_PortWater', [0, 1.5, -6], [0, 0, -1], 'water'), P('BO_PortOut', [7, 1.5, 0], [1, 0, 0], 'steam')], solids: [['BO_Furnace', [-3.9, .4, -2.2], [-1.1, 6.6, 2.2]], ['BO_Shell', [-.9, 3.2, -1.4], [4.5, 6.0, 1.4]], ['BO_Controls', [4.5, .4, 4.1], [6.1, 2.4, 4.7]]] },
  SteamTurbine: { pfx: 'ST_', s: [14, 8, 8], tri: [35000, 60000], wire: [5, 6.4, 0], groups: ['Bed', 'Inlet', 'Casing', 'Gearbox', 'Shaft', 'Guard', 'Generator', 'Oil', 'Controls', 'Details', 'PortIn', 'Emissive', 'Glass', 'WireTop'],
    ports: [P('ST_PortIn', [-7, 1.5, 0], [-1, 0, 0], 'steam')], solids: [['ST_Generator', [3.7, 2.0, -1.0], [6.3, 3.8, 1.0]], ['ST_Gearbox', [.2, 1.0, -.9], [1.8, 3.8, .9]], ['ST_Casing', [-3.2, 2.2, -.7], [-.8, 3.6, .7]]] },
};
export const BUILD = { WaterPump: buildWaterPump, WaterTank: buildWaterTank, Boiler: buildBoiler, SteamTurbine: buildSteamTurbine };
