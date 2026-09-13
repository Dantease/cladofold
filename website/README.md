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

Build output is `dist/`. Relative asset URLs support both a GitHub Pages project path and the production domain, [cladofold.app](https://cladofold.app/).

GitHub Pages deploys this directory through the repository's Actions workflow. Cloudflare manages DNS: the apex and `www` are DNS-only CNAME records targeting `dantease.github.io`; Cloudflare flattens the apex record. The repository's Pages custom domain is `cladofold.app`. GitHub provides the HTTPS certificate and redirects `www` to the apex. Actions deployments do not require a `CNAME` file in the build output.

The development build labels the download as being prepared. Set `VITE_RELEASE_READY=true` only when the pinned release asset in `src/main.js` exists. The Pages workflow verifies that asset before enabling the production link.

The Pages environment permits deployment from the publishing branch, not release tags. After publishing a release without a website change, dispatch the workflow from that branch to refresh download availability:

```sh
gh workflow run pages.yml --repo Dantease/cladofold --ref codex/initial-release
```

Website commits on the publishing branch already trigger this deployment. The workflow deliberately has no release-tag deployment trigger, so it respects the existing environment protection rules.

## Interaction

- The entry prompt says “Scroll to open.” With natural trackpad scrolling, an upward finger gesture opens (positive wheel delta); the reverse closes.
- On touchscreens, swipe upward to open and downward to close.
- Arrow Up/Down move the lid, Page Up/Down move farther, Home opens, End closes when focus is outside a control.
- Scroll, touch, buttons, and keyboard navigation share one smooth exponential easing curve across the lid and interior page. The response has a 160 ms time constant, catching up about 95% in 480 ms for a fixed target. This gives a noticeable soft delay rather than tracking each gesture exactly. Reversing a gesture starts from the visible position. Page content reaches its top before closing begins, and the reveal completes before content scrolls. Reduce Motion bypasses the easing.
- The cue is also a button. “Open without animation” goes directly to the downloads.
- Reduced motion follows the system preference and has an explicit toggle. WebGL failure reveals ordinary download controls.
- Once the lid opens, scrolling explores appearance controls, lid-response settings, and the download footer inside the display. A closing gesture folds only after the page reaches its top edge.
- Appearance presets and sliders update a small browser preview; the response switches explain the real native-app settings. They do not change the visitor’s Mac.
- The open display has scroll-driven depth: a slower hero wallpaper, small opposing offsets for feature copy and settings panels, and a soft glass reflection rendered by the existing WebGL display material. Reflections follow page position, with no timer or idle animation. Phone movement is halved; Reduce Motion disables both parallax and the WebGL reflection.
- While open, arrow keys, Page Up/Down, and Space browse the content; Home and End go to its top and footer.

The headline pairs the system sans-serif with a Georgia italic second line. The site loads no analytics, custom fonts, or third-party scripts. GitHub hosts the app downloads. The display snapshot captures only this site’s content; it does not request screen access. Browser events redraw the scene only while it changes; device pixel ratio is capped at 1.5.

The model is CC BY 4.0. Preserve visible credit and `public/MODEL-LICENSE.txt` when sharing it. JavaScript source is MIT-licensed.

## Optional star prompt

Available releases download immediately through a normal file link. A small, dismissible prompt then invites visitors to star the repository; it never blocks the download or moves keyboard focus. The prompt appears once per page visit. The header also has a quiet GitHub star link. Starring is entirely optional, and the site collects no GitHub username, token, or account data.

If the release is unavailable, a short dialog explains that the preview is being prepared and links to the releases page. It does not claim a download started or ask for a star. The release-ready flag remains controlled by the Pages build’s artifact check.
