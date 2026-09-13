# cladofold.

A native MacBook utility that gradually blurs the built-in display as you close the lid, then brings it back into focus as you open it. Includes a menu-bar app and a real **cladofold.** pane in **System Settings**.

## Download and share

Run `./Scripts/package.sh --preview` to generate a universal DMG and ZIP in `dist/`. Give either complete file to another person. They drag **cladofold.** to Applications and open it; no developer tools are needed. The System Settings pane is carried inside the app and installed per user. Both `/Applications` and `~/Applications` are supported; settings controls remember the installed app's location.

**The app name is exactly `cladofold.`**, lowercase with a trailing period. Its on-disk filename is consequently `cladofold..app`. Internal bundle identifiers retain the old name to preserve existing preferences through the upgrade.

Current packages are **unnotarized previews**. This build machine has no Developer ID certificate, so recipients may need Apple's app-specific **Open Anyway** flow. See [recipient instructions](Distribution/READ-ME.txt) and the [compatibility report and notarization workflow](Distribution/COMPATIBILITY.md). Find [preview downloads](https://github.com/Dantease/cladofold/releases), or visit the [interactive website](https://dantease.github.io/cladofold/).

## App icon

The **cf.** mark follows the CladoBook icon: lowercase cream lettering, an acid-lime green square period, and a near-black background. `Resources/Brand/cf-master.png` is the master; `Scripts/MakeIcon.swift` packages it into native macOS sizes with rounded corners and transparent outer margins. The app and preference pane use the same ICNS resource. The menu bar uses a small system-colored `cf.` label for legibility in light and dark appearances.

## Use

1. Open `~/Applications/cladofold..app`.
2. In **System Settings → cladofold.**, choose **Allow…** and enable cladofold. in **Privacy & Security → Screen & System Audio Recording**. If macOS asks you to quit and reopen the app, accept it.
3. Start with your lid at a comfortable working angle. Closing begins the effect from that position. Reopen to the starting angle to clear it.

The top switch toggles the effect. **Duo fold animation** adds a hinge-anchored perspective shift, tapered black side borders that soften with the image, stronger darkening toward the outer edge, and a final fade to black. Opening reverses the same angle-driven transition. **Dark border** adjusts how far the borders reach inward; disable Duo mode to return to the original blur.

**Start when I begin closing** tracks your open position instead of waiting for a fixed threshold. **Finish near** sets the near-closed endpoint (8° by default). **Keep blur until I open the lid back up** holds the effect when you pause; turn it off to clear after half a second of stillness. Turn automatic start off to use the original manual angle thresholds.

Adjust maximum blur, darkening, smoothing, and progressive blur from the hinge. Settings save immediately and synchronize between the app and the System Settings pane. **Duo** selects the new animation with a 48 pt blur and quicker response; **Subtle**, **Balanced**, and **Dreamy** change blur, darkening, and smoothing. Presets preserve your angle thresholds and login preference.

The miniature preview works without screen permission and uses the same renderer as the desktop effect on synthetic content. Drag its angle slider or enable **Follow my lid**. **Preview on my screen** runs a six-second closing/opening animation. **Control–Option–Command–B** immediately disables the effect. You can also disable it or quit from the cf. button in the menu bar.

**Launch at login** uses Apple's ServiceManagement API. Login-item approval, if required by macOS, is managed in **General → Login Items & Extensions**.

## Requirements and behavior

- macOS Sonoma 14.0 or later; universal arm64 + x86_64 app and settings pane.
- A MacBook with a readable Apple lid-angle HID sensor. Expected on 14/16-inch MacBook Pros and M2-or-newer Airs; unavailable on M1 Air and 13-inch Pro models. Verified on this M5 Max MacBook Pro. Use **Check Mac compatibility…** and read the [model matrix](Distribution/COMPATIBILITY.md) for limitations.
- Screen Recording permission for desktop blur. The app does not require Accessibility or Input Monitoring permission.
- Only the built-in display is affected. A desktop frame is captured at the start of each effect and stays frozen during the fold; applications continue running underneath. Screen frames stay in RAM and GPU memory and are released when the effect clears. Nothing is saved or transmitted.
- The app clears its overlay on sensor loss, display changes, sleep, session changes, and screen lock. macOS controls its lock screen; this app does not draw over it. Automatic mode takes a new open-position reference when the unlocked session resumes. It cannot animate a physical opening that happened while the Mac was asleep.
- The overlay ignores mouse input and sits below the system menu bar. A closed lid still sleeps normally. The app does not change power behavior.

## Build and install

Requires Xcode or the Command Line Tools with the macOS SDK; no package downloads.

```sh
./Scripts/test.sh
./Scripts/build.sh
./Scripts/install.sh
open "$HOME/Applications/cladofold..app"
```

Build artifacts are in `build/cladofold..app` and `build/cladofold..prefPane`. The app embeds its pane and installs it for the current user on launch. Installation is per-user in `~/Applications` and `~/Library/PreferencePanes`; no administrator account is required. Quit cladofold. before replacing an installed build. System Settings may need to be quit and reopened after updating its pane. Local builds are ad-hoc signed; after a rebuild macOS may require Screen Recording permission again.

If macOS shows cladofold. enabled but capture is still denied after a rebuild, the permission entry may refer to an older signature. In **Screen & System Audio Recording**, select **cladofold.**, remove just that entry with **−**, then use **+** to add `~/Applications/cladofold..app` again. Enable it and quit/reopen cladofold. when prompted. This refresh affects only cladofold. The app checks access with ScreenCaptureKit as well as CoreGraphics preflight; neither check bypasses macOS permission enforcement.

To check hardware without showing an overlay:

```sh
"$HOME/Applications/cladofold..app/Contents/MacOS/cladofold" --diagnose
```

Development sandboxes can block HID access even when the sensor is present. Run hardware diagnostics outside such a sandbox.

Core Image rendering checks also need normal macOS graphics access. If a development sandbox returns empty rendering buffers, run `build/render-tests` outside that sandbox. The tests render only a generated stripe pattern, never your desktop.

To remove cladofold., turn off Launch at login, quit it, then move `~/Applications/cladofold..app` and `~/Library/PreferencePanes/cladofold..prefPane` to Trash. You can remove its screen permission in Privacy & Security.

## Implementation

- SwiftUI provides shared controls hosted by both AppKit and `NSPreferencePane`.
- CFPreferences plus distributed change notifications synchronize settings between processes.
- IOKit HID feature report 1 supplies the angle on a serial background queue at 30 Hz. Main-thread interpolation runs at 60 Hz; rendering stops when the effect is hidden or stationary.
- ScreenCaptureKit captures a single Retina desktop frame per fold. Display metadata and reusable GPU resources are prepared ahead of time. A tiny transient permission-check frame is also captured when verifying access. Core Image projects it through a hinge-anchored perspective transform onto black, then applies variable-radius hinge blur and spatial shading. Black participates in the blur so margins feather naturally. Metal presents the result.
- A generation guard invalidates asynchronous captures after disabling, sleep, or sensor loss. The six-second preview is bounded, and the keyboard shortcut is registered through Carbon without monitoring keystrokes.

## Reference

The animation approach was informed by [lqSky7/iphone-duo-macos-animation](https://github.com/lqSky7/iphone-duo-macos-animation), inspected at commit `7157979b46c1a46a02cdfb3fdf7d281405a18acf`, and the lid-sensor format documented by [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor). cladofold. is a separate implementation; no source files, assets, private SkyLight code, updater, or build scripts were copied from those projects.

Apple framework references: [Preference Panes](https://developer.apple.com/documentation/preferencepanes), [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit), [Core Image](https://developer.apple.com/documentation/coreimage), and [ServiceManagement](https://developer.apple.com/documentation/servicemanagement).

## Animation research and fidelity

Version 1.1 was compared with the [MacBook demonstration](https://www.youtube.com/watch?v=zos2ZjvgEmc) and the opening/closing segment around 8:12 in [Marques Brownlee’s iPhone Duo hands-on](https://www.youtube.com/watch?v=Od6M0AXpcxQ&t=492s), alongside [Apple’s public product demonstration](https://www.apple.com/iphone-duo/) and the reference shader linked above. The key visual cues are projected content, soft black margins, increasing blur away from the hinge, and spatial darkening. The projection and shading parameters here are an independent visual approximation, not Apple’s private implementation. A MacBook has one display hinged along the bottom; the phone’s transfer between inner and outer displays cannot be reproduced literally on that hardware.

## Website development

```sh
cd website
npm ci
npm test
npm run dev
```

The site uses Three.js and the lid of a licensed articulated MacBook model. Its “Scroll to open” cue leads into a frosted display with soft dark borders. An upward finger gesture opens on a natural-scrolling trackpad or touchscreen; the reverse closes it back to black. Buttons, keyboard controls, reduced motion, and a WebGL fallback keep downloads accessible. See [website development notes](website/README.md).

## Contributing and licenses

The app and website source code are [MIT-licensed](LICENSE). Forks and contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Modified forks are asked to use their own name and icon so users can distinguish them from the official app. See [branding guidance](BRANDING.md).

The website’s MacBook model is **CC BY 4.0**, credited to **jackbaeten**, and retains its own license. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). cladofold. is an independent project and is not affiliated with Apple.
