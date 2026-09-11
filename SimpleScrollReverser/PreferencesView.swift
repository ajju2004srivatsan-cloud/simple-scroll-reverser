import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if model.permissions.needsAttention {
                permissionSection
            }
            scrollingSection
            generalSection
            footer
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppIdentity.displayName)
                    .font(.title2.weight(.semibold))
                Text(statusLine)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
        }
    }

    private var statusLine: String {
        if !model.permissions.accessibilityTrusted {
            return "Waiting for Accessibility permission"
        }
        if !model.settings.enabled {
            return "Paused"
        }
        if let device = model.lastDeviceLabel {
            return "On — last scroll: \(device)"
        }
        return "On"
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.permissions.accessibilityTrusted {
                PermissionBanner(
                    title: "Accessibility is required",
                    detail: "macOS will not let this app invert scroll events until it is allowed in Privacy & Security → Accessibility. Add Simple Scroll Reverser, then toggle Enable.",
                    buttonTitle: "Open Accessibility Settings",
                    action: { model.requestAccessibility() }
                )
            }
            if !model.permissions.inputMonitoringTrusted {
                PermissionBanner(
                    title: "Input Monitoring is recommended",
                    detail: "On recent macOS versions, Input Monitoring is also requested so HID scroll events can be observed. Grant it if scrolling is not reversed after Accessibility is on.",
                    buttonTitle: "Open Input Monitoring Settings",
                    action: { model.requestInputMonitoring() }
                )
            }
        }
    }

    private var scrollingSection: some View {
        GroupBox("Scrolling") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable Scroll Reverser", isOn: enabledBinding)
                    .disabled(!model.permissions.canInstallEventTap)
                Divider()
                Toggle("Reverse mouse", isOn: mouseBinding)
                Text("Includes USB/Bluetooth mice and Magic Mouse when it can be detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Reverse trackpad", isOn: trackpadBinding)
                Divider()
                Toggle("Reverse vertical", isOn: verticalBinding)
                Toggle("Reverse horizontal", isOn: horizontalBinding)
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Wheel step size")
                        Spacer()
                        Text(wheelStepLabel)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: wheelStepBinding,
                        in: Double(AppSettings.wheelStepSizeRange.lowerBound)...Double(AppSettings.wheelStepSizeRange.upperBound),
                        step: 1
                    )
                    Text(model.hasSeenDiscreteWheel
                         ? "A discrete scroll wheel was detected. System default keeps macOS acceleration."
                         : "Applies only to discrete (clicky) scroll wheels. System default keeps macOS acceleration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var generalSection: some View {
        GroupBox("General") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Start at login", isOn: loginBinding)
                if let hint = model.loginItemHint {
                    HStack(alignment: .top, spacing: 8) {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Login Items") {
                            model.openLoginItemsSettings()
                        }
                        .font(.caption)
                    }
                }
                Text("Recommended: leave System Settings → Trackpad → Natural scrolling on, enable Reverse mouse, and leave Reverse trackpad off. That keeps gestures natural while giving a classic wheel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var footer: some View {
        HStack {
            Text("Version \(Bundle.main.shortVersionString)  ·  \(AppIdentity.bundleID)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Check Permissions") {
                model.refreshPermissions()
            }
            .controlSize(.small)
        }
    }

    private var wheelStepLabel: String {
        model.settings.wheelStepSize == 0 ? "System default" : "\(model.settings.wheelStepSize) lines"
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { model.settings.enabled }, set: { model.setEnabled($0) })
    }

    private var mouseBinding: Binding<Bool> {
        Binding(get: { model.settings.reverseMouse }, set: { model.setReverseMouse($0) })
    }

    private var trackpadBinding: Binding<Bool> {
        Binding(get: { model.settings.reverseTrackpad }, set: { model.setReverseTrackpad($0) })
    }

    private var verticalBinding: Binding<Bool> {
        Binding(get: { model.settings.reverseVertical }, set: { model.setReverseVertical($0) })
    }

    private var horizontalBinding: Binding<Bool> {
        Binding(get: { model.settings.reverseHorizontal }, set: { model.setReverseHorizontal($0) })
    }

    private var loginBinding: Binding<Bool> {
        Binding(get: { model.loginItemEnabled }, set: { model.setStartAtLogin($0) })
    }

    private var wheelStepBinding: Binding<Double> {
        Binding(
            get: { Double(model.settings.wheelStepSize) },
            set: { model.setWheelStepSize(Int($0.rounded())) }
        )
    }
}

private struct PermissionBanner: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle, action: action)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35))
        )
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
