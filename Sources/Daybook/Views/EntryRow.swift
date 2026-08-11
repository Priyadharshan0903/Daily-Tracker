import SwiftUI

/// One task in the Today list: check off, edit inline, re-file, delete, reorder.
///
/// The row is deliberately thin — it owns interaction state and composes the
/// pieces below, each of which is responsible for exactly one part of the row.
struct EntryRow: View {
    private enum Layout {
        static let handleWidth: CGFloat = 14
        static let controlHeight: CGFloat = 22
        static let columnSpacing: CGFloat = 10
        static let checkWidth: CGFloat = 18
        /// Lines the tag picker up with the task text rather than the row edge.
        static var textIndent: CGFloat { handleWidth + columnSpacing + checkWidth + columnSpacing }
    }

    @EnvironmentObject private var store: Store
    @EnvironmentObject private var reorder: ReorderController

    let entry: Entry
    /// Set on carried-over rows to show the day the task was originally logged.
    var originLabel: String? = nil
    var isSelected: Bool = false
    var isReorderable: Bool = false

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var isPickingTag = false
    @State private var draftText = ""
    /// Bumped on every successful save; drives the confirmation outline.
    @State private var saveCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Layout.columnSpacing) {
                DragHandle(isEnabled: isReorderable,
                           isHighlighted: isHovering || isDragging,
                           width: Layout.handleWidth,
                           height: Layout.controlHeight,
                           onDrag: { location, translation in
                               reorder.drag(entry.id, to: location, translation: translation)
                           },
                           onEnd: {
                               reorder.finish { dragged, target in
                                   store.moveEntry(dragged, onto: target)
                               }
                           })

                CheckToggle(done: entry.done) { store.toggle(entry.id) }

                if isEditing {
                    EntryEditor(text: $draftText,
                                initialText: entry.text,
                                onSubmit: commitEdit,
                                onCancel: cancelEdit)
                } else {
                    title
                }

                if isEditing {
                    SaveButton(action: commitEdit)
                } else {
                    EntryActions(entry: entry,
                                 originLabel: originLabel,
                                 onPickTag: togglePicker,
                                 onEdit: beginEdit,
                                 onDelete: { store.remove(entry.id) })
                }
            }

            if isPickingTag {
                tagPicker.padding(.leading, Layout.textIndent)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd)
                // accent100, not neutral200 — the tag badge is neutral200 and
                // vanished into a matching hover background.
                .fill(isDragging ? Theme.surface
                                 : (isSelected || isHovering ? Theme.accent100 : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .overlay(alignment: .top) {
            if reorder.targetID == entry.id {
                Capsule().fill(Theme.accent).frame(height: 2)
            }
        }
        .savedOutline(trigger: saveCount)
        // Rows publish their frames so the reorder controller can work out which
        // one the pointer is over.
        .background(frameReporter)
        .offset(y: isDragging ? reorder.offset : 0)
        .shadow(color: isDragging ? Color.black.opacity(0.18) : .clear,
                radius: isDragging ? 8 : 0, y: isDragging ? 3 : 0)
        .zIndex(isDragging ? 1 : 0)
        .onHover { isHovering = $0 }
    }

    private var isDragging: Bool { reorder.draggingID == entry.id }

    private var borderColor: Color {
        if isDragging { return Theme.accent.opacity(0.5) }
        return isSelected ? Theme.accent.opacity(0.55) : .clear
    }

    @ViewBuilder
    private var frameReporter: some View {
        if isReorderable {
            GeometryReader { geo in
                Color.clear.preference(
                    key: RowFramesKey.self,
                    value: [entry.id: geo.frame(in: .named(ReorderController.space))]
                )
            }
        }
    }

    private var title: some View {
        Text(entry.text)
            .font(.system(size: 14.5))
            .strikethrough(entry.done)
            .foregroundColor(entry.done ? Theme.neutral600 : Theme.text)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: beginEdit)
            .help(entry.text)
    }

    private var tagPicker: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(store.data.settings.tags, id: \.self) { tag in
                TagChip(label: tag, selected: tag == entry.tag) { pick(tag) }
            }
            TagChip(label: "No tag", selected: entry.tag.isEmpty) { pick("") }
        }
    }

    // MARK: - Actions

    private func togglePicker() {
        withAnimation(.easeOut(duration: 0.18)) { isPickingTag.toggle() }
    }

    private func pick(_ tag: String) {
        store.setEntryTag(entry.id, tag: tag)
        withAnimation(.easeOut(duration: 0.18)) { isPickingTag = false }
    }

    private func beginEdit() {
        draftText = entry.text
        isPickingTag = false
        isEditing = true
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.updateEntryText(entry.id, text: trimmed)
        saveCount += 1
    }

    /// Esc discards. Clearing the flag first stops the blur handler saving.
    private func cancelEdit() {
        isEditing = false
    }
}

// MARK: - Drag handle

/// Grip dots. Always drawn, just faint until hovered: a handle that only existed
/// on hover hid the affordance and made the drag gesture unreliable, because the
/// view's identity changed at the moment the drag would have started.
private struct DragHandle: View {
    let isEnabled: Bool
    let isHighlighted: Bool
    let width: CGFloat
    let height: CGFloat
    let onDrag: (_ location: CGPoint, _ translation: CGFloat) -> Void
    let onEnd: () -> Void

    var body: some View {
        if isEnabled {
            GripDots(color: isHighlighted ? Theme.neutral500 : Theme.neutral300)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .pointingCursor()
                .help("Drag to reorder — or ⌘↑ / ⌘↓")
                .gesture(
                    DragGesture(minimumDistance: 2,
                                coordinateSpace: .named(ReorderController.space))
                        .onChanged { onDrag($0.location, $0.translation.height) }
                        .onEnded { _ in onEnd() }
                )
        } else {
            // Reserve the same width so every row's checkbox lines up.
            Color.clear.frame(width: width, height: height)
        }
    }
}

private struct GripDots: View {
    let color: Color

    var body: some View {
        VStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 2.5) {
                    Circle().frame(width: 2.5, height: 2.5)
                    Circle().frame(width: 2.5, height: 2.5)
                }
            }
        }
        .foregroundColor(color)
    }
}

// MARK: - Row pieces

private struct EntryEditor: View {
    @Binding var text: String
    let initialText: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        // Clicking away saves, the way inline rename works elsewhere on macOS.
        InlineTextField(text: $text,
                        initialText: initialText,
                        fontSize: 14.5,
                        onSubmit: onSubmit,
                        onCancel: onCancel,
                        onBlur: onSubmit)
            // 18pt is the field's exact intrinsic height; leave slack for the
            // field editor AppKit installs on focus.
            .frame(height: 21)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent.opacity(0.55)))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SaveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Save")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.accent))
                .foregroundColor(.white)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingCursor()
        .help("Save (Return or ⌘↩)")
    }
}

private struct EntryActions: View {
    let entry: Entry
    let originLabel: String?
    let onPickTag: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            if let originLabel {
                Text(originLabel)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.orange500.opacity(0.15)))
                    .foregroundColor(Theme.orange700)
                    .help("Carried over from \(originLabel)")
            }

            Button(action: onPickTag) {
                if entry.tag.isEmpty {
                    AddTagBadge()
                } else {
                    TagBadge(label: entry.tag)
                }
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help(entry.tag.isEmpty ? "Add a tag" : "Change tag")

            RowIconButton(systemName: "square.and.pencil", help: "Edit entry", action: onEdit)
            RowIconButton(systemName: "xmark", help: "Delete entry", size: 11, danger: true, action: onDelete)
        }
    }
}

// MARK: - Save confirmation

/// Traces a green outline around the view once, then fades it out. Driven by
/// changes to `trigger` so the caller only has to bump a counter.
private struct SavedOutline: ViewModifier {
    let trigger: Int
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                // Inset by half the line width — a centred stroke would spill
                // outside the bounds and be clipped by the enclosing ScrollView.
                RoundedRectangle(cornerRadius: Theme.radiusMd)
                    .inset(by: 0.9)
                    .trim(from: 0, to: progress)
                    .stroke(Theme.success.opacity(0.85),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .opacity(opacity)
            )
            .onChange(of: trigger) { _ in run() }
    }

    private func run() {
        progress = 0
        opacity = 1
        withAnimation(.easeInOut(duration: 0.55)) { progress = 1 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.easeOut(duration: 0.35)) { opacity = 0 }
            try? await Task.sleep(nanoseconds: 400_000_000)
            progress = 0
        }
    }
}

extension View {
    func savedOutline(trigger: Int) -> some View {
        modifier(SavedOutline(trigger: trigger))
    }
}
