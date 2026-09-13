# cladofold. website

A Vite / Three.js static site. The articulated model and its notices are in `public/`. The MacBook is a real glTF mesh, with the website rendered onto its display during motion and accessible HTML controls at the open endpoint.

## Develop

Use Node.js 22.12 or newer (Node 24 LTS recommended).

```sh
npm ci
npm test
npm run dev
npm run build
```

Build output is `dist/`. Relative asset URLs support a GitHub Pages project path or a later custom domain. No domain purchase or DNS configuration is part of this build.

The development build labels the download as being prepared. Set `VITE_RELEASE_READY=true` only when the pinned release asset in `src/main.js` exists. The Pages workflow verifies that asset before enabling the production link.

## Interaction

- Scroll toward the page top to open; toward the bottom to close.
- On touchscreens, pull a finger down to open and up to close. This preserves page-direction semantics.
- Arrow Up/Down move the lid, Page Up/Down move farther, Home opens, End closes when focus is outside a control.
- The cue is also a button. “Open without animation” goes directly to the downloads.
- Reduced motion follows the system preference and has an explicit toggle. WebGL failure reveals ordinary download controls.
- Short screens allow the content inside the display to scroll before closing at its bottom edge.

The site loads no analytics, custom fonts, or third-party scripts. GitHub hosts the app downloads. Browser events redraw the scene only while it changes; device pixel ratio is capped at 1.5.

The model is CC BY 4.0. Preserve visible credit and `public/MODEL-LICENSE.txt` when sharing it. JavaScript source is MIT-licensed.
