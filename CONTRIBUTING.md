# Contributing

Fork the repository and open a pull request with the problem, resulting behavior, and relevant validation. The Mac app is in `Sources/`; the website is in `website/`.

For motion changes, run `./Scripts/test.sh` on macOS with normal graphics access, then `./Scripts/build.sh`. Tests render synthetic patterns. Check partial close/hold/reopen, near-close behavior, disable during capture, and sleep/lock cleanup on real hardware before proposing a binary release. Record your Mac model, macOS version, and whether Screen Recording was granted; do not share desktop captures containing private information.

For website changes, run `npm ci`, `npm test`, and `npm run build` inside `website/`. Check both directions, touch/keyboard alternatives, reduced motion, dialogs, and narrow/short viewports. Keep Download and Star controls accessible.

The code is MIT-licensed. Contributions should be your own work or have a compatible license with preserved notices. See `THIRD_PARTY_NOTICES.md` before changing assets and `BRANDING.md` before distributing a modified fork.

Please do not commit signing keys, credentials, user preferences, logs, app bundles, disk images, or node_modules. Releases carry built binaries as GitHub assets.
