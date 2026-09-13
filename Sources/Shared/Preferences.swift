import AppKit
import Combine

enum CladofoldID {
    static let app = "com.dante.Foldable"
    static let pane = "com.dante.Foldable.Settings"
    static let changed = Notification.Name("com.dante.Foldable.preferencesChanged")
    static let status = Notification.Name("com.dante.Foldable.status")
    static let command = Notification.Name("com.dante.Foldable.command")
    // Preserve the original IDs so upgrading retains the user's preferences.
    static let appName = "cladofold..app"
    static let paneName = "cladofold..prefPane"
    static var appURL: URL? {
        if Bundle.main.bundleIdentifier == app { return Bundle.main.bundleURL }
        var candidates: [URL] = []
        CFPreferencesAppSynchronize(app as CFString)
        if let path = CFPreferencesCopyAppValue("installedApplicationPath" as CFString, app as CFString) as? String {
            candidates.append(URL(fileURLWithPath: path))
        }
        candidates += [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/\(appName)"),
                       URL(fileURLWithPath: "/Applications/\(appName)")]
        return candidates.first { Bundle(url: $0)?.bundleIdentifier == app && Bundle(url: $0)?.executableURL.map { FileManager.default.isExecutableFile(atPath: $0.path) } == true }
    }

    static func rememberApplication() {
        CFPreferencesSetAppValue("installedApplicationPath" as CFString, Bundle.main.bundleURL.path as CFString, app as CFString)
        CFPreferencesAppSynchronize(app as CFString)
    }
    static let paneURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/PreferencePanes/cladofold..prefPane")
}

final class Preferences: NSObject, ObservableObject {
    @Published var settings = BlurSettings() {
        didSet {
            guard !loading else { return }
            var valid = settings
            valid.validate()
            if valid != settings { settings = valid }
            guard let data = try? JSONEncoder().encode(valid) else { return }
            CFPreferencesSetAppValue("configuration" as CFString, data as CFData, CladofoldID.app as CFString)
            CFPreferencesAppSynchronize(CladofoldID.app as CFString)
            DistributedNotificationCenter.default().postNotificationName(CladofoldID.changed, object: sourceID, userInfo: nil, deliverImmediately: true)
        }
    }
    private var loading = false
    private let sourceID = UUID().uuidString

    override init() {
        super.init()
        reload()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(changed(_:)), name: CladofoldID.changed, object: nil)
    }

    @objc private func changed(_ note: Notification) {
        if note.object as? String != sourceID { reload() }
    }

    func reload() {
        CFPreferencesAppSynchronize(CladofoldID.app as CFString)
        guard let data = CFPreferencesCopyAppValue("configuration" as CFString, CladofoldID.app as CFString) as? Data,
              var value = try? JSONDecoder().decode(BlurSettings.self, from: data) else { return }
        value.validate()
        guard value != settings else { return }
        loading = true
        settings = value
        loading = false
    }

    deinit { DistributedNotificationCenter.default().removeObserver(self) }
}

final class RuntimeStatus: NSObject, ObservableObject {
    @Published var angle: Double?
    @Published var openAngle: Double?
    @Published var progress = 0.0
    @Published var permission = false
    @Published var ready = false
    @Published var captureState = CaptureAccess.State.unverified
    @Published var message = "Start cladofold. to connect your lid sensor."
    @Published var running = false
    @Published var previewing = false
    @Published var shortcutAvailable = true
    private var lastUpdate = Date.distantPast
    private var timer: Timer?

    override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(receive(_:)), name: CladofoldID.status, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastUpdate) > 4 { self.running = false; self.ready = false; self.permission = false; self.angle = nil }
        }
    }

    @objc private func receive(_ note: Notification) {
        guard let info = note.userInfo else { return }
        lastUpdate = Date()
        running = true
        angle = info["angle"] as? Double
        openAngle = info["openAngle"] as? Double
        progress = info["progress"] as? Double ?? 0
        permission = info["permission"] as? Bool ?? false
        ready = info["ready"] as? Bool ?? false
        captureState = CaptureAccess.State(rawValue: info["captureState"] as? String ?? "") ?? .unverified
        message = info["message"] as? String ?? "Ready"
        previewing = info["previewing"] as? Bool ?? false
        shortcutAvailable = info["shortcutAvailable"] as? Bool ?? true
    }

    func command(_ command: String) {
        if running {
            DistributedNotificationCenter.default().postNotificationName(CladofoldID.command, object: command, userInfo: nil, deliverImmediately: true)
        } else {
            guard let appURL = CladofoldID.appURL else {
                message = "Install cladofold. in Applications, then open it once."
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = ["--command", command]
            configuration.activates = command != "start"
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
                if let error { DispatchQueue.main.async { self?.message = "Could not open cladofold.: \(error.localizedDescription)" } }
            }
        }
    }

    deinit {
        timer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
