import AppKit

private final class BrandBundleLocator: NSObject {}

enum BrandArtwork {
    // In System Settings, Bundle.main is the host; locate our pane's own resources.
    static let icon: NSImage = {
        let bundle = Bundle(for: BrandBundleLocator.self)
        guard let url = bundle.url(forResource: "cladofold-cf", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return NSImage(size: NSSize(width: 60, height: 60)) }
        return image
    }()
}
