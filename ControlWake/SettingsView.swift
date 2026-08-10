import ServiceManagement
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var desiredState = false
    @State private var assertionActive = false
    @State private var loginItemStatus = "Unknown"
    @State private var configuredControlCount = 0
    @State private var lastRefreshed = "Not yet"
    @State private var actionMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("ControlWake 0.1", systemImage: "cup.and.heat.waves.fill")
                .font(.title2.bold())

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                statusRow("Desired state", value: desiredState ? "ON" : "OFF")
                statusRow("Sleep assertion", value: assertionActive ? "ACTIVE" : "INACTIVE")
                statusRow("Launch at login", value: loginItemStatus)
                statusRow("Controls configured by user", value: "\(configuredControlCount)")
                statusRow("Last refreshed", value: lastRefreshed)
                statusRow("App Group", value: ControlWakeConstants.appGroupIdentifier)
            }

            if let actionMessage {
                Text(actionMessage)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Button(assertionActive ? "Turn Off" : "Turn On") {
                    toggleKeepAwake()
                }
                .buttonStyle(.borderedProminent)

                Button("Reload Control") {
                    ControlCenter.shared.reloadControls(
                        ofKind: ControlWakeConstants.controlKind
                    )
                    actionMessage = "Reload requested. This updates a control after it has been added; it does not add it to Control Center."
                    Task { await refresh() }
                }

                Button("Refresh Status") {
                    actionMessage = "Status refreshed."
                    Task { await refresh() }
                }
            }

            Text("Add the Keep Awake control from Control Center → Edit Controls, then use Refresh Status to confirm that macOS sees it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 520)
        .task {
            await refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .visibleSettingsShouldRefresh
            )
        ) { _ in
            Task { await refresh() }
        }
    }

    @ViewBuilder
    private func statusRow(_ title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontDesign(.monospaced)
                .textSelection(.enabled)
        }
    }

    private func toggleKeepAwake() {
        do {
            try KeepAwakeCoordinator.shared.setEnabled(!assertionActive)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

    }

    private func refresh() async {
        desiredState = SharedState.keepAwakeEnabled
        assertionActive = SleepAssertionManager.shared.isActive
        loginItemStatus = Self.description(for: SMAppService.mainApp.status)
        lastRefreshed = Date.now.formatted(date: .omitted, time: .standard)

        do {
            let controls = try await ControlCenter.shared.currentControls()
            configuredControlCount = controls.filter {
                $0.kind == ControlWakeConstants.controlKind
            }.count
        } catch {
            errorMessage = "Could not query Control Center: \(error.localizedDescription)"
        }
    }

    private static func description(for status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered:
            "Not registered"
        case .enabled:
            "Enabled"
        case .requiresApproval:
            "Requires approval"
        case .notFound:
            "Not found"
        @unknown default:
            "Unknown"
        }
    }
}
