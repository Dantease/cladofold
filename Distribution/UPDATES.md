# Publishing automatic updates

cladofold. 1.4.0 and later use Sparkle 2.10.0. Earlier installed copies need one manual upgrade; they cannot acquire an updater remotely. Publishing source changes alone does not update installed apps.

The app checks the HTTPS feed at `https://cladofold.app/appcast.xml` about once per day while running. Automatic checking and downloading are on by default, with an opt-out in the cf. menu. Verified updates install on quit; users can choose Check for Updates to install sooner. No update forces a restart during an active fold. A user may need macOS authorization if the app's location is not writable.

## Signing and keys

The app requires signed feeds and verifies archive signatures before extraction. Both use the public Ed25519 key embedded in `Resources/App-Info.plist`. The matching private key is stored only in the release Mac's Keychain account `com.dante.Foldable.sparkle`. The Developer ID identity and Apple notarytool profile are also local prerequisites. Do not commit or upload private signing keys. Preserve the signing Keychain when moving release machines.

Retrieve only the existing public key with:

```sh
./Scripts/prepare-sparkle.sh
build/Dependencies/Sparkle-2.10.0/bin/generate_keys --account com.dante.Foldable.sparkle -p
```

The framework download is pinned by version and SHA-256 in `Scripts/prepare-sparkle.sh`. Its nested helpers are signed before the framework and app. Do not edit a signed feed manually; regenerate it after changes. Do not rotate the app's Apple signing identity and update key together.

## Release sequence

1. Increase `CFBundleVersion` in both app and pane plists for every released binary, and set their matching marketing version. Update the guide, repository and website download pins, displayed version, and Pages download check. Keep the existing public release working until its replacement is verified.
2. Run `./Scripts/test.sh`, the updater tests, and `npm test && npm run build` in `website/`. Build and review the release sources.
3. Package using the existing Developer ID identity and notarytool Keychain profile:

   ```sh
   CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
   NOTARY_PROFILE='your-existing-keychain-profile' \
   ./Scripts/package.sh --notarize
   ```

   Packaging notarizes and staples the app and DMG, creates the ZIP and checksum manifest, then automatically signs the final DMG and generates `website/public/appcast.xml`. It retains previous feed entries. `--preview` builds are local ad-hoc artifacts and never update the public feed. The feed generator currently uses `v<VERSION>-preview` GitHub release tags, matching the public release channel.
4. Optionally add plain-text release notes and regenerate signatures with `./Scripts/generate-update-feed.sh path/to/notes.txt`. Verify using `./Scripts/check-update-feed.sh dist/cladofold.-<VERSION>-universal-notarized.dmg`. Confirm extracted app/pane versions, signatures, Gatekeeper acceptance and both CPU architectures. Validate the update path using an isolated older updater-enabled copy.
5. Commit and push the tested native sources first, retaining the website/feed changes locally. Wait for Mac CI. Create a GitHub release targeting that exact commit, upload the DMG, ZIP and SHA-256 manifest, compare uploaded hashes, and publish the release. Existing assets and tags remain available for rollback.
6. Only after the new public download resolves, commit and push the website/feed/download changes. GitHub Pages checks the feed signature and the downloaded DMG before deploying. Wait for deployment success and verify the live feed, all download links and downloaded hashes.

Releases use increasing bundle versions; reverting source changes requires a new higher-version release. Do not silently replace an already signed archive at an existing feed URL. To halt an unshipped update, retain the prior verified feed and download links while preparing a corrected release.

## Verification scope

`node --test Tests/Updates/feed.test.mjs` exercises public-key-only signature verification, tamper rejection and feed metadata. Set `SPARKLE_SIGN_UPDATE` to the distribution's `bin/sign_update` when running locally to include official-tool interoperability. The publication checker does not require the private key or network access. Sparkle itself performs update verification and installation in the app; the extra checker catches publishing mistakes.
