import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scrollDestination } from '../src/motion.js';

test('continued scrolling after opening explores the page with the lid fully open', () => {
  assert.deepEqual(scrollDestination(1, 0, 2000, 400), { opening: 1, scrollTop: 400 });
});
test('scrolling back through features keeps the lid open until the top', () => {
  assert.deepEqual(scrollDestination(1, 500, 2000, -300), { opening: 1, scrollTop: 200 });
  assert.deepEqual(scrollDestination(1, 200, 2000, -200), { opening: 1, scrollTop: 0 });
});
test('only the gesture remaining beyond the top closes the lid', () => {
  assert.deepEqual(scrollDestination(1, 200, 2000, -310), { opening: .9, scrollTop: 0 });
  assert.deepEqual(scrollDestination(1, 50, 2000, -105, 550), { opening: .9, scrollTop: 0 });
});
test('scrolling beyond the footer never closes the lid or overflows the content', () => {
  assert.deepEqual(scrollDestination(1, 1900, 2000, 500), { opening: 1, scrollTop: 2000 });
});
test('the initial reveal completes before any feature scrolling begins', () => {
  assert.deepEqual(scrollDestination(0, 0, 2000, 550), { opening: .5, scrollTop: 0 });
  assert.deepEqual(scrollDestination(.5, 0, 2000, 1000), { opening: 1, scrollTop: 0 });
});
