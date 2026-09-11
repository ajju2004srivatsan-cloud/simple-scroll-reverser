import Foundation
import IOKit.hid

/// Watches attached pointer devices and records which one last produced a
/// scroll-like HID value. The CGEvent tap reads that hint to distinguish a
/// Magic Mouse from a trackpad.
final class HIDDeviceMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var manager: IOHIDManager?
    private var kindsByDevice = [UnsafeMutableRawPointer: DeviceKind]()
    private var lastKind: DeviceKind?
    private var lastKindUptime: TimeInterval = 0
    private var started = false

    func start() {
        lock.lock()
        if started {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, Self.matchingCriteria())

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.deviceAdded, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.deviceRemoved, context)
        IOHIDManagerRegisterInputValueCallback(manager, Self.inputValue, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        // Already-attached matching devices are reported through `deviceAdded`.
        // Do not walk IOHIDManagerCopyDevices() via NSSet: IOHIDDevice is a CF
        // type, so `as?` / `as` from `Any` fail on current Xcode (either
        // "always succeeds" or "'Any' is not convertible").

        lock.lock()
        self.manager = manager
        lock.unlock()
    }

    func stop() {
        lock.lock()
        let manager = self.manager
        self.manager = nil
        started = false
        kindsByDevice.removeAll()
        lastKind = nil
        lock.unlock()

        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    /// Most recently active scroll device, if the HID report is still fresh.
    func recentScrollKind(maxAge: TimeInterval = 0.25) -> DeviceKind? {
        lock.lock()
        defer { lock.unlock() }
        guard let lastKind else { return nil }
        let age = ProcessInfo.processInfo.systemUptime - lastKindUptime
        return age <= maxAge ? lastKind : nil
    }

    fileprivate func remember(_ device: IOHIDDevice) {
        let kind = classify(device)
        let id = Unmanaged.passUnretained(device).toOpaque()
        lock.lock()
        kindsByDevice[id] = kind
        lock.unlock()
    }

    fileprivate func forget(_ device: IOHIDDevice) {
        let id = Unmanaged.passUnretained(device).toOpaque()
        lock.lock()
        kindsByDevice.removeValue(forKey: id)
        lock.unlock()
    }

    fileprivate func noteInput(from device: IOHIDDevice, usagePage: UInt32, usage: UInt32) {
        guard Self.isScrollLike(usagePage: usagePage, usage: usage) else { return }
        let id = Unmanaged.passUnretained(device).toOpaque()
        lock.lock()
        let kind = kindsByDevice[id] ?? classify(device)
        kindsByDevice[id] = kind
        lastKind = kind
        lastKindUptime = ProcessInfo.processInfo.systemUptime
        lock.unlock()
    }

    private func classify(_ device: IOHIDDevice) -> DeviceKind {
        let product = stringProperty(device, kIOHIDProductKey as CFString) ?? ""
        let builtIn = boolProperty(device, "Built-In" as CFString)
        let touchPad = IOHIDDeviceConformsTo(device, HIDUsage.pageDigitizer, HIDUsage.touchPad)
        let mouse = IOHIDDeviceConformsTo(device, HIDUsage.pageGenericDesktop, HIDUsage.mouse)
        return DeviceClassifier.kind(
            productName: product,
            builtIn: builtIn,
            conformsToTouchPad: touchPad,
            conformsToMouse: mouse
        )
    }

    private func stringProperty(_ device: IOHIDDevice, _ key: CFString) -> String? {
        IOHIDDeviceGetProperty(device, key) as? String
    }

    private func boolProperty(_ device: IOHIDDevice, _ key: CFString) -> Bool {
        if let number = IOHIDDeviceGetProperty(device, key) as? NSNumber {
            return number.boolValue
        }
        return false
    }

    private static func matchingCriteria() -> NSArray {
        [
            [
                kIOHIDDeviceUsagePageKey: NSNumber(value: HIDUsage.pageGenericDesktop),
                kIOHIDDeviceUsageKey: NSNumber(value: HIDUsage.mouse)
            ] as NSDictionary,
            [
                kIOHIDDeviceUsagePageKey: NSNumber(value: HIDUsage.pageGenericDesktop),
                kIOHIDDeviceUsageKey: NSNumber(value: HIDUsage.pointer)
            ] as NSDictionary,
            [
                kIOHIDDeviceUsagePageKey: NSNumber(value: HIDUsage.pageDigitizer),
                kIOHIDDeviceUsageKey: NSNumber(value: HIDUsage.touchPad)
            ] as NSDictionary
        ]
    }

    private static func isScrollLike(usagePage: UInt32, usage: UInt32) -> Bool {
        if usagePage == HIDUsage.pageGenericDesktop {
            return usage == HIDUsage.wheel || usage == HIDUsage.z
        }
        if usagePage == HIDUsage.pageConsumer {
            return usage == HIDUsage.acPan
        }
        if usagePage == HIDUsage.pageDigitizer {
            return true
        }
        return false
    }

    private static let deviceAdded: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue().remember(device)
    }

    private static let deviceRemoved: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue().forget(device)
    }

    private static let inputValue: IOHIDValueCallback = { context, _, _, value in
        guard let context else { return }
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            .noteInput(from: device, usagePage: usagePage, usage: usage)
    }
}

private enum HIDUsage {
    static let pageGenericDesktop: UInt32 = 0x01
    static let mouse: UInt32 = 0x02
    static let pointer: UInt32 = 0x01
    static let z: UInt32 = 0x32
    static let wheel: UInt32 = 0x38
    static let pageDigitizer: UInt32 = 0x0D
    static let touchPad: UInt32 = 0x05
    static let pageConsumer: UInt32 = 0x0C
    static let acPan: UInt32 = 0x0238
}
