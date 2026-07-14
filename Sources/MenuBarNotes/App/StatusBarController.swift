import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store: NoteStore
    private var pickerWindow: NSWindow?

    init(store: NoteStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 360)
        popover.contentViewController = NSHostingController(
            rootView: NoteEditorView(store: store)
        )
        popover.delegate = self

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "note.text",
                accessibilityDescription: "Menu Bar Notes"
            )
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: - Clicks

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(from: button)
            return
        }

        toggleEditor(from: button)
    }

    private func toggleEditor(from button: NSStatusBarButton) {
        if popover.isShown {
            store.flushSave()
            popover.performClose(nil)
            return
        }

        _ = store.ensureActiveNote()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let newNote = menu.addItem(
            withTitle: "New Note",
            action: #selector(newNoteAction),
            keyEquivalent: "n"
        )
        newNote.target = self

        let openExisting = menu.addItem(
            withTitle: "Open Existing…",
            action: #selector(openExistingAction),
            keyEquivalent: "o"
        )
        openExisting.target = self

        menu.addItem(.separator())

        let chooseFolder = menu.addItem(
            withTitle: "Choose Notes Folder…",
            action: #selector(chooseNotesFolderAction),
            keyEquivalent: ""
        )
        chooseFolder.target = self

        let reveal = menu.addItem(
            withTitle: "Reveal in Finder",
            action: #selector(revealInFinderAction),
            keyEquivalent: "r"
        )
        reveal.target = self

        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Menu Bar Notes",
            action: #selector(quitAction),
            keyEquivalent: "q"
        ).target = self

        // Standard status-item pattern: assign menu, click, then clear so left-click stays custom.
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menu actions

    @objc private func newNoteAction() {
        if store.createNewNote() != nil {
            showEditorIfNeeded()
        }
    }

    @objc private func openExistingAction() {
        showOpenPicker()
    }

    @objc private func chooseNotesFolderAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Select the folder where markdown notes should be saved."
        panel.directoryURL = store.notesDirectory

        // Activate so the panel appears above other apps from a menu-bar-only app.
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            store.setNotesDirectory(url)
        }
    }

    @objc private func revealInFinderAction() {
        store.revealInFinder()
    }

    @objc private func quitAction() {
        store.flushSave()
        NSApp.terminate(nil)
    }

    private func showEditorIfNeeded() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Open picker

    private func showOpenPicker() {
        if let existing = pickerWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: OpenNotePickerView(
                store: store,
                onSelect: { [weak self] note in
                    self?.store.openNote(at: note.url)
                    self?.closePicker()
                    self?.showEditorIfNeeded()
                },
                onCancel: { [weak self] in
                    self?.closePicker()
                }
            )
        )

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Open Existing Note"
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.contentViewController = hosting
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        pickerWindow = window
    }

    private func closePicker() {
        pickerWindow?.orderOut(nil)
        pickerWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === pickerWindow {
            pickerWindow = nil
        }
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        store.flushSave()
    }
}
