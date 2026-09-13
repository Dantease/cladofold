import AppKit
import SwiftUI
import Combine
import Carbon
import ServiceManagement
import ScreenCaptureKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let preferences = Preferences()
    private let sensor = SensorMonitor()
    private let overlay = BlurOverlay()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var timers: [Timer] = []
    private var cancellables: Set<AnyCancellable> = []
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var localKeyMonitor: Any?
    private var captureTask: Task<Void, Never>?
    private var captureGeneration = 0
    private var angle: Double?
    private var sampleTime = Date.distantPast
    private var sensorMessage = "Connecting to lid sensor"
    private var permission = false
    private var verifiedCaptureAccess = false
    private var checkingCaptureAccess = false
    private var errorMessage: String?
    private var suspended = false
    private var locked = false
    private var progress = 0.0
    private var lastRender = -1.0
    private var lastTick = Date()
    private var previewStart: Date?
    private var captureRetryAfter = Date.distantPast
    private var loginState: Bool?
    private var shortcutAvailable = true
    private var motion = LidMotion()
    private var motionSettings = BlurSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: CladofoldID.app).count <= 1 else {
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        CladofoldID.rememberApplication()
        installSettingsPane()
        locked = (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
        setupMenu()
        setupShortcut()
        setupObservers()
        sensor.onSample = { [weak self] angle, message in
            guard let self else { return }
            self.angle = angle
            self.sensorMessage = message
            if angle != nil { self.sampleTime = Date() }
        }
        sensor.start()
        motionSettings = preferences.settings
        preferences.$settings.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.settingsChanged() }
        }.store(in: &cancellables)
        addTimer(interval: 1.0 / 60) { [weak self] in self?.tick() }
        addTimer(interval: 0.5) { [weak self] in self?.publishStatus() }
        reconcileLoginItem()
        publishStatus()
        if permission || UserDefaults.standard.bool(forKey: "screenPermissionWasRequested") {
            Task { await verifyCaptureAccess(openSettingsOnFailure: false) }
        }
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--command"), args.indices.contains(index + 1) {
            command(args[index + 1])
        } else if !args.contains("--background"),
                  NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue != OSType(keyAELaunchedAsLogInItem) {
            showSettings()
        }
    }

    private func addTimer(interval: Double, action: @escaping () -> Void) {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        timers.append(timer)
    }

    private func setupObservers() {
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(receiveCommand(_:)), name: CladofoldID.command, object: nil)
        distributed.addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(self, selector: #selector(sleeping), name: name, object: nil)
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(waking), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func sleeping() { suspended = true; clear(); overlay.clear(discardResources: true) }
    @objc private func waking() { suspended = false; sampleTime = .distantPast; clear(); prepareAfterResume() }
    @objc private func screenLocked() { locked = true; clear() }
    @objc private func screenUnlocked() { locked = false; sampleTime = .distantPast; clear(); prepareAfterResume() }
    @objc private func displaysChanged() { clear(); overlay.clear(discardResources: true); prepareAfterResume() }

    private func prepareAfterResume() {
        guard permission, !suspended, !locked else { return }
        Task { await verifyCaptureAccess(openSettingsOnFailure: false) }
    }

    private func tick() {
        let now = Date()
        let elapsed = min(0.1, now.timeIntervalSince(lastTick))
        lastTick = now
        guard (preferences.settings.enabled || previewStart != nil), permission, !suspended, !locked else {
            if progress != 0 || overlay.capturing || overlay.ready { clear() }
            return
        }
        let target: Double
        if let previewStart {
            let seconds = now.timeIntervalSince(previewStart)
            if seconds >= 6 { clear(); return }
            // Two seconds close, one second hold, two seconds open, one second clear.
            let linear = seconds < 2 ? seconds / 2 : (seconds < 3 ? 1 : max(0, (5 - seconds) / 2))
            target = linear * linear * (3 - 2 * linear)
        } else if let angle, now.timeIntervalSince(sampleTime) < 0.6 {
            target = motion.target(angle: angle, time: now.timeIntervalSinceReferenceDate, settings: preferences.settings)
        } else {
            clear(); return
        }
        progress = BlurMath.follow(progress, toward: target, elapsed: elapsed, duration: preferences.settings.smoothing)
        if progress < 0.0005 && target == 0 {
            if overlay.ready || overlay.capturing { clearOverlay() }
            return
        }
        if !overlay.ready && !overlay.capturing && now > captureRetryAfter {
            captureRetryAfter = now.addingTimeInterval(3)
            let generation = captureGeneration
            captureTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.overlay.capture()
                    guard self.captureGeneration == generation, !Task.isCancelled else { return }
                    self.captureRetryAfter = .distantPast
                    self.errorMessage = nil
                    self.lastRender = -1
                } catch {
                    guard self.captureGeneration == generation, !Task.isCancelled else { return }
                    self.verifiedCaptureAccess = false
                    self.errorMessage = error.localizedDescription
                    self.overlay.clear(discardResources: true)
                }
            }
        }
        if overlay.ready && abs(progress - lastRender) > 0.0005 {
            overlay.render(progress: progress, settings: preferences.settings)
            lastRender = progress
        }
    }

    private func clearOverlay() {
        captureGeneration += 1
        captureTask?.cancel()
        captureTask = nil
        overlay.clear()
        progress = 0
        lastRender = -1
    }

    private func clear() {
        previewStart = nil
        motion.reset()
        clearOverlay()
    }

    private func settingsChanged() {
        let next = preferences.settings
        if next.automaticStart != motionSettings.automaticStart || next.holdWhenStill != motionSettings.holdWhenStill {
            clear()
        }
        motionSettings = next
        if !preferences.settings.enabled { clear() }
        lastRender = -1
        errorMessage = nil
        reconcileLoginItem()
        publishStatus()
    }

    private func reconcileLoginItem() {
        let desired = preferences.settings.launchAtLogin
        guard desired != loginState else { return }
        loginState = desired
        do {
            if desired && SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            if !desired && SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            if desired && SMAppService.mainApp.status == .requiresApproval {
                errorMessage = "Allow cladofold. in General → Login Items & Extensions."
            }
        } catch {
            errorMessage = "Login item: \(error.localizedDescription)"
            if desired { preferences.settings.launchAtLogin = false }
        }
    }

    private func publishStatus() {
        permission = CGPreflightScreenCaptureAccess() || verifiedCaptureAccess
        let freshAngle = Date().timeIntervalSince(sampleTime) < 0.6 ? angle : nil
        let previewMessage: String? = previewStart == nil ? nil : (overlay.ready ? "Previewing on built-in display" : "Preparing screen preview")
        let message = overlay.renderError ?? errorMessage ?? previewMessage ?? (!preferences.settings.enabled ? "Effect is turned off" : (!permission ? "Screen Recording permission needed" : (freshAngle == nil ? sensorMessage : "Ready · follows your lid")))
        var info: [String: Any] = ["permission": permission, "message": message, "previewing": previewStart != nil, "shortcutAvailable": shortcutAvailable, "overlayVisible": overlay.visible, "renderedFrames": overlay.renderedFrames]
        if let freshAngle { info["angle"] = freshAngle }
        if let openAngle = motion.openAngle { info["openAngle"] = openAngle }
        info["progress"] = progress
        info["captureMilliseconds"] = overlay.captureMilliseconds
        DistributedNotificationCenter.default().postNotificationName(CladofoldID.status, object: nil, userInfo: info, deliverImmediately: true)
        statusItem.button?.toolTip = "cladofold. · \(message)" + (freshAngle.map { " · \(Int($0))°" } ?? "")
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "cf."
        statusItem.button?.font = .systemFont(ofSize: 13, weight: .bold)
        statusItem.button?.setAccessibilityLabel("cladofold.")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        menuNeedsUpdate(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let label = NSMenuItem(title: angle.map { "cladofold. · \(Int($0))°" } ?? "cladofold.", action: nil, keyEquivalent: "")
        label.isEnabled = false
        menu.addItem(label)
        let enabled = item("Enable cladofold.", action: #selector(toggleEnabled))
        enabled.state = preferences.settings.enabled ? .on : .off
        menu.addItem(enabled)
        menu.addItem(item("Settings…", action: #selector(showSettings), key: ","))
        menu.addItem(item("Open in System Settings…", action: #selector(openSystemSettings)))
        menu.addItem(item(previewStart == nil ? "Preview for 6 seconds" : "Stop preview", action: #selector(togglePreview)))
        if !permission { menu.addItem(item("Allow Screen Recording…", action: #selector(requestPermission))) }
        menu.addItem(.separator())
        menu.addItem(item("Disable effect now", action: #selector(disableEffect)))
        menu.addItem(item("Quit cladofold.", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key)
        result.target = self
        return result
    }

    @objc private func toggleEnabled() { preferences.settings.enabled.toggle() }
    @objc func disableEffect() { preferences.settings.enabled = false; clear() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func togglePreview() {
        if previewStart != nil { clear(); return }
        guard permission else { requestPermission(); return }
        clear()
        previewStart = Date()
        captureRetryAfter = .distantPast
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 610, height: 780), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "cladofold."
            window.contentView = NSHostingView(rootView: SettingsView(preferences: preferences, onCommand: { [weak self] in self?.command($0) }))
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        if NSApp.mainMenu == nil {
            let main = NSMenu()
            let appItem = NSMenuItem()
            let appMenu = NSMenu()
            appMenu.addItem(item("Settings…", action: #selector(showSettings), key: ","))
            let stop = item("Disable effect now", action: #selector(disableEffect), key: "b")
            stop.keyEquivalentModifierMask = [.control, .option, .command]
            appMenu.addItem(stop)
            appMenu.addItem(.separator())
            appMenu.addItem(item("Quit cladofold.", action: #selector(quit), key: "q"))
            appItem.submenu = appMenu
            main.addItem(appItem)
            NSApp.mainMenu = main
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }

    @objc private func openSystemSettings() {
        if installSettingsPane() { NSWorkspace.shared.open(CladofoldID.paneURL) }
        else { showSettings(); publishStatus() }
    }

    @discardableResult private func installSettingsPane() -> Bool {
        let source = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/\(CladofoldID.paneName)")
        do {
            try PaneInstaller.install(from: source, to: CladofoldID.paneURL)
            return true
        } catch {
            errorMessage = "System Settings: \(error.localizedDescription)"
            return false
        }
    }

    @objc private func requestPermission() {
        clear()
        NSApp.activate(ignoringOtherApps: true)
        UserDefaults.standard.set(true, forKey: "screenPermissionWasRequested")
        Task { await verifyCaptureAccess(openSettingsOnFailure: true) }
    }

    /// Validate the API we actually use. CoreGraphics preflight can remain false
    /// after a permission change even when ScreenCaptureKit is available.
    private func verifyCaptureAccess(openSettingsOnFailure: Bool) async {
        guard !checkingCaptureAccess else { return }
        checkingCaptureAccess = true
        let preparationGeneration = captureGeneration
        defer { checkingCaptureAccess = false; publishStatus() }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) else { throw OverlayError.noDisplay }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 2
            configuration.height = 2
            configuration.showsCursor = false
            // A tiny transient frame proves capture access without saving anything.
            _ = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            verifiedCaptureAccess = true
            errorMessage = nil
            if preparationGeneration == captureGeneration && !suspended && !locked { try overlay.prepare(content: content) }
        } catch {
            verifiedCaptureAccess = false
            errorMessage = "Screen access: \(error.localizedDescription)"
            if openSettingsOnFailure, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func receiveCommand(_ notification: Notification) {
        if let name = notification.object as? String { command(name) }
    }

    private func command(_ name: String) {
        switch name {
        case "settings": showSettings()
        case "systemSettings": openSystemSettings()
        case "permission": requestPermission()
        case "preview": if previewStart == nil { togglePreview() }
        case "stopPreview": clear()
        case "disable": disableEffect()
        default: publishStatus()
        }
    }

    private func setupShortcut() {
        // Keep the same shortcut available to settings-window key events too.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_ANSI_B), event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.control, .option, .command] {
                self?.disableEffect()
                return nil
            }
            return event
        }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.disableEffect() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        let id = EventHotKeyID(signature: 0x464F4C44, id: 1)
        shortcutAvailable = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        clear()
        sensor.stop()
        timers.forEach { $0.invalidate() }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
