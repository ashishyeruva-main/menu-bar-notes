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
                .disabled(store.currentNoteURL == nil && store.lastError != nil)
        }
        .frame(width: 420, height: 360)
        .background(VisualEffectBackground())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(titleText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                if store.lastError == nil {
                    statusChip
                }
            }

            if let error = store.lastError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                        .accessibilityHidden(true)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                    if store.isDirty {
                        Text("Unsaved")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Error: \(error)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var titleText: String {
        if !store.currentNoteName.isEmpty {
            return store.currentNoteName
        }
        if store.lastError != nil {
            return "No note"
        }
        return "New note"
    }

    @ViewBuilder
    private var statusChip: some View {
        if store.isDirty {
            Text("Unsaved")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if store.currentNoteURL != nil {
            Text("Saved")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
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
