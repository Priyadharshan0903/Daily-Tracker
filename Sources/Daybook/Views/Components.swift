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
    /// Optional mirror of the field's focus, for callers that reveal UI only
    /// while the field is being used.
    var isFocused: Binding<Bool>? = nil
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: Theme.scaled(size)))
                    .foregroundColor(Theme.neutral500)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.scaled(size)))
                .focused($focused)
                .onSubmit(onSubmit)
        }
        .onChange(of: focused) { isFocused?.wrappedValue = $0 }
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
                .font(Theme.font(11, weight: .medium))
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
            .font(Theme.font(11))
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
            .font(Theme.font(11))
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
                        .font(Theme.font(9, weight: .bold))
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
                        .font(Theme.font(12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
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
    @EnvironmentObject var store: Store
    let entry: Entry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Reviewing the week is exactly when you want to tick something off.
            Button {
                store.toggle(entry.id)
            } label: {
                Text(entry.done ? "✓" : "○")
                    .font(Theme.font(12.5))
                    .foregroundColor(entry.done ? Theme.accent700 : Theme.neutral500)
                    .frame(width: 11, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help(entry.done ? "Mark as not done" : "Mark as done")
            Text(entry.text)
                .font(Theme.font(13.5))
                .lineSpacing(1.5)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(entry.text)
            if !entry.tag.isEmpty {
                Text(entry.tag)
                    .font(Theme.font(11))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundColor(Theme.neutral600)
            }
        }
        .padding(.leading, 2)
    }
}

/// Compact icon button for entry-row actions. The bare 11pt pencil read as a
/// stray slash; a hit area with a hover chip makes it legible as a control.
struct RowIconButton: View {
    let systemName: String
    let help: String
    var size: CGFloat = 12
    var danger: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: Theme.scaled(size), weight: .semibold))
                .foregroundColor(hovering ? (danger ? Theme.orange600 : Theme.accent700) : Theme.neutral500)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovering ? (danger ? Theme.orange500.opacity(0.15) : Theme.accent200) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingCursor()
        .help(help)
    }
}

/// Radio dot used by the Settings tag list.
struct RadioDot: View {
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(selected ? Theme.accent : Theme.neutral500, lineWidth: 1.5)
                if selected {
                    Circle().fill(Theme.accent).frame(width: 7, height: 7)
                }
            }
            .frame(width: 14, height: 14)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}

/// Primary pill/rounded action button (accent background, white label).
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(13, weight: .semibold))
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
                .font(Theme.font(13, weight: .semibold))
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
