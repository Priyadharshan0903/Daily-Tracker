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
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.neutral200))
            .foregroundColor(Theme.neutral700)
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
    @State private var hovering = false
    @State private var hoveringDelete = false
    @State private var editing = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            CheckToggle(done: entry.done) { store.toggle(entry.id) }

            if editing {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14.5))
                    .focused($editFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand { editing = false }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear { editFocused = true }
            } else {
                Text(entry.text)
                    .font(.system(size: 14.5))
                    .strikethrough(entry.done)
                    .foregroundColor(entry.done ? Theme.neutral600 : Theme.text)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: beginEdit)
                    .help("Double-click to edit")
            }

            Menu {
                ForEach(store.data.settings.tags, id: \.self) { tag in
                    Button(tag) { store.setEntryTag(entry.id, tag: tag) }
                }
            } label: {
                TagBadge(label: entry.tag)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .pointingCursor()
            .help("Change tag")

            Button(action: beginEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.neutral500)
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .opacity(hovering && !editing ? 1 : 0)
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
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: Theme.radiusMd).fill(hovering ? Theme.neutral200 : Color.clear))
        .onHover { hovering = $0 }
    }

    private func beginEdit() {
        editText = entry.text
        editing = true
    }

    private func commitEdit() {
        store.updateEntryText(entry.id, text: editText)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.tag)
                .font(.system(size: 11))
                .foregroundColor(Theme.neutral600)
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
