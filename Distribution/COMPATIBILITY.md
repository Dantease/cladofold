# cladofold. compatibility

Version 1.3.0 preview. Hardware research: September 12, 2026.

The universal download contains **arm64 and x86_64** executables for both the app and the System Settings pane. Minimum deployment target is **macOS Sonoma 14.0**. A successful cross-compilation is not a substitute for testing on each processor and OS version.

| MacBook family | Automatic lid animation |
| --- | --- |
| 14-inch MacBook Pro (2021 onward) | Expected, subject to a readable sensor |
| 16-inch MacBook Pro (2019 Intel and 2021 onward Apple silicon) | Expected, subject to a readable sensor |
| 13-inch MacBook Air with M2 or later | Expected, subject to a readable sensor |
| 15-inch MacBook Air | Expected, subject to a readable sensor |
| M1 MacBook Air | Required continuous angle sensor is absent |
| 13-inch MacBook Pro, including M1/M2 Touch Bar | Required continuous angle sensor is absent |
| Most older Intel MacBooks and 12-inch MacBook | Required continuous angle sensor is absent; some also cannot run macOS 14 |

The app detects the actual sensor; it does not restrict access based on a model list. A compatible Apple HID orientation device must return feature report 1 containing a valid 0–180° angle. Hardware being listed with a lid sensor does not guarantee macOS exposes it in this format. Repaired, disabled, inaccessible, or differently implemented sensors can prevent automatic animation.

**Tested here:** Apple M5 Max MacBook Pro (Mac17,6), macOS 26.6.2. Other model families are research-based expectations. We have not measured the percentage of all MacBooks in use that meet these requirements, so cannot claim support for a majority of the installed base.

**Without a sensor:** the miniature preview remains usable. On a MacBook with a built-in display and screen permission, the six-second desktop preview also works. A binary closed/open signal cannot reconstruct a continuous opening angle, and a wake event arrives too late to animate the physical opening while asleep. The app does not pretend these are equivalent substitutes.

## Other requirements

- Metal-capable graphics and an active built-in display. External displays are excluded.
- Screen Recording permission for the full desktop effect. No Accessibility, Input Monitoring, camera or microphone access is needed.
- The desktop must be awake and unlocked. macOS controls the lock screen, sleep and clamshell behavior.
- No Xcode, Homebrew or third-party runtime is needed by recipients. Swift system libraries and Apple frameworks are used.
- Administrator access is only potentially needed to copy the app into system-wide `/Applications`; `~/Applications` works for a per-user installation. The pane installs into that user's `~/Library/PreferencePanes`.

## Evidence

- Apple's [MacBook Air (M2, 2022) repair manual](https://support.apple.com/en-us/100603) includes its lid-angle sensor.
- Apple's [MacBook Pro (14-inch, 2021) repair manual](https://support.apple.com/en-gb/100549) includes its lid-angle sensor.
- The [LidAngleSensor project's model findings](https://github.com/samhenrigold/LidAngleSensor/issues/36) list the 2019 16-inch Pro, redesigned 14/16-inch Pros and M2-and-later Airs; these are community hardware findings, not certification of this app.
- The [sensor project's README](https://github.com/samhenrigold/LidAngleSensor) explicitly identifies M1 Air and M1/M2 Touch Bar Pro as problematic.
- [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager) is available from macOS 14.0. This build guards the later `includeMenuBar` property with a macOS 14.2 availability check.

## Distribution status

The current downloadable DMG and ZIP are **ad-hoc-signed, unnotarized previews**. Apple may block opening them by default. Recipients can follow Apple's [app-specific Open Anyway instructions](https://support.apple.com/102445) if they trust the source and their Mac permits it. No Gatekeeper bypass scripts or quarantine-stripping instructions are included.

An ad-hoc signature identifies only the exact program being signed, without a developer certificate ([Apple's code-signing guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html)). Rebuilt previews can therefore require a fresh Screen Recording permission entry. The app stops automatic checks after a failure so activation and wake cannot keep triggering requests. Stable Developer ID signing across releases and a real upgrade/permission-retention test are still needed before presenting updates as seamless. Notarization does not remove the user's initial Screen Recording consent or macOS-controlled reminders.

For a normal notarized release, install a Developer ID Application certificate and configure a `notarytool` Keychain profile. Run:

```sh
CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-existing-keychain-profile' \
./Scripts/package.sh --notarize
```

This signs nested code before the app with hardened runtime and a secure timestamp, submits the app to Apple, staples and checks its ticket, then notarizes and staples the DMG. Credentials remain in the Keychain. No certificate, private key, token, or profile is included in a download. The notarization path is prepared but has not been executed because no Developer ID identity is available on the build Mac.
