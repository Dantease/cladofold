import Foundation

/// Blocking HID calls never run on the UI or rendering thread.
final class SensorMonitor {
    private let queue = DispatchQueue(label: "com.dante.Foldable.sensor", qos: .userInitiated)
    private let sensor = LidSensor()
    private var timer: DispatchSourceTimer?
    private var lastReconnect = Date.distantPast
    var onSample: ((Double?, String) -> Void)?

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            var angle = self.sensor.read()
            if angle == nil, Date().timeIntervalSince(self.lastReconnect) > 3 {
                self.lastReconnect = Date()
                self.sensor.connect()
                angle = self.sensor.read()
            }
            let message = self.sensor.status
            DispatchQueue.main.async { [weak self] in self?.onSample?(angle, message) }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        queue.async { [sensor] in sensor.disconnect() }
    }
}
