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
