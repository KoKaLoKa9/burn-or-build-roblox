// Pack 5 · paddy field: rice row segments (shared rice atlas, recoloured per stage), straw, bund, factory items, test field.
import { THREE, V3, TAU, DEG, DS, setSeed, rnd, rr, pick, clamp, lerp, sstep, makeNoise, N, cv, field, texFrom, normalCanvas, grayFrom, mrCanvas, pbr, simpleSet, lib, blotch, specks, wrapped, add, boxG, tubeG, blobG, cardG, makeAsset } from './env_common.js';
import { FM } from './env_flora_lib.js';

/* ================= helpers ================= */
const col = (c, k = 1) => `rgb(${clamp(c[0] * k, 0, 255) | 0},${clamp(c[1] * k, 0, 255) | 0},${clamp(c[2] * k, 0, 255) | 0})`;
const g3 = v => `rgb(${v | 0},${v | 0},${v | 0})`;
const mix3 = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
const put = (o, c, k = 1) => { o[0] = clamp(c[0] * k, 0, 255); o[1] = clamp(c[1] * k, 0, 255); o[2] = clamp(c[2] * k, 0, 255); };
function shape(pts, wf) { const n = pts.length, L = [], R = [];
  for (let i = 0; i < n; i++) { const a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1, nx = -dy / l, ny = dx / l, w = wf(i / (n - 1)) / 2;
    L.push([pts[i][0] + nx * w, pts[i][1] + ny * w]); R.push([pts[i][0] - nx * w, pts[i][1] - ny * w]); }
  return L.concat(R.reverse()); }
function fillPoly(x, poly, st) { x.fillStyle = st; x.beginPath(); poly.forEach((p, i) => i ? x.lineTo(p[0], p[1]) : x.moveTo(p[0], p[1])); x.closePath(); x.fill(); }
function strokePts(x, pts, w, st) { x.strokeStyle = st; x.lineWidth = w; x.beginPath(); pts.forEach((p, i) => i ? x.lineTo(p[0], p[1]) : x.moveTo(p[0], p[1])); x.stroke(); }
// 2D path: angle 0 = up the canvas, +a = to the right, PI = down
function bend(x0, y0, L, n, fa) { const pts = [[x0, y0]]; let X = x0, Y = y0; for (let i = 1; i <= n; i++) { const a = fa((i - .5) / n); X += Math.sin(a) * L / n; Y -= Math.cos(a) * L / n; pts.push([X, Y]); } return pts; }
function walk(pts) { const acc = [0]; for (let i = 1; i < pts.length; i++) acc.push(acc[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  return { len: acc[acc.length - 1], at: d => { let i = 1; while (i < acc.length - 1 && acc[i] < d) i++; const t = (d - acc[i - 1]) / ((acc[i] - acc[i - 1]) || 1), a = pts[i - 1], b = pts[i]; return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), Math.atan2(b[1] - a[1], b[0] - a[0])]; } }; }
/** RGBA DataTexture (straight alpha, no premultiply halo), rows flipped so canvas top = v 1 like CanvasTexture. */
function dataTex(c, a) { const W = c.width, H = c.height, cd = c.getContext('2d').getImageData(0, 0, W, H).data, ad = a.getContext('2d').getImageData(0, 0, W, H).data, out = new Uint8Array(W * H * 4);
  for (let j = 0; j < H; j++) { const s = j * W * 4, d = (H - 1 - j) * W * 4; for (let i = 0; i < W * 4; i += 4) { out[d + i] = cd[s + i]; out[d + i + 1] = cd[s + i + 1]; out[d + i + 2] = cd[s + i + 2]; out[d + i + 3] = ad[s + i]; } }
  const t = new THREE.DataTexture(out, W, H, THREE.RGBAFormat); t.colorSpace = THREE.SRGBColorSpace; t.generateMipmaps = true; t.minFilter = THREE.LinearMipmapLinearFilter; t.magFilter = THREE.LinearFilter; t.anisotropy = 8; t.flipY = false; t.needsUpdate = true; return t; }
function voronoi(G, seed) { setSeed(seed); const P = []; for (let j = 0; j < G; j++) for (let i = 0; i < G; i++) P.push([rnd(), rnd()]);
  return (u, v) => { const x = u * G, y = v * G, ci = Math.floor(x), cj = Math.floor(y); let f1 = 9, f2 = 9;
    for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) { const ii = ci + di, jj = cj + dj, p = P[((jj % G + G) % G) * G + ((ii % G + G) % G)], d = Math.hypot(ii + p[0] - x, jj + p[1] - y); if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d; }
    return [f1, f2]; }; }
const wrapV = (H, y, r, fn) => { for (const o of [-H, 0, H]) if (y + o + r >= 0 && y + o - r <= H) fn(y + o); };

/* ================= shared rice atlas (1024², neutral, tinted per stage) ================= */
const AS = 1024;
const REG = { FAN: [0, 0, 512, 512], PAN1: [512, 0, 192, 1024], PAN2: [704, 0, 192, 1024], BLADE: [896, 0, 128, 512], CULM: [896, 512, 128, 512], STUB: [0, 512, 256, 256], TUFT: [256, 512, 256, 256], STRAW: [0, 768, 512, 256] };
const UVR = {}; for (const k in REG) { const [x, y, w, h] = REG[k], e = 4; UVR[k] = { u0: (x + e) / AS, u1: (x + w - e) / AS, vt: 1 - (y + e) / AS, vb: 1 - (y + h - e) / AS }; }
const BODY = [238, 236, 216];
export const seamCanvases = {};
let _atlas;
export function riceAtlas() {
  if (_atlas) return _atlas; setSeed(5101);
  const c = cv(AS), x = c.getContext('2d'), a = cv(AS), y = a.getContext('2d'), h = cv(AS), z = h.getContext('2d');
  x.fillStyle = 'rgb(200,196,174)'; x.fillRect(0, 0, AS, AS); y.fillStyle = '#000'; y.fillRect(0, 0, AS, AS); z.fillStyle = '#000'; z.fillRect(0, 0, AS, AS);
  for (const k of [x, y, z]) { k.lineCap = 'round'; k.lineJoin = 'round'; }
  const clip = (r, fn) => { for (const k of [x, y, z]) { k.save(); k.beginPath(); k.rect(r[0] + 3, r[1] + 3, r[2] - 6, r[3] - 6); k.clip(); } fn(...r); for (const k of [x, y, z]) k.restore(); };
  const P = (poly, cc, hv) => { fillPoly(x, poly, cc); fillPoly(y, poly, '#fff'); fillPoly(z, poly, g3(hv)); };
  const S = (pts, w, cc, hv, al = true) => { strokePts(x, pts, w, cc); if (al) strokePts(y, pts, w, '#fff'); if (hv != null) strokePts(z, pts, w, g3(hv)); };
  const shade = (r, y0, y1, c0) => { x.save(); x.globalCompositeOperation = 'multiply'; const g = x.createLinearGradient(0, y0, 0, y1); g.addColorStop(0, c0); g.addColorStop(1, '#fff'); x.fillStyle = g; x.fillRect(r[0], r[1], r[2], r[3]); x.restore(); };
  // FAN: a tiller's leaf mass rising from the bottom centre, blades arching outward
  clip(REG.FAN, (ox, oy, W, H) => { const bx = ox + W / 2, by = oy + H - 4, bl = [];
    for (let i = 0; i < 74; i++) { const s = rnd() < .5 ? -1 : 1, th = s * Math.pow(rnd(), 1.15) * 1.15; bl.push({ s, th, L: rr(.5, .98) * (H - 10) * (1 - .28 * Math.abs(th)), dr: rr(.05, .6) * (.25 + Math.abs(th)), w0: rr(6, 11), x0: bx + rr(-16, 16), lum: rr(.74, 1.02), dry: rnd() < .16 }); }
    bl.sort((p, q) => p.lum - q.lum);
    for (const b of bl) { const pts = bend(b.x0, by, b.L, 14, t => b.th * (.3 + .7 * t) + b.s * b.dr * t * t), wf = t => b.w0 * (t < .12 ? .75 + t / .12 * .25 : Math.max(0, 1 - Math.pow((t - .12) / .88, 1.5)));
      P(shape(pts, wf), col(BODY, b.lum), 140 + b.lum * 60);
      if (b.dry) { const k = 10; P(shape(pts.slice(k), t => wf(k / 14 + t * (1 - k / 14))), col([226, 204, 156], b.lum), 160); }
      S(pts.slice(1, -2), 1.3, 'rgba(255,255,240,.35)', 225, false); }
    shade([ox, oy, W, H], by, by - H * .45, 'rgb(118,120,110)'); });
  // PAN1/PAN2: hanging panicle — peduncle (top 29%), then rachis with primary branches and individual grains
  for (const [k, green] of [['PAN1', false], ['PAN2', true]]) clip(REG[k], (ox, oy, W, H) => {
    const cx = ox + W / 2, neck = oy + H * .29, base = green ? [228, 230, 184] : [244, 232, 188], ph = rnd() * 6;
    S(bend(cx, oy, neck - oy, 6, () => Math.PI), 7, col([226, 222, 190], .85), 170);
    const axis = bend(cx, neck, H * .69, 22, t => Math.PI + .1 * Math.sin(t * 3 + ph)); S(axis, 4.4, col(base, .78), 170);
    const grains = [], aw = walk(axis);
    for (let b = 0; b < 10; b++) { const t0 = .02 + b / 10 * .6, st = aw.at(t0 * aw.len), s = b % 2 ? 1 : -1, L = H * .69 * (1 - t0) * rr(.55, .88), sp = rr(.1, .28) * s;
      const br = bend(st[0], st[1], L, 10, t => Math.PI - sp * (1.6 - 1.25 * t)); br.forEach(p => p[0] = clamp(p[0], ox + 14, ox + W - 14));
      S(br, 2.6, col(base, .7), 150); const w = walk(br); let side = 1; for (let d = 22; d < w.len - 6; d += rr(19, 25)) { grains.push([w.at(d), side]); side = -side; } }
    let sd = 1; for (let d = aw.len * .55; d < aw.len - 8; d += 21) { grains.push([aw.at(d), sd]); sd = -sd; }
    for (const [[gx0, gy0, ang], sdd] of grains) { const nx = -Math.sin(ang), ny = Math.cos(ang), gx = gx0 + nx * 6.5 * sdd, gy = gy0 + ny * 6.5 * sdd, rot = ang - Math.PI / 2 + sdd * rr(.12, .38), lum = rr(.8, 1.03);
      x.save(); x.translate(gx, gy); x.rotate(rot); x.fillStyle = col(base, lum); x.beginPath(); x.ellipse(0, 0, 6.4, 16.5, 0, 0, TAU); x.fill(); x.strokeStyle = 'rgba(108,90,56,.6)'; x.lineWidth = 1.4; x.stroke();
      x.strokeStyle = 'rgba(255,252,236,.6)'; x.lineWidth = 1.2; x.beginPath(); x.moveTo(-1.2, -12); x.lineTo(-1.2, 12); x.stroke(); x.fillStyle = 'rgba(92,74,48,.9)'; x.beginPath(); x.arc(0, 16, 1.9, 0, TAU); x.fill();
      if (rnd() < .22) { x.fillStyle = 'rgba(120,86,50,.5)'; for (let q = 0; q < 3; q++) { x.beginPath(); x.arc(rr(-3, 3), rr(-10, 10), rr(1, 2.2), 0, TAU); x.fill(); } } x.restore();
      y.save(); y.translate(gx, gy); y.rotate(rot); y.fillStyle = '#fff'; y.beginPath(); y.ellipse(0, 0, 7.2, 17.3, 0, 0, TAU); y.fill(); y.restore();
      z.save(); z.translate(gx, gy); z.rotate(rot); const gg = z.createRadialGradient(0, 0, 0, 0, 0, 16); gg.addColorStop(0, '#fff'); gg.addColorStop(1, '#606060'); z.fillStyle = gg; z.beginPath(); z.ellipse(0, 0, 6.4, 16.5, 0, 0, TAU); z.fill(); z.restore(); } });
  // BLADE: one leaf blade, base at bottom
  clip(REG.BLADE, (ox, oy, W, H) => { const pts = bend(ox + W / 2, oy + H - 3, H - 8, 16, t => .04 * Math.sin(t * 3)), wf = t => (W - 16) * (t < .15 ? .85 + t : Math.max(0, 1 - Math.pow((t - .15) / .85, 1.3)));
    P(shape(pts, wf), col(BODY, .95), 180);
    for (const o of [-.3, -.15, .15, .3]) S(pts.slice(0, -3).map((p, i) => [p[0] + o * wf(i / 16), p[1]]), 1, 'rgba(255,255,235,.3)', 200, false);
    S(pts.slice(0, -2), 2, 'rgba(255,255,240,.45)', 240, false); P(shape(pts.slice(13), t => wf(13 / 16 + t * 3 / 16)), col([226, 204, 158], .95), 170);
    shade([ox, oy, W, H], oy + H, oy + H * .62, 'rgb(150,152,140)'); });
  // CULM: opaque stem strip, maps 0..2 studs of height: grey-brown base band, nodes at 0.8 and 1.5
  clip(REG.CULM, (ox, oy, W, H) => { y.fillStyle = '#fff'; y.fillRect(ox, oy, W, H);
    for (let i = 0; i < W; i++) { const l = .86 + .06 * Math.sin(i * .9) + .05 * Math.sin(i * .23 + 1) + rr(-.02, .02); x.fillStyle = col(BODY, l); x.fillRect(ox + i, oy, 1, H); z.fillStyle = g3(150 + 60 * Math.sin(i * .9)); z.fillRect(ox + i, oy, 1, H); }
    shade([ox, oy, W, H], oy + H, oy + H * .78, 'rgb(128,128,126)');
    for (const f of [.6, .25]) { x.fillStyle = 'rgba(90,86,70,.6)'; x.fillRect(ox, oy + f * H - 3, W, 5); x.fillStyle = 'rgba(255,252,236,.45)'; x.fillRect(ox, oy + f * H + 2, W, 3); z.fillStyle = '#fff'; z.fillRect(ox, oy + f * H - 2, W, 6); }
    for (let i = 0; i < 160; i++) { x.fillStyle = `rgba(80,72,60,${rr(.2, .5)})`; x.fillRect(ox + rnd() * W, oy + H * rr(.82, 1), rr(1, 3), rr(1, 4)); } });
  // STUB: a hill of cut stems, base at bottom
  clip(REG.STUB, (ox, oy, W, H) => { const st = []; for (let i = 0; i < 24; i++) st.push({ x: ox + W / 2 + (rnd() + rnd() + rnd() - 1.5) * 90, h: rr(.55, .96) * (H - 10), t: rr(-.13, .13), w: rr(8, 13), l: rr(.75, 1.02) });
    st.sort((p, q) => p.l - q.l);
    for (const s of st) { const b = [s.x, oy + H - 2], tp = [s.x + Math.sin(s.t) * s.h, oy + H - 2 - Math.cos(s.t) * s.h];
      P(shape([b, tp], () => s.w), col(BODY, s.l), 170); S([[b[0] + s.w * .25, b[1]], [tp[0] + s.w * .25, tp[1]]], 1.5, 'rgba(255,255,240,.35)', 200, false);
      x.fillStyle = col([252, 248, 230]); x.beginPath(); x.ellipse(tp[0], tp[1], s.w / 2, s.w / 4.5, s.t, 0, TAU); x.fill(); x.fillStyle = 'rgba(70,62,50,.9)'; x.beginPath(); x.ellipse(tp[0], tp[1], s.w / 3.6, s.w / 9, s.t, 0, TAU); x.fill();
      y.fillStyle = '#fff'; y.beginPath(); y.ellipse(tp[0], tp[1], s.w / 2, s.w / 4.5, s.t, 0, TAU); y.fill(); }
    for (let i = 0; i < 6; i++) { const s = pick(st), sd = rnd() < .5 ? -1 : 1; P(shape(bend(s.x, oy + H - s.h * rr(.3, .6), rr(50, 95), 8, t => sd * (.5 + 2.2 * t)), t => 6 * (1 - t * .8)), col([232, 214, 170], rr(.75, .95)), 150); }
    shade([ox, oy, W, H], oy + H, oy + H * .55, 'rgb(116,116,114)'); });
  // TUFT: loose straw strands fanning up from the bottom centre
  clip(REG.TUFT, (ox, oy, W, H) => { for (let i = 0; i < 110; i++) { const th = rr(-1.2, 1.2), L = rr(.45, .97) * (H - 8) * (1 - .2 * Math.abs(th)), k = rr(-.3, .3), lum = rr(.72, 1.04), w = rr(2.4, 4.6);
      P(shape(bend(ox + W / 2 + rr(-18, 18), oy + H - 3, L, 8, t => th * (.4 + .6 * t) + k * t), t => w * (1 - .5 * t)), col(BODY, lum), 150 + lum * 60); }
    shade([ox, oy, W, H], oy + H, oy + H * .6, 'rgb(150,148,140)'); });
  // STRAW: scattered loose strands (litter)
  clip(REG.STRAW, (ox, oy, W, H) => { for (let i = 0; i < 190; i++) { const cx = ox + rr(20, W - 20), cy = oy + rr(15, H - 15), an = rnd() * TAU, L = rr(40, 200), k = rr(-.4, .4), w = rnd() < .08 ? rr(7, 10) : rr(2.2, 5), lum = rr(.7, 1.05);
      P(shape(bend(cx - Math.sin(an) * L / 2, cy + Math.cos(an) * L / 2, L, 6, t => an + k * t), t => w * (.6 + .4 * Math.sin(t * Math.PI))), col(BODY, lum), 150 + lum * 70); } });
  const map = dataTex(c, a), nrm = texFrom(normalCanvas(h, 2.5, false), false, false), mr = texFrom(mrCanvas(grayFrom(h, .78, .3)), false, false);
  _atlas = { map, nrm, mr, canvas: c }; return _atlas;
}
const _rm = {};
/** Stage material: the shared rice atlas with a per-stage tint. */
export function riceMat(name, hex) { if (_rm[name]) return _rm[name]; const A = riceAtlas();
  const m = new THREE.MeshStandardMaterial({ map: A.map, normalMap: A.nrm, roughnessMap: A.mr, roughness: 1, metalness: 0, color: new THREE.Color(hex), alphaTest: .5, side: DS, alphaToCoverage: true });
  m.normalScale.set(.8, .8); m.name = name; m.userData.uvScale = 1; m.userData.tint = hex; return _rm[name] = m; }
export const TINTS = { Seedling: 0xb4d35a, Growing: 0x5d9236, Heading: 0x74a040, HeadingPanicle: 0xd4d78a, RipeStraw: 0xc8a24c, RipeGrain: 0xe4b04a, Stubble: 0xe4c47e, Charred: 0x332f2b, Scorched: 0x7a5a32, Straw: 0xdcbb70, EmptyPanicle: 0xcdb47c, StrawWet: 0x8c7a48, StrawDry: 0xeac56a, Weed: 0x4c7a2c };
const RM = k => riceMat('EV_Rice_' + k, TINTS[k]);

/* ================= geometry ================= */
function stripG(pts, side, wid, reg, f0, f1) { const r = UVR[reg], n = pts.length, pos = [], uv = [], idx = [];
  for (let i = 0; i < n; i++) { const p = pts[i], s = Array.isArray(side) ? side[i] : side, t = i / (n - 1), w = typeof wid === 'function' ? wid(t) : wid, f = Array.isArray(f0) ? f0[i] : f0 + (f1 - f0) * t, v = r.vt - f * (r.vt - r.vb);
    pos.push(p.x - s.x * w / 2, p.y - s.y * w / 2, p.z - s.z * w / 2, p.x + s.x * w / 2, p.y + s.y * w / 2, p.z + s.z * w / 2); uv.push(r.u0, v, r.u1, v); }
  for (let i = 0; i < n - 1; i++) { const a = 2 * i; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx); g.computeVertexNormals(); return g; }
const hdir = az => new V3(Math.cos(az), 0, Math.sin(az)), perp = d => new V3(-d.z, 0, d.x), UP = new V3(0, 1, 0);
function arc(base, d, L, n, fa) { const pts = [base.clone()]; let p = base.clone(); for (let i = 1; i < n; i++) { const a = fa((i - .5) / (n - 1)); p = p.clone().addScaledVector(d, Math.sin(a) * L / (n - 1)); p.y += Math.cos(a) * L / (n - 1); pts.push(p); } return pts; }
function leafRib(base, az, L, lean, archA, w, n = 4, twist = 0) { const d = hdir(az), pts = arc(base, d, L, n, t => lean + archA * t), s = perp(d); return stripG(pts, pts.map((_, i) => s.clone().applyAxisAngle(d, twist * i / (n - 1))), w, 'BLADE', 1, 0); }
function fanG(base, az, h, w, lean, bnd, reg = 'FAN', n = 3) { const d = hdir(az); return stripG(arc(base, d, h, n, t => lean + bnd * t), perp(d), w, reg, 1, 0); }
/** Real stem: open tube on the CULM strip, v follows world height (strip = 0..2 studs). */
function culmG(a, b, r0, r1, seg = 3) { const g = tubeG([a, b], [r0, r1], seg, { uRep: 1, tile: a.distanceTo(b) }), uv = g.attributes.uv, r = UVR.CULM;
  for (let i = 0; i < uv.count; i++) { const f = 1 - lerp(a.y, b.y, uv.getY(i)) / 2; uv.setXY(i, r.u0 + clamp(uv.getX(i), 0, 1) * (r.u1 - r.u0), r.vt - clamp(f, 0, 1) * (r.vt - r.vb)); } return g; }
/** Parametric grid fn(s,t)->V3 with normals from finite differences (periodic fn in t ⇒ seamless ends). */
function sweepG(fn, ns, nk, uvFn) { const pos = [], nor = [], uv = [], idx = [], e = 1e-3;
  for (let k = 0; k <= nk; k++) for (let i = 0; i <= ns; i++) { const s = i / ns, t = k / nk, p = fn(s, t), ps = fn(Math.min(1, s + e), t).sub(fn(Math.max(0, s - e), t)), pt = fn(s, t + e).sub(fn(s, t - e)), n = new V3().crossVectors(pt, ps).normalize();
    pos.push(p.x, p.y, p.z); nor.push(n.x, n.y, n.z); const q = uvFn(s, t, p); uv.push(q[0], q[1]); }
  for (let k = 0; k < nk; k++) for (let i = 0; i < ns; i++) { const a = k * (ns + 1) + i, b = a + 1, c = a + ns + 1, d = c + 1; idx.push(a, c, b, b, c, d); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx); return g; }
function latheG(prof, seg, o = {}) { const g = new THREE.LatheGeometry(prof.map(p => new THREE.Vector2(Math.max(p[0], 1e-3), p[1])), seg, o.phi0 ?? 0), p = g.attributes.position, n = prof.length;
  if (o.amp) { for (let i = 0; i < p.count; i++) { const X = p.getX(i), Y = p.getY(i), Z = p.getZ(i); if (Math.hypot(X, Z) < .01) continue; const k = 1 + o.amp * (N.fbm3(X * (o.f || 2) + (o.so || 0), Y * (o.f || 2), Z * (o.f || 2), 3) - .5) * 2; p.setX(i, X * k); p.setZ(i, Z * k); if (o.yAmp) p.setY(i, Y + o.yAmp * (N.fbm3(X * 3 + 9, Y * 3, Z * 3, 2) - .5)); } }
  if (o.sq) for (let i = 0; i < p.count; i++) { p.setX(i, p.getX(i) * o.sq[0]); p.setZ(i, p.getZ(i) * o.sq[1]); }
  g.computeVertexNormals(); const nn = g.attributes.normal; for (let j = 0; j < n; j++) { const A = j, B = seg * n + j, v = new V3(nn.getX(A) + nn.getX(B), nn.getY(A) + nn.getY(B), nn.getZ(A) + nn.getZ(B)).normalize(); nn.setXYZ(A, v.x, v.y, v.z); nn.setXYZ(B, v.x, v.y, v.z); }
  if (o.studs) { const uv = g.attributes.uv, rA = prof.reduce((s, q) => s + q[0], 0) / n; let L = 0; for (let j = 1; j < n; j++) L += Math.hypot(prof[j][0] - prof[j - 1][0], prof[j][1] - prof[j - 1][1]); for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * TAU * rA, uv.getY(i) * L); }
  if (o.vByY) { const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setY(i, p.getY(i) / o.vByY); }
  return g; }
/** Squash a primitive's horizontal reach (per side, relative to its hill base) and height so it stays inside the segment. */
const XM = 3.18, ZM = 3.985;
function fit(g, bx, bz, HM, xm = XM, zm = ZM) { const p = g.attributes.position; let xp = 0, xn = 0, zp = 0, zn = 0, yp = 0;
  for (let i = 0; i < p.count; i++) { const dx = p.getX(i) - bx, dz = p.getZ(i) - bz; xp = Math.max(xp, dx); xn = Math.min(xn, dx); zp = Math.max(zp, dz); zn = Math.min(zn, dz); yp = Math.max(yp, p.getY(i)); }
  const fxp = xp > xm - bx ? (xm - bx) / xp : 1, fxn = xn < -xm - bx ? (-xm - bx) / xn : 1, fzp = zp > zm - bz ? (zm - bz) / zp : 1, fzn = zn < -zm - bz ? (-zm - bz) / zn : 1, fy = HM && yp > HM ? HM / yp : 1;
  for (let i = 0; i < p.count; i++) { const dx = p.getX(i) - bx, dz = p.getZ(i) - bz; p.setXYZ(i, bx + dx * (dx > 0 ? fxp : fxn), Math.max(.02, p.getY(i) * fy), bz + dz * (dz > 0 ? fzp : fzn)); }
  if (fxp < 1 || fxn < 1 || fzp < 1 || fzn < 1 || fy < 1) { if (g.index && g.attributes.normal && !g.userData.keepN) g.computeVertexNormals(); } return g; }
/** After merge: optional transform, then centre on x/z, rest on y=0 and squeeze into W×H×D. */
function postFit(asset, W, H, D, pre) { const ms = asset.children; if (pre) ms.forEach(m => m.geometry.applyMatrix4(pre));
  const b = new THREE.Box3(); ms.forEach(m => { m.geometry.computeBoundingBox(); b.union(m.geometry.boundingBox); }); const s = b.getSize(new V3());
  const M = new THREE.Matrix4().makeScale(Math.min(1, W / s.x), Math.min(1, H / s.y), Math.min(1, D / s.z)).multiply(new THREE.Matrix4().makeTranslation(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2));
  ms.forEach(m => { m.geometry.applyMatrix4(M); m.geometry.computeBoundingBox(); m.geometry.computeBoundingSphere(); }); return asset; }

/* ================= ground / water textures ================= */
const _m = {};
const once = (k, f) => _m[k] || (_m[k] = f());
export const waterMat = () => once('water', () => { const S = 256, nz = makeNoise(501);
  const c = field(S, S, (u, v, o) => { const n = nz.fbm2(u, v, 4, 4), s = nz.fbm2(u, v, 2, 3); put(o, mix3([84, 76, 58], [128, 120, 96], sstep(.5, .75, s)), .9 + n * .2); });
  specks(c.getContext('2d'), S, S, 60, ['#cbb98a', '#e2d6b0'], .6, 1.6, .3, .8);
  const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 128 + (nz.fbm2(u, v, 8, 4) - .5) * 90 + Math.sin((nz.fbm2(u, v, 2, 2) * 6 + u * 2) * TAU) * 12; });
  return pbr('EV_PaddyWater', { color: c, height: h, k: 1.4, roughBase: .05, roughAmp: .04, uv: .25, transparent: true, opacity: .62 }); });
function waterG(w, d, y) { const g = new THREE.PlaneGeometry(w, d, 1, 1); g.rotateX(-Math.PI / 2); g.translate(0, y, 0); const p = g.attributes.position, uv = g.attributes.uv; for (let i = 0; i < p.count; i++) uv.setXY(i, p.getX(i) + w / 2, -(p.getZ(i)) + d / 2); return g; }
// burnt-stubble ground: 512×640 = 6.4×8 studs, periodic along the row, irregular alpha edge across it
const BW = 512, BH = 640, bnz = makeNoise(611);
const bAsh = (u, v) => sstep(.52, .7, bnz.fbm2(u, v, 4, 5)), bChar = (u, v) => sstep(.48, .62, bnz.fbm2(u + .3, v + .6, 3, 4));
const burntMat = () => once('burnt', () => { setSeed(611); const vor = voronoi(9, 611);
  const crack = (u, v) => { const [a, b] = vor(u + (bnz.fbm2(u, v, 8, 3) - .5) * .03, v); return 1 - sstep(.02, .06, b - a); };
  const c = field(BW, BH, (u, v, o) => { const n = bnz.fbm2(u, v, 8, 4), cr = crack(u, v), as = bAsh(u, v), ch = bChar(u, v), fl = bnz.n2(u * 200, v * 200, 200);
    let k = mix3([100, 84, 68], [72, 60, 50], n); k = mix3(k, [30, 27, 24], ch * .85); k = mix3(k, [22, 20, 18], cr * .9); k = mix3(k, mix3([140, 138, 132], [214, 210, 202], sstep(.6, .9, bnz.fbm2(u, v, 16, 3))), as * .92); if (fl > .86) k = mix3(k, [226, 222, 214], .6); put(o, k); });
  const h = field(BW, BH, (u, v, o) => { o[0] = o[1] = o[2] = 120 + bAsh(u, v) * 90 - crack(u, v) * 100 + (bnz.fbm2(u, v, 16, 3) - .5) * 40; });
  const x = c.getContext('2d'), z = h.getContext('2d'); x.lineCap = z.lineCap = 'round';
  for (let i = 0; i < 260; i++) { const px = rr(30, BW - 30), py = rnd() * BH, an = rnd() * TAU, L = rr(14, 60), half = rnd() < .3, cc = half ? `rgb(${rr(120, 170) | 0},${rr(88, 120) | 0},${rr(50, 70) | 0})` : `rgb(${rr(20, 44) | 0},${rr(18, 36) | 0},${rr(16, 30) | 0})`, lw = rr(1.5, 3);
    wrapV(BH, py, L, Y => { x.strokeStyle = cc; x.lineWidth = lw; x.beginPath(); x.moveTo(px, Y); x.lineTo(px + Math.cos(an) * L, Y + Math.sin(an) * L); x.stroke(); z.strokeStyle = '#ddd'; z.lineWidth = 2; z.beginPath(); z.moveTo(px, Y); z.lineTo(px + Math.cos(an) * L, Y + Math.sin(an) * L); z.stroke(); }); }
  const a = field(BW, BH, (u, v, o) => { const e = Math.abs(u - .5) * 2, lim = .9 + (bnz.fbm2(.37, v, 10, 3) - .5) * .16 + (bnz.n2(u * 40, v * 50, 40, 50) - .5) * .06; o[0] = o[1] = o[2] = e < lim ? 255 : 0; });
  seamCanvases.BurntGround = c;
  const m = new THREE.MeshStandardMaterial({ map: dataTex(c, a), normalMap: texFrom(normalCanvas(h, 2.5, true), false), roughnessMap: texFrom(mrCanvas(grayFrom(h, .9, .1)), false), roughness: 1, alphaTest: .5, side: DS });
  m.name = 'EV_BurntStubbleGround'; m.userData.uvScale = 1; return m; });
// puddled mud for the prepared row: ridge profile shared by texture + geometry
const RIDGES = [-2.95, -1.475, 0, 1.475, 2.95];
const ridgeH = x => { let m = 0; for (const c of RIDGES) { const w = Math.abs(c) > 2.9 && Math.abs(x) > Math.abs(c) ? .25 : .68, q = Math.abs(x - c) / w; m = Math.max(m, q < 1 ? (1 - q * q) * (1 - q * q) : 0); } return m; };
const pnz = makeNoise(707);
const puddledMat = () => once('mud', () => { const W = 512, H = 640; setSeed(707);
  const c = field(W, H, (u, v, o) => { const xs = u * 6.4 - 3.2, r = ridgeH(xs), n = pnz.fbm2(u, v, 6, 5), sm = pnz.fbm2(u * .5, v, 3, 3), f = pnz.n2(u * 160, v * 160, 160);
    let k = mix3([46, 38, 30], [84, 70, 54], r * .7 + n * .3); k = mix3(k, [104, 90, 70], sstep(.6, .8, sm) * r * .5); put(o, k, .9 + f * .18); });
  const h = field(W, H, (u, v, o) => { o[0] = o[1] = o[2] = 128 + (pnz.fbm2(u, v, 16, 4) - .5) * 90; });
  const x = c.getContext('2d'), z = h.getContext('2d');
  for (let i = 0; i < 900; i++) { const px = rnd() * W, py = rnd() * H, L = rr(8, 40), w = rr(1, 3), ex = rr(-3, 3), sc = `rgba(${rr(30, 60) | 0},${rr(26, 48) | 0},${rr(20, 36) | 0},.5)`; wrapV(H, py, L, Y => { x.strokeStyle = sc; x.lineWidth = w; x.beginPath(); x.moveTo(px, Y); x.lineTo(px + ex, Y + L); x.stroke(); }); }
  // boot prints walking down two furrows
  for (const fx of [-.7375, 2.2125]) { let py = rr(0, 60), sd = 1; while (py < H) { const px = (fx + 3.2) / 6.4 * W + sd * 9, Y0 = py;
      wrapV(H, Y0, 50, Y => { for (const [cx, cy, rx, ry, cc, hv] of [[px, Y, 13, 26, 'rgba(24,20,16,.75)', 30], [px, Y + 34, 11, 13, 'rgba(24,20,16,.75)', 30]]) { x.fillStyle = cc; x.beginPath(); x.ellipse(cx, cy, rx, ry, 0, 0, TAU); x.fill(); z.fillStyle = g3(hv); z.beginPath(); z.ellipse(cx, cy, rx, ry, 0, 0, TAU); z.fill(); z.strokeStyle = '#d0d0d0'; z.lineWidth = 3; z.stroke(); }
        z.fillStyle = '#555'; for (let t = 0; t < 6; t++) z.fillRect(px - 10, Y - 20 + t * 8, 20, 3); });
      py += rr(64, 80); sd = -sd; } }
  specks(x, W, H, 260, ['#6e6a3a', '#8a8048', '#2a221a'], .8, 2.2, .3, .7);
  seamCanvases.PuddledMud = c;
  return pbr('EV_PuddledMud', { color: c, height: h, k: 2.5, roughBase: .4, roughAmp: .3, uv: 1, rep: true }); });
// pack-4 mud recipe (terrain under the test field)
export const terrainMud = () => once('terrain', () => { const S = 1024, nz = makeNoise(104); setSeed(104); const vor = voronoi(14, 104);
  const crack = (u, v) => { const [a, b] = vor(u + (nz.fbm2(u, v, 8, 3) - .5) * .02, v + (nz.fbm2(v, u, 8, 3) - .5) * .02); return 1 - sstep(.02, .07, b - a); };
  const c = field(S, S, (u, v, o) => { const n = nz.fbm2(u, v, 5, 5), k = crack(u, v), f = nz.fbm2(u, v, 64, 2); let cc = mix3([118, 102, 86], [160, 146, 124], sstep(.4, .7, n)); cc = mix3(cc, [52, 42, 34], k * .9); put(o, cc, .88 + f * .2); });
  const h = field(S, S, (u, v, o) => { const [a] = vor(u, v), k = crack(u, v); o[0] = o[1] = o[2] = 170 - k * 150 + (nz.fbm2(u, v, 16, 3) - .5) * 30 - a * 20; });
  const x = c.getContext('2d'); x.lineCap = 'round'; for (let i = 0; i < 2500; i++) { const px = rnd() * S, py = rnd() * S, an = rnd() * TAU, L = rr(6, 26); wrapped(S, S, px, py, L, (X, Y) => { x.strokeStyle = `rgba(${rr(170, 214) | 0},${rr(140, 180) | 0},${rr(80, 110) | 0},.6)`; x.lineWidth = rr(1, 2.4); x.beginPath(); x.moveTo(X, Y); x.lineTo(X + Math.cos(an) * L, Y + Math.sin(an) * L); x.stroke(); }); }
  return pbr('Mud', { color: c, height: h, k: 3.5, roughBase: .88, roughAmp: .1, uv: .125 }); });
const bundMat = () => once('bund', () => { const W = 512, H = 1024, nz = makeNoise(808); setSeed(808);
  const zone = u => Math.abs(u * 2 - 1);
  const c = field(W, H, (u, v, o) => { const q = zone(u), n = nz.fbm2(u, v, 8, 5), f = nz.n2(u * 128, v * 256, 128, 256), cl = sstep(.62, .78, nz.fbm2(u + .2, v, 16, 3));
    let k = mix3([150, 98, 64], [176, 128, 90], n); k = mix3(k, [112, 74, 52], sstep(.8, 1, q) * .8); k = mix3(k, [96, 64, 46], cl * .6);
    const grass = sstep(.16, .22, q) * (1 - sstep(.4, .48, q)), path = 1 - sstep(.12, .2, q); k = mix3(k, mix3([112, 118, 60], [176, 160, 98], nz.fbm2(u, v, 6, 3)), grass * .9); k = mix3(k, [194, 168, 128], path * .85); put(o, k, .88 + f * .2); });
  const h = field(W, H, (u, v, o) => { o[0] = o[1] = o[2] = 128 + (nz.fbm2(u, v, 16, 4) - .5) * 100 + sstep(.62, .78, nz.fbm2(u + .2, v, 16, 3)) * 60; });
  const x = c.getContext('2d'), z = h.getContext('2d'); x.lineCap = z.lineCap = 'round';
  for (let i = 0; i < 9000; i++) { const u = rr(.25, .75), q = zone(u); if (q < .16 || q > .46) continue; const px = u * W, py = rnd() * H, an = rr(0, TAU), L = rr(6, 20), cc = `hsl(${rr(48, 80)},${rr(25, 45)}%,${rr(28, 52)}%)`, lw = rr(1.2, 2.6);
    wrapV(H, py, L, Y => { x.strokeStyle = cc; x.lineWidth = lw; x.beginPath(); x.moveTo(px, Y); x.lineTo(px + Math.cos(an) * L, Y + Math.sin(an) * L); x.stroke(); z.strokeStyle = '#eee'; z.lineWidth = 2; z.beginPath(); z.moveTo(px, Y); z.lineTo(px + Math.cos(an) * L, Y + Math.sin(an) * L); z.stroke(); }); }
  for (let i = 0; i < 700; i++) { const u = rnd() < .5 ? rr(0, .38) : rr(.62, 1), px = u * W, py = rnd() * H, r = rr(2, 7), fc = `rgba(${rr(90, 130) | 0},${rr(58, 84) | 0},${rr(40, 58) | 0},.7)`, ro = rnd() * 3; wrapV(H, py, r, Y => { x.fillStyle = fc; x.beginPath(); x.ellipse(px, Y, r, r * .7, ro, 0, TAU); x.fill(); z.fillStyle = '#fff'; z.beginPath(); z.arc(px, Y, r * .8, 0, TAU); z.fill(); }); }
  let py = 0, sd = 1; while (py < H) { const px = W / 2 + sd * 10; wrapV(H, py, 30, Y => { x.fillStyle = 'rgba(150,120,86,.55)'; x.beginPath(); x.ellipse(px, Y, 9, 22, 0, 0, TAU); x.fill(); z.fillStyle = '#666'; z.beginPath(); z.ellipse(px, Y, 9, 22, 0, 0, TAU); z.fill(); }); py += rr(70, 90); sd = -sd; }
  seamCanvases.BundEarth = c;
  return pbr('EV_BundEarth', { color: c, height: h, k: 3, roughBase: .9, roughAmp: .1, uv: 1 }); });
const charMat = () => once('char', () => { const S = 512, nz = makeNoise(909); setSeed(909);
  const c = field(S, S, (u, v, o) => { const n = nz.fbm2(u, v, 6, 4), as = sstep(.58, .75, nz.fbm2(u + .4, v, 4, 4)); put(o, mix3(mix3([24, 22, 20], [48, 42, 38], n), mix3([128, 126, 120], [208, 204, 196], nz.fbm2(u, v, 16, 2)), as * .85)); });
  const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 100 + (nz.fbm2(u, v, 12, 4) - .5) * 80; });
  const x = c.getContext('2d'), z = h.getContext('2d'); x.lineCap = z.lineCap = 'round';
  for (let i = 0; i < 4000; i++) { const px = rnd() * S, py = rnd() * S, an = Math.PI / 2 + rr(-.5, .5), L = rr(30, 120), w = rr(1.5, 3.5), cc = rnd() < .85 ? `rgb(${rr(14, 44) | 0},${rr(12, 38) | 0},${rr(10, 32) | 0})` : `rgb(${rr(120, 200) | 0},${rr(118, 196) | 0},${rr(112, 188) | 0})`;
    wrapped(S, S, px, py, L, (X, Y) => { x.strokeStyle = cc; x.lineWidth = w; x.beginPath(); x.moveTo(X, Y); x.lineTo(X + Math.cos(an) * L, Y + Math.sin(an) * L); x.stroke(); z.strokeStyle = '#ccc'; z.lineWidth = w; z.beginPath(); z.moveTo(X, Y); z.lineTo(X + Math.cos(an) * L, Y + Math.sin(an) * L); z.stroke(); }); }
  return pbr('EV_CharredStraw', { color: c, height: h, k: 2.5, roughBase: .92, roughAmp: .08, uv: .5 }); });
const baleEndMat = () => once('baleEnd', () => { const S = 512, c = cv(S), x = c.getContext('2d'), h = cv(S), z = h.getContext('2d'); setSeed(1201); x.fillStyle = '#5a4424'; x.fillRect(0, 0, S, S); z.fillStyle = '#202020'; z.fillRect(0, 0, S, S);
  for (let i = 0; i < 9000; i++) { const px = rnd() * S, py = rnd() * S, r = rr(1.5, 4.5), an = rnd() * TAU, cc = `hsl(${rr(36, 48)},${rr(40, 66)}%,${rr(36, 70)}%)`;
    wrapped(S, S, px, py, r * 3, (X, Y) => { x.fillStyle = cc; x.beginPath(); x.ellipse(X, Y, r, r * rr(.4, 1), an, 0, TAU); x.fill(); z.fillStyle = g3(rr(140, 255)); z.beginPath(); z.ellipse(X, Y, r, r * .7, an, 0, TAU); z.fill(); }); }
  x.lineCap = 'round'; for (let i = 0; i < 1400; i++) { const px = rnd() * S, py = rnd() * S, an = rr(-.4, .4), L = rr(10, 40); wrapped(S, S, px, py, L, (X, Y) => { x.strokeStyle = `hsl(${rr(38, 46)},${rr(40, 60)}%,${rr(44, 72)}%)`; x.lineWidth = rr(1.5, 3); x.beginPath(); x.moveTo(X, Y); x.lineTo(X + Math.cos(an) * L, Y + Math.sin(an) * L); x.stroke(); }); }
  return pbr('EV_BaleEnd', { color: c, height: h, k: 3, roughBase: .88, roughAmp: .1, uv: .5 }); });
const chopMat = () => once('chop', () => { const S = 512, c = cv(S), x = c.getContext('2d'), h = cv(S), z = h.getContext('2d'); setSeed(1301); x.fillStyle = '#4a3a20'; x.fillRect(0, 0, S, S); z.fillStyle = '#202020'; z.fillRect(0, 0, S, S); x.lineCap = z.lineCap = 'round';
  for (let i = 0; i < 12000; i++) { const px = rnd() * S, py = rnd() * S, an = rnd() * TAU, L = rr(8, 26), w = rr(2, 4.5), cc = `hsl(${rr(36, 48)},${rr(42, 70)}%,${rr(36, 72)}%)`, hv = rr(120, 255) | 0;
    wrapped(S, S, px, py, L, (X, Y) => { x.strokeStyle = cc; x.lineWidth = w; x.beginPath(); x.moveTo(X, Y); x.lineTo(X + Math.cos(an) * L, Y + Math.sin(an) * L); x.stroke(); z.strokeStyle = g3(hv); z.lineWidth = w; z.beginPath(); z.moveTo(X, Y); z.lineTo(X + Math.cos(an) * L, Y + Math.sin(an) * L); z.stroke(); }); }
  return pbr('EV_ChoppedStraw', { color: c, height: h, k: 3, roughBase: .85, roughAmp: .1, uv: .5 }); });
const wovenMat = () => once('woven', () => { const S = 256, nz = makeNoise(1401);
  const c = field(S, S, (u, v, o) => { const w = (Math.sin(u * TAU * 64) > 0) !== (Math.sin(v * TAU * 64) > 0) ? 1 : .93, n = nz.fbm2(u, v, 4, 3); put(o, [236, 236, 230], w * (.9 + n * .12)); });
  blotch(c.getContext('2d'), S, S, 6, [150, 140, 110], 10, 50, .18);
  const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 128 + Math.sin(u * TAU * 64) * Math.sin(v * TAU * 64) * 70; });
  return pbr('EV_WovenSack', { color: c, height: h, k: 1.2, roughBase: .55, roughAmp: .1, uv: 1, side: DS }); });
const biocharSackMat = () => once('biochar', () => { const W = 1024, H = 512, nz = makeNoise(1501); setSeed(1501);
  const c = field(W, H, (u, v, o) => { const w = (Math.sin(u * TAU * 400) > 0) !== (Math.sin(v * TAU * 180) > 0) ? 1 : .93; const dust = sstep(.5, .75, nz.fbm2(u, v, 5, 5)) * (.4 + .6 * v), n = nz.fbm2(u, v, 8, 3);
    put(o, mix3([232, 232, 226].map(q => q * w * (.92 + n * .1)), [34, 32, 30], dust * .85)); });
  const x = c.getContext('2d');
  for (let i = 0; i < 9; i++) { const px = rnd() * W, py = rr(.35, .95) * H, r = rr(30, 90); wrapped(W, H, px, py, r, (X, Y) => { const g = x.createRadialGradient(X, Y, 0, X, Y, r); g.addColorStop(0, 'rgba(20,18,16,.7)'); g.addColorStop(1, 'rgba(20,18,16,0)'); x.fillStyle = g; x.fillRect(X - r, Y - r, 2 * r, 2 * r); }); }
  for (let i = 0; i < 5; i++) { const px = W * rr(.3, .7), py = H * rr(.4, .8); x.fillStyle = 'rgba(22,20,18,.55)'; for (let f = 0; f < 4; f++) { x.beginPath(); x.ellipse(px + f * 9, py + rr(-3, 3), 4, 13, .3, 0, TAU); x.fill(); } }
  // stencil on the front (u = 0.5 faces +z)
  x.save(); x.translate(W / 2, H * .5); x.scale(.74, 1); x.font = '700 78px "IBM Plex Sans Condensed",sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillStyle = 'rgba(26,26,26,.92)'; x.fillText('BIOCHAR', 0, 0);
  x.globalCompositeOperation = 'destination-out'; x.fillStyle = '#000'; const tw = x.measureText('BIOCHAR').width; for (let i = 0; i < 7; i++) x.fillRect(-tw / 2 + (i + .5) * tw / 7 - 1.5, -6, 3, 12); x.restore();
  x.globalCompositeOperation = 'source-over'; x.fillStyle = 'rgba(232,232,226,1)'; for (let i = 0; i < 400; i++) x.fillRect(W / 2 + rr(-190, 190), H * .5 + rr(-42, 42), rr(1, 3), rr(1, 3));
  specks(x, W, H, 900, ['#1a1816', '#2c2a28'], .6, 2.4, .2, .7);
  const h = field(W, H, (u, v, o) => { o[0] = o[1] = o[2] = 128 + Math.sin(u * TAU * 400) * Math.sin(v * TAU * 180) * 60; });
  return pbr('EV_BiocharSack', { color: c, height: h, k: 1, roughBase: .6, roughAmp: .1, uv: 1, rep: false }); });
const crateMat = () => once('crate', () => { const S = 512, nz = makeNoise(1601);
  const c = field(S, S, (u, v, o) => { const g = nz.fbm2(u * 4, v * .3, 8, 5), ring = .5 + .5 * Math.sin((g * 10 + u * 30) * 1.3); put(o, [206, 172, 124], .82 + ring * .14 + (g - .5) * .2); });
  blotch(c.getContext('2d'), S, S, 10, [120, 100, 76], 10, 60, .25); specks(c.getContext('2d'), S, S, 300, ['#6a5034'], .6, 1.6, .2, .6);
  const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 128 + (nz.fbm2(u * 4, v * .3, 16, 4) - .5) * 120; });
  return pbr('EV_CrateWood', { color: c, height: h, k: 2, roughBase: .85, roughAmp: .15, uv: 1 }); });
const pelletMat = () => once('pellet', () => { const S = 512, c = cv(S), x = c.getContext('2d'), h = cv(S), z = h.getContext('2d'); setSeed(1701); x.fillStyle = '#3e2c1a'; x.fillRect(0, 0, S, S); z.fillStyle = '#101010'; z.fillRect(0, 0, S, S); x.lineCap = z.lineCap = 'round';
  for (let i = 0; i < 2600; i++) { const px = rnd() * S, py = rnd() * S, an = rnd() * TAU, L = rr(6, 26), dx = Math.cos(an) * L, dy = Math.sin(an) * L, tt = rr(.85, 1.1), cc = [128 * tt, 94 * tt, 58 * tt];
    wrapped(S, S, px, py, L + 8, (X, Y) => { x.strokeStyle = col(cc, .6); x.lineWidth = 12; x.beginPath(); x.moveTo(X, Y); x.lineTo(X + dx, Y + dy); x.stroke(); x.strokeStyle = col(cc); x.lineWidth = 9; x.stroke(); x.strokeStyle = col(cc, 1.25); x.lineWidth = 3; x.beginPath(); x.moveTo(X - 2, Y - 2); x.lineTo(X + dx - 2, Y + dy - 2); x.stroke();
      z.strokeStyle = '#999'; z.lineWidth = 11; z.beginPath(); z.moveTo(X, Y); z.lineTo(X + dx, Y + dy); z.stroke(); z.strokeStyle = '#eee'; z.lineWidth = 5; z.stroke(); }); }
  return pbr('EV_StrawPellets', { color: c, height: h, k: 3, roughBase: .7, roughAmp: .2, uv: 1 }); });
const stencilMat = () => once('stencil', () => { const W = 512, H = 128, c = cv(W, H), x = c.getContext('2d'); x.font = '700 96px "IBM Plex Sans Condensed",sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillStyle = '#1c1c1c'; x.fillText('PELLET', W / 2, H / 2 + 4);
  x.globalCompositeOperation = 'destination-out'; const tw = x.measureText('PELLET').width; for (let i = 0; i < 6; i++) x.fillRect(W / 2 - tw / 2 + (i + .5) * tw / 6 - 2, H / 2 - 4, 4, 14); for (let i = 0; i < 500; i++) x.fillRect(rnd() * W, rnd() * H, rr(1, 3), rr(1, 3)); x.globalCompositeOperation = 'source-over';
  const h = cv(W, H); h.getContext('2d').fillStyle = '#808080'; h.getContext('2d').fillRect(0, 0, W, H);
  return pbr('EV_StencilPellet', { color: c, height: h, k: .5, roughBase: .6, roughAmp: 0, alpha: true, rep: false }); });
const mushMat = () => once('mush', () => { const W = 128, H = 256, nz = makeNoise(1801);
  const c = field(W, H, (u, v, o) => { const t = 1 - v, s = nz.n2(u * 24, v * 4, 24, 4), k = t < .3 ? mix3([224, 216, 202], [184, 174, 160], t / .3) : t < .62 ? mix3([184, 174, 160], [98, 88, 78], (t - .3) / .32) : mix3([98, 88, 78], [58, 52, 46], (t - .62) / .38); put(o, k, .92 + s * .12); });
  const h = field(W, H, (u, v, o) => { o[0] = o[1] = o[2] = 128 + (nz.n2(u * 24, v * 4, 24, 4) - .5) * 80; });
  return pbr('EV_StrawMushroom', { color: c, height: h, k: 1, roughBase: .55, roughAmp: .15, uv: 1, rep: false }); });
const basketMat = () => once('basket', () => { const S = 256, nz = makeNoise(1901);
  const c = field(S, S, (u, v, o) => { const a = Math.floor(u * 16), b = Math.floor(v * 16), over = (a + b) % 2 === 0, fu = (u * 16) % 1, fv = (v * 16) % 1, edge = over ? Math.min(fv, 1 - fv) : Math.min(fu, 1 - fu), n = nz.fbm2(u, v, 8, 3);
    put(o, over ? [188, 150, 92] : [166, 128, 74], (.8 + n * .3) * (.6 + .4 * sstep(0, .12, edge))); });
  const h = field(S, S, (u, v, o) => { const a = Math.floor(u * 16), b = Math.floor(v * 16), over = (a + b) % 2 === 0, fu = (u * 16) % 1, fv = (v * 16) % 1; o[0] = o[1] = o[2] = over ? 120 + Math.sin(fv * Math.PI) * 120 : 120 + Math.sin(fu * Math.PI) * 120; });
  return pbr('EV_BambooWeave', { color: c, height: h, k: 2, roughBase: .7, roughAmp: .2, uv: 2, side: DS }); });
const twineMat = () => once('twine', () => simpleSet('EV_BaleTwine', 0xd2702a, { rough: .45, dirt: .1, bump: 30 }));
const stringMat = () => once('string', () => simpleSet('EV_SackString', 0x2f5788, { rough: .6, dirt: .1, bump: 30 }));
const clodMat = () => once('clod', () => simpleSet('EV_EarthClod', 0x8a5c40, { rough: .95, bump: 90 }));
const tinted = (base, name, hex, rough) => once(name, () => { const m = base.clone(); m.name = name; m.color = new THREE.Color(hex); if (rough) m.roughness = rough; m.userData = { ...base.userData }; return m; });

/* ================= row segments ================= */
const ROWNAME = { seedling: 'RiceSeedling', growing: 'RiceGrowing', heading: 'RiceHeading', ripe: 'RiceRipe', stubble: 'Stubble', burnt: 'StubbleBurnt' };
export const ROW_H = { seedling: 1, growing: 2.2, heading: 3.2, ripe: 3.4, stubble: 1.2, burnt: .8, prepared: .4 };
const pf = [0, .29, .29 + .71 / 3, .29 + 1.42 / 3, 1];
const HILL = {
  seedling(P, b, vg) { const m = RM('Seedling'); P('Plants', culmG(b, b.clone().add(new V3(rr(-.02, .02), .22 * vg, rr(-.02, .02))), .03, .022, 3), m);
    const n = 3 + (rnd() * 3 | 0), a0 = rnd() * TAU; for (let k = 0; k < n; k++) P('Plants', leafRib(b.clone().add(new V3(0, rr(.04, .16), 0)), a0 + k * TAU / n + rr(-.5, .5), rr(.45, .82) * vg, rr(.12, .5), rr(.25, .9), .065, 4, rr(-.4, .4)), m); },
  growing(P, b, vg) { const m = RM('Growing'); P('Plants', culmG(b, b.clone().add(new V3(0, .5, 0)), .08, .055, 4), m);
    const a0 = rnd() * Math.PI; for (let k = 0; k < 3; k++) P('Plants', fanG(b, a0 + k * Math.PI / 3 + (rnd() < .5 ? 0 : Math.PI), rr(1.5, 2.0) * vg, rr(1.2, 1.5), rr(-.12, .12), rr(.15, .4)), m);
    for (let k = 0; k < 3; k++) P('Plants', leafRib(b.clone().add(new V3(0, rr(.3, .8), 0)), rnd() * TAU, rr(1.1, 1.55) * vg, rr(.35, .65), rr(.5, 1.1), .1, 4, rr(-.5, .5)), m); },
  heading(P, b, vg) { const m = RM('Heading'), mp = RM('HeadingPanicle'); P('Plants', culmG(b, b.clone().add(new V3(0, .65, 0)), .085, .06, 3), m);
    const a0 = rnd() * Math.PI; for (let k = 0; k < 3; k++) P('Plants', fanG(b, a0 + k * Math.PI / 3 + (rnd() < .5 ? 0 : Math.PI), rr(2.15, 2.6) * vg, rr(1.0, 1.25), rr(-.08, .08), rr(.08, .22)), m);
    for (let k = 0; k < 2; k++) P('Plants', leafRib(b.clone().add(new V3(0, rr(1.3, 1.75), 0)), rnd() * TAU, rr(.9, 1.25), rr(.12, .35), rr(.15, .45), .11, 4, rr(-.4, .4)), m);
    for (let k = 0; k < 2; k++) { const d = hdir(rnd() * TAU), bs = b.clone().add(new V3(rr(-.1, .1), rr(2.2, 2.42) * vg, rr(-.1, .1))), ln = rr(.02, .16); P('Panicles', stripG(arc(bs, d, rr(.5, .72), 3, () => ln), perp(d), .2, rnd() < .5 ? 'PAN1' : 'PAN2', .6, .99), mp); } },
  ripe(P, b, vg) { const m = RM('RipeStraw'), mg = RM('RipeGrain'); P('Plants', culmG(b, b.clone().add(new V3(rr(-.04, .04), 1.2, rr(-.04, .04))), .055, .04, 3), m);
    const a0 = rnd() * Math.PI; for (let k = 0; k < 2; k++) P('Plants', fanG(b, a0 + k * Math.PI / 2 + (rnd() < .5 ? 0 : Math.PI), rr(1.85, 2.3) * vg, rr(1.0, 1.2), rr(-.1, .1), rr(.3, .55)), m);
    const az0 = rnd() * TAU; for (let k = 0; k < 3; k++) { const az = az0 + k * TAU / 3 + rr(-.6, .6), d = hdir(az), al = rr(.04, .24), Ls = rr(1.0, 1.22) * vg, Lp = rr(.82, .98), a1 = al + rr(.55, .85), a2 = a1 + rr(.7, .9), a3 = a2 + rr(.45, .7);
      const p0 = b.clone().add(new V3(rr(-.05, .05), rr(1.45, 1.62), rr(-.05, .05))), p1 = p0.clone().addScaledVector(d, Math.sin(al) * Ls); p1.y += Math.cos(al) * Ls; const pts = [p0, p1];
      for (const an of [a1, a2, a3]) { const q = pts[pts.length - 1].clone().addScaledVector(d, Math.sin(an) * Lp / 3); q.y += Math.cos(an) * Lp / 3; pts.push(q); }
      const s = perp(d).applyAxisAngle(d, rr(-.4, .4)); P('Panicles', stripG(pts, s, .22, rnd() < .62 ? 'PAN1' : 'PAN2', pf), mg); } },
  stubble(P, b) { const m = RM('Stubble'), a0 = rnd() * Math.PI; for (let k = 0; k < 2; k++) P('Stubs', fanG(b, a0 + k * Math.PI / 2, rr(.95, 1.15), rr(.42, .52), rr(-.06, .06), 0, 'STUB', 2), m);
    for (let k = 0; k < 3; k++) { const o = b.clone().add(new V3(rr(-.08, .08), 0, rr(-.08, .08))); P('Stubs', culmG(o, o.clone().add(new V3(rr(-.06, .06), rr(.7, 1.1), rr(-.06, .06))), .03, .026, 3), m); } },
  burnt(P, b) { const m = RM('Charred'); if (rnd() < .12) { P('Stubs', culmG(b, b.clone().add(new V3(0, rr(.08, .16), 0)), .06, .05, 3), m); return; }
    P('Stubs', fanG(b, rnd() * Math.PI, rr(.4, .62), .45, rr(-.08, .08), 0, 'STUB', 2), m);
    for (let k = 0; k < 2; k++) { const o = b.clone().add(new V3(rr(-.08, .08), 0, rr(-.08, .08))); P('Stubs', culmG(o, o.clone().add(new V3(rr(-.05, .05), rr(.2, .66), rr(-.05, .05))), .032, .026, 3), m); } },
};
export const HILL_PITCH = .8;
export function riceRow(stage, v, seed) {
  const HM = ROW_H[stage];
  return makeAsset(`EV_${ROWNAME[stage]}_${v}`, seed, part => {
    for (let j = 0; j < 10; j++) for (let i = 0; i < 8; i++) {
      const bx = -2.8 + i * HILL_PITCH + rr(-.06, .06), bz = -3.6 + j * HILL_PITCH + rr(-.05, .05), vg = rr(.88, 1.08), L = [];
      HILL[stage]((pn, g, m) => L.push([pn, g, m]), new V3(bx, 0, bz), vg);
      let rot = null; if (stage === 'ripe' && v === 'B' && rnd() < .11) { const az = rnd() < .7 ? (bz > 0 ? -Math.PI / 2 : Math.PI / 2) + rr(-.7, .7) : rr(0, TAU), d = hdir(az), ax = new V3(d.z, 0, -d.x).normalize();
        rot = new THREE.Matrix4().makeTranslation(bx, 0, bz).multiply(new THREE.Matrix4().makeRotationAxis(ax, rr(.85, 1.25))).multiply(new THREE.Matrix4().makeTranslation(-bx, 0, -bz)); }
      for (const [pn, g, m] of L) { if (rot) g.applyMatrix4(rot); fit(g, bx, bz, HM); add(part(pn), g, m); } }
    if (stage === 'seedling' || stage === 'growing') add(part('Water'), waterG(6.4, 8, .15), waterMat());
    if (stage === 'stubble') { const m = RM('Straw'); for (let i = 0; i < 28; i++) { const c = new V3(rr(-2.6, 2.6), rr(.025, .05), rr(-3.5, 3.5)), d = hdir(rnd() * TAU), Lc = rr(.5, .75), s = perp(d); s.y = rr(-.05, .05);
        const g = stripG([c.clone().addScaledVector(d, -Lc / 2), c.clone().addScaledVector(d, Lc / 2)], s.normalize(), rr(1.0, 1.5), 'STRAW', 0, 1); fit(g, c.x, c.z, HM); add(part('Litter'), g, m); } }
    if (stage === 'burnt') { const g = sweepG((s, t) => { const x = lerp(-3.2, 3.2, s), z = lerp(4, -4, t), e = Math.abs(s - .5) * 2; return new V3(x, .015 + (bAsh(s, t) * .06 + (bnz.fbm2(s, t, 8, 3) - .5) * .02) * (1 - sstep(.8, 1, e)), z); }, 16, 20, (s, t) => [s, 1 - t]);
      add(part('Ground'), g, burntMat()); const m = RM('Scorched');
      for (let i = 0; i < 12; i++) { const c = new V3(rr(-2.5, 2.5), rr(.06, .1), rr(-3.4, 3.4)), d = hdir(rnd() * TAU), Lc = rr(.4, .6); const g2 = stripG([c.clone().addScaledVector(d, -Lc / 2), c.clone().addScaledVector(d, Lc / 2)], perp(d), rr(.9, 1.3), 'STRAW', 0, 1); fit(g2, c.x, c.z, HM); add(part('Strands'), g2, m); } }
  });
}
export function preparedRow(v, seed) {
  return makeAsset(`EV_PreparedRow_${v}`, seed, part => {
    const hfn = (x, t) => { const e = Math.abs(x) / 3.2, edge = 1 - sstep(.93, 1, e); return (.02 + .27 * ridgeH(x) + (pnz.fbm2((x + 3.2) / 6.4, t, 6, 4) - .5) * .09 + Math.max(0, pnz.fbm2((x + 3.2) / 6.4 + .5, t, 14, 3) - .62) * .25) * edge; };
    add(part('Ground'), sweepG((s, t) => { const x = lerp(-3.2, 3.2, s); return new V3(x, Math.max(0, hfn(x, t)), lerp(4, -4, t)); }, 36, 24, (s, t) => [s * 6.4 / 6.4, 1 - t]), puddledMat());
    const g = waterG(5.9, 8, .11); add(part('Water'), g, waterMat());
    const m = RM('Weed'); for (let i = 0; i < 7; i++) { const x = pick(RIDGES.slice(1, 4)) + rr(-.2, .2), z = rr(-3.4, 3.4), b = new V3(x, hfn(x, (4 - z) / 8) - .02, z);
      for (let k = 0; k < 5; k++) { const lg = leafRib(b, rnd() * TAU, rr(.22, .4), rr(.2, .7), rr(.4, 1), .07, 3, rr(-.3, .3)); fit(lg, x, z, .4); add(part('Weeds'), lg, m); } }
  });
}

/* ================= straw ================= */
function strand(P, base, d, L, lean, archA, w, f0, f1, n = 3) { P(stripG(arc(base, d, L, n, t => lean + archA * t), perp(d), w, 'CULM', f0, f1)); }
function radialFit(g, R, cx = 0, cz = 0) { const p = g.attributes.position; let rm = 0; for (let i = 0; i < p.count; i++) rm = Math.max(rm, Math.hypot(p.getX(i) - cx, p.getZ(i) - cz)); if (rm <= R) return g; const k = R / rm; for (let i = 0; i < p.count; i++) p.setXYZ(i, cx + (p.getX(i) - cx) * k, p.getY(i), cz + (p.getZ(i) - cz) * k); g.computeVertexNormals(); return g; }
export function strawSheaf(v, seed) {
  const rag = v === 'C', H = v === 'C' ? 4.35 : v === 'B' ? 4.45 : 4.6, bY = H * .64;
  const a = makeAsset(`EV_StrawSheaf_${v}`, seed, part => {
    const mS = RM('Straw'), add2 = (pn, m) => g => add(part(pn), g, m);
    const prof = [[0, 0], [1.0, 0], [.92, .18], [.72, .6], [.55, 1.2], [.44, 2.0], [.36, bY - .25], [.3, bY], [.36, bY + .22], [.48, bY + .55], [.46, bY + .85], [.26, bY + 1.05], [0, bY + 1.12]];
    add(part('Body'), latheG(prof, 28, { amp: rag ? .13 : .07, f: 1.6, so: seed * .1, studs: true }), lib.straw);
    const band = []; for (let i = 0; i <= 40; i++) { const t = i / 40 * TAU; band.push(new V3(Math.cos(t) * .335, bY + Math.sin(t * 3) * .012, Math.sin(t) * .335)); }
    add(part('Band'), tubeG(band, band.map(() => .05), 5, { tile: .5, wob: (i, s, an) => .3 * Math.sin(an + i * 1.4) }), lib.strawSun);
    add(part('Band'), blobG(.08, 1, .3, 2, seed, [1.3, 1, .8]), lib.strawSun).position.set(0, bY, .36);
    const S = add2('Strands', mS);
    for (let i = 0; i < 70; i++) { const az = rnd() * TAU, d = hdir(az), y0 = rr(.25, .9), r0 = lerp(.92, .7, (y0 - .18) / .42) - .02, b = d.clone().multiplyScalar(r0); b.y = y0; const g = stripG(arc(b, d, rr(.45, .7), 3, t => 2.2 + .5 * t), perp(d), .045, 'CULM', .72, 1); radialFit(g, 1.18); S(g); }
    for (let i = 0; i < 46; i++) { const az = rnd() * TAU, d = hdir(az), y0 = rr(.7, bY - .4), b = d.clone().multiplyScalar(lerp(.6, .38, (y0 - .6) / (bY - 1)) + .02); b.y = y0; S(stripG(arc(b, d, rr(.6, 1.1), 3, () => rr(-.06, .04)), perp(d), .04, 'CULM', .5, .15)); }
    const nTop = rag ? 120 : 100; for (let i = 0; i < nTop; i++) { const az = rnd() * TAU, d = hdir(az), b = d.clone().multiplyScalar(rr(.22, .34)); b.y = bY + rr(.05, .3); const out = rnd(), lean = lerp(.08, rag ? 1.3 : .95, out), L = rr(1.15, 1.6) * (rag ? rr(.7, 1.15) : 1);
      const g = stripG(arc(b, d, L, 4, t => lean + (rag ? rr(.3, 1.2) : .25 + .7 * out) * t * t), perp(d).applyAxisAngle(d, rr(-.5, .5)), rr(.026, .036), 'CULM', .55, .02); radialFit(g, v === 'B' ? .8 : 1.18); fit(g, 0, 0, 4.75, 9, 9); S(g); }
    for (let i = 0; i < 20; i++) { const az = i / 20 * TAU + rr(-.2, .2), d = hdir(az), b = d.clone().multiplyScalar(.22); b.y = bY + .1 + (i % 2) * .25; const g = fanG(b, az, rr(1.35, 1.75) * (rag ? rr(.8, 1.1) : 1), rr(.9, 1.15), rr(.1, .4), rr(.25, .5), 'TUFT', 3); radialFit(g, v === 'B' ? .8 : 1.18); fit(g, 0, 0, 4.75, 9, 9); S(g); }
    if (v === 'A') { const mp = RM('EmptyPanicle'); for (let i = 0; i < 8; i++) { const d = hdir(rnd() * TAU), p0 = d.clone().multiplyScalar(.3); p0.y = bY + .3; const pts = [p0]; for (const [an, L] of [[rr(.2, .5), 1.0], [1.3, .3], [2.1, .3], [2.6, .3]]) { const q = pts[pts.length - 1].clone().addScaledVector(d, Math.sin(an) * L); q.y += Math.cos(an) * L; pts.push(q); }
        const g = stripG(pts, perp(d), .17, 'PAN2', pf); radialFit(g, 1.18); fit(g, 0, 0, 4.75, 9, 9); add(part('Panicles'), g, mp); } }
  });
  const shear = v === 'B' ? new THREE.Matrix4().set(1, Math.tan(5 * DEG), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : null;
  return postFit(a, 2.4, 4.8, 2.4, shear);
}
export function strawSheafBurnt(v, seed) {
  const a = makeAsset(`EV_StrawSheafBurnt_${v}`, seed, part => {
    const mc = charMat(), ms = RM('Charred');
    add(part('Body'), latheG([[0, 0], [1.1, 0], [1.05, .18], [.92, .5], [.72, .9], [.5, 1.2], [.3, 1.4], [0, 1.45]], 24, { amp: .2, f: 1.3, so: 3, yAmp: .25, studs: true }), mc).position.x = .08;
    add(part('Body'), latheG([[0, 1.1], [.34, 1.12], [.27, 1.6], [.2, 2.0], [.12, 2.32], [0, 2.4]], 20, { amp: .18, f: 2.5, so: 7, studs: true }), mc).rotation.z = .08;
    for (const [t0, t1, y] of [[.3, 1.6, .95], [2.4, 3.6, 1.0]]) { const pts = []; for (let i = 0; i <= 10; i++) { const t = lerp(t0, t1, i / 10), r = .78 + .06 * Math.sin(i); pts.push(new V3(Math.cos(t) * r, y - .25 * Math.sin(i / 10 * Math.PI) + rr(-.03, .03), Math.sin(t) * r)); } add(part('Band'), tubeG(pts, pts.map((_, i) => .045 * (1 - Math.abs(i - 5) / 12)), 4, { tile: .5 }), mc); }
    const P = g => add(part('Strands'), g, ms);
    for (let i = 0; i < 64; i++) { const d = hdir(rnd() * TAU), b = d.clone().multiplyScalar(rr(.8, 1.0)); b.y = rr(.03, .25); const g = stripG(arc(b, d, rr(.3, .6), 3, () => rr(1.45, 1.62)), perp(d), .045, 'CULM', .9, .4); radialFit(g, 1.18); P(g); }
    for (let i = 0; i < 72; i++) { const d = hdir(rnd() * TAU), b = d.clone().multiplyScalar(rr(.1, .25)); b.y = rr(1.6, 2.2); const g = stripG(arc(b, d, rr(.3, .7), 3, t => rr(.2, 1.2) + t * rr(0, 1)), perp(d), .04, 'CULM', .6, .2); fit(g, 0, 0, 2.48, 9, 9); P(g); }
  });
  return postFit(a, 2.4, 2.5, 2.4);
}
export function strawWindrow(v, seed) {
  return makeAsset(`EV_StrawWindrow_${v}`, seed, part => { const nz = makeNoise(seed);
    const fn = (s, t) => { const z = lerp(4, -4, t), hc = .58 + .2 * nz.fbm2(.3, t, 3, 3), wc = 1.78 + .18 * (nz.fbm2(.7, t, 4, 3) - .5) * 2, q = (s * 2 - 1), x = q * wc + (nz.fbm2(.1, t, 2, 3) - .5) * .25, lump = (nz.fbm2(s, t, 6, 4) - .5) * .22;
      return new V3(x, Math.max(0, Math.pow(Math.max(0, 1 - q * q), .65) * hc + lump * (1 - q * q)), z); };
    add(part('Body'), sweepG(fn, 16, 48, (s, t, p) => [p.x, p.z]), lib.straw);
    const m = RM('Straw');
    for (let i = 0; i < 170; i++) { const s = rr(.08, .92), t = rr(.05, .95), b = fn(s, t); b.y -= .03; const d = hdir(rnd() < .7 ? Math.PI / 2 + rr(-.5, .5) : rnd() * TAU), g = stripG(arc(b, d, rr(.5, 1.1), 3, () => rr(1.35, 1.75)), perp(d).applyAxisAngle(d, rr(-1, 1)), .04, 'CULM', .5, .05); fit(g, b.x, b.z, 1, 1.98, 3.985); add(part('Strands'), g, m); }
    for (let i = 0; i < 34; i++) { const s = rr(.2, .8), t = rr(.08, .92), b = fn(s, t); b.y -= .05; const az = rnd() * TAU, g = fanG(b, az, rr(.35, .55), rr(.6, .9), rr(.6, 1.2) * (s < .5 ? -1 : 1), .3, 'TUFT', 2); fit(g, b.x, b.z, 1, 1.98, 3.985); add(part('Strands'), g, m); }
  });
}
export function strawBale(v, seed) {
  const a = makeAsset(`EV_StrawBaleSquare_${v}`, seed, part => {
    const W = 2.92, H = 1.7, D = 1.92, box = new THREE.BoxGeometry(W, H, D, 12, 7, 8), p = box.attributes.position, uv = box.attributes.uv;
    for (let i = 0; i < p.count; i++) { let x = p.getX(i), y = p.getY(i), z = p.getZ(i); const qx = x / (W / 2), qy = y / (H / 2), qz = z / (D / 2), c = qx * qx * qy * qy + qy * qy * qz * qz + qx * qx * qz * qz, k = 1 - .05 * c, nn = N.fbm3(x * 3, y * 3, z * 3, 3) - .5;
      x *= k * (1 + .012 * (1 - qy * qy) * (1 - qz * qz)); y *= k * (1 + .02 * (1 - qx * qx) * (1 - qz * qz)); z *= k * (1 + .035 * (1 - qx * qx) * (1 - qy * qy)); const r = Math.hypot(x, y, z) || 1; p.setXYZ(i, x + x / r * nn * .05, y + y / r * nn * .05 + H / 2, z + z / r * nn * .05); }
    const dims = [[D, H], [D, H], [W, D], [W, D], [W, H], [W, H]];
    box.computeVertexNormals();
    const faces = box.groups.map((gr, gi) => { const g = new THREE.BufferGeometry(); g.setAttribute('position', p.clone()); g.setAttribute('normal', box.attributes.normal.clone()); const u2 = uv.clone(); g.setAttribute('uv', u2); const idx = []; for (let k = gr.start; k < gr.start + gr.count; k++) idx.push(box.index.getX(k)); g.setIndex(idx);
      const used = new Set(idx); for (const vi of used) u2.setXY(vi, uv.getX(vi) * dims[gi][0], uv.getY(vi) * dims[gi][1]); return g; });
    faces.forEach((g, gi) => add(part(gi < 2 ? 'Ends' : 'Bale'), g, gi < 2 ? baleEndMat() : lib.straw));
    for (const zc of [-.48, .48]) { const pts = [], hx = W / 2 * .99 + .005, hy = H / 2 * .99 + .02, rc = .14; const path = [[-hx, -hy + rc + .05, 'L'], [-hx, hy - rc], [-hx + rc, hy], [hx - rc, hy], [hx, hy - rc], [hx, -hy + rc + .05]];
      for (let i = 0; i < path.length - 1; i++) { const [x0, y0] = path[i], [x1, y1] = path[i + 1], n = i % 2 === 0 ? 8 : 3; for (let k = 0; k < n; k++) { const t = k / n; pts.push(new V3(lerp(x0, x1, t), lerp(y0, y1, t) + H / 2, zc)); } } pts.push(new V3(hx, -hy + rc + .05 + H / 2, zc));
      add(part('Twine'), tubeG(pts, pts.map(() => .024), 4, { tile: .2 }), twineMat()); }
    const m = RM('Straw'); for (let i = 0; i < 54; i++) { const end = rnd() < .6, sx = rnd() < .5 ? -1 : 1, b = end ? new V3(sx * W / 2 * .95, rr(.15, H - .15), rr(-D / 2 + .15, D / 2 - .15)) : new V3(rr(-W / 2 + .2, W / 2 - .2), H * .99, rr(-D / 2 + .2, D / 2 - .2));
      const d = end ? new V3(sx, 0, 0) : hdir(rnd() * TAU); add(part('Strands'), stripG(arc(b, d, rr(.25, .5), 2, () => end ? rr(1.2, 1.9) : rr(1.1, 1.5)), perp(d).lengthSq() ? perp(d) : new V3(0, 0, 1), .04, 'CULM', .5, .2), m); }
  });
  return postFit(a, 3, 1.8, 2);
}
export function bund(v, seed) {
  return makeAsset(`EV_Bund_${v}`, seed, part => { const nz = makeNoise(seed);
    const fn = (s, t) => { const x0 = lerp(-1.1, 1.1, s), q = Math.abs(x0) / 1.1, z = lerp(4, -4, t), cr = (nz.fbm2(s, t, 8, 4) - .5) * 2 * sstep(.3, .6, q) * (1 - sstep(.9, 1, q)), y = 1.46 * Math.pow(1 - sstep(.38, 1, q), .85) - .045 * (1 - sstep(0, .2, q)) + (nz.fbm2(s + .5, t, 16, 3) - .5) * .03;
      return new V3(clamp(x0 + Math.sign(x0) * cr * .07, -1.1, 1.1), Math.max(0, y + cr * .05), z); };
    add(part('Earth'), sweepG(fn, 18, 40, (s, t) => [s, 1 - t]), bundMat());
    const gm = FM.grassCard; for (let i = 0; i < 34; i++) { const sd = rnd() < .5 ? -1 : 1, q = rr(.2, .44), x = sd * q * 1.1, z = rr(-3.6, 3.6), y = fn((x + 1.1) / 2.2, (4 - z) / 8).y - .03;
      for (let k = 0; k < 2; k++) { const w = rr(.4, .62), h = Math.min(rr(.18, .26), 1.66 - y); const o = add(part('Grass'), cardG(w, h), gm, [x, y, z], [0, rnd() * Math.PI, 0]); } }
    const m = RM('Weed'); for (let i = 0; i < 5; i++) { const sd = rnd() < .5 ? -1 : 1, x = sd * rr(.5, .75), z = rr(-3.3, 3.3), b = new V3(x, fn((x + 1.1) / 2.2, (4 - z) / 8).y - .02, z); for (let k = 0; k < 4; k++) { const g = leafRib(b, rnd() * TAU, rr(.18, .3), rr(.4, 1), rr(.3, .8), .07, 3); fit(g, x, z, 1.7, 1.1, 3.985); add(part('Weeds'), g, m); } }
    for (let i = 0; i < 10; i++) { const r = rr(.07, .14), sd = rnd() < .5 ? -1 : 1; add(part('Clods'), blobG(r, 0, .35, 2, i + seed, [1, .7, 1]), clodMat(), [sd * (1.1 - r * 1.1), r * .75, rr(-3.8 + r, 3.8 - r)]); }
  });
}

/* ================= factory items ================= */
function bundle(name, seed, wet) {
  const a = makeAsset(name, seed, part => {
    const R = wet ? 1 : 1.16, prof = [[0, -.6], [.17 * R, -.6], [.24 * R, -.5], [.26 * R, -.25], [.2, -.05], [.175, 0], [.2, .05], [.27 * R, .25], [.3 * R, .45], [.27 * R, .58], [0, .61]];
    const mb = wet ? tinted(lib.straw, 'EV_StrawWet', 0x86784e, .55) : lib.straw;
    add(part('Bundle'), latheG(prof, 18, { amp: wet ? .12 : .07, f: wet ? 3 : 4, so: seed * .01, studs: true }), mb);
    add(part('Band'), new THREE.TorusGeometry(.185, .032, 6, 18).rotateX(Math.PI / 2), wet ? mb : lib.strawSun);
    const ms = RM(wet ? 'StrawWet' : 'StrawDry'), n = wet ? 46 : 92;
    for (let i = 0; i < n; i++) { const top = rnd() < .55, d = hdir(rnd() * TAU), b = d.clone().multiplyScalar(rr(.12, .26) * R); b.y = top ? .56 : -.57; const spread = wet ? rr(.05, .35) : rr(.2, .9);
      const g = stripG(arc(b, d, rr(.1, wet ? .16 : .26), 3, t => (top ? 0 : Math.PI) + (top ? 1 : -1) * spread * (1 + t)), perp(d), wet ? .035 : .03, 'CULM', .5, .1); add(part('Strands'), g, ms); }
  });
  return postFit(a, 1.3, 1.1, 1.3, new THREE.Matrix4().makeRotationZ(Math.PI / 2));
}
export const itemWetStraw = (v, s) => bundle(`EV_ItemWetStraw_${v}`, s, true);
export const itemDryStraw = (v, s) => bundle(`EV_ItemDryStraw_${v}`, s, false);
export function itemShredded(v, seed) {
  const a = makeAsset(`EV_ItemShreddedStraw_${v}`, seed, part => {
    add(part('Sack'), latheG([[0, 0], [.44, 0], [.52, .06], [.56, .3], [.57, .55], [.55, .72], [.56, .76], [.62, .8], [.64, .76], [.6, .64]], 24, { amp: .05, f: 2.5, so: 2, sq: [1, .92], studs: true }), wovenMat());
    add(part('Heap'), latheG([[.56, .7], [.5, .85], [.35, .95], [.16, 1.0], [0, 1.01]], 24, { amp: .09, f: 4, so: 5, yAmp: .08, sq: [1, .92], studs: true }), chopMat());
    const m = RM('StrawDry'); for (let i = 0; i < 52; i++) { const spill = i > 40, an = rnd() * TAU, r = spill ? rr(.62, .68) : rr(0, .45), b = new V3(Math.cos(an) * r, spill ? .02 : 1.0 - r * r * .3, Math.sin(an) * r * .92), d = hdir(rnd() * TAU);
      add(part('Bits'), stripG([b, b.clone().addScaledVector(d, rr(.05, .1))], new V3(-d.z, .3, d.x).normalize(), .025, 'CULM', .4, .3), m); }
  });
  return postFit(a, 1.3, 1.1, 1.3);
}
export function itemPelletCrate(v, seed) {
  const a = makeAsset(`EV_ItemPelletCrate_${v}`, seed, part => { const w = crateMat(), C = part('Crate'), hw = .74;
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) add(C, boxG(.12, 1.36, .12), w, [sx * (hw - .06), .68, sz * (hw - .06)]);
    for (const y of [.24, .68, 1.12]) for (const s of [-1, 1]) { add(C, boxG(1.48, .3, .05), w, [0, y, s * (hw - .025)]); add(C, boxG(.05, .3, 1.38), w, [s * (hw - .025), y, 0]); }
    for (const z of [-.5, 0, .5]) add(C, boxG(1.42, .05, .4), w, [0, .025, z]);
    add(part('Pellets'), boxG(1.36, 1.12, 1.36), pelletMat(), [0, .6, 0]);
    add(part('Pellets'), sweepG((s, t) => { const x = lerp(-.68, .68, s), z = lerp(.68, -.68, t); return new V3(x, 1.18 + .1 * Math.max(0, 1 - (x * x + z * z) / .55) + (N.fbm2(s, t, 4, 3) - .5) * .04, z); }, 8, 8, (s, t, p) => [p.x, p.z]), pelletMat());
    add(part('Stencil'), new THREE.PlaneGeometry(1.1, .27), stencilMat(), [0, .68, -hw - .004], [0, Math.PI, 0]); add(part('Stencil'), new THREE.PlaneGeometry(1.1, .27), stencilMat(), [hw + .004, .68, 0], [0, Math.PI / 2, 0]);
  });
  return postFit(a, 1.5, 1.4, 1.5);
}
export function itemBiochar(v, seed) {
  const a = makeAsset(`EV_ItemBiochar_${v}`, seed, part => {
    add(part('Sack'), latheG([[0, 0], [.42, 0], [.5, .05], [.54, .22], [.55, .45], [.52, .66], [.44, .8], [.3, .9], [.14, .95], [.09, .98], [.1, 1.0], [.17, 1.04], [.2, 1.08], [.08, 1.1], [0, 1.09]], 32, { phi0: 0, amp: .035, f: 5, so: 4, sq: [1, .78], vByY: 1.1 }), biocharSackMat());
    add(part('Tie'), new THREE.TorusGeometry(.1, .018, 5, 16).rotateX(Math.PI / 2), stringMat(), [0, .975, 0]);
    const tl = [new V3(.08, .975, .04), new V3(.16, .9, .1), new V3(.2, .78, .14)]; add(part('Tie'), tubeG(tl, [.016, .016, .014], 4, { tile: .2 }), stringMat());
  });
  return postFit(a, 1.3, 1.1, 1.3);
}
export function itemMushrooms(v, seed) {
  const a = makeAsset(`EV_ItemMushrooms_${v}`, seed, part => {
    add(part('Basket'), latheG([[0, 0], [.5, 0], [.58, .04], [.62, .2], [.64, .27], [.62, .29], [.58, .27], [.55, .1], [.48, .05], [0, .05]], 20, { amp: .015, f: 6, studs: true }), basketMat());
    const egg = [[0, 0], [.06, .005], [.09, .06], [.095, .13], [.08, .19], [.05, .235], [0, .25]], M = mushMat(), spots = [[0, 0, .05, 0], ...[0, 1, 2, 3, 4, 5].map(i => [Math.cos(i / 6 * TAU + .3) * .27, Math.sin(i / 6 * TAU + .3) * .27, .05, 0]), [.12, .05, .16, 1.35], [-.1, -.12, .15, 1.5]];
    spots.forEach(([x, z, y, lie], i) => { const s = rr(1.0, 1.3) * 1.15, m = add(part('Mushrooms'), latheG(egg, 7, { amp: .04, f: 8, so: i }), M, [x, y, z], [lie ? rr(-.2, .2) : rr(-.15, .15), rnd() * TAU, lie ? lie : rr(-.15, .15)], [s, s, s]); });
  });
  return postFit(a, 1.3, 1.1, 1.3);
}

/* ================= test field ================= */
export const STAGE_ORDER = [['prepared', 'PreparedRow', ['A']], ['seedling', 'RiceSeedling', ['A', 'B']], ['growing', 'RiceGrowing', ['A', 'B']], ['heading', 'RiceHeading', ['A', 'B']], ['ripe', 'RiceRipe', ['A', 'B']], ['stubble', 'Stubble', ['A', 'B']], ['burnt', 'StubbleBurnt', ['A']]];
export const FIELD = { z0: 44, plot: 36, rowX: [-13.5, -4.5, 4.5, 13.5], laneX: [-9, 0, 9], len: 40 };
export function buildTestField(byName) {
  const F = new THREE.Group(); F.name = 'TestField'; setSeed(4242); const z0 = FIELD.z0, n = STAGE_ORDER.length, cx = k => (k - (n - 1) / 2) * FIELD.plot;
  const place = (name, x, z, ry = 0) => { const src = byName[name]; if (!src) return; const o = src.clone(); o.position.set(x, 0, z); o.rotation.y = ry; F.add(o); return o; };
  STAGE_ORDER.forEach(([st, base, vars], k) => { const px = cx(k);
    FIELD.rowX.forEach((rx, r) => { for (let s = 0; s < FIELD.len / 8; s++) place(`EV_${base}_${vars[(s + r) % vars.length]}`, px + rx, z0 + 4 + s * 8); });
    FIELD.laneX.forEach((lx, l) => place(st === 'burnt' ? 'EV_StrawSheafBurnt_A' : `EV_StrawSheaf_${'ABC'[(k + l) % 3]}`, px + lx, z0 + rr(5, 35), rr(0, TAU)));
    if (st === 'stubble') { for (const [lx, z] of [[-9, 8], [-9, 13], [0, 30], [9, 6], [9, 26]]) place(`EV_StrawSheaf_${pick(['A', 'B', 'C'])}`, px + lx, z0 + z, rr(0, TAU));
      for (let s = 1; s < 5; s++) place('EV_StrawWindrow_A', px + FIELD.rowX[2], z0 + 4 + s * 8);
      place('EV_StrawBaleSquare_A', px + 0, z0 + 16, Math.PI / 2 + rr(-.08, .08)); place('EV_StrawBaleSquare_A', px + 0, z0 + 19.4, Math.PI / 2 + rr(-.08, .08)); }
  });
  const half = n * FIELD.plot / 2; for (let k = 0; k <= n; k++) for (let s = 0; s < 5; s++) place('EV_Bund_A', -half + k * FIELD.plot, z0 + 4 + s * 8);
  const nb = Math.ceil((2 * half + 2.2) / 8); for (const z of [z0 - 1.1, z0 + FIELD.len + 1.1]) for (let i = 0; i < nb; i++) place('EV_Bund_A', -nb * 4 + 4 + i * 8, z, Math.PI / 2);
  const mud = terrainMud(), tg = new THREE.PlaneGeometry(2 * half + 8, FIELD.len + 8); tg.rotateX(-Math.PI / 2); const p = tg.attributes.position, uv = tg.attributes.uv; for (let i = 0; i < p.count; i++) uv.setXY(i, p.getX(i), -p.getZ(i));
  const m = new THREE.Mesh(tg, mud); mud.userData.uvScale = .125; tg.attributes.uv.array.forEach((q, i, A) => A[i] = q * .125); m.position.set(0, .002, z0 + FIELD.len / 2); m.name = 'FieldTerrain'; F.add(m);
  F.traverse(o => { if (o.isMesh) { o.castShadow = !/_Water$|_Litter$|_Ground$|FieldTerrain/.test(o.name); o.receiveShadow = true; } });
  F.userData.plotX = Object.fromEntries(STAGE_ORDER.map(([st], k) => [st, cx(k)])); return F;
}
