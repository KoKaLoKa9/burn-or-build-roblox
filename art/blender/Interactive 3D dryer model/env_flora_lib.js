// Flora builders + textures for Pack 1 (also reused by the school's planter trees).
import { THREE, V3, TAU, DEG, YUP, DS, rnd, rr, pick, clamp, lerp, sstep, makeNoise, N, cv, field, pbr, simpleSet, lib, blotch, specks, wrapped, add, sub, pipe, beam, boxG, cylG, alongZ, revolve, tubeG, curve, blobG, cardG, makeAsset, v3 } from './env_common.js';

/* ================= textures ================= */
const cardTex = (W, H, draw) => { const c = cv(W, H), x = c.getContext('2d'), h = cv(W, H), y = h.getContext('2d'); y.fillStyle = '#000'; y.fillRect(0, 0, W, H); x.lineCap = y.lineCap = 'round'; draw(x, y, W, H); return { c, h }; };
function leafPath(x, cx, cy, L, w, a, tip = .35) { x.save(); x.translate(cx, cy); x.rotate(a); x.beginPath(); x.moveTo(0, 0); x.quadraticCurveTo(w, L * tip, 0, L); x.quadraticCurveTo(-w, L * tip, 0, 0); x.restore(); }
function leaf(x, y, cx, cy, L, w, a, col, hv = 170, rib = true) {
  leafPath(x, cx, cy, L, w, a); x.fillStyle = col; x.fill(); leafPath(y, cx, cy, L, w, a); y.fillStyle = `rgb(${hv},${hv},${hv})`; y.fill();
  if (rib) { const ex = cx - Math.sin(a) * L * .9, ey = cy + Math.cos(a) * L * .9; x.strokeStyle = 'rgba(230,240,190,.35)'; x.lineWidth = Math.max(1, w * .12); x.beginPath(); x.moveTo(cx, cy); x.lineTo(ex, ey); x.stroke(); y.strokeStyle = '#fff'; y.lineWidth = Math.max(1, w * .15); y.beginPath(); y.moveTo(cx, cy); y.lineTo(ex, ey); y.stroke(); }
}
const hsl = (h, s, l) => `hsl(${h},${s}%,${l}%)`;
function tiled(S, base, fn, k = 2, o = {}) { const nz = makeNoise(o.seed || 3); const c = field(S, S, (u, v, out) => fn(u, v, out, nz, 'c')); const h = field(S, S, (u, v, out) => fn(u, v, out, nz, 'h')); return { c, h }; }

const T = {};
const R = {
  palmBark: () => { const { c, h } = tiled(512, 0, (u, v, o, nz, m) => { const ring = Math.abs(Math.sin((v * 6 + nz.fbm2(u, v, 4, 3) * .6) * Math.PI)), scar = Math.pow(1 - ring, 6), fis = nz.fbm2(u * 3, v * .6, 6, 4), lich = nz.fbm2(u, v, 3, 3);
      if (m === 'c') { const g = 112 + (fis - .5) * 50 - scar * 46; o[0] = g * .98; o[1] = g * .95; o[2] = g * .9; if (lich > .64) { o[0] = lerp(o[0], 150, .5); o[1] = lerp(o[1], 156, .5); o[2] = lerp(o[2], 128, .5); } if (lich < .3) { o[0] *= .8; o[1] *= .78; o[2] *= .76; } }
      else o[0] = o[1] = o[2] = 150 - scar * 120 + (fis - .5) * 70; }, 2, { seed: 11 });
    return pbr('EV_PalmBark', { color: c, height: h, k: 3, roughBase: .9, roughAmp: .15, uv: .5 }); },
  palmBoot: () => { const { c, h } = tiled(256, 0, (u, v, o, nz, m) => { const f = nz.fbm2(u * 6, v * .5, 8, 4); if (m === 'c') { o[0] = 70 + f * 50; o[1] = 52 + f * 36; o[2] = 34 + f * 20; } else o[0] = o[1] = o[2] = f * 255; }, 2, { seed: 12 });
    return pbr('EV_PalmLeafBase', { color: c, height: h, k: 3, roughBase: .95, roughAmp: .1 }); },
  palmFan: () => fanTex(false), palmFanDead: () => fanTex(true),
  palmFruit: () => simpleSet('EV_PalmFruit', 0x231a1c, { rough: .35, dirt: .05, bump: 20 }),
  rainBark: () => { const { c, h } = tiled(512, 0, (u, v, o, nz, m) => { const f = nz.fbm2(u * 4, v * .7, 6, 5), furrow = Math.pow(Math.abs(Math.sin((u * 14 + f * 2.5) * Math.PI)), .5), mo = nz.fbm2(u, v, 3, 3);
      if (m === 'c') { const g = 56 + furrow * 46 + (f - .5) * 30; o[0] = g * 1.0; o[1] = g * .92; o[2] = g * .82; if (mo > .62) { o[0] = lerp(o[0], 96, .45); o[1] = lerp(o[1], 104, .45); o[2] = lerp(o[2], 78, .45); } }
      else o[0] = o[1] = o[2] = furrow * 220 + f * 35; }, 2, { seed: 13 });
    return pbr('EV_RainTreeBark', { color: c, height: h, k: 4, roughBase: .92, roughAmp: .1, uv: .5 }); },
  pineBark: () => { const { c, h } = tiled(512, 0, (u, v, o, nz, m) => { const pl = nz.n2(u * 10, v * 6, 10, 6), crack = Math.abs(nz.fbm2(u * 2, v * 1.2, 5, 3) - .5), edge = sstep(0, .06, crack), f = nz.fbm2(u, v, 8, 4);
      if (m === 'c') { const t = .7 + pl * .5; o[0] = (150 * t) * edge + 40 * (1 - edge); o[1] = (82 * t) * edge + 28 * (1 - edge); o[2] = (52 * t) * edge + 22 * (1 - edge); o[0] += (f - .5) * 30; }
      else o[0] = o[1] = o[2] = edge * (150 + pl * 90); }, 2, { seed: 14 });
    return pbr('EV_PineBark', { color: c, height: h, k: 4, roughBase: .9, roughAmp: .12, uv: .5 }); },
  frangiBark: () => { const { c, h } = tiled(256, 0, (u, v, o, nz, m) => { const f = nz.fbm2(u, v, 6, 4), scar = Math.max(0, nz.n2(u * 8, v * 8, 8) - .78) * 4;
      if (m === 'c') { o[0] = 128 + (f - .5) * 30 - scar * 40; o[1] = 126 + (f - .5) * 30 - scar * 40; o[2] = 108 + (f - .5) * 26 - scar * 30; } else o[0] = o[1] = o[2] = 128 + (f - .5) * 40 - scar * 120; }, 2, { seed: 15 });
    return pbr('EV_FrangipaniBark', { color: c, height: h, k: 2, roughBase: .75, roughAmp: .15, uv: 1 }); },
  bananaStem: () => { const { c, h } = tiled(512, 0, (u, v, o, nz, m) => { const st = nz.fbm2(u * 6, v * .4, 6, 4), dry = sstep(.52, .62, nz.fbm2(u * 2, v * .7, 3, 4)), stripe = .5 + .5 * Math.sin(u * TAU * 40);
      if (m === 'c') { const gr = [92 + st * 40, 112 + st * 40, 52 + st * 20], br = [122 + st * 30, 90 + st * 24, 54 + st * 14]; for (let i = 0; i < 3; i++) o[i] = lerp(gr[i], br[i], dry) * (.92 + stripe * .1); if (nz.n2(u * 30, v * 20, 30, 20) > .82) { o[0] *= .6; o[1] *= .5; o[2] *= .5; } }
      else o[0] = o[1] = o[2] = 128 + stripe * 50 + (st - .5) * 60; }, 2, { seed: 16 });
    return pbr('EV_BananaStem', { color: c, height: h, k: 1.5, roughBase: .6, roughAmp: .2, uv: .5 }); },
  bananaLeaf: () => bananaTex(false), bananaDead: () => bananaTex(true),
  bananaFruit: () => simpleSet('EV_BananaFruit', 0x6f8a32, { rough: .45, dirt: .08, bump: 20 }),
  bananaBud: () => simpleSet('EV_BananaBud', 0x5a2234, { rough: .4, dirt: .05 }),
  culm: () => { const { c, h } = tiled(512, 0, (u, v, o, nz, m) => { const node = Math.abs(((v * 2) % 1) - .5), n = nz.fbm2(u, v * .3, 6, 4), dust = sstep(.55, .7, nz.fbm2(u, v, 3, 3));
      if (m === 'c') { o[0] = 104 + n * 40 + dust * 50; o[1] = 128 + n * 36 + dust * 20; o[2] = 52 + n * 16 + dust * 30; if (node < .02) { o[0] *= .55; o[1] *= .6; o[2] *= .5; } else if (node < .05) { o[0] += 40; o[1] += 30; o[2] += 30; } }
      else o[0] = o[1] = o[2] = node < .02 ? 240 : 128 + (n - .5) * 40; }, 2, { seed: 17 });
    return pbr('EV_BambooCulm', { color: c, height: h, k: 2, roughBase: .45, roughAmp: .2, uv: .5 }); },
  foliageCore: () => { const S = 512, c = cv(S), x = c.getContext('2d'), h = cv(S), y = h.getContext('2d'); x.fillStyle = '#1f3518'; x.fillRect(0, 0, S, S); y.fillStyle = '#202020'; y.fillRect(0, 0, S, S);
    for (let i = 0; i < 2600; i++) { const px = rnd() * S, py = rnd() * S, a = rnd() * TAU, L = rr(10, 26); wrapped(S, S, px, py, L, (X, Y) => leaf(x, y, X, Y, L, L * .35, a, hsl(rr(84, 110), rr(30, 50), rr(12, 30)), rr(90, 220) | 0, false)); }
    return pbr('EV_FoliageCore', { color: c, height: h, k: 2, roughBase: .8, roughAmp: .15, uv: .5 }); },
  rainLeaf: () => clusterTex('EV_RainTreeLeaves', 1024, { h: [84, 104], s: [32, 52], l: [16, 36], L: [12, 20], n: 2600, twigs: 9, pinn: true, seed: 3 }),
  pineNeedle: () => { const { c, h } = cardTex(512, 512, (x, y, W, H) => { for (let t = 0; t < 9; t++) { const cx = rr(.25, .75) * W, cy = rr(.3, .8) * H, n = 140, R0 = rr(70, 140);
      x.strokeStyle = '#4a3020'; x.lineWidth = 6; x.beginPath(); x.moveTo(W / 2, H); x.lineTo(cx, cy); x.stroke(); y.strokeStyle = '#999'; y.lineWidth = 6; y.beginPath(); y.moveTo(W / 2, H); y.lineTo(cx, cy); y.stroke();
      for (let i = 0; i < n; i++) { const a = -Math.PI / 2 + rr(-1.5, 1.5), L = R0 * rr(.6, 1); x.strokeStyle = hsl(rr(78, 100), rr(30, 48), rr(18, 38)); x.lineWidth = rr(1.4, 2.6); x.beginPath(); x.moveTo(cx, cy); x.lineTo(cx + Math.cos(a) * L, cy + Math.sin(a) * L); x.stroke(); y.strokeStyle = '#ddd'; y.lineWidth = 2; y.beginPath(); y.moveTo(cx, cy); y.lineTo(cx + Math.cos(a) * L, cy + Math.sin(a) * L); y.stroke(); } } });
    return pbr('EV_PineNeedles', { color: c, height: h, k: 2, roughBase: .7, roughAmp: .2, alpha: true, rep: false }); },
  frangiLeaf: () => { const { c, h } = cardTex(256, 512, (x, y, W, H) => { leaf(x, y, W / 2, H * .98, H * .95, W * .62, Math.PI, hsl(96, 42, 30), 170);
      for (let i = 1; i < 14; i++) { const t = i / 14, cy = H * (.98 - t * .9); for (const s of [-1, 1]) { x.strokeStyle = 'rgba(210,230,160,.28)'; x.lineWidth = 2; x.beginPath(); x.moveTo(W / 2, cy); x.lineTo(W / 2 + s * W * .28 * Math.sin(t * Math.PI) * 1.2, cy - H * .03); x.stroke(); } } });
    return pbr('EV_FrangipaniLeaf', { color: c, height: h, k: 2, roughBase: .45, roughAmp: .2, alpha: true, rep: false }); },
  frangiFlower: () => { const { c, h } = cardTex(256, 256, (x, y, W) => { for (let f = 0; f < 4; f++) { const cx = [.3, .7, .35, .68][f] * W, cy = [.32, .35, .7, .7][f] * W, r = W * .2, rot = rnd() * TAU;
      for (let p = 0; p < 5; p++) { const a = rot + p / 5 * TAU; x.save(); x.translate(cx, cy); x.rotate(a); x.beginPath(); x.ellipse(r * .45, r * .12, r * .55, r * .3, .35, 0, TAU); const g = x.createLinearGradient(0, 0, r, 0); g.addColorStop(0, '#f2c42a'); g.addColorStop(.45, '#fbf4dc'); g.addColorStop(1, '#fffdf4'); x.fillStyle = g; x.fill(); x.restore();
        y.save(); y.translate(cx, cy); y.rotate(a); y.beginPath(); y.ellipse(r * .45, r * .12, r * .55, r * .3, .35, 0, TAU); y.fillStyle = '#ccc'; y.fill(); y.restore(); } } });
    return pbr('EV_FrangipaniFlower', { color: c, height: h, k: 1, roughBase: .5, roughAmp: .1, alpha: true, rep: false }); },
  bambooLeaf: () => { const { c, h } = cardTex(512, 512, (x, y, W, H) => { for (let t = 0; t < 7; t++) { const sx = rr(.2, .8) * W, sy = rr(.05, .3) * H, ex = sx + rr(-.2, .2) * W, ey = rr(.65, .95) * H;
      x.strokeStyle = '#7a8a3a'; x.lineWidth = 3; x.beginPath(); x.moveTo(sx, sy); x.lineTo(ex, ey); x.stroke(); y.strokeStyle = '#888'; y.lineWidth = 3; y.beginPath(); y.moveTo(sx, sy); y.lineTo(ex, ey); y.stroke();
      for (let i = 0; i < 9; i++) { const tt = rr(.1, 1), px = lerp(sx, ex, tt), py = lerp(sy, ey, tt), a = rr(-.8, .8) + (rnd() < .5 ? 0 : Math.PI * .1), L = rr(70, 130); leaf(x, y, px, py, L, L * .13, a, hsl(rr(70, 96), rr(30, 52), rr(22, 42)), 170); } } });
    return pbr('EV_BambooLeaves', { color: c, height: h, k: 2, roughBase: .6, roughAmp: .2, alpha: true, rep: false }); },
  bushLeaf: () => clusterTex('EV_ShrubLeaves', 512, { h: [86, 112], s: [34, 56], l: [18, 38], L: [22, 40], n: 900, twigs: 6, seed: 5 }),
  bushLeaf2: () => clusterTex('EV_ShrubLeavesYellow', 512, { h: [62, 88], s: [40, 58], l: [26, 46], L: [18, 34], n: 900, twigs: 6, seed: 6 }),
  bougain: () => clusterTex('EV_Bougainvillea', 512, { h: [86, 110], s: [30, 50], l: [18, 34], L: [20, 34], n: 520, twigs: 6, seed: 7, bracts: 520 }),
  epiphyte: () => { const { c, h } = cardTex(256, 256, (x, y, W) => { for (let i = 0; i < 9; i++) { const a = -Math.PI / 2 + rr(-1.1, 1.1); leaf(x, y, W / 2, W * .98, W * rr(.6, .9), W * .1, a + Math.PI, hsl(rr(80, 100), 45, rr(24, 38)), 170); } });
    return pbr('EV_EpiphyteFern', { color: c, height: h, k: 2, roughBase: .55, roughAmp: .2, alpha: true, rep: false }); },
  laterite: () => { const { c, h } = tiled(512, 0, (u, v, o, nz, m) => { const f = nz.fbm2(u, v, 6, 5), pit = nz.n2(u * 40, v * 40, 40), hole = sstep(.72, .8, pit), band = nz.fbm2(u * .5, v * 2, 3, 3);
      if (m === 'c') { o[0] = 150 + (f - .5) * 70 + band * 20; o[1] = 78 + (f - .5) * 40; o[2] = 46 + (f - .5) * 24; if (hole) { o[0] *= 1 - hole * .6; o[1] *= 1 - hole * .6; o[2] *= 1 - hole * .55; } if (f > .66) { o[0] = lerp(o[0], 180, .3); o[1] = lerp(o[1], 132, .3); o[2] = lerp(o[2], 90, .3); } }
      else o[0] = o[1] = o[2] = 150 + (f - .5) * 120 - hole * 130; }, 2, { seed: 18 });
    return pbr('EV_Laterite', { color: c, height: h, k: 3, roughBase: .92, roughAmp: .1, uv: .5 }); },
  granite: () => { const { c, h } = tiled(512, 0, (u, v, o, nz, m) => { const f = nz.fbm2(u, v, 5, 5), sp = nz.n2(u * 90, v * 90, 90), lich = nz.fbm2(u * 2, v * 2, 4, 4);
      if (m === 'c') { let g = 140 + (f - .5) * 50; let r = g, gg = g, b = g * .97; if (sp > .78) { r = gg = b = 40; } else if (sp < .18) { r = 196; gg = 176; b = 164; } if (lich > .64) { r = lerp(r, 160, .55); gg = lerp(gg, 158, .55); b = lerp(b, 110, .55); } if (lich < .28) { r *= .75; gg *= .75; b *= .72; } o[0] = r; o[1] = gg; o[2] = b; }
      else o[0] = o[1] = o[2] = 128 + (f - .5) * 100 + (sp - .5) * 40; }, 2, { seed: 19 });
    return pbr('EV_Granite', { color: c, height: h, k: 2.5, roughBase: .8, roughAmp: .2, uv: .5 }); },
  grassDry: () => bladeTex('EV_GrassBladesDry', [74, 82, 36], [196, 170, 102]),
  grassGreen: () => bladeTex('EV_GrassBladesGreen', [56, 86, 30], [150, 156, 76]),
  grassCard: () => { const { c, h } = cardTex(512, 512, (x, y, W, H) => { for (let i = 0; i < 260; i++) { const bx = rr(.1, .9) * W, L = rr(.45, .98) * H, bend = rr(-.35, .35) * W, col = rnd() < .55 ? hsl(rr(40, 52), rr(35, 55), rr(48, 70)) : hsl(rr(70, 90), rr(30, 45), rr(28, 44));
      x.strokeStyle = col; x.lineWidth = rr(2, 5); x.beginPath(); x.moveTo(bx, H); x.quadraticCurveTo(bx + bend * .3, H - L * .5, bx + bend, H - L); x.stroke(); y.strokeStyle = '#ccc'; y.lineWidth = 3; y.beginPath(); y.moveTo(bx, H); y.quadraticCurveTo(bx + bend * .3, H - L * .5, bx + bend, H - L); y.stroke(); } });
    return pbr('EV_GrassCard', { color: c, height: h, k: 1.5, roughBase: .85, roughAmp: .1, alpha: true, rep: false }); },
  seedHead: () => { const { c, h } = cardTex(128, 512, (x, y, W, H) => { x.strokeStyle = '#a08a58'; x.lineWidth = 3; x.beginPath(); x.moveTo(W / 2, H); x.lineTo(W / 2, 0); x.stroke(); for (let i = 0; i < 70; i++) { const py = rr(.02, .5) * H, a = rr(-.9, .9) - Math.PI / 2, L = rr(14, 34); x.strokeStyle = hsl(rr(32, 44), rr(30, 50), rr(56, 76)); x.lineWidth = 3; x.beginPath(); x.moveTo(W / 2, py); x.lineTo(W / 2 + Math.cos(a) * L * Math.sign(rr(-1, 1)), py + Math.sin(a) * L); x.stroke(); y.strokeStyle = '#bbb'; y.lineWidth = 3; y.beginPath(); y.moveTo(W / 2, py); y.lineTo(W / 2 + Math.cos(a) * L, py + Math.sin(a) * L); y.stroke(); } });
    return pbr('EV_GrassSeedHead', { color: c, height: h, k: 1, roughBase: .85, roughAmp: .1, alpha: true, rep: false }); },
  hammock: () => { const { c, h } = tiled(256, 0, (u, v, o, nz, m) => { const stripe = Math.floor(u * 8) % 4, cols = [[178, 52, 44], [222, 196, 120], [40, 92, 120], [222, 196, 120]], w = Math.sin(u * TAU * 64) * Math.sin(v * TAU * 64), d = nz.fbm2(u, v, 4, 3);
      if (m === 'c') { const cc = cols[stripe]; for (let i = 0; i < 3; i++) o[i] = cc[i] * (.85 + w * .08 + (d - .5) * .2); } else o[0] = o[1] = o[2] = 128 + w * 80; }, 2, { seed: 20 });
    return pbr('EV_HammockCloth', { color: c, height: h, k: 1.5, roughBase: .92, roughAmp: .05, side: DS }); },
  mat: () => { const { c, h } = tiled(256, 0, (u, v, o, nz, m) => { const a = Math.floor(u * 32), b = Math.floor(v * 32), wv = (a + b) % 2, d = nz.fbm2(u, v, 4, 3);
      if (m === 'c') { const g = wv ? 1 : .86; o[0] = 196 * g * (.9 + d * .2); o[1] = 168 * g * (.9 + d * .2); o[2] = 112 * g; } else o[0] = o[1] = o[2] = wv ? 180 : 90; }, 2, { seed: 21 });
    return pbr('EV_WovenMat', { color: c, height: h, k: 1.5, roughBase: .85, roughAmp: .1, uv: 1 }); },
};
export const FM = new Proxy({}, { get: (_, k) => T[k] || (R[k] ? (T[k] = R[k]()) : undefined) });

function fanTex(dead) {
  const S = 1024, K = 14, span = 250 * DEG, nz = makeNoise(dead ? 9 : 8);
  const { c, h } = cardTex(S, S, (x, y) => { const cx = S / 2, cy = S / 2, Rr = S * .48, P = (r, a) => [cx + r * Math.sin(a), cy - r * Math.cos(a)];
    for (let k = 0; k < K; k++) { const a0 = -span / 2 + span * k / K, a1 = a0 + span / K, am = (a0 + a1) / 2, split = Rr * rr(.62, .74), tip = Rr * rr(.9, 1.0);
      for (const half of [0, 1]) { const ea = half ? a1 : a0; x.beginPath(); x.moveTo(cx, cy); x.lineTo(...P(split, ea)); x.lineTo(...P(tip, am + (half ? .012 : -.012))); x.lineTo(...P(tip * .97, am)); x.closePath();
        const base = dead ? [rr(110, 140), rr(80, 98), rr(48, 60)] : [rr(64, 82), rr(98, 116), rr(70, 86)], sh = half ? .82 : 1.06;
        const g = x.createRadialGradient(cx, cy, Rr * .1, cx, cy, Rr); g.addColorStop(0, rgbs(base, sh)); g.addColorStop(.68, rgbs(base, sh * .95)); g.addColorStop(1, dead ? rgbs([96, 70, 44], sh) : rgbs([150, 134, 78], sh)); x.fillStyle = g; x.fill();
        y.beginPath(); y.moveTo(cx, cy); y.lineTo(...P(split, ea)); y.lineTo(...P(tip, am)); y.closePath(); y.fillStyle = half ? '#777' : '#aaa'; y.fill(); }
      x.strokeStyle = dead ? 'rgba(60,40,20,.5)' : 'rgba(220,230,190,.35)'; x.lineWidth = 3; x.beginPath(); x.moveTo(cx, cy); x.lineTo(...P(tip * .96, am)); x.stroke(); y.strokeStyle = '#fff'; y.lineWidth = 4; y.beginPath(); y.moveTo(cx, cy); y.lineTo(...P(tip * .96, am)); y.stroke();
      if (dead || rnd() < .35) { x.globalCompositeOperation = 'destination-out'; for (let t = 0; t < (dead ? 4 : 1); t++) { const r = rr(.75, .98) * Rr, a = am + rr(-.03, .03); x.beginPath(); x.arc(...P(r, a), rr(6, 18), 0, TAU); x.fill(); } x.globalCompositeOperation = 'source-over'; }
    }
    x.strokeStyle = dead ? '#5a4028' : '#5e7240'; x.lineWidth = 16; x.beginPath(); x.moveTo(cx, cy + 6); x.lineTo(cx, cy - Rr * .35); x.stroke();
    x.globalCompositeOperation = 'source-atop'; specks(x, S, S, dead ? 600 : 250, dead ? ['#3d2a18', '#a08058'] : ['#40502c', '#a6a070'], 1, 3, .1, .35); x.globalCompositeOperation = 'source-over';
  });
  return pbr(dead ? 'EV_PalmFanDead' : 'EV_PalmFan', { color: c, height: h, k: 2, roughBase: .6, roughAmp: .2, alpha: true, rep: false });
}
function c0(x) { const c = cv(x.canvas.width, x.canvas.height); c.getContext('2d').drawImage(x.canvas, 0, 0); return c; }
const rgbs = (b, s) => `rgb(${clamp(b[0] * s, 0, 255) | 0},${clamp(b[1] * s, 0, 255) | 0},${clamp(b[2] * s, 0, 255) | 0})`;
function bananaTex(dead) { // half blade: u along leaf (0 base → 1 tip), v midrib (0) → edge (1)
  const W = 1024, H = 256;
  const { c, h } = cardTex(W, H, (x, y) => {
    const base = dead ? [134, 104, 62] : [78, 120, 46];
    x.fillStyle = rgbs(base, 1); x.fillRect(0, 0, W, H); y.fillStyle = '#909090'; y.fillRect(0, 0, W, H);
    for (let i = 0; i < 260; i++) { const px = i / 260 * W * 1.1; x.strokeStyle = dead ? 'rgba(80,58,30,.35)' : 'rgba(170,200,110,.22)'; x.lineWidth = 2; x.beginPath(); x.moveTo(px, H); x.lineTo(px + H * .45, 0); x.stroke(); y.strokeStyle = 'rgba(220,220,220,.6)'; y.lineWidth = 2; y.beginPath(); y.moveTo(px, H); y.lineTo(px + H * .45, 0); y.stroke(); }
    blotch(x, W, H, 16, dead ? [90, 66, 40] : [120, 104, 52], 20, 80, .35);
    x.fillStyle = dead ? '#5a4024' : '#6f6a34'; x.fillRect(0, 0, W, 6);
    const g = x.createLinearGradient(0, 0, 0, 0); x.fillStyle = dead ? 'rgba(70,48,24,.5)' : 'rgba(150,120,60,.55)'; x.fillRect(0, 0, W, 0);
    for (let i = 0; i < W; i += 2) { const dry = dead ? 1 : sstep(.85, 1, i / W); if (dry > 0) { x.fillStyle = `rgba(140,104,58,${dry * .8})`; x.fillRect(i, 0, 2, H); } }
    for (let i = 0; i < W; i++) { const edgeDry = .05 + .04 * Math.sin(i * .05); x.fillStyle = 'rgba(150,120,64,.8)'; x.fillRect(i, H * (1 - edgeDry), 1, H * edgeDry); }
    x.globalCompositeOperation = 'destination-out'; const tears = dead ? 26 : 14;
    for (let t = 0; t < tears; t++) { const px = rr(.1, .95) * W, depth = rr(.35, .9) * H, w = rr(2, 7); x.beginPath(); x.moveTo(px - w, H); x.lineTo(px + depth * .45, H - depth); x.lineTo(px + w + depth * .45, H - depth + 2); x.lineTo(px + w * 2, H); x.closePath(); x.fill(); }
    x.beginPath(); x.moveTo(W * .985, 0); x.lineTo(W, 0); x.lineTo(W, H); x.lineTo(W * .9, H); x.closePath(); x.fill();
    x.globalCompositeOperation = 'source-over';
  });
  return pbr(dead ? 'EV_BananaLeafDead' : 'EV_BananaLeaf', { color: c, height: h, k: 1.5, roughBase: .5, roughAmp: .2, alpha: true, rep: false });
}
function clusterTex(name, S, o) {
  const { c, h } = cardTex(S, S, (x, y, W, H) => {
    const tips = [];
    for (let t = 0; t < o.twigs; t++) { const ex = rr(.12, .88) * W, ey = rr(.08, .6) * H; tips.push([ex, ey]); x.strokeStyle = '#4a3a2a'; x.lineWidth = S / 160; x.beginPath(); x.moveTo(W / 2 + rr(-.05, .05) * W, H * .98); x.quadraticCurveTo(lerp(W / 2, ex, .3), lerp(H, ey, .6), ex, ey); x.stroke(); y.strokeStyle = '#777'; y.lineWidth = S / 160; y.beginPath(); y.moveTo(W / 2, H * .98); y.quadraticCurveTo(lerp(W / 2, ex, .3), lerp(H, ey, .6), ex, ey); y.stroke(); }
    for (let i = 0; i < o.n; i++) { const [tx, ty] = pick(tips), t = rr(.25, 1.15), px = lerp(W / 2, tx, t) + rr(-.12, .12) * W, py = lerp(H * .95, ty, t) + rr(-.1, .1) * H; if (px < 8 || px > W - 8 || py < 8 || py > H - 8) continue;
      const L = rr(o.L[0], o.L[1]) * S / 512, a = rr(0, TAU), col = hsl(rr(o.h[0], o.h[1]), rr(o.s[0], o.s[1]), rr(o.l[0], o.l[1]) + (py < H * .4 ? 6 : 0));
      if (o.pinn) { for (let k = -2; k <= 2; k++) leaf(x, y, px + k * L * .32 * Math.cos(a), py + k * L * .32 * Math.sin(a), L * .55, L * .22, a + Math.PI / 2 + rr(-.2, .2), col, rr(120, 220) | 0, false); }
      else leaf(x, y, px, py, L, L * .38, a, col, rr(120, 220) | 0, true); }
    if (o.bracts) for (let i = 0; i < o.bracts; i++) { const [tx, ty] = pick(tips), t = rr(.4, 1.1), px = lerp(W / 2, tx, t) + rr(-.12, .12) * W, py = lerp(H * .9, ty, t) + rr(-.1, .1) * H; if (px < 8 || px > W - 8 || py < 8 || py > H - 8) continue;
      for (let k = 0; k < 3; k++) { const a = k / 3 * TAU + rr(0, 1); leafPath(x, px, py, 14, 9, a, .5); x.fillStyle = hsl(rr(318, 334), rr(62, 80), rr(44, 60)); x.fill(); leafPath(y, px, py, 14, 9, a, .5); y.fillStyle = '#ddd'; y.fill(); } }
  });
  return pbr(name, { color: c, height: h, k: 2, roughBase: .6, roughAmp: .2, alpha: true, rep: false });
}
function bladeTex(name, base, tip) { const c = field(128, 512, (u, v, o) => { const t = v; for (let i = 0; i < 3; i++) o[i] = lerp(tip[i], base[i], t) * (.9 + .1 * Math.sin(u * TAU * 3)); }); const h = field(128, 512, (u, v, o) => { o[0] = o[1] = o[2] = 128 + Math.cos((u - .5) * Math.PI) * 60; });
  return pbr(name, { color: c, height: h, k: 1, roughBase: .75, roughAmp: .1, side: DS, rep: false }); }

/* ================= geometry helpers specific to plants ================= */
const basisQ = (xv, yv, zv) => new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().makeBasis(xv, yv, zv));
/** Place geometry so local +Y follows `dir` and local +Z faces toward `face` (projected). */
function placeAlong(g, geo, mat, pos, dir, face = YUP, roll = 0) { const y = v3(dir).normalize(); let z = v3(face).sub(y.clone().multiplyScalar(v3(face).dot(y))); if (z.lengthSq() < 1e-6) z = new V3(1, 0, 0).sub(y.clone().multiplyScalar(y.x)); z.normalize(); z.applyAxisAngle(y, roll); const x = new V3().crossVectors(y, z);
  const m = new THREE.Mesh(geo, mat); m.position.copy(v3(pos)); m.quaternion.copy(basisQ(x, y, z)); g.add(m); return m; }
/** Card facing a normal; centred. */
function faceCard(g, mat, w, h, pos, normal, roll = 0, pivotBottom = false) { const geo = pivotBottom ? cardG(w, h) : new THREE.PlaneGeometry(w, h); const z = v3(normal).normalize(); let up = Math.abs(z.y) > .95 ? new V3(1, 0, 0) : YUP.clone(); const x = new V3().crossVectors(up, z).normalize(); const y = new V3().crossVectors(z, x);
  const m = new THREE.Mesh(geo, mat); m.position.copy(v3(pos)); m.quaternion.copy(basisQ(x, y, z)); m.rotateZ(roll); g.add(m); return m; }
/** Pleated palmate fan leaf (Borassus): centre at origin, extends toward +Y, face +Z. 6K tris. */
function fanLeafG(R, K = 14, span = 250 * DEG, pleat = .1, droop = .3) {
  const pos = [], uv = [], C = [0, 0, 0], ring = (r, a, z) => [r * Math.sin(a), r * Math.cos(a), z], M = [], Rr = [];
  for (let j = 0; j <= 2 * K; j++) { const a = -span / 2 + span * j / (2 * K), ridge = j % 2 ? 1 : -1, rimR = R * (j % 2 ? rr(.92, 1) : .7);
    const dz = r => -droop * R * Math.pow(r / R, 2) * (1 - .4 * Math.cos(a));
    M.push(ring(R * .5, a, ridge * pleat * R * .5 + dz(R * .5))); Rr.push(ring(rimR, a, ridge * pleat * R + dz(rimR))); }
  const U = p => [.5 + p[0] * .48 / R, .5 + p[1] * .48 / R];
  for (let j = 0; j < 2 * K; j++) { const tri = (a, b, c) => { pos.push(...a, ...b, ...c); uv.push(...U(a), ...U(b), ...U(c)); };
    tri(C, M[j + 1], M[j]); tri(M[j], M[j + 1], Rr[j + 1]); tri(M[j], Rr[j + 1], Rr[j]); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.computeVertexNormals(); return g;
}
/** Banana leaf: midrib along a curve; two half-blade strips folded down; uv u along, v midrib→edge. */
function bananaLeafG(pts, width, fold = .35, tearSide = 1) {
  const n = pts.length, pos = [], uv = [], idx = [], P = pts.map(v3);
  for (let i = 0; i < n; i++) { const t = i / (n - 1), T2 = (i < n - 1 ? P[i + 1].clone().sub(P[i]) : P[i].clone().sub(P[i - 1])).normalize(); const side = new V3().crossVectors(T2, YUP); if (side.lengthSq() < 1e-4) side.set(1, 0, 0); side.normalize(); const dn = new V3().crossVectors(side, T2).normalize().negate();
    const w = width * Math.pow(Math.sin(Math.PI * clamp(t * .98 + .02, 0, 1)), .55);
    for (const s of [-1, 1]) { const e = P[i].clone().addScaledVector(side, s * w * Math.cos(fold)).addScaledVector(dn, w * Math.sin(fold)); pos.push(P[i].x, P[i].y, P[i].z, e.x, e.y, e.z); uv.push(t, 0, t, 1); } }
  for (let i = 0; i < n - 1; i++) for (let s = 0; s < 2; s++) { const a = i * 4 + s * 2, b = a + 4; s ? idx.push(a, b, a + 1, a + 1, b, b + 1) : idx.push(a, a + 1, b, a + 1, b + 1, b); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx); g.computeVertexNormals(); return g;
}
const tube = (g, mat, ctrl, n, r0, r1, seg, o = {}) => { const pts = ctrl.length >= n ? ctrl : curve(ctrl, n); const rad = pts.map((_, i) => lerp(r0, r1, Math.pow(i / (pts.length - 1), o.taper || 1))); add(g, tubeG(pts, rad, seg, o), mat); return pts; };
const sph = (r, d = 0) => new THREE.IcosahedronGeometry(r, d);

/* ================= builders ================= */
export function sugarPalm(v, seed, H, leanDeg, o = {}) {
  return makeAsset(`EV_SugarPalm_${v}`, seed, part => {
    const tr = part('Trunk'), lv = part('Leaves'), dd = part('DeadFronds'), bt = part('LeafBases');
    const az = rr(0, TAU), lean = leanDeg * DEG, topY = H - 3.6, n = 24, pts = [], rad = [];
    for (let i = 0; i < n; i++) { const t = i / (n - 1), y = t * topY, off = Math.tan(lean) * y * (.55 + .45 * t); pts.push(new V3(Math.cos(az) * off, y - .15, Math.sin(az) * off)); rad.push((1.05 - .22 * t + .55 * Math.exp(-t * 22)) * (1 + (i % 2 ? .035 : 0))); }
    add(tr, tubeG(pts, rad, 12, { tile: 2, uRep: 3 }), FM.palmBark);
    for (let k = 0; k < 6; k++) { const a = k / 6 * TAU + rr(-.3, .3); tube(tr, FM.palmBark, [[Math.cos(a) * 1.2, .5, Math.sin(a) * 1.2], [Math.cos(a) * 1.75, .05, Math.sin(a) * 1.75], [Math.cos(a) * 2.0, -.25, Math.sin(a) * 2.0]], 3, .32, .12, 5, { tile: 2, uRep: 1 }); }
    const top = pts[n - 1].clone(), crown = top.clone().add(new V3(0, .9, 0));
    add(tr, cylG(.86, .9, 1.4, 12), FM.palmBoot, [top.x, top.y + .5, top.z]);
    for (let k = 0; k < 16; k++) { const a = k / 16 * TAU + rr(-.2, .2), y = top.y + rr(-.4, 1.2); const b = add(bt, boxG(.5, 1.4, .18), FM.palmBoot, [top.x + Math.cos(a) * .85, y, top.z + Math.sin(a) * .85], [0, -a + Math.PI / 2, 0]); b.rotateX(rr(.15, .45)); }
    const nLive = o.leaves || 26;
    for (let k = 0; k < nLive; k++) { const a = (k / nLive) * TAU * 3.2 + rr(-.25, .25), el = lerp(-14, 74, Math.pow(rnd(), .9)) * DEG, L = rr(3.2, 3.8), dir = new V3(Math.cos(a) * Math.cos(el), Math.sin(el), Math.sin(a) * Math.cos(el));
      const tipP = crown.clone().addScaledVector(dir, L).add(new V3(0, -.12 * L * Math.cos(el), 0)); tube(lv, FM.palmBoot, [crown, crown.clone().addScaledVector(dir, L * .5), tipP], 3, .09, .06, 4, { uRep: 1 });
      placeAlong(lv, fanLeafG(rr(2.6, 3.0), 14, rr(230, 260) * DEG, rr(.08, .12), rr(.15, .35)), FM.palmFan, tipP, dir.clone().add(new V3(0, .15, 0)), YUP, rr(-1.1, 1.1)); }
    for (let k = 0; k < (o.dead || 4); k++) { const a = rr(0, TAU), el = rr(-82, -55) * DEG, L = rr(2.0, 2.6), dir = new V3(Math.cos(a) * Math.cos(el), Math.sin(el), Math.sin(a) * Math.cos(el)), base = crown.clone().add(new V3(0, -.6, 0));
      const tipP = base.clone().addScaledVector(dir, L); tube(dd, FM.palmBoot, [base, tipP], 2, .08, .06, 4, { uRep: 1 });
      placeAlong(dd, fanLeafG(rr(2.0, 2.4), 14, rr(150, 190) * DEG, .16, .1), FM.palmFanDead, tipP, dir, new V3(Math.cos(a), 0, Math.sin(a)), rr(-.4, .4)); }
    if (o.fruit) { const fr = part('Fruit'); for (let c = 0; c < 2; c++) { const a = az + c * 2.2 + .6, d = new V3(Math.cos(a), -.55, Math.sin(a)).normalize(), b0 = crown.clone().add(new V3(0, -.3, 0)), b1 = b0.clone().addScaledVector(d, 1.5);
      tube(fr, FM.palmBoot, [b0, b0.clone().addScaledVector(d, .8).add(new V3(0, .1, 0)), b1], 4, .07, .05, 4, { uRep: 1 });
      for (let i = 0; i < 14; i++) add(fr, sph(rr(.25, .32), 0), FM.palmFruit, b1.clone().add(new V3(rr(-.45, .45), rr(-.5, .25), rr(-.45, .45))).toArray()); } }
  });
}
export function rainTree(v, seed, W, H) {
  return makeAsset(`EV_RainTree_${v}`, seed, part => {
    const wd = part('Wood'), lf = part('Canopy'), ep = part('Epiphytes'), Rc = W / 2 - 3.7;
    tube(wd, FM.rainBark, [[0, -.2, 0], [.1, 1.5, 0], [0, 3.2, .1], [0, 4.4, 0]], 6, 2.1, 1.55, 14, { tile: 2, uRep: 5, wob: (i, s, a) => .08 * Math.sin(a * 5 + i) });
    for (let k = 0; k < 7; k++) { const a = k / 7 * TAU + rr(-.2, .2); tube(wd, FM.rainBark, [[Math.cos(a) * 1.3, .9, Math.sin(a) * 1.3], [Math.cos(a) * 2.3, .1, Math.sin(a) * 2.3], [Math.cos(a) * 2.9, -.2, Math.sin(a) * 2.9]], 3, .6, .2, 6, { tile: 2, uRep: 2 }); }
    const canopyY = r => H - 1.7 - (H * .2) * Math.pow(r / Rc, 2);
    const nL = 6, tips = [];
    for (let k = 0; k < nL; k++) { const a = k / nL * TAU + rr(-.25, .25), el = rr(26, 42) * DEG, len = Rc * rr(.62, .78), d = new V3(Math.cos(a), 0, Math.sin(a)), p0 = new V3(Math.cos(a) * .5, 4.0, Math.sin(a) * .5);
      const p1 = p0.clone().addScaledVector(d, len * .35).add(new V3(0, len * .35 * Math.tan(el), 0)), p3 = d.clone().multiplyScalar(len).setY(canopyY(len) - 2.4), p2 = p1.clone().lerp(p3, .55).add(new V3(0, .9, 0));
      const pts = tube(wd, FM.rainBark, [p0, p1, p2, p3], 12, 1.0, .32, 9, { tile: 2, uRep: 3 });
      for (const t of [5, 8, 11]) { const s = pts[t], ba = a + rr(-.9, .9), bd = new V3(Math.cos(ba), 0, Math.sin(ba)), r = clamp(s.clone().setY(0).length() + Rc * rr(.18, .32), 0, Rc * .95), e = bd.clone().multiplyScalar(r).add(new V3(s.x, 0, s.z).multiplyScalar(.25)).setY(canopyY(r) - 1.2);
        tube(wd, FM.rainBark, [s, s.clone().lerp(e, .5).add(new V3(0, .8, 0)), e], 6, t === 5 ? .45 : .32, .1, 6, { tile: 2, uRep: 2 }); tips.push(e); }
      if (k % 2 === 0) { const s = pts[4]; for (let f = 0; f < 5; f++) faceCard(ep, FM.epiphyte, 1.2, 1.2, s.clone().add(new V3(0, .7, 0)), new V3(Math.cos(f / 5 * TAU), .9, Math.sin(f / 5 * TAU)), rr(0, TAU), true); } }
    for (let i = 0; i < 26; i++) { const r = Rc * Math.sqrt(rnd()) * .82, a = rnd() * TAU; add(lf, blobG(rr(3, 4.2), 1, .3, 1.3, i * 3.1, [1, .42, 1]), FM.foliageCore, [Math.cos(a) * r, canopyY(r) - .5, Math.sin(a) * r]); }
    const nC = Math.round(150 * (Rc / 18) ** 2);
    for (let i = 0; i < nC; i++) { const r = Rc * Math.sqrt(rnd()), a = rnd() * TAU, s = rr(5.2, 7), y = canopyY(r) + rr(-.7, .6), p = new V3(Math.cos(a) * r, y, Math.sin(a) * r), edge = r / Rc;
      faceCard(lf, FM.rainLeaf, s, s, p, new V3(rr(-.3, .3) + Math.cos(a) * edge * .4, 1, rr(-.3, .3) + Math.sin(a) * edge * .4), rr(0, TAU));
      if (edge > .55 || rnd() < .35) { const ya = rr(0, Math.PI); for (const q of [0, Math.PI / 2]) faceCard(lf, FM.rainLeaf, s, s * .62, p.clone().add(new V3(0, -s * .2, 0)), new V3(Math.cos(ya + q), 0, Math.sin(ya + q)), 0); } }
  });
}
export function umbrellaPine(v, seed, H) {
  return makeAsset(`EV_UmbrellaPine_${v}`, seed, part => {
    const wd = part('Trunk'), nd = part('Needles'), a0 = rr(0, TAU);
    const trunk = tube(wd, FM.pineBark, [[0, -.2, 0], [.25 * Math.cos(a0), H * .3, .25 * Math.sin(a0)], [-.2 * Math.cos(a0), H * .62, -.15 * Math.sin(a0)], [.1, H - .9, .05]], 16, .62, .14, 10, { tile: 2, uRep: 2, taper: .8 });
    for (let k = 0; k < 5; k++) { const p = trunk[3 + k * 2], a = rr(0, TAU); tube(wd, FM.pineBark, [p, p.clone().add(new V3(Math.cos(a) * .7, .25, Math.sin(a) * .7))], 2, .08, .03, 4, { uRep: 1 }); }
    for (let y = H * .64; y < H - .6; y += 1.0) { const tt = sstep(H * .62, H * .9, y), nb = 4 + (rnd() < .5 ? 1 : 0), Lb = lerp(1.6, 4.3, tt), ti = clamp(Math.round((y / (H - .9)) * 15), 0, 15), base = trunk[ti];
      for (let b = 0; b < nb; b++) { const a = b / nb * TAU + rr(-.4, .4) + y, d = new V3(Math.cos(a), 0, Math.sin(a)), e = base.clone().addScaledVector(d, Lb).add(new V3(0, lerp(.9, .2, tt) + rr(-.2, .3), 0)), m = base.clone().lerp(e, .5).add(new V3(0, -.15, 0));
        tube(wd, FM.pineBark, [base, m, e], 4, .12, .04, 5, { uRep: 1 });
        for (let c = 0; c < 3; c++) { const t = .45 + c * .28, p = base.clone().lerp(e, t).add(new V3(0, .25, 0)), s = rr(2.0, 2.6); faceCard(nd, FM.pineNeedle, s, s, p, new V3(rr(-.2, .2), 1, rr(-.2, .2)), rr(0, TAU)); faceCard(nd, FM.pineNeedle, s, s * .7, p.clone().add(new V3(0, -.45, 0)), d.clone().applyAxisAngle(YUP, Math.PI / 2 + rr(-.4, .4)), 0, true); } } }
    for (let c = 0; c < 6; c++) { const a = rr(0, TAU), r = rr(0, 2.6), p = new V3(Math.cos(a) * r, H - .55, Math.sin(a) * r); faceCard(nd, FM.pineNeedle, 2.6, 2.6, p, new V3(rr(-.15, .15), 1, rr(-.15, .15)), rr(0, TAU)); }
  });
}
export function frangipani(v, seed, scale = 1) {
  return makeAsset(`EV_Frangipani_${v}`, seed, part => {
    const wd = part('Branches'), lf = part('Leaves'), fl = part('Flowers'), S = scale;
    tube(wd, FM.frangiBark, [[0, -.15, 0], [.05 * S, 1.4 * S, 0], [0, 2.8 * S, .05 * S]], 5, .36 * S, .3 * S, 10, { uRep: 2 });
    const grow = (p, d, L, r, lvl) => { const e = p.clone().addScaledVector(d, L); const m = p.clone().lerp(e, .5).add(new V3(0, L * .12, 0)); tube(wd, FM.frangiBark, [p, m, e], 4, r, r * .82, 8, { uRep: 1, capEnd: lvl === 0 });
      if (lvl === 0) { const tip = e.clone(); for (let i = 0; i < 8; i++) { const a = i / 8 * TAU + rr(-.2, .2), el = rr(25, 55) * DEG, ld = new V3(Math.cos(a) * Math.cos(el), Math.sin(el), Math.sin(a) * Math.cos(el)); placeAlong(lf, cardG(.6 * S, rr(1.5, 1.9) * S, -.15 * S, 2), FM.frangiLeaf, tip, ld, YUP, 0); }
        for (let i = 0; i < 2; i++) faceCard(fl, FM.frangiFlower, .7 * S, .7 * S, tip.clone().add(new V3(rr(-.12, .12), .32 * S + i * .1, rr(-.12, .12))), new V3(rr(-.3, .3), 1, rr(-.3, .3)), rr(0, TAU)); return; }
      const nk = lvl === 3 ? 3 : 2; for (let k = 0; k < nk; k++) { const a = lvl === 3 ? k / 3 * TAU + rr(-.3, .3) : Math.atan2(d.z, d.x) + (k - .5) * rr(.9, 1.3), el = rr(40, 62) * DEG; grow(e, new V3(Math.cos(a) * Math.cos(el), Math.sin(el), Math.sin(a) * Math.cos(el)), lvl === 3 ? 1.95 * S : L * .8, r * .78, lvl - 1); } };
    grow(new V3(0, 2.8 * S, .05 * S), new V3(0, 1, 0), .5 * S, .3 * S, 3);
  });
}
export function banana(v, seed, stems, H) {
  return makeAsset(`EV_Banana_${v}`, seed, part => {
    const st = part('Stems'), lf = part('Leaves'), dl = part('DeadLeaves'), bn = part('Bunch');
    const sp = []; for (let i = 0; i < stems; i++) { const a = i / stems * TAU + rr(-.4, .4), r = i === 0 ? 0 : rr(.45, .7), h = i === 0 ? H - 2.6 : rr(.45, .85) * (H - 2.6); sp.push({ p: new V3(Math.cos(a) * r, 0, Math.sin(a) * r), h, a }); }
    sp.forEach((s, i) => { const lean = new V3(Math.cos(s.a), 0, Math.sin(s.a)).multiplyScalar(i ? .25 : .05), top = s.p.clone().add(new V3(0, s.h, 0)).add(lean.clone().multiplyScalar(s.h * .2));
      tube(st, FM.bananaStem, [s.p.clone().add(new V3(0, -.15, 0)), s.p.clone().lerp(top, .5), top], 5, i ? .34 : .44, i ? .22 : .3, 9, { uRep: 2, tile: 2 });
      const nl = i ? 5 : 7, lsc = i ? .85 : 1;
      add(lf, cylG(.03, .09, 2.2 * lsc, 6), FM.bananaStem, [top.x, top.y + 1.1 * lsc, top.z]);
      for (let k = 0; k < nl; k++) { const a = k / nl * TAU + rr(-.3, .3), el = rr(26, 56) * DEG, L = rr(4.3, 4.9) * lsc, d = new V3(Math.cos(a), 0, Math.sin(a)), pts = [];
        for (let j = 0; j < 9; j++) { const t = j / 8, s2 = t * L; pts.push(top.clone().addScaledVector(d, s2 * Math.cos(el)).add(new V3(0, s2 * Math.sin(el) - .75 * L * t * t, 0))); }
        tube(lf, FM.bananaStem, [top, pts[1]], 2, .06, .05, 4, { uRep: 1 }); add(lf, bananaLeafG(pts.slice(1), rr(.62, .78) * lsc, rr(.2, .45)), FM.bananaLeaf); }
      for (let k = 0; k < (i ? 1 : 2); k++) { const a = rr(0, TAU), d = new V3(Math.cos(a), 0, Math.sin(a)), pts = []; for (let j = 0; j < 7; j++) { const t = j / 6; pts.push(top.clone().add(new V3(0, -.2, 0)).addScaledVector(d, .3 + t * .35).add(new V3(0, -t * 2.6, 0))); }
        add(dl, bananaLeafG(pts, .45, 1.1), FM.bananaDead); }
      if (i === 0) { const d = new V3(Math.cos(s.a + 1.2), 0, Math.sin(s.a + 1.2)), p0 = top.clone(), p1 = top.clone().addScaledVector(d, .9).add(new V3(0, .3, 0)), p2 = top.clone().addScaledVector(d, 1.3).add(new V3(0, -1.0, 0)), p3 = top.clone().addScaledVector(d, 1.35).add(new V3(0, -2.6, 0));
        const ped = tube(bn, FM.bananaStem, [p0, p1, p2, p3], 10, .08, .06, 5, { uRep: 1 });
        for (let hh = 0; hh < 5; hh++) { const c = ped[4 + hh]; for (let f = 0; f < 9; f++) { const fa = (f / 9) * Math.PI * 1.4 - .7 + Math.atan2(d.z, d.x) + Math.PI, fd = new V3(Math.cos(fa), 0, Math.sin(fa)), b0 = c.clone().addScaledVector(fd, .1), b1 = b0.clone().addScaledVector(fd, .22).add(new V3(0, .12, 0)), b2 = b1.clone().addScaledVector(fd, .12).add(new V3(0, .28, 0));
          add(bn, tubeG([b0, b1, b2], [.05, .065, .04], 5, { capEnd: true, uRep: 1 }), FM.bananaFruit); } }
        add(bn, cylG(.02, .17, .6, 8), FM.bananaBud, [p3.x, p3.y - .3, p3.z], [Math.PI, 0, 0]); }
    });
  });
}
export function bamboo(v, seed) {
  return makeAsset(`EV_Bamboo_${v}`, seed, part => {
    const cu = part('Culms'), lf = part('Leaves');
    for (let i = 0; i < 30; i++) { const a = rnd() * TAU, r = Math.sqrt(rnd()) * .9, base = new V3(Math.cos(a) * r, -.15, Math.sin(a) * r), h = lerp(12.5, 19.6, 1 - r / 1.0 * rnd()), out = new V3(Math.cos(a + rr(-.4, .4)), 0, Math.sin(a + rr(-.4, .4))), off = rr(1.4, 3.0) * h / 19.6, pts = [], rad = [], n = 15;
      for (let j = 0; j < n; j++) { const t = j / (n - 1); pts.push(base.clone().add(new V3(0, h * t * (1 - .06 * t * t), 0)).addScaledVector(out, off * Math.pow(t, 1.9))); rad.push(lerp(.17, .05, t) * (j % 2 ? 1.06 : 1)); }
      add(cu, tubeG(pts, rad, 6, { tile: 2, uRep: 1 }), FM.culm);
      for (let j = 7; j < n; j += 1) { if (rnd() < .3) continue; const p = pts[j], sa = rr(0, TAU), sd = new V3(Math.cos(sa), -.35, Math.sin(sa)).add(out.clone().multiplyScalar(.6)); faceCard(lf, FM.bambooLeaf, rr(1.6, 2.2), rr(1.6, 2.2), p.clone().addScaledVector(sd, .3), new V3(-sd.z, rr(-.3, .3), sd.x), rr(-.6, .6)); } }
  });
}
export function bush(v, seed, kind) {
  return makeAsset(`EV_Bush_${v}`, seed, part => {
    const core = part('Core'), lf = part('Leaves'), wd = part('Stems');
    const conf = kind === 'round' ? { blobs: [[0, 1.7, 0, 1.9, [1, .85, 1]], [.6, 1.2, .5, 1.3, [1, .8, 1]], [-.7, 1.3, -.3, 1.3, [1, .8, 1]]], mat: FM.bushLeaf, cards: 220, s: [1.2, 1.7] }
      : kind === 'spread' ? { blobs: [[0, 1.35, 0, 1.6, [1.5, .8, 1.25]], [1.3, 1.15, .5, 1.0, [1.2, .78, 1]], [-1.3, 1.1, -.3, 1.0, [1.2, .78, 1]]], mat: FM.bushLeaf2, cards: 240, s: [1.1, 1.6] }
      : { blobs: [[0, 1.9, 0, 1.5, [1, .9, 1]], [.8, 1.4, .3, 1.0, [1, .9, 1]]], mat: FM.bougain, cards: 200, s: [1.2, 1.8] };
    for (let i = 0; i < 6; i++) { const a = rr(0, TAU); tube(wd, FM.frangiBark, [[rr(-.2, .2), -.1, rr(-.2, .2)], [Math.cos(a) * .6, .8, Math.sin(a) * .6], [Math.cos(a) * 1.0, 1.5, Math.sin(a) * 1.0]], 4, .08, .03, 5, { uRep: 1 }); }
    conf.blobs.forEach(([x, y, z, r, sq], i) => add(core, blobG(r * .82, 4, .3, 1.6, i * 2.3 + seed, sq), FM.foliageCore, [x, y, z]));
    for (let i = 0; i < conf.cards; i++) { const [x, y, z, r, sq] = pick(conf.blobs), d = new V3(rr(-1, 1), rr(-.2, 1), rr(-1, 1)).normalize(), p = new V3(x + d.x * r * sq[0] * rr(.75, 1.02), Math.max(.35, y + d.y * r * sq[1] * rr(.75, 1.02)), z + d.z * r * sq[2] * rr(.75, 1.02)); faceCard(lf, conf.mat, rr(...conf.s), rr(...conf.s), p, d, rr(0, TAU)); }
    if (kind === 'bougain') for (let i = 0; i < 7; i++) { const a = i / 7 * TAU + rr(-.3, .3), pts = tube(wd, FM.frangiBark, [[0, .1, 0], [Math.cos(a) * 1.3, 3.0, Math.sin(a) * 1.3], [Math.cos(a) * 2.4, rr(3.2, 3.8), Math.sin(a) * 2.4], [Math.cos(a) * 2.75, rr(2.3, 3.0), Math.sin(a) * 2.75]], 8, .07, .03, 5, { uRep: 1 });
      for (let j = 3; j < 8; j++) faceCard(lf, FM.bougain, rr(1.0, 1.4), rr(1.0, 1.4), pts[j], new V3(Math.cos(a), rr(-.2, .8), Math.sin(a)), rr(0, TAU)); }
  });
}
export function rock(v, seed, kind, size) {
  return makeAsset(`EV_Rock_${v}`, seed, part => {
    const g = part('Rock'), m = kind === 'laterite' ? FM.laterite : FM.granite;
    const lump = (geo, s, p, sink = .3) => { const pp = geo.attributes.position; let minY = 1e9; for (let i = 0; i < pp.count; i++) { pp.setXYZ(i, pp.getX(i) * s[0], pp.getY(i) * s[1], pp.getZ(i) * s[2]); minY = Math.min(minY, pp.getY(i)); }
      for (let i = 0; i < pp.count; i++) { const y = pp.getY(i) - minY - sink; pp.setY(i, Math.max(y, -sink * .9)); } geo.computeVertexNormals(); add(g, geo, m, p); };
    const [w, h, d] = size;
    const amp = kind === 'laterite' ? .42 : .22, k = 1 / (2 * (1 + amp * .7));
    lump(blobG(1, 8, amp, kind === 'laterite' ? 2.0 : 1.2, seed), [w * k * .92, h * k * 1.15, d * k * .92], [0, 0, 0]);
    lump(blobG(1, 3, .3, 1.6, seed + 4), [w * .16, h * .3, d * .18], [w * .26, 0, -d * .18], .15);
  });
}
export function strawStack(v, seed, cut) {
  return makeAsset(`EV_StrawStack_${v}`, seed, part => {
    const body = part('Body'), cap = part('Top'), fr = part('Fringe'), pl = part('Pole'), nz = makeNoise(seed);
    const prof = [[0, -.15], [3.05, -.15], [3.35, .6], [3.6, 1.6], [3.62, 2.6], [3.5, 3.3], [3.3, 3.75]], dome = [[3.38, 3.55], [3.05, 4.25], [2.45, 5.0], [1.6, 5.65], [.8, 6.05], [.15, 6.2], [0, 6.22]];
    const disp = (geo, amp, cutX) => { const p = geo.attributes.position, vv = new V3(); for (let i = 0; i < p.count; i++) { vv.fromBufferAttribute(p, i); const r = Math.hypot(vv.x, vv.z); if (r < .01) continue; const k = 1 + amp * (nz.fbm3(vv.x * .6, vv.y * .9, vv.z * .6, 3) - .5) * 2; vv.x *= k; vv.z *= k; if (cutX !== undefined && vv.x > cutX && vv.y < 3.9) vv.x = cutX + (nz.n3(vv.y * 2, vv.z * 2, 1) - .5) * .25; p.setXYZ(i, vv.x, vv.y, vv.z); } geo.computeVertexNormals(); return geo; };
    const cutX = cut ? 1.9 : undefined, tilt = cut ? 3 * DEG : 0;
    const B = disp(revolve(prof, 64), .07, cutX); const D = disp(revolve(dome, 64), .06, cutX);
    const bm = add(body, B, lib.straw); const dm = add(cap, D, lib.strawSun); bm.rotation.z = dm.rotation.z = tilt;
    add(pl, cylG(.07, .1, 2.2, 6), lib.woodRough, [0, cut ? 5.42 : 5.62, 0], [0, 0, tilt]);
    for (let i = 0; i < 44; i++) { const a = i / 44 * TAU + rr(-.05, .05), r = 3.72 + rr(0, .08), y = rr(3.55, 3.85); if (cut && Math.cos(a) * r > cutX - .1) continue; faceCard(fr, lib.strawFringe, rr(1.4, 1.9), rr(1.3, 1.8), new V3(Math.cos(a) * r, y - 1.0, Math.sin(a) * r), new V3(Math.cos(a), .1, Math.sin(a)), rr(-.15, .15)); }
    for (let i = 0; i < 36; i++) { const a = i / 36 * TAU + rr(-.05, .05), r = 3.45 + rr(0, .08); if (cut && Math.cos(a) * r > cutX - .1) continue; faceCard(fr, lib.strawFringe, rr(1.4, 1.9), rr(.8, 1.1), new V3(Math.cos(a) * r, .45, Math.sin(a) * r), new V3(Math.cos(a), -.2, Math.sin(a)), rr(-.2, .2)); }
    const rAt = y => { for (let i = 0; i < dome.length - 1; i++) if (y >= dome[i][1] && y <= dome[i + 1][1]) return lerp(dome[i][0], dome[i + 1][0], (y - dome[i][1]) / (dome[i + 1][1] - dome[i][1])); return 0; };
    for (let i = 0; i < 30; i++) { const a = rnd() * TAU, y = rr(4.0, 5.9), r = rAt(y) + .08; if (cut && Math.cos(a) * r > cutX - .1) continue; faceCard(fr, lib.strawFringe, 1.2, 1.0, new V3(Math.cos(a) * r, y, Math.sin(a) * r), new V3(Math.cos(a), 1.2, Math.sin(a)), rr(-.3, .3)); }
    if (cut) { add(body, blobG(1, 3, .25, 1.5, 9, [1.1, .45, 1.6]), lib.straw, [cutX + .75, .1, 0]); for (let i = 0; i < 16; i++) faceCard(fr, lib.strawFringe, 1.2, .8, new V3(cutX + rr(.3, 1.3), .1, rr(-1.5, 1.5)), new V3(rr(-1, 1), 1, rr(-1, 1)), rr(0, TAU)); }
  });
}
export function fieldHut(v, seed) {
  return makeAsset(`EV_FieldHut_${v}`, seed, part => {
    const fr = part('Frame'), fl = part('Floor'), rf = part('Roof'), fg = part('RoofFringe'), hm = part('Hammock'), pr = part('Props');
    const px = [-3.6, 0, 3.6], pz = [-2.6, 2.6], deck = 2.25, eaveY = 5.25, ridgeY = 8.25, ez = 3.75;
    const pTop = 6.0;
    for (const x of px) for (const z of pz) { add(fr, cylG(.17, .19, pTop + .1, 8), lib.bamboo, [x, (pTop + .1) / 2 - .1, z]); add(fr, cylG(.24, .26, .3, 8), lib.concrete, [x, 0, z]); }
    for (const x of px) { add(fr, alongZ(cylG(.12, .12, 5.5, 8)), lib.bamboo, [x, pTop, 0]); add(fr, cylG(.12, .12, ridgeY - pTop, 8), lib.bamboo, [x, (ridgeY + pTop) / 2, 0]); }
    for (const z of pz) add(fr, alongXg(cylG(.11, .11, 7.6, 8)), lib.bamboo, [0, pTop, z]);
    for (const z of pz) add(fr, alongXg(cylG(.15, .15, 7.9, 8)), lib.bamboo, [0, deck - .14, z]);
    for (const x of px) add(fr, alongZ(cylG(.13, .13, 5.6, 8)), lib.bamboo, [x, deck - .3, 0]);
    for (let i = 0; i < 26; i++) { const x = -3.75 + i * .3; add(fl, boxG(.26, .07, 5.6), lib.bamboo, [x + rr(-.02, .02), deck, 0]); }
    add(fl, boxG(2.6, .02, 1.8), FM.mat, [-1.6, deck + .045, .6]);
    add(fr, alongXg(cylG(.09, .09, 7.2, 6)), lib.bamboo, [0, deck + .85, 2.6]);
    for (const x of [-3.6, 3.6]) add(fr, alongZ(cylG(.09, .09, 5.2, 6)), lib.bamboo, [x, deck + .85, 0]);
    add(fr, alongXg(cylG(.13, .13, 9.4, 8)), lib.bamboo, [0, ridgeY + .05, 0]);
    const slopeL = Math.hypot(ez, ridgeY - eaveY), ang = Math.atan2(ridgeY - eaveY, ez);
    for (const s of [-1, 1]) { const m = add(rf, boxG(9.6, .32, slopeL + .1), lib.thatch, [0, (ridgeY + eaveY) / 2 + .12, s * ez / 2]); m.rotation.x = s * ang;
      for (let i = 0; i < 9; i++) { const x = -4.2 + i * 1.05; beam(fr, lib.bamboo, [x, ridgeY, 0], [x, eaveY + .02, s * (ez - .05)], .1, .1); }
      for (let i = 0; i < 6; i++) { const m2 = add(fg, cardG(1.62, 1.0, 0), lib.thatchFringe, [-4.0 + i * 1.6, eaveY - .82, s * (ez + .02)]); m2.rotation.y = s > 0 ? 0 : Math.PI; m2.rotation.x = s * .15; } }
    add(rf, boxG(9.7, .3, .7), lib.thatch, [0, ridgeY + .3, 0]);
    for (const s of [-1, 1]) { pipe(fr, lib.bamboo, [-1.5 + s * .45, 0, -3.9], [-1.5 + s * .35, deck + .9, -2.65], .07, 6); }
    for (let i = 1; i < 7; i++) { const t = i / 7; add(fr, alongXg(cylG(.05, .05, .82, 6)), lib.bamboo, [-1.5, t * (deck + .9), lerp(-3.9, -2.65, t)]); }
    const hz = 2.2, hpts = [], n = 12; for (let i = 0; i <= n; i++) { const t = i / n; hpts.push(new V3(lerp(-3.4, -.2, t), deck + 2.3 - Math.sin(Math.PI * t) * 1.1, hz)); }
    add(hm, ribbonG(hpts, .55), FM.hammock); for (const e of [hpts[0], hpts[n]]) pipe(hm, lib.rubber, e, [e.x < -2 ? -3.6 : 0, deck + 2.9, 2.6], .02, 4);
    add(pr, revolve([[0, 0], [.32, .03], [.42, .25], [.38, .5], [.2, .66], [.22, .72], [0, .72]], 16), lib.terracotta, [2.6, deck + .03, 1.5]);
    add(pr, revolve([[0, 0], [.22, .01], [.26, .12], [.2, .3], [.12, .34], [0, .34]], 14), lib.ceramic, [2.0, deck + .03, 1.9]);
  });
}
const alongXg = g => g.rotateZ(Math.PI / 2);
function ribbonG(pts, w) { const pos = [], uv = [], idx = []; pts.forEach((p, i) => { pos.push(p.x, p.y, p.z - w / 2, p.x, p.y, p.z + w / 2); uv.push(i / (pts.length - 1) * 3, 0, i / (pts.length - 1) * 3, 1); }); for (let i = 0; i < pts.length - 1; i++) { const a = i * 2; idx.push(a, a + 2, a + 1, a + 1, a + 2, a + 3); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx); g.computeVertexNormals(); return g; }
export function grassClump(v, seed, green) {
  return makeAsset(`EV_GrassClump_${v}`, seed, part => {
    const bl = part('Blades'), cd = part('Cards'), m = green ? FM.grassGreen : FM.grassDry;
    for (let i = 0; i < 250; i++) { const a = rnd() * TAU, r = Math.sqrt(rnd()) * .7, b = new V3(Math.cos(a) * r, -.05, Math.sin(a) * r), h = rr(.55, 1.42), lean = rr(.1, .35) * (r + .3), d = new V3(Math.cos(a + rr(-.6, .6)), 0, Math.sin(a + rr(-.6, .6))), w = rr(.035, .06);
      const pts = [0, .35, .7, 1].map(t => b.clone().add(new V3(0, h * t * (1 - .25 * t * lean), 0)).addScaledVector(d, lean * h * t * t)), side = new V3(-d.z, 0, d.x), pos = [], uv = [];
      pts.forEach((p, j) => { const ww = w * (1 - j / 3.2); pos.push(p.x - side.x * ww, p.y, p.z - side.z * ww, p.x + side.x * ww, p.y, p.z + side.z * ww); uv.push(0, 1 - j / 3, 1, 1 - j / 3); });
      const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex([0, 2, 1, 1, 2, 3, 2, 4, 3, 3, 4, 5, 4, 6, 5, 5, 6, 7]); g.computeVertexNormals(); add(bl, g, m); }
    for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI + rr(-.1, .1); faceCard(cd, FM.grassCard, rr(2.2, 2.6), rr(1.1, 1.42), new V3(rr(-.15, .15), -.05, rr(-.15, .15)), new V3(Math.cos(a), 0, Math.sin(a)), 0, true); }
    if (green) for (let i = 0; i < 18; i++) { const a = rnd() * TAU, r = rnd() * .7; faceCard(cd, FM.seedHead, .14, .55, new V3(Math.cos(a) * r, rr(.75, .9), Math.sin(a) * r), new V3(Math.cos(a + 1.5), 0, Math.sin(a + 1.5)), rr(-.2, .2), true); }
  });
}
