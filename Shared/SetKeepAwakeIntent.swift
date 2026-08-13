import AppIntents
import Foundation

extension Notification.Name {
    static let controlWakeIntentWillPerform = Notification.Name(
        "com.inkirby.ControlWake.intentWillPerform"
    )
    static let controlWakeStatusDidChange = Notification.Name(
        "com.inkirby.ControlWake.statusDidChange"
    )
    static let visibleSettingsShouldRefresh = Notification.Name(
        "com.inkirby.ControlWake.visibleSettingsShouldRefresh"
    )
}

struct SetKeepAwakeIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Keep Awake"
    static let description = IntentDescription(
        "Prevents the display from turning off due to inactivity."
    )
    // Dynamic foreground mode launches the containing app in the background and
    // only brings it forward if the intent explicitly requests that transition.
    // ControlWake never requests it, so Control Center stays open while the
    // long-lived app process owns the sleep assertion.
    static var supportedModes: IntentModes { .foreground(.dynamic) }

    @Parameter(title: "Keep Awake is enabled")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .controlWakeIntentWillPerform,
            object: nil
        )
        try KeepAwakeCoordinator.shared.setEnabled(value)
        return .result()
    }
}
