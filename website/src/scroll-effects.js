import { clamp } from './motion.js';

export function sectionDepth(scrollTop, viewportHeight, top, height, compact = false, reduced = false) {
  if (reduced || viewportHeight <= 0) return { copy: 0, card: 0, tilt: 0, glow: 0 };
  const distance = clamp((scrollTop + viewportHeight / 2 - top - height / 2) / viewportHeight, -1, 1);
  const scale = compact ? 0.5 : 1;
  return { copy: distance * 12 * scale, card: -distance * 28 * scale, tilt: distance * 1.6 * scale, glow: distance * 60 * scale };
}

export function createScrollEffects(interior, requestFrame) {
  const hero = interior.querySelector('.hero-screen');
  const sections = [...interior.querySelectorAll('.feature-section, .screen-footer')];
  let viewportHeight = 0, compact = false, maximumScroll = 0, layout = [];

  function measure() {
    viewportHeight = interior.clientHeight;
    compact = interior.clientWidth < 700;
    maximumScroll = Math.max(1, interior.scrollHeight - viewportHeight);
    layout = sections.map(element => ({ element, top: element.offsetTop, height: element.offsetHeight }));
    requestFrame();
  }
  const observer = new ResizeObserver(measure);
  observer.observe(interior);
  observer.observe(hero);
  sections.forEach(section => observer.observe(section));
  measure();

  return {
    update(enabled) {
      const scrollTop = interior.scrollTop;
      hero.style.setProperty('--hero-depth', `${enabled ? Math.min(scrollTop * 0.2, viewportHeight * 0.24) : 0}px`);
      for (const { element, top, height } of layout) {
        const depth = sectionDepth(scrollTop, viewportHeight, top, height, compact, !enabled);
        element.style.setProperty('--copy-depth', `${depth.copy}px`);
        element.style.setProperty('--card-depth', `${depth.card}px`);
        element.style.setProperty('--card-tilt', `${depth.tilt}deg`);
        element.style.setProperty('--glow-depth', `${depth.glow}px`);
      }
      return {
        phase: enabled ? clamp(scrollTop / maximumScroll) : 0,
        strength: enabled ? clamp(scrollTop / Math.max(1, viewportHeight * 0.55)) : 0,
      };
    },
    dispose() { observer.disconnect(); },
  };
}
