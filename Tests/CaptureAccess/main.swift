import Foundation
import ScreenCaptureKit

var count = 0
func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else { fatalError("FAIL: \(description)") }
    count += 1
}
let denial = NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue)
let failure = NSError(domain: "Renderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No built-in display"])
var access = CaptureAccess()
check(!access.ready, "Starting the app does not imply capture is available")
let first = access.begin(preflightGranted: true)!
check(!access.ready && access.checking, "A pending check does not enable the overlay")
check(access.begin(preflightGranted: true) == nil, "Concurrent permission checks are coalesced")
check(access.fail(denial, request: first) && access.state == .needsPermission, "TCC denial gets actionable permission guidance")
check(!access.ready && access.detail == nil, "A denial cannot retain verified access or expose a raw TCC error")
check(!access.succeed(first), "A late success cannot overwrite a denial")
let retry = access.begin(preflightGranted: true, userInitiated: true)!
check(access.succeed(retry) && access.ready, "A successful retry recovers without restarting")
access.fail(denial)
check(!access.ready && access.state == .needsPermission, "Revocation during a fold disables further capture attempts")
let beforeSleep = access.begin(preflightGranted: true, userInitiated: true)!
access.invalidate()
check(!access.succeed(beforeSleep), "Sleep or display changes invalidate unfinished permission checks")
let afterWake = access.begin(preflightGranted: true, userInitiated: true)!
check(!access.fail(denial, request: beforeSleep) && access.checking, "A stale failure cannot overwrite the wake check")
access.cancel(beforeSleep)
check(access.checking, "A cancelled older check cannot cancel a newer check")
check(access.succeed(afterWake), "The current wake check can recover")
access.fail(failure)
check(access.state == .unavailable && access.detail == "No built-in display", "Display or renderer failures do not blame permission")
let cancelled = access.begin(preflightGranted: true, userInitiated: true)!
access.cancel(cancelled)
check(!access.checking && !access.ready, "A cancelled current check does not get stuck")

var quiet = CaptureAccess()
check(quiet.begin(preflightGranted: false) == nil, "Launching with denied preflight never requests capture")
check(!quiet.checking, "A skipped automatic check leaves no pending task")
let permitted = quiet.begin(preflightGranted: true)!
quiet.fail(denial, request: permitted)
check(quiet.automaticChecksBlocked, "A denied real capture latches automatic checks off")
var automaticRequests = 0
for _ in 0..<20 {
    // Activation, display changes and wake events cannot restart a denied API.
    quiet.invalidate()
    if quiet.begin(preflightGranted: true) != nil { automaticRequests += 1 }
}
check(automaticRequests == 0, "Repeated activation/wake events cannot create a permission prompt loop")
var relaunched = CaptureAccess(automaticChecksBlocked: quiet.automaticChecksBlocked)
check(relaunched.begin(preflightGranted: true) == nil, "The persisted failure latch survives relaunch with stale preflight")
let manual = relaunched.begin(preflightGranted: false, userInitiated: true)!
check(relaunched.checking, "An explicit Check again can probe a false preflight once")
check(relaunched.begin(preflightGranted: false, userInitiated: true) == nil, "Rapid manual clicks cannot duplicate the pending request")
relaunched.succeed(manual)
check(relaunched.ready && !relaunched.automaticChecksBlocked, "Successful verification restores normal operation")
relaunched.invalidate()
check(relaunched.begin(preflightGranted: true) != nil, "A working app can prepare again after wake")
relaunched.fail(denial)
relaunched.permissionChanged()
check(!relaunched.automaticChecksBlocked && relaunched.begin(preflightGranted: true) != nil, "A newly granted OS permission permits one automatic check")
relaunched.fail(denial)
check(relaunched.begin(preflightGranted: true) == nil, "If that new check fails, automatic retries stop again")
print("Passed \(count) capture recovery and prompt-loop checks")
