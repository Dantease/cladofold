export function setupDownloads(releaseUrl) {
  const nudge = document.querySelector('#star-nudge');
  let prompted = false;

  document.querySelectorAll('.download-link').forEach(link => {
    link.href = releaseUrl;
    link.addEventListener('click', event => {
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
}
