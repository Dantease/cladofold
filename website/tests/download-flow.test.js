import { test } from 'node:test';
import assert from 'node:assert/strict';
import { setupDownloads } from '../src/download-flow.js';
import { releaseURL } from '../src/release.js';

class FakeElement {
  constructor() { this.listeners = new Map(); }
  addEventListener(name, listener) { this.listeners.set(name, listener); }
}

test('runtime download setup preserves ordinary navigation to the pinned DMG', () => {
  const links = Array.from({ length: 4 }, () => new FakeElement());
  const close = new FakeElement();
  const status = { textContent: '' };
  const nudge = {
    hidden: true,
    querySelector(selector) { return selector === 'button' ? close : status; },
  };
  const previousDocument = globalThis.document;
  globalThis.document = {
    querySelector(selector) { return selector === '#star-nudge' ? nudge : null; },
    querySelectorAll(selector) { return selector === '.download-link' ? links : []; },
  };

  try {
    setupDownloads(releaseURL);
    assert.deepEqual(links.map(link => link.href), Array(4).fill(releaseURL));
    let prevented = false;
    links[0].listeners.get('click')({
      metaKey: false, ctrlKey: false, shiftKey: false, altKey: false,
      preventDefault() { prevented = true; },
    });
    assert.equal(prevented, false);
    assert.equal(nudge.hidden, false);
    assert.equal(status.textContent, 'Your download is starting.');
  } finally {
    globalThis.document = previousDocument;
  }
});
