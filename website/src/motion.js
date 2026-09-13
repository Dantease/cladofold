export const clamp = (value, low = 0, high = 1) => Math.max(low, Math.min(high, value));
export const ease = (value) => { const t = clamp(value); return t * t * (3 - 2 * t); };
export function wheelOpening(opening, deltaY, deltaMode = 0, viewportHeight = 800) {
  const pixels = deltaY * (deltaMode === 1 ? 16 : deltaMode === 2 ? viewportHeight : 1);
  return clamp(opening - pixels / 1100);
}
export function touchOpening(opening, fingerDeltaY) { return clamp(opening + fingerDeltaY / 550); }
export function followOpening(current, target, seconds) {
  const next = current + (target - current) * (1 - Math.exp(-Math.min(seconds, 0.05) * 25));
  return Math.abs(next - target) < 0.0001 ? target : next;
}
