import PreferencePanes
import SwiftUI

@objc(CladofoldPreferencePane)
final class CladofoldPreferencePane: NSPreferencePane {
    private let preferences = Preferences()

    override func loadMainView() -> NSView {
        let view = NSHostingView(rootView: SettingsView(preferences: preferences, isPreferencePane: true))
        view.frame = NSRect(x: 0, y: 0, width: 610, height: 780)
        mainView = view
        return view
    }

    override func didSelect() {
        preferences.reload()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.arguments = ["--background"]
        if NSRunningApplication.runningApplications(withBundleIdentifier: CladofoldID.app).isEmpty,
           let appURL = CladofoldID.appURL {
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
        }
    }
}
