import SwiftUI

struct OpenNotePickerView: View {
    @ObservedObject var store: NoteStore
    let onSelect: (NoteFile) -> Void
    let onCancel: () -> Void

    @State private var notes: [NoteFile] = []
    @State private var selection: NoteFile.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if notes.isEmpty {
                emptyState
            } else {
                noteList
            }
            Divider()
            footer
        }
        .frame(width: 380, height: 420)
        .background(VisualEffectBackground())
        .onAppear { refresh() }
    }

    private var header: some View {
        HStack {
            Text("Open Existing Note")
                .font(.headline)
            Spacer()
            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh list")
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No markdown notes yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noteList: some View {
        List(notes, selection: $selection) { note in
            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayName)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Text(Self.modifiedFormatter.string(from: note.modified))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(note.id)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onSelect(note)
            }
        }
        .listStyle(.inset)
    }

    private var footer: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Open") {
                if let id = selection, let note = notes.first(where: { $0.id == id }) {
                    onSelect(note)
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selection == nil)
        }
        .padding(12)
    }

    private func refresh() {
        notes = store.listNotes()
        if let current = store.currentNoteURL {
            selection = current
        }
    }

    private static let modifiedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
