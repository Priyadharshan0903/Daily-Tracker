import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var newTag = ""
    @State private var isAddingTag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            general
            tags
            footer
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: - Sections

    private var general: some View {
        SettingsSection("General") {
            SettingsRow("Daily reminder", hint: "A nudge to write the day down") {
                HStack(spacing: 8) {
                    Toggle("", isOn: binding(\.reminderEnabled))
                        .toggleStyle(DaybookToggleStyle())
                        .labelsHidden()

                    if store.data.settings.reminderEnabled {
                        Text("at")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.neutral600)
                        DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field)
                            .labelsHidden()
                            .fixedSize()
                    } else {
                        Text("Off")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.neutral500)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: store.data.settings.reminderEnabled)
            }

            RowDivider()

            SettingsRow("Week starts on") {
                SegmentedPicker(options: WeekStart.allCases.map(\.rawValue), selection: weekStart)
            }

            RowDivider()

            SettingsRow("Launch at login") {
                Toggle("", isOn: binding(\.launchAtLogin))
                    .toggleStyle(DaybookToggleStyle())
                    .labelsHidden()
            }
        }
    }

    private var tags: some View {
        SettingsSection("Tags") {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(store.data.settings.tags, id: \.self) { tag in
                    EditableTagChip(tag: tag,
                                    canDelete: store.data.settings.tags.count > 1,
                                    onRename: { store.renameTag(tag, to: $0) },
                                    onDelete: { store.deleteTag(tag) })
                }
                newTagChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            RowDivider()

            SettingsRow("New tasks get") {
                Picker("", selection: defaultTag) {
                    Text("No tag").tag("")
                    ForEach(store.data.settings.tags, id: \.self) { tag in
                        Text(tag).tag(tag)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var newTagChip: some View {
        if isAddingTag {
            InlineTextField(text: $newTag,
                            initialText: "",
                            fontSize: 11,
                            onSubmit: commitNewTag,
                            onCancel: cancelNewTag,
                            onBlur: commitNewTag)
                .frame(width: 78, height: 15)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.55)))
        } else {
            Button { isAddingTag = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 8, weight: .bold))
                    Text("New tag").font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(Capsule().strokeBorder(Theme.neutral300))
                .foregroundColor(Theme.neutral500)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help("Add a tag")
        }
    }

    /// Data actions live with the privacy note — that's what they're about, and
    /// as quiet links they stop outweighing the actual settings.
    private var footer: some View {
        HStack(spacing: 12) {
            Text("Entries stay on this Mac.")
                .font(.system(size: 11.5))
                .foregroundColor(Theme.neutral600)
                .fixedSize()
            link("Export…", action: exportAll)
            link("Import…", action: importAll)
            Spacer(minLength: 8)
            link("Quit Daybook") { NSApplication.shared.terminate(nil) }
        }
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(Theme.accent700)
            .pointingCursor()
    }

    // MARK: - Bindings

    private func binding<T>(_ keyPath: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { store.data.settings[keyPath: keyPath] },
                set: { store.data.settings[keyPath: keyPath] = $0 })
    }

    private var defaultTag: Binding<String> { binding(\.defaultTag) }

    private var weekStart: Binding<String> {
        Binding(get: { store.data.settings.weekStart.rawValue },
                set: { store.data.settings.weekStart = WeekStart(rawValue: $0) ?? .monday })
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: store.data.settings.reminderHour,
                                      minute: store.data.settings.reminderMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.data.settings.reminderHour = parts.hour ?? 17
                store.data.settings.reminderMinute = parts.minute ?? 0
            }
        )
    }

    // MARK: - Tag actions

    private func commitNewTag() {
        store.addTag(newTag)
        cancelNewTag()
    }

    private func cancelNewTag() {
        newTag = ""
        isAddingTag = false
    }

    // MARK: - Backup / restore

    private func exportAll() {
        guard let data = store.exportAllData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "daybook-backup-\(store.todayKey).json"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func importAll() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let raw = try? Data(contentsOf: url) else { return }

        guard let decoded = try? JSONDecoder().decode(StoreData.self, from: raw) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn't import this file"
            alert.informativeText = "It doesn't look like a Daybook backup (expected the JSON produced by “Export…”)."
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Replace Daybook data?"
        alert.informativeText = "This replaces all current entries, notes, and settings with the imported file (\(decoded.entries.count) entries). This can't be undone."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.replaceAllData(decoded)
        }
    }
}

// MARK: - Layout pieces

/// A titled group of rows on its own panel, in the spirit of System Settings.
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundColor(Theme.neutral500)
                .padding(.leading, 2)

            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.neutral100))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.neutral300))
        }
    }
}

/// Label on the left, control hugging the right — so no fixed label column is
/// needed and short labels don't leave a gutter of dead space.
private struct SettingsRow<Content: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder let content: () -> Content

    init(_ label: String, hint: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.hint = hint
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                if let hint {
                    Text(hint)
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.neutral500)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.leading, 12)
    }
}

/// A tag as a chip — click the name to rename in place, × to remove.
private struct EditableTagChip: View {
    let tag: String
    let canDelete: Bool
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var isHovering = false
    @State private var draft = ""

    var body: some View {
        if isEditing {
            InlineTextField(text: $draft,
                            initialText: tag,
                            fontSize: 11,
                            onSubmit: commit,
                            onCancel: { isEditing = false },
                            onBlur: commit)
                .frame(width: 78, height: 15)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.55)))
        } else {
            HStack(spacing: 5) {
                // Two sibling buttons rather than one nested in the other —
                // a Button inside a Button doesn't receive clicks on macOS.
                Button {
                    draft = tag
                    isEditing = true
                } label: {
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .help("Click to rename")

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                    // Space is reserved even when hidden, so chips don't resize on hover.
                    .opacity(isHovering ? 1 : 0)
                    .help("Delete tag — entries keep the label")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.neutral200))
            .foregroundColor(Theme.neutral700)
            .onHover { isHovering = $0 }
        }
    }

    private func commit() {
        isEditing = false
        onRename(draft)
    }
}
