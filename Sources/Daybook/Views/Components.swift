import AppKit
import SwiftUI

extension View {
    /// Shows the pointing-hand cursor while hovering — SwiftUI on macOS has no native cursor modifier.
    @ViewBuilder
    func pointingCursor(_ enabled: Bool = true) -> some View {
        if enabled {
            onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        } else {
            self
        }
    }
}

/// ScrollView that hugs its content height up to `maxHeight`, then scrolls.
/// A plain ScrollView collapses to zero height inside the self-sizing
/// MenuBarExtra window, hiding the content entirely.
struct FittedScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: () -> Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    }
                )
        }
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        .frame(height: min(contentHeight, maxHeight))
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Lays children out left-to-right, wrapping to a new line when the row is full.
/// The popover is only 404pt wide, so a plain HStack of tag chips clips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var size = CGSize(width: 0, height: 0)
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let item = subview.sizeThatFits(.unspecified)
            if lineWidth > 0, lineWidth + spacing + item.width > maxWidth {
                size.width = max(size.width, lineWidth)
                size.height += lineHeight + lineSpacing
                lineWidth = item.width
                lineHeight = item.height
            } else {
                lineWidth += lineWidth > 0 ? spacing + item.width : item.width
                lineHeight = max(lineHeight, item.height)
            }
        }
        size.width = max(size.width, lineWidth)
        size.height += lineHeight
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let item = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + item.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(item))
            x += item.width + spacing
            lineHeight = max(lineHeight, item.height)
        }
    }
}

/// Plain text field with an always-visible placeholder — the system placeholder
/// color is nearly invisible on the light-grey input backgrounds.
struct PlaceholderField: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 14
    var onSubmit: () -> Void = {}

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: size))
                    .foregroundColor(Theme.neutral500)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: size))
                .onSubmit(onSubmit)
        }
    }
}

/// Capsule tag chip — accent-tinted when selected, neutral otherwise.
struct TagChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(selected ? Theme.accent200 : Theme.neutral200))
                .foregroundColor(selected ? Theme.accent700 : Theme.neutral700)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingCursor()
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

/// Small read-only tag capsule used on entry rows.
struct TagBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.neutral200))
            .foregroundColor(Theme.neutral700)
    }
}

/// "+ Tag" affordance shown on entries that have no tag yet.
struct AddTagBadge: View {
    var body: some View {
        Text("+ Tag")
            .font(.system(size: 11))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(Theme.neutral300))
            .foregroundColor(Theme.neutral500)
    }
}

/// 18pt circular check toggle — outline when open, filled accent with a white check when done.
struct CheckToggle: View {
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if done {
                    Circle().fill(Theme.accent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle().strokeBorder(Theme.accent600, lineWidth: 1.5)
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}

/// Interactive entry row for the Today view — check off, inline-edit text, re-file tag, delete.
struct EntryRow: View {
    @EnvironmentObject var store: Store
    let entry: Entry
    /// Set on carried-over rows to show the day the task was originally logged.
    var originLabel: String? = nil
    @State private var hovering = false
    @State private var hoveringDelete = false
    @State private var editing = false
    @State private var editText = ""
    @State private var pickingTag = false
    @FocusState private var editFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                CheckToggle(done: entry.done) { store.toggle(entry.id) }

                if editing {
                    TextField("", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14.5))
                        .focused($editFocused)
                        .onSubmit(commitEdit)
                        .onExitCommand(perform: cancelEdit)
                        // Clicking anywhere outside saves, the way inline rename works elsewhere on macOS.
                        .onChange(of: editFocused) { focused in
                            if !focused && editing { commitEdit() }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent.opacity(0.55)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onAppear { editFocused = true }
                } else {
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

                if editing {
                    Button(action: commitEdit) {
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
                    .help("Save (or press Return)")
                } else {
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

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { pickingTag.toggle() }
                    } label: {
                        if entry.tag.isEmpty {
                            AddTagBadge()
                        } else {
                            TagBadge(label: entry.tag)
                        }
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                    .help(entry.tag.isEmpty ? "Add a tag" : "Change tag")

                    Button(action: beginEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.neutral500)
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                    .opacity(hovering ? 1 : 0)
                    .help("Edit entry")

                    Button {
                        store.remove(entry.id)
                    } label: {
                        Text("×")
                            .font(.system(size: 16))
                            .foregroundColor(hoveringDelete ? Theme.orange600 : Theme.neutral500)
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveringDelete = $0 }
                    .pointingCursor()
                    .help("Delete entry")
                }
            }

            if pickingTag {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(store.data.settings.tags, id: \.self) { tag in
                        TagChip(label: tag, selected: tag == entry.tag) { pick(tag) }
                    }
                    TagChip(label: "No tag", selected: entry.tag.isEmpty) { pick("") }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: Theme.radiusMd).fill(hovering ? Theme.neutral200 : Color.clear))
        .onHover { hovering = $0 }
    }

    private func pick(_ tag: String) {
        store.setEntryTag(entry.id, tag: tag)
        withAnimation(.easeOut(duration: 0.18)) { pickingTag = false }
    }

    private func beginEdit() {
        editText = entry.text
        pickingTag = false
        editing = true
    }

    private func commitEdit() {
        guard editing else { return }
        editing = false
        store.updateEntryText(entry.id, text: editText)
    }

    /// Esc discards. Clearing `editing` first stops the focus-loss handler from saving.
    private func cancelEdit() {
        editing = false
    }
}

/// Pill segmented control matching the tab bar — the native segmented picker's
/// unselected segments are nearly invisible on the light theme.
struct SegmentedPicker: View {
    let options: [String]
    @Binding var selection: String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { selection = option }
                } label: {
                    Text(option)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(Theme.accent)
                                    .matchedGeometryEffect(id: "segment", in: ns)
                            }
                        }
                        .foregroundColor(selection == option ? .white : Theme.neutral700)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .pointingCursor()
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.neutral200))
    }
}

/// High-contrast switch: the off state stays clearly outlined on the light theme
/// (the system switch's off state is nearly invisible on white).
struct DaybookToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() }
        } label: {
            Capsule()
                .fill(configuration.isOn ? Theme.accent : Theme.neutral300)
                .overlay(Capsule().strokeBorder(configuration.isOn ? Theme.accent600 : Theme.neutral500, lineWidth: 1))
                .frame(width: 36, height: 20)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .frame(width: 16, height: 16)
                        .padding(2)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}

/// Compact read-only entry line for the Week view.
struct WeekEntryLine: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.done ? "✓" : "○")
                .font(.system(size: 12.5))
                .foregroundColor(entry.done ? Theme.accent700 : Theme.neutral500)
            Text(entry.text)
                .font(.system(size: 13.5))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(entry.text)
            if !entry.tag.isEmpty {
                Text(entry.tag)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundColor(Theme.neutral600)
            }
        }
        .padding(.leading, 2)
    }
}

/// Primary pill/rounded action button (accent background, white label).
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                .foregroundColor(.white)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}

/// Secondary action button (neutral background).
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.neutral200))
                .foregroundColor(Theme.text)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}
