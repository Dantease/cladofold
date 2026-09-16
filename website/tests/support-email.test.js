import { test } from 'node:test';
import assert from 'node:assert/strict';
import { supportMailto } from '../public/support-email.js';

test('support email drafts keep user text inside an encoded mail body', () => {
  const url = new URL(supportMailto({
    name: ' Ana & Zoë ',
    email: 'ana+test@example.com',
    message: 'Could this handle 90°?\nThank you!',
  }));

  assert.equal(url.protocol, 'mailto:');
  assert.equal(url.pathname, 'hello@cladoconsult.com');
  assert.equal(url.searchParams.get('subject'), 'cladofold. support request');
  assert.equal(url.searchParams.get('body'), 'Name: Ana & Zoë\nEmail: ana+test@example.com\n\nMessage:\nCould this handle 90°?\nThank you!');
});
