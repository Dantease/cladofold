import Foundation
import IOKit.hid

/// Only matches Apple's orientation sensor; never opens keyboard or mouse devices.
final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private(set) var status = "Searching for lid sensor"

    func connect() {
        disconnect()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDDeviceUsagePageKey: 0x0020,
            kIOHIDDeviceUsageKey: 0x008A
        ] as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            status = "No compatible lid sensor found"
            return
        }
        for candidate in devices {
            guard IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { continue }
            device = candidate
            if read() != nil { status = "Lid sensor connected"; return }
            IOHIDDeviceClose(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
            device = nil
        }
        status = "Lid sensor unavailable"
    }

    func read() -> Double? {
        guard let device else { return nil }
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess else { return nil }
        return BlurMath.decodeLidReport(Array(report.prefix(length)))
    }

    func disconnect() {
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        manager = nil
    }

    deinit { disconnect() }
}
