import { toCanvas } from 'html-to-image';

// Snapshot only this site's own content. This does not access the visitor's
// desktop, other tabs, or any browser screen-capture API.
export async function screenContent(interior, bounds, wallpaper) {
  const rect = interior.getBoundingClientRect();
  const clone = interior.cloneNode(true);
  clone.querySelectorAll('[id]').forEach(node => node.removeAttribute('id'));
  clone.removeAttribute('id');
  clone.classList.add('ready');
  clone.inert = true;
  clone.setAttribute('aria-hidden', 'true');
  const staging = document.createElement('div');
  Object.assign(staging.style, { position: 'fixed', left: '-20000px', top: '0', pointerEvents: 'none' });
  Object.assign(clone.style, {
    position: 'relative', left: '0', top: '0', width: `${rect.width}px`, height: `${rect.height}px`,
    visibility: 'visible', opacity: '1', pointerEvents: 'none',
  });
  for (const child of clone.children) child.style.transform = `translateY(${-interior.scrollTop}px)`;
  staging.appendChild(clone);
  document.body.appendChild(staging);
  try {
    const content = await toCanvas(clone, {
      width: rect.width, height: rect.height, pixelRatio: Math.min(devicePixelRatio,1.5),
      skipFonts: true,
      style: { position: 'relative', left: '0', top: '0', margin: '0', visibility: 'visible', opacity: '1', transform: 'none' },
    });
    const canvas = document.createElement('canvas');
    canvas.width = 1536; canvas.height = Math.round(1536*bounds.height/bounds.width);
    const context = canvas.getContext('2d');
    context.drawImage(wallpaper,0,0,canvas.width,canvas.height);
    context.fillStyle = 'rgba(8,17,30,.28)'; context.fillRect(0,0,canvas.width,canvas.height);
    const ratio = canvas.width / bounds.width;
    context.drawImage(content, (rect.left-bounds.left)*ratio, (rect.top-bounds.top)*ratio, rect.width*ratio, rect.height*ratio);
    return canvas;
  } finally { staging.remove(); }
}
