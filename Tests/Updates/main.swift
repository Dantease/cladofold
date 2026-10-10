import AppKit
import Sparkle

// Compile separately with AppUpdater.swift and the pinned Sparkle framework.
// --policy must run inside a fixture app with the identifier below and the
// same SUEnableAutomaticChecks/SUAutomaticallyUpdate defaults as production.
// --install TARGET FEED EXPECTED_BUILD performs a real Sparkle install only
// into an inactive fixture under build/update-smoke, never Applications.

@MainActor func policyChecks() {
    let identifier = "com.dante.cladofold.UpdaterPolicyTests"
    precondition(Bundle.main.bundleIdentifier == identifier, "Use the isolated policy-test app bundle")
    let defaults = UserDefaults.standard
    let saved = defaults.persistentDomain(forName: identifier)
    defaults.removePersistentDomain(forName: identifier)
    defer {
        if let saved { defaults.setPersistentDomain(saved, forName: identifier) }
        else { defaults.removePersistentDomain(forName: identifier) }
    }
    var count = 0
    func check(_ value: Bool, _ message: String) {
        precondition(value, message)
        count += 1
    }
    var ready = false
    let updater = AppUpdater { ready }
    check(updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates,
          "First run reads enabled defaults from the bundle")
    updater.setAutomaticallyUpdates(false)
    check(!updater.automaticallyChecksForUpdates && !updater.automaticallyDownloadsUpdates,
          "Opting out disables both checks and downloads")
    let reopened = AppUpdater { ready }
    check(!reopened.automaticallyChecksForUpdates && !reopened.automaticallyDownloadsUpdates,
          "Creating another updater preserves the stored opt-out")
    reopened.setAutomaticallyUpdates(true)
    check(reopened.automaticallyChecksForUpdates && reopened.automaticallyDownloadsUpdates,
          "Explicitly opting back in enables both checks and downloads")
    let menu = NSMenu()
    reopened.addMenuItems(to: menu)
    check(menu.items.map(\.title) == ["Check for Updates…", "Automatically Update"], "Update controls are discoverable")
    check(!reopened.validateMenuItem(menu.items[0]), "A fold, lock or sleep blocks explicit update interaction")
    check(reopened.supportsGentleScheduledUpdateReminders
          && !reopened.standardUserDriverShouldHandleShowingScheduledUpdate(.empty(), andInImmediateFocus: true),
          "Scheduled checks never force a foreground update window")
    var installs = 0
    check(reopened.postponeRelaunchIfNeeded { installs += 1 }, "A requested relaunch defers while the app is busy")
    reopened.resumeDeferredRelaunchIfReady()
    check(installs == 0, "A deferred relaunch cannot run while busy")
    ready = true
    reopened.resumeDeferredRelaunchIfReady()
    reopened.resumeDeferredRelaunchIfReady()
    check(installs == 1, "A deferred relaunch resumes exactly once when clear and awake")
    check(!reopened.postponeRelaunchIfNeeded { installs += 1 } && installs == 1,
          "An available app leaves immediate installation to Sparkle")
    ready = false
    _ = reopened.postponeRelaunchIfNeeded { installs += 1 }
    reopened.stop()
    ready = true
    reopened.resumeDeferredRelaunchIfReady()
    check(installs == 1, "Shutdown cancels a deferred relaunch callback")
    updater.stop()
    print("Passed \(count) updater policy checks")
}

@MainActor final class InstallSmoke: NSObject, SPUUpdaterDelegate, SPUUserDriver {
    private let target: URL
    private let feed: URL
    private let expectedBuild: String
    private let checkOnly: Bool
    private var updater: SPUUpdater?
    private var timeout: Timer?

    init(target: URL, feed: URL, expectedBuild: String, checkOnly: Bool) {
        self.target = target
        self.feed = feed
        self.expectedBuild = expectedBuild
        self.checkOnly = checkOnly
    }

    func start() throws {
        let allowedRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("build/update-smoke", isDirectory: true).resolvingSymlinksInPath().path + "/"
        guard target.path.hasPrefix(allowedRoot), target.pathExtension == "app",
              let bundle = Bundle(url: target), bundle.bundleIdentifier == "com.dante.Foldable",
              bundle.object(forInfoDictionaryKey: "SUDefaultsDomain") as? String == "com.dante.Foldable.UpdateSmoke",
              !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundle.bundleIdentifier }) else {
            throw NSError(domain: "UpdateSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: "Target must be an inactive cladofold. clone under build/update-smoke with isolated SUDefaultsDomain; quit the installed app first"])
        }
        guard feed.scheme == "https" || (feed.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(feed.host ?? "")) else {
            throw NSError(domain: "UpdateSmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "Use HTTPS or a loopback test feed"])
        }
        let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: self, delegate: self)
        self.updater = updater
        try updater.start()
        updater.checkForUpdates()
        timeout = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { _ in
            print("FAIL: updater smoke timed out")
            exit(2)
        }
    }

    // A feed override is confined to this test binary, never the native app.
    func feedURLString(for updater: SPUUpdater) -> String? { feed.absoluteString }
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool { false }
    func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool { false }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        print("FAIL: unexpected permission request in explicit smoke check")
        exit(3)
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { print("Checking fixture feed") }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !checkOnly, appcastItem.versionString == expectedBuild, !appcastItem.isInformationOnlyUpdate else {
            print("FAIL: unexpected update \(appcastItem.versionString)")
            exit(4)
        }
        print("Found fixture build \(appcastItem.versionString)")
        reply(.install)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) { print("Release notes: \(error.localizedDescription)") }
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        if checkOnly,
           let latest = (error as NSError).userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem,
           latest.versionString == expectedBuild,
           let reason = (error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber,
           reason.intValue == SPUNoUpdateFoundReason.onLatestVersion.rawValue {
            print("PASS: fixture is current at build \(expectedBuild)")
            acknowledgement()
            DispatchQueue.main.async { exit(0) }
            return
        }
        acknowledgement()
        fail(error)
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
        fail(error)
    }
    private func fail(_ error: Error) {
        let error = error as NSError
        print("FAIL: \(error.domain) \(error.code): \(error.localizedDescription)")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            print("Underlying: \(underlying.domain) \(underlying.code): \(underlying.localizedDescription)")
        }
        exit(5)
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { print("Downloading fixture") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { print("Extracting and verifying fixture") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { reply(.install) }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        print("Installing isolated fixture; target terminated: \(applicationTerminated)")
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        timeout?.invalidate()
        // Read the replaced plist from disk, not a cached pre-install Bundle.
        do {
            let data = try Data(contentsOf: target.appendingPathComponent("Contents/Info.plist"))
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            guard plist?["CFBundleVersion"] as? String == expectedBuild, !relaunched else {
                print("FAIL: replacement version or relaunch state does not match")
                exit(6)
            }
            print("PASS: Sparkle installed fixture build \(expectedBuild) without relaunch")
            acknowledgement()
            DispatchQueue.main.async { exit(0) }
        } catch { fail(error) }
    }
    func dismissUpdateInstallation() {}
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let args = CommandLine.arguments
    if args.count == 2 && args[1] == "--policy" {
        policyChecks()
    } else if args.count == 5 && ["--install", "--check-only"].contains(args[1]), let feed = URL(string: args[3]) {
        let smoke = InstallSmoke(target: URL(fileURLWithPath: args[2]).resolvingSymlinksInPath(), feed: feed,
                                 expectedBuild: args[4], checkOnly: args[1] == "--check-only")
        do {
            try smoke.start()
            withExtendedLifetime(smoke) { application.run() }
        } catch {
            print("FAIL: \(error.localizedDescription)")
            exit(1)
        }
    } else {
        print("Usage: updater-tests --policy | --install|--check-only TARGET_APP FEED_URL EXPECTED_BUILD")
        exit(64)
    }
}
