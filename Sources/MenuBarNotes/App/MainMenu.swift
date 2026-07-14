import AppKit

/// Installs a minimal main menu so standard text editing shortcuts work.
///
/// LSUIElement / accessory apps have no system menu bar. macOS still routes
/// ⌘A / ⌘C / ⌘V / ⌘X / ⌘Z through `NSApp.mainMenu` → Edit → first responder.
/// Without those items, `TextEditor` never receives the commands.
enum MainMenu {
    static func install() {
        let mainMenu = NSMenu()

        // App menu (Quit)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Menu Bar Notes",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        // Edit menu — required for text editing key equivalents
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(
            NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        )
        editMenu.addItem(
            NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        )
        editMenu.addItem(.separator())
        editMenu.addItem(
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        )
        editMenu.addItem(
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        )
        editMenu.addItem(
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        )
        editMenu.addItem(
            NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        )
        editMenu.addItem(
            NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        )

        NSApp.mainMenu = mainMenu
    }
}
