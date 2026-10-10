import Foundation

/// Blocking HID calls never run on the UI or rendering thread.
final class SensorMonitor {
    private struct Sample {
        let angle: Double?
        let message: String
        let time: Double
    }

    private let queue = DispatchQueue(label: "com.dante.Foldable.sensor", qos: .userInitiated)
    private let sensor = LidSensor()
    private let mailbox = LatestSampleMailbox<Sample>()
    private var timer: DispatchSourceTimer?
    private var lastReconnect = Date.distantPast
    var onSample: ((Double?, String, Double) -> Void)?

    func start() {
        timer?.cancel()
        let generation = mailbox.start()
        queue.async { [weak self] in self?.lastReconnect = .distantPast }
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
            let sample = Sample(angle: angle, message: self.sensor.status, time: Date.timeIntervalSinceReferenceDate)
            guard self.mailbox.offer(sample, generation: generation) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let sample = self.mailbox.take(generation: generation) else { return }
                self.onSample?(sample.angle, sample.message, sample.time)
            }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        mailbox.stop()
        timer?.cancel()
        timer = nil
        queue.async { [sensor] in sensor.disconnect() }
    }
}
