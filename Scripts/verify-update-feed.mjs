#!/usr/bin/env node
import { createPublicKey, verify } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const signingPrefix = Buffer.from('<!-- sparkle-signatures:\n');
const sparkleNamespace = 'http://www.andymatuschak.org/xml-namespaces/sparkle';
const utf8 = new TextDecoder('utf-8', { fatal: true });

function requireCondition(condition, message) {
  if (!condition) throw new Error(message);
}

function base64(value, length, label) {
  requireCondition(typeof value === 'string', `Missing ${label}`);
  const bytes = Buffer.from(value, 'base64');
  requireCondition(bytes.length === length && bytes.toString('base64') === value, `Invalid ${label}`);
  return bytes;
}

function publicKeyFromBase64(value) {
  const raw = base64(value, 32, 'Ed25519 public key');
  return createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), raw]),
    format: 'der', type: 'spki' });
}

// Sparkle 2.10.0 common_cli/Signing.swift appends this block after the exact
// signed bytes. SPUExtractSignedFeed.m finds its last occurrence. For publishing,
// reject duplicate blocks and unsigned trailing content rather than ignoring it.
// https://github.com/sparkle-project/Sparkle/blob/2.10.0/common_cli/Signing.swift
export function verifySignedFeed(feed, publicKey) {
  requireCondition(Buffer.isBuffer(feed) && feed.length <= 2 * 1024 * 1024, 'Feed must be at most 2 MiB');
  const start = feed.lastIndexOf(signingPrefix);
  requireCondition(start >= 0 && feed.indexOf(signingPrefix) === start, 'Missing or ambiguous feed signature block');
  const block = utf8.decode(feed.subarray(start));
  const match = /^<!-- sparkle-signatures:\nedSignature: ([A-Za-z0-9+/]+={0,2})\nlength: (0|[1-9][0-9]*)\n-->\n?$/.exec(block);
  requireCondition(match, 'Invalid feed signature framing or unsigned suffix');
  const content = feed.subarray(0, start);
  requireCondition(BigInt(match[2]) === BigInt(content.length), 'Feed byte length mismatch');
  requireCondition(verify(null, content, publicKeyFromBase64(publicKey), base64(match[1], 64, 'feed signature')),
    'Feed signature verification failed');
  return content;
}

function decodeEntities(text) {
  return text.replace(/&([^;]*);|&/g, (entity, name) => {
    const named = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };
    if (Object.hasOwn(named, name)) return named[name];
    if (/^#(?:[0-9]+|x[0-9a-fA-F]+)$/.test(name ?? '')) {
      const code = name.startsWith('#x') ? parseInt(name.slice(2), 16) : Number(name.slice(1));
      requireCondition(code === 9 || code === 10 || code === 13 ||
        (code >= 32 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff)), 'Invalid XML character');
      return String.fromCodePoint(code);
    }
    throw new Error(`Unsupported XML entity ${entity}`);
  });
}

// Deliberately bounded XML subset used by generate_appcast. No DTDs, external
// entities, namespace rebinding or executable XML processing. This is a release
// artifact checker, not a replacement for Sparkle's runtime appcast parser.
function parseXML(bytes) {
  const xml = utf8.decode(bytes);
  const document = { name: '#document', children: [], text: '', attributes: {} };
  const stack = [document];
  let offset = 0;
  while (offset < xml.length) {
    const parent = stack.at(-1);
    if (xml[offset] !== '<') {
      let end = xml.indexOf('<', offset);
      if (end < 0) end = xml.length;
      parent.text += decodeEntities(xml.slice(offset, end));
      offset = end;
      continue;
    }
    if (xml.startsWith('<!--', offset)) {
      const end = xml.indexOf('-->', offset + 4);
      requireCondition(end >= 0 && !xml.slice(offset + 4, end).includes('--'), 'Malformed XML comment');
      offset = end + 3;
      continue;
    }
    if (xml.startsWith('<![CDATA[', offset)) {
      const end = xml.indexOf(']]>', offset + 9);
      requireCondition(stack.length > 1 && end >= 0, 'Malformed CDATA');
      parent.text += xml.slice(offset + 9, end);
      offset = end + 3;
      continue;
    }
    if (xml.startsWith('<?xml ', offset)) {
      const end = xml.indexOf('?>', offset + 6);
      requireCondition(offset === 0 && end >= 0, 'Misplaced XML declaration');
      offset = end + 2;
      continue;
    }
    const token = /^<\/?[A-Za-z_][\w.:-]*(?:\s+[A-Za-z_][\w.:-]*\s*=\s*(?:"[^"<]*"|'[^'<]*'))*\s*\/?>/.exec(xml.slice(offset));
    requireCondition(token, 'Unsupported or malformed XML element');
    const tag = token[0];
    const name = /^<\/?([A-Za-z_][\w.:-]*)/.exec(tag)[1];
    if (tag.startsWith('</')) {
      requireCondition(/^<\/[A-Za-z_][\w.:-]*\s*>$/.test(tag) && stack.length > 1 && parent.name === name,
        'Mismatched XML closing element');
      stack.pop();
    } else {
      const attributes = Object.create(null);
      for (const attr of tag.matchAll(/\s+([A-Za-z_][\w.:-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')/g)) {
        requireCondition(!Object.hasOwn(attributes, attr[1]), 'Duplicate XML attribute');
        requireCondition(stack.length === 1 || !attr[1].startsWith('xmlns'), 'Namespace rebinding is unsupported');
        attributes[attr[1]] = decodeEntities(attr[2] ?? attr[3]);
      }
      const child = { name, attributes, children: [], text: '' };
      parent.children.push(child);
      if (!tag.endsWith('/>')) stack.push(child);
      requireCondition(stack.length <= 32, 'XML nesting exceeds limit');
    }
    offset += tag.length;
  }
  requireCondition(stack.length === 1 && document.children.length === 1 && !document.text.trim(), 'Incomplete XML document');
  return document.children[0];
}

function onlyChild(parent, name) {
  const matches = parent.children.filter(child => child.name === name);
  requireCondition(matches.length === 1, `Expected one ${name} element`);
  return matches[0];
}

function leafText(parent, name) {
  const node = onlyChild(parent, name);
  requireCondition(node.children.length === 0, `Invalid ${name} value`);
  return node.text.trim();
}

export function verifyUpdateFeed({ feed, publicKey, version, shortVersion, archives = [] }) {
  requireCondition(typeof version === 'string' && version.length > 0 && typeof shortVersion === 'string' && shortVersion.length > 0,
    'Expected build and short versions are required');
  const root = parseXML(verifySignedFeed(feed, publicKey));
  requireCondition(root.name === 'rss' && root.attributes.version === '2.0' &&
    root.attributes['xmlns:sparkle'] === sparkleNamespace && !root.attributes.xmlns, 'Unexpected RSS or Sparkle namespace');
  const items = onlyChild(root, 'channel').children.filter(child => child.name === 'item');
  requireCondition(items.length > 0, 'Feed contains no updates');
  const releases = items.map(item => {
    const enclosure = onlyChild(item, 'enclosure');
    const release = { version: leafText(item, 'sparkle:version'), shortVersion: leafText(item, 'sparkle:shortVersionString'),
      url: enclosure.attributes.url, length: enclosure.attributes.length, signature: enclosure.attributes['sparkle:edSignature'] };
    const url = new URL(release.url);
    requireCondition(url.protocol === 'https:' && url.hostname && !url.username && !url.password && !url.hash,
      'Update download must use HTTPS without credentials or fragment');
    requireCondition(/^(0|[1-9][0-9]*)$/.test(release.length ?? ''), 'Invalid archive byte length');
    base64(release.signature, 64, 'archive signature');
    return { ...release, filename: decodeURIComponent(url.pathname.split('/').at(-1)) };
  });
  const expected = releases.filter(item => item.version === version);
  requireCondition(expected.length === 1 && expected[0].shortVersion === shortVersion, 'Release version mismatch or duplicate build');
  requireCondition(archives.length > 0, 'Supply the release archive for signature verification');
  const seen = new Set();
  for (const archive of archives) {
    const name = basename(archive.name);
    requireCondition(!seen.has(name), 'Duplicate local archive name');
    seen.add(name);
    const matches = releases.filter(item => item.filename === name);
    requireCondition(matches.length === 1, `No unambiguous signed enclosure for ${name}`);
    const release = matches[0];
    requireCondition(BigInt(release.length) === BigInt(archive.data.length), `Archive byte length mismatch: ${name}`);
    requireCondition(verify(null, archive.data, publicKeyFromBase64(publicKey), base64(release.signature, 64, 'archive signature')),
      `Archive signature verification failed: ${name}`);
  }
  requireCondition(seen.has(expected[0].filename), 'Expected release archive was not verified');
  return { version, shortVersion, verifiedArchives: [...seen] };
}

function main(args) {
  const options = {};
  const paths = [];
  const names = { '--public-key': 'publicKey', '--feed': 'feedPath', '--version': 'version', '--short-version': 'shortVersion' };
  while (args.length) {
    const arg = args.shift();
    if (Object.hasOwn(names, arg)) {
      requireCondition(args.length && !Object.hasOwn(options, names[arg]), `Missing or duplicate ${arg}`);
      options[names[arg]] = args.shift();
    } else {
      requireCondition(!arg.startsWith('-'), `Unknown option ${arg}`);
      paths.push(arg);
    }
  }
  requireCondition(options.feedPath, 'Usage: verify-update-feed.mjs --public-key KEY --feed FILE --version BUILD --short-version VERSION ARCHIVE...');
  const result = verifyUpdateFeed({ ...options, feed: readFileSync(options.feedPath),
    archives: paths.map(name => ({ name, data: readFileSync(name) })) });
  console.log(`Verified signed feed and ${result.verifiedArchives.length} archive(s) for ${result.shortVersion} (${result.version}).`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(`Update verification failed: ${error.message}`); process.exitCode = 1; }
}
