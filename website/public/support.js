import { supportMailto } from './support-email.js';

const form = document.querySelector('#support-form');
const status = document.querySelector('#form-status');

form.addEventListener('submit', event => {
  event.preventDefault();
  if (!form.reportValidity()) return;
  const data = new FormData(form);
  const name = String(data.get('name')).trim();
  const email = String(data.get('email')).trim();
  const message = String(data.get('message')).trim();
  status.textContent = 'Email draft requested. If it did not open, email hello@cladoconsult.com directly.';
  window.location.href = supportMailto({ name, email, message });
});
