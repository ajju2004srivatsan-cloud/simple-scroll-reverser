import SwiftUI

/// First-launch (and on-demand) setup: Gatekeeper help plus TCC deep links.
/// The “Not Opened” dialog happens before any app code runs; this screen
/// cannot intercept it, only explain the steps and finish post-launch permissions.
struct SetupGuideView: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        Form {
            Section {
                Text("macOS asked to protect you before this window could appear. The steps below match that “Not Opened” alert, then the two permissions this app needs to reverse scrolling.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("If Mac says “Not Opened”", systemImage: "lock.shield")
                            .font(.body.weight(.medium))
                        Spacer()
                        StatusBadge(title: "Before launch", systemImage: "info.circle", isComplete: false, informational: true)
                    }
                    Text("Apple could not verify this build is free of malware because GitHub Actions ships an ad-hoc signed zip — not Developer ID notarized. That alert is shown by macOS **before** Simple Scroll Reverser starts, so the app cannot open it, click Open Anyway, or skip Gatekeeper.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 4) {
                        labeledStep("1", "System Settings → Privacy & Security.")
                        labeledStep("2", "Scroll to Security and choose Open Anyway for Simple Scroll Reverser.")
                        labeledStep("3", "Or in Finder: Control-click the app → Open → Open.")
                    }
                    Text("Terminal fallback if it is still blocked:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(PrivacySettingsOpener.quarantineRemovalCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Open Privacy & Security") {
                            model.openPrivacyAndSecurity()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Copy xattr Command") {
                            PrivacySettingsOpener.copyQuarantineCommand()
                        }
                    }
                    .controlSize(.regular)
                }
                .padding(.vertical, 4)
            } header: {
                Label("Gatekeeper", systemImage: "checkmark.seal")
            } footer: {
                Text("A Developer ID certificate plus notarization would remove that first dialog. This project does not ship certificates, and nothing in the app bypasses Gatekeeper.")
            }

            Section {
                permissionCard(
                    title: "Accessibility",
                    systemImage: "hand.raised.fill",
                    allowed: model.permissions.accessibilityTrusted,
                    detail: "Required. macOS will not let this app invert scroll events until Simple Scroll Reverser is enabled here.",
                    buttonTitle: "Open Accessibility Settings",
                    action: { model.requestAccessibility() },
                    prominent: true
                )
            } header: {
                Label("Accessibility", systemImage: "hand.raised")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    labeledStep("1", "Click the + button under the apps list.")
                    labeledStep("2", "Choose /Applications/Simple Scroll Reverser.app and add it.")
                    labeledStep("3", "Turn the toggle ON (Accessibility and Input Monitoring if listed).")
                }
            } header: {
                Label("If the app is not in the list", systemImage: "plus.app")
            } footer: {
                Text("Keep Simple Scroll Reverser.app in /Applications, not Downloads. After updating, replace that copy so the Privacy list stays attached to the same app.")
            }

            Section {
                permissionCard(
                    title: "Input Monitoring",
                    systemImage: "dot.radiowaves.left.and.right",
                    allowed: model.permissions.inputMonitoringTrusted,
                    detail: "Recommended on recent macOS so HID scroll events can be observed. If the app is missing from Input Monitoring, click +, choose /Applications/Simple Scroll Reverser.app, add it, and turn the toggle ON.",
                    buttonTitle: "Open Input Monitoring Settings",
                    action: { model.requestInputMonitoring() },
                    prominent: false
                )
            } header: {
                Label("Input Monitoring", systemImage: "waveform")
            }

            Section {
                Button("Check Permissions") {
                    model.refreshPermissions()
                }
                Button("Continue to Preferences") {
                    model.completeSetup()
                }
                .disabled(!model.permissions.canInstallEventTap)
            } footer: {
                Text(model.permissions.canInstallEventTap
                     ? "Accessibility is allowed. Continue when you are ready — you can reopen this guide from Preferences."
                     : "Continue unlocks after Accessibility is allowed. Input Monitoring can be granted now or later.")
            }
        }
        .formStyle(.grouped)
        .controlSize(.regular)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            model.requestPrivacyListEntries()
        }
    }

    private func labeledStep(_ index: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(index)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.callout)
        }
    }

    private func permissionCard(
        title: String,
        systemImage: String,
        allowed: Bool,
        detail: String,
        buttonTitle: String,
        action: @escaping () -> Void,
        prominent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.body.weight(.medium))
                Spacer()
                StatusBadge(
                    title: allowed ? "Allowed" : "Needed",
                    systemImage: allowed ? "checkmark.circle.fill" : "exclamationmark.circle",
                    isComplete: allowed,
                    informational: false
                )
            }
            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if prominent && !allowed {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Button(buttonTitle, action: action)
                    .controlSize(.small)
                    .disabled(allowed)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String
    let isComplete: Bool
    let informational: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(informational || isComplete ? .secondary : .primary)
            .symbolRenderingMode(.hierarchical)
            .labelStyle(.titleAndIcon)
    }
}
