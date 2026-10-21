// Animated mock-ups of the features. Each demo builds a small desktop inside its frame and plays a loop while it is on screen.
// With "reduce motion" on, a demo plays once without waiting and stays on its last state.
const h = (html) => { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstElementChild; };
const css = (el, o) => Object.assign(el.style, o);
const unit = (v) => (typeof v === 'number' ? v + '%' : v);
const box = (r) => ({ left: r[0] + '%', top: r[1] + '%', width: r[2] + '%', height: r[3] + '%' });

// Screen areas as [x, y, width, height] in % of the screen.
const Z0 = [1.6, 2.7, 38, 94.6], Z1 = [41.2, 2.7, 57.2, 56], Z2 = [41.2, 61.4, 57.2, 35.9];
const Z1MID = Z1[0] + Z1[2] / 2;
const PILL_Y = 8.7;

function win(cls, r) {
  const w = h(`<div class="win ${cls}"><div class="bar"><b></b><b></b><b></b><span></span></div><div class="blk"></div></div>`);
  if (r) css(w, box(r));
  return w;
}
function zone(r) { const z = h('<div class="zo"></div>'); css(z, box(r)); return z; }
function frame(root) {
  root.innerHTML = '<div class="mb"><div class="l"><i style="width:2.2cqw"></i><i style="width:4cqw"></i><i style="width:3.4cqw"></i></div><div class="r"><i style="width:5cqw"></i><span class="app"></span></div></div><div class="screen"></div>';
  return root.querySelector('.screen');
}
function cursor(sc) {
  const el = h('<div class="cur"><svg viewBox="0 0 14 22"><path d="M1 1v17l4.2-3.8L8.2 21l3.2-1.4-3-6.4H14z" fill="#fff" stroke="#000" stroke-width="1.2" stroke-linejoin="round"/></svg></div>');
  const rip = h('<div class="rip"></div>');
  sc.append(rip, el);
  let x = 95, y = 95;
  return {
    to(nx, ny) { x = nx; y = ny; css(el, { left: unit(nx), top: unit(ny) }); },
    show(on) { el.style.opacity = on ? 1 : 0; },
    click() { css(rip, { left: unit(x), top: unit(y) }); rip.classList.remove('go'); void rip.offsetWidth; rip.classList.add('go'); },
  };
}
// The keys and the trackpad of a demo live in the row under it, so the animation itself stays clean.
function held(root, name = 'k') {
  const ks = root.parentElement.querySelectorAll(`.keys kbd[data-hold="${name}"]`);
  return { show() {}, press(on) { ks.forEach((k) => k.classList.toggle('on', on)); } };
}
function touch(root) {
  const el = root.parentElement.querySelector('.keys .touch'), fs = el.querySelectorAll('.f');
  return {
    show(on) { el.classList.toggle('live', on); },
    down(on) { el.classList.toggle('down', on); },
    move(n, ms) { fs.forEach((f) => { f.style.transitionDuration = ms + 'ms'; f.style.transform = `translateX(${n * 4}px)`; }); },
  };
}
function stack(sc, r, classes) {
  const el = h('<div class="stack"></div>');
  css(el, box(r));
  const wins = classes.map((c) => { const w = win(c); el.append(w); return w; });
  sc.append(el);
  return {
    pos(p, ms = 800) { wins.forEach((w, i) => { w.style.transitionDuration = ms + 'ms'; w.style.transform = `translateX(${(i - p) * 101.5}%)`; }); },
  };
}
function pill(sc, n) {
  const el = h(`<div class="pill">${'<div class="cell"><i></i></div>'.repeat(n)}<div class="cap"></div></div>`);
  css(el, { left: Z1MID + '%', top: 'calc(2.7% + 1.2cqw)' });
  sc.append(el);
  const cap = el.querySelector('.cap');
  return { at(p, ms = 800) { cap.style.transitionDuration = ms + 'ms'; cap.style.transform = `translateX(${p * 100}%)`; } };
}
const cellX = (i, n) => Z1MID + (i - (n - 1) / 2) * 4;

const demos = {
  snap(sc, root) {
    const hl = [Z0, Z1, Z2].map((r) => { const e = h('<div class="hl"></div>'); css(e, box(r)); return e; });
    sc.append(...[Z0, Z1, Z2].map(zone));
    const a = win('w1 p1', Z0), b = win('w5 p3', Z2), c = win('w2 p2');
    sc.append(a, b, c, ...hl);
    const cur = cursor(sc), keys = held(root);
    const LOOSE = [63, 52, 30, 34];
    const loose = () => { css(c, { ...box(LOOSE), opacity: 1, transform: 'rotate(3deg)' }); };
    return {
      reset() { loose(); hl.forEach((e) => e.classList.remove('on')); keys.show(false); keys.press(false); cur.show(false); cur.to(92, 90); },
      async body(wait) {
        cur.show(true); cur.to(LOOSE[0] + LOOSE[2] / 2, LOOSE[1] + 4); await wait(1100);
        keys.show(true); keys.press(true); hl.forEach((e) => e.classList.add('on')); await wait(500);
        css(c, { ...box(Z1), transform: 'rotate(0deg)' }); cur.to(Z1[0] + Z1[2] / 2, Z1[1] + 4); await wait(1200);
        hl.forEach((e) => e.classList.remove('on')); keys.press(false); cur.click(); await wait(500);
        keys.show(false); cur.show(false); await wait(400);
      },
    };
  },

  stack(sc, root) {
    sc.append(win('w1 p1', Z0), win('w5 p3', Z2));
    const s = stack(sc, Z1, ['w2 p2', 'w3 p1', 'w4 p3']), p = pill(sc, 3), cur = cursor(sc);
    const next = held(root, 'next'), prev = held(root, 'prev');
    const step = async (wait, key, n) => { key.press(true); await wait(260); s.pos(n); p.at(n); await wait(500); key.press(false); await wait(600); };
    return {
      reset() { s.pos(0, 0); p.at(0, 0); cur.show(false); cur.to(Z1MID, 30); next.press(false); prev.press(false); },
      async body(wait) {
        cur.show(true); cur.to(cellX(1, 3), PILL_Y); await wait(1100);
        cur.click(); s.pos(1); p.at(1); await wait(1300);
        cur.to(cellX(2, 3), PILL_Y); await wait(1000);
        cur.click(); s.pos(2); p.at(2); await wait(1300);
        cur.to(cellX(0, 3), PILL_Y); await wait(1000);
        cur.click(); s.pos(0); p.at(0); await wait(1100);
        cur.show(false); await wait(700);
        await step(wait, next, 1); await step(wait, next, 2); await step(wait, prev, 1);
        await wait(500);
      },
    };
  },

  scroll(sc, root) {
    sc.append(win('w1 p1', Z0), win('w5 p3', Z2));
    const s = stack(sc, Z1, ['w2 p2', 'w3 p1', 'w4 p3']), p = pill(sc, 3), keys = held(root), pad = touch(root);
    return {
      reset() { s.pos(2, 0); p.at(2, 0); keys.show(false); keys.press(false); pad.show(false); pad.down(false); pad.move(-3, 0); },
      async body(wait) {
        keys.show(true); keys.press(true); pad.show(true); await wait(700);
        pad.down(true); await wait(250);
        pad.move(4, 1400); s.pos(0, 1400); p.at(0, 1400); await wait(1700);
        pad.down(false); await wait(500); pad.move(2, 0); await wait(80);
        pad.down(true); await wait(250);
        pad.move(-1, 900); s.pos(1, 900); p.at(1, 900); await wait(1200);
        pad.down(false); await wait(500);
        keys.press(false); keys.show(false); pad.show(false); await wait(300);
      },
    };
  },

  beyond(sc, root) {
    const clip = h('<div class="clip"></div>'), strip = h('<div class="strip"></div>');
    const R0 = [101.6, 2.7, 46.4, 94.6], R1 = [149.6, 2.7, 48.8, 94.6];
    strip.append(win('w1 p1', Z0), win('w2 p2', Z1), win('w5 p3', Z2), win('w6 p3', R0), win('w7 p1', R1));
    clip.append(strip); sc.append(clip);
    const er = h('<div class="edge r">›</div>'), el = h('<div class="edge l">‹</div>');
    sc.append(er, el);
    const right = held(root, 'right'), left = held(root, 'left'), keys = held(root, 'scroll'), pad = touch(root);
    const go = (x, ms) => { strip.style.transitionDuration = ms + 'ms'; strip.style.transform = `translateX(${x}%)`; };
    const edges = (r, l) => { er.style.opacity = r; el.style.opacity = l; };
    return {
      reset() { go(0, 0); [right, left, keys].forEach((k) => k.press(false)); pad.show(false); pad.down(false); pad.move(3, 0); edges(1, 0); },
      async body(wait) {
        // First the keys alone: one press, one zone-width over.
        await wait(700);
        right.press(true); await wait(260); go(-100, 1500); edges(0, 1); await wait(1700); right.press(false); await wait(1000);
        left.press(true); await wait(260); go(0, 1500); edges(1, 0); await wait(1700); left.press(false); await wait(900);
        // Then the same, held on and scrolled with two fingers.
        keys.press(true); pad.show(true); await wait(800);
        pad.down(true); await wait(250);
        pad.move(-4, 1600); go(-100, 1600); edges(0, 0); await wait(1500); edges(0, 1); await wait(500);
        pad.down(false); await wait(1500);
        pad.move(-3, 0); await wait(80); pad.down(true); await wait(250);
        pad.move(4, 1600); go(0, 1600); edges(0, 0); await wait(1500); edges(1, 0); await wait(400);
        pad.down(false); keys.press(false); pad.show(false); await wait(300);
      },
    };
  },

  editor(sc) {
    const mk = (n) => { const z = h(`<div class="z"><div class="zf">${n}</div></div>`); sc.append(z); return z; };
    const A = mk(1), B = mk(2), C = mk(3), cur = cursor(sc);
    const put = (z, r, o = 1) => { css(z, { ...box(r), opacity: o }); };
    const FULL = [1.6, 2.7, 96.8, 94.6];
    return {
      reset() { put(A, FULL); put(B, [41.2, 2.7, 57.2, 94.6], 0); put(C, [41.2, 61.4, 57.2, 35.9], 0); cur.show(false); cur.to(40, 50); },
      async body(wait) {
        cur.show(true); cur.to(40, 50); await wait(900); cur.click(); await wait(250);
        put(A, Z0); put(B, [41.2, 2.7, 57.2, 94.6]); await wait(1100);
        cur.to(70, 58); await wait(1000); cur.click(); await wait(250);
        put(B, Z1); put(C, Z2); await wait(1100);
        cur.to(40.6, 32); await wait(1000);
        cur.to(34.6, 32); put(A, [1.6, 2.7, 32, 94.6]); put(B, [35.2, 2.7, 63.2, 56]); put(C, [35.2, 61.4, 63.2, 35.9]); await wait(1300);
        cur.show(false); await wait(300);
      },
    };
  },

  layouts(sc) {
    const G = [[1.6, 2.7, 47.4, 45.9], [50.6, 2.7, 47.4, 45.9], [1.6, 51.3, 47.4, 46], [50.6, 51.3, 47.4, 46]];
    const spare = zone(G[3]); css(spare, { opacity: 0 });
    const a = win('w1 p1', Z0), b = win('w2 p2', Z1), c = win('w5 p3', Z2);
    sc.append(spare, a, b, c);
    const names = ['Three zones', 'Grid', 'Main and side'];
    const dd = h(`<div class="dd">${names.map((n) => `<div><b></b>${n}</div>`).join('')}</div>`);
    sc.append(dd);
    const rows = dd.querySelectorAll('div'), cur = cursor(sc);
    const mark = (hover, checked) => rows.forEach((r, j) => { r.classList.toggle('on', j === hover); r.firstChild.textContent = j === checked ? '✓' : ''; });
    const rowY = (i) => `${0.4 + 0.6 + 4.4 * i + 2.2}cqw`;
    return {
      reset() { css(a, box(Z0)); css(b, box(Z1)); css(c, box(Z2)); spare.style.opacity = 0; dd.classList.remove('show'); mark(-1, 0); cur.show(false); cur.to('calc(100% - 3.2cqw)', '-2.2cqw'); },
      async body(wait) {
        cur.show(true); await wait(600); cur.click(); await wait(250);
        dd.classList.add('show'); await wait(800);
        cur.to('calc(100% - 15cqw)', rowY(1)); await wait(1000); mark(1, 0); await wait(600); cur.click(); await wait(300);
        mark(1, 1); await wait(250);
        dd.classList.remove('show'); css(a, box(G[0])); css(b, box(G[1])); css(c, box(G[2])); spare.style.opacity = 1; cur.show(false); await wait(1800);
      },
    };
  },
};

function runner(root, demo) {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce) root.classList.add('static');
  let gen = 0, visible = false;
  const jump = (fn) => { root.classList.add('nt'); fn(); void root.offsetWidth; root.classList.remove('nt'); };
  const start = async () => {
    const my = ++gen;
    const wait = (ms) => new Promise((res, rej) => setTimeout(() => (visible && my === gen ? res() : rej(new Error('stop'))), reduce ? 0 : ms));
    try {
      do { jump(() => demo.reset()); await wait(80); await demo.body(wait); await wait(2200); } while (!reduce);
    } catch (e) { /* scrolled out of view: the next time it is visible it starts again */ }
  };
  new IntersectionObserver((entries) => {
    visible = entries[0].isIntersecting;
    if (visible) start();
  }, { threshold: 0.4 }).observe(root);
}

document.querySelectorAll('[data-demo]').forEach((root) => {
  const sc = frame(root);
  runner(root, demos[root.dataset.demo](sc, root));
});
