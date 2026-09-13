import Foundation

var count = 0
func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else { fatalError("FAIL: \(description)") }
    count += 1
}

var settings = BlurSettings()
check(BlurMath.progress(angle: 110, settings: settings) == 0, "Normal working angle is clear")
check(BlurMath.progress(angle: 85, settings: settings) == 0, "Trigger boundary is clear")
check(BlurMath.progress(angle: 15, settings: settings) == 1, "Closed boundary is fully blurred")
check(BlurMath.progress(angle: 0, settings: settings) == 1, "Closed lid clamps to full effect")
check(BlurMath.progress(angle: 50, settings: settings) == 0.5, "Midpoint is symmetric")
check(BlurMath.progress(angle: .nan, settings: settings) == 0, "Invalid reading clears screen")
let closing = stride(from: 130.0, through: 0.0, by: -1).map { BlurMath.progress(angle: $0, settings: settings) }
check(zip(closing, closing.dropFirst()).allSatisfy { $0 <= $1 }, "Closing monotonically increases blur")
settings.enabled = false
check(BlurMath.progress(angle: 0, settings: settings) == 0, "Disable always clears")
settings.startAngle = .nan; settings.endAngle = 999; settings.radius = -20; settings.smoothing = .infinity
settings.validate()
check(settings.startAngle == 85 && settings.endAngle == 75 && settings.radius == 0 && settings.smoothing == 0.12, "Corrupt preferences are sanitized")
check(BlurMath.decodeLidReport([1, 106, 0]) == 106, "Real HID angle format")
check(BlurMath.decodeLidReport([1, 0, 1]) == nil, "Impossible angle rejected")
check(BlurMath.decodeLidReport([2, 106, 0]) == nil, "Wrong report rejected")
check(BlurMath.decodeLidReport([1, 2]) == nil, "Truncated report rejected")
let at30 = (0..<30).reduce(0.0) { v, _ in BlurMath.smooth(v, toward: 1, elapsed: 1.0/30, duration: 0.6) }
let at60 = (0..<60).reduce(0.0) { v, _ in BlurMath.smooth(v, toward: 1, elapsed: 1.0/60, duration: 0.6) }
check(abs(at30 - at60) < 0.00001, "Smoothing is independent of frame rate")
check(BlurMath.smooth(0.8, toward: 0, elapsed: 0.1, duration: 0) == 0, "Instant response supported")
let legacy = Data(#"{"enabled":true,"radius":32.67374595469256,"startAngle":85,"endAngle":15,"smoothing":0.12,"dimming":0.2,"progressiveBlur":true,"launchAtLogin":false}"#.utf8)
let migrated = try JSONDecoder().decode(BlurSettings.self, from: legacy)
check(migrated.radius == 32.67374595469256 && migrated.duoStyle && migrated.borderDepth == 1, "Duo controls migrate without changing saved strength")
var custom = migrated
custom.duoStyle = false; custom.borderDepth = 1.35
let restored = try JSONDecoder().decode(BlurSettings.self, from: JSONEncoder().encode(custom))
check(restored == custom, "Animation controls persist")
custom.borderDepth = .infinity; custom.validate()
check(custom.borderDepth == 1, "Invalid border depth is sanitized")
print("Passed \(count) behavior checks")

var adaptive = BlurSettings()
adaptive.endAngle = 49.605 // Preserve old manual settings, but do not use them in automatic mode.
var motion = LidMotion()
check(motion.target(angle: 112, time: 0, settings: adaptive) == 0, "Initial working position is clear")
let onset = motion.target(angle: 111, time: 1.0 / 30, settings: adaptive)
check(onset > 0, "First degree of closing responds above the old 85-degree threshold")
check(BlurMath.follow(0, toward: onset, elapsed: 1.0 / 60, duration: 0.12) > 0, "Onset starts on the first animation tick")
let held = motion.target(angle: 90, time: 0.5, settings: adaptive)
check(motion.target(angle: 90, time: 60, settings: adaptive) == held, "Hold mode retains partial blur after a long stationary interval")
check(motion.openAngle == 112, "Holding the lid does not redefine the working position")
check(motion.target(angle: 100, time: 60.1, settings: adaptive) < held, "Partial reopening immediately reverses the target")
check(motion.target(angle: 112, time: 60.2, settings: adaptive) == 0, "Returning to the original working angle clears")
check(BlurMath.follow(0.1, toward: 0, elapsed: 1.0 / 60, duration: 0.6) == 0, "Clear endpoint has no smoothing tail even with maximum smoothing")
let firstReversedFrame = BlurMath.follow(0.8, toward: 0.1, elapsed: 1.0 / 120, duration: 0.6)
check(firstReversedFrame < 0.8 && firstReversedFrame > 0.1, "Reopening reverses on the next display frame without jumping to the target")
let reversed = (0..<54).reduce(0.8) { value, _ in BlurMath.follow(value, toward: 0.1, elapsed: 1.0 / 120, duration: 0.6) }
check(abs(reversed - 0.1) < 0.02, "Maximum smoothing has a bounded settling time after a large reversal")
check(motion.target(angle: 50, time: 61, settings: adaptive) < 0.88, "Old 50-degree endpoint no longer fades to full black in automatic mode")
check(motion.target(angle: 31, time: 62, settings: adaptive) < 1, "The desktop is not fully black above 30 degrees")
check(motion.target(angle: 30, time: 63, settings: adaptive) == 1, "Automatic fold completes at 30 degrees above closed")
check(BlurMath.follow(0.8, toward: 1, elapsed: 1.0 / 60, duration: 0.6) == 1, "Full darkness reaches its angle without an exponential tail")
motion.reset()
check(motion.target(angle: 100, time: 70, settings: adaptive) == 0 && motion.openAngle == 100, "New session anchors at its actual working angle")
adaptive.holdWhenStill = false
let moving = motion.target(angle: 95, time: 70.1, settings: adaptive)
check(moving > 0 && motion.target(angle: 95, time: 70.4, settings: adaptive) == moving, "Settle mode does not clear while inside the settling interval")
check(motion.target(angle: 95, time: 70.7, settings: adaptive) == 0, "Optional settle mode clears stationary blur")
check(motion.target(angle: 94, time: 70.8, settings: adaptive) > 0, "Closing again starts from the settled position")
check(motion.target(angle: .nan, time: 71, settings: adaptive) == 0 && motion.openAngle == nil, "Invalid sensor data resets motion state")
adaptive.automaticStart = false
check(motion.target(angle: 60, time: 72, settings: adaptive) == BlurMath.progress(angle: 60, settings: adaptive), "Manual thresholds remain available")
let newMigrated = try JSONDecoder().decode(BlurSettings.self, from: legacy)
check(newMigrated.automaticStart && newMigrated.nearClosedAngle == 30 && newMigrated.holdWhenStill && newMigrated.endAngle == 15, "Migration uses the new endpoint without overwriting old manual angles")
adaptive.nearClosedAngle = 11
let restoredMotion = try JSONDecoder().decode(BlurSettings.self, from: JSONEncoder().encode(adaptive))
check(restoredMotion == adaptive, "New motion controls round-trip through saved preferences")
print("Passed \(count) total behavior checks including motion timelines and preference migration")

// Reproduce the one-degree staircase from the physical HID sensor. The first
// rendered step must be small, and motion must continue between sensor changes.
let degree = 1.0 / 80
let first120 = BlurMath.follow(0.5, toward: 0.5 + degree, elapsed: 1.0 / 120, duration: 0.12)
let first60 = BlurMath.follow(0.5, toward: 0.5 + degree, elapsed: 1.0 / 60, duration: 0.12)
check(first120 - 0.5 < degree * 0.18, "A degree change is spread across ProMotion frames instead of a visible jump")
check(first60 - 0.5 < degree * 0.30, "A degree change also interpolates on 60 Hz MacBooks")
var between = 0.5
var fineSteps: [Double] = []
for _ in 0..<18 {
    let next = BlurMath.follow(between, toward: 0.5 + degree, elapsed: 1.0 / 120, duration: 0.12)
    fineSteps.append(next - between)
    between = next
}
check(fineSteps.allSatisfy { $0 > 0.000005 }, "Slow one-degree moves retain intermediate frames rather than snapping and pausing")
check(between < 0.5 + degree && between > 0.5 + degree * 0.90, "Interpolation follows closely without overshooting the measured angle")
let fold60 = (0..<12).reduce(0.2) { v, _ in BlurMath.follow(v, toward: 0.8, elapsed: 1.0 / 60, duration: 0.12) }
let fold120 = (0..<24).reduce(0.2) { v, _ in BlurMath.follow(v, toward: 0.8, elapsed: 1.0 / 120, duration: 0.12) }
check(abs(fold60 - fold120) < 0.000001, "Display cadence changes preserve the same physical response time")
let opening = BlurMath.follow(0.7, toward: 0.3, elapsed: 1.0 / 120, duration: 0.12)
let closingFrame = BlurMath.follow(0.3, toward: 0.7, elapsed: 1.0 / 120, duration: 0.12)
check(abs(opening + closingFrame - 1) < 0.000001, "Opening and closing have matching smoothness")
check(BlurMath.follow(0.2, toward: 0.7, elapsed: 1.0 / 120, duration: 0) == 0.7, "Zero smoothing still provides direct sensor response")
check(BlurMath.follow(0.4, toward: 0.8, elapsed: 0, duration: 0.12) == 0.4, "No elapsed time must not advance the fold")
print("Passed \(count) total behavior checks including whole-degree interpolation at 60/120 Hz")
