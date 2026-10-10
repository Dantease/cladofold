import AppKit
import Sparkle

/// Sparkle owns scheduling, downloads, verification and installation on quit.
/// Nothing here runs on the lid-animation clock or changes preferences at launch.
@MainActor final class AppUpdater: NSObject, NSMenuItemValidation, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private let canInteract: () -> Bool
    private lazy var controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    private var pendingRelaunch: (() -> Void)?
    private var relaunchTimer: Timer?
    private(set) var updateAvailable = false

    init(canInteract: @escaping () -> Bool) {
        self.canInteract = canInteract
        super.init()
    }

    func start() { controller.startUpdater() }

    var automaticallyChecksForUpdates: Bool { controller.updater.automaticallyChecksForUpdates }
    var automaticallyDownloadsUpdates: Bool { controller.updater.automaticallyDownloadsUpdates }

    func addMenuItems(to menu: NSMenu) {
        let check = NSMenuItem(title: updateAvailable ? "Update Available…" : "Check for Updates…",
                               action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        check.target = self
        menu.addItem(check)
        let automatic = NSMenuItem(title: "Automatically Update", action: #selector(toggleAutomaticUpdates(_:)), keyEquivalent: "")
        automatic.target = self
        updateAutomaticMenuState(automatic)
        automatic.toolTip = "Check and download updates automatically. Install when you quit, or restart when you choose."
        menu.addItem(automatic)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates(_:)) {
            menuItem.title = updateAvailable ? "Update Available…" : "Check for Updates…"
            return canInteract() && controller.updater.canCheckForUpdates
        }
        if menuItem.action == #selector(toggleAutomaticUpdates(_:)) { updateAutomaticMenuState(menuItem) }
        return true
    }

    private func updateAutomaticMenuState(_ item: NSMenuItem) {
        item.state = automaticallyChecksForUpdates ? (automaticallyDownloadsUpdates ? .on : .mixed) : .off
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        guard canInteract(), controller.updater.canCheckForUpdates else { return }
        controller.checkForUpdates(sender)
    }

    @objc private func toggleAutomaticUpdates(_ sender: Any?) {
        setAutomaticallyUpdates(!(automaticallyChecksForUpdates && automaticallyDownloadsUpdates))
    }

    /// Called only for an explicit user preference change. Sparkle persists it.
    func setAutomaticallyUpdates(_ enabled: Bool) {
        // Sparkle allows downloading only while automatic checks are enabled.
        // Enable checking first; disable downloading before turning checks off.
        if enabled { controller.updater.automaticallyChecksForUpdates = true }
        controller.updater.automaticallyDownloadsUpdates = enabled
        if !enabled { controller.updater.automaticallyChecksForUpdates = false }
    }

    // A background utility should not open an update window during lid motion,
    // lock or sleep. The cf. menu indicator brings Sparkle's UI into focus only
    // after an explicit click; automatic install-on-quit remains Sparkle's job.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        updateAvailable = !handleShowingUpdate
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) { updateAvailable = false }
    func standardUserDriverWillFinishUpdateSession() { updateAvailable = false }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        postponeRelaunchIfNeeded(installHandler)
    }

    /// Only a relaunch already requested through Sparkle can reach this path.
    /// Automatic background downloads never force the app to terminate.
    func postponeRelaunchIfNeeded(_ installHandler: @escaping () -> Void) -> Bool {
        guard !canInteract() else { return false }
        pendingRelaunch = installHandler
        relaunchTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.resumeDeferredRelaunchIfReady() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        relaunchTimer = timer
        return true
    }

    func resumeDeferredRelaunchIfReady() {
        guard canInteract(), let installHandler = pendingRelaunch else { return }
        pendingRelaunch = nil
        relaunchTimer?.invalidate()
        relaunchTimer = nil
        installHandler()
    }

    func stop() {
        relaunchTimer?.invalidate()
        relaunchTimer = nil
        pendingRelaunch = nil
    }
}
