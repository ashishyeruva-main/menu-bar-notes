import SwiftUI

struct NoteEditorView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TextEditor(text: $store.content)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 420, height: 360)
        .background(VisualEffectBackground())
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "note.text")
                .foregroundStyle(.secondary)
            Text(store.currentNoteName.isEmpty ? "New note" : store.currentNoteName)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if store.isDirty {
                Text("Saving…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if store.currentNoteURL != nil {
                Text("Saved")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Frosted glass background for the popover.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
