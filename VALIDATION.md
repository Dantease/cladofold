# Validation — 1.3.0 preview

Build host: Apple silicon MacBook Pro (M5 Max), macOS 26.6.2, Apple Swift 6.3.3.

## Automated checks

- 38 behavior checks: first-degree closing onset, held partial folds, quick partial reopening, immediate full clear, near-closed endpoints, optional clear on stillness, invalid readings, manual mode, lifecycle resets, and preference migration.
- 30 synthetic Core Image rendering checks: progressive blur, dark borders, endpoint fidelity, deterministic reversal, and 15 regression cases for unwanted darkening along the top edge. These render generated patterns, never the desktop.
- 5 installation checks: fresh install, identical install, update, unrelated pane preservation, and invalid bundle rejection.
- Universal arm64 and x86_64 app and preference-pane compilation; strict local signature verification.

## Runtime limits

Earlier previews completed live desktop rendering on this Mac. The 1.3.0 build still needs its own installed-app capture and physical-lid acceptance checks. Automated timelines cannot establish perceived latency on real hardware. Apple silicon and Intel slices are compiled, but Intel and macOS 14 runtime behavior have not been physically tested.

The effect does not draw on the macOS lock screen or run while asleep. New ad-hoc signatures may require refreshing the app’s Screen Recording permission. This preview is not notarized.

## Website

The black entry, upward opening, downward closing, projected display blur, open-screen alignment, download controls, and dialogs were reviewed in a browser at desktop and phone widths (390 and 320 pixels). The compact layout allows content scrolling before closing when its interior overflows. Real iPhone touch and mobile GPU performance remain device-testing items.
