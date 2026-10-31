// Shared kit for Power_v2: PRNG, procedural canvas PBR textures, materials, geometry helpers, merge.
import * as THREE from 'three';
export { THREE };
export const V3 = THREE.Vector3, V2 = THREE.Vector2, TAU = Math.PI * 2, DEG = Math.PI / 180, YUP = new V3(0, 1, 0), DS = THREE.DoubleSide;
let seed = 20261104;
export const setSeed = s => { seed = s; };
export const rnd = () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
export const rr = (a, b) => a + (b - a) * rnd();
const rgba = (c, a) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;

/* ================= textures ================= */
export const cv = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
export function texFrom(c, srgb = true, rep = true) { const t = new THREE.CanvasTexture(c); if (srgb) t.colorSpace = THREE.SRGBColorSpace; if (rep) t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = 8; return t; }
export function normalFrom(hc, k = 2) {
  const w = hc.width, h = hc.height, s = hc.getContext('2d').getImageData(0, 0, w, h).data, o = cv(w, h), ctx = o.getContext('2d'), img = ctx.createImageData(w, h), d = img.data;
  for (let y = 0; y < h; y++) { const yu = ((y - 1 + h) % h) * w, yd = ((y + 1) % h) * w, yr = y * w;
    for (let x = 0; x < w; x++) { const xl = (x - 1 + w) % w, xr = (x + 1) % w, dx = (s[(yr + xr) * 4] - s[(yr + xl) * 4]) / 255 * k, dy = (s[(yd + x) * 4] - s[(yu + x) * 4]) / 255 * k, l = Math.hypot(dx, dy, 1), i = (yr + x) * 4;
      d[i] = (-dx / l * .5 + .5) * 255; d[i + 1] = (dy / l * .5 + .5) * 255; d[i + 2] = (1 / l * .5 + .5) * 255; d[i + 3] = 255; } }
  ctx.putImageData(img, 0, 0); return texFrom(o, false);
}
function blotch(x, W, H, n, col, r0, r1, a) { for (let i = 0; i < n; i++) { const px = rnd() * W, py = rnd() * H, r = rr(r0, r1), al = a * rr(.5, 1);
  for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) { const X = px + ox, Y = py + oy; if (X + r < 0 || X - r > W || Y + r < 0 || Y - r > H) continue;
    const g = x.createRadialGradient(X, Y, 0, X, Y, r); g.addColorStop(0, rgba(col, al)); g.addColorStop(1, rgba(col, 0)); x.fillStyle = g; x.fillRect(X - r, Y - r, 2 * r, 2 * r); } } }
function specks(x, W, H, n, cols, r0, r1, a0, a1) { for (let i = 0; i < n; i++) { x.globalAlpha = rr(a0, a1); x.fillStyle = cols[(rnd() * cols.length) | 0]; x.beginPath(); x.arc(rnd() * W, rnd() * H, rr(r0, r1), 0, TAU); x.fill(); } x.globalAlpha = 1; }
function chipPath(x, cx, cy, s) { x.beginPath(); const n = 7; for (let i = 0; i < n; i++) { const a = i / n * TAU, r = s * rr(.45, 1.1); i ? x.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r * rr(.6, 1)) : x.moveTo(cx + r, cy); } x.closePath(); }
function chips(c, h, W, H, n, smin, smax, cols = ['#6e4a2e', '#666a68']) { for (let i = 0; i < n; i++) { const px = rnd() * W, py = rnd() * H, s = rr(smin, smax);
  chipPath(c, px, py, s * 1.25); c.fillStyle = 'rgba(40,44,43,.45)'; c.fill(); chipPath(c, px, py, s); c.fillStyle = rnd() < .3 ? cols[0] : cols[1]; c.fill(); chipPath(h, px, py, s); h.fillStyle = '#5a5a5a'; h.fill(); } }
function strawDust(x, S, n) { for (let i = 0; i < n; i++) { x.globalAlpha = rr(.2, .55); x.fillStyle = rnd() < .5 ? '#cdb27a' : '#d8cfb4'; x.save(); x.translate(rnd() * S, rnd() * S); x.rotate(rnd() * TAU); x.fillRect(0, 0, rr(4, 16), 1.5); x.restore(); } x.globalAlpha = 1; }
function rustStreaks(x, W, H, n, a = .5) { for (let i = 0; i < n; i++) { const sx = rnd() * W, sy = rnd() * H, L = rr(H * .06, H * .25), g = x.createLinearGradient(0, sy, 0, sy + L); g.addColorStop(0, `rgba(122,62,26,${a})`); g.addColorStop(1, 'rgba(122,62,26,0)'); x.fillStyle = g; x.fillRect(sx, sy, rr(2, 6), L); } }
const plate = (W, H, draw) => { const c = cv(W, H), x = c.getContext('2d'); draw(x, W, H); return texFrom(c, true, false); };
function paint(S, base, light, dark, nChip, chipCols) { const c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d');
  x.fillStyle = base; x.fillRect(0, 0, S, S); blotch(x, S, S, 40, light, S * .03, S * .12, .32); blotch(x, S, S, 40, dark, S * .03, S * .12, .28);
  specks(x, S, S, S * 3, ['#c8bc98', '#a89a74'], .5, 1.6, .08, .3); h.fillStyle = '#b0b0b0'; h.fillRect(0, 0, S, S); specks(h, S, S, S * 2, ['#a4a4a4', '#bcbcbc'], 1, 3, .4, .8);
  chips(x, h, S, S, nChip, S * .0015, S * .005, chipCols); return { c, x, hc, h }; }

export function makeTextures() {
  const T = {};
  { const S = 1024, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#a6a195'; x.fillRect(0, 0, S, S);
    blotch(x, S, S, 50, [198, 193, 182], 60, 200, .22); blotch(x, S, S, 50, [116, 110, 100], 50, 180, .18); specks(x, S, S, 9000, ['#8a857a', '#c0bbaf', '#6c685f', '#9b958a'], .5, 1.8, .25, .7);
    const hc = cv(S, S), h = hc.getContext('2d'); h.fillStyle = '#888'; h.fillRect(0, 0, S, S); blotch(h, S, S, 40, [170, 170, 170], 40, 150, .3); specks(h, S, S, 5000, ['#333', '#555'], .6, 2.2, .4, .9);
    T.concrete = texFrom(c); T.concreteN = normalFrom(hc, 1.6); }
  { const p = paint(1024, '#226f6b', [44, 132, 126], [18, 76, 74], 260); blotch(p.x, 1024, 1024, 22, [190, 172, 128], 40, 160, .26); strawDust(p.x, 1024, 1600); rustStreaks(p.x, 1024, 1024, 26, .4); T.teal = texFrom(p.c); T.tealN = normalFrom(p.hc, 2); }
  { const p = paint(1024, '#d7a312', [236, 190, 52], [168, 122, 10], 340, ['#5a4a2e', '#555a58']); blotch(p.x, 1024, 1024, 26, [150, 136, 104], 40, 180, .3); rustStreaks(p.x, 1024, 1024, 20, .35);
    for (let i = 0; i < 160; i++) { p.x.strokeStyle = `rgba(80,70,40,${rr(.1, .3)})`; p.x.lineWidth = rr(.6, 1.4); p.x.beginPath(); const sx = rnd() * 1024, sy = rnd() * 1024; p.x.moveTo(sx, sy); p.x.lineTo(sx + rr(-40, 40), sy + rr(-8, 8)); p.x.stroke(); }
    T.canopy = texFrom(p.c); T.canopyN = normalFrom(p.hc, 2); }
  { const S = 512, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#a9adac'; x.fillRect(0, 0, S, S); h.fillStyle = '#808080'; h.fillRect(0, 0, S, S);
    for (let i = 0; i < 380; i++) { const px = rnd() * S, py = rnd() * S, r = rr(10, 34), t = (rr(-24, 24)) | 0, k = 5 + ((rnd() * 4) | 0), pts = [];
      for (let j = 0; j < k; j++) { const a = j / k * TAU + rr(-.3, .3), q = r * rr(.6, 1.1); pts.push([Math.cos(a) * q, Math.sin(a) * q]); }
      for (const ox of [-S, 0, S]) for (const oy of [-S, 0, S]) { const X = px + ox, Y = py + oy; if (X + r < 0 || X - r > S || Y + r < 0 || Y - r > S) continue;
        for (const [ctx, col] of [[x, `rgba(${170 + t},${174 + t},${173 + t},.55)`], [h, `rgba(${128 + t * 2},${128 + t * 2},${128 + t * 2},.5)`]]) { ctx.fillStyle = col; ctx.beginPath(); pts.forEach(([a, b], j) => j ? ctx.lineTo(X + a, Y + b) : ctx.moveTo(X + a, Y + b)); ctx.closePath(); ctx.fill(); } } }
    blotch(x, S, S, 22, [118, 110, 94], 20, 90, .22); blotch(x, S, S, 14, [222, 226, 224], 20, 70, .2); specks(x, S, S, 2600, ['#8d918f', '#c9cccb', '#9a8a6a'], .5, 1.6, .2, .6); rustStreaks(x, S, S, 8, .25);
    T.galv = texFrom(c); T.galvN = normalFrom(hc, .8); }
  { // weathered timber, grain along u
    const W = 512, c = cv(W, W), x = c.getContext('2d'), hc = cv(W, W), h = hc.getContext('2d'); x.fillStyle = '#6f5034'; x.fillRect(0, 0, W, W); h.fillStyle = '#808080'; h.fillRect(0, 0, W, W);
    for (let y = 0; y < W; y++) { const v = Math.sin(y * .21 + Math.sin(y * .037) * 4) * .5 + .5, l = 74 + v * 40; x.fillStyle = `rgba(${l + 34},${l + 10},${l - 18},.55)`; x.fillRect(0, y, W, 1); h.fillStyle = `rgb(${90 + v * 90},${90 + v * 90},${90 + v * 90})`; h.fillRect(0, y, W, 1); }
    for (let i = 0; i < 260; i++) { const y = rnd() * W; x.strokeStyle = `rgba(40,26,14,${rr(.15, .4)})`; x.lineWidth = rr(.6, 1.6); x.beginPath(); x.moveTo(0, y); for (let px = 0; px <= W; px += 32) x.lineTo(px, y + Math.sin(px * .02 + i) * 3); x.stroke(); }
    for (let i = 0; i < 6; i++) { const px = rnd() * W, py = rnd() * W; for (let r = 18; r > 2; r -= 3) { x.strokeStyle = `rgba(52,32,16,.35)`; x.lineWidth = 1.4; x.beginPath(); x.ellipse(px, py, r * 1.8, r * .7, 0, 0, TAU); x.stroke(); } h.fillStyle = '#444'; h.beginPath(); h.ellipse(px, py, 8, 4, 0, 0, TAU); h.fill(); }
    blotch(x, W, W, 30, [140, 132, 118], 20, 80, .3); blotch(x, W, W, 20, [40, 30, 22], 20, 60, .2); specks(x, W, W, 1200, ['#3a2a1a', '#b4a68c'], .5, 1.5, .2, .5);
    T.timber = texFrom(c); T.timberN = normalFrom(hc, 1.4); }
  { // cast iron: dark, rough, rust blooms
    const S = 512, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#3b3a38'; x.fillRect(0, 0, S, S); h.fillStyle = '#808080'; h.fillRect(0, 0, S, S);
    specks(x, S, S, 9000, ['#2c2b29', '#4a4845', '#55524e'], .5, 1.6, .3, .8); specks(h, S, S, 9000, ['#6a6a6a', '#9a9a9a'], .5, 1.6, .4, .9);
    blotch(x, S, S, 30, [110, 58, 28], 10, 50, .35); blotch(x, S, S, 30, [30, 28, 26], 20, 70, .3); rustStreaks(x, S, S, 14, .4); T.iron = texFrom(c); T.ironN = normalFrom(hc, 1.6); }
  { const S = 512, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#b9bcbe'; x.fillRect(0, 0, S, S); for (let i = 0; i < 900; i++) { x.fillStyle = `rgba(${rnd() < .5 ? '255,255,255' : '90,94,98'},${rr(.03, .12)})`; x.fillRect(0, rnd() * S, S, rr(.5, 2)); } blotch(x, S, S, 14, [150, 140, 120], 20, 80, .18); T.alu = texFrom(c); }
  { // mono PERC cells: 6 × 12 per panel, white backsheet gaps, chamfered corners, busbars + fingers
    const W = 600, H = 1200, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#e8ebee'; x.fillRect(0, 0, W, H); const cw = W / 6, ch = H / 12, g = 6, k = 12;
    for (let j = 0; j < 12; j++) for (let i = 0; i < 6; i++) { const x0 = i * cw + g / 2, y0 = j * ch + g / 2, w = cw - g, hh = ch - g;
      const gr = x.createLinearGradient(x0, y0, x0 + w, y0 + hh); gr.addColorStop(0, '#16213a'); gr.addColorStop(.5, '#0d1628'); gr.addColorStop(1, '#141d33'); x.fillStyle = gr;
      x.beginPath(); x.moveTo(x0 + k, y0); x.lineTo(x0 + w - k, y0); x.lineTo(x0 + w, y0 + k); x.lineTo(x0 + w, y0 + hh - k); x.lineTo(x0 + w - k, y0 + hh); x.lineTo(x0 + k, y0 + hh); x.lineTo(x0, y0 + hh - k); x.lineTo(x0, y0 + k); x.closePath(); x.fill();
      x.fillStyle = 'rgba(160,176,196,.18)'; for (let f = 4; f < hh; f += 4) x.fillRect(x0 + 2, y0 + f, w - 4, .7);
      x.fillStyle = 'rgba(214,220,228,.85)'; for (let b = 1; b <= 4; b++) x.fillRect(x0 + w * b / 5 - 1, y0 + 1, 2, hh - 2); }
    specks(x, W, H, 300, ['#bdb6a0'], .5, 1.2, .1, .3); T.cells = texFrom(c, true, false); }
  { const S = 512, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#a7abac'; x.fillRect(0, 0, S, S); h.fillStyle = '#909090'; h.fillRect(0, 0, S, S);
    for (const px of [0, S / 2]) { x.fillStyle = 'rgba(70,74,76,.55)'; x.fillRect(px, 0, 4, S); x.fillStyle = 'rgba(230,232,232,.5)'; x.fillRect(px + 4, 0, 3, S); h.fillStyle = '#f0f0f0'; h.fillRect(px, 0, 8, S); }
    blotch(x, S, S, 22, [190, 194, 196], 20, 80, .3); blotch(x, S, S, 18, [110, 104, 92], 20, 70, .22); specks(x, S, S, 1600, ['#8c9092', '#cfd2d3'], .5, 1.4, .2, .5);
    for (let i = 0; i < 26; i++) { h.fillStyle = 'rgba(60,60,60,.4)'; h.beginPath(); h.ellipse(rnd() * S, rnd() * S, rr(6, 18), rr(4, 10), rnd() * 3, 0, TAU); h.fill(); }
    T.lagging = texFrom(c); T.laggingN = normalFrom(hc, 2); }
  { const S = 512, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#8c8478'; x.fillRect(0, 0, S, S); h.fillStyle = '#404040'; h.fillRect(0, 0, S, S); const bw = 128, bh = 56;
    for (let j = 0; j < S / bh + 1; j++) for (let i = -1; i < S / bw + 1; i++) { const ox = i * bw + (j % 2) * bw / 2, oy = j * bh; const l = rr(.85, 1.1); x.fillStyle = `rgb(${190 * l | 0},${102 * l | 0},${58 * l | 0})`; x.fillRect(ox + 3, oy + 3, bw - 6, bh - 6); h.fillStyle = '#c0c0c0'; h.fillRect(ox + 3, oy + 3, bw - 6, bh - 6); }
    blotch(x, S, S, 30, [40, 30, 24], 20, 80, .35); specks(x, S, S, 3000, ['#6a3a22', '#d8a070', '#2a2220'], .5, 1.6, .2, .6); T.brick = texFrom(c); T.brickN = normalFrom(hc, 3); }
  { const S = 512, c = cv(S, S), x = c.getContext('2d'), hc = cv(S, S), h = hc.getContext('2d'); x.fillStyle = '#9a978f'; x.fillRect(0, 0, S, S); blotch(x, S, S, 40, [170, 166, 156], 30, 120, .25); blotch(x, S, S, 30, [92, 88, 80], 20, 90, .25);
    for (let i = 0; i < 40; i++) { const sx = rnd() * S, L = rr(80, 400), g = x.createLinearGradient(0, 0, 0, L); g.addColorStop(0, 'rgba(60,58,50,.35)'); g.addColorStop(1, 'rgba(60,58,50,0)'); x.fillStyle = g; x.fillRect(sx, rnd() * S, rr(3, 12), L); }
    specks(x, S, S, 6000, ['#6c685f', '#c0bbaf'], .5, 1.6, .2, .6); h.fillStyle = '#888'; h.fillRect(0, 0, S, S); specks(h, S, S, 4000, ['#444', '#bbb'], .6, 2, .4, .9);
    T.pole = texFrom(c); T.poleN = normalFrom(hc, 1.4); }
  { const S = 256, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#e3ae12'; x.fillRect(0, 0, S, S); x.fillStyle = '#1b1b19';
    for (let i = -3; i < 4; i++) { x.beginPath(); x.moveTo(i * 128, S); x.lineTo(i * 128 + 64, S); x.lineTo(i * 128 + 64 + S, 0); x.lineTo(i * 128 + S, 0); x.closePath(); x.fill(); }
    specks(x, S, S, 700, ['#a7a296', '#6d685f'], .6, 2.6, .3, .8); T.hazard = texFrom(c); }
  { const S = 256, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#d9a914'; for (let i = 0; i < 4; i++) { x.fillRect(i * 64, 0, 9, S); x.fillRect(0, i * 64, S, 9); } T.mesh = texFrom(c); }
  { const S = 256, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#2a2b2a'; x.fillRect(0, 0, S, S); for (let i = 0; i < 32; i++) { x.fillStyle = i % 2 ? '#5d6160' : '#3a3c3b'; x.fillRect(0, i * 8, S, 4); } for (let i = 0; i < 16; i++) { x.fillStyle = 'rgba(20,20,20,.8)'; x.fillRect(i * 16, 0, 2, S); } T.radiator = texFrom(c); }
  { const S = 512, c = cv(S, S), x = c.getContext('2d'); x.fillStyle = '#1b1c1b'; x.fillRect(0, 0, S, S); for (let i = 0; i < 260; i++) { x.fillStyle = `rgba(90,88,84,${rr(.05, .18)})`; x.fillRect(0, rnd() * S, S, rr(1, 3)); } T.rubber = texFrom(c); }
  { // battery case: translucent green-grey with moulded MAX/MIN level lines
    const W = 256, H = 256, c = cv(W, H), x = c.getContext('2d'); x.fillStyle = '#9fb3a4'; x.fillRect(0, 0, W, H); blotch(x, W, H, 10, [180, 196, 184], 20, 60, .3);
    for (const [y, t] of [[H * .2, 'MAX'], [H * .36, 'MIN']]) { x.fillStyle = '#e8f0ea'; x.fillRect(0, y, W, 3); x.font = '600 18px "IBM Plex Mono",monospace'; x.fillText(t, 8, y - 4); }
    T.cellCase = texFrom(c); }
  T.fire = plate(256, 256, (x, W) => { const g = x.createLinearGradient(0, W, 0, 0); g.addColorStop(0, '#ff6a00'); g.addColorStop(.5, '#ffb030'); g.addColorStop(1, '#3a0800'); x.fillStyle = g; x.fillRect(0, 0, W, W);
    for (let i = 0; i < 40; i++) { const px = rnd() * W, h = rr(60, 200); const fg = x.createLinearGradient(0, W, 0, W - h); fg.addColorStop(0, 'rgba(255,240,170,.9)'); fg.addColorStop(1, 'rgba(255,120,20,0)'); x.fillStyle = fg; x.beginPath(); x.moveTo(px - 14, W); x.quadraticCurveTo(px + rr(-20, 20), W - h * .6, px + rr(-6, 6), W - h); x.quadraticCurveTo(px + rr(-20, 20), W - h * .5, px + 14, W); x.fill(); }
    for (let i = 0; i < 200; i++) { x.fillStyle = `rgba(255,${rr(120, 220) | 0},40,${rr(.3, .9)})`; x.beginPath(); x.arc(rnd() * W, W - rr(0, 50), rr(2, 7), 0, TAU); x.fill(); } });
  T.leaf = plate(128, 128, (x, W) => { x.translate(W / 2, W / 2); x.rotate(.6); x.fillStyle = '#8a6a2e'; x.beginPath(); x.ellipse(0, 0, 50, 20, 0, 0, TAU); x.fill(); x.strokeStyle = '#5a3e18'; x.lineWidth = 2; x.beginPath(); x.moveTo(-54, 0); x.lineTo(50, 0); x.stroke(); for (let i = -3; i <= 3; i++) { x.beginPath(); x.moveTo(i * 12, 0); x.lineTo(i * 12 + 10, i % 2 ? 14 : -14); x.stroke(); } });
  const decal = (W, H, draw) => { const c = cv(W, H), x = c.getContext('2d'); draw(x, W, H); return texFrom(c, true, false); };
  const radial = (col, a, n, r0, r1, spread) => decal(512, 512, (x, W) => { for (let i = 0; i < n; i++) { const r = rr(r0, r1), px = W / 2 + rr(-spread, spread), py = W / 2 + rr(-spread, spread); const g = x.createRadialGradient(px, py, 0, px, py, r); g.addColorStop(0, rgba(col, a)); g.addColorStop(.7, rgba(col, a * .5)); g.addColorStop(1, rgba(col, 0)); x.fillStyle = g; x.fillRect(0, 0, W, W); } });
  T.oil = radial([22, 18, 12], .16, 26, 40, 150, 110); T.soot = radial([12, 12, 12], .3, 30, 40, 170, 90); T.worn = radial([118, 96, 66], .3, 24, 50, 170, 90);
  T.dust = decal(512, 512, (x, W) => { for (let i = 0; i < 30; i++) { const r = rr(50, 170), px = W / 2 + rr(-100, 100), py = W / 2 + rr(-100, 100); const g = x.createRadialGradient(px, py, 0, px, py, r); g.addColorStop(0, 'rgba(196,176,124,.22)'); g.addColorStop(1, 'rgba(196,176,124,0)'); x.fillStyle = g; x.fillRect(0, 0, W, W); }
    for (let i = 0; i < 900; i++) { const a = rnd() * TAU, d = Math.sqrt(rnd()) * 210; x.fillStyle = `rgba(${rnd() < .5 ? '214,182,110' : '176,150,96'},${rr(.3, .8)})`; x.save(); x.translate(W / 2 + Math.cos(a) * d, W / 2 + Math.sin(a) * d); x.rotate(rnd() * TAU); x.fillRect(0, 0, rr(4, 14), 1.6); x.restore(); } });
  T.sootBand = decal(64, 512, (x, W, H) => { const g = x.createLinearGradient(0, 0, 0, H); g.addColorStop(0, 'rgba(14,14,14,.9)'); g.addColorStop(.55, 'rgba(30,28,26,.45)'); g.addColorStop(1, 'rgba(30,28,26,0)'); x.fillStyle = g; x.fillRect(0, 0, W, H); });
  T.rust = decal(128, 512, (x, W, H) => { for (let i = 0; i < 9; i++) { const px = rr(20, 108), L = rr(180, 500), g = x.createLinearGradient(0, 0, 0, L); g.addColorStop(0, 'rgba(126,62,24,.75)'); g.addColorStop(1, 'rgba(126,62,24,0)'); x.fillStyle = g; x.fillRect(px, 0, rr(3, 10), L); } });
  // --- signs / plates / dials ---
  const bolt = (x, cx, cy, s, col) => { x.fillStyle = col; x.beginPath(); [[.15, -1], [-.45, .12], [-.02, .12], [-.2, 1], [.45, -.15], [.05, -.15], [.25, -1]].forEach(([a, b], i) => { const X = cx + a * s, Y = cy + b * s; i ? x.lineTo(X, Y) : x.moveTo(X, Y); }); x.closePath(); x.fill(); };
  const tri = (x, cx, ty, s) => { x.fillStyle = '#111'; x.beginPath(); x.moveTo(cx, ty); x.lineTo(cx + s, ty + s * 1.7); x.lineTo(cx - s, ty + s * 1.7); x.closePath(); x.fill(); x.fillStyle = '#f1c40f'; x.beginPath(); x.moveTo(cx, ty + s * .35); x.lineTo(cx + s * .72, ty + s * 1.55); x.lineTo(cx - s * .72, ty + s * 1.55); x.closePath(); x.fill(); };
  const FS = '"IBM Plex Sans Condensed",sans-serif', FM = '"IBM Plex Mono",monospace';
  T.signHV = plate(512, 384, (x, W, H) => { x.fillStyle = '#f1c40f'; x.fillRect(0, 0, W, H); x.strokeStyle = '#111'; x.lineWidth = 14; x.strokeRect(10, 10, W - 20, H - 20); tri(x, W / 2, 30, 90); bolt(x, W / 2, 128, 50, '#111');
    x.fillStyle = '#111'; x.textAlign = 'center'; const fit = (t, px, wt, y) => { let p = px; do { x.font = `${wt} ${p}px ${FS}`; p -= 2; } while (x.measureText(t).width > W - 60 && p > 10); x.fillText(t, W / 2, y); }; fit('DANGER HIGH VOLTAGE', 58, 700, 280); fit('อันตราย ไฟฟ้าแรงสูง', 34, 500, 334); specks(x, W, H, 300, ['#8a8574', '#c9b26a'], .6, 2, .2, .5); });
  T.signThai = plate(384, 448, (x, W, H) => { x.fillStyle = '#f4f2ec'; x.fillRect(0, 0, W, H); x.strokeStyle = '#c0201a'; x.lineWidth = 16; x.strokeRect(12, 12, W - 24, H - 24); bolt(x, W / 2, 150, 92, '#c0201a');
    x.fillStyle = '#c0201a'; x.textAlign = 'center'; x.font = `700 92px ${FS}`; x.fillText('อันตราย', W / 2, 330); x.font = `600 30px ${FS}`; x.fillText('ไฟฟ้าแรงสูง ห้ามปีน', W / 2, 390); blotch(x, W, H, 8, [120, 100, 70], 20, 60, .25); rustStreaks(x, W, H, 5, .4); });
  T.poleTag = plate(256, 128, (x, W, H) => { x.fillStyle = '#c7cacb'; x.fillRect(0, 0, W, H); x.strokeStyle = '#333'; x.lineWidth = 4; x.strokeRect(6, 6, W - 12, H - 12); x.fillStyle = '#1d1d1d'; x.textAlign = 'center'; x.font = `700 54px ${FM}`; x.fillText('12-0347', W / 2, 82); });
  T.noSmoke = plate(768, 192, (x, W, H) => { x.fillStyle = '#f4f3ee'; x.fillRect(0, 0, W, H); x.strokeStyle = '#111'; x.lineWidth = 8; x.strokeRect(6, 6, W - 12, H - 12);
    x.strokeStyle = '#c0201a'; x.lineWidth = 14; x.beginPath(); x.arc(96, 96, 62, 0, TAU); x.stroke(); x.fillStyle = '#111'; x.fillRect(52, 88, 80, 16); x.strokeStyle = '#c0201a'; x.beginPath(); x.moveTo(52, 52); x.lineTo(140, 140); x.stroke();
    tri(x, W - 96, 30, 46); x.fillStyle = '#111'; x.fillRect(W - 112, 84, 30, 30);
    x.fillStyle = '#111'; x.textAlign = 'center'; x.font = `700 58px ${FS}`; x.fillText('NO SMOKING · ACID', W / 2, 92); x.font = `500 30px ${FS}`; x.fillText('ห้ามสูบบุหรี่ · กรดกัดกร่อน', W / 2, 146); });
  T.namePlate = (l1, l2, l3, bg = '#b7b9b5', ink = '#1e201f') => plate(512, 256, (x, W, H) => { x.fillStyle = bg; x.fillRect(0, 0, W, H); for (let i = 0; i < 300; i++) { x.fillStyle = `rgba(255,255,255,${rr(0, .12)})`; x.fillRect(0, rnd() * H, W, 1); }
    x.strokeStyle = ink; x.lineWidth = 6; x.strokeRect(22, 22, W - 44, H - 44); x.fillStyle = ink; x.textAlign = 'center'; x.font = `700 54px ${FS}`; x.fillText(l1, W / 2, 98); x.font = `600 22px ${FM}`; x.fillText(l2, W / 2, 146); x.fillText(l3, W / 2, 182);
    x.fillStyle = '#555'; for (const [a, b] of [[14, 14], [W - 14, 14], [14, H - 14], [W - 14, H - 14]]) { x.beginPath(); x.arc(a, b, 8, 0, TAU); x.fill(); } });
  T.hot = plate(256, 256, (x, W) => { tri(x, W / 2, 20, 100); x.strokeStyle = '#111'; x.lineWidth = 8; for (const o of [-30, 0, 30]) { x.beginPath(); x.moveTo(W / 2 + o, 200); x.bezierCurveTo(W / 2 + o - 20, 170, W / 2 + o + 20, 140, W / 2 + o, 110); x.stroke(); } });
  T.zap = plate(256, 256, (x, W) => { tri(x, W / 2, 20, 100); bolt(x, W / 2, 150, 52, '#111'); });
  T.dial = (unit, max, red, face = '#f4f3ee') => plate(256, 256, (x, W) => { x.fillStyle = face; x.fillRect(0, 0, W, W); const c = W / 2;
    x.strokeStyle = '#c0392b'; x.lineWidth = 12; x.beginPath(); x.arc(c, c, 92, (135 + 270 * red) * DEG, 405 * DEG); x.stroke();
    x.strokeStyle = '#111'; for (let i = 0; i <= 40; i++) { const a = (135 + i / 40 * 270) * DEG, r0 = i % 5 ? 92 : 82; x.lineWidth = i % 5 ? 2 : 4; x.beginPath(); x.moveTo(c + Math.cos(a) * r0, c + Math.sin(a) * r0); x.lineTo(c + Math.cos(a) * 100, c + Math.sin(a) * 100); x.stroke(); }
    x.fillStyle = '#111'; x.font = `600 18px ${FM}`; x.textAlign = 'center'; x.textBaseline = 'middle'; for (let i = 0; i <= 8; i++) { const a = (135 + i / 8 * 270) * DEG; x.fillText(String(Math.round(max * i / 8)), c + Math.cos(a) * 64, c + Math.sin(a) * 64); }
    x.font = `600 22px ${FM}`; x.fillText(unit, c, c + 52); const na = (135 + .55 * 270) * DEG; x.strokeStyle = '#111'; x.lineWidth = 5; x.beginPath(); x.moveTo(c - Math.cos(na) * 14, c - Math.sin(na) * 14); x.lineTo(c + Math.cos(na) * 90, c + Math.sin(na) * 90); x.stroke(); x.beginPath(); x.arc(c, c, 9, 0, TAU); x.fill(); });
  T.lcd = (lines, bg = '#0c1a22', fg = '#7cf0c0') => plate(512, 256, (x, W, H) => { x.fillStyle = bg; x.fillRect(0, 0, W, H); x.fillStyle = fg; x.font = `600 40px ${FM}`; lines.forEach((l, i) => x.fillText(l, 24, 64 + i * 56)); });
  T.label = (txt, bg, fg = '#111') => plate(512, 128, (x, W, H) => { x.fillStyle = bg; x.fillRect(0, 0, W, H); x.fillStyle = fg; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = `700 56px ${FS}`; x.fillText(txt, W / 2, H / 2 + 4); });
  return T;
}

/* ================= materials ================= */
export function mat(part, name, o, uvs = 1) { const m = new THREE.MeshStandardMaterial(o); m.name = name; m.userData.part = part; m.userData.uvScale = uvs; return m; }
export function decalMat(part, name, map, o = {}) { return mat(part, name, Object.assign({ map, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4, roughness: .9, metalness: 0 }, o)); }

/* ================= geometry ================= */
export const v3 = a => a.isVector3 ? a.clone() : new V3(a[0], a[1], a[2]);
export function boxG(w, h, d) { const g = new THREE.BoxGeometry(w, h, d), uv = g.attributes.uv, dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]]; for (let f = 0; f < 6; f++) for (let k = 0; k < 4; k++) { const i = f * 4 + k; uv.setXY(i, uv.getX(i) * dims[f][0], uv.getY(i) * dims[f][1]); } return g; }
export function bboxG(w, h, d, b = .03) { b = Math.min(b, w / 2 - .002, h / 2 - .002, d / 2 - .002); const s = new THREE.Shape(), x = w / 2 - b, y = h / 2 - b; s.moveTo(-x, -y); s.lineTo(x, -y); s.lineTo(x, y); s.lineTo(-x, y); s.closePath();
  const g = new THREE.ExtrudeGeometry(s, { depth: d - 2 * b, bevelEnabled: true, bevelThickness: b, bevelSize: b, bevelSegments: 1 }); g.translate(0, 0, -(d - 2 * b) / 2); return g; }
export function cylG(rt, rb, h, seg = 24, open = false, ts = 0, tl = TAU) { const g = new THREE.CylinderGeometry(rt, rb, h, seg, 1, open, ts, tl), uv = g.attributes.uv, su = (rt + rb) / 2 * tl; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * su, uv.getY(i) * h); return g; }
export const hexG = (r, h) => new THREE.CylinderGeometry(r, r, h, 6);
export const alongX = g => g.rotateZ(-Math.PI / 2), alongZ = g => g.rotateX(Math.PI / 2);
export function revolve(prof, seg = 32) { const pos = [], nor = [], uv = []; let acc = 0;
  for (let i = 0; i < prof.length - 1; i++) { const [r0, y0] = prof[i], [r1, y1] = prof[i + 1], dr = r1 - r0, dy = y1 - y0, L = Math.hypot(dr, dy) || 1, nr = dy / L, ny = -dr / L;
    for (let s = 0; s < seg; s++) { const a0 = TAU * s / seg, a1 = TAU * (s + 1) / seg, P = (r, y, a) => [r * Math.sin(a), y, r * Math.cos(a)], N = a => [nr * Math.sin(a), ny, nr * Math.cos(a)], ra = (r0 + r1) / 2;
      const A = P(r0, y0, a0), B = P(r0, y0, a1), C = P(r1, y1, a1), D = P(r1, y1, a0), nA = N(a0), nB = N(a1);
      pos.push(...A, ...B, ...C, ...A, ...C, ...D); nor.push(...nA, ...nB, ...nB, ...nA, ...nB, ...nA); uv.push(a0 * ra, acc, a1 * ra, acc, a1 * ra, acc + L, a0 * ra, acc, a1 * ra, acc + L, a0 * ra, acc + L); }
    acc += L; }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); return g; }
export const latheX = (p, s) => revolve(p, s).rotateZ(-Math.PI / 2), latheZ = (p, s) => revolve(p, s).rotateX(Math.PI / 2);
export const ringProf = (ri, ro, w, ch = 0) => ch ? [[ri, -w / 2], [ro - ch, -w / 2], [ro, -w / 2 + ch], [ro, w / 2 - ch], [ro - ch, w / 2], [ri, w / 2], [ri, -w / 2]] : [[ri, -w / 2], [ro, -w / 2], [ro, w / 2], [ri, w / 2], [ri, -w / 2]];
export function frustumG(bw, bd, tw, td, h) { const g = boxG(bw, h, bd).toNonIndexed(), p = g.attributes.position; for (let i = 0; i < p.count; i++) if (p.getY(i) > 0) { p.setX(i, p.getX(i) * tw / bw); p.setZ(i, p.getZ(i) * td / bd); } g.computeVertexNormals(); return g; }
export function gearG(R, n, th, h = .045, holes = 0, hr = 0) { const s = new THREE.Shape(); let first = true;
  for (let i = 0; i < n; i++) { const a0 = i / n * TAU, da = TAU / n; for (const [f, r] of [[0, R - h], [.18, R - h], [.34, R + h], [.66, R + h], [.82, R - h]]) { const a = a0 + f * da, X = r * Math.cos(a), Y = r * Math.sin(a); first ? (s.moveTo(X, Y), first = false) : s.lineTo(X, Y); } }
  s.closePath(); for (let k = 0; k < holes; k++) { const a = k / holes * TAU, p = new THREE.Path(); p.absarc(Math.cos(a) * R * .55, Math.sin(a) * R * .55, hr, 0, TAU, true); s.holes.push(p); }
  const g = new THREE.ExtrudeGeometry(s, { depth: th, bevelEnabled: false, curveSegments: 10 }); g.translate(0, 0, -th / 2); return g; }
export function tubeG(pts, r, radial = 8, tension = .3) { const P = pts.map(v3), c = new THREE.CatmullRomCurve3(P, false, 'catmullrom', tension); let L = 0; for (let i = 1; i < P.length; i++) L += P[i].distanceTo(P[i - 1]);
  const g = new THREE.TubeGeometry(c, Math.max(8, Math.round(L * 10)), r, radial, false), uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * L, uv.getY(i) * TAU * r); return g; }
export function helixG(R, r, turns, y0, y1, seg = 220, radial = 6) { const pts = []; for (let i = 0; i <= seg; i++) { const t = i / seg, a = t * turns * TAU; pts.push(new V3(R * Math.cos(a), y0 + (y1 - y0) * t, R * Math.sin(a))); } return new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), seg, r, radial, false); }
export function add(g, geo, m, p = [0, 0, 0], r = [0, 0, 0], s) { const o = new THREE.Mesh(geo, m); o.position.copy(v3(p)); o.rotation.set(r[0], r[1], r[2]); if (s) o.scale.set(s[0], s[1], s[2]); g.add(o); return o; }
export function orient(o, dir) { o.quaternion.setFromUnitVectors(YUP, v3(dir).normalize()); return o; }
export function pipe(g, m, a, b, r, seg = 16, open = false) { a = v3(a); b = v3(b); const d = b.clone().sub(a), o = new THREE.Mesh(cylG(r, r, d.length(), seg, open), m); o.position.copy(a).add(b).multiplyScalar(.5); orient(o, d); g.add(o); return o; }
export function beam(g, m, a, b, w, h) { a = v3(a); b = v3(b); const d = b.clone().sub(a), o = new THREE.Mesh(boxG(w, d.length(), h), m); o.position.copy(a).add(b).multiplyScalar(.5); orient(o, d); g.add(o); return o; }
export function sub(parent, pos, dir) { const s = new THREE.Group(); s.position.copy(v3(pos)); if (dir) orient(s, dir); parent.add(s); return s; }
function elbow(g, m, start, u, v, R, r, seg, tub) { const o = new THREE.Mesh(new THREE.TorusGeometry(R, r, seg, tub, Math.PI / 2), m), xl = v.clone().negate(), yl = u.clone(), zl = new V3().crossVectors(xl, yl); o.quaternion.setFromRotationMatrix(new THREE.Matrix4().makeBasis(xl, yl, zl)); o.position.copy(start).addScaledVector(v, R); g.add(o); return o; }
export function duct(g, m, pts, r, R, seg = 20, tub = 8, onSeg) { const P = pts.map(v3);
  for (let i = 0; i < P.length - 1; i++) { const a = P[i].clone(), b = P[i + 1].clone(), d = b.clone().sub(a).normalize(); if (i > 0) a.addScaledVector(d, R); if (i < P.length - 2) b.addScaledVector(d, -R);
    if (a.distanceTo(b) > 1e-3) pipe(g, m, a, b, r, seg); if (onSeg) onSeg(a, b, d); if (i < P.length - 2) elbow(g, m, b, d, P[i + 2].clone().sub(P[i + 1]).normalize(), R, r, seg, tub); } }
export const plane = (w, h) => new THREE.PlaneGeometry(w, h);

/* merge each group into one mesh per material: <Group>_<Part> (split if > 19k tris) */
export function mergeGroup(grp) {
  grp.updateMatrixWorld(true); const inv = grp.matrixWorld.clone().invert(), byMat = new Map();
  grp.traverse(o => { if (!o.isMesh) return; let geo = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
    for (const k of Object.keys(geo.attributes)) if (!['position', 'normal', 'uv'].includes(k)) geo.deleteAttribute(k);
    if (!geo.attributes.normal) geo.computeVertexNormals(); if (!geo.attributes.uv) geo.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(geo.attributes.position.count * 2), 2));
    geo.applyMatrix4(inv.clone().multiply(o.matrixWorld)); const sc = o.material.userData.uvScale || 1;
    if (sc !== 1) { const uv = geo.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * sc, uv.getY(i) * sc); }
    if (!byMat.has(o.material)) byMat.set(o.material, []); byMat.get(o.material).push(geo); });
  for (const c of [...grp.children]) grp.remove(c);
  const out = [];
  for (const [m, list] of byMat) { const chunks = [[]]; let cnt = 0; for (const gg of list) { const n = gg.attributes.position.count; if (cnt + n > 57000 && chunks[chunks.length - 1].length) { chunks.push([]); cnt = 0; } chunks[chunks.length - 1].push(gg); cnt += n; }
    chunks.forEach((ch, ci) => { const tot = ch.reduce((s, gg) => s + gg.attributes.position.count, 0), pos = new Float32Array(tot * 3), nor = new Float32Array(tot * 3), uv = new Float32Array(tot * 2); let off = 0;
      for (const gg of ch) { const n = gg.attributes.position.count; pos.set(gg.attributes.position.array, off * 3); nor.set(gg.attributes.normal.array, off * 3); uv.set(gg.attributes.uv.array.subarray(0, n * 2), off * 2); off += n; }
      const geo = new THREE.BufferGeometry(); geo.setAttribute('position', new THREE.BufferAttribute(pos, 3)); geo.setAttribute('normal', new THREE.BufferAttribute(nor, 3)); geo.setAttribute('uv', new THREE.BufferAttribute(uv, 2)); geo.computeBoundingBox(); geo.computeBoundingSphere();
      const mesh = new THREE.Mesh(geo, m); mesh.name = `${grp.name}_${m.userData.part}${chunks.length > 1 ? '_' + (ci + 1) : ''}`; grp.add(mesh); out.push(mesh); }); }
  return out;
}
