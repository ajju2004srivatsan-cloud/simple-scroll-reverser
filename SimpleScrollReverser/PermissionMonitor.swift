import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

struct PermissionState: Equatable, Sendable {
    var accessibilityTrusted: Bool
    var inputMonitoringTrusted: Bool

    /// A modifying HID tap requires Accessibility. Input Monitoring is also
    /// requested on modern macOS and is treated as required when the OS reports it.
    var canInstallEventTap: Bool { accessibilityTrusted }

    var needsAttention: Bool { !accessibilityTrusted || !inputMonitoringTrusted }
}

final class PermissionMonitor: @unchecked Sendable {
    private var timer: Timer?
    private var callback: ((PermissionState) -> Void)?
    private var lastState: PermissionState?
    private var activeObserver: NSObjectProtocol?

    static func currentState() -> PermissionState {
        PermissionState(
            accessibilityTrusted: AXIsProcessTrusted(),
            inputMonitoringTrusted: CGPreflightListenEventAccess()
        )
    }

    func start(onChange: @escaping (PermissionState) -> Void) {
        stop()
        callback = onChange
        lastState = Self.currentState()
        onChange(lastState!)

        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
        callback = nil
    }

    private func poll() {
        let state = Self.currentState()
        if state != lastState {
            lastState = state
            callback?(state)
        }
    }
}

enum PrivacySettingsOpener {
    static func openAccessibilityAndPrompt() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"))
    }

    static func openInputMonitoringAndPrompt() {
        CGRequestListenEventAccess()
        open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"))
    }

    static func openLoginItems() {
        open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"))
    }

    private static func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
