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
    static let quarantineRemovalCommand = "xattr -cr \"/Applications/Simple Scroll Reverser.app\""

    /// Ask macOS to create the Accessibility and Input Monitoring rows for this
    /// process. The system prompt only appears when the process is not trusted.
    static func requestPrivacyListEntries() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        CGRequestListenEventAccess()
        ScrollEventTap.probeForTCC()
    }

    /// Privacy & Security root — where “Open Anyway” appears after a Gatekeeper block.
    static func openPrivacyAndSecurity() {
        openFirstWorking([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security",
            "x-apple.systempreferences:com.apple.preference.security?General"
        ])
    }

    static func openAccessibilityAndPrompt() {
        requestPrivacyListEntries()
        openFirstWorking([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ])
    }

    static func openInputMonitoringAndPrompt() {
        requestPrivacyListEntries()
        openFirstWorking([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
        ])
    }

    static func openLoginItems() {
        openFirstWorking([
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.users"
        ])
    }

    static func copyQuarantineCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(quarantineRemovalCommand, forType: .string)
    }

    @discardableResult
    private static func openFirstWorking(_ candidates: [String]) -> Bool {
        for string in candidates {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }
}
