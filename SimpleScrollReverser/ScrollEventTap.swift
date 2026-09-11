import Foundation
import CoreGraphics

/// Intercepts HID scroll-wheel events and inverts selected axes in place.
final class ScrollEventTap: @unchecked Sendable {
    var onDiscreteWheel: (() -> Void)?
    var onDeviceKind: ((DeviceKind) -> Void)?

    private let lock = NSLock()
    private let stopped = DispatchSemaphore(value: 0)
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private var hidMonitor: HIDDeviceMonitor?
    private var running = false
    private var reportedDiscreteWheel = false
    private var lastPostedKind: DeviceKind?

    func start(deviceMonitor: HIDDeviceMonitor) {
        lock.lock()
        hidMonitor = deviceMonitor
        if running {
            lock.unlock()
            return
        }
        running = true
        lock.unlock()

        let thread = Thread { [weak self] in
            self?.runTapThread()
        }
        thread.name = "SimpleScrollReverser.EventTap"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
    }

    func stop() {
        lock.lock()
        let wasRunning = running
        running = false
        let loop = runLoop
        lock.unlock()
        guard wasRunning else { return }
        if let loop {
            CFRunLoopStop(loop)
        }
        _ = stopped.wait(timeout: .now() + 1.0)
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reenable()
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        let settings = SettingsStore.shared.current
        guard settings.enabled else {
            return Unmanaged.passUnretained(event)
        }

        let signals = DeviceClassifier.signals(from: event)
        if !signals.isContinuous {
            noteDiscreteWheel()
        }

        let hidHint = hidMonitor?.recentScrollKind()
        let kind = DeviceClassifier.kind(from: signals, hidHint: hidHint)
        noteKind(kind)

        let reverseDevice = (kind == .mouse && settings.reverseMouse)
            || (kind == .trackpad && settings.reverseTrackpad)
        guard reverseDevice, settings.reverseVertical || settings.reverseHorizontal else {
            applyWheelStepIfNeeded(event, settings: settings, signals: signals)
            return Unmanaged.passUnretained(event)
        }

        if settings.reverseVertical {
            invert(event, line: .scrollWheelEventDeltaAxis1, point: .scrollWheelEventPointDeltaAxis1, fixed: .scrollWheelEventFixedPtDeltaAxis1)
        }
        if settings.reverseHorizontal {
            invert(event, line: .scrollWheelEventDeltaAxis2, point: .scrollWheelEventPointDeltaAxis2, fixed: .scrollWheelEventFixedPtDeltaAxis2)
        }

        applyWheelStepIfNeeded(event, settings: settings, signals: signals)
        return Unmanaged.passUnretained(event)
    }

    func handleWake() {
        lock.lock()
        let tap = self.tap
        let monitor = hidMonitor
        lock.unlock()

        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        if let tap, CGEvent.tapIsEnabled(tap: tap) {
            return
        }
        guard let monitor else { return }
        stop()
        start(deviceMonitor: monitor)
    }

    private func invert(_ event: CGEvent, line: CGEventField, point: CGEventField, fixed: CGEventField) {
        event.setIntegerValueField(line, value: -event.getIntegerValueField(line))
        event.setIntegerValueField(point, value: -event.getIntegerValueField(point))
        event.setDoubleValueField(fixed, value: -event.getDoubleValueField(fixed))
    }

    private func applyWheelStepIfNeeded(_ event: CGEvent, settings: AppSettings, signals: DeviceClassifier.EventSignals) {
        guard !signals.isContinuous, settings.wheelStepSize > 0 else { return }
        let lines = Int64(settings.wheelStepSize)
        let vertical = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        if vertical != 0 {
            let sign: Int64 = vertical > 0 ? 1 : -1
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: sign * lines)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Double(sign * lines))
        }
        let horizontal = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        if horizontal != 0 {
            let sign: Int64 = horizontal > 0 ? 1 : -1
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: sign * lines)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Double(sign * lines))
        }
    }

    private func noteDiscreteWheel() {
        lock.lock()
        let already = reportedDiscreteWheel
        reportedDiscreteWheel = true
        lock.unlock()
        if !already {
            onDiscreteWheel?()
        }
    }

    private func noteKind(_ kind: DeviceKind) {
        lock.lock()
        let changed = lastPostedKind != kind
        lastPostedKind = kind
        lock.unlock()
        if changed {
            onDeviceKind?(kind)
        }
    }

    private func reenable() {
        lock.lock()
        let tap = self.tap
        lock.unlock()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func runTapThread() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollTapCallback,
            userInfo: userInfo
        ) else {
            lock.lock()
            running = false
            lock.unlock()
            stopped.signal()
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            lock.lock()
            running = false
            lock.unlock()
            stopped.signal()
            return
        }

        let loop = CFRunLoopGetCurrent()
        lock.lock()
        self.tap = tap
        self.runLoop = loop
        lock.unlock()

        CFRunLoopAddSource(loop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()

        CFRunLoopRemoveSource(loop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)

        lock.lock()
        self.tap = nil
        self.runLoop = nil
        self.thread = nil
        self.running = false
        lock.unlock()
        stopped.signal()
    }
}

private func scrollTapCallback(
    _ proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let tap = Unmanaged<ScrollEventTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
