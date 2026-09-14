import Foundation

struct BlurSettings: Equatable, Codable {
    var enabled = true
    var radius = 36.0
    var startAngle = 85.0
    var endAngle = 15.0
    var smoothing = 0.12
    var dimming = 0.20
    var progressiveBlur = true
    var launchAtLogin = false
    var duoStyle = true
    var borderDepth = 1.0
    var automaticStart = true
    var nearClosedAngle = 30.0
    var holdWhenStill = true

    init() {}

    // New controls must not discard the user's previously saved settings.
    private enum CodingKeys: String, CodingKey {
        case enabled, radius, startAngle, endAngle, smoothing, dimming, progressiveBlur, launchAtLogin, duoStyle, borderDepth
        case automaticStart, nearClosedAngle, holdWhenStill
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        radius = try values.decodeIfPresent(Double.self, forKey: .radius) ?? 36
        startAngle = try values.decodeIfPresent(Double.self, forKey: .startAngle) ?? 85
        endAngle = try values.decodeIfPresent(Double.self, forKey: .endAngle) ?? 15
        smoothing = try values.decodeIfPresent(Double.self, forKey: .smoothing) ?? 0.12
        dimming = try values.decodeIfPresent(Double.self, forKey: .dimming) ?? 0.20
        progressiveBlur = try values.decodeIfPresent(Bool.self, forKey: .progressiveBlur) ?? true
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        duoStyle = try values.decodeIfPresent(Bool.self, forKey: .duoStyle) ?? true
        borderDepth = try values.decodeIfPresent(Double.self, forKey: .borderDepth) ?? 1
        automaticStart = try values.decodeIfPresent(Bool.self, forKey: .automaticStart) ?? true
        nearClosedAngle = try values.decodeIfPresent(Double.self, forKey: .nearClosedAngle) ?? 30
        holdWhenStill = try values.decodeIfPresent(Bool.self, forKey: .holdWhenStill) ?? true
        validate()
    }

    mutating func validate() {
        radius = Self.clamp(radius, 0...80, fallback: 36)
        startAngle = Self.clamp(startAngle, 35...130, fallback: 85)
        endAngle = Self.clamp(endAngle, 0...(startAngle - 10), fallback: 15)
        smoothing = Self.clamp(smoothing, 0...0.6, fallback: 0.12)
        dimming = Self.clamp(dimming, 0...0.65, fallback: 0.2)
        borderDepth = Self.clamp(borderDepth, 0...1.5, fallback: 1)
        nearClosedAngle = Self.clamp(nearClosedAngle, 0...30, fallback: 30)
    }

    static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        min(range.upperBound, max(range.lowerBound, value.isFinite ? value : fallback))
    }
}

enum BlurMath {
    static func progress(angle: Double, settings: BlurSettings) -> Double {
        guard angle.isFinite, settings.enabled else { return 0 }
        var settings = settings
        settings.validate()
        let t = min(1, max(0, (settings.startAngle - angle) / (settings.startAngle - settings.endAngle)))
        return t * t * (3 - 2 * t)
    }

    static func smooth(_ current: Double, toward target: Double, elapsed: Double, duration: Double) -> Double {
        guard duration > 0 else { return target }
        let next = current + (target - current) * (1 - exp(-max(0, elapsed) / duration))
        return abs(next - target) < 0.0005 ? target : next
    }

    /// Interpolate whole-degree sensor steps on every display frame. Use the
    /// same response in both directions so reopening does not expose the steps.
    /// Physical clear/black endpoints still take effect immediately.
    static func follow(_ current: Double, toward target: Double, elapsed: Double, duration: Double) -> Double {
        guard target > 0 else { return 0 }
        guard target < 1 else { return 1 }
        guard duration > 0 else { return target }
        let timeConstant = min(duration / 2, 0.12)
        let next = current + (target - current) * (1 - exp(-max(0, elapsed) / timeConstant))
        // A coarse snap threshold hid the final intermediate frames of each
        // degree, making a slow fold alternate between movement and a pause.
        return abs(next - target) < 0.000005 ? target : next
    }

    /// Report 1 is a little-endian, nine-bit angle in whole degrees.
    static func decodeLidReport(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let angle = Int(bytes[1]) | (Int(bytes[2]) << 8)
        guard (0...180).contains(angle) else { return nil }
        return Double(angle)
    }
}

/// Tracks one fold from the user's working position. Stationary samples never
/// move that reference in hold mode; full reset is reserved for lifecycle changes.
struct LidMotion {
    private(set) var openAngle: Double?
    private var previousAngle: Double?
    private var lastMovement = 0.0

    mutating func reset() { self = LidMotion() }

    /// An explicit follow/calibration action starts a new cycle at this angle.
    mutating func setOpenAngle(_ angle: Double, time: Double) {
        reset()
        guard angle.isFinite, (0...180).contains(angle) else { return }
        openAngle = angle
        previousAngle = angle
        lastMovement = time
    }

    mutating func target(angle: Double, time: Double, settings: BlurSettings) -> Double {
        guard angle.isFinite, (0...180).contains(angle), settings.enabled else {
            reset(); return 0
        }
        guard let previousAngle else {
            self.previousAngle = angle
            openAngle = angle
            lastMovement = time
            return settings.automaticStart ? 0 : BlurMath.progress(angle: angle, settings: settings)
        }
        if abs(angle - previousAngle) >= 0.5 { lastMovement = time }
        self.previousAngle = angle
        if !settings.holdWhenStill && time - lastMovement >= 0.5 {
            openAngle = angle
            return 0
        }
        guard settings.automaticStart else { return BlurMath.progress(angle: angle, settings: settings) }
        let reference = openAngle ?? previousAngle
        // Freeze the reference throughout a partial fold. At the return point,
        // start a fresh cycle instead of retaining the session's highest angle.
        // One degree of return tolerance accommodates the integer HID readings;
        // it applies only while reopening, so the first closing degree still works.
        if angle >= reference || (angle > previousAngle && angle >= reference - 1) {
            openAngle = angle
            return 0
        }
        let end = min(settings.nearClosedAngle, max(0, reference - 10))
        // Half a degree suppresses the numerical boundary without waiting through
        // a large fixed-angle dead zone. HID reports arrive in whole degrees.
        let t = min(1, max(0, (reference - angle - 0.5) / max(0.5, reference - end - 0.5)))
        return t
    }
}

enum LidPreviewMath {
    static func progress(angle: Double, reference: Double, settings: BlurSettings) -> Double {
        var previewSettings = settings
        previewSettings.enabled = true
        guard previewSettings.automaticStart else { return BlurMath.progress(angle: angle, settings: previewSettings) }
        var motion = LidMotion()
        motion.setOpenAngle(reference, time: 0)
        return motion.target(angle: angle, time: 0.1, settings: previewSettings)
    }

    /// At clear or black, appearance edits are invisible. Use a readable sample
    /// fold for adjustment, without changing the real lid or desktop effect.
    static func appearanceProgress(from progress: Double) -> Double {
        (0.15...0.85).contains(progress) ? progress : 0.55
    }
}
