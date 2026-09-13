import Foundation
import ScreenCaptureKit

/// A preflight flag or a working lid sensor cannot prove that a frame can be
/// captured. Only the installed app's successful capture check marks it ready.
struct CaptureAccess {
    enum State: String { case unverified, checking, ready, needsPermission, unavailable }
    private(set) var state = State.unverified
    private(set) var detail: String?
    private(set) var automaticChecksBlocked: Bool
    private var generation = 0
    var ready: Bool { state == .ready }
    var checking: Bool { state == .checking }
    func isCurrent(_ request: Int) -> Bool { request == generation && checking }

    init(automaticChecksBlocked: Bool = false) {
        self.automaticChecksBlocked = automaticChecksBlocked
    }

    mutating func begin(preflightGranted: Bool, userInitiated: Bool = false) -> Int? {
        // Calling ScreenCaptureKit can itself display a system prompt. A past
        // request is not permission to keep calling it after macOS denies access.
        guard !checking, userInitiated || (preflightGranted && !automaticChecksBlocked) else { return nil }
        generation += 1
        state = .checking
        detail = nil
        return generation
    }

    @discardableResult mutating func succeed(_ request: Int) -> Bool {
        guard isCurrent(request) else { return false }
        state = .ready
        automaticChecksBlocked = false
        detail = nil
        return true
    }

    @discardableResult mutating func fail(_ error: Error, request: Int? = nil) -> Bool {
        if let request, request != generation || !checking { return false }
        generation += 1
        automaticChecksBlocked = true
        let failure = error as NSError
        let denied = failure.domain == SCStreamErrorDomain &&
            failure.code == SCStreamError.Code.userDeclined.rawValue
        state = denied ? .needsPermission : .unavailable
        detail = denied ? nil : error.localizedDescription
        return true
    }

    mutating func invalidate() {
        generation += 1
        state = .unverified
        detail = nil
    }

    mutating func permissionChanged() {
        // Only a newly observed false-to-true preflight transition permits an
        // automatic retry. Sleep, activation and relaunch keep the failure latch.
        automaticChecksBlocked = false
        invalidate()
    }

    mutating func cancel(_ request: Int) {
        if request == generation, checking { invalidate() }
    }

    var message: String? {
        switch state {
        case .unverified: return "Screen access needs a check"
        case .checking: return "Checking screen access…"
        case .ready: return nil
        case .needsPermission: return "macOS has not authorized this copy of cladofold."
        case .unavailable: return detail ?? "The desktop animation could not start"
        }
    }
}
