# Validation — 1.3.0 preview

Build host: Apple silicon MacBook Pro (M5 Max), macOS 26.6.2, Apple Swift 6.3.3.

## Automated checks

- 39 behavior checks: first-degree closing onset, held partial folds, quick partial reopening, immediate full clear and full black, near-closed endpoints, optional clear on stillness, invalid readings, manual mode, lifecycle resets, and preference migration.
- 25 capture recovery and prompt-loop checks: denied access, successful retry, revocation, coalesced checks, cancellation, stale completion after sleep/display changes, separate permission versus display/renderer errors, denied preflight, repeated activation/wake events, persisted retry blocking, and explicit versus automatic rechecks. Total native checks: 102.
- 33 synthetic Core Image rendering checks: progressive blur, dark borders, endpoint fidelity, deterministic reversal, 15 regression cases for unwanted darkening along the top edge, brighter early folds, and the 30-degree black endpoint. These render generated patterns, never the desktop.
- 5 installation checks: fresh install, identical install, update, unrelated pane preservation, and invalid bundle rejection.
- Universal arm64 and x86_64 app and preference-pane compilation; strict local signature verification. GitHub’s macOS runner independently passed the build, behavioral timelines, and installation safeguards.
- The installed 1.3.0 build 9 app, the app extracted from the ZIP, and the app mounted from the read-only DMG have the same executable SHA-256: `de20c93f7ec22a929f0deae270b1f0f6292e26dbabd7b22dc15c405bbc79a654`. Both packaged bundles pass strict signature verification, and the disk image passes checksum verification. The build 9 DMG SHA-256 is `ad78c0c6d2b3c24fda2f8317f01bc60fa0924da35cc37656d298846d7ea50a9e`; ZIP SHA-256 is `8e5a96aca64b5b42eadf735adb561429a8d4207486cfcd9e8cf9c63fec260fe9`.
- App and installed System Settings pane report version 1.3.0, build 9. Saved animation settings are preserved; this Mac's endpoint remains 30° at the owner's request.

## Runtime limits

The installed build 9 completed live desktop rendering on this Mac. The six-second preview reached full effect and cleared, with 221 rendered frames observed during the sampled timeline and a 28.8 ms capture. The owner then confirmed that partial closing, holding, and reopening follow the physical lid and clear correctly. A normal quit/reopen returned directly to Ready with verified screen access and no new permission prompt. The saved full-darkness endpoint remains 30°; that numeric endpoint is covered by automated timelines and rendering tests, not a physical angle calibration.

The September 13 repair found live lid-angle readings but Screen Recording denied despite an enabled System Settings switch. With the owner's approval, only cladofold.'s old permission entry was removed and the installed build was added again. After macOS Quit & Reopen and one explicit Check again, preflight and actual ScreenCaptureKit capture both succeeded. The successful normal restart afterward confirmed access retention for this unchanged build.

Build 9 corrects an overly broad automatic recheck added in build 8: a previous permission request no longer permits capture attempts on activation or wake. Automatic checks require a currently allowed preflight and stop after a failed capture; that stop is persisted across app launches. Only an observed new permission grant or an explicit Check again can retry. Opening Screen Recording settings no longer starts another capture check. Before permission repair, launching the installed build and switching away/back left `captureChecksStarted: 0`, `preflightGranted: false`, a live 118° sensor, and no overlay or system capture request. A later explicit failed check latched automatic requests off as intended.

The effect does not draw on the macOS lock screen or run while asleep. Intel and macOS 14 runtime behavior, a clean installation on a second Mac, and full sleep/wake acceptance remain untested. The signing identity query found no valid code-signing identities. New ad-hoc signatures may require refreshing the app’s Screen Recording permission; a stable Developer ID upgrade path remains a distribution limitation. This preview is not notarized.

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

## Gentle scroll easing — September 13, 2026

The previous direct-scroll behavior has been replaced with one smooth travel controller for both lid opening and interior scrolling. Twenty-five tests pass, including a short settling interval, frame-rate equivalence, immediate reversal from the visible position, transitions at the page top and fully open lid, resize bounds, external scrollbar synchronization, and immediate reduced-motion behavior. The production build passes.

Browser review confirmed the lid follows a scroll gesture before settling, the page and parallax move together, reversing from the page continues into closing, and the compact layout remains usable with reduced motion. The browser reported no WebGL warnings or errors. Perceived trackpad feel remains a user acceptance check.

The follow-up tuning increases the response time constant from 67 ms to 160 ms at the owner's request. A fixed scroll target is about 71% reached after 200 ms and 95% reached after 480 ms, with the same curve for lid and page motion. Frame-rate, reversal, endpoint, and reduced-motion checks remain in place.
