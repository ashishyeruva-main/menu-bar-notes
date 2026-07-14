import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var store: NoteStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = NoteStore()
        self.store = store
        statusBarController = StatusBarController(store: store)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.flushSave()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
