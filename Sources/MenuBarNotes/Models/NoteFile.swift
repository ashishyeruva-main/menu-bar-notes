import Foundation

struct NoteFile: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let modified: Date

    var displayName: String {
        name
    }

    init(url: URL, modified: Date) {
        self.id = url
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.modified = modified
    }
}
