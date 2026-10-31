// Six power machines for Power_v2. Each builder returns a THREE.Group root named by game id.
import { THREE, V3, TAU, DEG, YUP, DS, rnd, rr, setSeed, makeTextures, mat, decalMat, v3, boxG, bboxG, cylG, hexG, alongX, alongZ, revolve, latheX, latheZ, ringProf, frustumG, gearG, tubeG, helixG, add, orient, pipe, beam, sub, duct, plane, mergeGroup, cv, texFrom } from './power_lib.js';
const PI = Math.PI;
export const T = makeTextures();
{ const S = 512, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#b8913e'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < 2600; i++) { const l = rr(.7, 1.15); x.strokeStyle = `rgba(${220 * l | 0},${180 * l | 0},${96 * l | 0},${rr(.4, .9)})`; x.lineWidth = rr(1, 3); const px = rnd() * S, py = rnd() * S, a = rr(-.25, .25); x.beginPath(); x.moveTo(px, py); x.lineTo(px + Math.cos(a) * rr(30, 120), py + Math.sin(a) * rr(30, 120)); x.stroke(); }
  T.straw = texFrom(c); }
const sm = (part, name, o, s) => mat(part, name, o, s);
export const M = {
  concrete: sm('Concrete', 'Concrete', { map: T.concrete, normalMap: T.concreteN, roughness: .92 }, .25),
  hazard: sm('Hazard', 'HazardStripe', { map: T.hazard, roughness: .7 }, 1.6),
  teal: sm('Teal', 'TealEnamel', { map: T.teal, normalMap: T.tealN, roughness: .52, metalness: .2 }, .5),
  engine: sm('EngineTeal', 'EngineTealDark', { map: T.teal, normalMap: T.tealN, color: 0x8fa7a4, roughness: .45, metalness: .3 }, .5),
  canopy: sm('Canopy', 'CanopyYellow', { map: T.canopy, normalMap: T.canopyN, roughness: .5, metalness: .15 }, .35),
  yellow: sm('Guard', 'SafetyYellow', { map: T.canopy, normalMap: T.canopyN, roughness: .5, metalness: .15, side: DS }, .5),
  galv: sm('Galv', 'GalvanisedSteel', { map: T.galv, normalMap: T.galvN, roughness: .42, metalness: .72 }, .6),
  timber: sm('Timber', 'Timber', { map: T.timber, normalMap: T.timberN, roughness: .85 }, .4),
  iron: sm('Iron', 'CastIron', { map: T.iron, normalMap: T.ironN, roughness: .7, metalness: .55 }, .6),
  skid: sm('Skid', 'SkidPaintBlack', { map: T.iron, normalMap: T.ironN, color: 0x6b6d6a, roughness: .55, metalness: .4 }, .5),
  alu: sm('Alu', 'Aluminium', { map: T.alu, roughness: .35, metalness: .85 }, .5),
  cells: sm('Cells', 'SolarCellGlass', { map: T.cells, roughness: .05, metalness: .3, envMapIntensity: 1.6 }),
  laminate: sm('Laminate', 'PanelLaminate', { color: 0x1a1f2a, roughness: .2, metalness: .2 }),
  backsheet: sm('Backsheet', 'PanelBacksheet', { color: 0xe6e6e0, roughness: .8 }),
  lag: sm('Lagging', 'LaggingCladding', { map: T.lagging, normalMap: T.laggingN, roughness: .4, metalness: .7 }, .4),
  brick: sm('Firebrick', 'Firebrick', { map: T.brick, normalMap: T.brickN, roughness: .9 }, .8),
  pole: sm('PoleConcrete', 'PoleConcrete', { map: T.pole, normalMap: T.poleN, roughness: .9 }, .5),
  guard: sm('Mesh', 'WireMeshGuard', { map: T.mesh, alphaTest: .5, side: DS, roughness: .5 }, 2),
  radiator: sm('Core', 'RadiatorCore', { map: T.radiator, roughness: .6, metalness: .5 }, 1),
  rubber: sm('Rubber', 'Rubber', { map: T.rubber, roughness: .88 }),
  foam: sm('Foam', 'AcousticFoamPerforated', { map: T.mesh, color: 0x8a8c88, roughness: .9 }, 6),
  caseM: sm('Case', 'CellCase', { map: T.cellCase, transparent: true, opacity: .5, roughness: .25, depthWrite: false, side: DS }, .83),
  electrolyte: sm('Electrolyte', 'Electrolyte', { color: 0xc5d6a0, transparent: true, opacity: .4, roughness: .1, depthWrite: false }),
  water: sm('Water', 'GaugeWater', { color: 0x8fb7c9, transparent: true, opacity: .5, roughness: .1, depthWrite: false }),
  plates: sm('Plates', 'LeadPlates', { color: 0x4a4b4d, roughness: .75, metalness: .3 }),
  copper: sm('Copper', 'Copper', { color: 0xb8673a, roughness: .32, metalness: .95 }),
  brass: sm('Brass', 'Brass', { color: 0xb38c3c, roughness: .35, metalness: .9 }),
  porcelain: sm('Porcelain', 'Porcelain', { color: 0xeeeae0, roughness: .12 }),
  red: sm('Red', 'RedPaint', { color: 0xb8281c, roughness: .4, metalness: .1 }),
  black: sm('Black', 'BlackPlastic', { color: 0x1c1c1c, roughness: .55 }),
  dark: sm('Dark', 'DarkPaint', { color: 0x2f3231, roughness: .6, metalness: .3 }),
  ctrl: sm('Enclosure', 'EnclosureGrey', { color: 0xd4d7d1, roughness: .5 }),
  steel: sm('Steel', 'BrightSteel', { color: 0xb9bcbd, roughness: .32, metalness: .9 }),
  bolt: sm('Bolts', 'ZincBolt', { color: 0x8f918d, roughness: .45, metalness: .8 }),
  cable: sm('Cable', 'CableBlack', { color: 0x161616, roughness: .6 }),
  ash: sm('Ash', 'Ash', { color: 0x9d9a93, roughness: 1 }),
  straw: sm('Straw', 'StrawBale', { map: T.straw, roughness: .95 }, .8),
  hole: sm('Bore', 'BoreShadow', { color: 0x0d0d0d, roughness: 1 }),
  holeBack: sm('BoreIn', 'BoreShadowInner', { color: 0x0d0d0d, roughness: 1, side: THREE.BackSide }),
  glass: sm('Glass', 'Glass', { color: 0xdfe8ea, roughness: .05, transparent: true, opacity: .25, depthWrite: false }),
  emG: sm('LampGreen', 'LampGreen', { color: 0x2bd46a, emissive: 0x2bd46a, emissiveIntensity: 1.6 }),
  emR: sm('LampRed', 'LampRed', { color: 0xff3322, emissive: 0xff2a1a, emissiveIntensity: 1.6 }),
  emA: sm('LampAmber', 'LampAmber', { color: 0xffb020, emissive: 0xffa010, emissiveIntensity: 1.4 }),
  fire: sm('Flames', 'Fire', { map: T.fire, emissive: 0xffffff, emissiveMap: T.fire, emissiveIntensity: 1.8, roughness: 1 }),
  coal: sm('Coals', 'Coals', { color: 0xff5a10, emissive: 0xff4a00, emissiveIntensity: 1.5, roughness: 1 }),
  leaf: sm('Leaves', 'DryLeaf', { map: T.leaf, alphaTest: .5, side: DS, roughness: .9 }),
  marker: sm('Marker', 'WireMarker', { color: 0xff00ff, transparent: true, opacity: 0, depthWrite: false }),
  oil: decalMat('Oil', 'OilStain', T.oil, { roughness: .3 }), soot: decalMat('Soot', 'Soot', T.soot), worn: decalMat('Worn', 'WornPatch', T.worn),
  dust: decalMat('Dust', 'StrawDust', T.dust), rust: decalMat('Rust', 'RustStreak', T.rust),
};
M.sootCh = decalMat('SootBand', 'SootBandChimney', T.sootBand); M.sootCh.userData.uvScale = 1 / .9;
M.sootDG = decalMat('SootBand', 'SootBandStack', T.sootBand); M.sootDG.userData.uvScale = 1 / .7;
const label = (part, tex, o = {}) => sm(part, part, Object.assign({ map: tex, roughness: .55, metalness: .1, polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -3 }, o));
const lcd = (part, tex) => sm(part, part, { map: tex, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: .9, roughness: .3 });
M.levels = [1, 2, 3, 4].map(i => sm('Lamp', 'BatteryLevel' + i, { color: 0x2bd46a, emissive: 0x2bd46a, emissiveIntensity: 1.6 }));

/* ---------- shared helpers ---------- */
const root = id => { const r = new THREE.Group(); r.name = id; return r; };
const grpOf = (R, p) => n => { let g = R.children.find(c => c.name === p + n); if (!g) { g = new THREE.Group(); g.name = p + n; R.add(g); } return g; };
const nut = (g, p, d = [0, 1, 0], r = .04, h = .035) => orient(add(g, hexG(r, h).translate(0, h / 2, 0), M.bolt, p), d);
function boltRing(g, c, d, R, n, r = .035, h = .03, a0 = 0) { const s = sub(g, c, d); for (let i = 0; i < n; i++) { const a = a0 + i / n * TAU; nut(s, [R * Math.cos(a), 0, R * Math.sin(a)], [0, 1, 0], r, h); } return s; }
function anchor(g, x, y, z) { add(g, cylG(.09, .09, .015, 12), M.bolt, [x, y + .0075, z]); nut(g, [x, y + .015, z], [0, 1, 0], .06, .05); add(g, cylG(.025, .025, .1, 8), M.bolt, [x, y + .09, z]); }
function pad(g, w, d, h, bolts = [], edge = true) { add(g, bboxG(w, h, d, .04), M.concrete, [0, h / 2, 0]);
  if (edge) for (const s of [-1, 1]) { add(g, boxG(w - .12, .006, .16), M.hazard, [0, h + .003, s * (d / 2 - .12)]); add(g, boxG(.16, .006, d - .44), M.hazard, [s * (w / 2 - .12), h + .003, 0]); }
  bolts.forEach(([x, z]) => anchor(g, x, h, z)); }
function gland(g, p, d = [0, 1, 0], r = .06) { const s = sub(g, p, d); add(s, hexG(r * 1.3, .05).translate(0, .025, 0), M.bolt); add(s, cylG(r * .9, r, .07, 12).translate(0, .085, 0), M.black); add(s, new THREE.SphereGeometry(r * .85, 12, 5, 0, TAU, 0, PI / 2).translate(0, .12, 0), M.black); return s; }
const flat = (w, h) => plane(w, h).rotateX(-PI / 2);
function sticker(g, m, w, h, p, ry = 0) { return add(g, plane(w, h), m, p, [0, ry, 0]); }
function wireTop(R, pfx, p) { const m = new THREE.Mesh(new THREE.BoxGeometry(.2, .2, .2), M.marker); m.name = pfx + 'WireTop'; m.position.copy(v3(p)); m.visible = false; R.add(m); }
function prismXY(g, m, pts, z0, z1) { const s = new THREE.Shape(); pts.forEach(([a, b], i) => i ? s.lineTo(a, b) : s.moveTo(a, b)); const geo = new THREE.ExtrudeGeometry(s, { depth: z1 - z0, bevelEnabled: false }); geo.translate(0, 0, z0); return add(g, geo, m); }
function prismZY(g, m, shape, x0, x1) { const geo = new THREE.ExtrudeGeometry(shape, { depth: x1 - x0, bevelEnabled: false, curveSegments: 24 }); geo.translate(0, 0, -x1); geo.rotateY(-PI / 2); return add(g, geo, m); }
function louvre(g, c, w, h, face, m = M.canopy) { const s = sub(g, c); s.rotation.y = Math.atan2(face[0], face[1]);
  add(s, plane(w, h), M.hole, [0, 0, .004]); const n = Math.floor((h - .06) / .09);
  for (let i = 0; i < n; i++) add(s, boxG(w - .03, .022, .085), m, [0, -h / 2 + .08 + i * .09, .036], [-.65, 0, 0]);
  for (const k of [-1, 1]) { add(s, boxG(w + .08, .04, .06), m, [0, k * (h / 2 + .02), .03]); add(s, boxG(.04, h, .06), m, [k * (w / 2 + .02), 0, .03]); } return s; }
function dialFace(g, part, tex, c, r, normal, glassG) { const s = sub(g, c, normal); add(s, new THREE.CircleGeometry(r, 32).rotateX(-PI / 2), label(part, tex), [0, .002, 0]); if (glassG) { const s2 = sub(glassG, c, normal); add(s2, new THREE.CircleGeometry(r, 32).rotateX(-PI / 2), M.glass, [0, .008, 0]); } }
export function finish(R) { for (const c of [...R.children]) if (c.isGroup) mergeGroup(c);
  R.traverse(o => { if (!o.isMesh) return; const m = o.material; o.castShadow = !(m.transparent || m === M.marker); o.receiveShadow = true; }); return R; }

/* ================= 1. HandCrank ================= */
export function buildHandCrank() {
  setSeed(101); const R = root('HandCrank'), G = grpOf(R, 'HC_');
  const B = G('Base'), Dy = G('Dynamo'), W = G('Wheel'), D = G('Details'), Gl = G('Glass'); const DT = .48;
  for (const z of [-1.7, 1.7]) { add(B, bboxG(5.8, .3, .46, .03), M.timber, [0, .15, z]);
    for (const x of [-2.55, -.4, 1.15, 2.55]) { add(B, boxG(.07, .32, .5), M.iron, [x, .16, z]); for (const s of [-1, 1]) nut(B, [x, .2, z + s * .25], [0, 0, s], .032, .02); } }
  for (let i = 0; i < 9; i++) { const x = -2.6 + i * .65; add(B, bboxG(.6, .18, 4.2, .025), M.timber, [x, .39, rr(-.03, .03)], [0, rr(-.005, .005), 0]);
    for (const z of [-1.7, 1.7]) for (const dx of [-.16, .16]) add(B, hexG(.03, .012), M.iron, [x + dx, DT + .006, z]); }
  for (const x of [.65, 1.65]) { const ph = 2.36 - DT; add(B, bboxG(.4, ph, .55, .03), M.timber, [x, DT + ph / 2, 0]);
    for (const s of [-1, 1]) { add(B, boxG(.36, .3, .02), M.iron, [x, DT + .15, s * .285]); add(B, boxG(.36, .02, .16), M.iron, [x, DT + .01, s * .365]);
      for (const dx of [-.11, .11]) { nut(B, [x + dx, DT + .02, s * .39], [0, 1, 0], .03, .025); nut(B, [x + dx, DT + .2, s * .295], [0, 0, s], .03, .02); } }
    add(B, bboxG(.42, .1, .8, .02), M.iron, [x, 2.41, 0]); add(B, latheX([[.075, -.17], [.21, -.17], [.23, -.14], [.23, .14], [.21, .17], [.075, .17]], 24), M.iron, [x, 2.6, 0]);
    for (const s of [-1, 1]) nut(B, [x, 2.46, s * .33], [0, 1, 0], .035, .035);
    add(B, cylG(.035, .035, .08, 10), M.brass, [x, 2.86, 0]); add(B, cylG(.05, .05, .03, 10), M.brass, [x, 2.915, 0]); }
  // flywheel (group origin on axis)
  W.position.set(2.2, 2.6, 0);
  add(W, latheX(ringProf(1.6, 1.9, .24, .03), 72), M.iron);
  add(W, latheX([[.07, -.2], [.2, -.2], [.25, -.13], [.25, .13], [.2, .2], [.07, .2]], 32), M.iron);
  for (let i = 0; i < 6; i++) { const a = i / 6 * TAU, d = new V3(0, Math.cos(a), Math.sin(a)); orient(add(W, cylG(.05, .08, 1.38, 14), M.iron, d.clone().multiplyScalar(.92)), d); }
  add(W, latheX([[0, -.05], [.1, -.05], [.1, .12], [0, .12]], 16), M.iron, [0, 1.45, 0]);
  add(W, latheX([[0, .1], [.035, .1], [.035, .75], [0, .75]], 12), M.steel, [0, 1.45, 0]);
  add(W, latheX([[0, .2], [.06, .2], [.075, .24], [.088, .46], [.075, .68], [.055, .72], [0, .72]], 18), M.timber, [0, 1.45, 0]);
  { const g = gearG(1.0, 48, .14, .045, 6, .17); g.rotateY(PI / 2); add(W, g, M.iron, [-2.05, 0, 0]); add(W, latheX([[.07, -.12], [.2, -.12], [.2, .12], [.07, .12]], 24), M.iron, [-2.05, 0, 0]); }
  add(W, alongX(cylG(.07, .07, 2.55, 18)), M.steel, [-.97, 0, 0]);
  for (const x of [-1.76, -.33]) add(W, latheX(ringProf(.07, .11, .06), 18), M.steel, [x, 0, 0]);
  // dynamo
  const dy = 1.59, dz = .85;
  add(Dy, alongX(cylG(.55, .55, 1.6, 56)), M.iron, [-1.5, dy, dz]);
  add(Dy, latheX([[0, 0], [.28, 0], [.44, .07], [.52, .18], [.53, .26]], 40), M.iron, [-2.56, dy, dz]);
  add(Dy, latheX([[.53, 0], [.52, .08], [.44, .19], [.28, .26], [0, .26]], 40), M.iron, [-.7, dy, dz]);
  for (const x of [-2.64, -.44]) add(Dy, latheX([[0, 0], [.12, 0], [.12, .08], [0, .08]], 16), M.iron, [x, dy, dz]);
  add(Dy, alongX(cylG(.05, .05, .75, 12)), M.steel, [-.07, dy, dz]);
  { const g = gearG(.32, 16, .14, .04); g.rotateY(PI / 2); add(Dy, g, M.iron, [.15, dy, dz]); }
  for (const x of [-2.1, -.9]) for (let i = 0; i < 16; i++) { const a = i / 16 * TAU; if (Math.cos(a) < -.45) continue; add(Dy, boxG(.3, .045, .08), M.hole, [x, dy + .553 * Math.cos(a), dz + .553 * Math.sin(a)], [a, 0, 0]); }
  for (const x of [-2.05, -.95]) { const fh = dy - .3 - (DT + .05); add(Dy, frustumG(.34, 1.05, .24, .62, fh), M.iron, [x, DT + .05 + fh / 2, dz]); add(Dy, boxG(.44, .05, 1.15), M.iron, [x, DT + .025, dz]);
    for (const a of [-1, 1]) for (const b of [-1, 1]) nut(Dy, [x + a * .14, DT + .05, dz + b * .48], [0, 1, 0], .035, .03); }
  add(Dy, bboxG(.45, .26, .4, .03), M.iron, [-1.5, 2.25, dz]); for (const a of [-1, 1]) for (const b of [-1, 1]) nut(Dy, [-1.5 + a * .17, 2.38, dz + b * .15], [0, 1, 0], .02, .015);
  gland(Dy, [-1.5, 2.25, dz - .2], [0, 0, -1], .045);
  add(Dy, new THREE.TorusGeometry(.07, .018, 8, 18), M.steel, [-.95, 2.22, dz]); add(Dy, cylG(.02, .02, .08, 8), M.steel, [-.95, 2.15, dz]);
  sticker(Dy, label('Nameplate', T.namePlate('DYNAMO', '12 V · 60 W · 1500 rpm', 'No. 1964-0417', '#b38c3c', '#3a2a10'), { metalness: .7, roughness: .35 }), .48, .24, [-1.5, dy, dz + .557]);
  add(Dy, flat(1.8, 1.1), M.oil, [-1.45, DT + .003, dz]);
  // details: meter board, voltmeter, knife switch, cable post
  for (const z of [-1.55, -.25]) add(D, bboxG(.12, 2.55 - DT, .12, .015), M.timber, [-2.72, DT + (2.55 - DT) / 2, z]);
  add(D, bboxG(.06, 1.25, 1.45, .015), M.timber, [-2.64, 1.88, -.9]);
  add(D, latheX([[0, 0], [.2, 0], [.22, .02], [.22, .09], [.19, .1]], 32), M.dark, [-2.61, 2.15, -.55]);
  add(D, new THREE.TorusGeometry(.2, .015, 6, 32).rotateY(PI / 2), M.brass, [-2.51, 2.15, -.55]);
  dialFace(D, 'DialV', T.dial('V', 16, .8, '#efe6cf'), [-2.512, 2.15, -.55], .19, [1, 0, 0], Gl);
  add(D, boxG(.03, .52, .36), M.dark, [-2.595, 1.55, -1.2]);
  for (const zz of [-.08, .08]) { const z = -1.2 + zz; add(D, boxG(.06, .08, .03), M.copper, [-2.55, 1.74, z]); add(D, boxG(.06, .06, .04), M.copper, [-2.55, 1.36, z]);
    const p0 = new V3(-2.53, 1.36, z), d = new V3(Math.sin(40 * DEG), Math.cos(40 * DEG), 0); beam(D, M.copper, p0, p0.clone().addScaledVector(d, .34), .01, .035); }
  { const tip = new V3(-2.53, 1.36, 0).addScaledVector(new V3(Math.sin(40 * DEG), Math.cos(40 * DEG), 0), .34); pipe(D, M.black, [tip.x, tip.y, -1.31], [tip.x, tip.y, -1.09], .02, 10); pipe(D, M.black, [tip.x, tip.y, -1.2], [tip.x + .14, tip.y + .05, -1.2], .028, 10); }
  add(D, bboxG(.18, 4.12 - DT, .18, .02), M.timber, [-.6, DT + (4.12 - DT) / 2, -.45]);
  add(D, boxG(.06, .04, .46), M.iron, [-.6, 4.0, -.15]); nut(D, [-.6, 4.02, -.45], [0, 1, 0], .03, .02);
  add(D, cylG(.02, .02, .1, 8), M.steel, [-.6, 4.07, 0]);
  add(D, revolve([[.03, 0], [.1, 0], [.12, .05], [.12, .1], [.08, .13], [.08, .2], [.11, .23], [.11, .27], [.06, .32], [0, .33]], 28), M.porcelain, [-.6, 4.04, 0]);
  add(D, tubeG([[-1.5, 2.25, dz - .27], [-1.55, 2.2, .2], [-2.0, 2.32, -.15], [-2.5, 2.48, -.4], [-2.62, 2.52, -.42]], .025, 8), M.cable);
  add(D, tubeG([[-2.62, 2.52, -1.3], [-2.0, 2.68, -.5], [-1.1, 2.9, -.42], [-.72, 3.05, -.45], [-.72, 3.95, -.45], [-.66, 4.22, -.12], [-.6, 4.2, -.02]], .025, 8, .2), M.cable);
  add(D, tubeG([[-2.61, 2.1, -.62], [-2.61, 1.8, -.9], [-2.57, 1.76, -1.12]], .015, 6), M.cable);
  for (const y of [3.3, 3.7]) add(D, boxG(.06, .02, .06), M.steel, [-.72, y, -.45]);
  add(D, new THREE.TorusGeometry(.085, .012, 4, 16).rotateX(PI / 2), M.copper, [-.6, 4.205, 0]);
  add(D, flat(1.6, 1.0), M.worn, [2.2, .003, 2.5]); add(D, flat(1.0, 1.7), M.worn, [2.35, DT + .004, 1.15]);
  wireTop(R, 'HC_', [-.6, 4.4, 0]);
  return finish(R);
}

/* ================= 2. SolarPanel ================= */
export function buildSolar() {
  setSeed(202); const R = root('SolarPanel'), G = grpOf(R, 'SP_'); const Rk = G('Rack'), Fr = G('Frame'), Ce = G('Cells'), Co = G('Controller'), Em = G('Emissive');
  const th = 16 * DEG, L = 7.0, Wp = 3.6, ct = Math.cos(th), st = Math.sin(th), cy = 1.0 + L / 2 * st + .14 * ct;
  const Wd = (x, y, z) => new V3(x, cy + y * ct + z * st, -y * st + z * ct);
  const tilt = g => { const s = new THREE.Group(); s.position.set(0, cy, 0); s.rotation.x = -th; g.add(s); return s; };
  const tf = tilt(Fr), tc = tilt(Ce), tr = tilt(Rk), s0 = xc => xc > 0 ? 1 : -1;
  for (const xc of [-1.85, 1.85]) {
    for (const s of [-1, 1]) { add(tf, boxG(.06, .16, L), M.alu, [xc + s * (Wp / 2 - .03), -.06, 0]); add(tf, boxG(Wp - .12, .16, .06), M.alu, [xc, -.06, s * (L / 2 - .03)]);
      add(tf, boxG(.05, .025, L - .12), M.alu, [xc + s * (Wp / 2 - .085), .005, 0]); add(tf, boxG(Wp - .22, .025, .05), M.alu, [xc, .005, s * (L / 2 - .085)]);
      add(tf, boxG(.05, .02, L - .12), M.alu, [xc + s * (Wp / 2 - .085), -.13, 0]); add(tf, boxG(Wp - .22, .02, .05), M.alu, [xc, -.13, s * (L / 2 - .085)]);
      for (const k of [-1, 1]) add(tf, boxG(.03, .012, .05), M.hole, [xc + s * (Wp / 2 - .03) + (s > 0 ? -.035 : .035), -.13, k * (L / 2 - .4)]); }
    add(tf, boxG(Wp - .12, .03, L - .12), M.laminate, [xc, -.01, 0]);
    add(tf, plane(Wp - .12, L - .12).rotateX(PI / 2), M.backsheet, [xc, -.026, 0]);
    add(tc, flat(Wp - .14, L - .14), M.cells, [xc, .0058, 0]);
    // junction box + leads
    add(tf, bboxG(.42, .09, .3, .02), M.black, [xc, -.075, 2.7]); for (const k of [-1, 1]) add(tf, cylG(.03, .03, .08, 10).rotateX(PI / 2), M.black, [xc + k * .12, -.08, 2.53]);
    add(tf, plane(.24, .14).rotateX(PI / 2), label('JBox', T.label('IP67 · 1000 V', '#e8e8e2')), [xc, -.121, 2.7]);
    sticker(tf, label('PanelLabel', T.namePlate('COOP SOLAR 380 W', 'Vmp 34.6 V · Imp 11.0 A', 'Voc 41.2 V · IEC 61215', '#eeeeea', '#222')), .6, .3, [xc - .9, -.028, 2.2]).rotation.set(PI / 2, 0, PI);
    for (const v of [-2.2, 2.2]) { for (const s of [-1, 1]) if (s * xc > 0) { const x = xc + s * (Wp / 2 + .05); add(tf, bboxG(.1, .1, .16, .015), M.alu, [x, -.03, v]); nut(tf, [x, .02, v], [0, 1, 0], .03, .025); } }
    add(tf, flat(Wp - .2, .7), M.dust, [xc, .0095, -L / 2 + .42]);
    for (let k = 0; k < 6; k++) add(tf, plane(.16, .16), M.leaf, [xc + rr(-1.6, 1.6), k % 2 ? .022 : .011, -L / 2 + rr(.03, .14)], [-PI / 2, 0, rr(0, TAU)]);
    // cables to controller
    add(Fr, tubeG([Wd(xc + .12, -.13, 2.53), Wd(xc + .12, -.22, 2.4), Wd(1.6, -.22, 2.4), Wd(2.4, -.3, 2.45), [2.4, 1.6, 2.55], [2.42, .95, 2.72], [2.58 + (xc > 0 ? .06 : 0), .78, 2.8]], .022, 14, .3), M.cable);
    for (let k = 0; k < 6; k++) { const v = -2.6 + k * 1.0; add(tf, new THREE.TorusGeometry(.04, .008, 6, 14).rotateY(PI / 2), M.black, [xc + s0(xc) * 1.4, -.17, v]); }
    for (const k of [-1, 1]) { add(tf, cylG(.035, .035, .14, 16).rotateX(PI / 2), M.black, [xc + k * .12, -.12, 2.4]); add(tf, tubeG([[xc + k * .12, -.12, 2.33], [xc + k * .12 + .2, -.15, 1.9], [xc + s0(xc) * 1.4, -.17, 1.4], [xc + s0(xc) * 1.4, -.17, -2.6], [xc + s0(xc) * 1.4 + k * .04, -.2, -2.9]], .015, 10, .3), M.cable); }
  }
  for (const v of [-2.2, 2.2]) { add(tf, bboxG(.16, .06, .16, .015), M.alu, [0, .025, v]); nut(tf, [0, .055, v], [0, 1, 0], .03, .025); }
  // rack
  for (const v of [-2.2, 2.2]) add(tr, boxG(7.5, .1, .1), M.galv, [0, -.19, v]);
  for (const x of [-3.1, 0, 3.1]) { add(tr, boxG(.1, .14, L - .4), M.galv, [x, -.31, 0]); for (const v of [-2.2, 2.2]) for (const k of [-1, 1]) nut(tr, [x + k * .07, -.14, v], [0, 1, 0], .025, .02); }
  let zr;
  for (const x of [-3.1, 0, 3.1]) for (const v of [-2.9, 2.95]) { const t = Wd(x, -.38, v); if (v > 0) zr = t.z;
    add(Rk, bboxG(.55, .4, .55, .04), M.concrete, [x, .2, t.z]); add(Rk, boxG(.24, .02, .24), M.galv, [x, .41, t.z]);
    for (const a of [-1, 1]) for (const b of [-1, 1]) nut(Rk, [x + a * .08, .42, t.z + b * .08], [0, 1, 0], .025, .025);
    beam(Rk, M.galv, [x, .4, t.z], [x, t.y + .02, t.z], .1, .1); add(Rk, boxG(.16, .1, .16), M.galv, [x, t.y + .02, t.z]);
    for (const k of [-1, 1]) nut(Rk, [x + k * .081, t.y - .02, t.z], [k, 0, 0], .025, .02); add(Rk, alongX(cylG(.012, .012, .2, 8)), M.bolt, [x, t.y - .02, t.z]);
    if (v > 0) beam(Rk, M.galv, [x, .6, t.z - .04], Wd(x, -.38, .5), .06, .06); }
  for (const [a, b] of [[-3.1, 0]]) { beam(Rk, M.galv, [a, .6, zr], [b, Wd(0, -.38, 2.95).y - .25, zr], .05, .03); beam(Rk, M.galv, [b, .6, zr], [a, Wd(0, -.38, 2.95).y - .25, zr], .05, .03); }
  beam(Rk, M.galv, [0, .7, zr], [3.1, .7, zr], .05, .05);
  // controller
  const cxC = 2.75, czC = zr - .12;
  add(Co, bboxG(.5, .55, .22, .025), M.ctrl, [cxC, 1.275, czC]); add(Co, boxG(.1, .4, .06), M.galv, [3.03, 1.28, zr - .05]);
  for (let i = 0; i < 8; i++) add(Co, boxG(.02, .42, .05), M.alu, [cxC - .21 + i * .06, 1.275, czC - .135]);
  sticker(Co, label('CtrlLabel', T.lcd(['MPPT 20A', '12/24 V'], '#20333a', '#e8f0ee')), .3, .15, [cxC + .05, 1.3, czC + .112]);
  add(Co, cylG(.035, .035, .01, 14).rotateX(PI / 2), M.black, [cxC - .15, 1.45, czC + .112]);
  add(Em, cylG(.022, .022, .012, 14).rotateX(PI / 2), M.emG, [cxC - .15, 1.45, czC + .118]);
  gland(Co, [cxC, 1.55, czC], [0, 1, 0], .04); for (const dx of [-.11, .06]) gland(Co, [cxC + dx, 1.0, czC], [0, -1, 0], .035);
  wireTop(R, 'SP_', [cxC, 1.62, czC]);
  return finish(R);
}

/* ================= 3. PowerPole ================= */
export function buildPole() {
  setSeed(303); const R = root('PowerPole'), G = grpOf(R, 'PO_'); const Po = G('Pole'), Ca = G('Crossarm'), In = G('Insulators'), C1 = G('Coil1'), C2 = G('Coil2'), De = G('Details');
  const H = 13.6, w = y => .5 - .22 * y / H;
  add(Po, bboxG(1.7, .45, 1.7, .05), M.concrete, [0, .225, 0]); add(Po, frustumG(.5, .5, .28, .28, H), M.pole, [0, H / 2, 0]);
  add(Po, frustumG(.28, .28, .2, .2, .08), M.pole, [0, H + .04, 0]);
  for (let y = 2.6; y < 12.6; y += .9) for (const s of [-1, 1]) add(Po, plane(.07, .07), M.hole, [s * (w(y) / 2 + .002), y, 0], [0, s * PI / 2, 0]);
  add(Po, flat(1.4, 1.4), M.rust, [0, .452, 0]);
  // double steel crossarm straddling the pole
  for (const s of [-1, 1]) { add(Ca, boxG(.02, .2, 5.2), M.galv, [s * .155, 13.35, 0]); for (const y of [13.26, 13.44]) add(Ca, boxG(.08, .02, 5.2), M.galv, [s * .185, y, 0]); }
  add(Ca, alongX(cylG(.025, .025, .5, 8)), M.bolt, [0, 13.35, 0]); for (const s of [-1, 1]) nut(Ca, [s * .23, 13.35, 0], [s, 0, 0], .04, .035);
  for (const z of [-2, 2]) { add(Ca, boxG(.42, .02, .22), M.galv, [0, 13.46, z]); for (const s of [-1, 1]) nut(Ca, [s * .17, 13.47, z], [0, 1, 0], .03, .025); }
  for (const s of [-1, 1]) for (const sz of [-1, 1]) beam(Ca, M.galv, [s * .165, 12.4, sz * .13], [s * .165, 13.25, sz * 1.3], .05, .015);
  add(Ca, bboxG(w(12.4) + .04, .1, w(12.4) + .04, .01), M.galv, [0, 12.4, 0]);
  // insulators (spool type, neck carries the coil)
  const prof = [[.03, 0], [.12, 0], [.2, .06], [.57, .12], [.57, .16], [.5, .22], [.46, .28], [.46, .72], [.5, .78], [.57, .84], [.57, .88], [.3, .93], [.12, .96], [0, .96]];
  for (const z of [-2, 2]) { add(In, cylG(.03, .03, .26, 10), M.galv, [0, 13.58, z]); nut(In, [0, 13.47, z], [0, 1, 0], .05, .04); add(In, revolve(prof, 40), M.porcelain, [0, 13.7, z]); }
  for (const [C, z] of [[C1, -2], [C2, 2]]) { C.position.set(0, 14.2, z); add(C, helixG(.52, .06, 2, -.15, .15, 200, 8), M.copper);
    add(C, boxG(.12, .34, .1), M.copper, [.555, 0, 0]); add(C, boxG(.12, .34, .1), M.copper, [-.555, 0, 0]);
    for (const s of [-1, 1]) nut(C, [s * .615, 0, 0], [s, 0, 0], .03, .03); }
  // details
  const sy = 3.0, sz = w(sy) / 2;
  add(De, boxG(.66, .76, .012), M.galv, [0, sy, sz + .008]); sticker(De, label('SignDanger', T.signThai), .62, .72, [0, sy, sz + .016]);
  for (const y of [sy + .34, sy - .34]) add(De, bboxG(w(y) + .03, .04, w(y) + .03, .005), M.steel, [0, y, 0]);
  sticker(De, label('PoleTag', T.poleTag, { metalness: .5 }), .36, .18, [0, 2.1, w(2.1) / 2 + .004]);
  const gw = []; for (let y = 13.25; y > .6; y -= 1.0) gw.push([-(w(y) / 2 + .025), y, .09]); gw.push([-(w(.6) / 2 + .025), .5, .09], [-.6, .47, .3], [-.65, .5, .45]);
  add(De, tubeG(gw, .014, 6, .1), M.copper); for (let y = 12.4; y > 1; y -= 1.2) add(De, boxG(.03, .025, .06), M.steel, [-(w(y) / 2 + .02), y, .09]);
  add(De, cylG(.03, .03, .2, 8), M.copper, [-.65, .55, .45]); add(De, boxG(.08, .06, .08), M.brass, [-.65, .58, .45]);
  add(De, tubeG([[-.2, 13.25, .09], [-.16, 13.3, .09]], .014, 6), M.copper);
  return finish(R);
}

/* ================= 4. Battery ================= */
export function buildBattery() {
  setSeed(404); const R = root('Battery'), G = grpOf(R, 'BB_');
  const Cab = G('Cabinet'), Ce = G('Cells'), Bu = G('Busbars'), Ct = G('Controls'), Lv = [1, 2, 3, 4].map(i => G('Level' + i)), Gl = G('Glass');
  pad(Cab, 6, 6, .3, [[-2.78, -2.78], [2.78, -2.78], [-2.78, 2.78], [2.78, 2.78]]);
  add(Cab, boxG(5.4, .03, 4.8), M.galv, [0, .315, -.1]); for (const s of [-1, 1]) { add(Cab, boxG(5.4, .12, .03), M.galv, [0, .36, -.1 + s * 2.385]); add(Cab, boxG(.03, .12, 4.8), M.galv, [s * 2.685, .36, -.1]); }
  add(Cab, flat(1.6, 1.0), M.rust, [-1.2, .332, 1.6]); add(Cab, flat(1.2, .9), M.rust, [1.6, .332, 1.8]);
  for (const a of [-1, 1]) for (const b of [-1, 1]) add(Cab, boxG(.22, .17, .22), M.galv, [a * 2.35, .415, -.1 + b * 2.1]);
  add(Cab, boxG(5.0, .05, 4.4), M.teal, [0, .525, -.1]);
  for (const s of [-1, 1]) { add(Cab, boxG(.04, 4.95, 4.4), M.teal, [s * 2.48, 2.975, -.1]);
    for (let i = 0; i < 8; i++) for (const z of [-1.3, .9]) { add(Cab, plane(1.4, .1), M.hole, [s * 2.502, 1.05 + i * .5, z], [0, s * PI / 2, 0]); add(Cab, boxG(.05, .03, 1.42), M.teal, [s * 2.515, 1.08 + i * .5, z], [0, 0, s * .55]); } }
  add(Cab, boxG(5.0, 4.95, .04), M.teal, [0, 2.975, -2.28]);
  add(Cab, bboxG(5.2, .06, 4.6, .02), M.teal, [0, 5.48, -.1]); add(Cab, boxG(5.2, .05, .03), M.teal, [0, 5.43, 2.2]);
  for (const s of [-1, 1]) add(Cab, boxG(.25, 4.95, .05), M.teal, [s * 2.375, 2.975, 2.075]);
  add(Cab, boxG(4.5, .45, .05), M.teal, [0, 5.225, 2.075]); add(Cab, boxG(4.5, .15, .05), M.teal, [0, .575, 2.075]);
  for (const y of [1.2, 3.0, 4.8]) { add(Cab, cylG(.032, .032, .22, 10), M.steel, [2.52, y, 2.12]); add(Cab, boxG(.04, .22, .12), M.steel, [2.48, y, 2.12]); }
  for (const y of [2.2, 3.75]) { add(Cab, boxG(4.9, .06, 4.3), M.galv, [0, y, -.1]); for (const s of [-1, 1]) add(Cab, boxG(.08, .08, 4.3), M.galv, [s * 2.42, y - .07, -.1]); }
  sticker(Cab, label('SignAcid', T.noSmoke), 1.6, .4, [0, 5.225, 2.103]);
  sticker(Cab, label('RatingPlate', T.namePlate('BATTERY BANK', '48 V · 600 Ah · 24 × 2 V', 'Lead-acid · vented · keep upright', '#e9e9e3', '#222')), .7, .35, [1.5, 5.225, 2.103]);
  add(Cab, flat(4.4, .5), M.dust, [0, 5.513, -.2]);
  // cells: 3 tiers × 6, snake-connected
  const tb = [.55, 2.23, 3.78], cw = .68, cd = .95, cz = .9;
  tb.forEach((y0, t) => { for (let i = 0; i < 6; i++) { const xc = -1.9 + i * .76;
      add(Ce, boxG(cw, 1.02, cd), M.caseM, [xc, y0 + .51, cz]);
      for (let k = 0; k < 7; k++) add(Ce, boxG(.03, .85, cd - .12), M.plates, [xc - .27 + k * .09, y0 + .47, cz]);
      add(Ce, boxG(cw - .04, .9, cd - .04), M.electrolyte, [xc, y0 + .47, cz]);
      add(Ce, bboxG(cw + .02, .1, cd + .02, .015), M.black, [xc, y0 + 1.07, cz]);
      add(Ce, cylG(.06, .06, .08, 14), M.dark, [xc, y0 + 1.16, cz - .28]); add(Ce, cylG(.04, .06, .04, 14), M.dark, [xc, y0 + 1.22, cz - .28]);
      for (const s of [-1, 1]) { const pos = (t % 2 ? s > 0 : s < 0); add(Ce, cylG(.05, .05, .13, 14), M.plates, [xc + s * .2, y0 + 1.185, cz]); add(Ce, cylG(.075, .075, .03, 16), pos ? M.red : M.black, [xc + s * .2, y0 + 1.135, cz]);
        nut(Ce, [xc + s * .2, y0 + 1.24, cz], [0, 1, 0], .055, .04); }
      if (i < 5) add(Bu, boxG(.48, .025, .09), M.copper, [xc + .38, y0 + 1.2275, cz]); } });
  add(Bu, tubeG([[2.1, tb[0] + 1.28, cz], [2.33, tb[0] + 1.3, cz], [2.33, tb[1] + 1.3, cz], [2.1, tb[1] + 1.28, cz]], .035, 8, .2), M.red);
  add(Bu, tubeG([[-2.1, tb[1] + 1.28, cz], [-2.33, tb[1] + 1.3, cz], [-2.33, tb[2] + 1.3, cz], [-2.1, tb[2] + 1.28, cz]], .035, 8, .2), M.red);
  add(Bu, tubeG([[2.1, tb[2] + 1.28, cz], [2.3, tb[2] + 1.32, cz], [2.42, 5.2, .9], [2.6, 4.6, .9]], .04, 8, .3), M.cable);
  add(Bu, tubeG([[-2.1, tb[0] + 1.28, cz], [-2.36, tb[0] + 1.32, .4], [-2.36, 5.3, .2], [0, 5.35, -.4], [2.4, 5.3, .6], [2.6, 4.62, .95]], .04, 8, .3), M.red);
  // controls: BMS box on +X wall, conduit to roof gland
  add(Ct, bboxG(.32, 1.0, .9, .02), M.ctrl, [2.66, 4.0, .9]);
  sticker(Ct, lcd('Display', T.lcd(['48.6 V  75%', 'CHG  +12 A'])), .5, .25, [2.822, 4.2, .9], PI / 2);
  for (let k = 0; k < 3; k++) add(Ct, cylG(.035, .035, .03, 12).rotateZ(PI / 2), M.dark, [2.83, 3.85, .7 + k * .2]);
  sticker(Ct, label('BmsLabel', T.label('BMS-48', '#d4d7d1', '#1f6f6c')), .4, .1, [2.822, 3.62, .9], PI / 2);
  gland(Ct, [2.66, 3.5, .9], [0, -1, 0], .04); gland(Ct, [2.66, 4.5, .9], [0, 1, 0], .04);
  add(Ct, tubeG([[2.66, 4.62, .9], [2.7, 5.3, .9], [2.65, 5.58, .6], [1.6, 5.56, .2], [.2, 5.56, 0], [0, 5.58, 0]], .04, 10, .3), M.galv);
  gland(Ct, [0, 5.51, 0], [0, 1, 0], .07);
  add(Ct, boxG(.2, 1.25, .03), M.black, [-2.375, 4.18, 2.115]);
  sticker(Ct, label('LevelLabel', T.label('CHARGE', '#1c1c1c', '#e8e8e2')), .2, .05, [-2.375, 4.86, 2.132]);
  Lv.forEach((g, k) => add(g, boxG(.13, .22, .02), M.levels[k], [-2.375, 3.73 + k * .3, 2.135]));
  { const s = sub(Gl, [2.828, 4.2, .9]); add(s, plane(.52, .27), M.glass, [0, 0, 0], [0, PI / 2, 0]); }
  wireTop(R, 'BB_', [0, 5.7, 0]);
  return finish(R);
}

/* ================= 5. StrawGenerator ================= */
function bale(g, c, w, h, d, ry = 0) { const s = sub(g, c); s.rotation.y = ry; add(s, bboxG(w, h, d, .07), M.straw);
  for (const z of [-d / 4, d / 4]) { add(s, boxG(w + .02, .025, .025), M.dark, [0, h / 2 + .005, z]); add(s, boxG(w + .02, .025, .025), M.dark, [0, -h / 2 - .005, z]); for (const k of [-1, 1]) add(s, boxG(.025, h + .02, .025), M.dark, [k * (w / 2 + .005), 0, z]); }
  for (let i = 0; i < 230; i++) { const f = (rnd() * 3) | 0, L = rr(.12, .3); const p = f === 0 ? [rr(-w / 2, w / 2), h / 2 + .01, rr(-d / 2, d / 2)] : f === 1 ? [rr(-w / 2, w / 2), rr(-h / 2, h / 2), (rnd() < .5 ? -1 : 1) * (d / 2 + .01)] : [(rnd() < .5 ? -1 : 1) * (w / 2 + .01), rr(-h / 2, h / 2), rr(-d / 2, d / 2)];
    add(s, boxG(L, .012, .02), M.straw, p, [rr(-.3, .3), rr(0, PI), rr(-.3, .3)]); } return s; }
export function buildStraw() {
  setSeed(505); const R = root('StrawGenerator'), G = grpOf(R, 'SG_');
  const Fo = G('Foundation'), Fe = G('Feeder'), Fu = G('Furnace'), Bo = G('Boiler'), Fi = G('Filter'), Ch = G('Chimney'), En = G('Engine'), Ge = G('Generator'), Co = G('Controls'), De = G('Details'), Fire = G('Fire'), Em = G('Emissive'), Gl = G('Glass');
  const PT = .3;
  pad(Fo, 14, 12, PT, [[-6.6, -5.6], [6.6, -5.6], [-6.6, 5.6], [6.6, 5.6], [0, -5.6], [0, 5.6], [6.6, 0], [3.3, 5.6], [-3.3, -5.6]]);
  add(Fo, bboxG(5.5, .12, 5.1, .03), M.concrete, [-1.8, PT + .06, 0]); add(Fo, bboxG(5.0, .12, 3.9, .03), M.concrete, [4.3, PT + .06, 3.5]);
  // ---- feeder: chute from the IN opening, roller feeder ----
  const fy = x => 1.21 + (x + 7) * (-.25 / 1.5);
  prismXY(Fe, M.galv, [[-7, 1.21], [-5.5, .96], [-5.5, 1.0], [-7, 1.25]], -1.2, 1.2);
  for (const s of [-1, 1]) { const z0 = s > 0 ? 1.2 : -1.24; prismXY(Fe, M.teal, [[-7, 1.21], [-5.5, .96], [-5.5, 2.5], [-7, 2.7]], z0, z0 + .04);
    add(Fe, boxG(.06, 1.5, .06), M.yellow, [-6.97, 1.96, s * 1.2]); }
  add(Fe, boxG(.06, .06, 2.4), M.yellow, [-6.97, 1.24, 0]);
  for (const x of [-6.6, -5.8]) for (const s of [-1, 1]) { beam(Fe, M.galv, [x, PT + .12, s * 1.0], [x, fy(x) - .02, s * 1.0], .08, .08); add(Fe, boxG(.2, .02, .2), M.galv, [x, PT + .13, s]); }
  add(Fe, flat(1.3, 2.0), M.dust, [-6.25, fy(-6.25) + .045, 0]).rotation.z = .165;
  const hx0 = -5.5, hx1 = -4.4, hxc = -4.95;
  add(Fe, boxG(1.1, 3.0, .04), M.teal, [hxc, PT + 1.5, -1.48]); add(Fe, boxG(1.1, .04, 3.0), M.teal, [hxc, 3.28, 0]);
  add(Fe, boxG(.04, .66, 3.0), M.teal, [hx0 + .02, .63, 0]); add(Fe, boxG(.04, .8, 3.0), M.teal, [hx0 + .02, 2.9, 0]); for (const s of [-1, 1]) add(Fe, boxG(.04, 1.54, .3), M.teal, [hx0 + .02, 1.73, s * 1.35]);
  add(Fe, boxG(1.1, .8, .04), M.teal, [hxc, .7, 1.48]); add(Fe, boxG(1.1, .7, .04), M.teal, [hxc, 2.95, 1.48]); for (const s of [-1, 1]) add(Fe, boxG(.1, 1.5, .04), M.teal, [hxc + s * .5, 1.85, 1.48]);
  add(Fe, plane(1.0, 2.9), M.hole, [hxc, 1.8, -1.455]); add(Fe, plane(.9, 1.5), M.guard, [hxc, 1.85, 1.505]);
  for (const s of [-1, 1]) add(Fe, boxG(.95, .04, .04), M.yellow, [hxc, 1.85 + s * .75, 1.51]);
  for (const [x, y] of [[-4.95, 1.4], [-4.95, 2.25]]) { add(Fe, alongZ(cylG(.33, .33, 2.9, 24)), M.iron, [x, y, 0]); pipe(Fe, M.steel, [x, y, -1.72], [x, y, 1.62], .06, 10);
    for (let i = 0; i < 6; i++) for (let k = 0; k < 8; k++) { const a = k / 8 * TAU + i * .4, d = new V3(Math.cos(a), Math.sin(a), 0); orient(add(Fe, new THREE.ConeGeometry(.045, .14, 6), M.steel, [x + d.x * .38, y + d.y * .38, -1.2 + i * .48]), d); }
    for (const z of [-1.56, 1.56]) { add(Fe, bboxG(.3, .3, .12, .02), M.iron, [x, y, z]); for (const a of [-1, 1]) nut(Fe, [x + a * .1, y + .15, z], [0, 1, 0], .025, .02); } }
  add(Fe, bboxG(1.0, 2.8, .2, .03), M.yellow, [hxc, 2.5, -1.62]); for (const y of [1.3, 2.5, 3.7]) nut(Fe, [hxc + .45, y, -1.72], [0, 0, -1], .025, .02);
  add(Fe, bboxG(.5, .5, .4, .03), M.iron, [hxc, 3.55, -1.25]); add(Fe, alongZ(cylG(.28, .28, .8, 28)), M.teal, [hxc, 3.58, -.6]);
  for (let i = 0; i < 14; i++) { const a = i / 14 * PI; add(Fe, boxG(.025, .07, .7), M.teal, [hxc + Math.cos(a) * .3, 3.58 + Math.sin(a) * .3, -.6], [0, 0, a]); }
  add(Fe, latheZ([[.28, 0], [.28, .1], [.2, .15], [0, .16]], 24), M.teal, [hxc, 3.58, -.2]); add(Fe, bboxG(.2, .14, .2, .02), M.teal, [hxc, 3.9, -.7]);
  // ---- furnace ----
  const fx0 = -4.4, fx1 = .8, fxc = (fx0 + fx1) / 2, fz = 2.4, ftop = 4.6;
  add(Fu, bboxG(5.2, ftop - PT - .12, 4.8, .06), M.iron, [fxc, PT + .12 + (ftop - PT - .12) / 2, 0]); add(Fu, boxG(5.3, .2, 4.9), M.dark, [fxc, PT + .22, 0]);
  for (const y of [1.7, 3.2]) for (const s of [-1, 1]) add(Fu, boxG(5.24, .12, .05), M.iron, [fxc, y, s * (fz + .025)]);
  for (const x of [-4.0, -3.0, -.1, .5]) for (const s of [-1, 1]) { add(Fu, boxG(.1, 4.1, .05), M.iron, [x, 2.45, s * (fz + .03)]); for (const y of [1.7, 3.2]) nut(Fu, [x, y, s * (fz + .055)], [0, 0, s], .035, .025); }
  for (const x of [fx0 + .1, fx1 - .1]) for (const z of [-fz + .1, fz - .1]) add(Fu, new THREE.TorusGeometry(.09, .025, 6, 16), M.iron, [x, ftop + .08, z]);
  const dx = -1.6, dyy = 2.65;
  add(Fu, boxG(1.5, .25, .08), M.brick, [dx, dyy + .625, fz + .04]); add(Fu, boxG(1.5, .25, .08), M.brick, [dx, dyy - .625, fz + .04]); for (const s of [-1, 1]) add(Fu, boxG(.25, 1.0, .08), M.brick, [dx + s * .625, dyy, fz + .04]);
  add(Fu, bboxG(.96, .96, .07, .02), M.iron, [dx, dyy, fz + .12]); for (const s of [-1, 1]) { add(Fu, boxG(.8, .05, .03), M.iron, [dx, dyy + s * .3, fz + .17]); add(Fu, boxG(.05, .8, .03), M.iron, [dx + s * .3, dyy, fz + .17]); }
  for (const y of [dyy - .3, dyy + .3]) { add(Fu, cylG(.04, .04, .18, 12), M.iron, [dx - .52, y, fz + .12]); add(Fu, boxG(.12, .14, .03), M.iron, [dx - .45, y, fz + .12]); }
  beam(Fu, M.iron, [dx + .42, dyy - .1, fz + .18], [dx + .42, dyy + .25, fz + .18], .05, .04); pipe(Fu, M.timber, [dx + .42, dyy + .02, fz + .2], [dx + .42, dyy + .02, fz + .38], .035, 10);
  add(Fu, new THREE.TorusGeometry(.15, .03, 8, 28), M.brass, [dx, dyy, fz + .16]); add(Fire, new THREE.CircleGeometry(.14, 28), M.fire, [dx, dyy, fz + .158]); add(Gl, new THREE.CircleGeometry(.145, 28), M.glass, [dx, dyy, fz + .17]);
  add(Fire, plane(1.02, 1.02), M.fire, [dx, dyy, fz + .085]);
  add(Fu, bboxG(1.1, .6, .06, .02), M.iron, [dx, .95, fz + .04]); for (let i = 0; i < 3; i++) add(Fire, plane(.1, .32), M.coal, [dx - .25 + i * .25, .95, fz + .072]);
  add(Fu, boxG(.75, .1, .02), M.iron, [dx + .1, 1.2, fz + .08]); pipe(Fu, M.steel, [dx + .5, 1.2, fz + .09], [dx + .62, 1.2, fz + .09], .02, 8);
  for (const s of [-1, 1]) add(Fu, cylG(.035, .035, .14, 10), M.iron, [dx - .58, .95 + s * .16, fz + .04]);
  sticker(Fu, label('SignHot', T.hot), .4, .4, [-.4, 3.0, fz + .056]); add(Fu, plane(1.5, .9), M.soot, [dx, dyy + .95, fz + .057]);
  for (const x of [-3.5, .2, -2.6]) add(Fu, plane(.5, 2.0), M.rust, [x, 3.5, fz + .057]); add(Fu, plane(.6, 2.2), M.rust, [-2.2, 3.4, -fz - .057], [0, PI, 0]);
  // ---- boiler ----
  const bx0 = -4.2, bx1 = .8, bL = bx1 - bx0, bcx = (bx0 + bx1) / 2, by = 6.3, bR = 1.55;
  add(Bo, alongX(cylG(bR, bR, bL, 80, true)), M.lag, [bcx, by, 0]);
  add(Bo, latheX([[bR, 0], [bR - .04, .1], [bR - .25, .24], [.9, .34], [0, .38]], 64).rotateY(PI), M.lag, [bx0, by, 0]);
  for (let i = 0; i < 7; i++) { const x = bx0 + .35 + i * (bL - .7) / 6; add(Bo, new THREE.TorusGeometry(bR + .012, .022, 6, 80).rotateY(PI / 2), M.steel, [x, by, 0]); add(Bo, boxG(.08, .06, .1), M.steel, [x, by + bR + .03, 0]); nut(Bo, [x, by + bR + .06, .04], [0, 1, 0], .02, .02); }
  for (const x of [-3.5, -.1]) { const s = new THREE.Shape(); s.moveTo(-1.3, ftop); s.lineTo(1.3, ftop); s.lineTo(1.3, 5.42); s.absarc(0, by, 1.57, -.595, -2.546, true); s.closePath(); prismZY(Bo, M.iron, s, x - .1, x + .1);
    add(Bo, boxG(.5, .04, 2.8), M.iron, [x, ftop + .02, 0]); for (const z of [-1.2, -.4, .4, 1.2]) nut(Bo, [x + .17, ftop + .04, z], [0, 1, 0], .035, .03); }
  const top = by + bR;
  add(Bo, cylG(.25, .25, .08, 24), M.iron, [-.6, top + .02, 0]); add(Bo, new THREE.SphereGeometry(.22, 20, 12), M.iron, [-.6, top + .27, 0]); add(Bo, cylG(.1, .13, .2, 16), M.iron, [-.6, top + .52, 0]);
  add(Bo, cylG(.02, .02, .26, 8), M.steel, [-.6, top + .7, 0]); add(Bo, new THREE.TorusGeometry(.25, .03, 8, 28).rotateX(PI / 2), M.red, [-.6, top + .8, 0]);
  for (let i = 0; i < 4; i++) add(Bo, boxG(.5, .02, .03), M.red, [-.6, top + .8, 0], [0, i * PI / 4, 0]);
  boltRing(Bo, [-.6, top + .06, 0], [0, 1, 0], .2, 8, .025, .02);
  duct(Bo, M.lag, [[-.38, top + .27, 0], [2.9, top + .27, 0], [2.9, top + .27, 3.5], [2.9, 3.05, 3.5]], .13, .4, 24, 10);
  for (const p of [[-.36, top + .27, 0, 1, 0, 0], [2.9, 3.08, 3.5, 0, -1, 0]]) add(Bo, cylG(.2, .2, .05, 24), M.iron, [p[0], p[1], p[2]]).quaternion.setFromUnitVectors(YUP, new V3(p[3], p[4], p[5]));
  add(Bo, boxG(.12, top + .1 - 7.9, .12), M.galv, [1.95, 7.9 + (top + .1 - 7.9) / 2, 0]); beam(Bo, M.galv, [1.95, 7.9, 3.5], [2.75, 7.9, 3.5], .1, .1);
  add(Bo, cylG(.17, .19, .06, 20), M.iron, [-2.8, top + .03, 0]); add(Bo, cylG(.12, .14, .4, 20), M.iron, [-2.8, top + .26, 0]);
  beam(Bo, M.steel, [-2.75, top + .47, 0], [-3.75, top + .47, 0], .05, .05); add(Bo, new THREE.SphereGeometry(.14, 16, 10), M.iron, [-3.6, top + .47, 0]);
  add(Bo, boxG(.08, .25, .06), M.iron, [-2.66, top + .38, 0]); pipe(Bo, M.iron, [-2.8, top + .46, 0], [-2.8, top + 1.15, 0], .06, 12); pipe(Bo, M.iron, [-2.8, top + 1.12, 0], [-2.6, top + 1.12, 0], .055, 12);
  { const z1 = Math.sqrt(bR * bR - .36); pipe(Bo, M.steel, [-3.6, 6.9, z1 - .02], [-3.6, 6.9, 1.75], .025, 8); add(Bo, new THREE.TorusGeometry(.08, .015, 6, 16).rotateY(PI / 2), M.steel, [-3.6, 7.0, 1.75]); pipe(Bo, M.steel, [-3.6, 7.08, 1.75], [-3.6, 7.42, 1.75], .02, 8);
    add(Bo, alongZ(cylG(.22, .22, .1, 36)), M.dark, [-3.6, 7.62, 1.8]); add(Bo, new THREE.TorusGeometry(.215, .02, 6, 36), M.brass, [-3.6, 7.62, 1.85]);
    dialFace(Bo, 'DialP', T.dial('bar', 16, .8), [-3.6, 7.62, 1.851], .2, [0, 0, 1], Gl); }
  for (const y of [5.75, 6.95]) { const z1 = Math.sqrt(bR * bR - (y - by) ** 2); pipe(Bo, M.steel, [-2.3, y, z1 - .02], [-2.3, y, 1.8], .05, 10); add(Bo, bboxG(.14, .14, .14, .02), M.brass, [-2.3, y, 1.8]); pipe(Bo, M.red, [-2.3, y, 1.86], [-2.12, y, 1.86], .02, 8); }
  add(Gl, cylG(.04, .04, 1.06, 16), M.glass, [-2.3, 6.35, 1.8]); add(Bo, cylG(.03, .03, .5, 12), M.water, [-2.3, 6.08, 1.8]);
  for (let i = 0; i < 3; i++) { const a = i / 3 * TAU; pipe(Bo, M.steel, [-2.3 + .08 * Math.cos(a), 5.82, 1.8 + .08 * Math.sin(a)], [-2.3 + .08 * Math.cos(a), 6.88, 1.8 + .08 * Math.sin(a)], .008, 6); }
  pipe(Bo, M.steel, [-2.3, 5.68, 1.8], [-2.3, 5.3, 1.8], .02, 8);
  add(Bo, bboxG(.8, 7.6, 2.5, .04), M.iron, [1.2, PT + 3.8, 0]);
  add(Bo, latheX([[0, 0], [.95, 0], [.95, .05], [.85, .12], [.5, .18], [0, .2]], 56), M.iron, [1.6, by, 0]);
  for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; add(Bo, boxG(.1, .12, .08), M.steel, [1.66, by + .98 * Math.cos(a), .98 * Math.sin(a)], [a, 0, 0]); }
  pipe(Bo, M.steel, [1.8, by, 0], [1.95, by, 0], .05, 12); add(Bo, boxG(.04, .6, .05), M.steel, [1.96, by, 0]);
  add(Bo, bboxG(.06, .7, 1.0, .02), M.iron, [1.62, 1.4, 0]); for (const s of [-1, 1]) add(Bo, boxG(.04, .06, .14), M.steel, [1.66, 1.4, s * .3]);
  add(Bo, plane(.7, 2.2), M.rust, [1.605, 3.6, .7], [0, PI / 2, 0]);
  // ---- cyclone + bag filter ----
  const ccx = 1.9, ccz = -3.7, cr = .75;
  add(Fi, cylG(cr, cr, 2.2, 56), M.teal, [ccx, 6.3, ccz]); add(Fi, cylG(cr, .18, 1.6, 56, true), M.teal, [ccx, 4.4, ccz]); pipe(Fi, M.teal, [ccx, 3.6, ccz], [ccx, 3.1, ccz], .18, 20);
  add(Fi, bboxG(.5, .4, .5, .03), M.iron, [ccx, 2.9, ccz]); add(Fi, alongX(cylG(.12, .12, .3, 16)), M.teal, [ccx + .4, 2.9, ccz]); pipe(Fi, M.galv, [ccx, 2.7, ccz], [ccx, 1.3, ccz], .12, 16);
  add(Fi, cylG(.42, .42, .95, 32), M.galv, [ccx, PT + .5, ccz]); add(Fi, cylG(.44, .44, .05, 32), M.galv, [ccx, PT + .98, ccz]);
  for (let y = .45; y < 1.2; y += .3) add(Fi, new THREE.TorusGeometry(.425, .012, 4, 32).rotateX(PI / 2), M.galv, [ccx, y + PT, ccz]);
  add(Fi, new THREE.TorusGeometry(.79, .04, 6, 48).rotateX(PI / 2), M.galv, [ccx, 5.35, ccz]);
  for (let i = 0; i < 4; i++) { const a = PI / 4 + i * PI / 2, x = ccx + .8 * Math.cos(a), z = ccz + .8 * Math.sin(a); beam(Fi, M.galv, [x, PT, z], [x, 5.4, z], .1, .1); add(Fi, boxG(.24, .02, .24), M.galv, [x, PT + .01, z]); anchor(Fi, x + .08, PT + .02, z); }
  for (let i = 0; i < 4; i++) { const a0 = PI / 4 + i * PI / 2, a1 = a0 + PI / 2; beam(Fi, M.galv, [ccx + .8 * Math.cos(a0), 1.0, ccz + .8 * Math.sin(a0)], [ccx + .8 * Math.cos(a1), 2.4, ccz + .8 * Math.sin(a1)], .04, .04); }
  add(Fi, boxG(.35, .6, 2.05), M.teal, [ccx - cr + .18, 7.0, (-1.25 - 3.3) / 2]); for (const z of [-1.3, -2.6]) add(Fi, boxG(.43, .68, .05), M.teal, [ccx - cr + .18, 7.0, z]);
  duct(Fi, M.teal, [[ccx, 7.4, ccz], [ccx, 8.15, ccz], [3.6, 8.15, ccz], [3.6, 7.62, ccz]], .25, .3, 32, 10);
  add(Fi, bboxG(2.6, 3.4, 3.6, .04), M.teal, [4.3, 5.9, -3.8]); add(Fi, frustumG(.5, .5, 2.6, 3.6, 1.2), M.teal, [4.3, 3.6, -3.8]);
  add(Fi, bboxG(.5, .4, .5, .03), M.iron, [4.3, 2.8, -3.8]); add(Fi, alongZ(cylG(.12, .12, .3, 16)), M.teal, [4.3, 2.8, -3.35]); pipe(Fi, M.galv, [4.3, 2.6, -3.8], [4.3, 1.45, -3.8], .12, 16); add(Fi, cylG(.42, .42, 1.05, 32), M.galv, [4.3, PT + .55, -3.8]);
  for (const [x, z] of [[3.08, -2.08], [5.52, -2.08], [3.08, -5.52], [5.52, -5.52]]) { add(Fi, boxG(.14, 4.2 - PT, .14), M.galv, [x, PT + (4.2 - PT) / 2, z]); add(Fi, boxG(.3, .02, .3), M.galv, [x, PT + .01, z]); anchor(Fi, x, PT + .02, z + (z > -3 ? -.1 : .1)); }
  for (const z of [-2.08, -5.52]) beam(Fi, M.galv, [3.08, 1.2, z], [5.52, 3.6, z], .05, .05);
  for (const x of [3.5, 4.3, 5.1]) for (const z of [-1.97, -5.63]) add(Fi, boxG(.08, 3.4, .06), M.teal, [x, 5.9, z]);
  for (const z of [-4.6, -3.0]) for (const x of [2.97, 5.63]) add(Fi, boxG(.06, 3.4, .08), M.teal, [x, 5.9, z]);
  for (const s of [-1, 1]) { add(Fi, boxG(2.72, .08, .06), M.teal, [4.3, 5.9, -3.8 + s * 1.83]); add(Fi, boxG(.06, .08, 3.72), M.teal, [4.3 + s * 1.33, 5.9, -3.8]); }
  add(Fi, boxG(2.7, .06, 3.7), M.teal, [4.3, 7.63, -3.8]);
  for (const x of [3.55, 5.05]) { add(Fi, bboxG(.7, .08, .6, .02), M.teal, [x, 7.7, -2.9]); add(Fi, new THREE.TorusGeometry(.06, .015, 6, 12), M.steel, [x, 7.78, -2.9]); for (const a of [-1, 1]) for (const b of [-1, 1]) nut(Fi, [x + a * .28, 7.74, -2.9 + b * .23], [0, 1, 0], .025, .02); }
  pipe(Fi, M.galv, [3.1, 7.98, -5.1], [5.5, 7.98, -5.1], .12, 20); for (const x of [3.2, 5.4]) add(Fi, boxG(.08, .3, .08), M.galv, [x, 7.8, -5.1]);
  for (let i = 0; i < 6; i++) { const x = 3.35 + i * .38; add(Fi, cylG(.09, .09, .14, 16), M.dark, [x, 7.78, -4.85]); add(Fi, bboxG(.1, .08, .12, .01), M.black, [x, 7.9, -4.7]); pipe(Fi, M.galv, [x, 7.9, -5.0], [x, 7.82, -4.9], .03, 8); }
  add(Fi, tubeG([[3.35, 7.95, -4.62], [4.3, 8.0, -4.6], [5.3, 7.95, -4.62]], .02, 6), M.cable);
  pipe(Fi, M.teal, [4.0, 6.6, -2.0], [4.0, 6.6, -.45], .3, 32); for (const z of [-2.04, -1.0]) add(Fi, alongZ(cylG(.38, .38, .05, 32)), M.teal, [4.0, 6.6, z]);
  boltRing(Fi, [4.0, 6.6, -1.0], [0, 0, 1], .34, 10, .025, .02);
  sticker(Fi, label('FilterPlate', T.namePlate('BAG FILTER', 'PM2.5 < 30 mg/Nm³', 'Pulse-jet · 48 bags', '#d9dcd6', '#1f6f6c')), .8, .4, [4.3, 5.2, -1.94]);
  // ---- chimney: top at (4, 12, 0) ----
  const chx = 4, chr = .5;
  add(Ch, cylG(chr, .8, .8, 48, true), M.galv, [chx, PT + .4, 0]); add(Ch, cylG(.95, .95, .05, 48), M.galv, [chx, PT + .025, 0]);
  for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; nut(Ch, [chx + .87 * Math.cos(a), PT + .05, .87 * Math.sin(a)], [0, 1, 0], .04, .04); }
  add(Ch, cylG(chr, chr, 12 - 1.1, 56, true), M.galv, [chx, 1.1 + (12 - 1.1) / 2, 0]);
  add(Ch, cylG(chr - .04, chr - .04, 1.2, 56, true), M.holeBack, [chx, 11.4, 0]); add(Ch, new THREE.RingGeometry(chr - .04, chr, 56).rotateX(-PI / 2), M.galv, [chx, 12, 0]);
  for (const y of [3.4, 5.7, 8.0, 10.3]) { add(Ch, revolve(ringProf(chr, chr + .07, .06, .01), 56), M.galv, [chx, y, 0]); boltRing(Ch, [chx, y + .03, 0], [0, 1, 0], chr + .035, 12, .022, .02); }
  for (let i = 0; i < 3; i++) { const a = i / 3 * TAU + PI / 6; add(Ch, boxG(.2, .25, .03), M.galv, [chx + .56 * Math.cos(a), 9.0, .56 * Math.sin(a)], [0, -a, 0]).rotation.y = -a + PI / 2; }
  add(Ch, bboxG(.06, .5, .4, .02), M.galv, [chx + .5, 1.6, 0]); for (const s of [-1, 1]) add(Ch, boxG(.04, .06, .1), M.steel, [chx + .54, 1.6 + s * .15, 0]);
  add(Ch, cylG(chr + .004, chr + .004, .9, 56, true), M.sootCh, [chx, 11.55, 0]);
  add(Ch, alongZ(cylG(.38, .38, .06, 32)), M.galv, [chx, 6.6, -.5]);
  // ---- engine: steam turbine, coupling ----
  for (const z of [1.8, 5.2]) add(En, boxG(4.8, .25, .2), M.dark, [4.3, PT + .245, z]); for (const x of [2.0, 4.0, 6.5]) add(En, boxG(.2, .25, 3.2), M.dark, [x, PT + .245, 3.5]);
  add(En, boxG(4.8, .03, 3.6), M.galv, [4.3, .565, 3.5]);
  add(En, latheX([[.25, -.75], [.5, -.68], [.72, -.45], [.8, -.15], [.8, .15], [.72, .45], [.5, .68], [.25, .75]], 56), M.engine, [2.9, 1.75, 3.5]);
  add(En, boxG(1.4, .05, 1.72), M.engine, [2.9, 1.75, 3.5]); for (let i = 0; i < 7; i++) for (const s of [-1, 1]) nut(En, [2.3 + i * .2, 1.775, 3.5 + s * .83], [0, 1, 0], .03, .03);
  for (const x of [2.4, 3.4]) add(En, bboxG(.25, .66, 1.2, .02), M.engine, [x, .91, 3.5]);
  pipe(En, M.steel, [3.65, 1.75, 3.5], [4.3, 1.75, 3.5], .1, 16);
  add(En, alongX(cylG(.32, .32, .55, 24, true, PI, PI)), M.yellow, [3.97, 1.75, 3.5]); for (const x of [3.7, 4.24]) add(En, alongX(cylG(.32, .32, .02, 24, false, PI, PI)), M.yellow, [x, 1.75, 3.5]);
  for (const s of [-1, 1]) add(En, plane(.55, .5), M.guard, [3.97, 1.5, 3.5 + s * .32]);
  add(En, boxG(.55, .03, .7), M.yellow, [3.97, 1.25, 3.5]); add(En, boxG(.06, .7, .06), M.yellow, [3.97, .9, 3.2]);
  add(En, bboxG(.5, .35, .5, .03), M.iron, [2.9, 2.72, 3.5]); add(En, alongZ(cylG(.1, .1, .35, 16)), M.iron, [2.9, 2.72, 3.9]); add(En, bboxG(.18, .2, .18, .02), M.black, [2.9, 2.75, 4.15]);
  pipe(En, M.iron, [2.9, 1.5, 2.78], [2.9, 1.5, 2.15], .14, 16); add(En, new THREE.SphereGeometry(.14, 14, 8), M.iron, [2.9, 1.5, 2.15]); pipe(En, M.iron, [2.9, 1.5, 2.15], [2.9, 1.06, 2.15], .14, 16);
  add(En, bboxG(1.2, .5, .5, .03), M.engine, [2.9, .83, 2.05]); add(En, cylG(.06, .06, .1, 10), M.steel, [3.3, 1.12, 2.05]);
  sticker(En, label('TurbinePlate', T.namePlate('STEAM TURBINE', '18 bar · 210 °C', '3000 rpm · 22 kW', '#c9ccc8', '#222')), .5, .25, [2.9, 2.05, 4.215]).rotation.x = -.35;
  add(En, bboxG(.9, .08, .5, .02), M.galv, [.45, PT + .16, 3.4]); add(En, alongX(cylG(.22, .22, .6, 24)), M.teal, [.25, .62, 3.4]); add(En, latheX([[0, 0], [.25, 0], [.25, .12], [0, .14]], 20), M.iron, [.55, .62, 3.4]);
  duct(En, M.steel, [[.62, .62, 3.4], [.62, .62, 2.6], [.62, 5.9, 2.6], [.62, 5.9, Math.sqrt(bR * bR - .16) - .02]], .05, .15, 10, 6);
  add(En, bboxG(.14, .14, .14, .02), M.brass, [.62, 5.9, 2.05]);
  // ---- generator ----
  const gx = 5.25, gy = 1.75, gz = 3.5;
  add(Ge, alongX(cylG(.85, .85, 1.6, 56)), M.teal, [gx, gy, gz]);
  for (let i = 0; i < 40; i++) { const a = i / 40 * TAU; if (Math.cos(a) < -.6) continue; add(Ge, boxG(1.5, .12, .03), M.teal, [gx, gy + .9 * Math.cos(a), gz + .9 * Math.sin(a)], [a, 0, 0]); }
  add(Ge, latheX([[0, 0], [.35, 0], [.6, .08], [.82, .2]], 48), M.teal, [4.25, gy, gz]);
  add(Ge, latheX([[.85, 0], [.85, .25], [.75, .35], [0, .38]], 48), M.teal, [6.05, gy, gz]);
  for (let i = 0; i < 12; i++) { const a = i / 12 * TAU; add(Ge, boxG(.02, .05, .3), M.hole, [6.33, gy + .45 * Math.cos(a), gz + .45 * Math.sin(a)], [a, 0, 0]); }
  for (const x of [4.7, 5.8]) { add(Ge, bboxG(.3, .7, 1.5, .03), M.teal, [x, .91, gz]); for (const s of [-1, 1]) nut(Ge, [x, .58, gz + s * .65], [0, 1, 0], .035, .03); }
  add(Ge, bboxG(.55, .4, .5, .03), M.teal, [gx, 2.75, gz]); gland(Ge, [gx, 2.95, gz], [0, 1, 0], .05);
  sticker(Ge, label('GenPlate', T.namePlate('COOP STRAW POWER', '15 kW · 400/230 V · 50 Hz', '3-phase · IP23 · 2026', '#c9ccc8', '#1f6f6c')), .5, .25, [gx, 2.75, gz + .252]);
  add(Ge, new THREE.TorusGeometry(.09, .025, 6, 16), M.steel, [gx - .5, 2.66, gz]);
  // ---- controls ----
  add(Co, boxG(1.85, .1, .65), M.concrete, [5.85, PT + .05, -1.3]); add(Co, bboxG(1.8, 2.6, .6, .03), M.teal, [5.85, 1.7, -1.3]);
  for (const [x, tex, p] of [[5.4, T.dial('A', 40, .75), 'DialA'], [6.3, T.dial('V', 500, .85), 'DialV']]) { add(Co, bboxG(.42, .42, .06, .02), M.black, [x, 2.45, -.97]); sticker(Co, label(p, tex), .34, .34, [x, 2.45, -.938]); sticker(Gl, M.glass, .36, .36, [x, 2.45, -.934]); }
  for (const [x, m] of [[5.6, M.emR], [6.1, M.emG]]) { add(Co, alongZ(cylG(.08, .08, .04, 18)), M.steel, [x, 1.95, -.98]); add(Em, latheZ([[0, 0], [.06, 0], [.06, .02], [0, .04]], 16), m, [x, 1.95, -.96]); }
  add(Co, alongZ(cylG(.07, .07, .05, 16)), M.black, [5.85, 1.6, -.98]); add(Co, boxG(.03, .1, .03), M.steel, [5.85, 1.6, -.945]);
  add(Co, alongZ(cylG(.11, .11, .03, 18)), M.yellow, [6.4, 1.55, -.985]); add(Co, latheZ([[0, 0], [.08, 0], [.09, .04], [.08, .08], [0, .09]], 18), M.red, [6.4, 1.55, -.97]);
  add(Co, boxG(.05, .3, .05), M.steel, [5.0, 1.7, -.98]); for (const y of [.9, 2.5]) add(Co, cylG(.03, .03, .2, 8), M.steel, [6.75, y, -.98]);
  sticker(Co, label('SignHV', T.signHV), .52, .39, [5.85, 1.0, -.998]);
  add(Co, tubeG([[gx, 3.0, gz], [gx, 3.3, gz], [gx, 3.35, 2.5], [5.3, 3.35, -.8], [5.4, 3.3, -1.3], [5.4, 3.0, -1.3]], .045, 8, .2), M.galv);
  add(Co, tubeG([[6.3, 3.0, -1.4], [6.3, 3.3, -1.5], [5.95, 3.4, -2.3], [5.72, 3.9, -2.6], [5.72, 7.45, -2.8], [5.35, 7.75, -3.6], [4.3, 7.76, -3.98], [4.05, 7.9, -4.0]], .04, 8, .25), M.cable);
  for (const y of [4.6, 5.6, 6.6]) add(Co, boxG(.06, .06, .1), M.steel, [5.68, y, -2.7]);
  add(Co, cylG(.05, .05, .18, 10), M.galv, [4, 7.75, -4]); add(Co, revolve([[.03, 0], [.09, 0], [.11, .05], [.11, .09], [.07, .12], [.07, .19], [.1, .22], [.1, .26], [.05, .3], [0, .31]], 24), M.porcelain, [4, 7.78, -4]);
  // ---- details ----
  { const s = sub(De, [-3.1, 0, 4.4]); add(s, frustumG(.9, .6, 1.3, 1.0, .45), M.galv, [0, .97, 0]); add(s, new THREE.SphereGeometry(.55, 20, 12), M.ash, [0, 1.2, 0], [0, 0, 0], [1.1, .4, .82]);
    for (let i = 0; i < 9; i++) add(s, new THREE.DodecahedronGeometry(rr(.04, .09)), M.ash, [rr(-.5, .5), rr(1.22, 1.38), rr(-.35, .35)]);
    add(s, new THREE.TorusGeometry(.22, .07, 10, 24), M.rubber, [.85, PT + .29, 0]); pipe(s, M.steel, [.85, PT + .29, -.12], [.85, PT + .29, .12], .025, 8);
    for (const z of [-.35, .35]) { pipe(s, M.galv, [.85, PT + .29, z * .4], [-.4, .8, z], .03, 8); pipe(s, M.galv, [-.4, .8, z], [-1.2, 1.0, z], .03, 8); pipe(s, M.timber, [-1.0, .96, z], [-1.25, 1.02, z], .045, 8); pipe(s, M.galv, [-.4, .8, z], [-.45, PT, z], .025, 8); } }
  add(De, flat(2.2, 1.4), M.soot, [-2.6, PT + .004, 3.4]); add(De, flat(1.6, 2.4), M.dust, [-6.2, PT + .004, -.2]);
  bale(De, [-6.25, PT + .4, -3.2], .9, .8, 1.6); bale(De, [-6.25, PT + .4, -4.9], .9, .8, 1.6); bale(De, [-6.25, PT + 1.2, -4.05], .9, .8, 1.6, .08);
  add(De, flat(1.6, 3.6), M.dust, [-6.2, PT + .005, -4.0]);
  wireTop(R, 'SG_', [4, 8, -4]);
  return finish(R);
}

/* ================= 6. DieselGenerator ================= */
export function buildDiesel() {
  setSeed(606); const R = root('DieselGenerator'), G = grpOf(R, 'DG_');
  const Sk = G('Skid'), Ca = G('Canopy'), En = G('Engine'), Al = G('Alternator'), Ra = G('Radiator'), Ex = G('Exhaust'), Fl = G('Flap'), Co = G('Controls'), De = G('Details'), Em = G('Emissive'), Gl = G('Glass');
  for (const s of [-1, 1]) { add(Sk, boxG(11.6, .45, .24), M.skid, [0, .225, s * 3.3]); for (const x of [-2.3, 2.3]) add(Sk, plane(.9, .24), M.hole, [x, .2, s * 3.421], [0, s > 0 ? 0 : PI, 0]); }
  for (const s of [-1, 1]) add(Sk, boxG(.12, .45, 6.84), M.skid, [s * 5.74, .225, 0]);
  add(Sk, bboxG(11.2, .4, 6.3, .04), M.skid, [0, .22, 0]);
  for (const a of [-1, 1]) for (const b of [-1, 1]) { add(Sk, boxG(.3, .3, .03), M.skid, [a * 5.5, .6, b * 3.43]); add(Sk, new THREE.TorusGeometry(.07, .025, 6, 14), M.steel, [a * 5.5, .66, b * 3.45]); }
  add(Sk, cylG(.1, .1, .2, 16), M.skid, [-5.5, .52, 1.9]); add(Sk, cylG(.13, .13, .06, 18), M.red, [-5.5, .65, 1.9]); add(Sk, tubeG([[-5.4, .65, 1.95], [-5.3, .5, 2.0], [-5.35, .45, 2.05]], .008, 4), M.steel);
  add(Sk, cylG(.14, .14, .05, 28), M.dark, [-5.5, .445, 2.6]); dialFace(Sk, 'DialFuel', T.dial('FUEL', 8, .0), [-5.5, .471, 2.6], .12, [0, 1, 0], Gl);
  sticker(Sk, label('DieselLabel', T.label('DIESEL ONLY', '#e3ae12')), .5, .125, [-5.5, .426, 2.2]).rotation.x = -PI / 2;
  add(Sk, flat(.5, .5), M.oil, [-5.5, .423, 1.95]); add(Sk, cylG(.05, .05, .04, 6), M.steel, [3.0, .04, 3.17]);
  // canopy
  const cy0 = .45, cy1 = 6.2, ch = cy1 - cy0, cz = 3.3;
  for (const a of [-1, 1]) for (const b of [-1, 1]) add(Ca, boxG(.1, ch, .1), M.canopy, [a * 5.25, cy0 + ch / 2, b * 3.25]);
  for (const b of [-1, 1]) for (const y of [.5, 6.15]) add(Ca, boxG(10.6, .1, .1), M.canopy, [0, y, b * 3.25]);
  for (const a of [-1, 1]) for (const y of [.5, 6.15]) add(Ca, boxG(.1, .1, 6.6), M.canopy, [a * 5.25, y, 0]);
  add(Ca, boxG(10.4, 5.55, .04), M.canopy, [0, 3.325, -3.28]);
  for (const x of [-2.6, 0, 2.6]) add(Ca, boxG(.02, 5.5, .02), M.hole, [x, 3.325, -3.305]);
  for (const x of [-3.9, -1.3, 1.3, 3.9]) { louvre(Ca, [x, 1.9, -3.3], 1.6, 1.4, [0, -1]); louvre(Ca, [x, 4.9, -3.3], 1.6, 1.2, [0, -1]);
    for (const y of [1.2, 5.3]) add(Ca, cylG(.03, .03, .22, 10), M.steel, [x - 1.25, y, -3.33]); add(Ca, boxG(.06, .2, .04), M.steel, [x + 1.1, 3.4, -3.32]); add(Ca, cylG(.025, .025, .08, 8).rotateX(PI / 2), M.dark, [x + 1.1, 3.4, -3.36]); }
  // +Z: panel A with window, opening, panel C with folded door
  add(Ca, boxG(.6, 5.55, .04), M.canopy, [-4.9, 3.325, 3.28]); add(Ca, boxG(3.1, 5.55, .04), M.canopy, [-2.05, 3.325, 3.28]);
  add(Ca, boxG(1.0, 2.65, .04), M.canopy, [-4.1, 1.875, 3.28]); add(Ca, boxG(1.0, 1.95, .04), M.canopy, [-4.1, 5.175, 3.28]);
  for (const s of [-1, 1]) { add(Ca, boxG(1.08, .05, .06), M.rubber, [-4.1, 3.7 + s * .52, 3.29]); add(Ca, boxG(.05, 1.08, .06), M.rubber, [-4.1 + s * .52, 3.7, 3.29]); }
  add(Gl, plane(1.0, 1.0), M.glass, [-4.1, 3.7, 3.285]);
  louvre(Ca, [-2.05, 1.6, 3.3], 2.4, 1.2, [0, 1]);
  for (const x of [-.45, 2.4]) add(Ca, boxG(.1, ch, .1), M.canopy, [x, cy0 + ch / 2, 3.25]);
  add(Ca, boxG(2.85, 5.55, .04), M.canopy, [3.825, 3.325, 3.28]);
  add(Ca, boxG(2.8, 5.4, .03), M.canopy, [3.85, 3.3, 3.365]); add(Ca, boxG(2.5, 5.1, .03), M.dark, [3.85, 3.3, 3.39]); add(Ca, plane(2.5, 5.1), M.foam, [3.85, 3.3, 3.406]); for (const y of [1.6, 3.3, 5.0]) add(Ca, boxG(2.5, .06, .04), M.canopy, [3.85, y, 3.41]);
  for (const y of [1.3, 3.3, 5.3]) { add(Ca, cylG(.035, .035, .25, 12), M.steel, [2.43, y, 3.36]); add(Ca, boxG(.08, .22, .03), M.steel, [2.47, y, 3.35]); }
  add(Ca, boxG(.05, .2, .04), M.steel, [5.1, 3.3, 3.43]);
  // -X end, +X radiator grille, roof
  add(Ca, boxG(.04, 5.55, 6.4), M.canopy, [-5.28, 3.325, 0]); for (const z of [-1.6, 1.6]) louvre(Ca, [-5.3, 3.4, z], 2.2, 3.6, [-1, 0]);
  add(Ca, boxG(.04, .6, 6.4), M.canopy, [5.28, 5.85, 0]); add(Ca, boxG(.04, .45, 6.4), M.canopy, [5.28, .725, 0]); for (const s of [-1, 1]) add(Ca, boxG(.04, 4.6, .6), M.canopy, [5.28, 3.25, s * 2.9]);
  for (let i = 0; i < 30; i++) add(Ca, boxG(.1, .035, 5.2), M.canopy, [5.3, 1.0 + i * .152, 0], [0, 0, .5]);
  for (const z of [-1.3, 1.3]) add(Ca, boxG(.12, 4.6, .05), M.canopy, [5.3, 3.25, z]);
  add(Ca, bboxG(10.8, .08, 6.8, .03), M.canopy, [0, 6.24, 0]); for (const z of [-1.7, 0, 1.7]) add(Ca, boxG(10.6, .03, .06), M.canopy, [0, 6.295, z]);
  for (const a of [-1, 1]) for (const b of [-1, 1]) { add(Ca, boxG(.3, .25, .04), M.canopy, [a * 4.6, 6.4, b * 2.6]); add(Ca, new THREE.TorusGeometry(.09, .03, 8, 18), M.steel, [a * 4.6, 6.44, b * 2.6]); }
  add(Ca, cylG(.32, .36, .1, 28), M.galv, [-4, 6.33, 0]); add(Ca, flat(2.6, 2.6), M.soot, [-4, 6.283, 0]); add(Ca, flat(3.0, 1.4), M.soot, [-3.6, 6.284, .2]);
  add(Ca, plane(.6, 2.2), M.rust, [-5.31, 2.2, -2.6], [0, -PI / 2, 0]);
  sticker(Ca, label('SignHV', T.signHV), .9, .675, [-2.05, 4.75, 3.303]);
  sticker(Ca, label('Nameplate', T.namePlate('COOP GENSET', '20 kVA · 16 kW · 400/230 V', '50 Hz · 1500 rpm · S/N 2026-0193', '#d9dcd6', '#1e201f')), 1.0, .5, [-2.05, 3.7, 3.303]);
  gland(Ca, [3, 6.28, 0], [0, 1, 0], .05);
  for (const b of [-1, 1]) for (const y of [.5, 6.15]) for (let x = -5.0; x <= 5.01; x += .5) { if (b > 0 && x > -.45 && x < 2.4) continue; nut(Ca, [x, y, b * 3.3], [0, 0, b], .025, .02); }
  for (const a of [-1, 1]) for (const b of [-1, 1]) for (let y = 1.0; y < 6; y += .5) nut(Ca, [a * 5.25, y, b * 3.3], [0, 0, b], .025, .02);
  for (let x = -5.2; x <= 5.21; x += .4) for (const b of [-1, 1]) nut(Ca, [x, 6.28, b * 3.3], [0, 1, 0], .025, .02);
  for (let z = -3.0; z <= 3.01; z += .4) for (const a of [-1, 1]) nut(Ca, [a * 5.32, 6.28, z], [0, 1, 0], .025, .02);
  // engine
  for (const x of [-3.5, -1.2, 1.0, 2.8]) for (const s of [-1, 1]) add(En, cylG(.12, .12, .12, 14), M.rubber, [x, .48, s * .95]);
  for (const s of [-1, 1]) add(En, boxG(7.6, .2, .16), M.skid, [-.6, .64, s * .95]);
  add(En, bboxG(2.8, .36, 1.0, .04), M.engine, [1.2, .92, 0]); add(En, bboxG(3.2, 1.4, 1.3, .05), M.engine, [1.2, 1.8, 0]); add(En, bboxG(3.0, .38, 1.15, .04), M.engine, [1.2, 2.69, 0]); for (let i = 0; i < 10; i++) for (const s of [-1, 1]) nut(En, [-.1 + i * .29, 2.88, s * .5], [0, 1, 0], .03, .03);
  add(En, bboxG(2.8, .26, .85, .05), M.teal, [1.2, 3.01, 0]); for (let i = 0; i < 4; i++) nut(En, [.2 + i * .66, 3.14, 0], [0, 1, 0], .035, .03);
  add(En, cylG(.06, .06, .08, 14), M.black, [.4, 3.18, .2]);
  for (let i = 0; i < 8; i++) for (const s of [-1, 1]) add(En, boxG(.06, 1.2, .04), M.engine, [-.2 + i * .4, 1.8, s * .67]);
  for (let i = 0; i < 4; i++) add(En, alongZ(cylG(.06, .06, .02, 14)), M.steel, [.0 + i * .8, 1.5, .672]);
  add(En, bboxG(1.6, .4, .3, .03), M.dark, [1.0, 1.95, .8]);
  for (let i = 0; i < 4; i++) { const x = .2 + i * .66; add(En, cylG(.035, .035, .2, 10), M.steel, [x, 2.95, .5]); add(En, tubeG([[.5 + i * .3, 2.15, .85], [.5 + i * .3, 2.6, .9], [x, 2.95, .65], [x, 3.0, .53]], .012, 5, .3), M.steel); }
  add(En, alongZ(cylG(.15, .15, .38, 24)), M.dark, [.6, 1.45, .87]); add(En, cylG(.09, .09, .3, 18), M.red, [2.25, 2.0, .86]); add(En, boxG(.1, .1, .2), M.dark, [2.25, 2.2, .75]);
  add(En, tubeG([[1.8, 1.3, .66], [1.82, 2.0, .72], [1.82, 2.5, .76]], .012, 5), M.steel); add(En, new THREE.TorusGeometry(.035, .012, 5, 12), M.yellow, [1.82, 2.53, .76]);
  add(En, alongX(cylG(.14, .14, .5, 18)), M.black, [-.2, 1.3, .75]);
  add(En, latheX([[.7, 0], [1.0, .2], [1.0, .4]], 48), M.engine, [-.8, 2.0, 0]);
  add(En, alongX(cylG(.3, .3, 1.0, 28)), M.dark, [.4, 3.55, .35]); for (const x of [0, .8]) add(En, boxG(.06, .3, .1), M.galv, [x, 3.28, .35]);
  add(En, tubeG([[-.1, 3.55, .35], [-.42, 3.4, -.1], [-.4, 3.05, -.75]], .1, 12), M.rubber);
  add(En, latheX([[.3, 0], [.3, .25], [0, .3]], 28), M.dark, [.9, 3.55, .35]);
  add(En, latheX([[0, -.15], [.28, -.15], [.28, .15], [0, .15]], 32), M.iron, [2.95, 1.5, 0]); add(En, latheX([[0, -.12], [.22, -.12], [.22, .12], [0, .12]], 28), M.iron, [3.0, 2.6, 0]);
  for (const s of [-1, 1]) beam(En, M.rubber, [2.97, 1.5, s * .29], [2.97, 2.6, s * .23], .05, .02);
  add(En, new THREE.TorusGeometry(.29, .02, 4, 16, PI).rotateX(PI).rotateY(PI / 2), M.rubber, [2.97, 1.5, 0]); add(En, new THREE.TorusGeometry(.23, .02, 4, 14, PI).rotateY(PI / 2), M.rubber, [2.97, 2.6, 0]);
  pipe(En, M.steel, [3.0, 2.6, 0], [3.9, 2.6, 0], .05, 12); add(En, alongX(cylG(.18, .18, .12, 20)), M.dark, [3.9, 2.6, 0]);
  for (let i = 0; i < 6; i++) { const a = i / 6 * TAU, d = new V3(0, Math.cos(a), Math.sin(a)); const o = add(En, boxG(.04, 1.0, .34), M.dark, [3.92, 2.6 + d.y * .7, d.z * .7]); o.quaternion.setFromUnitVectors(YUP, d); o.rotateY(.45); }
  add(En, tubeG([[2.75, 2.95, 0], [3.4, 3.6, .6], [4.3, 4.55, .9]], .07, 12), M.rubber); add(En, tubeG([[2.85, 1.95, .5], [3.6, 1.1, 1.1], [4.3, .95, 1.2]], .07, 12), M.rubber);
  add(En, tubeG([[.2, .42, -1.0], [.25, .8, -.8], [.9, 1.8, -.75]], .02, 6), M.black);
  // exhaust
  add(Ex, bboxG(2.8, .22, .18, .03), M.iron, [1.2, 2.6, -.72]); for (let i = 0; i < 4; i++) pipe(Ex, M.iron, [.2 + i * .66, 2.6, -.58], [.2 + i * .66, 2.6, -.66], .07, 10);
  add(Ex, new THREE.SphereGeometry(.26, 18, 12), M.iron, [-.25, 2.8, -.9]); add(Ex, latheX([[.0, 0], [.22, 0], [.22, .2], [0, .22]], 20), M.iron, [-.25, 2.8, -.9]);
  duct(Ex, M.lag, [[-.25, 3.0, -.9], [-.25, 5.3, -.9], [-.75, 5.3, -.9]], .16, .3, 20, 8);
  for (let y = 3.6; y < 4.2; y += .08) add(Ex, new THREE.TorusGeometry(.18, .02, 4, 20).rotateX(PI / 2), M.steel, [-.25, y, -.9]);
  add(Ex, alongX(cylG(.38, .38, 2.6, 36)), M.galv, [-2.1, 5.3, -.9]); for (const s of [-1, 1]) add(Ex, latheX(s > 0 ? [[.38, 0], [.25, .12], [.16, .15]] : [[.16, 0], [.25, .03], [.38, .15]], 36), M.galv, [s > 0 ? -.8 : -3.55, 5.3, -.9]);
  for (const x of [-3.0, -1.2]) { add(Ex, new THREE.TorusGeometry(.4, .025, 4, 36).rotateY(PI / 2), M.steel, [x, 5.3, -.9]); pipe(Ex, M.steel, [x, 5.7, -.9], [x, 6.2, -.9], .025, 8); }
  duct(Ex, M.galv, [[-3.55, 5.3, -.9], [-4, 5.3, -.9], [-4, 5.3, 0], [-4, 7.885, 0]], .17, .25, 24, 8);
  add(Ex, revolve(ringProf(.17, .2, .03, .005), 28), M.galv, [-4, 7.885, 0]); add(Ex, cylG(.175, .175, .7, 28, true), M.sootDG, [-4, 7.55, 0]);
  add(Ex, revolve(ringProf(.17, .26, .06, .01), 28), M.galv, [-4, 6.95, 0]); boltRing(Ex, [-4, 6.98, 0], [0, 1, 0], .225, 6, .02, .02);
  add(Ex, boxG(.05, .1, .14), M.galv, [-4.21, 7.84, 0]);
  sticker(Ex, label('SignHotEx', T.hot), .26, .26, [-1.8, 5.3, -.5]).rotation.y = 0;
  // flap (origin on hinge)
  Fl.position.set(-4.21, 7.905, 0);
  pipe(Fl, M.steel, [0, 0, -.07], [0, 0, .07], .018, 10);
  { const s = new THREE.Group(); s.rotation.z = 6 * DEG; Fl.add(s); add(s, cylG(.215, .215, .012, 32), M.galv, [.215, .006, 0]); add(s, boxG(.24, .012, .04), M.galv, [.1, .014, -.05]); add(s, boxG(.24, .012, .04), M.galv, [.1, .014, .05]); add(s, boxG(.06, .03, .1), M.iron, [-.04, .01, 0]); }
  // radiator
  add(Ra, boxG(.3, 3.4, 3.2), M.radiator, [4.55, 2.75, 0]); add(Ra, bboxG(.4, .3, 3.3, .03), M.engine, [4.55, 4.6, 0]); add(Ra, bboxG(.4, .25, 3.3, .03), M.engine, [4.55, .92, 0]);
  for (const s of [-1, 1]) { add(Ra, boxG(.42, 3.4, .06), M.engine, [4.55, 2.75, s * 1.63]); add(Ra, boxG(.2, .35, .2), M.skid, [4.55, .62, s * 1.4]); }
  add(Ra, cylG(.08, .1, .1, 18), M.steel, [4.55, 4.8, .9]); add(Ra, tubeG([[4.6, 4.8, 1.0], [4.8, 4.6, 1.5], [4.85, 1.0, 1.55]], .015, 6), M.rubber); add(Ra, cylG(.03, .03, .08, 8), M.steel, [4.55, .76, -1.2]);
  add(Ra, latheX([[1.3, 0], [1.3, .3], [1.45, .38], [1.6, .38]], 56), M.engine, [4.02, 2.6, 0]);
  add(Ra, plane(2.5, 2.5), M.guard, [3.75, 2.6, 0], [0, PI / 2, 0]);
  // alternator
  add(Al, alongX(cylG(1.0, 1.0, 2.4, 64)), M.teal, [-2.2, 2.0, 0]);
  for (let i = 0; i < 48; i++) { const a = i / 48 * TAU; if (Math.cos(a) < -.55) continue; add(Al, boxG(2.2, .1, .025), M.teal, [-2.2, 2.0 + 1.03 * Math.cos(a), 1.03 * Math.sin(a)], [a, 0, 0]); }
  add(Al, latheX([[1.0, 0], [1.05, .1], [.95, .6]], 56), M.teal, [-1.0, 2.0, 0]);
  add(Al, latheX([[0, 0], [.5, 0], [.85, .12], [1.0, .25]], 56), M.teal, [-3.65, 2.0, 0]);
  for (let i = 0; i < 14; i++) { const a = i / 14 * TAU; add(Al, boxG(.02, .05, .26), M.hole, [-3.6, 2.0 + .62 * Math.cos(a), .62 * Math.sin(a)], [a, 0, 0]); }
  for (const x of [-3.0, -1.4]) { add(Al, bboxG(.3, .35, 1.6, .03), M.teal, [x, .915, 0]); for (const s of [-1, 1]) nut(Al, [x, .74, s * .72], [0, 1, 0], .035, .03); }
  add(Al, bboxG(.9, .55, .9, .03), M.teal, [-2.2, 3.2, 0]); for (const dx of [-.25, 0, .25]) gland(Al, [-2.2 + dx, 3.475, .2], [0, 1, 0], .05);
  sticker(Al, label('AltPlate', T.namePlate('ALTERNATOR', '20 kVA · 0.8 pf · 400 V', 'Brushless · AVR · IP23', '#c9ccc8', '#1f6f6c')), .5, .25, [-2.2, 3.2, .452]);
  add(Al, tubeG([[-2.2, 3.6, .2], [-2.2, 5.6, .25], [-2.0, 6.0, .3], [2.8, 6.0, .3], [3, 6.08, .1], [3, 6.2, 0]], .05, 8, .25), M.cable);
  for (const x of [-1.0, .6, 2.2]) add(Al, boxG(.05, .2, .08), M.steel, [x, 6.1, .3]);
  // controls behind window
  add(Co, bboxG(1.3, 1.4, .4, .03), M.dark, [-4.1, 3.7, 2.98]); for (const a of [-1, 1]) for (const b of [-1, 1]) add(Co, cylG(.03, .03, .1, 8).rotateX(PI / 2), M.steel, [-4.1 + a * .55, 3.7 + b * .6, 3.22]);
  sticker(Co, lcd('HourMeter', T.lcd(['04217.3 h'], '#101a10', '#d8f0a0')), .34, .12, [-4.4, 4.15, 3.185]);
  [['DialOil', T.dial('bar', 8, .1)], ['DialTemp', T.dial('°C', 120, .8)], ['DialVolt', T.dial('V', 32, .85)]].forEach(([p, t], i) => { add(Co, alongZ(cylG(.12, .12, .03, 28)), M.black, [-4.45 + i * .35, 3.8, 3.19]); dialFace(Co, p, t, [-4.45 + i * .35, 3.8, 3.206], .105, [0, 0, 1]); });
  add(Co, alongZ(cylG(.07, .07, .03, 18)), M.steel, [-4.45, 3.35, 3.19]); add(Co, boxG(.03, .1, .06), M.brass, [-4.45, 3.35, 3.22]);
  [M.emG, M.emR, M.emA].forEach((m, i) => add(Em, latheZ([[0, 0], [.04, 0], [.04, .015], [0, .03]], 14), m, [-4.05 + i * .2, 3.35, 3.18]));
  add(Co, alongZ(cylG(.13, .13, .02, 24)), M.yellow, [-3.2, 3.7, 3.31]); add(Co, latheZ([[0, 0], [.1, 0], [.11, .04], [.1, .08], [0, .09]], 20), M.red, [-3.2, 3.7, 3.32]);
  // details
  add(De, bboxG(1.0, .55, .7, .04), M.black, [.9, .695, 1.85]); add(De, boxG(1.1, .03, .8), M.galv, [.9, .435, 1.85]);
  for (const [x, m] of [[.55, M.red], [1.25, M.black]]) { add(De, cylG(.05, .05, .08, 12), m, [x, 1.01, 1.85]); }
  add(De, tubeG([[.55, 1.05, 1.85], [.3, 1.1, 1.4], [-.1, 1.3, .9]], .03, 8), M.red); add(De, tubeG([[1.25, 1.05, 1.85], [1.5, 1.0, 1.3], [1.5, .8, .95]], .03, 8), M.cable);
  add(De, flat(4.0, .9), M.oil, [1.0, .003, 3.5]); add(De, flat(1.6, .8), M.oil, [-2.0, .003, -3.55]);
  add(De, plane(.8, .35), M.oil, [1.0, .22, 3.422]); add(De, plane(.6, .3), M.oil, [-.4, .2, -3.422], [0, PI, 0]);
  for (let i = 0; i < 6; i++) add(De, new THREE.SphereGeometry(.05, 10, 6), M.black, [rr(.3, 2.2), .006, rr(3.48, 3.7)], [0, 0, 0], [1.4, .1, 1]);
  { const s = sub(De, [-1.0, 0, -3.75]); add(s, bboxG(.85, 1.0, .4, .05), M.red, [0, .5, 0]); for (const sx of [-1, 1]) add(s, boxG(.6, .04, .02), M.red, [0, .5, sx * .205], [0, 0, sx * .6]);
    for (const x of [-.25, 0, .25]) add(s, boxG(.05, .14, .06), M.red, [x, 1.06, 0]); add(s, boxG(.6, .04, .06), M.red, [0, 1.13, 0]); add(s, cylG(.05, .05, .1, 12), M.dark, [.33, 1.05, 0]); }
  wireTop(R, 'DG_', [3, 6.4, 0]);
  return finish(R);
}

export const SPEC = {
  HandCrank: { pfx: 'HC_', s: [6, 5, 6], tri: [6000, 15000], wire: [-.6, 4.4, 0], groups: ['Base', 'Dynamo', 'Wheel', 'Details', 'Glass', 'WireTop'] },
  SolarPanel: { pfx: 'SP_', s: [8, 4, 8], tri: [8000, 18000], wire: [2.8, 1.6, 2.8], groups: ['Rack', 'Frame', 'Cells', 'Controller', 'Emissive', 'WireTop'] },
  PowerPole: { pfx: 'PO_', s: [2, 14.8, 5.2], tri: [6000, 12000], groups: ['Pole', 'Crossarm', 'Insulators', 'Coil1', 'Coil2', 'Details'] },
  Battery: { pfx: 'BB_', s: [6, 6, 6], tri: [10000, 18000], wire: [0, 5.7, 0], groups: ['Cabinet', 'Cells', 'Busbars', 'Controls', 'Level1', 'Level2', 'Level3', 'Level4', 'Glass', 'WireTop'] },
  StrawGenerator: { pfx: 'SG_', s: [14, 12, 12], tri: [50000, 80000], wire: [4, 8, -4], groups: ['Foundation', 'Feeder', 'Furnace', 'Boiler', 'Filter', 'Chimney', 'Engine', 'Generator', 'Controls', 'Details', 'Fire', 'Emissive', 'Glass', 'WireTop'] },
  DieselGenerator: { pfx: 'DG_', s: [12, 8, 8], tri: [30000, 55000], wire: [3, 6.4, 0], groups: ['Skid', 'Canopy', 'Engine', 'Alternator', 'Radiator', 'Exhaust', 'Flap', 'Controls', 'Details', 'Emissive', 'Glass', 'WireTop'] },
};
export const BUILD = { HandCrank: buildHandCrank, SolarPanel: buildSolar, PowerPole: buildPole, Battery: buildBattery, StrawGenerator: buildStraw, DieselGenerator: buildDiesel };

export { wireTop, nut, boltRing, anchor, pad, gland, flat, sticker, prismXY, prismZY, louvre, dialFace, label, lcd, grpOf, root };
