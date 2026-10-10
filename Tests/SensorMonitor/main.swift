import Foundation

var count = 0
func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else { fatalError("FAIL: \(description)") }
    count += 1
}

struct Sample: Equatable {
    let angle: Double
    let time: Double
}

let mailbox = LatestSampleMailbox<Sample>()
let first = mailbox.start()
var scheduledCallbacks = 0
// Simulate a blocked main queue while the sensor continues reporting at 60 Hz.
for frame in 0..<120 {
    if mailbox.offer(Sample(angle: Double(150 - frame), time: Double(frame) / 60), generation: first) {
        scheduledCallbacks += 1
    }
}
check(scheduledCallbacks == 1, "A stalled consumer has only one queued delivery")
check(mailbox.take(generation: first) == Sample(angle: 31, time: 119.0 / 60), "Delivery keeps only the newest angle and its original acquisition time")
check(mailbox.take(generation: first) == nil, "Old samples are not replayed after delivery")
check(mailbox.offer(Sample(angle: 30, time: 2), generation: first), "A delivered mailbox schedules the next sample")

mailbox.stop()
check(mailbox.take(generation: first) == nil, "A queued callback cannot deliver after stop")
check(!mailbox.offer(Sample(angle: 29, time: 2.1), generation: first), "An in-flight read cannot enqueue after stop")

let second = mailbox.start()
check(second != first, "Restart uses a new generation")
check(mailbox.offer(Sample(angle: 100, time: 3), generation: second), "Restart can schedule a fresh delivery")
check(mailbox.take(generation: first) == nil, "An old callback cannot consume a restarted sample")
check(!mailbox.offer(Sample(angle: 28, time: 2.2), generation: first), "An old producer cannot overwrite a restarted sample")
check(!mailbox.offer(Sample(angle: 101, time: 3.1), generation: second), "An old callback does not clear the current scheduling slot")
check(mailbox.take(generation: second) == Sample(angle: 101, time: 3.1), "Restart delivers only current samples")

check(mailbox.offer(Sample(angle: 102, time: 3.2), generation: second), "Current generation can enqueue again")
let third = mailbox.start()
check(mailbox.take(generation: second) == nil, "Starting twice invalidates the previous queued delivery")
check(mailbox.offer(Sample(angle: 110, time: 4), generation: third), "Starting twice leaves the new producer usable")
check(mailbox.take(generation: third) == Sample(angle: 110, time: 4), "The replacement producer delivers its sample")
print("Passed \(count) sensor delivery checks")
