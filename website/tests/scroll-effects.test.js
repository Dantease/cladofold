import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sectionDepth } from '../src/scroll-effects.js';

test('scroll depth follows position immediately and retraces exactly when reversing', () => {
  const start = sectionDepth(500, 800, 800, 600);
  const middle = sectionDepth(700, 800, 800, 600);
  const end = sectionDepth(900, 800, 800, 600);
  assert.equal(middle.copy, 0);
  assert.equal(Math.abs(middle.card), 0);
  assert.equal(start.copy, -end.copy);
  assert.equal(start.card, -end.card);
  assert.deepEqual(sectionDepth(500, 800, 800, 600), start);
});
test('offscreen depth is bounded and phone movement is smaller', () => {
  const far = sectionDepth(10000, 800, 800, 600);
  assert.deepEqual(far, sectionDepth(20000, 800, 800, 600));
  const phone = sectionDepth(10000, 800, 800, 600, true);
  assert.equal(phone.card, far.card / 2);
  assert.ok(Math.abs(far.card) <= 28);
});
test('reduced motion and zero-height layouts have no parallax', () => {
  const neutral = { copy: 0, card: 0, tilt: 0, glow: 0 };
  assert.deepEqual(sectionDepth(900, 800, 800, 600, false, true), neutral);
  assert.deepEqual(sectionDepth(900, 0, 800, 600), neutral);
});
