# Validation — 1.3.1 preview candidate

Build host: Apple silicon MacBook Pro (M5 Max), macOS 26.6.2, Apple Swift 6.3.3.

## Automated checks

- 48 behavior checks: first-degree closing onset, held partial folds, immediate full clear and full black, near-closed endpoints, optional clear on stillness, invalid readings, manual mode, lifecycle resets, preference migration, and whole-degree interpolation at 60/120 Hz. Reversal starts on the next frame, both directions use the same response, and maximum smoothing has a bounded settling time.
- 25 capture recovery and prompt-loop checks: denied access, successful retry, revocation, coalesced checks, cancellation, stale completion after sleep/display changes, separate permission versus display/renderer errors, denied preflight, repeated activation/wake events, persisted retry blocking, and explicit versus automatic rechecks. Total native checks: 110.
- 32 synthetic Core Image rendering checks: progressive blur, dark borders, endpoint fidelity, deterministic reversal, 15 regression cases for unwanted darkening along the top edge, and the 30-degree black endpoint. The brighter-early-fold assertion was removed because that visual change is explicitly being rolled back; the earlier mid-fold shading assertion was restored. These render generated patterns, never the desktop.
- 5 installation checks: fresh install, identical install, update, unrelated pane preservation, and invalid bundle rejection.
- Universal arm64 and x86_64 app and preference-pane compilation; strict local signature verification. GitHub’s macOS runner independently passed the motion tests, permission-recovery tests, universal app/pane build, and installation safeguards for build 11 ([run 34790907659](https://github.com/Dantease/cladofold/actions/runs/34790907659)).
- The installed 1.3.1 build 11 app, the app extracted from the ZIP, and the app mounted from the read-only DMG have the same executable SHA-256: `effa3f9097a5a9324087b4304986435321a4c3ffaf114d7331fe58fdae7bdbe5`. Both packaged bundles pass strict signature verification, and the disk image passes checksum verification. The build 11 DMG SHA-256 is `b3f0dcfbbec6c9495d0e761d0d2ee564ab4be7c7e46ac3616f18406ddc2738fc`; ZIP SHA-256 is `93a92a49c4e0c2ee4926c642329b7019c85bfed7b32454b9524bdd34481e4397`.
- App and installed System Settings pane report version 1.3.1, build 11. The previous app and preferences were backed up before installation. Saved animation configuration was verified byte-for-byte unchanged afterward. The endpoint remains 30° and the smoothing setting remains 120 ms.

## Continuous desktop motion — September 13, 2026

The owner rejected build 10's stepping on the actual desktop (not the miniature settings preview) and requested the smoothness of the iPhone Duo transition. Apple's [interactive fold reference](https://www.apple.com/iphone-duo/) was reviewed at partial and full opening, alongside the [Mac reference project's rendering approach](https://github.com/lqSky7/iphone-duo-macos-animation). These provide a visual target, not Apple's internal timing specification; no exact device-to-device equivalence has been established or claimed.

A generated-pattern benchmark at this Mac's 3456×2234 resolution measured the unchanged Core Image renderer at 4.05 ms median / 5.00 ms p95 CPU encoding and 1.67 ms median / 2.12 ms p95 GPU execution. This did not justify replacing the visual renderer. Build 11 instead replaces the unsynchronized 60 Hz timer with the built-in display's CADisplayLink (up to 120 Hz), increases off-main-thread sensor polling from 30 to 60 Hz, and keeps rendering asleep when the fold is clear or settled. The smoothing response is symmetric: the existing 120 ms setting now uses a 60 ms exponential time constant in both directions. The old 25 ms reopening limit and coarse intermediate-frame threshold exposed whole-degree steps. The frame threshold is now 100 times finer. Full clear and full black remain immediate at their physical endpoints; the restored shading/projection filters are unchanged.

The installed six-second preview reached full effect and cleared with no render error. Initial capture took 31.2 ms. During the final moving two-second window, the display callback cadence averaged 118.9 Hz, with p95 interval 8.65 ms and maximum 16.1 ms; earlier warm-up sampling started at 107.4 Hz. The sampled timeline observed 414 completed rendered frames. Callback timing is not an end-to-end display-presentation benchmark, and this single Mac does not establish performance on every supported model. Physical slow-fold acceptance remains pending.

Only cladofold.'s existing screen-access entry was refreshed for the rebuilt ad-hoc app under the owner's prior authorization. Capture verified successfully, and a subsequent normal quit/relaunch returned directly to Ready without a new prompt. The public download remains 1.3.0 build 9 pending physical acceptance of this candidate.

## Approved animation rollback — September 13, 2026

The owner reported that the updated appearance was worse and lagged, and approved restoring build 6's animation while retaining the 30-degree endpoint and capture-permission fixes. `BlurFilter.swift` and `BlurOverlay.swift` exactly match `e720993^`; the app's render call again submits each changed frame directly. This restores the prior edge shading and final fade and removes the single-frame-in-flight gate. The capture state machine, persistent retry suppression, immediate clear/full-black endpoints, saved controls, and website easing remain intact. The scheduling change has not been established as the cause of the reported lag.

The installed build 10 completed its six-second desktop preview, reached progress 1, and returned to progress 0 with the overlay hidden and no rendering error. The sampled timeline observed 213 completed frames and a 28.8 ms initial capture; these are functional observations, not a frame-rate benchmark. Screen access required refreshing only cladofold.'s existing permission entry for the rebuilt ad-hoc app. After Quit & Reopen and one explicit Check again, real capture succeeded. A subsequent normal quit/relaunch returned directly to Ready with verified access and no permission prompt.

The owner subsequently reported stepwise desktop motion on build 10. The build 11 follow-up above supersedes that candidate. Version 1.3.1 has not been published; the public release and website download remain on 1.3.0 build 9 pending physical acceptance.

## Runtime limits

Before the rollback, build 9 completed live desktop rendering on this Mac. The six-second preview reached full effect and cleared, with 221 rendered frames observed during the sampled timeline and a 28.8 ms capture. The owner initially confirmed that partial closing, holding, and reopening follow the physical lid and clear correctly, then reported dissatisfaction with its appearance and lag and requested the rollback above. A normal quit/reopen retained verified screen access. The saved full-darkness endpoint remains 30°; that numeric endpoint is covered by automated timelines and rendering tests, not a physical angle calibration.

The September 13 repair found live lid-angle readings but Screen Recording denied despite an enabled System Settings switch. With the owner's approval, only cladofold.'s old permission entry was removed and the installed build was added again. After macOS Quit & Reopen and one explicit Check again, preflight and actual ScreenCaptureKit capture both succeeded. The successful normal restart afterward confirmed access retention for this unchanged build.

Build 9 corrects an overly broad automatic recheck added in build 8: a previous permission request no longer permits capture attempts on activation or wake. Automatic checks require a currently allowed preflight and stop after a failed capture; that stop is persisted across app launches. Only an observed new permission grant or an explicit Check again can retry. Opening Screen Recording settings no longer starts another capture check. Before permission repair, launching the installed build and switching away/back left `captureChecksStarted: 0`, `preflightGranted: false`, a live 118° sensor, and no overlay or system capture request. A later explicit failed check latched automatic requests off as intended.

The effect does not draw on the macOS lock screen or run while asleep. Intel and macOS 14 runtime behavior, a clean installation on a second Mac, and full sleep/wake acceptance remain untested. The signing identity query found no valid code-signing identities. New ad-hoc signatures may require refreshing the app’s Screen Recording permission; a stable Developer ID upgrade path remains a distribution limitation. This preview is not notarized.

## Website

The black entry, upward opening, downward closing, projected display blur, open-screen alignment, download controls, and dialogs were reviewed in a browser at desktop and phone widths (390 and 320 pixels). The compact layout allows content scrolling before closing when its interior overflows. Real iPhone touch and mobile GPU performance remain device-testing items.

Twenty-five website tests pass. The published v1.3.0-preview contains the verified build 9 DMG, ZIP, and checksum manifest; GitHub's asset digests match the local packages. The production website at cladofold.app points to that release. A real browser click on Download for Mac emitted a download event immediately and then showed the optional, dismissible star suggestion without moving focus. The live page reported no console warnings or errors.

The release-tag deployment was rejected by GitHub Pages' existing environment protection rules. The website was then deployed successfully from its permitted publishing branch (run 34789100377). The workflow no longer tries to deploy release tags; the website README documents how to dispatch a refresh from the publishing branch after future releases.

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
