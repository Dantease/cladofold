import { test } from 'node:test';
import assert from 'node:assert/strict';
import { wheelOpening, touchOpening, followOpening, foldState, createOpeningMotion } from '../src/motion.js';

test('natural trackpad swipe up opens, swipe down closes, and reversing returns to the same angle', () => {
  const open = wheelOpening(0, 440);
  assert.equal(open, 0.4);
  assert.equal(wheelOpening(open, -440), 0);
});
test('pixel, line and page wheel units describe the same distance', () => {
  assert.equal(wheelOpening(0, 320), wheelOpening(0, 20, 1));
  assert.equal(wheelOpening(0, 320), wheelOpening(0, 0.4, 2, 800));
});
test('touch swipe up opens and the opposite gesture closes', () => {
  assert.equal(touchOpening(0, -275), 0.5);
  assert.equal(touchOpening(0.5, 275), 0);
});
test('large gestures stop at closed and open endpoints', () => {
  assert.equal(wheelOpening(0, 20000), 1);
  assert.equal(wheelOpening(1, -20000), 0);
  assert.equal(touchOpening(0, 1000), 0);
  assert.equal(touchOpening(1, -1000), 1);
});
test('button animation is independent of 60Hz versus 120Hz frames', () => {
  let a = 0, b = 0;
  for(let i=0;i<12;i++) a=followOpening(a,1,1/60);
  for(let i=0;i<24;i++) b=followOpening(b,1,1/120);
  assert.ok(Math.abs(a-b)<0.00001);
});

test('multiple scroll events reach their exact combined position on the next frame, without a tail', () => {
  const motion = createOpeningMotion();
  for (const delta of [110, 220, 110]) {
    motion.moveTo(wheelOpening(motion.scrubOrigin, delta), { scrub: true });
  }
  assert.equal(motion.current, 0);
  assert.equal(motion.advance(1/120), 0.4);
  assert.equal(motion.moving, false);
  assert.equal(motion.advance(1), 0.4);
});

test('a closing gesture immediately reverses an unfinished button opening from its visible position', () => {
  const motion = createOpeningMotion();
  motion.moveTo(1);
  const before = motion.advance(1/60);
  assert.ok(before > 0 && before < 1);
  motion.moveTo(wheelOpening(motion.scrubOrigin, -110), { scrub: true });
  assert.ok(Math.abs(motion.advance(1/120) - (before - 0.1)) < 1e-12);
  assert.equal(motion.moving, false);
});

test('direct touch input stays synchronized across different rendering frame rates', () => {
  for (const eventsPerFrame of [1, 2, 4]) {
    const motion = createOpeningMotion();
    for (let i=0; i<40; i++) {
      motion.moveTo(touchOpening(motion.scrubOrigin, -5.5), { scrub: true });
      if ((i+1)%eventsPerFrame === 0) motion.advance(eventsPerFrame/120);
    }
    assert.ok(Math.abs(motion.current - 0.4) < 1e-12);
    motion.moveTo(touchOpening(motion.scrubOrigin, 55), { scrub: true });
    assert.ok(Math.abs(motion.advance(1/120) - 0.3) < 1e-12);
    assert.equal(motion.moving, false);
  }
});
test('opening settles to a usable exact endpoint and closing returns fully black', () => {
  let value=0;
  for(let i=0;i<60;i++) value=followOpening(value,1,1/60);
  assert.equal(value,1);
  for(let i=0;i<60;i++) value=followOpening(value,0,1/60);
  assert.equal(value,0);
});
test('a suspended tab resumes without one giant animation jump', () => {
  assert.equal(followOpening(0,1,60),followOpening(0,1,0.05));
});

test('the lid stays readable through the main blur transition and reaches clean endpoints', () => {
  assert.deepEqual(foldState(1), { effect: 0, tilt: 0 });
  assert.ok(foldState(0).tilt > 1.5);
  assert.equal(foldState(0).effect, 1);
  assert.ok(foldState(0.5).tilt < Math.PI / 6);
  assert.deepEqual(foldState(-1), foldState(0));
  assert.deepEqual(foldState(2), foldState(1));
});
