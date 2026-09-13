import './style.css';
import { clamp, wheelOpening, touchOpening, followOpening } from './motion.js';
import { createScene } from './scene.js';

const stage = document.querySelector('#stage');
const interior = document.querySelector('#inside');
const intro = document.querySelector('#intro');
const closeButton = document.querySelector('#close-lid');
const skip = document.querySelector('#skip-motion');
const motionButton = document.querySelector('#motion-toggle');
const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
let reduced = systemMotion.matches;
let opening = 0;
let target = 0;
let frame = 0;
let lastTime = performance.now();
let scene;
let sceneReady = false;
let fingerY = null;
let unavailable = false;
const touch = matchMedia('(pointer: coarse)').matches;
document.querySelector('#gesture-hint').textContent = touch ? 'Pull down to open' : 'Scroll up to open';
document.querySelector('#phone-note').hidden = !/iPhone|iPad|Android/i.test(navigator.userAgent);

const release = 'https://github.com/Dantease/cladofold/releases/download/v1.3.0-preview/cladofold.-1.3.0-universal-preview.dmg';
if (import.meta.env.VITE_RELEASE_READY === 'true') {
  document.querySelectorAll('.download-link').forEach(link => { link.href = release; });
} else {
  document.querySelectorAll('.download-link').forEach(link => {
    link.setAttribute('aria-disabled', 'true');
    link.addEventListener('click', event => { event.preventDefault(); document.querySelector('#installation').showModal(); });
  });
  document.querySelector('.release-note').textContent = 'The new preview is being prepared';
}

function failScene() {
  unavailable = true;
  stage.style.display = 'none';
  document.querySelector('#fallback-note').hidden = false;
  setOpening(1, true);
}
try { scene = createScene(stage, () => { sceneReady = true; lastTime = performance.now(); schedule(); }, failScene); } catch { failScene(); }

function refresh() {
  const opened = opening >= 0.999;
  const closed = opening < 0.002;
  intro.classList.toggle('leaving', !closed);
  interior.classList.toggle('ready', opened);
  interior.inert = !opened;
  interior.setAttribute('aria-hidden', String(!opened));
  closeButton.hidden = closed;
  skip.hidden = opened;
  stage.style.opacity = String(clamp(opening / 0.045));
  motionButton.setAttribute('aria-pressed', String(reduced));
  motionButton.textContent = reduced ? 'Enable motion' : 'Reduce motion';
  document.querySelector('#fold-state').textContent = closed ? 'MacBook closed' : opened ? 'MacBook open' : `MacBook ${Math.round(opening * 100)}% open`;
  document.body.dataset.opening = String(Math.round(opening * 100));
  scene?.render(opening, opened);
}
function animate(now) {
  frame = 0;
  // Keep the first reveal intact when someone scrolls before the model arrives.
  if (!sceneReady && !unavailable) return;
  const elapsed = (now - lastTime) / 1000;
  lastTime = now;
  opening = reduced || unavailable ? target : followOpening(opening, target, elapsed);
  refresh();
  if (opening !== target) schedule();
}
function schedule() {
  if (!frame && !document.hidden) frame = requestAnimationFrame(animate);
}
function setOpening(value, instant = false) {
  target = clamp(value);
  if (instant || reduced || unavailable) opening = target;
  if (target < 0.999 && interior.contains(document.activeElement)) document.activeElement.blur();
  if (location.hash === '#inside') history.replaceState(null, '', location.pathname + location.search);
  lastTime = performance.now();
  refresh();
  schedule();
}
const isControl = (element) => element instanceof Element && element.closest('dialog,button,a,input,select,textarea');
// At short viewport heights, keep all content reachable before closing the lid.
const canScrollInterior = (element, delta) => opening >= 0.999 && interior.contains(element)
  && (delta > 0 ? interior.scrollTop + interior.clientHeight < interior.scrollHeight - 1 : interior.scrollTop > 0);
window.addEventListener('wheel', event => {
  if (event.ctrlKey || event.deltaY === 0 || document.querySelector('dialog[open]') || isControl(event.target)) return;
  if (canScrollInterior(event.target, event.deltaY)) return;
  event.preventDefault();
  setOpening(reduced ? (event.deltaY < 0 ? 1 : 0) : wheelOpening(target, event.deltaY, event.deltaMode, innerHeight));
}, { passive: false });
window.addEventListener('touchstart', event => { fingerY = event.touches.length === 1 && !isControl(event.target) ? event.touches[0].clientY : null; }, { passive: true });
window.addEventListener('touchmove', event => {
  if (fingerY === null || event.touches.length !== 1 || document.querySelector('dialog[open]')) return;
  const nextY = event.touches[0].clientY;
  const delta = nextY - fingerY;
  fingerY = nextY;
  if (canScrollInterior(event.target, -delta)) return;
  event.preventDefault();
  if (delta) setOpening(reduced ? (delta > 0 ? 1 : 0) : touchOpening(target, delta));
}, { passive: false });
window.addEventListener('touchend', () => { fingerY = null; }, { passive: true });
window.addEventListener('keydown', event => {
  if (document.querySelector('dialog[open]') || isControl(event.target)) return;
  const actions = { ArrowUp: target + 0.15, ArrowDown: target - 0.15, PageUp: target + 0.5, PageDown: target - 0.5, Home: 1, End: 0 };
  if (event.key in actions) { event.preventDefault(); setOpening(actions[event.key]); }
});
document.querySelector('#open-lid').addEventListener('click', () => setOpening(1));
closeButton.addEventListener('click', () => setOpening(0));
skip.addEventListener('click', event => { event.preventDefault(); setOpening(1, true); document.querySelector('.primary-download').focus(); });
motionButton.addEventListener('click', () => { reduced = !reduced; if (reduced) setOpening(target > 0 ? 1 : 0, true); else refresh(); });
systemMotion.addEventListener('change', event => { reduced = event.matches; if (reduced) setOpening(target > 0 ? 1 : 0, true); else refresh(); });
for (const [button, dialog] of [['#compatibility-open','#compatibility'],['#install-open','#installation']]) {
  document.querySelector(button).addEventListener('click', () => document.querySelector(dialog).showModal());
}
document.querySelectorAll('dialog').forEach(dialog => {
  dialog.querySelector('.dialog-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => { if (event.target === dialog) { const r = dialog.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) dialog.close(); } });
});
window.addEventListener('resize', () => { scene?.resize(); refresh(); });
document.addEventListener('visibilitychange', () => { if (document.hidden && frame) { cancelAnimationFrame(frame); frame = 0; } else { lastTime = performance.now(); schedule(); } });
window.addEventListener('pagehide', event => { if (!event.persisted) scene?.dispose(); });
if (location.hash === '#inside') setOpening(1, true); else refresh();
