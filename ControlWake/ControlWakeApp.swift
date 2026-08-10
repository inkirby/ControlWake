import AppKit
import SwiftUI

@main
struct ControlWakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindowController: NSWindowController?
    private var pendingSettingsPresentation: Task<Void, Never>?
    private var lastControlIntentDate = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controlIntentWillPerform),
            name: .controlWakeIntentWillPerform,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusDidChange),
            name: .controlWakeStatusDidChange,
            object: nil
        )
        KeepAwakeCoordinator.shared.restoreDesiredState()
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        scheduleSettingsWindow()
        return true
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        scheduleSettingsWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        pendingSettingsPresentation?.cancel()
        SleepAssertionManager.shared.releaseForTermination()
    }

    @objc
    private func controlIntentWillPerform() {
        lastControlIntentDate = Date()
        pendingSettingsPresentation?.cancel()
        pendingSettingsPresentation = nil
    }

    @objc
    private func statusDidChange() {
        guard settingsWindowController?.window?.isVisible == true else {
            return
        }

        NotificationCenter.default.post(
            name: .visibleSettingsShouldRefresh,
            object: nil
        )
    }

    private func scheduleSettingsWindow() {
        pendingSettingsPresentation?.cancel()

        guard Date().timeIntervalSince(lastControlIntentDate) > 1 else {
            return
        }

        pendingSettingsPresentation = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            guard Date().timeIntervalSince(lastControlIntentDate) > 1 else {
                return
            }

            showSettingsWindow()
            pendingSettingsPresentation = nil
        }
    }

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "ControlWake"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(
            name: .visibleSettingsShouldRefresh,
            object: nil
        )
    }
}
