// Depot pack: CollectionPoint + BuyerDepot. Shares textures, materials and helpers with the power pack.
import { THREE, V3, TAU, DS, rnd, rr, setSeed, mat, decalMat, boxG, bboxG, cylG, alongX, alongZ, revolve, latheX, frustumG, tubeG, add, pipe, beam, sub, plane, cv, texFrom, normalFrom } from './power_lib.js';
import { T, M, finish, nut, anchor, pad, flat, sticker, prismXY, louvre, dialFace, label, lcd, grpOf, root } from './power_machines.js';
export { M };
const PI = Math.PI, PT = .3;

/* ---------- textures (pack additions) ---------- */
function wrapDot(x, S, px, py, r, c) { for (const ox of [-S, 0, S]) for (const oy of [-S, 0, S]) { const X = px + ox, Y = py + oy; if (X + r < 0 || X - r > S || Y + r < 0 || Y - r > S) continue;
  const g = x.createRadialGradient(X, Y, 0, X, Y, r); g.addColorStop(0, `rgba(${c[0]},${c[1]},${c[2]},${c[3]})`); g.addColorStop(1, `rgba(${c[0]},${c[1]},${c[2]},0)`); x.fillStyle = g; x.fillRect(X - r, Y - r, 2 * r, 2 * r); } }
function wear(x, S, H, n, a0 = .2, a1 = .8, r0 = .8, r1 = 3.2) { x.globalCompositeOperation = 'destination-out'; for (let i = 0; i < n; i++) { x.globalAlpha = rr(a0, a1); x.beginPath(); x.arc(rnd() * S, rnd() * H, rr(r0, r1), 0, TAU); x.fill(); } x.globalAlpha = 1; x.globalCompositeOperation = 'source-over'; }
const D = {};
{ const S = 512, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#e4e5e2'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < 70; i++) wrapDot(x, S, rnd() * S, rnd() * S, rr(20, 90), rnd() < .5 ? [250, 250, 248, .25] : [165, 160, 150, .2]);
  for (let i = 0; i < 46; i++) { const px = rnd() * S, py = rnd() * S, L = rr(30, 170), g = x.createLinearGradient(0, py, 0, py + L); g.addColorStop(0, 'rgba(120,96,64,.24)'); g.addColorStop(1, 'rgba(120,96,64,0)'); x.fillStyle = g; x.fillRect(px, py, rr(2, 5), L); }
  for (let i = 0; i < 1600; i++) { x.fillStyle = `rgba(${rnd() < .5 ? '90,88,80' : '255,255,255'},${rr(.05, .2)})`; x.fillRect(rnd() * S, rnd() * S, rr(1, 2.5), rr(1, 2.5)); }
  D.sheet = texFrom(c); }
{ const S = 256, hc = cv(S, S), h = hc.getContext('2d'); for (let xx = 0; xx < S; xx++) { const t = (xx % 64) / 64, v = t < .15 ? t / .15 : t < .35 ? 1 : t < .5 ? 1 - (t - .35) / .15 : 0, g = 60 + v * 160 | 0; h.fillStyle = `rgb(${g},${g},${g})`; h.fillRect(xx, 0, 1, S); } D.ribN = normalFrom(hc, 6); }
{ const S = 256, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#c3c7c6'; x.fillRect(0, 0, S, S); h.fillStyle = '#808080'; h.fillRect(0, 0, S, S);
  for (let y = 0; y < S; y += 32) { x.fillStyle = 'rgba(60,64,64,.55)'; x.fillRect(0, y, S, 3); x.fillStyle = 'rgba(255,255,255,.35)'; x.fillRect(0, y + 4, S, 2); h.fillStyle = '#202020'; h.fillRect(0, y, S, 4); h.fillStyle = '#d8d8d8'; h.fillRect(0, y + 10, S, 14); }
  for (let i = 0; i < 30; i++) wrapDot(x, S, rnd() * S, rnd() * S, rr(10, 40), [110, 100, 80, .18]); D.shut = texFrom(c); D.shutN = normalFrom(hc, 3); }
{ const S = 256, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#2a1e12'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < 4; i++) { const y = 6 + i * 63, l = rr(.85, 1.1); x.fillStyle = `rgb(${178 * l | 0},${138 * l | 0},${90 * l | 0})`; x.fillRect(0, y, S, 54);
    for (let k = 0; k < 26; k++) { x.fillStyle = `rgba(${rnd() < .5 ? '120,84,48' : '215,180,130'},${rr(.15, .4)})`; x.fillRect(0, y + rnd() * 54, S, rr(.5, 1.6)); }
    for (const nx of [14, S - 14]) for (const ny of [16, 38]) { x.fillStyle = '#3a3a38'; x.beginPath(); x.arc(nx, y + ny, 2.4, 0, TAU); x.fill(); } }
  x.fillStyle = 'rgba(30,24,18,.82)'; x.font = '700 50px "IBM Plex Sans Condensed",sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText('PELLET', S / 2, S / 2 + 4);
  D.crate = texFrom(c); }
{ const S = 256, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#e9e6dc'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < S; i += 4) { x.fillStyle = 'rgba(150,145,130,.18)'; x.fillRect(i, 0, 1.5, S); x.fillRect(0, i, S, 1.5); }
  for (let i = 0; i < 22; i++) wrapDot(x, S, rnd() * S, S * rr(.65, 1), rr(20, 60), [120, 88, 52, .28]);
  x.fillStyle = 'rgba(30,95,90,.85)'; x.fillRect(0, S * .12, S, 10); D.bag = texFrom(c); }
D.logo = (() => { const S = 1024, c = cv(S, S), x = c.getContext('2d'), m = S / 2;
  x.fillStyle = '#f4f2ea'; x.beginPath(); x.arc(m, m, 490, 0, TAU); x.fill(); x.lineWidth = 26; x.strokeStyle = '#1d5d59'; x.beginPath(); x.arc(m, m, 460, 0, TAU); x.stroke();
  x.save(); x.translate(m, m + 20); x.rotate(-.45); x.fillStyle = '#3b8a3e'; x.beginPath(); x.moveTo(0, -370); x.bezierCurveTo(270, -220, 270, 200, 0, 330); x.bezierCurveTo(-270, 200, -270, -220, 0, -370); x.fill();
  x.strokeStyle = '#2a6a2c'; x.lineWidth = 16; x.beginPath(); x.moveTo(0, 320); x.lineTo(0, 410); x.stroke(); x.restore();
  const fl = (sc, col) => { x.save(); x.translate(m, m + 130); x.scale(sc, sc); x.fillStyle = col; x.beginPath(); x.moveTo(0, 120); x.bezierCurveTo(-130, 110, -150, -20, -70, -110); x.bezierCurveTo(-60, -40, -20, -30, -10, -60);
    x.bezierCurveTo(-30, -150, 20, -230, 60, -260); x.bezierCurveTo(40, -170, 150, -110, 130, 0); x.bezierCurveTo(120, 80, 70, 118, 0, 120); x.fill(); x.restore(); };
  fl(1.05, '#e8742a'); fl(.62, '#f3c03a'); wear(x, S, S, 1100, .2, .8, .8, 3.5); return texFrom(c, true, false); })();
D.pict = (() => { const S = 512, c = cv(S, S), x = c.getContext('2d'); x.strokeStyle = x.fillStyle = '#e2b21c'; x.lineCap = 'round';
  x.lineWidth = 18; x.beginPath(); x.arc(S / 2, S / 2, 234, 0, TAU); x.stroke(); x.lineWidth = 10;
  for (let i = -7; i <= 7; i++) { const a = i * .09; x.beginPath(); x.moveTo(S / 2 + i * 6, 300); x.quadraticCurveTo(S / 2 + i * 9, 220, S / 2 + Math.sin(a) * 190, 300 - Math.cos(a) * 190); x.stroke(); x.beginPath(); x.moveTo(S / 2 + i * 6, 300); x.lineTo(S / 2 + i * 10, 420); x.stroke(); }
  x.fillRect(S / 2 - 74, 288, 148, 28); for (let i = -3; i <= 3; i++) { const a = i * .2; x.beginPath(); x.ellipse(S / 2 + Math.sin(a) * 196 + 10, 300 - Math.cos(a) * 196 + 16, 10, 24, a + .6, 0, TAU); x.fill(); }
  wear(x, S, S, 600); return texFrom(c, true, false); })();
D.walk = (() => { const W = 256, H = 512, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#e2b21c'; x.fillRect(0, 0, W, H); x.fillStyle = '#2b2b28';
  for (let k = 0; k < 4; k++) { const y = 70 + k * 120; x.beginPath(); x.moveTo(W / 2, y); x.lineTo(W / 2 + 70, y + 60); x.lineTo(W / 2 + 46, y + 60); x.lineTo(W / 2, y + 24); x.lineTo(W / 2 - 46, y + 60); x.lineTo(W / 2 - 70, y + 60); x.closePath(); x.fill(); }
  wear(x, W, H, 1400, .2, .9, 1, 5); return texFrom(c, true, false); })();
D.wet = (() => { const S = 256, c = cv(S, S), x = c.getContext('2d'); for (let i = 0; i < 14; i++) { const px = S / 2 + rr(-50, 50), py = S / 2 + rr(-50, 50), r = rr(40, 100), g = x.createRadialGradient(px, py, 0, px, py, r); g.addColorStop(0, 'rgba(28,24,18,.42)'); g.addColorStop(1, 'rgba(28,24,18,0)'); x.fillStyle = g; x.fillRect(0, 0, S, S); } return texFrom(c, true, false); })();
D.chalk = (() => { const W = 512, H = 384, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#22302a'; x.fillRect(0, 0, W, H);
  for (let i = 0; i < 40; i++) { const px = rnd() * W, py = rnd() * H, r = rr(30, 120), g = x.createRadialGradient(px, py, 0, px, py, r); g.addColorStop(0, 'rgba(220,225,215,.08)'); g.addColorStop(1, 'rgba(220,225,215,0)'); x.fillStyle = g; x.fillRect(0, 0, W, H); }
  x.strokeStyle = 'rgba(230,232,225,.12)'; x.lineWidth = 18; for (let i = 0; i < 6; i++) { x.beginPath(); x.moveTo(rr(20, 200), rr(40, 340)); x.quadraticCurveTo(rr(150, 350), rr(40, 340), rr(300, 490), rr(40, 340)); x.stroke(); } return texFrom(c, true, false); })();
const bayTex = n => { const S = 256, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#e2ae14'; x.fillRect(0, 0, S, S); x.strokeStyle = '#151515'; x.lineWidth = 14; x.strokeRect(10, 10, S - 20, S - 20);
  x.fillStyle = '#151515'; x.font = '700 210px "IBM Plex Sans Condensed",sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText(String(n), S / 2, S / 2 + 12); wear(x, S, S, 260, .2, .7, .6, 2.4); return texFrom(c, true, false); };

const Q = {
  clad: mat('Cladding', 'CladdingTeal', { map: D.sheet, normalMap: D.ribN, color: 0x2c7b76, roughness: .5, metalness: .3 }, .5),
  cladW: mat('CladdingWhite', 'CladdingWhiteBand', { map: D.sheet, normalMap: D.ribN, color: 0xf1f0ea, roughness: .5, metalness: .25 }, .5),
  roofTeal: mat('RoofTeal', 'RoofSheetTeal', { map: D.sheet, color: 0x2c7b76, roughness: .45, metalness: .35, side: DS }, .25),
  roofGrey: mat('RoofGrey', 'RoofSheetGrey', { map: D.sheet, color: 0xb9bebc, roughness: .42, metalness: .55, side: DS }, .25),
  shut: mat('Shutter', 'RollerShutter', { map: D.shut, normalMap: D.shutN, roughness: .4, metalness: .6 }, 1),
  crate: mat('Crate', 'PelletCrate', { map: D.crate, roughness: .8 }, 1 / 1.5),
  bag: mat('BulkBag', 'BulkBagWoven', { map: D.bag, roughness: .85 }, 1),
  render: mat('Render', 'OfficeRender', { map: D.sheet, color: 0xe9e3d3, roughness: .85 }, .3),
  alu: mat('Alu', 'AluminiumFrame', { color: 0xc5c9ca, roughness: .35, metalness: .8 }),
  warm: mat('OfficeLight', 'OfficeWindowLight', { color: 0xf5e6c6, emissive: 0xffd9a0, emissiveIntensity: .9, roughness: .9 }),
  lampLit: mat('LampLit', 'LampHeadLight', { color: 0xfffbe8, emissive: 0xfff2cc, emissiveIntensity: 1.3, roughness: .5 }),
  leaf: mat('Leaves', 'PlantLeaves', { color: 0x3f7a35, roughness: .8 }),
  pot: mat('Pot', 'TerracottaPot', { color: 0xa8562e, roughness: .85 }),
  cab: mat('TruckCab', 'TruckCabBlue', { map: D.sheet, color: 0x2f62a8, roughness: .35, metalness: .3 }, .4),
  tglass: mat('TruckGlass', 'TruckGlassDark', { color: 0x1b262b, roughness: .08, metalness: .6 }),
  drumB: mat('DrumBlue', 'DrumBluePlastic', { color: 0x2a5fb0, roughness: .5 }),
  drumR: mat('DrumRed', 'DrumRedSteel', { map: D.sheet, color: 0xa8302a, roughness: .45, metalness: .4 }, .5),
  hose: mat('Hose', 'HoseGreen', { color: 0x2f8a3c, roughness: .5 }),
  wetStraw: mat('WetStraw', 'WetStraw', { map: M.straw.map || null, color: 0x9b7c4c, roughness: .75 }, M.straw.userData.uvScale || 1),
  twine: mat('Twine', 'TwineSisal', { color: 0xb59a6a, roughness: .9 }),
  water: mat('Water', 'WaterDrip', { color: 0x9cc4d8, roughness: .05, metalness: .2 }),
  chalk: label('Chalkboard', D.chalk),
  logo: decalMat('Logo', 'LogoFlameLeaf', D.logo),
  pict: decalMat('Pictogram', 'PictogramStraw', D.pict),
  walk: decalMat('Walkway', 'WalkwayPaint', D.walk),
  wet: decalMat('Wet', 'WetConcrete', D.wet),
};

/* ---------- helpers ---------- */
function prismX(g, m, pts, x0, x1) { const s = new THREE.Shape(); pts.forEach(([a, b], i) => i ? s.lineTo(a, b) : s.moveTo(a, b)); const geo = new THREE.ExtrudeGeometry(s, { depth: x1 - x0, bevelEnabled: false }); geo.rotateY(-PI / 2); geo.translate(x1, 0, 0); return add(g, geo, m); }
function corrSheet(w, d, period, amp) { const nx = Math.round(w / period) * 4, g = new THREE.PlaneGeometry(w, d, nx, 1); g.rotateX(-PI / 2); const p = g.attributes.position, uv = g.attributes.uv;
  for (let i = 0; i < p.count; i++) { p.setY(i, amp * Math.sin(p.getX(i) / period * TAU)); uv.setXY(i, p.getX(i), p.getZ(i)); } g.computeVertexNormals(); return g; }
function col(g, m, x, z, y0, y1, w = .3, d = .3, ry = 0) { const s = new THREE.Group(); s.position.set(x, (y0 + y1) / 2, z); s.rotation.y = ry; g.add(s); const h = y1 - y0;
  add(s, boxG(w, h, .035), m, [0, 0, d / 2 - .0175]); add(s, boxG(w, h, .035), m, [0, 0, -d / 2 + .0175]); add(s, boxG(.03, h, d - .07), m); return s; }
function basePlate(g, x, y, z, s = .5) { add(g, boxG(s, .03, s), M.galv, [x, y + .015, z]); for (const a of [-1, 1]) for (const b of [-1, 1]) nut(g, [x + a * s * .36, y + .03, z + b * s * .36], [0, 1, 0], .035, .03); }
function bagG(w, h, d) { const g = new THREE.BoxGeometry(w, h, d, 3, 4, 3), p = g.attributes.position;
  for (let i = 0; i < p.count; i++) { const y = p.getY(i) / (h / 2), b = 1 + .1 * (1 - y * y), s = y > .9 ? .94 : 1; p.setX(i, p.getX(i) * b * s); p.setZ(i, p.getZ(i) * b * s); if (y > .9) p.setY(i, p.getY(i) - .05 * (1 - Math.abs(p.getX(i)) / w * 2)); }
  g.computeVertexNormals(); return g; }
function pallet(g, x, y, z, ry = 0) { const s = new THREE.Group(); s.position.set(x, y, z); s.rotation.y = ry; g.add(s); add(s, boxG(1.6, .05, 1.6), M.timber, [0, .135, 0]); for (const k of [-.7, 0, .7]) add(s, boxG(1.6, .11, .16), M.timber, [0, .055, k]); return y + .16; }
function crate(g, x, y, z, ry = 0) { add(g, boxG(1.5, 1.4, 1.5), Q.crate, [x, y + .7, z], [0, ry, 0]); return y + 1.4; }
function bag(g, x, y, z, ry = 0) { const s = new THREE.Group(); s.position.set(x, y, z); s.rotation.y = ry; g.add(s); add(s, bagG(1.4, 1.6, 1.4), Q.bag, [0, .8, 0]);
  for (const [a, b] of [[-1, -1], [-1, 1], [1, -1], [1, 1]]) add(s, new THREE.TorusGeometry(.12, .025, 3, 6, PI), Q.bag, [a * .56, 1.55, b * .56], [0, a * b > 0 ? PI / 4 : -PI / 4, 0]);
  add(s, cylG(.14, .2, .18, 8), Q.bag, [0, 1.62, 0]); add(s, new THREE.TorusGeometry(.14, .02, 3, 8).rotateX(PI / 2), M.twine || Q.twine, [0, 1.66, 0]); return y + 1.7; }
function bundle(g, p, ry = 0, rx = 0) { const s = new THREE.Group(); s.position.set(p[0], p[1], p[2]); s.rotation.set(rx, ry, 0); g.add(s);
  add(s, alongZ(cylG(.3, .32, 1.0, 14)), Q.wetStraw); for (const z of [-.24, .24]) add(s, new THREE.TorusGeometry(.31, .016, 4, 16), Q.twine, [0, 0, z]);
  for (const e of [-1, 1]) for (let k = 0; k < 9; k++) { const a = rnd() * TAU, r = rr(0, .26); add(s, boxG(.014, .024, rr(.12, .26)), Q.wetStraw, [r * Math.cos(a), r * Math.sin(a), e * (.5 + .05)], [rr(-.35, .35), rr(-.35, .35), 0]); } return s; }
function drum(g, x, y, z, m, plastic) { add(g, cylG(.3, .3, .9, 22), m, [x, y + .45, z]); for (const h of plastic ? [.3, .6] : [.3, .6]) add(g, new THREE.TorusGeometry(.305, .018, 4, 22).rotateX(PI / 2), m, [x, y + h, z]);
  add(g, cylG(.06, .06, .03, 10), plastic ? M.black : M.bolt, [x + .15, y + .915, z + .05]); }

/* ================= 1. Collection point ================= */
export function buildCollectionPoint() {
  setSeed(901); const R = root('CollectionPoint'), G = grpOf(R, 'CP_');
  const Pd = G('Pad'), Fr = G('Frame'), Rf = G('Roof'), Hp = G('Hopper'), Bt = G('Belt'), St = G('Straw'), Pr = G('Props'), De = G('Details'), Em = G('Emissive'), Gl = G('Glass');
  pad(Pd, 12, 12, PT, [[-5.6, -5.6], [5.6, -5.6], [-5.6, 5.6], [5.6, 5.6], [0, -5.6], [-5.6, 0]]);
  add(Pd, flat(2.4, 3.9), Q.walk, [-1.5, PT + .004, 3.88]); add(Pd, flat(2.7, 2.7), Q.pict, [2.9, PT + .005, 3.35]);
  for (const [x, z, w, d] of [[-1.5, 0, 6.4, 4.8], [-1.0, 2.1, 3.2, 1.8], [2.3, 5.45, 3.6, .8], [-5.3, 5.4, 1.0, .8], [-3.9, -4.9, 1.6, 1.4], [1.2, -2.4, 2.4, 1.2]]) add(Pd, flat(w, d), Q.wet, [x, PT + .003, z]);
  add(Pd, flat(1.2, 1.0), M.rust, [-1.4, PT + .006, -2.0]);

  // ---- frame: two portal frames at x = ±4.6 ----
  const ta = Math.tan(22 * PI / 180), RY = 10, rafY = z => 9.57 - Math.abs(z) * ta;
  for (const x of [-4.6, 4.6]) {
    for (const z of [-4.4, 4.4]) { col(Fr, M.teal, x, z, PT, 7.64, .3, .3); basePlate(Fr, x, PT, z, .52); add(Fr, boxG(.42, .8, .42), M.hazard, [x, PT + .4, z]); }
    for (const s of [-1, 1]) beam(Fr, M.teal, [x, rafY(5.9), s * 5.9], [x, rafY(0), 0], .2, .3);
    add(Fr, boxG(.16, .16, 4.06), M.teal, [x, 8.55, 0]);
    for (const s of [-1, 1]) { beam(Fr, M.teal, [x, 6.55, s * 4.4], [x, rafY(3.0) - .14, s * 3.0], .1, .1); add(Fr, boxG(.34, .34, .02), M.teal, [x, rafY(4.4) - .08, s * 4.42]); }
    add(Fr, boxG(.3, .5, .02), M.teal, [x, 9.45, 0]); for (const y of [9.3, 9.6]) for (const k of [-1, 1]) nut(Fr, [x + .16, y, k * .08], [1, 0, 0], .03, .025); }
  for (const z of [-4.4, 4.4]) add(Fr, boxG(9.5, .25, .2), M.teal, [0, 7.52, z]);
  for (const z of [-5.8, -4.8, -3.4, -2.0, -.6, .6, 2.0, 3.4, 4.8, 5.8]) add(Fr, boxG(12, .2, .07), M.galv, [0, 9.82 - Math.abs(z) * ta - .02, z], [Math.sign(z) * Math.atan(ta), 0, 0]);
  for (const s of [-1, 1]) { pipe(Fr, M.steel, [-4.45, 1.0, -4.4 * 1], [4.45, 7.3, -4.4], .02, 6); pipe(Fr, M.steel, [4.45, 1.0, -4.4], [-4.45, 7.3, -4.4], .02, 6);
    pipe(Fr, M.steel, [-4.6, 1.0, s * 4.25], [-4.6, 7.3, -s * 4.25], .02, 6); }

  // ---- roof: teal corrugated, ridge at y = 10 ----
  const L = 5.92 / Math.cos(Math.atan(ta));
  for (const s of [-1, 1]) add(Rf, corrSheet(12, L, .25, .035), Q.roofTeal, [0, RY - .045 - 2.96 * ta, s * 2.96], [s * Math.atan(ta), 0, 0]);
  prismX(Rf, M.teal, [[-.35, RY - .35 * ta], [0, RY], [.35, RY - .35 * ta], [.35, RY - .35 * ta - .03], [0, RY - .03], [-.35, RY - .35 * ta - .03]], -6, 6);
  for (const s of [-1, 1]) { const y = RY - 5.92 * ta - .14; add(Rf, boxG(12, .02, .18), M.galv, [0, y - .08, s * 5.9]); add(Rf, boxG(12, .16, .02), M.galv, [0, y, s * 5.82]); add(Rf, boxG(12, .16, .02), M.galv, [0, y, s * 5.98]);
    for (const x of [-4.6, 0, 4.6]) add(Rf, boxG(.03, .2, .2), M.galv, [x, y, s * 5.9]); }
  for (const s of [-1, 1]) for (const x of [-6.0 + .02, 6 - .02]) beam(Rf, M.teal, [x, RY - 5.92 * ta - .1, s * 5.86], [x, RY - .1, 0], .04, .12);
  const gy = RY - 5.92 * ta - .22;
  pipe(Rf, M.galv, [-5.8, gy, 5.9], [-5.8, .5, 5.9], .06, 10); add(Rf, alongX(cylG(.06, .06, .25, 10)), M.galv, [-5.67, .47, 5.9]); add(Rf, boxG(.5, .06, .3), M.concrete, [-5.45, PT + .03, 5.75]);
  for (const y of [2, 4.5, 6.8]) add(Rf, boxG(.12, .05, .14), M.galv, [-5.8, y, 5.85]);
  // beacon: base on the ridge, dome in CP_Emissive
  add(Rf, boxG(.16, .03, .5), M.galv, [1.5, RY - .26 * ta - .005, .26], [Math.atan(ta), 0, 0]); add(Rf, cylG(.09, .09, .06, 16), M.iron, [1.5, 9.83, .55]); add(Rf, cylG(.03, .03, .06, 8), M.iron, [1.5, 9.78, .55]);
  add(Em, revolve([[.075, 0], [.075, .05], [.05, .1], [0, .12]], 18), M.emA, [1.5, 9.86, .55]);
  for (let i = 0; i < 4; i++) { const a = i / 4 * TAU; add(Rf, boxG(.012, .1, .012), M.iron, [1.5 + .08 * Math.cos(a), 9.91, .55 + .08 * Math.sin(a)]); }
  add(Rf, tubeG([[1.5, 9.8, .5], [1.2, 9.73, .3], [.6, 9.62, .1], [-1.0, 9.6, -.02]], .012, 4), M.cable);

  // ---- hopper: steel trough + grid, x -3.6..0.6 ----
  const x0 = -3.6, x1 = .6, k = 1.13 / 9.4, yb = x => .62 + (x + 3.4) * k;
  for (const s of [-1, 1]) { prismX(Hp, M.teal, s > 0 ? [[1.0, .5], [1.65, 1.4], [1.7, 1.4], [1.05, .5]] : [[-1.05, .5], [-1.7, 1.4], [-1.65, 1.4], [-1.0, .5]], x0, x1);
    add(Hp, boxG(x1 - x0, .2, .05), M.teal, [(x0 + x1) / 2, .4, s * 1.025]);
    for (const x of [-2.6, -1.5, -.4]) prismX(Hp, M.teal, s > 0 ? [[1.05, .5], [1.7, 1.4], [1.78, 1.4], [1.1, .4]] : [[-1.1, .4], [-1.78, 1.4], [-1.7, 1.4], [-1.05, .5]], x - .03, x + .03);
    add(Hp, boxG(x1 - x0 + .1, .06, .06), M.galv, [(x0 + x1) / 2, 1.43, s * 1.7]); add(Hp, boxG(x1 - x0 + .1, .006, .12), M.hazard, [(x0 + x1) / 2, 1.463, s * 1.72]); }
  add(Hp, boxG(.05, 1.1, 3.4), M.teal, [x0, .85, 0]); add(Hp, boxG(.06, .06, 3.46), M.galv, [x0, 1.43, 0]);
  for (const s of [-1, 1]) { add(Hp, boxG(.05, 1.1, .75), M.teal, [x1, .85, s * 1.33]); }
  for (const [x, z] of [[x0, -1.7], [x0, 1.7], [x1, -1.7], [x1, 1.7], [-1.5, -1.7], [-1.5, 1.7]]) { add(Hp, boxG(.12, 1.1, .12), M.galv, [x + (x === x0 ? .06 : x === x1 ? -.06 : 0), .85, z + (z > 0 ? -.06 : .06)]); }
  for (let i = 0; i <= 10; i++) add(Hp, boxG(4.2, .05, .025), M.galv, [(x0 + x1) / 2, 1.445, -1.5 + i * .3]);
  for (const x of [-3.0, -2.0, -1.0, 0]) add(Hp, boxG(.04, .07, 3.4), M.galv, [x, 1.435, 0]);
  for (const s of [-1, 1]) { add(Hp, boxG(.08, 1.0, .08), M.galv, [x1 + .02, 1.6, s * .95]); } add(Hp, boxG(.1, .1, 2.0), M.galv, [x1 + .02, 2.12, 0]);
  add(Hp, boxG(.04, .5, 1.7), M.galv, [x1 + .06, 1.75, 0]); pipe(Hp, M.steel, [x1 + .02, 2.17, 0], [x1 + .02, 2.4, 0], .02, 8); add(Hp, new THREE.TorusGeometry(.14, .02, 6, 18).rotateX(PI / 2), M.red, [x1 + .02, 2.42, 0]);
  for (const s of [-1, 1]) sticker(Hp, M.rust, .6, .5, [-2.0 + s * .9, .9, s * 1.9], s > 0 ? 0 : PI);

  // ---- straw in the hopper (origin at hopper floor, full at scale.y = 1) ----
  St.position.set(-1.5, .62, 0);
  { const g = new THREE.PlaneGeometry(3.9, 2.1, 28, 14); g.rotateX(-PI / 2); const p = g.attributes.position;
    const hs = (x, z) => Math.max(.02, .7 * (1 - Math.pow(Math.abs(z) / 1.08, 3)) * (1 - Math.pow(Math.abs(x) / 2.0, 6)) + .04 * Math.sin(x * 5.1 + z * 3.3));
    for (let i = 0; i < p.count; i++) p.setY(i, hs(p.getX(i), p.getZ(i)));
    g.computeVertexNormals(); add(St, g, Q.wetStraw);
    for (let i = 0; i < 640; i++) { const x = rr(-1.9, 1.9), z = rr(-1.0, 1.0); add(St, boxG(rr(.14, .34), .012, .022), Q.wetStraw, [x, hs(x, z) + rr(.005, .04), z], [rr(-.5, .5), rr(0, PI), rr(-.5, .5)]); } }

  // ---- inclined belt from the hopper out through the east side (ends at x = 6) ----
  add(Bt, new THREE.ExtrudeGeometry(new THREE.Shape([new THREE.Vector2(-3.4, yb(-3.4) - .02), new THREE.Vector2(6, 1.73), new THREE.Vector2(6, 1.75), new THREE.Vector2(-3.4, yb(-3.4))]), { depth: 1.6, bevelEnabled: false }).translate(0, 0, -.8), M.rubber);
  for (const s of [-1, 1]) prismXY(Bt, M.teal, [[-3.55, yb(-3.55) + .05], [6, 1.8], [6, 1.5], [-3.55, yb(-3.55) - .25]], s > 0 ? .85 : -.95, s > 0 ? .95 : -.85);
  add(Bt, alongZ(cylG(.15, .15, 1.6, 18)), M.iron, [-3.4, .47, 0]); add(Bt, alongZ(cylG(.17, .17, 1.6, 18)), M.iron, [5.8, 1.58, 0]);
  for (const s of [-1, 1]) { add(Bt, boxG(.2, .16, .12), M.iron, [5.8, 1.58, s * 1.03]); add(Bt, boxG(.2, .14, .1), M.iron, [-3.4, .47, s * 1.0]); }
  for (let x = -2.6; x < 5.4; x += .9) add(Bt, alongZ(cylG(.06, .06, 1.7, 10)), M.steel, [x, yb(x) - .08, 0]);
  add(Bt, new THREE.ExtrudeGeometry(new THREE.Shape([new THREE.Vector2(-1.4, yb(-1.4) - .32), new THREE.Vector2(5.6, yb(5.6) - .32), new THREE.Vector2(5.6, yb(5.6) - .3), new THREE.Vector2(-1.4, yb(-1.4) - .3)]), { depth: 1.5, bevelEnabled: false }).translate(0, 0, -.75), M.rubber);
  for (const x of [1.6, 3.4, 5.1]) { for (const s of [-1, 1]) { add(Bt, boxG(.08, yb(x) - .25 - PT, .08), M.galv, [x, PT + (yb(x) - .25 - PT) / 2, s * .9]); basePlate(Bt, x, PT, s * .9, .22); } beam(Bt, M.galv, [x, .5, -.9], [x, yb(x) - .3, .9], .04, .04); }
  add(Bt, alongZ(cylG(.18, .18, .55, 18)), M.teal, [4.3, .78, -.25]); add(Bt, bboxG(.36, .36, .3, .03), M.iron, [4.3, .78, .2]); add(Bt, boxG(.5, .04, .6), M.galv, [4.3, .58, 0]); add(Bt, boxG(.06, .28, .06), M.galv, [4.3, .44, 0]);
  beam(Bt, M.yellow, [4.4, .82, 1.05], [5.8, 1.58, 1.05], .26, .08);
  for (const x of [1.6, 3.4, 5.1]) add(Bt, boxG(.04, .45, .04), M.yellow, [x, yb(x) + .2, 1.05]);
  add(Bt, tubeG([[1.6, yb(1.6) + .4, 1.05], [3.4, yb(3.4) + .4, 1.05], [5.1, yb(5.1) + .4, 1.05]], .008, 4, .1), M.red);
  add(Bt, bboxG(.14, .2, .1, .02), M.yellow, [1.6, yb(1.6) + .32, 1.12]);
  for (let i = 0; i < 46; i++) { const x = rr(.8, 5.8); add(Bt, boxG(rr(.14, .3), .012, .022), Q.wetStraw, [x, yb(x) + .012, rr(-.7, .7)], [0, rr(0, PI), 0]); }

  // ---- props ----
  for (const [x, y] of [[-5.55, 0], [-4.85, 0], [-4.15, 0], [-5.2, 1], [-4.5, 1], [-4.85, 2]]) bundle(Pr, [x, PT + .335 + y * .56, 5.3], 0);
  bundle(Pr, [-3.35, PT + .67, 4.85], 0, -1.15); bundle(Pr, [-5.25, PT + .67, 4.0], PI / 2, -1.2);
  { const s = sub(Pr, [-4.3, PT, 2.3]); add(s, boxG(1.2, .1, 1.2), M.galv, [0, .05, 0]); add(s, plane(1.1, 1.1).rotateX(-PI / 2), T.mesh ? mat('Checker', 'CheckerPlate', { map: T.galv, normalMap: T.galvN, color: 0xc9cccb, metalness: .7, roughness: .4 }, 2) : M.galv, [0, .102, 0]);
    add(s, boxG(.08, 1.2, .08), M.galv, [0, .7, -.58]); add(s, alongZ(cylG(.2, .2, .1, 28)), M.red, [0, 1.42, -.58]); add(s, new THREE.TorusGeometry(.2, .015, 6, 28), M.steel, [0, 1.42, -.525]);
    dialFace(s, 'ScaleDial', T.dial('kg', 200, .9), [0, 1.42, -.524], .18, [0, 0, 1], Gl); bundle(s, [0, .42, 0], PI / 2); }
  { const s = sub(Pr, [-5.0, PT, -.7]); add(s, frustumG(.5, .75, .72, 1.05, .32), M.teal, [0, .55, 0]); add(s, new THREE.SphereGeometry(1, 12, 6), Q.wetStraw, [0, .7, 0], [0, 0, 0], [.3, .12, .45]);
    for (const x of [-.3, .3]) { pipe(s, M.steel, [x, .4, -.55], [x * 1.3, .72, .95], .02, 6); add(s, boxG(.03, .38, .03), M.steel, [x, .2, .3]); add(s, cylG(.04, .04, .14, 8), M.black, [x * 1.3, .74, 1.0]); }
    add(s, new THREE.TorusGeometry(.17, .06, 8, 18).rotateY(PI / 2), M.black, [0, .23, -.68]); add(s, alongX(cylG(.08, .08, .14, 12)), M.red, [0, .23, -.68]); pipe(s, M.steel, [-.12, .23, -.68], [.12, .23, -.68], .015, 6); }
  { const s = sub(Pr, [4.0, PT + .07, 5.3]); s.rotation.set(-.32, .3, 0); for (const x of [-.25, .25]) add(s, boxG(.04, 1.4, .04), M.red, [x, .78, 0]); for (const y of [.5, 1.0]) add(s, boxG(.54, .03, .03), M.red, [0, y, 0]);
    add(s, boxG(.56, .03, .3), M.steel, [0, .16, .15]); for (const x of [-.32, .32]) add(s, new THREE.TorusGeometry(.13, .04, 6, 14).rotateY(PI / 2), M.black, [x, .17, -.08]); add(s, boxG(.6, .03, .03), M.steel, [0, 1.48, 0]); }
  { const c = [4.6, 1.7, 4.565]; add(Pr, boxG(1.16, .86, .03), M.timber, c); sticker(Pr, Q.chalk, 1.06, .76, [c[0], c[1], c[2] + .016], 0); add(Pr, boxG(1.1, .03, .06), M.timber, [c[0], c[1] - .44, c[2] + .03]); add(Pr, boxG(.08, .015, .015), M.porcelain, [c[0] + .3, c[1] - .42, c[2] + .04]); }
  { const s = sub(Pr, [-4.6, 1.15, -4.62]); add(s, alongZ(cylG(.13, .13, .26, 16)), M.galv); for (const z of [-.14, .14]) add(s, alongZ(cylG(.34, .34, .02, 24)), M.red, [0, 0, z]);
    for (let i = 0; i < 4; i++) add(s, new THREE.TorusGeometry(.2 + (i % 2) * .05, .035, 6, 22), Q.hose, [0, 0, -.09 + i * .06]); add(s, boxG(.04, .04, .32), M.galv, [0, 0, .12]); add(s, boxG(.18, .03, .03), M.red, [.1, .2, .15]); }
  add(Pr, tubeG([[-4.6, .9, -4.66], [-4.3, .45, -5.0], [-3.8, PT + .04, -5.1], [-3.2, PT + .04, -4.7], [-3.4, PT + .04, -4.3], [-3.9, PT + .04, -4.4]], .035, 6, .4), Q.hose);
  pipe(Pr, M.galv, [-3.9, PT, -5.35], [-3.9, 1.0, -5.35], .04, 10); add(Pr, alongZ(cylG(.05, .05, .2, 10)), M.brass, [-3.9, .95, -5.25]); add(Pr, boxG(.18, .03, .04), M.red, [-3.9, 1.05, -5.35]);
  drum(Pr, -5.25, PT, -3.0, Q.drumB, true); drum(Pr, -5.3, PT, -2.2, Q.drumB, true);
  for (const [x, z, r] of [[4.05, -4.05, .2], [4.32, -4.1, .4], [4.0, -3.7, -.3], [4.3, -3.65, -.1]]) { const s = sub(Pr, [x, PT, z]); s.rotation.y = r; add(s, cylG(.07, .075, .42, 10), M.black, [0, .24, 0]); add(s, bboxG(.13, .09, .28, .03), M.black, [0, .045, .06]); }

  // ---- details ----
  for (let i = 0; i < 90; i++) { const x = rr(-5.6, 5.6), z = rr(-5.6, 5.6); if (Math.abs(z) < 1.9 && x > -3.8 && x < 6) continue; add(De, boxG(rr(.12, .3), .01, .02), Q.wetStraw, [x, PT + .006, z], [0, rr(0, PI), 0]); }
  for (const [x, y] of [[1.2, 7.25], [1.22, 6.6], [1.21, 4.9], [3.0, 7.2], [3.01, 5.6], [-5.8, .4]]) add(De, new THREE.SphereGeometry(.025, 6, 4), Q.water, [x, y, x < 0 ? 5.95 : 5.92], [0, 0, 0], [1, 1.6, 1]);
  add(De, flat(.6, .4), Q.wet, [1.2, PT + .007, 5.75]); add(De, flat(.6, .4), Q.wet, [3.0, PT + .007, 5.75]);
  sticker(De, label('CpPlate', T.namePlate('COOP STRAW INTAKE', 'Wet straw · max 2 t/day', 'S/N 2026-0501', '#c9ccc8', '#1f6f6c')), .4, .2, [-4.6, 1.6, 4.555], 0);
  return finish(R);
}

/* ================= 2. Buyer depot ================= */
export function buildBuyerDepot() {
  setSeed(902); const R = root('BuyerDepot'), G = grpOf(R, 'BD_');
  const Yd = G('Yard'), Bd = G('Building'), Rf = G('Roof'), Dk = G('Dock'), By = G('Bays'), S1 = G('Shutter1'), S2 = G('Shutter2'), S3 = G('Shutter3'), In = G('Interior'), Of = G('Office'), Tr = G('Truck'), Si = G('Silo'), De = G('Details'), Em = G('Emissive'), Gl = G('Glass');
  const FL = 1.5, SL = .12, RY = 12.44, roofY = z => RY - .04 - Math.abs(z) * SL, EY = roofY(12) - .06, WX0 = -14, WX1 = 10, WZ = 12, BAYS = [-8, 0, 8];
  // ---- yard ----
  pad(Yd, 44, 36, PT, [[-21.5, -17.5], [21.5, -17.5], [-21.5, 17.5], [21.5, 17.5], [0, 17.5], [21.5, 0]]);
  const line = (x, z, w, d, m = M.yellow) => add(Yd, boxG(w, .006, d), m, [x, PT + .004, z]);
  for (const zc of BAYS) for (const s of [-1, 1]) line(-19.5, zc + s * 1.55, 4.6, .12);
  for (const [x, z, w, d] of [[-5.3, -13.85, 12.8, .12], [-5.3, -17.0, 12.8, .12], [-11.65, -15.4, .12, 3.2], [1.05, -15.4, .12, 3.2]]) line(x, z, w, d);
  for (let i = 0; i < 6; i++) line(4.2 + i * .7, 16.9, .4, 1.6, M.porcelain);
  for (let i = 0; i < 3; i++) add(Yd, flat(.9, .9), label('Arrow' + i, T.label('◀', '#cfd0cc', '#e8e8e2')), [14.5 + i * 1.6, PT + .005, -14.8]);
  add(Yd, flat(6, 4), Q.wet, [-6, PT + .003, -15.4]); add(Yd, flat(3, 3), M.oil, [-5.5, PT + .004, -15.4]); add(Yd, flat(2.4, 2.0), M.oil, [-.6, PT + .004, -15.4]);
  // weighbridge in front of the truck
  add(Yd, boxG(10, .14, 3.4), mat('Checker', 'CheckerPlate', { map: T.galv, normalMap: T.galvN, color: 0xc9cccb, metalness: .7, roughness: .4 }, 2), [6.5, PT + .07, -15.0]);
  for (const s of [-1, 1]) { add(Yd, boxG(10, .02, .12), M.hazard, [6.5, PT + .15, -15.0 + s * 1.62]); prismXY(Yd, M.galv, s < 0 ? [[1.5, PT], [1.5, PT + .14], [.8, PT]] : [[11.5, PT], [12.2, PT], [11.5, PT + .14]], -16.7, -13.3); }
  for (const x of [2.2, 6.5, 10.8]) for (const z of [-16.6, -13.4]) add(Yd, boxG(.5, .04, .3), M.iron, [x, PT + .16, z]);
  { const c = [6.5, PT, -17.4]; add(Yd, boxG(.12, 1.6, .12), M.galv, [c[0], c[1] + .8, c[2]]); add(Yd, bboxG(.9, .5, .2, .03), M.ctrl, [c[0], c[1] + 1.75, c[2]]); sticker(Yd, lcd('WeighDisplay', T.lcd(['12 480 kg'], '#0b1a20', '#e8f05a')), .76, .3, [c[0], c[1] + 1.78, c[2] + .102], 0); basePlate(Yd, c[0], PT, c[2], .3); }
  // ---- building: floor, walls, gables, band ----
  add(Bd, bboxG(24, FL - PT, 24, .04), M.concrete, [-2, (PT + FL) / 2, 0]);
  const wallX = (x, z0, z1, y0, y1, out) => add(Bd, boxG(.16, y1 - y0, z1 - z0), Q.clad, [x + out * -.08, (y0 + y1) / 2, (z0 + z1) / 2]);
  const wallZ = (z, x0, x1, y0, y1, out) => add(Bd, boxG(x1 - x0, y1 - y0, .16), Q.clad, [(x0 + x1) / 2, (y0 + y1) / 2, z + out * -.08]);
  for (const [a, b] of [[-12, -9.7], [-6.3, -1.7], [1.7, 6.3], [9.7, 12]]) wallX(WX0, a, b, FL, EY, -1);
  for (const zc of BAYS) wallX(WX0, zc - 1.7, zc + 1.7, 5.5, EY, -1);
  wallX(WX1, -12, 12, FL, EY, 1);
  wallZ(-WZ, WX0 + .16, -8, FL, EY, -1); wallZ(-WZ, -4, WX1 - .16, FL, EY, -1); wallZ(-WZ, -8, -4, 5.5, EY, -1); wallZ(WZ, WX0 + .16, WX1 - .16, FL, EY, 1);
  for (const [x0, x1] of [[WX0, WX0 + .16], [WX1 - .16, WX1]]) prismX(Bd, Q.clad, [[-12, EY - .001], [0, RY - .12], [12, EY - .001]], x0, x1);
  for (const x of [WX0 - .02, WX1 + .02]) add(Bd, boxG(.04, 1.2, 24.08), Q.cladW, [x, 9.6, 0]);
  for (const z of [-WZ - .02, WZ + .02]) add(Bd, boxG(24.08, 1.2, .04), Q.cladW, [-2, 9.6, z]);
  for (const x of [WX0, WX1]) for (const z of [-WZ, WZ]) add(Bd, boxG(.18, EY - FL, .18), Q.cladW, [x + (x < 0 ? .07 : -.07), (FL + EY) / 2, z + (z < 0 ? .07 : -.07)]);
  for (const zc of BAYS) { for (const s of [-1, 1]) add(Bd, boxG(.12, 4.0, .12), M.galv, [WX0 - .02, 3.5, zc + s * 1.76]); add(Bd, boxG(.12, .12, 3.64), M.galv, [WX0 - .02, 5.56, zc]); }
  for (const x of [-8, -2, 4]) for (const z of [-11.68, 11.68]) col(Bd, M.teal, x, z, FL, EY - .4, .3, .3, PI / 2);
  for (const x of [-13.7, -8, -2, 4, 9.7]) for (const s of [-1, 1]) beam(Bd, M.teal, [x, EY - .35, s * 11.84], [x, RY - .4, 0], .2, .4);
  for (const x of [-8, -2, 4]) add(Bd, boxG(.06, .06, 23.6), M.galv, [x + 3, EY - .5, 0]);
  louvre(Bd, [WX1 + .002, 8.0, -6], 1.4, .9, [1, 0], M.teal); louvre(Bd, [WX1 + .002, 8.0, 6], 1.4, .9, [1, 0], M.teal);
  { const z = 4; add(Bd, boxG(.08, 2.3, 1.2), M.galv, [WX1 + .04, FL + 1.15, z]); add(Bd, boxG(.06, 2.15, 1.0), M.teal, [WX1 + .07, FL + 1.075, z]); add(Bd, boxG(.05, .04, .16), M.steel, [WX1 + .12, FL + 1.0, z + .32]); add(Bd, boxG(.8, .2, 1.6), M.concrete, [WX1 + .4, PT + .1, z]); for (let i = 0; i < 3; i++) add(Bd, boxG(.6, .3, 1.4), M.concrete, [WX1 + .3, PT + .15 + i * .0, z]); }
  add(Bd, boxG(.4, FL - PT - .02, 1.4), M.concrete, [WX1 + .2, (PT + FL) / 2, 4]); add(Bd, boxG(.4, .7, 1.4), M.concrete, [WX1 + .55, PT + .35, 4]);
  for (const [x, z, w] of [[-10, 12.003, 3], [3, 12.003, 2.5], [-6, -12.003, 2.4]]) sticker(Bd, M.dust, w, 1.2, [x, FL + .6, z], z > 0 ? 0 : PI);
  sticker(Bd, M.rust, 1.6, 2.0, [WX1 + .003, 3.0, -9.0], PI / 2); sticker(Bd, M.rust, 1.2, 1.6, [WX0 - .003, 3.4, 11.0], -PI / 2);
  // floor markings inside
  for (const z of [-2.1, 2.1, -9.6]) add(Bd, boxG(18, .006, .1), M.yellow, [-3, FL + .004, z]);
  // ---- roof ----
  const LS = 12.35 / Math.cos(Math.atan(SL)), a = Math.atan(SL);
  for (const s of [-1, 1]) add(Rf, corrSheet(24.6, LS, .3, .04), Q.roofGrey, [-2, roofY(6.175), s * 6.175], [s * a, 0, 0]);
  prismX(Rf, M.galv, [[-.5, roofY(.5) + .05], [0, RY], [.5, roofY(.5) + .05], [.5, roofY(.5) + .02], [0, RY - .03], [-.5, roofY(.5) + .02]], -14.3, 10.3);
  for (const s of [-1, 1]) for (const x of [-10, -2, 6]) { add(Gl, flat(1.6, 8.0), M.glass, [x, roofY(6.2) + .055, s * 6.2], [s * a, 0, 0]);
    for (const k of [-1, 1]) add(Rf, boxG(.08, .1, 8.1), M.alu, [x + k * .84, roofY(6.2) + .03, s * 6.2], [s * a, 0, 0]); }
  for (const x of [-10, -4, 2, 8]) { add(Rf, cylG(.2, .24, .3, 16), M.galv, [x, RY + .1, 0]); add(Rf, revolve([[.22, 0], [.33, .08], [.36, .25], [.3, .42], [.12, .52], [0, .54]], 20), M.galv, [x, RY + .25, 0]);
    for (let i = 0; i < 12; i++) { const b = i / 12 * TAU; add(Rf, boxG(.02, .42, .12), M.galv, [x + .35 * Math.cos(b), RY + .5, .35 * Math.sin(b)], [0, -b + .5, 0]); } add(Rf, cylG(.05, .05, .1, 8), M.galv, [x, RY + .82, 0]); }
  for (const s of [-1, 1]) { const y = roofY(12.35) - .16; add(Rf, boxG(24.6, .02, .2), M.galv, [-2, y - .08, s * 12.45]); add(Rf, boxG(24.6, .16, .02), M.galv, [-2, y, s * 12.36]); add(Rf, boxG(24.6, .16, .02), M.galv, [-2, y, s * 12.54]);
    add(Rf, boxG(24.6, .22, .03), Q.cladW, [-2, roofY(12.3) - .06, s * 12.33]);
    for (const x of [-13.6, 9.6]) { pipe(Rf, M.galv, [x, y - .08, s * 12.45], [x, .55, s * 12.45], .08, 10); add(Rf, alongZ(cylG(.08, .08, .3, 10)), M.galv, [x, .5, s * 12.6]); add(Rf, boxG(.5, .06, .4), M.concrete, [x, PT + .03, s * 12.85]);
      for (const yy of [3, 6, 9]) add(Rf, boxG(.14, .06, .14), M.galv, [x, yy, s * 12.38]); } }
  for (const x of [-14.32, 10.32]) for (const s of [-1, 1]) beam(Rf, Q.cladW, [x, roofY(12.35) - .02, s * 12.35], [x, RY - .02, 0], .04, .2);
  // ---- dock ----
  add(Dk, bboxG(3.0, FL - PT, 24, .03), M.concrete, [-15.5, (PT + FL) / 2, 0]); add(Dk, boxG(.08, .08, 24), M.galv, [-16.96, FL - .04, 0]); add(Dk, boxG(.006, .22, 24), M.hazard, [-17.003, FL - .2, 0]);
  for (const zc of BAYS) for (const s of [-1, 1]) { add(Dk, bboxG(.24, .5, .4, .04), M.black, [-17.12, 1.12, zc + s * 2.2]); add(Dk, boxG(.04, .6, .5), M.galv, [-17.02, 1.12, zc + s * 2.2]); for (const y of [.9, 1.35]) nut(Dk, [-17.25, y, zc + s * 2.2 + .14], [-1, 0, 0], .03, .02); }
  for (let i = 0; i < 4; i++) add(Dk, boxG(1.6, (4 - i) * .3, .4), M.concrete, [-16.2, PT + (4 - i) * .15, 12.2 + i * .4]);
  for (const x of [-16.95, -15.45]) { for (const z of [12.15, 13.45]) add(Dk, boxG(.05, 1.0, .05), M.yellow, [x, (z < 13 ? FL : PT + .3) + .5, z]); pipe(Dk, M.yellow, [x, FL + 1.0, 12.15], [x, PT + 1.3, 13.45], .025, 8); }
  add(Dk, bboxG(8, FL - PT, 2, .03), M.concrete, [-6, (PT + FL) / 2, -13]); add(Dk, boxG(8, .08, .08), M.galv, [-6, FL - .04, -13.96]); add(Dk, boxG(8, .22, .006), M.hazard, [-6, FL - .2, -14.003]);
  add(Dk, boxG(3.0, .03, 1.4), M.galv, [-6, FL + .015, -13.25]); add(Dk, boxG(3.0, .02, .03), M.hazard, [-6, FL + .03, -13.95]);
  for (const x of [-9.2, -2.8]) add(Dk, bboxG(.4, .5, .24, .04), M.black, [x, 1.12, -14.12]);
  add(Dk, bboxG(4.6, .62, .5, .03), M.galv, [-6, 5.86, -12.25]); for (const s of [-1, 1]) add(Dk, boxG(.12, 4.1, .1), M.galv, [-6 + s * 2.06, 3.55, -12.06]);
  add(Dk, boxG(4.6, 1.0, .02), Q.shut, [-6, 5.95, -12.51]);
  // ---- bays: housings, guides, numbers, lamps, roller conveyors, bollards ----
  const SH = [S1, S2, S3], cyb = x => 1.32 + (x + 22) * .13;
  BAYS.forEach((zc, i) => {
    add(By, bboxG(.5, .62, 3.6, .03), M.galv, [-14.25, 5.86, zc]); for (const s of [-1, 1]) add(By, boxG(.1, 4.1, .12), M.galv, [-14.07, 3.55, zc + s * 1.66]);
    sticker(By, label('BayNo' + (i + 1), bayTex(i + 1)), 1.3, 1.3, [-14.06, 7.0, zc], -PI / 2);
    add(By, alongX(cylG(.15, .15, .2, 16)), M.iron, [-14.1, 7.0, zc + 1.25]); add(By, boxG(.04, .4, .1), M.iron, [-14.04, 7.0, zc + 1.25]);
    add(Em, latheX([[.12, 0], [.12, .04], [.08, .1], [0, .12]], 16).rotateY(PI), M.emG, [-14.2, 7.0, zc + 1.25]);
    // shutter (origin on the top roll)
    const S = SH[i]; S.position.set(-14.25, 5.86, zc); add(S, alongZ(cylG(.2, .2, 3.4, 20)), M.galv);
    add(S, boxG(.035, 2.05, 3.32), Q.shut, [.17, -1.3, 0]); add(S, boxG(.07, .08, 3.34), Q.alu, [.17, -2.36, 0]); add(S, boxG(.05, .03, 3.3), M.black, [.17, -2.415, 0]);
    for (const s of [-1, 1]) add(S, boxG(.06, .04, .18), M.steel, [.1, -2.3, s * .9]);
    // roller conveyor: top 1.32 at x = -22, rising into the building
    for (const s of [-1, 1]) prismXY(By, M.teal, [[-22, 1.32], [-12, cyb(-12)], [-12, cyb(-12) - .28], [-22, 1.04]], s > 0 ? zc + 1.0 : zc - 1.08, s > 0 ? zc + 1.08 : zc - 1.0);
    prismXY(By, M.galv, [[-22, 1.29], [-21.75, cyb(-21.75) - .03], [-21.75, cyb(-21.75)], [-22, 1.32]], zc - 1.0, zc + 1.0);
    for (let x = -21.6; x < -12.1; x += .3) add(By, alongZ(cylG(.06, .06, 2.0, 12)), M.steel, [x, cyb(x) - .06, zc]);
    for (const x of [-21.2, -18.4, -15.6, -12.8]) { const base = x > -17 ? FL : PT, top = cyb(x) - .28; for (const s of [-1, 1]) { add(By, boxG(.08, top - base, .08), M.galv, [x, (base + top) / 2, zc + s * 1.04]); add(By, boxG(.24, .02, .2), M.galv, [x, base + .01, zc + s * 1.04]); } add(By, boxG(.06, .06, 2.0), M.galv, [x, base + .35, zc]); }
    add(By, alongZ(cylG(.14, .14, .5, 16)), M.teal, [-19.6, 1.2, zc - .55]); add(By, bboxG(.3, .28, .28, .03), M.iron, [-19.6, 1.22, zc - .1]); add(By, boxG(.4, .04, 1.0), M.galv, [-19.6, 1.38, zc - .3]);
    beam(By, M.yellow, [-19.4, 1.25, zc - 1.14], [-18.0, cyb(-18) - .15, zc - 1.14], .14, .06);
    add(By, boxG(.08, .5, 2.16), M.yellow, [-12.04, cyb(-12) + .2, zc]);
    for (const s of [-1, 1]) { const b = [-19.6, PT, zc + s * 1.95]; add(By, cylG(.12, .12, 1.0, 16), M.yellow, [b[0], PT + .5, b[2]]); for (const y of [.62, .82]) add(By, cylG(.125, .125, .08, 16), M.black, [b[0], PT + y, b[2]]); add(By, revolve([[.12, 0], [.08, .06], [0, .08]], 16), M.yellow, [b[0], PT + 1.0, b[2]]); basePlate(By, b[0], PT, b[2], .34); }
    crate(By, -13.2, cyb(-13.2), zc, .05);
  });
  // ---- interior: racking, crate stacks, bulk bags, forklift ----
  for (let i = 0; i < 8; i++) { const x = -12.6 + i * 2.8; for (const z of [-11.5, -10.4]) add(In, boxG(.1, 5.2, .1), M.teal, [x, FL + 2.6, z]); for (const y of [.4, 2.4, 4.6]) beam(In, M.teal, [x, FL + y, -11.5], [x, FL + y + .7, -10.4], .05, .05); }
  for (const y of [2.0, 3.9]) for (const z of [-11.5, -10.4]) add(In, boxG(19.7, .14, .06), M.yellow, [-12.6 + 9.8, FL + y, z]);
  for (let i = 0; i < 7; i++) { const x = -11.2 + i * 2.8; for (const [lv, y] of [[0, FL], [1, FL + 2.07], [2, FL + 3.97]]) { const t = pallet(In, x, y, -10.95); if ((i + lv) % 2) crate(In, x, t, -10.95); else bag(In, x, t, -10.95, rr(-.1, .1)); } }
  for (const x of [-8.5, -6.6, -4.7]) for (const z of [-9.2, -7.4, 7.4, 9.2]) { let t = pallet(In, x, FL, z); t = crate(In, x, t, z, rr(-.05, .05)); if (rnd() < .7) crate(In, x, t, z, rr(-.05, .05)); }
  for (const x of [-1.5, .4, 2.3, 4.2]) for (const z of [-6.5, -4.6, 4.6, 6.5]) { const t = pallet(In, x, FL, z); bag(In, x, t, z, rr(-.15, .15)); }
  for (const x of [1.0, 3.0, 5.0]) { const t = pallet(In, x, FL, 0); bag(In, x, t, 0); }
  for (const x of [6.4, 8.3]) for (const z of [-6.5, -4.6, -2.6, 2.6, 4.6, 6.5]) { const t = pallet(In, x, FL, z); bag(In, x, t, z, rr(-.15, .15)); }
  { const f = sub(In, [-8.4, FL, .3]); add(f, bboxG(1.5, .85, 1.1, .08), M.yellow, [0, .62, 0]); add(f, bboxG(.4, .95, 1.1, .06), M.iron, [.7, .7, 0]);
    for (const [x, r] of [[-.5, .28], [.5, .24]]) for (const s of [-1, 1]) { add(f, alongZ(cylG(r, r, .22, 16)), M.black, [x, r, s * .52]); add(f, alongZ(cylG(r * .5, r * .5, .24, 10)), M.yellow, [x, r, s * .52]); }
    add(f, bboxG(.4, .1, .45, .04), M.black, [.3, 1.1, 0]); add(f, boxG(.08, .45, .45), M.black, [.48, 1.35, 0]);
    for (const x of [-.45, .55]) for (const s of [-1, 1]) add(f, boxG(.05, 1.1, .05), M.black, [x, 1.6, s * .48]); add(f, boxG(1.05, .05, 1.0), M.black, [.05, 2.17, 0]); for (let k = 0; k < 4; k++) add(f, boxG(1.0, .03, .03), M.steel, [.05, 2.2, -.36 + k * .24]);
    add(f, new THREE.TorusGeometry(.15, .02, 6, 18).rotateX(PI / 2 - .5), M.black, [-.15, 1.4, 0]); pipe(f, M.black, [-.15, 1.4, 0], [-.3, 1.1, 0], .02, 6);
    for (const s of [-1, 1]) add(f, boxG(.1, 2.4, .12), M.steel, [-.82, 1.3, s * .32]); add(f, boxG(.06, .5, .9), M.steel, [-.9, .62, 0]);
    for (const s of [-1, 1]) add(f, boxG(1.1, .05, .12), M.steel, [-1.45, .4, s * .26]); pallet(f, -1.45, .43, 0); crate(f, -1.45, .59, 0); add(f, cylG(.08, .08, .12, 10), M.emA, [.5, 2.25, 0]); }
  for (const x of [-9, -1, 7]) for (const z of [-5, 5]) { pipe(In, M.steel, [x, EY - .4, z], [x, 9.6, z], .01, 4); add(In, cylG(.08, .35, .3, 16, true), M.iron, [x, 9.45, z]); add(In, new THREE.CircleGeometry(.3, 16).rotateX(PI / 2), Q.lampLit, [x, 9.31, z]); }
  add(In, flat(4, 3), M.dust, [-9, FL + .004, 0]);
  // ---- office annex (south) ----
  add(Of, boxG(9.4, .15, 4.4), M.concrete, [4.5, PT + .075, 14.2]); add(Of, bboxG(9, 3.9, 4.2, .04), Q.render, [4.5, .45 + 1.95, 14.1]);
  add(Of, boxG(9.3, .22, 4.4), M.concrete, [4.5, 4.46, 14.2]); for (const s of [-1, 1]) add(Of, boxG(9.3, .3, .08), Q.cladW, [4.5, 4.72, 14.2 + s * 2.16]); for (const x of [-.11, 9.11]) add(Of, boxG(.08, .3, 4.4), Q.cladW, [x, 4.72, 14.2]);
  add(Of, boxG(9.04, .16, .05), M.teal, [4.5, 4.3, 16.22]);
  const win = (c, ry, w, h) => { const s = sub(Of, c); s.rotation.y = ry; add(s, plane(w, h), Q.warm, [0, 0, .006]); add(s, plane(w, h), M.glass, [0, 0, .016]);
    for (const k of [-1, 1]) { add(s, boxG(w + .1, .06, .06), Q.alu, [0, k * (h / 2 + .02), .02]); add(s, boxG(.06, h, .06), Q.alu, [k * (w / 2 + .02), 0, .02]); } add(s, boxG(.04, h, .05), Q.alu, [0, 0, .02]); add(s, boxG(w + .2, .05, .16), M.concrete, [0, -h / 2 - .06, .06]);
    const e = sub(Em, c); e.rotation.y = ry; add(e, plane(w, h), Q.warm, [0, 0, .006]); const gg = sub(Gl, c); gg.rotation.y = ry; add(gg, plane(w, h), M.glass, [0, 0, .016]); };
  for (const x of [1.3, 5.6, 7.7]) win([x, 2.1, 16.2], 0, 1.4, 1.1); win([9.0, 2.1, 14.1], PI / 2, 1.6, 1.1); win([0, 2.1, 14.8], -PI / 2, 1.2, 1.1);
  add(Of, boxG(1.1, 2.3, .05), M.alu, [3.4, .45 + 1.15, 16.21]); add(Of, boxG(.95, 2.15, .06), M.teal, [3.4, .45 + 1.1, 16.24]); add(Of, boxG(.05, .2, .06), M.steel, [3.8, 1.5, 16.29]); add(Of, plane(.5, .6), Q.warm, [3.4, 2.2, 16.272]);
  add(Of, boxG(1.6, .08, .9), M.teal, [3.4, 2.95, 16.6]); for (const s of [-1, 1]) beam(Of, M.galv, [3.4 + s * .7, 2.6, 16.2], [3.4 + s * .7, 2.92, 16.95], .03, .03); add(Of, boxG(1.4, .15, .5), M.concrete, [3.4, .375, 16.45]);
  { const c = [9.55, PT, 13.0]; add(Of, boxG(.5, .1, 1.0), M.concrete, [c[0], PT + .05, c[2]]); add(Of, bboxG(.4, .75, .9, .03), Q.render, [c[0], PT + .48, c[2]]); add(Of, new THREE.CircleGeometry(.28, 20).rotateY(PI / 2), M.guard, [c[0] + .202, PT + .5, c[2]]); add(Of, new THREE.TorusGeometry(.28, .02, 4, 20).rotateY(PI / 2), M.iron, [c[0] + .205, PT + .5, c[2]]);
    for (const dz of [-.3, -.22]) add(Of, tubeG([[c[0] - .2, PT + .7, c[2] + dz], [9.1, 1.0, c[2] + dz], [9.03, 3.0, c[2] + dz]], .02, 6), M.copper); }
  for (const [x, z] of [[.5, 16.75], [6.6, 16.75], [8.6, 16.75]]) { add(Of, revolve([[.18, 0], [.24, .42], [.27, .45], [.27, .5], [0, .5]], 16), Q.pot, [x, PT, z]); for (let i = 0; i < 4; i++) add(Of, new THREE.IcosahedronGeometry(.22, 0), Q.leaf, [x + rr(-.1, .1), PT + .7 + i * .12, z + rr(-.1, .1)], [rr(0, 3), rr(0, 3), 0], [1, 1.3, 1]); }
  // ---- logo on the main (south) wall ----
  sticker(De, Q.logo, 7.4, 7.4, [-7, 5.2, WZ + .012], 0);
  // ---- truck being loaded (north) ----
  { const tz = -15.4, t = sub(Tr, [0, 0, tz]);
    for (const [x, r] of [[-.5, .5], [-7.6, .5], [-8.8, .5]]) for (const s of [-1, 1]) { add(t, alongZ(cylG(r, r, .32, 20)), M.rubber, [x, PT + r, s * 1.0]); add(t, alongZ(cylG(.26, .26, .34, 12)), M.steel, [x, PT + r, s * 1.0]); if (x < -1) add(t, alongZ(cylG(r, r, .3, 20)), M.rubber, [x, PT + r, s * .66]); }
    for (const s of [-1, 1]) add(t, boxG(11.3, .25, .12), M.black, [-5.4, PT + .95, s * .45]); for (const x of [-10, -7, -4, -1]) add(t, boxG(.12, .2, 1.0), M.black, [x, PT + .95, 0]);
    add(t, bboxG(2.0, 2.3, 2.4, .12), Q.cab, [-.6, PT + 2.15, 0]); add(t, plane(2.1, .9), Q.tglass, [.41, PT + 2.75, 0], [0, PI / 2, 0]);
    for (const s of [-1, 1]) { add(t, plane(.9, .7), Q.tglass, [-.5, PT + 2.75, s * 1.205], [0, s > 0 ? 0 : PI, 0]); add(t, boxG(.03, .5, .03), M.black, [.3, PT + 2.9, s * 1.3]); add(t, bboxG(.06, .3, .15, .02), M.black, [.32, PT + 2.85, s * 1.42]); add(t, boxG(.4, .06, .3), M.steel, [-.2, PT + .9, s * 1.1]); add(t, boxG(.18, .04, .04), M.steel, [-.1, PT + 2.2, s * 1.215]); }
    add(t, boxG(.05, .7, 1.8), M.iron, [.42, PT + 1.6, 0]); add(t, boxG(.2, .3, 2.45), M.steel, [.5, PT + 1.0, 0]); for (const s of [-1, 1]) add(t, alongX(cylG(.12, .12, .06, 14)), M.porcelain, [.43, PT + 1.45, s * .9]);
    for (const s of [-1, 1]) add(t, boxG(1.0, .06, .4), M.black, [-.5, PT + 1.05, s * 1.02]); add(t, alongX(cylG(.28, .28, .9, 18)), M.galv, [-2.3, PT + .85, -.95]);
    add(t, boxG(9.0, .14, 2.5), M.timber, [-6.6, PT + 1.27, 0]); for (const s of [-1, 1]) { add(t, boxG(9.0, .12, .06), M.black, [-6.6, PT + 1.2, s * 1.22]); for (let k = 0; k < 6; k++) add(t, boxG(.08, .14, .08), M.black, [-10.6 + k * 1.7, PT + 1.24, s * 1.24]); }
    add(t, boxG(.08, 1.6, 2.4), M.black, [-2.1, PT + 2.14, 0]); for (let k = 0; k < 4; k++) add(t, boxG(.06, .06, 2.4), M.steel, [-2.05, PT + 1.6 + k * .4, 0]);
    for (const s of [-1, 1]) { add(t, boxG(.04, .5, .5), M.black, [-9.5, PT + .6, s * 1.0]); add(t, boxG(.06, .1, .2), M.emR, [-11.1, PT + 1.15, s * 1.0]); }
    for (const x of [-10.2, -8.3, -6.4]) { bag(t, x, PT + 1.34, 0, rr(-.08, .08)); add(t, boxG(.06, .02, 2.56), M.yellow, [x, PT + 3.02, 0]); for (const s of [-1, 1]) add(t, boxG(.06, 1.62, .02), M.yellow, [x, PT + 2.2, s * 1.28]); }
    }
  // ---- pellet silo (NE) ----
  { const cx = 16.6, cz = -12.8, c = sub(Si, [cx, 0, cz]);
    add(c, cylG(3.3, 3.3, .1, 40), M.concrete, [0, PT + .05, 0]);
    for (let i = 0; i < 8; i++) { const b = i / 8 * TAU + PI / 8, x = 2.85 * Math.cos(b), z = 2.85 * Math.sin(b); add(c, boxG(.18, 4.7, .18), M.galv, [x, PT + .1 + 2.35, z]); basePlate(c, x, PT + .1, z, .4);
      const b2 = (i + 1) / 8 * TAU + PI / 8; beam(c, M.galv, [x, 1.0, z], [2.85 * Math.cos(b2), 4.6, 2.85 * Math.sin(b2)], .05, .05); }
    add(c, new THREE.TorusGeometry(2.95, .1, 4, 40).rotateX(PI / 2), M.galv, [0, 5.1, 0]);
    add(c, revolve([[.35, 2.8], [3.0, 5.0]], 40), M.galv); add(c, cylG(.35, .35, .3, 16), M.galv, [0, 2.65, 0]); add(c, boxG(.9, .12, .5), M.iron, [0, 2.45, 0]); add(c, alongX(cylG(.08, .08, .3, 10)), M.iron, [.55, 2.45, 0]); add(c, new THREE.TorusGeometry(.15, .02, 6, 16).rotateY(PI / 2), M.red, [.72, 2.45, 0]);
    add(c, tubeG([[0, 2.4, 0], [-.6, 2.0, -.2], [-1.6, 1.85, -.5]], .22, 12, .2), M.galv); add(c, cylG(.24, .3, .6, 14), M.black, [-1.75, 1.5, -.55]);
    const prof = []; for (let i = 0; i <= 76; i++) prof.push([3.0 + .04 * Math.sin(i / 2 * TAU), 5.0 + i * .15]); add(c, revolve(prof, 40), M.galv);
    for (const y of [5.0, 8.8, 12.6, 16.4]) add(c, new THREE.TorusGeometry(3.04, .05, 4, 40).rotateX(PI / 2), M.galv, [0, y, 0]);
    for (let i = 0; i < 12; i++) { const b = i / 12 * TAU; add(c, boxG(.08, 11.4, .12), M.galv, [3.06 * Math.cos(b), 10.7, 3.06 * Math.sin(b)], [0, -b, 0]); }
    add(c, revolve([[3.08, 16.4], [3.08, 16.5], [.55, 18.4], [0, 18.4]], 40), M.galv); add(c, cylG(.55, .55, .2, 20), M.galv, [0, 18.5, 0]); add(c, cylG(.2, .45, .45, 16), M.galv, [0, 18.82, 0]); add(c, cylG(.55, .55, .06, 16), M.galv, [0, 19.08, 0]);
    for (let i = 0; i < 16; i++) { const b = i / 16 * TAU; add(c, boxG(.04, .06, 2.4), M.galv, [1.75 * Math.cos(b), 17.4, 1.75 * Math.sin(b)], [0, -b + PI / 2, Math.atan(1.9 / 2.53)]); }
    const lx = 3.35; for (const z of [-.25, .25]) add(c, boxG(.06, 16.4, .05), M.galv, [lx, PT + 8.2, z]); for (let y = .6; y < 16.6; y += .3) pipe(c, M.galv, [lx, y, -.25], [lx, y, .25], .018, 5);
    for (let y = 2.5; y <= 16.6; y += .7) add(c, new THREE.TorusGeometry(.4, .02, 4, 16, PI).rotateX(PI / 2).rotateY(-PI / 2), M.galv, [lx + .0, y, 0]);
    for (const [dx, dz] of [[.4, 0], [0, -.4], [0, .4]]) add(c, boxG(.03, 14.2, .03), M.galv, [lx + dx, 9.6, dz]);
    for (const z of [-.3, .3]) pipe(c, M.galv, [lx, 16.6, z], [2.6, 17.4, z], .02, 6);
    add(c, tubeG([[-2.6, .6, 1.6], [-2.6, 6, 1.75], [-2.6, 15.8, 1.75], [-2.2, 16.8, 1.3], [-1.0, 17.8, .6]], .1, 10, .1), M.galv);
    sticker(c, label('SiloPlate', T.namePlate('PELLET SILO 80 t', 'Max fill 6 mm pellets', 'Do not enter', '#c9ccc8', '#1f6f6c')), .8, .4, [0, 6.0, 3.06], 0); }
  // ---- details: lamp posts, drums, pallet stack, cones, chocks ----
  for (const [x, z] of [[-21.0, -17.0], [21.0, -17.0], [-21.0, 17.0], [21.0, 17.0]]) { add(De, cylG(.08, .14, 9, 12), M.galv, [x, PT + 4.5, z]); basePlate(De, x, PT, z, .44);
    const dx = -Math.sign(x) * .7, dz = -Math.sign(z) * .7; pipe(De, M.galv, [x, 9.1, z], [x + dx, 9.3, z + dz], .04, 8); add(De, bboxG(.6, .14, .32, .04), M.iron, [x + dx * 1.2, 9.25, z + dz * 1.2], [0, Math.atan2(dx, dz), 0]);
    add(Em, flat(.5, .24).rotateX(PI), Q.lampLit, [x + dx * 1.2, 9.175, z + dz * 1.2], [0, Math.atan2(dx, dz), 0]); add(De, bboxG(.24, .34, .14, .03), M.galv, [x, 1.4, z + Math.sign(z) * -.12]); }
  for (const [x, z, m] of [[13.2, 4.0, Q.drumB], [13.8, 4.4, Q.drumR], [13.3, 4.8, Q.drumR], [12.7, 4.5, Q.drumB]]) drum(De, x, PT, z, m, m === Q.drumB);
  { let y = PT; for (let i = 0; i < 7; i++) y = pallet(De, 16.5, y, 6.0, rr(-.06, .06)); }
  for (const [x, z] of [[12.2, -12.8], [12.2, -17.2], [0.0, -17.6]]) { add(De, cylG(.03, .2, .5, 12), CONE, [x, PT + .29, z]); add(De, boxG(.4, .04, .4), M.black, [x, PT + .02, z]); }
  for (const x of [-7.6, -8.8]) prismXY(De, M.yellow, [[x + .52, PT], [x + .8, PT], [x + .52, PT + .22]], -16.5, -16.2);
  { const s = sub(De, [-17.6, PT, 11.6]); add(s, bboxG(.5, .8, .3, .03), M.red, [0, 1.2, 0]); add(s, boxG(.06, 1.0, .06), M.galv, [0, .5, 0]); }
  return finish(R);
}

const CONE = mat('Cone', 'TrafficCone', { color: 0xe86a1c, roughness: .6 });
export const SPEC = {
  CollectionPoint: { pfx: 'CP_', s: [12, 10, 12], tri: [25000, 45000], ridge: 10, pad: 'CP_Pad',
    groups: ['Pad', 'Frame', 'Roof', 'Hopper', 'Belt', 'Straw', 'Props', 'Details', 'Emissive', 'Glass'],
    ports: [{ x: 6, zc: 0, n: 1, allow: 'CP_Belt', label: 'OUT east' }], solids: [] },
  BuyerDepot: { pfx: 'BD_', s: [44, 20, 36], tri: [60000, 100000], pad: 'BD_Yard',
    groups: ['Yard', 'Building', 'Roof', 'Dock', 'Bays', 'Shutter1', 'Shutter2', 'Shutter3', 'Interior', 'Office', 'Truck', 'Silo', 'Details', 'Emissive', 'Glass'],
    ports: [-8, 0, 8].map((zc, i) => ({ x: -22, zc, n: -1, allow: 'BD_Bays', label: 'IN bay ' + (i + 1) })),
    solids: [['BD_Dock', [-17, .3, -12], [-14.02, 1.5, 12]], ['BD_Office', [0, .45, 12], [9, 4.35, 16.2]], ['BD_Silo', [14, 5.2, -15.4], [19.2, 16.2, -10.2]]] },
};
export const BUILD = { CollectionPoint: buildCollectionPoint, BuyerDepot: buildBuyerDepot };
