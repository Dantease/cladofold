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
let first = access.begin()!
check(!access.ready && access.checking, "A pending check does not enable the overlay")
check(access.begin() == nil, "Concurrent permission checks are coalesced")
check(access.fail(denial, request: first) && access.state == .needsPermission, "TCC denial gets actionable permission guidance")
check(!access.ready && access.detail == nil, "A denial cannot retain verified access or expose a raw TCC error")
check(!access.succeed(first), "A late success cannot overwrite a denial")
let retry = access.begin()!
check(access.succeed(retry) && access.ready, "A successful retry recovers without restarting")
access.fail(denial)
check(!access.ready && access.state == .needsPermission, "Revocation during a fold disables further capture attempts")
let beforeSleep = access.begin()!
access.invalidate()
check(!access.succeed(beforeSleep), "Sleep or display changes invalidate unfinished permission checks")
let afterWake = access.begin()!
check(!access.fail(denial, request: beforeSleep) && access.checking, "A stale failure cannot overwrite the wake check")
access.cancel(beforeSleep)
check(access.checking, "A cancelled older check cannot cancel a newer check")
check(access.succeed(afterWake), "The current wake check can recover")
access.fail(failure)
check(access.state == .unavailable && access.detail == "No built-in display", "Display or renderer failures do not blame permission")
let cancelled = access.begin()!
access.cancel(cancelled)
check(!access.checking && !access.ready, "A cancelled current check does not get stuck")
print("Passed \(count) capture recovery checks")
