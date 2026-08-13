import Foundation
import IOKit.pwr_mgt
import OSLog

enum SleepAssertionError: LocalizedError {
    case createFailed(IOReturn)
    case releaseFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .createFailed(let code):
            "Could not create the sleep assertion (IOKit error \(code))."
        case .releaseFailed(let code):
            "Could not release the sleep assertion (IOKit error \(code))."
        }
    }
}

@MainActor
final class SleepAssertionManager {
    static let shared = SleepAssertionManager()

    private let logger = Logger(
        subsystem: "com.inkirby.ControlWake",
        category: "SleepAssertion"
    )
    private var assertionID: IOPMAssertionID = 0

    var isActive: Bool {
        assertionID != 0
    }

    private init() {}

    func enable() throws {
        guard !isActive else { return }

        var newAssertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            "ControlWake" as CFString,
            "Keep display awake enabled by the user" as CFString,
            nil,
            nil,
            0,
            nil,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            logger.error("Assertion creation failed with IOKit error \(result)")
            throw SleepAssertionError.createFailed(result)
        }

        assertionID = newAssertionID
        logger.info("Assertion created: \(newAssertionID)")
    }

    func disable() throws {
        guard isActive else { return }

        let currentAssertionID = assertionID
        let result = IOPMAssertionRelease(currentAssertionID)
        guard result == kIOReturnSuccess else {
            logger.error("Assertion release failed with IOKit error \(result)")
            throw SleepAssertionError.releaseFailed(result)
        }

        assertionID = 0
        logger.info("Assertion released: \(currentAssertionID)")
    }

    func releaseForTermination() {
        guard isActive else { return }
        let currentAssertionID = assertionID
        IOPMAssertionRelease(currentAssertionID)
        assertionID = 0
        logger.info("Assertion released during termination: \(currentAssertionID)")
    }
}
