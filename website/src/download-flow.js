export function downloadState(releaseReady) {
  return releaseReady ? 'ready' : 'preparing';
}

export function setupDownloads(releaseReady, releaseUrl) {
  const unavailableDialog = document.querySelector('#download-unavailable');
  const nudge = document.querySelector('#star-nudge');
  let prompted = false;

  document.querySelectorAll('.download-link').forEach(link => {
    link.href = releaseReady ? releaseUrl : '#download-unavailable';
    if (!releaseReady) link.setAttribute('aria-haspopup', 'dialog');
    link.addEventListener('click', event => {
      if (downloadState(releaseReady) === 'preparing') {
        event.preventDefault();
        document.querySelectorAll('dialog[open]').forEach(open => open.close());
        unavailableDialog.showModal();
        return;
      }

      // Keep the native download link: no star check, extra click, or delay.
      // Modified clicks keep the browser's usual new-tab behavior too.
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      document.querySelectorAll('dialog[open]').forEach(open => open.close());
      if (prompted) return;
      prompted = true;
      nudge.hidden = false;
      nudge.querySelector('[role="status"]').textContent = 'Your download is starting.';
    });
  });

  nudge.querySelector('button').addEventListener('click', () => { nudge.hidden = true; });
  if (!releaseReady) document.querySelector('.release-note').textContent = 'The new preview is being prepared';
}
