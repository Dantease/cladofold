import Foundation

/// The download carries its settings pane; each user gets their own installed copy.
enum PaneInstaller {
    static func install(from source: URL, to destination: URL) throws {
        let files = FileManager.default
        guard Bundle(url: source)?.bundleIdentifier == "com.dante.Foldable.Settings" else {
            throw NSError(domain: "cladofold.", code: 1, userInfo: [NSLocalizedDescriptionKey: "The bundled System Settings pane is missing. Reinstall cladofold."])
        }
        if files.fileExists(atPath: destination.path) {
            guard Bundle(url: destination)?.bundleIdentifier == "com.dante.Foldable.Settings" else {
                throw NSError(domain: "cladofold.", code: 2, userInfo: [NSLocalizedDescriptionKey: "A different settings pane already uses this filename."])
            }
            if equalContents(source, destination) { return }
        }
        let parent = destination.deletingLastPathComponent()
        try files.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".cladofold-\(UUID().uuidString).prefPane")
        let backup = parent.appendingPathComponent(".cladofold-previous-\(UUID().uuidString).prefPane")
        defer { try? files.removeItem(at: staging) }
        try files.copyItem(at: source, to: staging)
        let replacing = files.fileExists(atPath: destination.path)
        if replacing { try files.moveItem(at: destination, to: backup) }
        do {
            try files.moveItem(at: staging, to: destination)
        } catch {
            if replacing { try? files.moveItem(at: backup, to: destination) }
            throw error
        }
        if replacing { try? files.removeItem(at: backup) }
    }

    private static func equalContents(_ lhs: URL, _ rhs: URL) -> Bool {
        let files = FileManager.default
        guard let paths = try? files.subpathsOfDirectory(atPath: lhs.path),
              let otherPaths = try? files.subpathsOfDirectory(atPath: rhs.path),
              Set(paths) == Set(otherPaths) else { return false }
        return paths.allSatisfy { files.contentsEqual(atPath: lhs.appendingPathComponent($0).path, andPath: rhs.appendingPathComponent($0).path) }
    }
}
