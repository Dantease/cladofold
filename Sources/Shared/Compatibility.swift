import AppKit
import SwiftUI
import Metal
import Darwin

enum Compatibility {
    static var model: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "Unknown Mac" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &value, &size, nil, 0) == 0 else { return "Unknown Mac" }
        return String(cString: value)
    }

    static var builtInDisplay: Bool {
        NSScreen.screens.contains {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(number.uint32Value) != 0
        }
    }
    static var metalAvailable: Bool { MTLCreateSystemDefaultDevice() != nil }
    static let hardwareSummary = "Automatic folding needs a readable lid-angle sensor. Expected on 14-inch and 16-inch MacBook Pro models (including the 2019 16-inch Intel model), and MacBook Air with M2 or later."
    static let fallbackSummary = "M1 MacBook Air, 13-inch MacBook Pro, and most older MacBooks cannot report a continuous lid angle. You can still use the miniature preview and, with screen permission, the timed desktop preview. Software cannot add the missing sensor."
}

struct CompatibilityView: View {
    let angle: Double?
    let running: Bool
    let permission: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Will cladofold. work on this Mac?").font(.title2.bold())
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 9) {
                row("Mac", Compatibility.model)
                row("System", ProcessInfo.processInfo.operatingSystemVersionString)
                row("Lid angle", angle.map { "Connected · \(Int($0))°" } ?? (running ? "No readable sensor — preview available" : "Start cladofold. to check"))
                row("Built-in display", Compatibility.builtInDisplay ? "Available" : "Not available")
                row("Metal graphics", Compatibility.metalAvailable ? "Available" : "Not available")
                row("Screen permission", permission ? "Allowed" : "Needed for the desktop effect")
            }
            Divider()
            Text(Compatibility.hardwareSummary)
            Text(Compatibility.fallbackSummary).foregroundStyle(.secondary)
            Text("Requires macOS Sonoma 14.0 or later. The download includes native Apple silicon and Intel versions. Sensor detection on your Mac is the deciding check; other models have not all been tested.").foregroundStyle(.secondary)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.font(.callout).padding(24).frame(width: 520)
    }
    private func row(_ title: String, _ value: String) -> some View {
        GridRow { Text(title).foregroundStyle(.secondary); Text(value) }
    }
}
