export const clamp = (value, low = 0, high = 1) => Math.max(low, Math.min(high, value));
export const ease = (value) => { const t = clamp(value); return t * t * (3 - 2 * t); };
export const wheelPixels = (deltaY, deltaMode = 0, viewportHeight = 800) => deltaY * (deltaMode === 1 ? 16 : deltaMode === 2 ? viewportHeight : 1);
export function wheelOpening(opening, deltaY, deltaMode = 0, viewportHeight = 800) {
  const pixels = wheelPixels(deltaY, deltaMode, viewportHeight);
  // Natural scrolling: moving two fingers upward produces positive wheel delta.
  return clamp(opening + pixels / 1100);
}
export function touchOpening(opening, fingerDeltaY) { return clamp(opening - fingerDeltaY / 550); }
export function scrollDestination(opening, scrollTop, maximumScroll, delta, foldDistance = 1100) {
  if (opening < 0.999) return { opening: clamp(opening + delta/foldDistance), scrollTop };
  const nextTop = clamp(scrollTop + delta, 0, Math.max(0,maximumScroll));
  const remaining = delta - (nextTop-scrollTop);
  return { opening: remaining < 0 ? clamp(1 + remaining/foldDistance) : 1, scrollTop: nextTop };
}
export function foldState(opening) {
  const effect = 1 - clamp(opening);
  // Keep the display facing the visitor while the frost clears, then finish
  // the physical fold. Both directions trace exactly the same visible state.
  return { effect, tilt: 1.55334 * Math.pow(effect, 1.8) };
}
export function followOpening(current, target, seconds, tolerance = 0.0001) {
  const responseSeconds = 0.16;
  const next = current + (target - current) * (1 - Math.exp(-Math.max(0, Math.min(seconds, 0.05)) / responseSeconds));
  return Math.abs(next - target) < tolerance ? target : next;
}

// The fold and the page share one travel distance. This avoids a second easing
// tail and keeps the lid open until the visible content reaches the top.
export function createDisplayMotion() {
  const foldTravel = 1100;
  let current = 0, target = 0, direction = 0;
  return {
    get current() { return current; },
    get target() { return target; },
    get opening() { return clamp(current / foldTravel); },
    get targetOpening() { return clamp(target / foldTravel); },
    get scrollTop() { return Math.max(0, current - foldTravel); },
    get moving() { return current !== target; },
    scroll(delta, maximumScroll, foldDistance = foldTravel, instant = false) {
      if (!delta) return;
      const nextDirection = Math.sign(delta);
      // A reversal starts from what is visible, with no old momentum to fight.
      if (direction !== nextDirection) target = current;
      direction = nextDirection;
      const next = scrollDestination(clamp(target / foldTravel), Math.max(0, target - foldTravel), maximumScroll, delta, foldDistance);
      target = next.opening * foldTravel + next.scrollTop;
      if (instant) {
        if (target < foldTravel) target = nextDirection > 0 ? foldTravel : 0;
        current = target;
      }
    },
    open(value, instant = false) {
      current = Math.min(current, foldTravel);
      target = clamp(value) * foldTravel;
      direction = 0;
      if (instant) current = target;
    },
    scrollTo(value, maximumScroll, instant = false) {
      target = foldTravel + clamp(value, 0, Math.max(0, maximumScroll));
      direction = 0;
      if (instant) current = target;
    },
    syncScroll(value) { current = target = foldTravel + Math.max(0, value); direction = 0; },
    bound(maximumScroll) { current = Math.min(current, foldTravel + Math.max(0, maximumScroll)); target = Math.min(target, foldTravel + Math.max(0, maximumScroll)); },
    finish() { current = target = target > 0 && target < foldTravel ? foldTravel : target; },
    advance(seconds) {
      current = followOpening(current, target, seconds, 0.35);
      return current;
    },
  };
}
