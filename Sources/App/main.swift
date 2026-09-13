import AppKit

if CommandLine.arguments.contains("--diagnose") {
    print("cladofold. \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
    print("Model: \(Compatibility.model)")
    print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("Built-in display: \(Compatibility.builtInDisplay)")
    print("Metal graphics: \(Compatibility.metalAvailable)")
    let sensor = LidSensor()
    sensor.connect()
    print("Sensor: \(sensor.status)")
    print("Angle: \(sensor.read().map { "\($0)°" } ?? "unavailable")")
    print("Screen capture permission: \(CGPreflightScreenCaptureAccess())")
    if sensor.read() == nil { print(Compatibility.fallbackSummary) }
} else {
    MainActor.assumeIsolated {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
