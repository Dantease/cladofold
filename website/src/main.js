import './style.css';
import './features.css';
import { clamp, wheelPixels, createDisplayMotion } from './motion.js';
import { createScene } from './scene.js';
import { setupDownloads } from './download-flow.js';
import { setupFeaturePreviews } from './feature-previews.js';
import { createScrollEffects } from './scroll-effects.js';
import { releaseURL } from './release.js';

const stage = document.querySelector('#stage');
const interior = document.querySelector('#inside');
const intro = document.querySelector('#intro');
const closeButton = document.querySelector('#close-lid');
const skip = document.querySelector('#skip-motion');
const motionButton = document.querySelector('#motion-toggle');
const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
let reduced = systemMotion.matches;
let opening = 0;
const motion = createDisplayMotion();
let renderedScrollTop = 0;
let frame = 0;
let lastTime = performance.now();
let scene;
let sceneReady = false;
let fingerY = null;
let unavailable = false;
const scrollEffects = createScrollEffects(interior, schedule);
document.querySelector('#phone-note').hidden = !/iPhone|iPad|Android/i.test(navigator.userAgent);

setupDownloads(releaseURL);

function failScene() {
  unavailable = true;
  stage.style.display = 'none';
  document.querySelector('#fallback-note').hidden = false;
  setOpening(1, true);
}
try { scene = createScene(stage, interior, () => { sceneReady = true; lastTime = performance.now(); schedule(); }, failScene); } catch { failScene(); }

function refresh() {
  const opened = opening >= 0.999;
  const closed = opening < 0.002;
  if (closed && interior.scrollTop > 0) { interior.scrollTop = 0; scene?.restoreTopTexture(); }
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
  const depth = scrollEffects.update(opened && !reduced && !unavailable);
  scene?.render(opening, opened, depth);
}
function animate(now) {
  frame = 0;
  // Keep the first reveal intact when someone scrolls before the model arrives.
  if (!sceneReady && !unavailable) return;
  const elapsed = (now - lastTime) / 1000;
  lastTime = now;
  motion.bound(interior.scrollHeight - interior.clientHeight);
  motion.advance(elapsed);
  opening = motion.opening;
  interior.scrollTop = motion.scrollTop;
  renderedScrollTop = interior.scrollTop;
  refresh();
  if (motion.moving) schedule();
}
function schedule() {
  if (!frame && !document.hidden) frame = requestAnimationFrame(animate);
}
function setOpening(value, instant = false) {
  const immediate = instant || reduced || unavailable;
  motion.open(value, immediate);
  if (motion.targetOpening < 0.999 && interior.contains(document.activeElement)) document.activeElement.blur();
  if (location.hash === '#inside') history.replaceState(null, '', location.pathname + location.search);
  // Use one short easing curve for the fold and interior page movement.
  if (!frame) lastTime = performance.now();
  if (immediate) { opening = motion.opening; interior.scrollTop = motion.scrollTop; renderedScrollTop = interior.scrollTop; refresh(); }
  schedule();
}
const isControl = (element) => element instanceof Element && element.closest('dialog,button,a,input,select,textarea');
// After the reveal, the same gesture scrolls the page inside the display.
// Only an upward page scroll beyond the content's top edge begins closing.
function scrollDisplay(delta, foldDistance = 1100) {
  motion.scroll(delta, interior.scrollHeight-interior.clientHeight, foldDistance, reduced || unavailable);
  if (motion.targetOpening < 0.999) scene?.restoreTopTexture();
  if (!frame) lastTime = performance.now();
  schedule();
}
function scrollPageTo(value) {
  motion.scrollTo(value, interior.scrollHeight-interior.clientHeight, reduced || unavailable);
  if (!frame) lastTime = performance.now();
  schedule();
}
window.addEventListener('wheel', event => {
  if (event.ctrlKey || event.deltaY === 0 || document.querySelector('dialog[open]')) return;
  event.preventDefault();
  scrollDisplay(wheelPixels(event.deltaY, event.deltaMode, innerHeight));
}, { passive: false });
window.addEventListener('touchstart', event => { fingerY = event.touches.length === 1 && !event.target.closest('input') && !document.querySelector('dialog[open]') ? event.touches[0].clientY : null; }, { passive: true });
window.addEventListener('touchmove', event => {
  if (fingerY === null || event.touches.length !== 1 || document.querySelector('dialog[open]')) return;
  const nextY = event.touches[0].clientY;
  const delta = nextY - fingerY;
  fingerY = nextY;
  event.preventDefault();
  if (delta) scrollDisplay(-delta, 550);
}, { passive: false });
window.addEventListener('touchend', () => { fingerY = null; }, { passive: true });
window.addEventListener('keydown', event => {
  if (document.querySelector('dialog[open]') || isControl(event.target)) return;
  if (opening >= 0.999) {
    if (event.key === 'Home') { event.preventDefault(); scrollPageTo(0); return; }
    if (event.key === 'End') { event.preventDefault(); scrollPageTo(interior.scrollHeight); return; }
    const distances = { ArrowDown: 60, ArrowUp: -60, PageDown: interior.clientHeight*.85, PageUp: -interior.clientHeight*.85, ' ': interior.clientHeight*.85*(event.shiftKey?-1:1) };
    if (event.key in distances) { event.preventDefault(); scrollDisplay(distances[event.key]); return; }
  }
  const actions = { ArrowUp: motion.targetOpening + 0.15, ArrowDown: motion.targetOpening - 0.15, PageUp: motion.targetOpening + 0.5, PageDown: motion.targetOpening - 0.5, Home: 1, End: 0 };
  if (event.key in actions) { event.preventDefault(); setOpening(actions[event.key]); }
});
document.querySelector('#open-lid').addEventListener('click', () => setOpening(1));
closeButton.addEventListener('click', () => setOpening(0));
skip.addEventListener('click', event => { event.preventDefault(); setOpening(1, true); document.querySelector('.primary-download').focus(); });
motionButton.addEventListener('click', () => { reduced = !reduced; if (reduced) motion.finish(); schedule(); });
systemMotion.addEventListener('change', event => { reduced = event.matches; if (reduced) motion.finish(); schedule(); });
for (const [button, dialog] of [['#compatibility-open','#compatibility'],['#footer-compatibility','#compatibility'],['#install-open','#installation']]) {
  document.querySelector(button).addEventListener('click', () => { document.querySelectorAll('dialog[open]').forEach(open => open.close()); document.querySelector(dialog).showModal(); });
}
document.querySelectorAll('dialog').forEach(dialog => {
  dialog.querySelector('.dialog-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => { if (event.target === dialog) { const r = dialog.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) dialog.close(); } });
});
window.addEventListener('resize', () => { scene?.resize(); refresh(); });
document.querySelector('.explore-cue').addEventListener('click', event => { event.preventDefault(); scrollPageTo(document.querySelector('#features').offsetTop); });
document.querySelector('.brand').addEventListener('click', event => { event.preventDefault(); scrollPageTo(0); });
let contentTimer;
setupFeaturePreviews(() => { clearTimeout(contentTimer); contentTimer = setTimeout(() => scene?.refreshTexture(), 180); });
interior.addEventListener('scroll', () => {
  // Scrollbar drags and browser focus scrolling take over from the animation.
  if (opening >= 0.999 && Math.abs(interior.scrollTop-renderedScrollTop) > 1) motion.syncScroll(interior.scrollTop);
  renderedScrollTop = interior.scrollTop;
  schedule(); clearTimeout(contentTimer); contentTimer = setTimeout(() => scene?.refreshTexture(), 120);
}, { passive: true });
document.addEventListener('visibilitychange', () => { if (document.hidden && frame) { cancelAnimationFrame(frame); frame = 0; } else { lastTime = performance.now(); schedule(); } });
window.addEventListener('pagehide', event => { if (!event.persisted) { scrollEffects.dispose(); scene?.dispose(); } });
if (location.hash === '#inside') setOpening(1, true); else refresh();
