import OSLog
import ServiceManagement
import WidgetKit

@MainActor
final class KeepAwakeCoordinator {
    static let shared = KeepAwakeCoordinator()

    private let logger = Logger(
        subsystem: "com.inkirby.ControlWake",
        category: "Coordinator"
    )

    private init() {}

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SleepAssertionManager.shared.enable()
            SharedState.keepAwakeEnabled = true
            registerForLogin()
            logger.info("ControlWake enabled")
        } else {
            try SleepAssertionManager.shared.disable()
            SharedState.keepAwakeEnabled = false
            unregisterFromLogin()
            logger.info("ControlWake disabled")
        }

        ControlCenter.shared.reloadControls(
            ofKind: ControlWakeConstants.controlKind
        )
        NotificationCenter.default.post(
            name: .controlWakeStatusDidChange,
            object: nil
        )
    }

    func restoreDesiredState() {
        guard SharedState.keepAwakeEnabled else { return }

        logger.info("Restoring assertion from persisted state")
        do {
            try SleepAssertionManager.shared.enable()
            registerForLogin()
        } catch {
            SharedState.keepAwakeEnabled = false
            ControlCenter.shared.reloadControls(
                ofKind: ControlWakeConstants.controlKind
            )
            logger.error("Could not restore assertion: \(error.localizedDescription)")
        }
    }

    private func registerForLogin() {
        guard SMAppService.mainApp.status != .enabled else { return }

        do {
            try SMAppService.mainApp.register()
            logger.info("Registered as a login item")
        } catch {
            logger.error("Could not register as a login item: \(error.localizedDescription)")
        }
    }

    private func unregisterFromLogin() {
        guard SMAppService.mainApp.status != .notRegistered else { return }

        do {
            try SMAppService.mainApp.unregister()
            logger.info("Unregistered login item")
        } catch {
            logger.error("Could not unregister login item: \(error.localizedDescription)")
        }
    }
}
