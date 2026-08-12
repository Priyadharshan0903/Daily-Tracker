import SwiftUI

/// Footer control that swaps the popover between work and the roadmap. Sits
/// beside the workspace switcher and matches its weight — both answer "which
/// context am I in", so neither should outrank the other.
struct RoadmapButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { isOn.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "map")
                    .font(Theme.font(10, weight: .semibold))
                Text("Roadmap")
                    .font(Theme.font(11.5, weight: .medium))
                    .fixedSize()
            }
            .foregroundColor(isOn ? Theme.accent700 : Theme.neutral700)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(isOn ? Theme.accent200 : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingCursor()
        .help(isOn ? "Back to your day" : "Open the roadmap")
    }
}
