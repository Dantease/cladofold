import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createDisplayMotion } from '../src/motion.js';

function settle(motion) { for (let i=0; i<120 && motion.moving; i++) motion.advance(1/60); }

test('lid gestures have a noticeable smooth delay without losing input', () => {
  const motion = createDisplayMotion();
  for (const delta of [110,220,110]) motion.scroll(delta,2000);
  assert.equal(motion.target,440);
  motion.advance(1/60);
  assert.ok(motion.opening>0 && motion.opening<0.4);
  for(let i=0;i<11;i++) motion.advance(1/60);
  assert.ok(motion.opening>0.27 && motion.opening<0.30);
  settle(motion);
  assert.equal(motion.opening,0.4);
  assert.equal(motion.moving,false);
});
test('easing is equivalent at 60Hz and 120Hz', () => {
  const a=createDisplayMotion(), b=createDisplayMotion();
  a.scroll(440,2000);b.scroll(440,2000);
  for(let i=0;i<12;i++) a.advance(1/60);
  for(let i=0;i<24;i++) b.advance(1/120);
  assert.ok(Math.abs(a.current-b.current)<1e-9);
});
test('interior scrolling uses the same easing and never overshoots', () => {
  const motion=createDisplayMotion();motion.open(1,true);motion.scroll(500,2000);
  motion.advance(1/60);
  assert.equal(motion.opening,1);
  assert.ok(motion.scrollTop>0 && motion.scrollTop<500);
  settle(motion);assert.equal(motion.scrollTop,500);
});
test('reversing a gesture cancels the pending direction from the visible position', () => {
  const motion=createDisplayMotion();motion.scroll(440,2000);motion.advance(1/60);
  const visible=motion.current;
  motion.scroll(-20,2000);motion.advance(1/60);
  assert.ok(motion.current<visible);
  settle(motion);assert.ok(Math.abs(motion.current-(visible-20))<1e-9);
});
test('the page reaches its top before the lid starts closing', () => {
  const motion=createDisplayMotion();motion.open(1,true);motion.scrollTo(400,2000,true);
  motion.scroll(-510,2000);
  motion.advance(1/60);
  assert.ok(motion.scrollTop>0);assert.equal(motion.opening,1);
  settle(motion);assert.equal(motion.scrollTop,0);assert.equal(motion.opening,0.9);
});
test('the lid reveal finishes before pending page scrolling is visible', () => {
  const motion=createDisplayMotion();motion.scroll(1100,2000);motion.scroll(400,2000);
  motion.advance(1/60);assert.ok(motion.opening<1);assert.equal(motion.scrollTop,0);
  settle(motion);assert.equal(motion.opening,1);assert.equal(motion.scrollTop,400);
});
test('reduced motion is immediate, and resize or scrollbar input cannot leave stale targets', () => {
  const motion=createDisplayMotion();motion.scroll(100,2000,1100,true);
  assert.equal(motion.opening,1);assert.equal(motion.moving,false);
  motion.scroll(500,2000,1100,true);assert.equal(motion.scrollTop,500);
  motion.bound(200);assert.equal(motion.scrollTop,200);assert.equal(motion.moving,false);
  motion.scroll(100,2000);motion.syncScroll(50);motion.advance(1/60);
  assert.equal(motion.scrollTop,50);assert.equal(motion.moving,false);
});
