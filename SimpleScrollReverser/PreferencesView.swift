import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 196)
            Divider()
            detail
                .frame(minWidth: 400)
        }
        .frame(minWidth: 620, idealWidth: 640, minHeight: 500, idealHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollDoodleView(
                reverseMouse: model.settings.reverseMouse && model.settings.enabled,
                reverseTrackpad: model.settings.reverseTrackpad && model.settings.enabled,
                enabled: model.settings.enabled && model.permissions.canInstallEventTap,
                lastDevice: model.lastDeviceLabel
            )
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppIdentity.displayName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.permissions.needsAttention {
                Label("Permissions needed", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(Bundle.main.shortVersionString)")
                Text(AppIdentity.bundleID)
                    .textSelection(.enabled)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
        .accessibilityElement(children: .contain)
    }

    private var detail: some View {
        Form {
            if model.permissions.needsAttention {
                permissionsSection
            }

            Section {
                Toggle(isOn: enabledBinding) {
                    Label("Enable Scroll Reverser", systemImage: "power")
                }
                .disabled(!model.permissions.canInstallEventTap)
            } header: {
                Label("Scrolling", systemImage: "arrow.up.arrow.down")
            } footer: {
                Text("When this is off, macOS scrolling is left unchanged.")
            }

            Section {
                Toggle(isOn: mouseBinding) {
                    Label("Reverse mouse", systemImage: "computermouse")
                }
                Toggle(isOn: trackpadBinding) {
                    Label("Reverse trackpad", systemImage: "rectangle")
                }
            } header: {
                Label("Devices", systemImage: "square.grid.2x2")
            } footer: {
                Text("Mouse includes USB and Bluetooth wheels, and Magic Mouse when it can be detected. Reverse trackpad independently of that.")
            }

            Section {
                Toggle(isOn: verticalBinding) {
                    Label("Reverse vertical", systemImage: "arrow.up.and.down")
                }
                Toggle(isOn: horizontalBinding) {
                    Label("Reverse horizontal", systemImage: "arrow.left.and.right")
                }
            } header: {
                Label("Axes", systemImage: "move.3d")
            }

            Section {
                LabeledContent("Wheel step size") {
                    Text(wheelStepLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: wheelStepBinding,
                    in: Double(AppSettings.wheelStepSizeRange.lowerBound)...Double(AppSettings.wheelStepSizeRange.upperBound),
                    step: 1
                )
                .accessibilityLabel("Wheel step size")
                .accessibilityValue(wheelStepLabel)
            } header: {
                Label("Scroll wheel", systemImage: "computermouse.fill")
            } footer: {
                Text(model.hasSeenDiscreteWheel
                     ? "A discrete scroll wheel was detected. System default keeps macOS acceleration."
                     : "Applies only to discrete (clicky) scroll wheels. System default keeps macOS acceleration.")
            }

            Section {
                Toggle(isOn: loginBinding) {
                    Label("Start at login", systemImage: "power.circle")
                }
                if let hint = model.loginItemHint {
                    Text(hint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items…") {
                        model.openLoginItemsSettings()
                    }
                }
            } header: {
                Label("General", systemImage: "gearshape")
            } footer: {
                Text("Recommended: keep System Settings → Trackpad → Natural scrolling on, enable Reverse mouse, and leave Reverse trackpad off.")
            }

            Section {
                Button("Check Permissions") {
                    model.refreshPermissions()
                }
            } footer: {
                Text("The sidebar doodle shows mouse and trackpad direction independently. It pauses when Reduce Motion is on.")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .controlSize(.regular)
    }

    private var permissionsSection: some View {
        Section {
            if !model.permissions.accessibilityTrusted {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Accessibility is required", systemImage: "hand.raised.fill")
                        .font(.body.weight(.medium))
                    Text("macOS will not let this app invert scroll events until it is allowed in Privacy & Security → Accessibility. Add Simple Scroll Reverser, then turn Enable back on.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Accessibility Settings") {
                        model.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            if !model.permissions.inputMonitoringTrusted {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Input Monitoring is recommended", systemImage: "dot.radiowaves.left.and.right")
                        .font(.body.weight(.medium))
                    Text("On recent macOS versions, Input Monitoring is also requested so HID scroll events can be observed. Grant it if scrolling is not reversed after Accessibility is on.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Input Monitoring Settings") {
                        model.requestInputMonitoring()
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Privacy", systemImage: "lock.shield")
        }
    }

    private var statusLine: String {
        if !model.permissions.accessibilityTrusted {
            return "Waiting for Accessibility"
        }
        if !model.settings.enabled {
            return "Paused"
        }
        if let device = model.lastDeviceLabel {
            return "On · last scroll: \(device)"
        }
        return "On"
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

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
