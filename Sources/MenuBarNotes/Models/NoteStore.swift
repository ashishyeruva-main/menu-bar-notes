import Foundation
import Combine
import AppKit

/// Owns the active note, file I/O, global counter, and Obsidian-style autosave.
///
/// Obsidian saves about every 2 seconds while you type. We mirror that:
/// mark dirty on edit, save on a 2s timer while dirty, and always flush on
/// note switch / popover close / quit.
@MainActor
final class NoteStore: ObservableObject {
    private static let counterKey = "MenuBarNotes.globalCounter"
    private static let lastNoteKey = "MenuBarNotes.lastNotePath"
    private static let notesDirectoryKey = "MenuBarNotes.notesDirectory"

    /// Default folder for a fresh install (`~/Documents/MenuBarNotes`).
    static var defaultNotesDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/MenuBarNotes", isDirectory: true)
    }

    /// Folder where `.md` notes are created and listed.
    var notesDirectory: URL {
        if let path = defaults.string(forKey: Self.notesDirectoryKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return Self.defaultNotesDirectory
    }

    @Published private(set) var currentNoteURL: URL?
    @Published var content: String = "" {
        didSet {
            guard content != lastSavedContent else { return }
            isDirty = true
            ensureAutosaveRunning()
        }
    }
    @Published private(set) var currentNoteName: String = ""
    @Published private(set) var isDirty: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var notesDirectoryDisplayPath: String = ""

    private var lastSavedContent: String = ""
    private var autosaveTimer: Timer?
    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    init() {
        refreshDirectoryDisplayPath()
        ensureNotesDirectory()
        syncCounterWithDisk()
        if let path = defaults.string(forKey: Self.lastNoteKey) {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path), isUnderNotesDirectory(url) {
                openNote(at: url)
            }
        }
    }

    // MARK: - Public actions

    /// Point the app at a different notes folder (e.g. an Obsidian vault path).
    func setNotesDirectory(_ url: URL) {
        flushSave()
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            lastError = "That path is not a folder."
            return
        }
        defaults.set(url.path, forKey: Self.notesDirectoryKey)
        refreshDirectoryDisplayPath()
        ensureNotesDirectory()
        syncCounterWithDisk()

        // Drop the active note if it no longer lives in the chosen folder.
        if let current = currentNoteURL, !isUnderNotesDirectory(current) {
            currentNoteURL = nil
            currentNoteName = ""
            lastSavedContent = ""
            content = ""
            isDirty = false
            defaults.removeObject(forKey: Self.lastNoteKey)
            stopAutosaveIfClean()
        }
        lastError = nil
    }

    /// Ensure there is an active note (create one if needed), then return it.
    @discardableResult
    func ensureActiveNote() -> URL? {
        if let current = currentNoteURL,
           fileManager.fileExists(atPath: current.path),
           isUnderNotesDirectory(current) {
            return current
        }
        return createNewNote()
    }

    @discardableResult
    func createNewNote() -> URL? {
        // Persist any real content first. Empty drafts are discarded instead of
        // left as vault litter when the user asks for a new note.
        // Dismissing the popover does NOT delete an empty note — only New Note does.
        if isCurrentNoteEffectivelyEmpty {
            deleteCurrentNoteIfEmpty()
        } else {
            flushSave()
        }

        ensureNotesDirectory()

        let counter = nextCounter()
        let stamp = Self.timestampFormatter.string(from: Date())
        let filename = "\(stamp)_\(counter).md"
        let url = notesDirectory.appendingPathComponent(filename)

        do {
            try "".write(to: url, atomically: true, encoding: .utf8)
            lastError = nil
            loadNote(at: url, content: "")
            return url
        } catch {
            lastError = "Could not create note: \(error.localizedDescription)"
            return nil
        }
    }

    func openNote(at url: URL) {
        // Switching via Open Existing keeps the previous note, even if empty —
        // only New Note discards an unused empty draft.
        flushSave()
        guard isUnderNotesDirectory(url) else {
            lastError = "That note is outside the notes folder."
            return
        }
        guard fileManager.fileExists(atPath: url.path) else {
            lastError = "Note no longer exists."
            return
        }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            lastError = nil
            loadNote(at: url, content: text)
        } catch {
            lastError = "Could not open note: \(error.localizedDescription)"
        }
    }

    func listNotes() -> [NoteFile] {
        ensureNotesDirectory()
        guard let urls = try? fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .compactMap { url -> NoteFile? in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                let modified = values?.contentModificationDate ?? .distantPast
                return NoteFile(url: url, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
    }

    func revealInFinder() {
        if let url = currentNoteURL, fileManager.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            ensureNotesDirectory()
            NSWorkspace.shared.open(notesDirectory)
        }
    }

    /// Flush any pending edits to disk immediately.
    func flushSave() {
        guard isDirty, let url = currentNoteURL else { return }
        writeToDisk(url: url, text: content)
    }

    /// True when the active note has no meaningful content (nothing written).
    /// Whitespace-only counts as empty.
    private var isCurrentNoteEffectivelyEmpty: Bool {
        guard currentNoteURL != nil else { return false }
        return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Removes the active note file if it is empty. Used only when creating a new note,
    /// not when dismissing the popover.
    private func deleteCurrentNoteIfEmpty() {
        guard isCurrentNoteEffectivelyEmpty, let url = currentNoteURL else { return }
        guard isUnderNotesDirectory(url) else { return }

        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            lastError = nil
        } catch {
            lastError = "Could not remove empty note: \(error.localizedDescription)"
            // Still clear the active note so createNewNote can proceed with a fresh file.
        }

        currentNoteURL = nil
        currentNoteName = ""
        lastSavedContent = ""
        content = ""
        isDirty = false
        defaults.removeObject(forKey: Self.lastNoteKey)
        stopAutosaveIfClean()
    }

    // MARK: - Autosave (Obsidian-like ~2s)

    private func ensureAutosaveRunning() {
        guard autosaveTimer == nil else { return }
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.autosaveTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autosaveTimer = timer
    }

    private func autosaveTick() {
        guard isDirty, let url = currentNoteURL else {
            stopAutosaveIfClean()
            return
        }
        writeToDisk(url: url, text: content)
        stopAutosaveIfClean()
    }

    private func stopAutosaveIfClean() {
        guard !isDirty else { return }
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }

    private func writeToDisk(url: URL, text: String) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            lastSavedContent = text
            isDirty = false
            lastError = nil
        } catch {
            lastError = "Could not save: \(error.localizedDescription)"
        }
    }

    // MARK: - Internals

    private func loadNote(at url: URL, content: String) {
        currentNoteURL = url
        currentNoteName = url.deletingPathExtension().lastPathComponent
        lastSavedContent = content
        self.content = content
        isDirty = false
        defaults.set(url.path, forKey: Self.lastNoteKey)
        stopAutosaveIfClean()
    }

    private func ensureNotesDirectory() {
        let dir = notesDirectory
        guard !fileManager.fileExists(atPath: dir.path) else { return }
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            lastError = "Could not create notes folder: \(error.localizedDescription)"
        }
    }

    private func isUnderNotesDirectory(_ url: URL) -> Bool {
        let notePath = url.standardizedFileURL.path
        let rootPath = notesDirectory.standardizedFileURL.path
        return notePath == rootPath || notePath.hasPrefix(rootPath + "/")
    }

    private func refreshDirectoryDisplayPath() {
        notesDirectoryDisplayPath = notesDirectory.path
    }

    /// Global counter: max(UserDefaults, highest trailing number on disk) + 1 when allocating.
    private func nextCounter() -> Int {
        syncCounterWithDisk()
        let next = defaults.integer(forKey: Self.counterKey) + 1
        defaults.set(next, forKey: Self.counterKey)
        return next
    }

    private func syncCounterWithDisk() {
        let onDisk = maxCounterFromDisk()
        let stored = defaults.integer(forKey: Self.counterKey)
        if onDisk > stored {
            defaults.set(onDisk, forKey: Self.counterKey)
        }
    }

    /// Parses trailing `_N` from filenames like `2026-07-14_215034_3.md`.
    private func maxCounterFromDisk() -> Int {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var maxValue = 0
        for url in urls where url.pathExtension.lowercased() == "md" {
            let base = url.deletingPathExtension().lastPathComponent
            if let underscore = base.lastIndex(of: "_") {
                let suffix = base[base.index(after: underscore)...]
                if let n = Int(suffix) {
                    maxValue = max(maxValue, n)
                }
            }
        }
        return maxValue
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f
    }()
}
