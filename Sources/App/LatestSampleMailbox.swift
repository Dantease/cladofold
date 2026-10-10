import Foundation

/// Keeps one pending value while a consumer queue is busy. A generation also
/// makes queued deliveries harmless after the producer stops or restarts.
final class LatestSampleMailbox<Value> {
    private let lock = NSLock()
    private var generation = 0
    private var active = false
    private var deliveryScheduled = false
    private var pending: Value?

    func start() -> Int {
        lock.lock()
        defer { lock.unlock() }
        generation += 1
        active = true
        deliveryScheduled = false
        pending = nil
        return generation
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        generation += 1
        active = false
        deliveryScheduled = false
        pending = nil
    }

    /// Returns true only when the caller needs to enqueue a consumer callback.
    func offer(_ value: Value, generation request: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard active, request == generation else { return false }
        pending = value
        guard !deliveryScheduled else { return false }
        deliveryScheduled = true
        return true
    }

    func take(generation request: Int) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard active, request == generation else { return nil }
        let value = pending
        pending = nil
        deliveryScheduled = false
        return value
    }
}
