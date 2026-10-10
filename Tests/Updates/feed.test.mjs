import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { verifySignedFeed, verifyUpdateFeed } from '../../Scripts/verify-update-feed.mjs';

// Ephemeral fixture keys remain in memory; never use or export release keys.
const keys = generateKeyPairSync('ed25519');
const publicKey = keys.publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64');
const archive = Buffer.from('Synthetic release archive bytes. No executable payload.');
const filename = 'cladofold-1.4.0.zip';
const signature = sign(null, archive, keys.privateKey).toString('base64');
const content = Buffer.from(`<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel><title>cladofold. — updates</title><item>
    <sparkle:version>36</sparkle:version><sparkle:shortVersionString>1.4.0</sparkle:shortVersionString>
    <description><![CDATA[<p>Signed release notes & examples.</p>]]></description>
    <enclosure url="https://github.com/Dantease/cladofold/releases/download/v1.4.0-preview/${filename}" length="${archive.length}" sparkle:edSignature="${signature}" type="application/octet-stream"/>
  </item></channel>
</rss>
`);
function signed(bytes = content, privateKey = keys.privateKey) {
  return Buffer.concat([bytes, Buffer.from(`<!-- sparkle-signatures:\nedSignature: ${sign(null, bytes, privateKey).toString('base64')}\nlength: ${bytes.length}\n-->\n`)]);
}
function options(overrides = {}) {
  return { feed: signed(), publicKey, version: '36', shortVersion: '1.4.0',
    archives: [{ name: filename, data: archive }], ...overrides };
}
function modified(from, to) { return Buffer.from(content.toString().replace(from, to)); }

test('authenticates Sparkle framed feed and matching archive with public key only', () => {
  assert.deepEqual(verifySignedFeed(signed(), publicKey), content);
  assert.deepEqual(verifyUpdateFeed(options()), { version: '36', shortVersion: '1.4.0', verifiedArchives: [filename] });
});
test('rejects same-length feed tampering and accepts correctly re-signed change', () => {
  const tampered = Buffer.from(signed().toString().replace('Signed release', 'Forged release'));
  assert.throws(() => verifyUpdateFeed(options({ feed: tampered })), /signature verification/);
  const changed = modified('Signed release', 'Revised release');
  assert.doesNotThrow(() => verifyUpdateFeed(options({ feed: signed(changed) })));
});
test('rejects archive tampering even when byte length matches', () => {
  const changed = Buffer.from(archive);
  changed[0] ^= 1;
  assert.throws(() => verifyUpdateFeed(options({ archives: [{ name: filename, data: changed }] })), /Archive signature/);
});
test('rejects truncated archive and missing expected archive', () => {
  assert.throws(() => verifyUpdateFeed(options({ archives: [{ name: filename, data: archive.subarray(1) }] })), /byte length/);
  assert.throws(() => verifyUpdateFeed(options({ archives: [] })), /Supply the release archive/);
});
test('rejects unsigned feed, wrong public key and forged feed signature', () => {
  assert.throws(() => verifyUpdateFeed(options({ feed: content })), /signature block/);
  const wrong = generateKeyPairSync('ed25519');
  assert.throws(() => verifyUpdateFeed(options({ feed: signed(content, wrong.privateKey) })), /signature verification/);
  assert.throws(() => verifyUpdateFeed(options({ publicKey: Buffer.alloc(32).toString('base64') })), /signature verification/);
});
test('rejects untrusted signing block length and unsigned appended content', () => {
  assert.throws(() => verifyUpdateFeed(options({ feed: Buffer.from(signed().toString().replace(`length: ${content.length}`, 'length: 1')) })), /byte length/);
  assert.throws(() => verifyUpdateFeed(options({ feed: Buffer.concat([signed(), Buffer.from('<item/>')]) })), /unsigned suffix/);
  assert.throws(() => verifyUpdateFeed(options({ feed: Buffer.concat([signed(), signed()]) })), /ambiguous/);
});
test('requires expected build and marketing versions', () => {
  assert.throws(() => verifyUpdateFeed(options({ version: '35' })), /version mismatch/);
  assert.throws(() => verifyUpdateFeed(options({ shortVersion: '1.3.1' })), /version mismatch/);
  assert.throws(() => verifyUpdateFeed(options({ version: undefined })), /versions are required/);
});
test('rejects non-HTTPS or credential-bearing signed download URLs', () => {
  for (const replacement of ['http://github.com', 'https://user:password@github.com']) {
    assert.throws(() => verifyUpdateFeed(options({ feed: signed(modified('https://github.com', replacement)) })), /HTTPS/);
  }
});
test('rejects mismatched Sparkle namespace, namespace rebinding and malformed XML', () => {
  for (const bytes of [modified('http://www.andymatuschak.org/xml-namespaces/sparkle', 'https://invalid.example'),
    modified('<item>', '<item xmlns:sparkle="https://invalid.example">'), modified('</item>', '</channel>')]) {
    assert.throws(() => verifyUpdateFeed(options({ feed: signed(bytes) })), /namespace|Namespace|Mismatched/);
  }
});
test('rejects duplicate signed fields and external entity declarations', () => {
  assert.throws(() => verifyUpdateFeed(options({ feed: signed(modified('<sparkle:version>36</sparkle:version>',
    '<sparkle:version>36</sparkle:version><sparkle:version>37</sparkle:version>')) })), /Expected one/);
  assert.throws(() => verifyUpdateFeed(options({ feed: signed(modified('<rss ', '<!DOCTYPE rss SYSTEM "https://invalid.example/entity"><rss ')) })), /Unsupported/);
});
test('rejects duplicate enclosures and invalid archive-signature metadata even in signed feeds', () => {
  const enclosure = /<enclosure[^>]+\/>/.exec(content.toString())[0];
  assert.throws(() => verifyUpdateFeed(options({ feed: signed(modified(enclosure, enclosure + enclosure)) })), /Expected one enclosure/);
  assert.throws(() => verifyUpdateFeed(options({ feed: signed(modified(signature, 'not-base64')) })), /Invalid archive signature/);
  assert.throws(() => verifyUpdateFeed(options({ feed: signed(modified(`length="${archive.length}"`, 'length="-1"')) })), /Invalid archive byte length/);
});
test('accepts XML entities and percent encoding in signed archive URLs', () => {
  const encoded = modified(filename, 'cladofold%2D1.4.0.zip?one=1&amp;two=2');
  assert.doesNotThrow(() => verifyUpdateFeed(options({ feed: signed(encoded) })));
});
test('CLI accepts authentic artifacts and fails tampered archive without signing-key access', () => {
  const directory = mkdtempSync(join(tmpdir(), 'cladofold-update-test-'));
  try {
    const feedPath = join(directory, 'appcast.xml');
    const archivePath = join(directory, filename);
    writeFileSync(feedPath, signed()); writeFileSync(archivePath, archive);
    const args = [resolve('Scripts/verify-update-feed.mjs'), '--public-key', publicKey, '--feed', feedPath,
      '--version', '36', '--short-version', '1.4.0', archivePath];
    assert.equal(spawnSync(process.execPath, args, { encoding: 'utf8' }).status, 0);
    writeFileSync(archivePath, 'tampered');
    assert.equal(spawnSync(process.execPath, args, { encoding: 'utf8' }).status, 1);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
test('optional official Sparkle verifier accepts fixture framing and rejects tampering',
  { skip: !process.env.SPARKLE_SIGN_UPDATE }, () => {
    const directory = mkdtempSync(join(tmpdir(), 'cladofold-sparkle-test-'));
    try {
      const feedPath = join(directory, 'appcast.xml');
      const seed = keys.privateKey.export({ format: 'der', type: 'pkcs8' }).subarray(-32).toString('base64');
      writeFileSync(feedPath, signed());
      const args = ['--ed-key-file', '-', '--verify', feedPath];
      const run = () => spawnSync(process.env.SPARKLE_SIGN_UPDATE, args, { input: `${seed}\n`, encoding: 'utf8' });
      assert.equal(run().status, 0, 'Official Sparkle must accept fixture');
      writeFileSync(feedPath, Buffer.from(signed().toString().replace('Signed release', 'Forged release')));
      assert.notEqual(run().status, 0, 'Official Sparkle must reject tampering');
    } finally { rmSync(directory, { recursive: true, force: true }); }
  });
