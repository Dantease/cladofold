import Foundation

enum FoldPreset: String, CaseIterable, Codable, Identifiable {
    case duo = "Duo", subtle = "Subtle", balanced = "Balanced", dreamy = "Dreamy"
    var id: String { rawValue }
    var original: FoldAppearance {
        switch self {
        case .duo: return FoldAppearance(radius: 48, dimming: 0.12)
        case .subtle: return FoldAppearance(radius: 18, dimming: 0.10)
        case .balanced: return FoldAppearance(radius: 36, dimming: 0.20)
        case .dreamy: return FoldAppearance(radius: 64, dimming: 0.32)
        }
    }
}

/// Presets own appearance only; selecting one never changes lid behavior,
/// smoothing, enablement or login settings.
struct FoldAppearance: Equatable, Codable {
    var radius: Double
    var dimming: Double
    var duoStyle = true
    var borderDepth = 1.0
    var progressiveBlur = true
    mutating func validate() {
        radius = BlurSettings.clamp(radius, 0...80, fallback: 36)
        dimming = BlurSettings.clamp(dimming, 0...0.65, fallback: 0.2)
        borderDepth = BlurSettings.clamp(borderDepth, 0...1.5, fallback: 1)
    }
}

struct BlurSettings: Equatable, Codable {
    var enabled = true
    var radius = 36.0
    var startAngle = 85.0
    var endAngle = 15.0
    static let defaultSmoothing = 0.378
    static let smoothingRange = 0.300...0.600
    var smoothing = defaultSmoothing
    // Earlier versions used a different meaning, or ignored this stored value.
    private let smoothingResponseVersion = 1
    var dimming = 0.20
    var progressiveBlur = true
    var launchAtLogin = false
    var duoStyle = true
    var borderDepth = 1.0
    var automaticStart = true
    var nearClosedAngle = 30.0
    var holdWhenStill = true
    var clearAtAngle = 90.0
    var adjustmentAllowance = 5.0
    var selectedPreset: FoldPreset? = .balanced
    var presetDefaults: [String: FoldAppearance] = [:]
    // Compatibility for the current renderer. Build 27 retired this preference,
    // so it is intentionally neither decoded nor encoded by CodingKeys.
    var vacuumReveal = false

    var appearance: FoldAppearance {
        get { FoldAppearance(radius: radius, dimming: dimming, duoStyle: duoStyle, borderDepth: borderDepth, progressiveBlur: progressiveBlur) }
        set {
            var valid = newValue
            valid.validate()
            radius = valid.radius; dimming = valid.dimming; duoStyle = valid.duoStyle
            borderDepth = valid.borderDepth; progressiveBlur = valid.progressiveBlur
        }
    }
    func defaultAppearance(for preset: FoldPreset) -> FoldAppearance { presetDefaults[preset.rawValue] ?? preset.original }
    var presetIsModified: Bool { selectedPreset.map { appearance != defaultAppearance(for: $0) } ?? false }
    mutating func selectPreset(_ preset: FoldPreset) {
        appearance = defaultAppearance(for: preset)
        selectedPreset = preset
    }
    mutating func savePresetDefault() {
        guard let selectedPreset else { return }
        presetDefaults[selectedPreset.rawValue] = appearance
    }
    mutating func restoreOriginalPreset() {
        guard let selectedPreset else { return }
        presetDefaults.removeValue(forKey: selectedPreset.rawValue)
        appearance = selectedPreset.original
    }

    init() {}

    // New controls must not discard the user's previously saved settings.
    private enum CodingKeys: String, CodingKey {
        case enabled, radius, startAngle, endAngle, smoothing, dimming, progressiveBlur, launchAtLogin, duoStyle, borderDepth
        case automaticStart, nearClosedAngle, holdWhenStill, clearAtAngle, adjustmentAllowance
        case smoothingResponseVersion
        case selectedPreset, presetDefaults
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        radius = try values.decodeIfPresent(Double.self, forKey: .radius) ?? 36
        startAngle = try values.decodeIfPresent(Double.self, forKey: .startAngle) ?? 85
        endAngle = try values.decodeIfPresent(Double.self, forKey: .endAngle) ?? 15
        let responseVersion = try values.decodeIfPresent(Int.self, forKey: .smoothingResponseVersion) ?? 0
        smoothing = responseVersion >= 1 ? (try values.decodeIfPresent(Double.self, forKey: .smoothing) ?? Self.defaultSmoothing) : Self.defaultSmoothing
        dimming = try values.decodeIfPresent(Double.self, forKey: .dimming) ?? 0.20
        progressiveBlur = try values.decodeIfPresent(Bool.self, forKey: .progressiveBlur) ?? true
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        duoStyle = try values.decodeIfPresent(Bool.self, forKey: .duoStyle) ?? true
        borderDepth = try values.decodeIfPresent(Double.self, forKey: .borderDepth) ?? 1
        automaticStart = try values.decodeIfPresent(Bool.self, forKey: .automaticStart) ?? true
        nearClosedAngle = try values.decodeIfPresent(Double.self, forKey: .nearClosedAngle) ?? 30
        holdWhenStill = try values.decodeIfPresent(Bool.self, forKey: .holdWhenStill) ?? true
        clearAtAngle = try values.decodeIfPresent(Double.self, forKey: .clearAtAngle) ?? 90
        adjustmentAllowance = try values.decodeIfPresent(Double.self, forKey: .adjustmentAllowance) ?? 5
        presetDefaults = (try? values.decodeIfPresent([String: FoldAppearance].self, forKey: .presetDefaults)) ?? [:]
        let savedSelection = try? values.decodeIfPresent(String.self, forKey: .selectedPreset)
        selectedPreset = savedSelection.flatMap(FoldPreset.init(rawValue:))
        validate()
        if savedSelection == nil { selectedPreset = FoldPreset.allCases.first { appearance == defaultAppearance(for: $0) } }
    }

    mutating func validate() {
        radius = Self.clamp(radius, 0...80, fallback: 36)
        startAngle = Self.clamp(startAngle, 35...130, fallback: 85)
        endAngle = Self.clamp(endAngle, 0...(startAngle - 10), fallback: 15)
        smoothing = Self.clamp(smoothing, Self.smoothingRange, fallback: Self.defaultSmoothing)
        dimming = Self.clamp(dimming, 0...0.65, fallback: 0.2)
        borderDepth = Self.clamp(borderDepth, 0...1.5, fallback: 1)
        nearClosedAngle = Self.clamp(nearClosedAngle, 0...30, fallback: 30)
        clearAtAngle = Self.clamp(clearAtAngle, 40...130, fallback: 90)
        adjustmentAllowance = Self.clamp(adjustmentAllowance, 3...15, fallback: 5)
        for key in Array(presetDefaults.keys) {
            guard FoldPreset(rawValue: key) != nil else { presetDefaults.removeValue(forKey: key); continue }
            presetDefaults[key]?.validate()
        }
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

    /// Shared response: about 95% of a target change completes in the selected
    /// duration. Every endpoint stays smooth, including at the fastest setting.
    static let settledTolerance = 0.000005

    static func follow(_ current: Double, toward target: Double, elapsed: Double, duration: Double = BlurSettings.defaultSmoothing) -> Double {
        let timeConstant = BlurSettings.clamp(duration, BlurSettings.smoothingRange, fallback: BlurSettings.defaultSmoothing) / 3
        let next = current + (target - current) * (1 - exp(-max(0, elapsed) / timeConstant))
        return abs(next - target) < settledTolerance ? target : next
    }

    /// Report 1 is a little-endian, nine-bit angle in whole degrees.
    static func decodeLidReport(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let angle = Int(bytes[1]) | (Int(bytes[2]) << 8)
        guard (0...180).contains(angle) else { return nil }
        return Double(angle)
    }
}

/// Visible motion starts only when a captured frame is available. Sensor intent
/// can keep changing during capture without skipping the visual entry frames.
struct FoldPresentation {
    private(set) var progress = 0.0
    private(set) var entryOpacity = 0.0

    mutating func update(target: Double, elapsed: Double, snapshotReady: Bool, duration: Double = BlurSettings.defaultSmoothing) {
        guard snapshotReady else { self = FoldPresentation(); return }
        progress = BlurMath.follow(progress, toward: target, elapsed: elapsed, duration: duration)
        entryOpacity = BlurMath.follow(entryOpacity, toward: 1, elapsed: elapsed, duration: duration)
    }
}

/// Whole-degree HID sits still between reports. Estimate the live angle so the
/// fold glides instead of ticking, then freeze if the next degree never comes.
struct LidAngleTracker {
    private var lastAngle: Double?
    private var lastDistinctTime = 0.0
    private var lastStep = 0.0
    private(set) var degreesPerSecond = 0.0

    mutating func reset() { self = LidAngleTracker() }

    mutating func sample(_ angle: Double, time: Double) {
        guard angle.isFinite, (0...180).contains(angle) else { reset(); return }
        if let last = lastAngle, abs(angle - last) >= 0.5 {
            let dt = time - lastDistinctTime
            if dt > 0, dt < 4 {
                degreesPerSecond = (angle - last) / dt
            } else {
                degreesPerSecond = 0
            }
            lastStep = abs(angle - last)
            lastAngle = angle
            lastDistinctTime = time
        } else if lastAngle == nil {
            lastAngle = angle
            lastDistinctTime = time
            lastStep = 0
            degreesPerSecond = 0
        }
    }

    func estimated(now: Double) -> Double {
        guard let lastAngle else { return 0 }
        let dt = now - lastDistinctTime
        let speed = abs(degreesPerSecond)
        // A large jump is an arrival. Only glide across single-degree HID steps.
        guard dt > 0, speed >= 0.25, lastStep <= 1.5 else { return lastAngle }
        let travel = degreesPerSecond * min(dt, 1 / speed)
        return BlurSettings.clamp(lastAngle + travel, 0...180, fallback: lastAngle)
    }

    func isExtrapolating(now: Double) -> Bool {
        let dt = now - lastDistinctTime
        let speed = abs(degreesPerSecond)
        return dt > 0 && speed >= 0.25 && lastStep <= 1.5 && dt < 1 / speed
    }
}

/// Tracks folds and screen adjustments from a resting position. A deliberate
/// hold while clear or closing accepts a new clear working position.
struct LidMotion {
    private(set) var openAngle: Double?
    private(set) var smoothClear = false
    private enum Phase { case clear, closing, opening }
    private var phase = Phase.clear
    private var previousAngle: Double?
    private var lastMovement = 0.0
    private var extremeAngle = 0.0
    private var extremeProgress = 0.0
    private var segmentAngle = 0.0
    private var segmentProgress = 0.0
    private var lastProgress = 0.0
    private var lastDistinctAngle: Double?
    private var lastDistinctTime = 0.0
    private var degreesPerSecond = 0.0

    /// Whole-degree HID can sit on one reading during a slow close. Wait at least
    /// one second, and longer than the current degree-step if the lid is still closing.
    static func stillHoldDuration(degreesPerSecond: Double) -> Double {
        let closingSpeed = max(0, -degreesPerSecond)
        let step = closingSpeed >= 0.25 ? 1 / closingSpeed : 0
        // Longer than a slow whole-degree dwell, but still a short hold after a fast close.
        return max(1.6, step + 0.4)
    }

    mutating func reset() { self = LidMotion() }

    /// An explicit follow/calibration action starts a new cycle at this angle.
    mutating func setOpenAngle(_ angle: Double, time: Double) {
        reset()
        guard angle.isFinite, (0...180).contains(angle) else { return }
        openAngle = angle
        previousAngle = angle
        lastMovement = time
        extremeAngle = angle
        lastDistinctAngle = angle
        lastDistinctTime = time
        degreesPerSecond = 0
    }

    mutating func target(angle: Double, time: Double, settings: BlurSettings) -> Double {
        guard angle.isFinite, (0...180).contains(angle), settings.enabled else {
            reset(); return 0
        }
        guard let previousAngle else {
            setOpenAngle(angle, time: time)
            return settings.automaticStart ? 0 : BlurMath.progress(angle: angle, settings: settings)
        }
        if abs(angle - previousAngle) >= 0.05 {
            if let lastDistinctAngle {
                let dt = time - lastDistinctTime
                if dt > 0, dt < 4 {
                    degreesPerSecond = (angle - lastDistinctAngle) / dt
                }
            }
            lastDistinctAngle = angle
            lastDistinctTime = time
            lastMovement = time
        }
        self.previousAngle = angle
        if !settings.holdWhenStill && time - lastMovement >= 0.5 {
            setOpenAngle(angle, time: time)
            return 0
        }
        guard settings.automaticStart else { return BlurMath.progress(angle: angle, settings: settings) }
        if time - lastMovement >= Self.stillHoldDuration(degreesPerSecond: degreesPerSecond)
            && (phase == .clear || phase == .closing || angle >= settings.clearAtAngle) {
            let needsFade = smoothClear || lastProgress > 0
            setOpenAngle(angle, time: time)
            smoothClear = needsFade
            return 0
        }
        let reference = openAngle ?? previousAngle
        let end = min(settings.nearClosedAngle, max(0, reference - 10))
        let clearAt = min(reference, settings.clearAtAngle)
        switch phase {
        case .clear:
            // A wider opening beyond the allowance can establish a reference;
            // other adjustments need a full second of stillness first.
            if angle > reference + settings.adjustmentAllowance {
                openAngle = angle
                return 0
            }
            guard angle < reference - settings.adjustmentAllowance else { return 0 }
            phase = .closing
            smoothClear = false
            segmentAngle = reference - settings.adjustmentAllowance
            segmentProgress = 0
            extremeAngle = angle
        case .closing:
            if angle >= extremeAngle + 3 {
                phase = .opening
                segmentAngle = extremeAngle
                segmentProgress = extremeProgress
                extremeAngle = angle
            }
        case .opening:
            if angle <= extremeAngle - 3 {
                phase = .closing
                segmentAngle = extremeAngle
                segmentProgress = extremeProgress
                extremeAngle = angle
            }
        }

        if phase == .opening {
            if angle >= clearAt {
                // A reversal above the threshold may still be visibly folded.
                // Ease that residual away instead of cutting the overlay off.
                let needsFade = segmentAngle >= clearAt
                setOpenAngle(angle, time: time)
                smoothClear = needsFade
                return 0
            }
            let t = BlurSettings.clamp((clearAt - angle) / max(1, clearAt - segmentAngle), 0...1, fallback: 0)
            lastProgress = min(lastProgress, segmentProgress * t)
            if angle >= extremeAngle {
                extremeAngle = angle
                extremeProgress = lastProgress
            }
        } else {
            let t = BlurSettings.clamp((segmentAngle - angle) / max(1, segmentAngle - end), 0...1, fallback: 0)
            lastProgress = max(lastProgress, segmentProgress + (1 - segmentProgress) * t)
            if angle <= extremeAngle {
                extremeAngle = angle
                extremeProgress = lastProgress
            }
        }
        return lastProgress
    }
}

/// Stateful preview driver: the slider, live lid and demo all use LidMotion.
/// It is independent of desktop enablement and never requests screen access.
struct LidPreviewSimulation {
    private(set) var motion = LidMotion()
    private(set) var progress = 0.0
    private var lastTime: Double?

    mutating func reset(angle: Double, time: Double) {
        motion.setOpenAngle(angle, time: time)
        progress = 0
        lastTime = time
    }

    mutating func update(angle: Double, time: Double, settings: BlurSettings) {
        var settings = settings
        settings.enabled = true
        let target = motion.target(angle: angle, time: time, settings: settings)
        let elapsed = max(0, time - (lastTime ?? time))
        lastTime = time
        progress = BlurMath.follow(progress, toward: target, elapsed: elapsed, duration: settings.smoothing)
    }
}

/// Internal timestamps keep advancing without publishing SwiftUI state. Only a
/// changed visible progress value needs to redraw the settings preview.
final class LidPreviewDriver {
    private var simulation = LidPreviewSimulation()
    var progress: Double { simulation.progress }
    var motion: LidMotion { simulation.motion }
    func reset(angle: Double, time: Double) { simulation.reset(angle: angle, time: time) }
    @discardableResult func update(angle: Double, time: Double, settings: BlurSettings) -> Bool {
        let previous = progress
        simulation.update(angle: angle, time: time, settings: settings)
        return previous != progress
    }
}

enum LidPreviewMath {
    static let demoDuration = 6.0

    static func demoAngle(elapsed: Double, reference: Double, closed: Double) -> Double {
        let travelDuration = 2.5
        let t = BlurSettings.clamp(elapsed < travelDuration ? elapsed / travelDuration : (travelDuration * 2 - elapsed) / travelDuration, 0...1, fallback: 0)
        let smooth = t * t * (3 - 2 * t)
        // Retain some linear travel at the hinge so even the slow, whole-degree
        // performance preview reverses before it looks like a one-second hold.
        let eased = smooth * 0.75 + t * 0.25
        return reference + (closed - reference) * eased
    }
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
