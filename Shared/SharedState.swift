import Foundation

enum SharedState {
    private static let defaults = UserDefaults(
        suiteName: ControlWakeConstants.appGroupIdentifier
    )!

    static var keepAwakeEnabled: Bool {
        get { defaults.bool(forKey: ControlWakeConstants.enabledKey) }
        set { defaults.set(newValue, forKey: ControlWakeConstants.enabledKey) }
    }
}
