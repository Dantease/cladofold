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
check(settings.startAngle == 85 && settings.endAngle == 75 && settings.radius == 0 && settings.smoothing == 0.378, "Corrupt preferences are sanitized")
check(BlurMath.decodeLidReport([1, 106, 0]) == 106, "Real HID angle format")
check(BlurMath.decodeLidReport([1, 0, 1]) == nil, "Impossible angle rejected")
check(BlurMath.decodeLidReport([2, 106, 0]) == nil, "Wrong report rejected")
check(BlurMath.decodeLidReport([1, 2]) == nil, "Truncated report rejected")
let at30 = (0..<30).reduce(0.0) { v, _ in BlurMath.smooth(v, toward: 1, elapsed: 1.0/30, duration: 0.12) }
let at60 = (0..<60).reduce(0.0) { v, _ in BlurMath.smooth(v, toward: 1, elapsed: 1.0/60, duration: 0.12) }
check(abs(at30 - at60) < 0.00001, "Smoothing is independent of frame rate")
check(BlurMath.smooth(0.8, toward: 0, elapsed: 0.1, duration: 0) == 0, "Instant response supported")
let legacy = Data(#"{"enabled":true,"radius":32.67374595469256,"startAngle":85,"endAngle":15,"smoothing":0.12,"dimming":0.2,"progressiveBlur":true,"launchAtLogin":false}"#.utf8)
let migrated = try JSONDecoder().decode(BlurSettings.self, from: legacy)
check(migrated.radius == 32.67374595469256 && migrated.duoStyle && migrated.borderDepth == 1, "Duo controls migrate without changing saved strength")
let retiredReveal = try JSONDecoder().decode(BlurSettings.self, from: Data(#"{"vacuumReveal":true}"#.utf8))
let retiredRevealJSON = String(decoding: try JSONEncoder().encode(retiredReveal), as: UTF8.self)
check(!retiredRevealJSON.contains("vacuumReveal"), "The retired reveal preference is ignored and removed on the next settings save")
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
let onset = motion.target(angle: 106, time: 1.0 / 30, settings: adaptive)
check(onset > 0, "Closing responds after the noise buffer above the old 85-degree threshold")
check(BlurMath.follow(0, toward: onset, elapsed: 1.0 / 60, duration: 0.300) > 0, "Onset starts on the first animation tick")
let held = motion.target(angle: 89, time: 0.5, settings: adaptive)
check(motion.target(angle: 89, time: 60, settings: adaptive) == 0 && motion.smoothClear, "One second at a visibly folded angle smoothly clears the screen")
check(motion.openAngle == 89, "Holding the lid adopts that angle as the new working position")
check(motion.target(angle: 100, time: 60.1, settings: adaptive) == 0, "Opening from the adopted position remains clear")
check(motion.target(angle: 112, time: 60.2, settings: adaptive) == 0, "Returning to the original working angle clears")
check(BlurMath.follow(0.1, toward: 0, elapsed: 1.0 / 60, duration: 0.300) > 0, "Clear endpoint retains intermediate frames instead of cutting off")
let firstReversedFrame = BlurMath.follow(0.8, toward: 0.1, elapsed: 1.0 / 120, duration: 0.300)
check(firstReversedFrame < 0.8 && firstReversedFrame > 0.1, "Reopening reverses on the next display frame without jumping to the target")
let reversed = (0..<54).reduce(0.8) { value, _ in BlurMath.follow(value, toward: 0.1, elapsed: 1.0 / 120, duration: 0.300) }
check(abs(reversed - 0.1) < 0.02, "Fixed smoothing has a bounded settling time after a large reversal")
check(motion.target(angle: 50, time: 61, settings: adaptive) < 0.88, "Old 50-degree endpoint no longer fades to full black in automatic mode")
check(motion.target(angle: 31, time: 62, settings: adaptive) < 1, "The desktop is not fully black above 30 degrees")
check(motion.target(angle: 30, time: 63, settings: adaptive) == 1, "Automatic fold completes at 30 degrees above closed")
check(BlurMath.follow(0.8, toward: 1, elapsed: 1.0 / 60, duration: 0.300) < 1, "Full darkness retains intermediate frames instead of snapping")
motion.reset()
check(motion.target(angle: 100, time: 70, settings: adaptive) == 0 && motion.openAngle == 100, "New session anchors at its actual working angle")
adaptive.holdWhenStill = false
let moving = motion.target(angle: 94, time: 70.1, settings: adaptive)
check(moving > 0 && motion.target(angle: 94, time: 70.4, settings: adaptive) == moving, "Settle mode does not clear while inside the settling interval")
check(motion.target(angle: 94, time: 70.7, settings: adaptive) == 0, "Optional settle mode clears stationary blur")
check(motion.target(angle: 88, time: 70.8, settings: adaptive) > 0, "Closing again starts beyond the settled position's noise buffer")
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
let first120 = BlurMath.follow(0.5, toward: 0.5 + degree, elapsed: 1.0 / 120, duration: 0.300)
let first60 = BlurMath.follow(0.5, toward: 0.5 + degree, elapsed: 1.0 / 60, duration: 0.300)
check(first120 - 0.5 < degree * 0.18, "A degree change is spread across ProMotion frames instead of a visible jump")
check(first60 - 0.5 < degree * 0.30, "A degree change also interpolates on 60 Hz MacBooks")
var between = 0.5
var fineSteps: [Double] = []
for _ in 0..<36 {
    let next = BlurMath.follow(between, toward: 0.5 + degree, elapsed: 1.0 / 120, duration: 0.300)
    fineSteps.append(next - between)
    between = next
}
check(fineSteps.allSatisfy { $0 > 0.000005 }, "Slow one-degree moves retain intermediate frames rather than snapping and pausing")
check(between < 0.5 + degree && between > 0.5 + degree * 0.90, "Interpolation follows closely without overshooting the measured angle")
let fold60 = (0..<12).reduce(0.2) { v, _ in BlurMath.follow(v, toward: 0.8, elapsed: 1.0 / 60, duration: 0.300) }
let fold120 = (0..<24).reduce(0.2) { v, _ in BlurMath.follow(v, toward: 0.8, elapsed: 1.0 / 120, duration: 0.300) }
check(abs(fold60 - fold120) < 0.000001, "Display cadence changes preserve the same physical response time")
let opening = BlurMath.follow(0.7, toward: 0.3, elapsed: 1.0 / 120, duration: 0.300)
let closingFrame = BlurMath.follow(0.3, toward: 0.7, elapsed: 1.0 / 120, duration: 0.300)
check(abs(opening + closingFrame - 1) < 0.000001, "Opening and closing have matching smoothness")
check(BlurMath.follow(0.2, toward: 0.7, elapsed: 1.0 / 120, duration: 0.300) < 0.7, "Fixed smoothing cannot be bypassed by a saved zero setting")
check(BlurMath.follow(0.4, toward: 0.8, elapsed: 0, duration: 0.300) == 0.4, "No elapsed time must not advance the fold")
print("Passed \(count) total behavior checks including whole-degree interpolation at 60/120 Hz")

var calibrated = LidMotion()
let cycleSettings = BlurSettings()
_ = calibrated.target(angle: 118, time: 0, settings: cycleSettings)
_ = calibrated.target(angle: 102, time: 1, settings: cycleSettings)
calibrated.setOpenAngle(102, time: 2)
check(calibrated.openAngle == 102 && calibrated.target(angle: 102, time: 2.1, settings: cycleSettings) == 0, "Follow my lid replaces an older wider reference with the current 102-degree angle")
check(calibrated.target(angle: 101, time: 2.2, settings: cycleSettings) == 0, "Calibration ignores one-degree closing noise")
let partial = calibrated.target(angle: 68, time: 3, settings: cycleSettings)
check(partial > 0 && calibrated.target(angle: 68, time: 100, settings: cycleSettings) == 0 && calibrated.openAngle == 68, "A held partial fold clears and becomes the calibrated reference")
check(calibrated.target(angle: 90, time: 101, settings: cycleSettings) == 0, "Reopening clears at the configured angle before the original resting position")
check(calibrated.target(angle: 102, time: 102, settings: cycleSettings) == 0, "Returning to 102 degrees clears without pushing farther")
var cyclesClear = true
for cycle in 0..<20 {
    _ = calibrated.target(angle: 60, time: Double(103 + cycle * 2), settings: cycleSettings)
    cyclesClear = cyclesClear && calibrated.target(angle: 102, time: Double(104 + cycle * 2), settings: cycleSettings) == 0 && calibrated.openAngle == 102
}
check(cyclesClear, "Repeated fold cycles do not accumulate a wider reopening threshold")
calibrated.setOpenAngle(103, time: 200)
_ = calibrated.target(angle: 60, time: 201, settings: cycleSettings)
check(calibrated.target(angle: 89, time: 202, settings: cycleSettings) > 0, "Reopening below the configured clear-at angle retains a partial fold")
check(calibrated.target(angle: 90, time: 203, settings: cycleSettings) == 0, "Reopening reaches clear at exactly the configured threshold")
_ = calibrated.target(angle: 60, time: 204, settings: cycleSettings)
check(calibrated.target(angle: 30, time: 205, settings: cycleSettings) == 1, "Calibration preserves the 30-degree blackout")
calibrated.setOpenAngle(.nan, time: 206)
check(calibrated.openAngle == nil, "Invalid calibration cannot poison the reference")

var previewOnly = BlurSettings()
previewOnly.enabled = false
let previewFold = LidPreviewMath.progress(angle: 70, reference: 102, settings: previewOnly)
check(previewFold > 0 && !previewOnly.enabled, "The miniature preview works while the desktop effect stays disabled")
check(LidPreviewMath.progress(angle: 102, reference: 102, settings: previewOnly) == 0, "The preview uses the selected starting angle")
check(LidPreviewMath.appearanceProgress(from: 0) == 0.55 && LidPreviewMath.appearanceProgress(from: 1) == 0.55, "Appearance edits are visible even with a fully open or black preview")
check(LidPreviewMath.appearanceProgress(from: 0.4) == 0.4, "Appearance editing preserves an already readable partial fold")
previewOnly.automaticStart = false
check(LidPreviewMath.progress(angle: 50, reference: 102, settings: previewOnly) == 0.5, "The independent preview respects manual angle thresholds")
print("Passed \(count) total behavior checks including calibrated cycles and live appearance previews")

var quiet = LidMotion()
quiet.setOpenAngle(102, time: 0)
let noise = [102.0, 101, 103, 100, 102, 104, 101, 102]
let quietTargets = (0..<400).map { quiet.target(angle: noise[$0 % noise.count], time: Double($0) / 60, settings: cycleSettings) }
check(quietTargets.allSatisfy { $0 == 0 } && quiet.openAngle == 102, "Long stationary jitter neither captures nor ratchets the calibrated angle")
check(quiet.target(angle: 96, time: 7, settings: cycleSettings) > 0, "Closing beyond the five-degree allowance starts the effect")
check(quiet.target(angle: 97, time: 7.1, settings: cycleSettings) > 0, "Reopening inside the hysteresis band retains a continuous partial fold")
check(quiet.target(angle: 98, time: 7.2, settings: cycleSettings) > 0, "Two degrees of upward movement remain inside the reopening buffer")
check(quiet.target(angle: 102, time: 7.3, settings: cycleSettings) == 0 && quiet.smoothClear, "Reopening beyond three degrees above the clear-at angle starts a smooth clear")
let afterReturn = (0..<400).map { quiet.target(angle: noise[$0 % noise.count], time: 8 + Double($0) / 60, settings: cycleSettings) }
check(afterReturn.allSatisfy { $0 == 0 } && quiet.openAngle == 102, "Post-reopening sensor jitter cannot re-show the overlay")
check(quiet.target(angle: 96, time: 16, settings: cycleSettings) > 0, "The next real fold works after a noisy return")
check(quiet.target(angle: 30, time: 17, settings: cycleSettings) == 1, "Hysteresis preserves full black at 30 degrees")
check(quiet.target(angle: 108, time: 18, settings: cycleSettings) == 0 && quiet.openAngle == 108, "A deliberate wider working position can establish a new reference")
print("Passed \(count) total behavior checks including open-position hysteresis")

// Approved threshold scenarios and stateful preview parity.
var thresholdSettings = BlurSettings()
check(thresholdSettings.clearAtAngle == 90 && migrated.clearAtAngle == 90, "New and existing settings receive the approved 90-degree default")
thresholdSettings.clearAtAngle = 500; thresholdSettings.validate()
check(thresholdSettings.clearAtAngle == 130, "Clear-at angle is bounded at 130 degrees")
thresholdSettings.clearAtAngle = 5; thresholdSettings.validate()
check(thresholdSettings.clearAtAngle == 40, "Clear-at angle remains above the full-darkness control")
thresholdSettings.clearAtAngle = .nan; thresholdSettings.validate()
check(thresholdSettings.clearAtAngle == 90, "Invalid clear-at settings safely use the default")
thresholdSettings.clearAtAngle = 105
let thresholdRestored = try JSONDecoder().decode(BlurSettings.self, from: JSONEncoder().encode(thresholdSettings))
check(thresholdRestored == thresholdSettings, "Custom clear-at settings persist across app and pane reloads")
thresholdSettings.clearAtAngle = 90

for resting in [80.0, 100, 120] {
    var fold = LidMotion()
    fold.setOpenAngle(resting, time: 0)
    check(fold.target(angle: resting - 2, time: 0.1, settings: thresholdSettings) == 0, "Two-degree closing noise is clear from \(resting)")
    check(fold.target(angle: resting - 6, time: 0.2, settings: thresholdSettings) > 0, "Closing starts beyond the allowance from \(resting), including above 110")
    _ = fold.target(angle: 60, time: 0.3, settings: thresholdSettings)
    let clearAt = min(resting, thresholdSettings.clearAtAngle)
    check(fold.target(angle: clearAt - 1, time: 0.4, settings: thresholdSettings) > 0, "Reopening remains partial below its effective clearing point")
    check(fold.target(angle: clearAt, time: 0.5, settings: thresholdSettings) == 0, "Reopening clears at \(clearAt), never requiring more than the original resting angle")
}

var reversal = LidMotion()
reversal.setOpenAngle(101, time: 0)
let at95 = reversal.target(angle: 95, time: 0.1, settings: thresholdSettings)
check(at95 > 0, "Closing from 101 to 95 activates the effect above the threshold")
check(reversal.target(angle: 96, time: 0.2, settings: thresholdSettings) == at95, "One-degree reversal above the threshold cannot flicker the effect")
check(reversal.target(angle: 97, time: 0.3, settings: thresholdSettings) == at95, "Two-degree reversal above the threshold stays in the buffer")
check(reversal.target(angle: 98, time: 0.4, settings: thresholdSettings) == 0 && reversal.smoothClear, "Three-degree upward reversal above the threshold requests smooth clearing")
let fading = BlurMath.follow(at95, toward: 0, elapsed: 1.0 / 120, duration: 0.300)
check(fading > 0 && fading < at95, "Above-threshold clearing uses the same fixed smooth response")
let faded = (0..<120).reduce(at95) { value, _ in BlurMath.follow(value, toward: 0, elapsed: 1.0 / 120, duration: 0.300) }
check(faded == 0, "Smooth clearing settles fully so the desktop overlay can be removed")
check(reversal.target(angle: 92, time: 0.5, settings: thresholdSettings) > 0 && !reversal.smoothClear, "Closing again works during a smooth clear")

var below = LidMotion()
below.setOpenAngle(110, time: 0)
let foldedAt60 = below.target(angle: 60, time: 0.1, settings: thresholdSettings)
let at70 = below.target(angle: 70, time: 0.2, settings: thresholdSettings)
check(at70 > 0 && at70 < foldedAt60, "Below-threshold reopening progressively unwinds the fold")
check(below.target(angle: 70, time: 20, settings: thresholdSettings) == at70 && below.openAngle == 110, "Holding during reopening retains the partial fold and original reference")
let reclosed = below.target(angle: 67, time: 20.1, settings: thresholdSettings)
check(reclosed > at70 && reclosed < foldedAt60, "Reclosing starts from the partial reopening curve without jumping back to the original curve")
check(below.target(angle: 30, time: 20.2, settings: thresholdSettings) == 1, "Reclosing still reaches the unchanged full-darkness endpoint")

for clearAt in [40.0, 90, 130] {
    var settings = thresholdSettings
    settings.clearAtAngle = clearAt
    settings.enabled = false
    var preview = LidPreviewSimulation()
    let reference = max(110, clearAt + 10)
    preview.reset(angle: reference, time: 0)
    var desktop = LidMotion()
    desktop.setOpenAngle(reference, time: 0)
    var desktopSettings = settings
    desktopSettings.enabled = true
    var rendered = 0.0
    var matching = true
    var reachedDark = false
    for tick in 1...360 {
        let time = Double(tick) / 60
        let angle = LidPreviewMath.demoAngle(elapsed: time, reference: reference, closed: 30)
        let target = desktop.target(angle: angle, time: time, settings: desktopSettings)
        rendered = BlurMath.follow(rendered, toward: target, elapsed: 1.0 / 60, duration: settings.smoothing)
        preview.update(angle: angle, time: time, settings: settings)
        matching = matching && abs(preview.progress - rendered) < 0.000001
        reachedDark = reachedDark || preview.progress >= 0.9
    }
    check(matching, "Preview and desktop follow the same six-second trajectory at a \(clearAt)-degree threshold")
    check(reachedDark && preview.progress == 0, "The preview reaches a dark fold and returns to clear with the desktop effect disabled")
}
print("Passed \(count) total behavior checks including adjustable thresholds and preview parity")

var adjustmentSettings = BlurSettings()
check(adjustmentSettings.adjustmentAllowance == 5 && migrated.adjustmentAllowance == 5, "New and existing users receive a five-degree allowance")
for (input, expected) in [(2.0, 3.0), (20.0, 15.0), (Double.nan, 5.0)] {
    adjustmentSettings.adjustmentAllowance = input
    adjustmentSettings.validate()
    check(adjustmentSettings.adjustmentAllowance == expected, "Adjustment allowance validates its range and invalid values")
}
adjustmentSettings.adjustmentAllowance = 9
let adjustedReload = try JSONDecoder().decode(BlurSettings.self, from: JSONEncoder().encode(adjustmentSettings))
check(adjustedReload == adjustmentSettings, "Custom adjustment allowance survives settings reload")
adjustmentSettings.adjustmentAllowance = 5

for allowance in [3.0, 5, 15] {
    var settings = adjustmentSettings
    settings.adjustmentAllowance = allowance
    var motion = LidMotion()
    motion.setOpenAngle(110, time: 0)
    check(motion.target(angle: 110 - allowance, time: 0.01, settings: settings) == 0, "The exact \(allowance)-degree boundary stays clear")
    check(motion.target(angle: 110 - allowance - 1, time: 0.02, settings: settings) > 0, "Crossing \(allowance) degrees starts immediately without a confirmation timer")
}

var adjustments = LidMotion()
adjustments.setOpenAngle(110, time: 0)
check(adjustments.target(angle: 106, time: 0.1, settings: adjustmentSettings) == 0, "Small glare adjustment stays clear")
_ = adjustments.target(angle: 106, time: 1.59, settings: adjustmentSettings)
check(adjustments.openAngle == 110, "A resting reference cannot reset before the deliberate-hold interval")
_ = adjustments.target(angle: 106, time: 1.71, settings: adjustmentSettings)
check(adjustments.openAngle == 106, "A deliberate hold adopts the adjusted resting angle")
check(adjustments.target(angle: 102, time: 1.8, settings: adjustmentSettings) == 0, "A second small adjustment starts from the new reference")
_ = adjustments.target(angle: 102, time: 3.41, settings: adjustmentSettings)
check(adjustments.openAngle == 102, "Repeated paused adjustments do not accumulate into closing")

var continuousClose = LidMotion()
continuousClose.setOpenAngle(110, time: 0)
_ = continuousClose.target(angle: 106, time: 0.1, settings: adjustmentSettings)
check(continuousClose.target(angle: 104, time: 0.9, settings: adjustmentSettings) > 0 && continuousClose.openAngle == 110, "Closing with pauses shorter than one second still accumulates movement")
check(continuousClose.target(angle: 103, time: 1.7, settings: adjustmentSettings) > 0 && continuousClose.openAngle == 110, "Continued closing does not settle just because the whole gesture lasts longer than one second")

for angle in [89.0, 90, 100] {
    var motion = LidMotion()
    motion.setOpenAngle(110, time: 0)
    let folded = motion.target(angle: angle, time: 0.1, settings: adjustmentSettings)
    check(folded > 0 && motion.target(angle: angle, time: 1.59, settings: adjustmentSettings) == folded, "An active fold does not settle early at \(angle) degrees")
    let settled = motion.target(angle: angle, time: 1.71, settings: adjustmentSettings)
    check(settled == 0 && motion.smoothClear && motion.openAngle == angle, "A settled adjustment at any angle fades clear and adopts its position")
    check(motion.target(angle: angle - 5, time: 1.8, settings: adjustmentSettings) == 0, "Settling restores the full adjustment allowance")
    check(motion.target(angle: angle - 6, time: 1.9, settings: adjustmentSettings) > 0, "A real close can interrupt the settling fade immediately")
}

var disturbed = LidMotion()
disturbed.setOpenAngle(110, time: 0)
_ = disturbed.target(angle: 100, time: 0.1, settings: adjustmentSettings)
_ = disturbed.target(angle: 99, time: 0.9, settings: adjustmentSettings)
check(disturbed.target(angle: 99, time: 1.7, settings: adjustmentSettings) > 0, "Further movement restarts the deliberate-hold interval")
check(disturbed.target(angle: 99, time: 2.51, settings: adjustmentSettings) == 0, "A complete still interval after further movement clears the adjustment")

check(LidMotion.stillHoldDuration(degreesPerSecond: -150) == 1.6, "A fast close still needs a deliberate hold, not an instant clear")
check(LidMotion.stillHoldDuration(degreesPerSecond: -1 / 1.2) >= 1.6, "A slow close waits longer than one whole-degree step before treating stillness as a hold")
var slowClose = LidMotion()
slowClose.setOpenAngle(110, time: 0)
var slowAngle = 104.0
var slowTime = 0.05
_ = slowClose.target(angle: slowAngle, time: slowTime, settings: adjustmentSettings)
for _ in 1...8 {
    check(slowClose.target(angle: slowAngle, time: slowTime + 1.2, settings: adjustmentSettings) > 0 && slowClose.openAngle == 110, "A slow whole-degree close is not mistaken for a stationary hold")
    slowTime += 1.2
    slowAngle -= 1
    _ = slowClose.target(angle: slowAngle, time: slowTime, settings: adjustmentSettings)
}
check(slowClose.target(angle: slowAngle, time: slowTime + 1.0, settings: adjustmentSettings) > 0, "One second on the last slow-close degree is still closing")
check(slowClose.target(angle: slowAngle, time: slowTime + 1.8, settings: adjustmentSettings) == 0 && slowClose.openAngle == slowAngle, "A real pause after slow motion becomes the new clear position")

var glide = LidAngleTracker()
glide.sample(50, time: 0)
glide.sample(49, time: 1.2)
let midStep = glide.estimated(now: 1.8)
check(midStep < 49 && midStep > 48, "The live lid angle glides between whole-degree HID reports")
check(glide.isExtrapolating(now: 1.8), "The tracker reports when its between-degree glide is active")
check(abs(glide.estimated(now: 2.4) - 48) < 0.05, "The glide stops at the next whole-degree estimate")
check(!glide.isExtrapolating(now: 2.4), "The tracker settles after one predicted degree so the display clock can pause")
glide.sample(50, time: 6.4)
check(glide.degreesPerSecond == 0 && glide.estimated(now: 6.5) == 50, "A sample after a long pause discards stale velocity before reversing")
print("Passed \(count) total behavior checks including screen adjustments and immediate activation")

// Fixed smooth transitions include both endpoints, not just intermediate angles.
check(BlurSettings.defaultSmoothing == 0.378, "The owner-selected default is 378 ms")
for rate in [60.0, 120.0] {
    var increasing = 0.0
    var decreasing = 1.0
    var continuous = true
    for _ in 0..<Int(rate * 0.3) {
        let up = BlurMath.follow(increasing, toward: 1, elapsed: 1 / rate, duration: 0.300)
        let down = BlurMath.follow(decreasing, toward: 0, elapsed: 1 / rate, duration: 0.300)
        continuous = continuous && up > increasing && up < 1 && down < decreasing && down > 0
        increasing = up; decreasing = down
    }
    check(continuous, "Clear and black endpoints retain every intermediate frame at \(Int(rate)) Hz")
    check(abs(increasing - 0.95021293) < 0.000001 && abs(decreasing - 0.04978707) < 0.000001, "Both directions complete about 95% of the change at the 300 ms minimum")
    let turned = BlurMath.follow(increasing, toward: 0, elapsed: 1 / rate, duration: 0.300)
    check(turned > 0 && turned < increasing, "Mid-animation reversal starts from the visible position on the next frame")
    for _ in 0..<Int(rate) {
        increasing = BlurMath.follow(increasing, toward: 1, elapsed: 1 / rate, duration: 0.300)
        decreasing = BlurMath.follow(decreasing, toward: 0, elapsed: 1 / rate, duration: 0.300)
    }
    check(increasing == 1 && decreasing == 0, "Both endpoints settle exactly so idle rendering can stop")
}
check(BlurMath.follow(0.2, toward: 1, elapsed: 0, duration: 0.300) == 0.2 && BlurMath.follow(0.8, toward: 0, elapsed: -1, duration: 0.300) == 0.8, "Endpoints cannot jump without elapsed time")
var captureEntry = FoldPresentation()
for _ in 0..<120 { captureEntry.update(target: 1, elapsed: 1 / 120, snapshotReady: false) }
check(captureEntry.progress == 0 && captureEntry.entryOpacity == 0, "Even a slow capture cannot accumulate invisible animation progress")
captureEntry.update(target: 0.6, elapsed: 1 / 120, snapshotReady: true)
check(captureEntry.progress > 0 && captureEntry.progress < 0.1, "First captured frame eases from clear toward the latest target")
check(captureEntry.entryOpacity > 0 && captureEntry.entryOpacity < 0.2, "First captured frame blends in instead of appearing fully opaque")
captureEntry.update(target: 0, elapsed: 1 / 120, snapshotReady: true)
check(captureEntry.progress > 0 && captureEntry.progress < 0.1, "Reopening during entry fades from the current visible fold")
captureEntry.update(target: 1, elapsed: 1 / 120, snapshotReady: false)
check(captureEntry.progress == 0 && captureEntry.entryOpacity == 0, "Losing or clearing the snapshot resets presentation state")
var zeroLegacy = BlurSettings()
zeroLegacy.smoothing = 0
var slowLegacy = zeroLegacy
slowLegacy.smoothing = 0.6
var quickPreview = LidPreviewSimulation()
var oldSlowPreview = LidPreviewSimulation()
quickPreview.reset(angle: 110, time: 0)
oldSlowPreview.reset(angle: 110, time: 0)
for frame in 1...120 {
    let angle = frame < 60 ? 30.0 : 110.0
    quickPreview.update(angle: angle, time: Double(frame) / 120, settings: zeroLegacy)
    oldSlowPreview.update(angle: angle, time: Double(frame) / 120, settings: slowLegacy)
}
check(quickPreview.progress < oldSlowPreview.progress, "Lower smoothing follows reopening more closely than higher smoothing")
check(zeroLegacy.smoothing == 0 && slowLegacy.smoothing == 0.6, "Preview rendering does not mutate input preferences")
check(migrated.smoothing == 0.378, "Old smoothing semantics migrate to the chosen 378 ms default")
var chosenResponse = BlurSettings()
chosenResponse.smoothing = 0.357
let restoredResponse = try JSONDecoder().decode(BlurSettings.self, from: JSONEncoder().encode(chosenResponse))
check(restoredResponse.smoothing == 0.357, "A chosen millisecond value survives save and restart without remigration")
let oldResponse = try JSONDecoder().decode(BlurSettings.self, from: Data(#"{"smoothing":0.4121819750134256,"radius":77.9,"clearAtAngle":94,"adjustmentAllowance":5}"#.utf8))
check(oldResponse.smoothing == 0.378 && oldResponse.radius == 77.9 && oldResponse.clearAtAngle == 94 && oldResponse.adjustmentAllowance == 5, "Migration preserves appearance and thresholds without reviving the ignored old timing")
for duration in [0.3, 0.378, 0.45, 0.6] {
    let rising = BlurMath.follow(0, toward: 1, elapsed: 1 / 120, duration: duration)
    let falling = BlurMath.follow(1, toward: 0, elapsed: 1 / 120, duration: duration)
    check(rising > 0 && rising < 1 && abs(rising + falling - 1) < 0.000001, "Every slider speed starts immediately and keeps symmetric smooth endpoints")
    check(abs(BlurMath.follow(0, toward: 1, elapsed: duration, duration: duration) - 0.95021293) < 0.000001, "Selected milliseconds describe 95% response time")
    var simulated = LidPreviewSimulation()
    var presentation = FoldPresentation()
    var motion = LidMotion()
    var selected = BlurSettings()
    selected.smoothing = duration
    simulated.reset(angle: 110, time: 0)
    motion.setOpenAngle(110, time: 0)
    var matches = true
    for tick in 1...360 {
        let time = Double(tick) / 60
        let angle = LidPreviewMath.demoAngle(elapsed: time, reference: 110, closed: 30)
        let target = motion.target(angle: angle, time: time, settings: selected)
        presentation.update(target: target, elapsed: 1 / 60, snapshotReady: true, duration: duration)
        simulated.update(angle: angle, time: time, settings: selected)
        matches = matches && abs(presentation.progress - simulated.progress) < 0.000001
    }
    check(matches, "Desktop and miniature use the selected timing through an entire cycle")
}
var clampedResponse = BlurSettings()
clampedResponse.smoothing = 0; clampedResponse.validate()
check(clampedResponse.smoothing == 0.3, "The slider's minimum retains smoothing rather than reintroducing snaps")
clampedResponse.smoothing = 99; clampedResponse.validate()
check(clampedResponse.smoothing == 0.6, "Invalid excessive timing is bounded")
let beforeRetime = BlurMath.follow(0.4, toward: 1, elapsed: 1 / 120, duration: 0.6)
let afterRetime = BlurMath.follow(beforeRetime, toward: 1, elapsed: 1 / 120, duration: 0.3)
check(afterRetime > beforeRetime && afterRetime < 1, "Changing speed mid-animation continues from the visible position without reset")
print("Passed \(count) total behavior checks including adjustable smoothing, migration and capture entry")
check(abs(BlurMath.follow(0, toward: 1, elapsed: 0.378) - 0.95021293) < 0.000001, "Default follower completes 95 percent in the chosen 378 ms")
check(BlurSettings().smoothing == 0.378, "Reset settings uses the owner-selected smoothing default")
print("Passed \(count) total behavior checks including the 378 ms default")
let idlePreview = LidPreviewDriver()
idlePreview.reset(angle: 110, time: 0)
var idleInvalidations = 0
for frame in 1...600 {
    if idlePreview.update(angle: 110, time: Double(frame) / 60, settings: BlurSettings()) { idleInvalidations += 1 }
}
check(idleInvalidations == 0, "Ten seconds of an idle preview publishes no visual changes")
check(idlePreview.motion.openAngle == 110, "Silent preview updates still maintain the resting reference")
check(idlePreview.update(angle: 80, time: 10.1, settings: BlurSettings()), "Moving the independent preview still publishes a changed frame")
check(idlePreview.progress > 0, "Independent preview retains animated progress")
idlePreview.reset(angle: 110, time: 11)
check(idlePreview.progress == 0, "Explicit preview reset restores a clear frame")
print("Passed \(count) total behavior checks including idle preview invalidation")
var personalized = BlurSettings()
personalized.smoothing = 0.378
personalized.clearAtAngle = 102
personalized.adjustmentAllowance = 12
personalized.launchAtLogin = true
personalized.enabled = false
for preset in FoldPreset.allCases {
    personalized.selectPreset(preset)
    check(personalized.appearance == preset.original && !personalized.presetIsModified, "Each untouched preset loads its complete original appearance")
    personalized.radius += 1
    personalized.dimming += 0.01
    personalized.duoStyle = false
    personalized.borderDepth = 0.42
    personalized.progressiveBlur = false
    let customized = personalized.appearance
    check(personalized.presetIsModified, "Editing a selected preset marks it modified")
    personalized.savePresetDefault()
    check(!personalized.presetIsModified, "Saving makes the current look that preset's default")
    let other: FoldPreset = preset == .duo ? .subtle : .duo
    personalized.selectPreset(other)
    personalized.selectPreset(preset)
    check(personalized.appearance == customized, "Returning to every preset recalls all five customized appearance controls")
    let disk = try JSONDecoder().decode(BlurSettings.self, from: JSONEncoder().encode(personalized))
    check(disk == personalized, "Preset selection and defaults survive a complete persistence round trip")
    check(personalized.smoothing == 0.378 && personalized.clearAtAngle == 102 && personalized.adjustmentAllowance == 12 && personalized.launchAtLogin && !personalized.enabled, "Presets preserve motion, smoothing, login and enablement")
}
check(personalized.presetDefaults.count == 4, "Every preset owns an independent saved default")
let savedDuo = personalized.presetDefaults[FoldPreset.duo.rawValue]
personalized.selectPreset(.duo)
personalized.radius = 79
personalized.selectPreset(.subtle)
personalized.selectPreset(.duo)
check(personalized.appearance == savedDuo, "Unsaved edits do not silently overwrite a preset default")
let remaining = personalized.presetDefaults.filter { $0.key != FoldPreset.duo.rawValue }
personalized.restoreOriginalPreset()
check(personalized.presetDefaults == remaining && personalized.appearance == FoldPreset.duo.original, "Restore original resets only the selected preset")
check(personalized.smoothing == 0.378 && personalized.clearAtAngle == 102, "Restoring an original appearance preserves lid behavior")
let oldCustom = try JSONDecoder().decode(BlurSettings.self, from: Data(#"{"radius":55,"dimming":0.23,"smoothing":0.378,"smoothingResponseVersion":1}"#.utf8))
check(oldCustom.radius == 55 && oldCustom.selectedPreset == nil && oldCustom.presetDefaults.isEmpty, "Upgrade preserves an existing custom look without assigning or saving a preset")
let oldBalanced = try JSONDecoder().decode(BlurSettings.self, from: Data(#"{"radius":36,"dimming":0.2}"#.utf8))
check(oldBalanced.selectedPreset == .balanced, "Upgrade recognizes an exact factory appearance without changing it")
let unknownPreset = try JSONDecoder().decode(BlurSettings.self, from: Data(#"{"radius":55,"selectedPreset":"Future"}"#.utf8))
check(unknownPreset.radius == 55 && unknownPreset.selectedPreset == nil, "An unknown preset selection does not discard the user's settings")
let belowMinimum = try JSONDecoder().decode(BlurSettings.self, from: Data(#"{"smoothing":0.12,"smoothingResponseVersion":1,"radius":55}"#.utf8))
check(belowMinimum.smoothing == 0.3 && belowMinimum.radius == 55, "Existing sub-300 ms settings move to the new minimum without changing appearance")
check(BlurSettings.smoothingRange == 0.3...0.6 && BlurSettings.defaultSmoothing == 0.378, "Smoothing starts at 300 ms while the chosen 378 ms default remains unchanged")
print("Passed \(count) total behavior checks including saved presets and 300 ms minimum")
