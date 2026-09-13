export function downloadState(releaseReady, starConfirmed) {
  if (!releaseReady) return 'preparing';
  return starConfirmed ? 'ready' : 'needs-star';
}

export function setupDownloads(releaseReady, releaseUrl) {
  const dialog = document.querySelector('#star-download');
  const confirmation = document.querySelector('#star-confirmed');
  const button = document.querySelector('#continue-download');
  const status = document.querySelector('#download-status');
  // An honest self-confirmation step, not a GitHub authentication check.
  // Keep this choice only for this page visit; collect no account information.
  let confirmed = false;
  function update() {
    const state = downloadState(releaseReady, confirmed);
    button.disabled = state !== 'ready';
    if (state === 'preparing') {
      dialog.querySelector('.star-confirmation').hidden = true;
      document.querySelector('#star-description').textContent = 'The next preview is being prepared. In the meantime, a star helps more people find cladofold.';
      button.textContent = 'Preview coming soon';
      status.textContent = 'Downloads will open here when the preview is ready.';
    } else {
      status.textContent = confirmed ? 'Thanks for supporting cladofold.' : 'Already starred? Confirm above to continue.';
    }
  }
  document.querySelectorAll('.download-link').forEach(link => {
    link.href = '#star-download';
    link.setAttribute('aria-haspopup', 'dialog');
    link.addEventListener('click', event => {
      event.preventDefault();
      document.querySelectorAll('dialog[open]').forEach(open => open.close());
      update();
      dialog.showModal();
    });
  });
  confirmation.addEventListener('change', () => { confirmed = confirmation.checked; update(); });
  button.addEventListener('click', () => {
    if (downloadState(releaseReady, confirmed) !== 'ready') return;
    // Opening the repository does not itself add a star. The visitor explicitly
    // confirms that action on GitHub before this link is available.
    window.location.assign(releaseUrl);
    dialog.close();
  });
  if (!releaseReady) document.querySelector('.release-note').textContent = 'The new preview is being prepared';
  update();
}
