import Foundation

final class StatusObserver: NSObject {
    private var previous: String?
    @objc func receive(_ note: Notification) {
        guard let info = note.userInfo, let data = try? JSONSerialization.data(withJSONObject: info, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) else { return }
        guard text != previous else { return }
        previous = text
        print(text)
        fflush(stdout)
    }
}
let observer = StatusObserver()
DistributedNotificationCenter.default().addObserver(observer, selector: #selector(StatusObserver.receive(_:)), name: Notification.Name("com.dante.Foldable.status"), object: nil)
let duration = Double(CommandLine.arguments.dropFirst().first ?? "12") ?? 12
let boundedDuration = min(60, max(1, duration))
RunLoop.current.run(until: Date().addingTimeInterval(boundedDuration))
