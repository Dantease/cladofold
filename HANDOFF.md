# cladofold. handoff — September 13, 2026

## Continue from this workspace

- Repository: https://github.com/Dantease/cladofold
- Working folder: `/Users/dante/Documents/ChatGPT/foldable`
- Branch: `codex/initial-release`
- Latest native work: build 13, open-angle hysteresis and optional Vacuum reveal; inspect `git log -3` for its commit. Earlier calibration and live appearance preview landed in `bd3f12b`.
- Website: https://cladofold.app

Open this folder as a local Codex project after signing into the new ChatGPT account. The repository and local workspace are the source of truth; a conversation export is useful only as additional history.

## Current native app state

- Installed app: `/Users/dante/Applications/cladofold..app`
- Installed version: 1.3.1, build 13
- Installed System Settings pane: `~/Library/PreferencePanes/cladofold..prefPane`
- Screen Recording: verified after adding the current installed build back in System Settings.
- The installed 1.3.1 preview packages are in `dist/`; they have not been published as the public download.
- Public GitHub release and website download remain on 1.3.0 build 9 pending physical approval of the current motion.

The app name is always `cladofold.` in product copy: lowercase, trailing period. Its `cf.` icon has a green period.

## What works and has been verified

- The fold effect starts 3° below the calibrated working angle and clears within 1°, reaches black at 30 degrees, and uses the Duo-style blur, dark border, and dimming presentation. The reference stays fixed through minor jitter.
- Optional **Vacuum reveal** defaults off. Turning it on demonstrates the bottom-up reveal in the miniature; Replay repeats it. The switch persists, and turning it off restores the prior renderer.
- The miniature lid preview updates in real time while blur strength, darkening, border depth, Duo mode, progressive blur, or presets are changed. When the preview is fully clear or fully black, an appearance adjustment temporarily uses a 55% folded sample so the result is visible.
- Selecting **Follow my lid** now calibrates the current lid angle as the clear position. **Use current angle as open** can recalibrate it later.
- A partial close and hold keeps its reference; reopening to the calibrated angle clears without requiring the lid to open farther.
- The installed six-second desktop preview captured and cleared normally. Screen access remains verified after a normal quit/reopen.
- 149 local native checks passed for build 13. GitHub Actions run `34792392467` passed the previous build 12; check the latest branch run for build 13.

Read [VALIDATION.md](VALIDATION.md) for hashes, package verification, performance observations, and limitations.

## Physical acceptance still needed

The owner reports a brief visual glitch when reopening with **Follow my lid** selected. Near the normal open angle, the overlay appears to momentarily recalculate or flicker before clearing. The rest of the motion is accepted.

Build 13 addresses sensor jitter with a 3° closing / 1° clear hysteresis and a reference that does not drift within the buffer. Synthetic jitter sequences pass, and native preview/desktop tests pass. The owner still needs to test whether this resolves the reported physical glitch. Do not automatically redo or revert these changes. The newly requested optional Vacuum reveal is also installed and ready for review.

Reproduce it with the desktop effect enabled, Follow my lid selected, and a calibrated working angle. Close partway, then reopen steadily to that angle. Investigate the final transition to clear. Preserve these requirements:

- Do not reintroduce the prior problem where reopening requires opening past the calibrated angle.
- Keep the 30-degree full-dark endpoint.
- Keep real-time settings preview updates.
- Preserve the 120 Hz display-link scheduling and symmetric smoothing from build 11.
- Do not change or bypass macOS privacy permissions. Ad-hoc rebuilds can require refreshing only cladofold.'s Screen Recording entry.

The relevant native files are:

- `Sources/Shared/BlurModel.swift` — lid angle target and smoothing math
- `Sources/App/AppDelegate.swift` — sensor updates, calibration command, display-link rendering
- `Sources/Shared/SettingsView.swift` — Follow my lid and live preview UI
- `Tests/main.swift` — motion behavior tests
- `Tests/Rendering/main.swift` — miniature preview rendering tests

## User preferences and product decisions

- Native effect: inspired by the iPhone Duo fold appearance, but do not claim a one-to-one reproduction of Apple's private implementation.
- Last observed personal settings: about 77.9 pt blur, 412 ms smoothing, 30-degree endpoint, Duo animation on, progressive blur on, darkening about 55.5%, dark border about 106.6%, launch at login on. Read fresh values before any update. Effect and Vacuum reveal switches were left off after testing.
- The site opens the lid as a user scrolls up and closes it as they scroll down. It has a light smooth delay, WebGL reflections, and parallax. Keep its website animation separate from native app motion work unless a website request is made.
- GitHub repo: `Dantease/cladofold`, MIT license. Forks should use their own name and icon.
- The website has immediate downloads plus an optional, non-blocking star prompt and header star control.
- Cloudflare DNS routes `cladofold.app` and `www.cladofold.app` to GitHub Pages.
- The public app is an unnotarized preview until a Developer ID certificate and notarization are available. Do not describe it as notarized.

## Useful commands

Run these from `/Users/dante/Documents/ChatGPT/foldable`:

```sh
./Scripts/test.sh
./Scripts/build.sh
./Scripts/package.sh --preview
```

`Scripts/package.sh --preview` rebuilds the app, so run it only after source changes are complete. Before installing a rebuild, back up the current cladofold. app and saved preferences. `Scripts/install.sh` installs only cladofold.-owned bundles, but the running app must be quit first.

Keep `planning/` private and do not publish it. Do not use broad git staging or destructive git commands. Do not publish a new public release or point the website download at a new build until the owner accepts the physical lid behavior.

## Ready-to-paste first message in the new account

```text
Continue the cladofold. project in /Users/dante/Documents/ChatGPT/foldable. Read HANDOFF.md and VALIDATION.md first. Build 13 adds open-angle hysteresis for the reopening glitch and an optional Vacuum reveal switch with animated miniature preview. Review my physical test results before changing it further. Preserve the 30-degree endpoint, calibration, live preview updates, and desktop display-link scheduling. Do not publish a new release until I approve the physical lid behavior.
```
