import AppKit

@main
enum HeyNavApp {
    @MainActor private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        Self.delegate = appDelegate
        application.delegate = appDelegate
        application.run()
    }
}
