// Shared kit for the EV_ environment packs: RNG + periodic noise, canvas PBR maps,
// geometry helpers, a shared material library, asset merging and the viewer/checks/export panel.
import * as THREE from 'three';
export { THREE };
export const V3 = THREE.Vector3, V2 = THREE.Vector2, TAU = Math.PI * 2, DEG = Math.PI / 180, YUP = new V3(0, 1, 0), DS = THREE.DoubleSide;

/* ---------- rng ---------- */
let _s = 1;
export const setSeed = n => { _s = n | 0; };
export const rnd = () => { _s |= 0; _s = _s + 0x6D2B79F5 | 0; let t = Math.imul(_s ^ _s >>> 15, 1 | _s); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
export const rr = (a, b) => a + (b - a) * rnd();
export const pick = a => a[(rnd() * a.length) | 0];
export const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
export const lerp = (a, b, t) => a + (b - a) * t;
export const sstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
export const rgba = (c, a) => `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`;

/* ---------- periodic value noise (2D tiles seamlessly; 3D for displacement) ---------- */
export function makeNoise(seed = 1) {
  const save = _s; setSeed(seed * 7919 + 13);
  const p = [...Array(256).keys()]; for (let i = 255; i > 0; i--) { const j = (rnd() * (i + 1)) | 0; [p[i], p[j]] = [p[j], p[i]]; }
  const perm = new Uint8Array(256); p.forEach((v, i) => perm[i] = v); const val = new Float32Array(256); for (let i = 0; i < 256; i++) val[i] = rnd(); _s = save;
  const h2 = (x, y) => val[perm[(perm[x & 255] + y) & 255]], h3 = (x, y, z) => val[perm[(perm[(perm[x & 255] + y) & 255] + z) & 255]];
  const n2 = (x, y, px = 256, py = px) => { const ix = Math.floor(x), iy = Math.floor(y), fx = x - ix, fy = y - iy, sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    const x0 = ((ix % px) + px) % px, x1 = (x0 + 1) % px, y0 = ((iy % py) + py) % py, y1 = (y0 + 1) % py, a = h2(x0, y0), b = h2(x1, y0), c = h2(x0, y1), d = h2(x1, y1);
    return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy; };
  const n3 = (x, y, z) => { const ix = Math.floor(x), iy = Math.floor(y), iz = Math.floor(z), fx = x - ix, fy = y - iy, fz = z - iz, sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy), sz = fz * fz * (3 - 2 * fz);
    const L = (a, b, t) => a + (b - a) * t, c = (i, j, k) => h3(ix + i, iy + j, iz + k);
    return L(L(L(c(0, 0, 0), c(1, 0, 0), sx), L(c(0, 1, 0), c(1, 1, 0), sx), sy), L(L(c(0, 0, 1), c(1, 0, 1), sx), L(c(0, 1, 1), c(1, 1, 1), sx), sy), sz); };
  const fbm2 = (u, v, per = 4, oct = 5, g = .5) => { let a = 1, f = 1, s = 0, t = 0; for (let o = 0; o < oct; o++) { s += a * n2(u * per * f, v * per * f, per * f); t += a; a *= g; f *= 2; } return s / t; };
  const fbm3 = (x, y, z, oct = 4, g = .5) => { let a = 1, f = 1, s = 0, t = 0; for (let o = 0; o < oct; o++) { s += a * n3(x * f, y * f, z * f); t += a; a *= g; f *= 2; } return s / t; };
  return { n2, n3, fbm2, fbm3 };
}
export const N = makeNoise(1);

/* ---------- canvas → PBR maps ---------- */
export const cv = (w, h = w) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
export function texFrom(c, srgb = true, rep = true) { const t = new THREE.CanvasTexture(c); if (srgb) t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = rep ? THREE.RepeatWrapping : THREE.ClampToEdgeWrapping; t.anisotropy = 8; return t; }
export function field(W, H, fn) { const c = cv(W, H), x = c.getContext('2d'), img = x.createImageData(W, H), d = img.data, o = [0, 0, 0, 255];
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) { o[3] = 255; fn(i / W, j / H, o, i, j); const k = (j * W + i) * 4; d[k] = o[0]; d[k + 1] = o[1]; d[k + 2] = o[2]; d[k + 3] = o[3]; }
  x.putImageData(img, 0, 0); return c; }
export function normalCanvas(hc, k = 2, wrap = true) {
  const w = hc.width, h = hc.height, s = hc.getContext('2d').getImageData(0, 0, w, h).data, o = cv(w, h), ctx = o.getContext('2d'), img = ctx.createImageData(w, h), d = img.data;
  const X = x => wrap ? (x + w) % w : clamp(x, 0, w - 1), Y = y => wrap ? (y + h) % h : clamp(y, 0, h - 1);
  for (let y = 0; y < h; y++) { const yu = Y(y - 1) * w, yd = Y(y + 1) * w, yr = y * w;
    for (let x = 0; x < w; x++) { const dx = (s[(yr + X(x + 1)) * 4] - s[(yr + X(x - 1)) * 4]) / 255 * k, dy = (s[(yd + x) * 4] - s[(yu + x) * 4]) / 255 * k, l = Math.hypot(dx, dy, 1), i = (yr + x) * 4;
      d[i] = (-dx / l * .5 + .5) * 255; d[i + 1] = (dy / l * .5 + .5) * 255; d[i + 2] = (1 / l * .5 + .5) * 255; d[i + 3] = 255; } }
  ctx.putImageData(img, 0, 0); return o;
}
export function grayFrom(hc, base, amp, invert = false) { const w = hc.width, h = hc.height, s = hc.getContext('2d').getImageData(0, 0, w, h).data;
  return field(w, h, (u, v, o, i, j) => { const k = (j * w + i) * 4, g = clamp(base + amp * (s[k] / 255 - .5) * (invert ? -1 : 1), .02, 1) * 255; o[0] = o[1] = o[2] = g; }); }
// glTF packs roughness in G and metalness in B; build that directly so the GLB keeps both.
export function mrCanvas(rc, metal = 0, mc = null) { const w = rc.width, h = rc.height, r = rc.getContext('2d').getImageData(0, 0, w, h).data, m = mc ? mc.getContext('2d').getImageData(0, 0, w, h).data : null;
  return field(w, h, (u, v, o, i, j) => { const k = (j * w + i) * 4; o[0] = 255; o[1] = r[k]; o[2] = m ? m[k] : metal * 255; }); }
export function blotch(x, W, H, n, col, r0, r1, a) {
  for (let i = 0; i < n; i++) { const px = rnd() * W, py = rnd() * H, r = rr(r0, r1), al = a * rr(.5, 1);
    for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) { const X = px + ox, Y = py + oy; if (X + r < 0 || X - r > W || Y + r < 0 || Y - r > H) continue;
      const g = x.createRadialGradient(X, Y, 0, X, Y, r); g.addColorStop(0, rgba(col, al)); g.addColorStop(1, rgba(col, 0)); x.fillStyle = g; x.fillRect(X - r, Y - r, 2 * r, 2 * r); } }
}
export function specks(x, W, H, n, cols, r0, r1, a0, a1) { for (let i = 0; i < n; i++) { x.globalAlpha = rr(a0, a1); x.fillStyle = pick(cols); x.beginPath(); x.arc(rnd() * W, rnd() * H, rr(r0, r1), 0, TAU); x.fill(); } x.globalAlpha = 1; }
export function wrapped(W, H, px, py, r, fn) { for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) { const X = px + ox, Y = py + oy; if (X + r < 0 || X - r > W || Y + r < 0 || Y - r > H) continue; fn(X, Y); } }
export function chipPath(x, cx, cy, s, n = 7) { x.beginPath(); for (let i = 0; i < n; i++) { const a = i / n * TAU, r = s * rr(.45, 1.1); i ? x.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r * rr(.6, 1)) : x.moveTo(cx + r, cy); } x.closePath(); }

/** Build a material from colour (+alpha) and height canvases; roughness (and metalness) packed per glTF. */
export function pbr(name, o) {
  const rep = o.rep !== false, m = new THREE.MeshStandardMaterial({ roughness: 1, metalness: o.metal ? 1 : 0 });
  m.map = texFrom(o.color, true, rep);
  m.normalMap = texFrom(normalCanvas(o.height, o.k ?? 2, rep), false, rep); if (o.normalScale) m.normalScale.set(o.normalScale, o.normalScale);
  const rc = o.rough || grayFrom(o.height, o.roughBase ?? .8, o.roughAmp ?? .3, o.roughInvert);
  const mr = texFrom(mrCanvas(rc, o.metal ? 1 : 0, o.metalCanvas), false, rep); m.roughnessMap = mr; if (o.metal) m.metalnessMap = mr;
  if (o.alpha) { m.alphaTest = .5; m.side = DS; }
  if (o.side) m.side = o.side;
  if (o.emissive) { m.emissive = new THREE.Color(o.emissive); m.emissiveMap = m.map; m.emissiveIntensity = o.emissiveIntensity ?? 1; }
  if (o.transparent) { m.transparent = true; m.opacity = o.opacity ?? .3; m.depthWrite = false; }
  m.name = name; m.userData.uvScale = o.uv ?? 1; m.userData.tint = !!o.tint; return m;
}
/** Small noisy set for minor materials (plastic, paint, rubber, metal fittings). */
export function simpleSet(name, hex, o = {}) {
  const S = o.size || 256, c = cv(S), x = c.getContext('2d'), col = new THREE.Color(hex), base = [col.r * 255, col.g * 255, col.b * 255];
  x.fillStyle = '#' + col.getHexString(); x.fillRect(0, 0, S, S);
  blotch(x, S, S, 14, base.map(v => v * 1.12), S * .05, S * .25, .35); blotch(x, S, S, 14, base.map(v => v * .82), S * .05, S * .25, .3);
  if (o.dirt !== false) { blotch(x, S, S, 6, [150, 130, 95], S * .05, S * .2, o.dirt ?? .15); specks(x, S, S, S * 2, ['#2a2622', '#c9b88a'], .4, 1.3, .05, .25); }
  if (o.rust) for (let i = 0; i < o.rust; i++) { const px = rnd() * S, L = rr(S * .2, S * .7), g = x.createLinearGradient(0, 0, 0, L); g.addColorStop(0, 'rgba(126,62,24,.6)'); g.addColorStop(1, 'rgba(126,62,24,0)'); x.fillStyle = g; x.fillRect(px, rnd() * S * .3, rr(2, 6), L); }
  const h = field(S, S, (u, v, out) => { const n = N.fbm2(u, v, 6, 4); out[0] = out[1] = out[2] = 128 + (n - .5) * (o.bump ?? 60); });
  return pbr(name, { color: c, height: h, k: o.k ?? 1.2, roughBase: o.rough ?? .6, roughAmp: o.roughAmp ?? .25, metal: o.metal, uv: o.uv ?? 1, tint: o.tint, alpha: o.alpha, emissive: o.emissive, emissiveIntensity: o.emissiveIntensity, transparent: o.transparent, opacity: o.opacity });
}

/* ---------- shared material library (lazy; one texture set reused across assets/packs) ---------- */
const _lib = {};
export const lib = new Proxy({}, { get: (_, k) => _lib[k] || (RECIPES[k] ? (_lib[k] = RECIPES[k]()) : undefined) });
const tintGrey = 200;
const RECIPES = {
  concrete: () => { const S = 1024, c = cv(S), x = c.getContext('2d'); x.fillStyle = '#a6a195'; x.fillRect(0, 0, S, S);
    blotch(x, S, S, 50, [198, 193, 182], 60, 200, .22); blotch(x, S, S, 50, [116, 110, 100], 50, 180, .18); specks(x, S, S, 9000, ['#8a857a', '#c0bbaf', '#6c685f', '#9b958a'], .5, 1.8, .25, .7);
    const h = cv(S), y = h.getContext('2d'); y.fillStyle = '#888'; y.fillRect(0, 0, S, S); blotch(y, S, S, 40, [170, 170, 170], 40, 150, .3); specks(y, S, S, 5000, ['#333', '#555'], .6, 2.2, .4, .9);
    return pbr('EV_Concrete', { color: c, height: h, k: 1.6, roughBase: .9, roughAmp: .15, uv: .25 }); },
  render: () => { // painted render, tintable: light grey carrying only stains/streaks
    const S = 1024, nz = makeNoise(21), c = field(S, S, (u, v, o) => { const n = nz.fbm2(u, v, 8, 5), st = Math.max(0, nz.fbm2(u * 6, v * .5, 6, 3) - .55) * 2.2; const g = tintGrey + (n - .5) * 26 - st * 60; o[0] = g; o[1] = g * .985; o[2] = g * .96; });
    const x = c.getContext('2d'); for (let i = 0; i < 28; i++) { const px = rnd() * S, L = rr(80, 380), g = x.createLinearGradient(0, 0, 0, L), py = rnd() * S; g.addColorStop(0, 'rgba(70,62,52,.15)'); g.addColorStop(1, 'rgba(70,62,52,0)'); x.fillStyle = g; wrapped(S, S, px, py, L, (X, Y) => x.fillRect(X, Y, rr(3, 12), L)); }
    blotch(x, S, S, 18, [120, 108, 90], 40, 160, .2);
    const h = field(S, S, (u, v, o) => { const n = nz.fbm2(u, v, 32, 3); o[0] = o[1] = o[2] = 128 + (n - .5) * 90; });
    return pbr('EV_RenderPaint_Tint', { color: c, height: h, k: 1.2, roughBase: .85, roughAmp: .15, uv: .25, tint: true }); },
  tin: () => { // corrugated galvanised tin, tintable: ribs every 0.25 stud, rust streaks
    const S = 512, nz = makeNoise(33), c = field(S, S, (u, v, o) => { const rib = Math.sin(u * TAU * 8), n = nz.fbm2(u, v, 6, 4); const g = tintGrey + rib * 10 + (n - .5) * 30; o[0] = g; o[1] = g; o[2] = g * .99; });
    const x = c.getContext('2d'); for (let i = 0; i < 26; i++) { const px = rnd() * S, py = rnd() * S * .4, L = rr(90, 380), g = x.createLinearGradient(0, py, 0, py + L); g.addColorStop(0, 'rgba(130,64,26,.75)'); g.addColorStop(1, 'rgba(130,64,26,0)'); x.fillStyle = g; x.fillRect(px, py, rr(3, 10), L); }
    blotch(x, S, S, 10, [120, 60, 26], 10, 50, .5);
    const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 128 + Math.sin(u * TAU * 8) * 110; });
    const rc2 = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = (.42 + (nz.fbm2(u, v, 6, 4) - .5) * .35) * 255; });
    return pbr('EV_CorrugatedTin_Tint', { color: c, height: h, k: 3, rough: rc2, metal: 1, uv: .5, tint: true }); },
  tile: () => { // clay roof tiles, tintable
    const S = 512, nz = makeNoise(44), c = cv(S), x = c.getContext('2d'); x.fillStyle = `rgb(${tintGrey},${tintGrey},${tintGrey})`; x.fillRect(0, 0, S, S); const h = cv(S), y = h.getContext('2d'); y.fillStyle = '#444'; y.fillRect(0, 0, S, S);
    for (let r = 0; r < 4; r++) for (let k = 0; k < 5; k++) { const px = k * S / 4 + (r % 2) * S / 8, py = r * S / 4; for (const ox of [-S, 0]) { const g = y.createLinearGradient(0, py, 0, py + S / 4); g.addColorStop(0, '#666'); g.addColorStop(.85, '#eee'); g.addColorStop(1, '#333'); y.fillStyle = g; y.fillRect(px + ox + 3, py, S / 4 - 6, S / 4 - 2); x.fillStyle = `rgba(0,0,0,${rr(0, .12)})`; x.fillRect(px + ox + 3, py, S / 4 - 6, S / 4 - 2); } }
    blotch(x, S, S, 20, [70, 70, 60], 20, 90, .22); specks(x, S, S, 1200, ['#3a3a30', '#e8e8e0'], .5, 1.5, .1, .35);
    return pbr('EV_RoofTile_Tint', { color: c, height: h, k: 3, roughBase: .75, roughAmp: .2, uv: .5, tint: true }); },
  teak: () => { // weathered teak planks (not tinted)
    const S = 1024, nz = makeNoise(55), c = field(S, S, (u, v, o) => { const plank = Math.floor(u * 6), pv = (plank * .37) % 1, grain = nz.fbm2(u * 6 + pv, v * .25 + pv, 8, 5), ring = .5 + .5 * Math.sin((grain * 9 + u * 60) * 1.0);
      const base = [128, 84, 50].map((cc, i) => cc * (.82 + pv * .3) * (.86 + ring * .18)); const weather = nz.fbm2(u, v, 3, 3); const g = (base[0] + base[1] + base[2]) / 3, w = sstep(.45, .75, weather) * .45;
      o[0] = lerp(base[0], g * 1.05, w); o[1] = lerp(base[1], g * 1.02, w); o[2] = lerp(base[2], g, w); const gap = (u * 6) % 1; if (gap < .012) { o[0] *= .35; o[1] *= .35; o[2] *= .35; } });
    const h = field(S, S, (u, v, o) => { const gap = (u * 6) % 1, gr = nz.fbm2(u * 6, v * .25, 8, 4); o[0] = o[1] = o[2] = gap < .012 ? 20 : 150 + (gr - .5) * 120; });
    return pbr('EV_TeakPlanks', { color: c, height: h, k: 2.4, roughBase: .78, roughAmp: .25, uv: .5 }); },
  woodRough: () => { // sawn timber posts/beams
    const S = 512, nz = makeNoise(66), c = field(S, S, (u, v, o) => { const g = nz.fbm2(u * 4, v * .3, 8, 5), s = .8 + g * .4; o[0] = 112 * s; o[1] = 82 * s; o[2] = 56 * s; });
    blotch(c.getContext('2d'), S, S, 12, [70, 66, 60], 20, 80, .3);
    const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 128 + (nz.fbm2(u * 4, v * .3, 16, 4) - .5) * 160; });
    return pbr('EV_SawnTimber', { color: c, height: h, k: 2, roughBase: .85, roughAmp: .2, uv: .5 }); },
  bamboo: () => { // bamboo culm/slat, tile 2 studs along, node lines
    const S = 512, nz = makeNoise(77), c = field(S, S, (u, v, o) => { const n = nz.fbm2(u, v * .2, 8, 4), node = Math.abs(((v * 2) % 1) - .5) < .012; const s = .85 + n * .3; o[0] = 186 * s; o[1] = 158 * s; o[2] = 96 * s; if (node) { o[0] *= .6; o[1] *= .58; o[2] *= .5; } const stain = nz.fbm2(u, v, 3, 3); if (stain > .62) { o[0] *= .8; o[1] *= .78; o[2] *= .75; } });
    const h = field(S, S, (u, v, o) => { const node = Math.abs(((v * 2) % 1) - .5); o[0] = o[1] = o[2] = node < .015 ? 230 : 128 + (nz.fbm2(u * 8, v * .5, 16, 3) - .5) * 60; });
    return pbr('EV_Bamboo', { color: c, height: h, k: 2, roughBase: .55, roughAmp: .2, uv: .5 }); },
  thatch: () => { // imperata grass thatch, tile 2 studs
    const S = 1024, c = cv(S), x = c.getContext('2d'), h = cv(S), y = h.getContext('2d'); x.fillStyle = '#6e5a38'; x.fillRect(0, 0, S, S); y.fillStyle = '#202020'; y.fillRect(0, 0, S, S); x.lineCap = y.lineCap = 'round';
    for (let i = 0; i < 16000; i++) { const px = rnd() * S, py = rnd() * S, L = rr(40, 160), a = Math.PI / 2 + rr(-.18, .18), dx = Math.cos(a) * L, dy = Math.sin(a) * L, w = rr(1.2, 3.2), col = `hsl(${rr(34, 44)},${rr(28, 52)}%,${rr(30, 62)}%)`, hv = rr(90, 255) | 0;
      wrapped(S, S, px, py, L, (X, Y) => { x.strokeStyle = col; x.lineWidth = w; x.beginPath(); x.moveTo(X, Y); x.lineTo(X + dx, Y + dy); x.stroke(); y.strokeStyle = `rgb(${hv},${hv},${hv})`; y.lineWidth = w; y.beginPath(); y.moveTo(X, Y); y.lineTo(X + dx, Y + dy); y.stroke(); }); }
    for (let r = 0; r < 6; r++) { const py = r * S / 6; const g = x.createLinearGradient(0, py, 0, py + S / 6); g.addColorStop(0, 'rgba(30,22,12,.35)'); g.addColorStop(.25, 'rgba(30,22,12,0)'); x.fillStyle = g; x.fillRect(0, py, S, S / 6); }
    blotch(x, S, S, 20, [180, 168, 140], 40, 160, .2);
    return pbr('EV_Thatch', { color: c, height: h, k: 3, roughBase: .9, roughAmp: .1, uv: .5 }); },
  thatchFringe: () => { // alpha card: hanging thatch ends, 1024x256 = 4 x 1 studs
    const W = 1024, H = 256, c = cv(W, H), x = c.getContext('2d'), h = cv(W, H), y = h.getContext('2d'); y.fillStyle = '#000'; y.fillRect(0, 0, W, H); x.lineCap = y.lineCap = 'round';
    for (let i = 0; i < 2600; i++) { const px = rnd() * W, L = rr(.45, 1) * H, a = Math.PI / 2 + rr(-.12, .12), col = `hsl(${rr(34, 44)},${rr(28, 50)}%,${rr(30, 60)}%)`; x.strokeStyle = col; x.lineWidth = rr(1.5, 3.5); x.beginPath(); x.moveTo(px, 0); x.lineTo(px + Math.cos(a) * L, Math.sin(a) * L); x.stroke(); y.strokeStyle = '#ccc'; y.lineWidth = 2; y.beginPath(); y.moveTo(px, 0); y.lineTo(px + Math.cos(a) * L, Math.sin(a) * L); y.stroke(); }
    return pbr('EV_ThatchFringe', { color: c, height: h, k: 2, roughBase: .9, roughAmp: .1, alpha: true, rep: false }); },
  straw: () => { // loose rice straw, tile 2 studs
    const S = 1024, c = cv(S), x = c.getContext('2d'), h = cv(S), y = h.getContext('2d'); x.fillStyle = '#9b7a3e'; x.fillRect(0, 0, S, S); y.fillStyle = '#303030'; y.fillRect(0, 0, S, S); x.lineCap = y.lineCap = 'round';
    for (let i = 0; i < 14000; i++) { const px = rnd() * S, py = rnd() * S, L = rr(30, 140), a = Math.PI / 2 + rr(-.5, .5), dx = Math.cos(a) * L, dy = Math.sin(a) * L, w = rr(1.4, 3.6), col = `hsl(${rr(36, 47)},${rr(45, 70)}%,${rr(38, 72)}%)`, hv = rr(110, 255) | 0;
      wrapped(S, S, px, py, L, (X, Y) => { x.strokeStyle = col; x.lineWidth = w; x.beginPath(); x.moveTo(X, Y); x.lineTo(X + dx, Y + dy); x.stroke(); y.strokeStyle = `rgb(${hv},${hv},${hv})`; y.lineWidth = w; y.beginPath(); y.moveTo(X, Y); y.lineTo(X + dx, Y + dy); y.stroke(); }); }
    return pbr('EV_Straw', { color: c, height: h, k: 3, roughBase: .85, roughAmp: .12, uv: .5 }); },
  strawSun: () => { const m = lib.straw.clone(); const S = 1024, c = cv(S), x = c.getContext('2d'); x.drawImage(lib.straw.map.image, 0, 0); x.globalCompositeOperation = 'screen'; x.fillStyle = 'rgba(120,112,92,.55)'; x.fillRect(0, 0, S, S); m.map = texFrom(c); m.name = 'EV_StrawSunBleached'; m.userData = { ...lib.straw.userData }; return m; },
  strawFringe: () => { const W = 512, H = 512, c = cv(W, H), x = c.getContext('2d'), h = cv(W, H), y = h.getContext('2d'); y.fillStyle = '#000'; y.fillRect(0, 0, W, H); x.lineCap = 'round';
    for (let i = 0; i < 1400; i++) { const px = rr(10, W - 10), py = rr(0, H * .25), L = rr(.4, .95) * (H - py), a = Math.PI / 2 + rr(-.35, .35), col = `hsl(${rr(36, 47)},${rr(45, 70)}%,${rr(40, 74)}%)`; x.strokeStyle = col; x.lineWidth = rr(1.5, 3.5); x.beginPath(); x.moveTo(px, py); x.lineTo(px + Math.cos(a) * L, py + Math.sin(a) * L); x.stroke(); y.strokeStyle = '#bbb'; y.lineWidth = 2; y.beginPath(); y.moveTo(px, py); y.lineTo(px + Math.cos(a) * L, py + Math.sin(a) * L); y.stroke(); }
    return pbr('EV_StrawFringe', { color: c, height: h, k: 2, roughBase: .85, roughAmp: .1, alpha: true, rep: false }); },
  steelPaint: () => simpleSet('EV_SteelPainted_Tint', 0xc8c8c8, { rough: .5, tint: true, rust: 6 }),
  steel: () => simpleSet('EV_GalvanisedSteel', 0xa9adab, { rough: .4, metal: true, dirt: .1 }),
  darkSteel: () => simpleSet('EV_DarkSteel', 0x3c3f41, { rough: .55, metal: true, rust: 4 }),
  rubber: () => simpleSet('EV_Rubber', 0x1c1c1c, { rough: .85, dirt: .1 }),
  chrome: () => simpleSet('EV_Chrome', 0xd8dadc, { rough: .18, metal: true, dirt: .05, bump: 10 }),
  plasticTint: () => simpleSet('EV_Plastic_Tint', 0xc8c8c8, { rough: .45, tint: true, bump: 15 }),
  fabricTint: () => { const S = 256, nz = makeNoise(88), c = field(S, S, (u, v, o) => { const w = (Math.sin(u * TAU * 64) * Math.sin(v * TAU * 64)) * 8, n = nz.fbm2(u, v, 4, 3); const g = tintGrey + w + (n - .5) * 30; o[0] = o[1] = o[2] = g; });
    const h = field(S, S, (u, v, o) => { o[0] = o[1] = o[2] = 128 + Math.sin(u * TAU * 64) * Math.sin(v * TAU * 64) * 80; });
    return pbr('EV_Fabric_Tint', { color: c, height: h, k: 1.5, roughBase: .92, roughAmp: .05, uv: 1, tint: true, side: DS }); },
  glass: () => simpleSet('EV_WindowGlass', 0x5d7078, { rough: .08, dirt: .25, bump: 4, transparent: true, opacity: .45 }),
  ceramic: () => simpleSet('EV_GlazedJar', 0x5a3a24, { rough: .3, dirt: .2 }),
  terracotta: () => simpleSet('EV_Terracotta', 0xa45a36, { rough: .8 }),
  soil: () => simpleSet('EV_PotSoil', 0x4a3424, { rough: .95, bump: 90 }),
  gold: () => simpleSet('EV_GiltPaint', 0xc8a040, { rough: .3, metal: true, dirt: .08 }),
  whitePaint: () => simpleSet('EV_WhitePaint', 0xe8e6de, { rough: .55, dirt: .2 }),
  redPaint: () => simpleSet('EV_RedPaint', 0xa8302a, { rough: .5, dirt: .2 }),
  black: () => simpleSet('EV_BlackPlastic', 0x232323, { rough: .5, dirt: .08 }),
};

/* ---------- geometry helpers ---------- */
export const v3 = a => a.isVector3 ? a.clone() : new V3(a[0], a[1], a[2]);
export function boxG(w, h, d) { const g = new THREE.BoxGeometry(w, h, d), uv = g.attributes.uv, dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]]; for (let f = 0; f < 6; f++) for (let k = 0; k < 4; k++) { const i = f * 4 + k; uv.setXY(i, uv.getX(i) * dims[f][0], uv.getY(i) * dims[f][1]); } return g; }
export function bboxG(w, h, d, b = .03) { b = Math.min(b, w / 2 - .002, h / 2 - .002, d / 2 - .002); const s = new THREE.Shape(), x = w / 2 - b, y = h / 2 - b; s.moveTo(-x, -y); s.lineTo(x, -y); s.lineTo(x, y); s.lineTo(-x, y); s.closePath();
  const g = new THREE.ExtrudeGeometry(s, { depth: d - 2 * b, bevelEnabled: true, bevelThickness: b, bevelSize: b, bevelSegments: 1 }); g.translate(0, 0, -(d - 2 * b) / 2); return g; }
export function cylG(rt, rb, h, seg = 16, open = false, ts = 0, tl = TAU) { const g = new THREE.CylinderGeometry(rt, rb, h, seg, 1, open, ts, tl), uv = g.attributes.uv, su = (rt + rb) / 2 * tl; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * su, uv.getY(i) * h); return g; }
export const alongX = g => g.rotateZ(-Math.PI / 2), alongZ = g => g.rotateX(Math.PI / 2);
export function revolve(prof, seg = 32, o = {}) {
  const t0 = o.t0 || 0, tl = o.tl || TAU, flat = !!o.flat, pos = [], nor = [], uv = []; let acc = 0;
  for (let i = 0; i < prof.length - 1; i++) { const [r0, y0] = prof[i], [r1, y1] = prof[i + 1], dr = r1 - r0, dy = y1 - y0, L = Math.hypot(dr, dy) || 1, nr = dy / L, ny = -dr / L;
    for (let s = 0; s < seg; s++) { const a0 = t0 + tl * s / seg, a1 = t0 + tl * (s + 1) / seg, am = (a0 + a1) / 2, P = (r, y, a) => [r * Math.sin(a), y, r * Math.cos(a)], Nn = a => [nr * Math.sin(a), ny, nr * Math.cos(a)];
      const A = P(r0, y0, a0), B = P(r0, y0, a1), C = P(r1, y1, a1), D = P(r1, y1, a0), nA = Nn(flat ? am : a0), nB = Nn(flat ? am : a1), ra = Math.max((r0 + r1) / 2, .05);
      pos.push(...A, ...B, ...C, ...A, ...C, ...D); nor.push(...nA, ...nB, ...nB, ...nA, ...nB, ...nA); uv.push(a0 * ra, acc, a1 * ra, acc, a1 * ra, acc + L, a0 * ra, acc, a1 * ra, acc + L, a0 * ra, acc + L); }
    acc += L; }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); return g;
}
export const ringProf = (ri, ro, w) => [[ri, -w / 2], [ro, -w / 2], [ro, w / 2], [ri, w / 2], [ri, -w / 2]];
export function frustumG(bw, bd, tw, td, h) { const g = boxG(bw, h, bd).toNonIndexed(), p = g.attributes.position; for (let i = 0; i < p.count; i++) if (p.getY(i) > 0) { p.setX(i, p.getX(i) * tw / bw); p.setZ(i, p.getZ(i) * td / bd); } g.computeVertexNormals(); return g; }
export function add(g, geo, m, p = [0, 0, 0], r = [0, 0, 0], s) { const o = new THREE.Mesh(geo, m); o.position.set(p[0], p[1], p[2]); o.rotation.set(r[0], r[1], r[2]); if (s) o.scale.set(s[0], s[1], s[2]); g.add(o); return o; }
export function orient(o, dir) { o.quaternion.setFromUnitVectors(YUP, v3(dir).normalize()); return o; }
export function pipe(g, m, a, b, r, seg = 12, open = false) { a = v3(a); b = v3(b); const d = b.clone().sub(a), o = new THREE.Mesh(cylG(r, r, d.length(), seg, open), m); o.position.copy(a).add(b).multiplyScalar(.5); orient(o, d); g.add(o); return o; }
export function beam(g, m, a, b, w, h) { a = v3(a); b = v3(b); const d = b.clone().sub(a), o = new THREE.Mesh(boxG(w, d.length(), h), m); o.position.copy(a).add(b).multiplyScalar(.5); orient(o, d); g.add(o); return o; }
export function sub(parent, pos = [0, 0, 0], rot = null) { const s = new THREE.Group(); s.position.copy(v3(pos)); if (rot) s.rotation.set(rot[0], rot[1], rot[2]); parent.add(s); return s; }
export const plane = (w, h) => new THREE.PlaneGeometry(w, h);
/** Card with its pivot at the bottom-centre edge; uv 0..1 over the card (for alpha atlases). */
export function cardG(w, h, bendZ = 0, segs = 1) { const g = new THREE.PlaneGeometry(w, h, 1, segs); g.translate(0, h / 2, 0); if (bendZ) { const p = g.attributes.position; for (let i = 0; i < p.count; i++) { const t = p.getY(i) / h; p.setZ(i, bendZ * t * t); } g.computeVertexNormals(); } return g; }
/** Tube along a polyline with per-point radius (parallel-transport frames). uv: u around (×uRep), v along (÷vTile). */
export function tubeG(pts, rad, seg = 8, o = {}) {
  pts = pts.map(v3); const n = pts.length, pos = [], nor = [], uv = [], idx = [];
  let T = pts[1].clone().sub(pts[0]).normalize(), Nn = Math.abs(T.y) < .9 ? new V3(0, 1, 0) : new V3(1, 0, 0); Nn.sub(T.clone().multiplyScalar(Nn.dot(T))).normalize(); let B = new V3().crossVectors(T, Nn); let vAcc = 0;
  const uRep = o.uRep ?? Math.max(1, Math.round(TAU * rad[0] / (o.tile || 1)));
  for (let i = 0; i < n; i++) {
    if (i > 0) { const T2 = (i < n - 1 ? pts[i + 1].clone().sub(pts[i - 1]) : pts[i].clone().sub(pts[i - 1])).normalize(), q = new THREE.Quaternion().setFromUnitVectors(T, T2); Nn.applyQuaternion(q); B.applyQuaternion(q); T = T2; vAcc += pts[i].distanceTo(pts[i - 1]); }
    for (let s = 0; s <= seg; s++) { const a = s / seg * TAU, d = Nn.clone().multiplyScalar(Math.cos(a)).addScaledVector(B, Math.sin(a)), r = rad[i] * (o.wob ? 1 + o.wob(i, s, a) : 1); pos.push(pts[i].x + d.x * r, pts[i].y + d.y * r, pts[i].z + d.z * r); nor.push(d.x, d.y, d.z); uv.push(s / seg * uRep, vAcc / (o.tile || 1)); }
  }
  for (let i = 0; i < n - 1; i++) for (let s = 0; s < seg; s++) { const a = i * (seg + 1) + s, b = a + seg + 1; idx.push(a, a + 1, b, a + 1, b + 1, b); }
  if (o.capEnd) { const c = pos.length / 3, e = pts[n - 1], t = T; pos.push(e.x, e.y, e.z); nor.push(t.x, t.y, t.z); uv.push(.5, vAcc); const base = (n - 1) * (seg + 1); for (let s = 0; s < seg; s++) idx.push(base + s, base + s + 1, c); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx); return g;
}
/** Smooth curve sample (Catmull-Rom) between control points. */
export function curve(ctrl, n) { const c = new THREE.CatmullRomCurve3(ctrl.map(v3)); return c.getPoints(n - 1); }
/** Displaced icosphere blob (rocks, foliage cores). */
export function blobG(r, detail = 2, amp = .25, freq = 1.5, seedOff = 0, sq = [1, 1, 1]) {
  const g = new THREE.IcosahedronGeometry(r, detail), p = g.attributes.position, v = new V3();
  for (let i = 0; i < p.count; i++) { v.fromBufferAttribute(p, i); const nn = v.clone().normalize(), d = 1 + amp * (N.fbm3(nn.x * freq + seedOff, nn.y * freq + seedOff * .7, nn.z * freq - seedOff, 4) - .5) * 2; v.copy(nn).multiplyScalar(r * d); p.setXYZ(i, v.x * sq[0], v.y * sq[1], v.z * sq[2]); }
  g.computeVertexNormals(); const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * TAU * r, uv.getY(i) * Math.PI * r); return g;
}

/* ---------- merging into named meshes ---------- */
export function mergeGroup(grp, name) {
  grp.updateMatrixWorld(true); const inv = grp.matrixWorld.clone().invert(), byMat = new Map();
  grp.traverse(o => { if (!o.isMesh) return; let geo = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
    if (!geo.attributes.normal) geo.computeVertexNormals(); if (!geo.attributes.uv) geo.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(geo.attributes.position.count * 2), 2));
    const mw = inv.clone().multiply(o.matrixWorld); geo.applyMatrix4(mw);
    if (mw.determinant() < 0) { const p = geo.attributes.position.array, nn = geo.attributes.normal.array, u = geo.attributes.uv.array; for (let i = 0; i < p.length; i += 9) for (const arr of [p, nn]) for (let k = 0; k < 3; k++) { const t = arr[i + 3 + k]; arr[i + 3 + k] = arr[i + 6 + k]; arr[i + 6 + k] = t; } for (let i = 0; i < u.length; i += 6) for (let k = 0; k < 2; k++) { const t = u[i + 2 + k]; u[i + 2 + k] = u[i + 4 + k]; u[i + 4 + k] = t; } }
    const sc = o.material.userData.uvScale || 1; if (sc !== 1) { const uv = geo.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * sc, uv.getY(i) * sc); }
    if (!byMat.has(o.material)) byMat.set(o.material, []); byMat.get(o.material).push(geo); });
  let total = 0; for (const l of byMat.values()) for (const gg of l) total += gg.attributes.position.count;
  const pos = new Float32Array(total * 3), nor = new Float32Array(total * 3), uv = new Float32Array(total * 2), out = new THREE.BufferGeometry(), mats = []; let off = 0, mi = 0;
  for (const [m, l] of byMat) { const start = off; for (const gg of l) { const n = gg.attributes.position.count; pos.set(gg.attributes.position.array, off * 3); nor.set(gg.attributes.normal.array, off * 3); uv.set(gg.attributes.uv.array.subarray(0, n * 2), off * 2); off += n; } out.addGroup(start, off - start, mi++); mats.push(m); }
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3)); out.setAttribute('normal', new THREE.BufferAttribute(nor, 3)); out.setAttribute('uv', new THREE.BufferAttribute(uv, 2)); out.computeBoundingBox(); out.computeBoundingSphere();
  const mesh = new THREE.Mesh(out, mats.length === 1 ? mats[0] : mats); mesh.name = name; return mesh;
}
/** Build one asset: build(part) gets a collector per part name; each part becomes one mesh EV_<Asset>_<Variant>_<Part>. */
export function makeAsset(name, seed, build) {
  setSeed(seed); const asset = new THREE.Group(); asset.name = name; const cols = new Map();
  const part = p => { if (!cols.has(p)) cols.set(p, new THREE.Group()); return cols.get(p); };
  build(part);
  for (const [p, g] of cols) { if (!g.children.length) continue; asset.add(mergeGroup(g, name + '_' + p)); }
  return asset;
}

/* ---------- viewer: environment, layout, checks, export, shots ---------- */
const CSS = `
#evp{position:fixed;top:12px;left:12px;width:330px;max-width:calc(100vw - 24px);max-height:calc(100vh - 80px);overflow:auto;background:rgba(250,250,247,.95);border:1px solid rgba(0,0,0,.12);border-radius:6px;font:11px/1.45 "IBM Plex Mono",ui-monospace,monospace;color:#1c1d1b;box-sizing:border-box;z-index:5}
#evp header{padding:10px 12px 8px;border-bottom:1px solid rgba(0,0,0,.1);display:flex;justify-content:space-between;align-items:baseline;gap:8px}
#evp h1{margin:0;font:700 15px/1.1 "IBM Plex Sans Condensed",sans-serif;letter-spacing:.02em}
#evp .sec{padding:8px 12px;border-bottom:1px solid rgba(0,0,0,.08)}
#evp .lab{font-weight:600;text-transform:uppercase;letter-spacing:.06em;font-size:10px;color:#5a5c58;margin-bottom:4px}
#evp table{width:100%;border-collapse:collapse}#evp td{padding:1px 2px;vertical-align:top}#evp td.r{text-align:right;white-space:nowrap}
#evp tr.as{cursor:pointer}#evp tr.as:hover td{background:#eef3f2}
#evp .bad{color:#b3261e;font-weight:600}#evp .ok{color:#1f6f6c;font-weight:600}
#evp .row{display:flex;flex-wrap:wrap;gap:4px}
#evp button{font:500 11px "IBM Plex Mono",monospace;padding:5px 7px;border:1px solid rgba(0,0,0,.18);background:#fff;border-radius:4px;cursor:pointer;color:#1c1d1b}
#evp button:hover{background:#eef3f2}#evp button.primary,#evp button[aria-pressed="true"]{background:#1f6f6c;color:#fff;border-color:#1f6f6c}
#evp .tog{background:none;border:none;padding:0;color:#5a5c58}#evp.min .body{display:none}`;
export function prepStage(stage) {
  const renderer = stage._renderer, scene = stage._scene; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = .85;
  const env = new THREE.Scene(); env.add(new THREE.Mesh(new THREE.BoxGeometry(60, 30, 60), new THREE.MeshBasicMaterial({ color: new THREE.Color(.45, .44, .42), side: THREE.BackSide })));
  const pnl = (w, h, c, p, r) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: new THREE.Color(c[0], c[1], c[2]), side: DS })); m.position.set(...p); m.rotation.set(...r); env.add(m); };
  pnl(30, 30, [3.6, 3.5, 3.3], [0, 14, 0], [Math.PI / 2, 0, 0]); pnl(20, 10, [2.2, 1.7, 1.2], [28, 6, -10], [0, -Math.PI / 2, 0]); pnl(20, 10, [.8, .9, 1.1], [-28, 6, 8], [0, Math.PI / 2, 0]);
  const pm = new THREE.PMREMGenerator(renderer); scene.environment = pm.fromScene(env, .04).texture; scene.environmentIntensity = .65;
  stage._ground.material = new THREE.MeshStandardMaterial({ color: 0xa9a49a, roughness: .95 });
  stage._key.color.set(0xffe6c8); stage._key.intensity = 2.6;
}
/** Lay assets side by side: rows of names; returns nothing (positions groups in root). */
export function layoutRows(root, rows, gap = 4) {
  let z = 0; const byName = Object.fromEntries(root.children.map(g => [g.name, g]));
  for (const row of rows) { const gs = row.map(n => byName[n]).filter(Boolean), boxes = gs.map(g => new THREE.Box3().setFromObject(g, true)); let x = 0, dmax = 0;
    const widths = boxes.map(b => b.max.x - b.min.x), total = widths.reduce((a, b) => a + b, 0) + gap * (gs.length - 1); x = -total / 2;
    gs.forEach((g, i) => { const b = boxes[i]; g.position.x = x - b.min.x; dmax = Math.max(dmax, b.max.z - b.min.z); x += widths[i] + gap; });
    gs.forEach((g, i) => { g.position.z = z - boxes[i].max.z; }); z -= dmax + gap; }
  const all = new THREE.Box3().setFromObject(root, true), c = all.getCenter(new V3()); for (const g of root.children) { g.position.z -= c.z; }
}
export function setupViewer(stage, root, cfg) {
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  stage.setObject(root);
  const cam = stage._camera, ctl = stage._controls, V = new V3();
  // stats per asset (in the asset's own frame: origin at ground contact)
  const rows = [], allMeshes = []; let okAll = true;
  for (const g of root.children) { const pos = g.position.clone(); g.position.set(0, 0, 0); g.updateMatrixWorld(true); const b = new THREE.Box3().setFromObject(g, true); g.position.copy(pos); g.updateMatrixWorld(true);
    const s = b.getSize(new V3()), spec = cfg.specs[g.name] || {}, inR = (v, r) => !r || (v >= r[0] - 1e-3 && v <= r[1] + 1e-3);
    let tris = 0, meshOk = true; const meshes = []; g.traverse(o => { if (o.isMesh) { const t = (o.geometry.index ? o.geometry.index.count : o.geometry.attributes.position.count) / 3; tris += t; meshes.push([o.name, t]); allMeshes.push([o.name, t]); if (t >= 20000) meshOk = false; } });
    const sizeOk = inR(s.x, spec.w) && inR(s.y, spec.h) && inR(s.z, spec.d), budOk = inR(tris, spec.budget), nameOk = meshes.every(([n]) => n.startsWith(g.name + '_'));
    const ok = sizeOk && budOk && meshOk && nameOk; okAll = okAll && ok;
    rows.push({ name: g.name, size: s, tris, sizeOk, budOk, meshOk, nameOk, ok, meshes, spec, min: b.min.clone() }); }
  let extras = 0; root.traverse(o => { if (o.isLight || o.isCamera || /Helper/.test(o.type)) extras++; });
  const direct = root.children.every(g => g.isGroup && /^EV_[A-Za-z]+_[A-Z]$/.test(g.name));
  const f1 = n => n.toFixed(1), rng = r => r ? (r[0] === r[1] ? f1(r[1]) : f1(r[0]) + '–' + f1(r[1])) : '—';
  const panel = document.createElement('aside'); panel.id = 'evp';
  const hasTint = rows.some(r => r.meshes.some(([n]) => n.endsWith('_Tint')));
  panel.innerHTML = `<header><h1>${cfg.title}</h1><button class="tog" id="evMin">hide</button></header><div class="body">
  <div class="sec"><div class="row"><button id="evContact">Contact sheet</button>${hasTint ? '<button id="evTint" aria-pressed="false">Preview tints</button>' : ''}<button id="evGlb" class="primary">Export GLB</button><span id="evMsg" style="align-self:center;color:#5a5c58"></span></div></div>
  <div class="sec"><div class="lab">Checks</div><table>
    <tr><td>Every mesh &lt; 20k tris (max ${Math.max(...allMeshes.map(m => m[1])).toLocaleString()})</td><td class="r ${allMeshes.every(m => m[1] < 20000) ? 'ok' : 'bad'}">${allMeshes.every(m => m[1] < 20000) ? '✓' : '✗'}</td></tr>
    <tr><td>Every asset inside size range</td><td class="r ${rows.every(r => r.sizeOk) ? 'ok' : 'bad'}">${rows.every(r => r.sizeOk) ? '✓' : '✗'}</td></tr>
    <tr><td>Every asset inside tri budget</td><td class="r ${rows.every(r => r.budOk) ? 'ok' : 'bad'}">${rows.every(r => r.budOk) ? '✓' : '✗'}</td></tr>
    <tr><td>Names EV_Asset_Var(_Part)</td><td class="r ${direct && rows.every(r => r.nameOk) ? 'ok' : 'bad'}">${direct && rows.every(r => r.nameOk) ? '✓' : '✗'}</td></tr>
    <tr><td>No lights/cameras/helpers in root</td><td class="r ${extras ? 'bad' : 'ok'}">${extras ? '✗' : '✓'}</td></tr></table></div>
  <div class="sec"><div class="lab">Assets · W×H×D studs · tris (click to focus)</div><table>${rows.map(r => `<tr class="as" data-n="${r.name}"><td>${r.name.replace(/^EV_/, '')}</td><td class="r ${r.sizeOk ? '' : 'bad'}" title="range ${rng(r.spec.w)} × ${rng(r.spec.h)} × ${rng(r.spec.d)}">${f1(r.size.x)}×${f1(r.size.y)}×${f1(r.size.z)}</td><td class="r ${r.budOk && r.meshOk ? '' : 'bad'}">${r.tris.toLocaleString()}</td><td class="r ${r.ok ? 'ok' : 'bad'}">${r.ok ? '✓' : '✗'}</td></tr>`).join('')}
  <tr><td style="font-weight:600;padding-top:4px">Total (${rows.length})</td><td></td><td class="r" style="font-weight:600;padding-top:4px">${rows.reduce((a, r) => a + r.tris, 0).toLocaleString()}</td><td></td></tr></table></div></div>`;
  document.body.appendChild(panel);
  panel.querySelector('#evMin').onclick = e => { panel.classList.toggle('min'); e.target.textContent = panel.classList.contains('min') ? 'show' : 'hide'; };
  const frame = (box, dir = new V3(.62, .42, -1)) => { const sph = box.getBoundingSphere(new THREE.Sphere()), dist = sph.radius / Math.tan(cam.fov * Math.PI / 360) * 1.08; cam.position.copy(sph.center).add(dir.clone().normalize().multiplyScalar(dist)); cam.near = Math.max(dist / 200, .02); cam.far = dist * 50; cam.updateProjectionMatrix(); ctl.target.copy(sph.center); ctl.update(); };
  const focus = n => { const g = root.getObjectByName(n); frame(new THREE.Box3().setFromObject(g, true), cfg.focusDir ? v3(cfg.focusDir) : undefined); };
  const contact = () => frame(new THREE.Box3().setFromObject(root, true), new V3(.35, .62, -1));
  panel.querySelectorAll('tr.as').forEach(tr => tr.onclick = () => focus(tr.dataset.n));
  panel.querySelector('#evContact').onclick = contact;
  const tintMeshes = []; root.traverse(o => { if (o.isMesh && o.name.endsWith('_Tint')) tintMeshes.push(o); });
  const tintMats = [...new Set(tintMeshes.flatMap(m => Array.isArray(m.material) ? m.material : [m.material]))];
  const palette = cfg.tintPalette || [0xd9c7a4, 0x9fbfae, 0xc98d74, 0xb7c3cf, 0xe0d29a];
  let tintOn = false; const setTint = on => { tintOn = on; tintMeshes.forEach((m, i) => { const mats = Array.isArray(m.material) ? m.material : [m.material]; if (on) { const cl = mats.map(mm => { const c = mm.clone(); c.color.set(palette[i % palette.length]); return c; }); m.userData._orig = m.material; m.material = Array.isArray(m.material) ? cl : cl[0]; } else if (m.userData._orig) { m.material = m.userData._orig; delete m.userData._orig; } }); };
  const tb = panel.querySelector('#evTint'); if (tb) tb.onclick = () => { const on = tb.getAttribute('aria-pressed') !== 'true'; tb.setAttribute('aria-pressed', on); setTint(on); };
  panel.querySelector('#evGlb').onclick = async () => { const msg = panel.querySelector('#evMsg'); msg.textContent = 'exporting…'; const was = tintOn; if (was) setTint(false);
    try { const { GLTFExporter } = await import('three/addons/exporters/GLTFExporter.js'); const buf = await new GLTFExporter().parseAsync(root, { binary: true, embedImages: true, onlyVisible: true });
      const url = URL.createObjectURL(new Blob([buf], { type: 'model/gltf-binary' })), a = document.createElement('a'); a.href = url; a.download = cfg.filename; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 4000); msg.textContent = (buf.byteLength / 1048576).toFixed(1) + ' MB'; }
    catch (e) { msg.textContent = 'failed: ' + e.message; throw e; } finally { if (was) setTint(true); } };
  window.__pack = { rows: rows.map(r => ({ name: r.name, size: [r.size.x, r.size.y, r.size.z].map(v => +v.toFixed(2)), tris: r.tris, ok: r.ok, sizeOk: r.sizeOk, budOk: r.budOk, meshOk: r.meshOk, meshes: r.meshes })), okAll, extras, maxMesh: Math.max(...allMeshes.map(m => m[1])) };
  window.__focus = focus; window.__contact = contact; window.__setTint = setTint;
  window.__snap = () => { stage._renderer.setClearColor(0xd6d7d4, 1); stage._renderer.render(stage._scene, cam); let im = document.getElementById('evsnap'); if (!im) { im = document.createElement('img'); im.id = 'evsnap'; im.style.cssText = 'position:fixed;inset:0;width:100vw;height:100vh;z-index:50;object-fit:cover'; document.body.appendChild(im); } im.src = stage._renderer.domElement.toDataURL('image/jpeg', .92); panel.style.display = 'none'; };
  contact();
  return { rows, focus, contact };
}
