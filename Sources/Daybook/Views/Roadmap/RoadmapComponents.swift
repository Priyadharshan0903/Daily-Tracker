import SwiftUI

/// The app's section header: small, kerned, uppercase.
struct Kicker: View {
    let text: String
    var color: Color = Theme.neutral700

    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(10, weight: .semibold))
            .kerning(0.8)
            .foregroundColor(color)
    }
}

/// 18pt square check. The roadmap uses squares where work entries use circles,
/// so a rhythm slot never reads as a task you added yourself.
struct SquareCheck: View {
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if done {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.accent)
                    Image(systemName: "checkmark")
                        .font(Theme.font(9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent600, lineWidth: 1.5)
                }
            }
            .frame(width: Theme.scaled(18), height: Theme.scaled(18))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}

/// Video / Docs / Article / Practice / Book badge on a library row.
struct KindBadge: View {
    let kind: ResourceKind

    var body: some View {
        Text(kind.label)
            .font(Theme.font(10.5))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                if kind.outlined {
                    Capsule().strokeBorder(Theme.neutral300)
                } else {
                    Capsule().fill(kind.fill)
                }
            }
            .foregroundColor(kind.tint)
    }
}

/// Label · meter · count, the row shape shared by the rhythm and track-balance
/// breakdowns on the roadmap week.
struct MeterRow: View {
    let label: String
    let value: Double
    let trailing: String
    var labelWidth: CGFloat = 78
    var trailingWidth: CGFloat = 34
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Theme.font(13))
                .foregroundColor(Theme.neutral700)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: Theme.scaled(labelWidth), alignment: .leading)
            ProgressBar(value: value, height: 6, tint: tint)
            Text(trailing)
                .font(Theme.font(11.5))
                .foregroundColor(Theme.neutral600)
                .frame(width: Theme.scaled(trailingWidth), alignment: .trailing)
        }
    }
}

/// The neutral-200 pill that wraps a text field and its action button — the
/// same shape the Today tab uses for quick add.
struct InputPill<Trailing: View>: View {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            PlaceholderField(placeholder: placeholder, text: $text, onSubmit: onSubmit)
            trailing()
        }
        .padding(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 4))
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.neutral200))
    }
}

/// Small pill button used inside the input pills.
struct PillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.accent))
                .foregroundColor(.white)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}
