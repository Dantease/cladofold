export function supportMailto({ name, email, message }) {
  const subject = 'cladofold. support request';
  const body = `Name: ${name.trim()}\nEmail: ${email.trim()}\n\nMessage:\n${message.trim()}`;
  return `mailto:hello@cladoconsult.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}
