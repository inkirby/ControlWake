import SwiftUI
import WidgetKit

struct ControlWakeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: ControlWakeConstants.controlKind,
            provider: KeepAwakeValueProvider()
        ) { isEnabled in
            ControlWidgetToggle(
                "Keep Awake",
                isOn: isEnabled,
                action: SetKeepAwakeIntent()
            ) { isOn in
                Label(
                    isOn ? "On" : "Off",
                    systemImage: isOn ? "cup.and.heat.waves.fill" : "cup.and.heat.waves"
                )
                .controlWidgetActionHint(isOn ? "Turn Off Keep Awake" : "Turn On Keep Awake")
            }
            .tint(.orange)
        }
        .displayName("Keep Awake")
        .description("Prevent the display from turning off due to inactivity.")
    }
}

private struct KeepAwakeValueProvider: ControlValueProvider {
    let previewValue = false

    func currentValue() async throws -> Bool {
        SharedState.keepAwakeEnabled
    }
}
