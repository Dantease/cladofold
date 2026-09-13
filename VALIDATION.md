# Validation — 1.3.0 preview

Build host: Apple silicon MacBook Pro (M5 Max), macOS 26.6.2, Apple Swift 6.3.3.

## Automated checks

- 38 behavior checks: first-degree closing onset, held partial folds, quick partial reopening, immediate full clear, near-closed endpoints, optional clear on stillness, invalid readings, manual mode, lifecycle resets, and preference migration.
- 30 synthetic Core Image rendering checks: progressive blur, dark borders, endpoint fidelity, deterministic reversal, and 15 regression cases for unwanted darkening along the top edge. These render generated patterns, never the desktop.
- 5 installation checks: fresh install, identical install, update, unrelated pane preservation, and invalid bundle rejection.
- Universal arm64 and x86_64 app and preference-pane compilation; strict local signature verification. GitHub’s macOS runner independently passed the build, behavioral timelines, and installation safeguards.
- The installed app, extracted ZIP, and mounted read-only DMG have the same executable SHA-256: `4b79bbe8b88b632cbb79193fa23aa9bb41d8bbb815b520db3a296a24d4dbead3`. Both package checksums pass.
- App and installed System Settings pane report version 1.3.0. Saved animation settings match the pre-update export; new controls migrate without discarding the existing configuration.

## Runtime limits

Earlier previews completed live desktop rendering on this Mac. The 1.3.0 build still needs its own installed-app capture and physical-lid acceptance checks. Automated timelines cannot establish perceived latency on real hardware. Apple silicon and Intel slices are compiled, but Intel and macOS 14 runtime behavior have not been physically tested.

The effect does not draw on the macOS lock screen or run while asleep. New ad-hoc signatures may require refreshing the app’s Screen Recording permission. This preview is not notarized.

## Website

The black entry, upward opening, downward closing, projected display blur, open-screen alignment, download controls, and dialogs were reviewed in a browser at desktop and phone widths (390 and 320 pixels). The compact layout allows content scrolling before closing when its interior overflows. Real iPhone touch and mobile GPU performance remain device-testing items.

Seven website motion tests pass. Keyboard Home/End, the reduced-motion toggle, modal dismissal, and public subpath asset loading were checked in the browser without console warnings or errors. The public GitHub Pages deployment succeeded. The new download remains gated until its draft release is published after the live app check.

## Website lid-only redesign — September 13, 2026

Eight website tests pass, covering the corrected natural-trackpad/touch gesture directions, delta units, endpoints, frame-rate independence, and a lid angle that keeps the screen readable through the main blur transition. The production build passes.

Browser review covered the lid without the base or keyboard, continuous frosted text and soft dark borders at partial opening, the live HTML handoff, and return to the black entry. Scrolling over the opening cue now starts the reveal. Desktop (1440×900), phone (390×844), and compact phone (320×568) layouts were checked. Compact content scrolls to the footer while the lid remains open; dialogs and reduced-motion controls work. The final local browser session reported no warnings or errors. Real-device touch and GPU performance remain untested.

This change affects the website only; the native 1.3.0 runtime acceptance limits above still apply.

## Website framing and direct scrolling follow-up — September 13, 2026

Eleven website motion tests pass. New regression cases cover coalescing several gesture events into one exact frame update, holding the angle when input ends, direct touch response across frame rates, and reversing an unfinished button animation from its current visible angle. Input handlers no longer render the old angle before scheduling the next frame or restart the animation clock on every event.

Browser checks confirmed the tighter open frame at 1440×900, 855×998, 390×844, and 320×568. A partial opening held at 9% without a trailing change; a later closing gesture reached 50% and held there. The progressive blur still renders during the fold, closing returns to black, compact content can scroll to its footer, and reduced-motion open/close controls reach their endpoints. The final local browser checks reported no console warnings or errors. This verifies browser event handling; physical trackpad feel remains a user acceptance check.

## Website typography, features, and download flow — September 13, 2026

Eighteen tests pass. New cases cover switching from lid movement to interior page scrolling, consuming only the remaining gesture beyond the page top when closing, keeping the lid open at the footer, requiring explicit star confirmation for an available release, and preventing confirmation from exposing a draft download.

Browser review covered the looser headline and italic serif pairing, appearance presets and range inputs, response switches, mobile feature sections, footer download routing, and the unavailable-release dialog. The star step is self-confirmed; authenticated GitHub star verification is not implemented. The native app’s release remains gated by the runtime acceptance checks above.

## Optional star prompt and custom domain — September 13, 2026

The star-confirmation requirement above has been removed. Eighteen website tests and the production build pass. Available release links use normal browser downloads immediately; the optional star prompt is nonmodal, keeps focus on the clicked link, and appears only once per page visit. Browser checks used the real download module with a harmless local test file to exercise the available-release path at desktop and 390-pixel phone widths. Dismissal prevented the prompt from returning on another download click. The unpublished-release path showed preparation information without a star request. The temporary test fixture was removed before publication.

Cloudflare DNS routes `cladofold.app` and `www.cladofold.app` to GitHub Pages. GitHub's DNS check succeeded, the certificate includes both hostnames, and HTTPS enforcement is enabled. The apex returned HTTP 200 over valid HTTPS. The native app's remaining runtime acceptance checks are unchanged.

## WebGL reflections and scroll parallax — September 13, 2026

Twenty-one website tests pass, including direct and reversible depth offsets, bounded movement for offscreen sections, smaller phone movement, and neutral values for reduced motion. The production build passes. The new reflection uses the existing WebGL context and display mesh, with scroll-position uniforms and no continuous animation loop.

Browser review covered the feature panels and glass reflection at desktop and 390×844 phone sizes, no WebGL warnings or errors, a neutral transform after enabling Reduce Motion, and a zero wallpaper offset after returning to the hero. Closing after a phone resize returned to the black entry. Live MacBook and physical-phone acceptance limits remain as described above.
