# Third-party notices

## Sparkle updater

The native app embeds [Sparkle 2.10.0](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0), distributed under its permissive license and included third-party licenses. `Scripts/prepare-sparkle.sh` pins the official release archive and SHA-256. The complete upstream license and external notices are bundled at `Contents/Resources/Sparkle-LICENSE.txt`. Sparkle handles signed update checks, downloads, verification, and installation.

## MacBook model — CC BY 4.0

The website includes “macbook pro M3 16 inch 2024” by **jackbaeten**, under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

- [Original model](https://sketchfab.com/3d-models/macbook-pro-m3-16-inch-2024-8e34fc2b303144f78490007d91ff57c4)
- [Author](https://sketchfab.com/jackbaeten)
- [Downloaded copy](https://github.com/adrianhajdin/gsap_macbook_landing/blob/main/public/models/macbook.glb)

We decoded the Draco geometry, separated the base and lid, added an inferred hinge pivot, and named the screen for a custom display material. This asset retains CC BY 4.0; it is not relicensed under MIT. The GLB contains its original source/license metadata. The website exposes attribution in its installation dialog and ships `MODEL-LICENSE.txt`.

## Website dependencies

Three.js, Vite, and [html-to-image](https://github.com/bubkoo/html-to-image) are MIT-licensed. Their distributions and transitive dependencies retain their respective notices in the installed packages; exact versions are recorded in `website/package-lock.json`. The website also ships the bundled Three.js and html-to-image copyright and license text in `website/public/DEPENDENCY-LICENSES.txt`.

## Website wallpaper

`website/public/wallpaper.jpg` is original project artwork depicting abstract pale blue, mint, and periwinkle glass forms. It contains no third-party product artwork and is included under the project’s MIT license. Creation-tool credits are recorded in [ATTRIBUTION.md](ATTRIBUTION.md).

## Animation references

The app is an independent implementation informed by public demonstrations and [lqSky7/iphone-duo-macos-animation](https://github.com/lqSky7/iphone-duo-macos-animation). No source files or assets from that repository are included. The sensor format was informed by [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor).
