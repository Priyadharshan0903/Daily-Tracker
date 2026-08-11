import AppKit
import SwiftUI

/// A workspace's avatar: a gradient disc with its initial.
///
/// The palette is picked from the workspace's id, so a workspace keeps the same
/// colours for its whole life without storing anything. A stable hash matters
/// here — Swift's `hashValue` is seeded per process and would change every launch.
///
/// Deliberately *not* perpetually animated: a `repeatForever` animation never
/// settles, and inside a MenuBarExtra popover — which sizes its window to its
/// content — that keeps re-triggering layout and tears the window away from what
/// it's drawing. Motion is limited to a pop when the workspace changes.
struct WorkspaceAvatar: View {
    let workspace: Workspace
    var size: CGFloat = 20

    @State private var appeared = false

    private static let palettes: [[Color]] = [
        [Color(hex: 0x3F70B8), Color(hex: 0x6F9BD9)],   // accent blue
        [Color(hex: 0x4F9E84), Color(hex: 0x7FC4AC)],   // teal
        [Color(hex: 0xCF7D05), Color(hex: 0xF5B03F)],   // amber
        [Color(hex: 0x6B5BC4), Color(hex: 0x9B8BE0)],   // violet
        [Color(hex: 0xC05A6E), Color(hex: 0xE28B9C)],   // rose
    ]

    private var palette: [Color] {
        let bytes = withUnsafeBytes(of: workspace.id.uuid) { Array($0) }
        let seed = bytes.reduce(0) { ($0 &* 31 &+ Int($1)) & 0xFFFFFF }
        return Self.palettes[seed % Self.palettes.count]
    }

    private var initial: String {
        String(workspace.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            if workspace.avatar.isEmpty {
                Circle()
                    .fill(LinearGradient(colors: palette,
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                Text(initial)
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundColor(.white)
            } else {
                // A soft tint behind the emoji — a full-strength gradient fights
                // with the emoji's own colours.
                Circle().fill(palette[1].opacity(0.22))
                Text(workspace.avatar)
                    .font(.system(size: size * 0.62))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(appeared ? 1 : 0.75)
        .opacity(appeared ? 1 : 0)
        // Keyed on the workspace so switching re-runs the pop.
        .task(id: workspace.id) {
            appeared = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

/// The footer control: current workspace, and a panel to switch or add one.
struct WorkspaceButton: View {
    @EnvironmentObject private var store: Store
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { isOpen.toggle() }
        } label: {
            HStack(spacing: 6) {
                WorkspaceAvatar(workspace: store.activeWorkspace, size: 18)
                Text(store.activeWorkspace.name)
                    .font(Theme.font(11.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 96, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(Theme.neutral700)
                Image(systemName: "chevron.up")
                    .font(Theme.font(7, weight: .bold))
                    .foregroundColor(Theme.neutral500)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(isOpen ? Theme.neutral200 : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingCursor()
        .help("Switch workspace")
    }
}

/// Floats above the content, anchored to the switcher in the footer.
struct WorkspacePanel: View {
    @EnvironmentObject private var store: Store
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.workspaces) { workspace in
                Button {
                    store.activate(workspace.id)
                    onDismiss()
                } label: {
                    HStack(spacing: 8) {
                        WorkspaceAvatar(workspace: workspace, size: 22)
                        Text(workspace.name)
                            .font(Theme.font(12.5, weight: .medium))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        if workspace.id == store.activeWorkspace.id {
                            Image(systemName: "checkmark")
                                .font(Theme.font(10, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverRowStyle())
            }

            Rectangle().fill(Theme.divider).frame(height: 1)

            Button {
                onDismiss()
                promptForNewWorkspace()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(Theme.font(10, weight: .bold))
                        .frame(width: 22)
                    Text("New workspace…")
                        .font(Theme.font(12.5, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundColor(Theme.accent700)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverRowStyle())
        }
        .frame(width: 210)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.neutral300))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
    }

    private func promptForNewWorkspace() {
        let alert = NSAlert()
        alert.messageText = "New workspace"
        alert.informativeText = "Entries, tags and weekly notes are kept separately per workspace."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "Career growth"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.addWorkspace(named: field.stringValue)
    }
}

/// Emoji choices for workspace avatars. Bundled artwork (anime or otherwise)
/// would mean shipping image assets and licensing them; emoji are already on the
/// system, scale to any size, and cost nothing.
enum AvatarCatalog {
    static let choices = [
        "💼", "📚", "🚀", "🎯", "🧠", "💡", "🌱", "🔧",
        "🐙", "🐱", "🦊", "🐼", "🐧", "🦉", "🐢", "🦄",
        "🔥", "⭐️", "🌙", "☀️", "🌊", "🏔️", "🧭", "🎨",
        "🎮", "☕️", "🧪", "📈", "✍️", "🗂️", "🏋️", "🎧",
    ]
}

/// Inline grid for picking a workspace's avatar.
struct AvatarPicker: View {
    let selected: String
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(AvatarCatalog.choices, id: \.self) { emoji in
                    Button { onPick(emoji) } label: {
                        Text(emoji)
                            .font(Theme.font(15))
                            .frame(width: 26, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selected == emoji ? Theme.accent200 : Color.clear)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                }
            }

            Button { onPick("") } label: {
                Text("Use the initial instead")
                    .font(Theme.font(11, weight: .medium))
                    .foregroundColor(Theme.accent700)
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
    }
}

/// Menu-like row highlight, since `.plain` gives no hover feedback.
private struct HoverRowStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovering ? Theme.accent100 : Color.clear)
            .onHover { isHovering = $0 }
    }
}
