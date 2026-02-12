import Cocoa

class NotifierDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

    private let terminalBundleIDs = [
        "com.googlecode.iterm2",
        "com.apple.Terminal",
        "com.github.wez.wezterm",
        "io.alacritty",
        "net.kovidgoyal.kitty",
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NSUserNotificationCenter.default
        center.delegate = self

        // Launched by clicking a notification (app was not running)
        if notification.userInfo?["NSApplicationLaunchUserNotificationKey"] is NSUserNotification {
            activateTerminal()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
            return
        }

        // Normal launch from shell: send notification
        let title = CommandLine.argc > 1 ? CommandLine.arguments[1] : "Claude Code"
        let message = CommandLine.argc > 2 ? CommandLine.arguments[2] : "Claude Code needs your attention"
        let soundName = CommandLine.argc > 3 ? CommandLine.arguments[3] : "Glass"

        let userNotification = NSUserNotification()
        userNotification.title = title
        userNotification.informativeText = message
        userNotification.soundName = soundName
        center.deliver(userNotification)

        // Brief pause to ensure delivery, then exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    // User clicks notification while app is still running
    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        didActivate notification: NSUserNotification
    ) {
        activateTerminal()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    // Ensure notification is displayed even if app is in foreground
    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        shouldPresent notification: NSUserNotification
    ) -> Bool {
        return true
    }

    private func activateTerminal() {
        let workspace = NSWorkspace.shared
        for bundleID in terminalBundleIDs {
            if let app = workspace.runningApplications.first(where: {
                $0.bundleIdentifier == bundleID
            }) {
                app.activate(options: [.activateIgnoringOtherApps])
                return
            }
        }
    }
}

let app = NSApplication.shared
let delegate = NotifierDelegate()
app.delegate = delegate
app.run()
