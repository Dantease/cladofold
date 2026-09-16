import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { releaseURL } from '../src/release.js';

const read = path => readFile(new URL(path, import.meta.url), 'utf8');

test('the website footer links to privacy, terms and support', async () => {
  const home = await read('../index.html');
  assert.match(home, /<nav class="footer-links" aria-label="Footer">/);
  for (const page of ['privacy', 'terms', 'support']) {
    assert.match(home, new RegExp(`href="\\./${page}\\.html"`));
  }
});

test('every download control starts the pinned Mac download', async () => {
  const home = await read('../index.html');
  const downloadLinks = [...home.matchAll(/<a class="[^"]*download-link[^"]*"[^>]*>/g)].map(match => match[0]);
  assert.equal(downloadLinks.length, 4);
  for (const link of downloadLinks) {
    assert.match(link, new RegExp(`href="${releaseURL.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`));
    // Derived from the pinned URL so a new release cannot leave this behind.
    assert.match(link, new RegExp(`download="${releaseURL.split('/').pop().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`));
  }
});

test('the deployment check uses the same pinned download', async () => {
  const workflow = await read('../../.github/workflows/pages.yml');
  assert.match(workflow, new RegExp(releaseURL.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
});

test('public information pages include the essential user disclosures', async () => {
  const [privacy, terms, support] = await Promise.all([
    read('../public/privacy.html'),
    read('../public/terms.html'),
    read('../public/support.html'),
  ]);
  assert.match(privacy, /GitHub Pages, which logs visitors’ IP addresses for security/);
  assert.match(privacy, /never uploaded or saved/);
  assert.match(terms, /MIT License/);
  assert.match(terms, /provided “as is,”/);
  assert.match(support, /id="support-name"[^>]+required/);
  assert.match(support, /id="support-email"[^>]+type="email"[^>]+required/);
  assert.match(support, /id="support-message"[^>]+required/);
  assert.match(support, /Nothing is sent from this page/);
});
