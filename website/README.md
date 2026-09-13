# cladofold. website

A Vite / Three.js static site. The articulated model and its notices are in `public/`. Only the lid of the real glTF MacBook mesh is visible. The site snapshots its own HTML into a display texture, projects it onto black, and applies a continuous progressive blur during motion. The same HTML becomes interactive at the open endpoint, with the model bezel and notch above it. The lid width adapts to the viewport, leaving a 10 px outer margin on desktop or 6 px on compact screens. The controls occupy a separate 40 px strip below the frame.

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

- The entry prompt says “Scroll to open.” With natural trackpad scrolling, an upward finger gesture opens (positive wheel delta); the reverse closes.
- On touchscreens, swipe upward to open and downward to close.
- Arrow Up/Down move the lid, Page Up/Down move farther, Home opens, End closes when focus is outside a control.
- Scroll and touch events update the lid directly on the next animation frame. The browser’s own momentum events are preserved; the site adds no trailing easing. Button and keyboard actions retain a short animation, which a new gesture interrupts from the visible angle.
- The cue is also a button. “Open without animation” goes directly to the downloads.
- Reduced motion follows the system preference and has an explicit toggle. WebGL failure reveals ordinary download controls.
- Short screens allow the content inside the display to scroll while the lid stays open; a closing gesture folds after the content reaches its top edge.

The site loads no analytics, custom fonts, or third-party scripts. GitHub hosts the app downloads. The display snapshot captures only this site’s content; it does not request screen access. Browser events redraw the scene only while it changes; device pixel ratio is capped at 1.5.

The model is CC BY 4.0. Preserve visible credit and `public/MODEL-LICENSE.txt` when sharing it. JavaScript source is MIT-licensed.
