import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var newTag = ""

    private let labelWidth: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Daily reminder") {
                HStack(spacing: 10) {
                    Toggle("", isOn: binding(\.reminderEnabled))
                        .toggleStyle(DaybookToggleStyle())
                        .labelsHidden()
                    DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .disabled(!store.data.settings.reminderEnabled)
                        .opacity(store.data.settings.reminderEnabled ? 1 : 0.45)
                    if !Reminders.available {
                        Text("(bundle only)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.neutral500)
                    }
                }
            }
            divider

            row("Week starts on") {
                SegmentedPicker(options: WeekStart.allCases.map(\.rawValue), selection: weekStartBinding)
            }
            divider

            row("Launch at login") {
                Toggle("", isOn: binding(\.launchAtLogin))
                    .toggleStyle(DaybookToggleStyle())
                    .labelsHidden()
            }
            divider

            tagsSection
            divider

            row("Data") {
                HStack(spacing: 8) {
                    SecondaryButton(title: "Export all…", action: exportAll)
                    SecondaryButton(title: "Import…", action: importAll)
                }
            }
            divider

            HStack(alignment: .firstTextBaseline) {
                Text("Entries stay on this Mac. Export a week as JSON or a report page any time.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.neutral600)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Quit Daybook") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accent700)
                    .pointingCursor()
            }
            .padding(.top, 12)
        }
        .padding(EdgeInsets(top: 6, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: - Layout helpers

    private var divider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: labelWidth, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    private var tagsSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tags")
                    .font(.system(size: 13, weight: .medium))
                Text("Radio marks the default for new tasks")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.neutral500)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: labelWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Button {
                        store.data.settings.defaultTag = ""
                    } label: {
                        ZStack {
                            Circle().strokeBorder(store.data.settings.defaultTag.isEmpty ? Theme.accent : Theme.neutral500,
                                                  lineWidth: 1.5)
                            if store.data.settings.defaultTag.isEmpty {
                                Circle().fill(Theme.accent).frame(width: 7, height: 7)
                            }
                        }
                        .frame(width: 14, height: 14)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                    .help("New tasks start with no tag")
                    Text("No tag")
                        .font(.system(size: 12.5))
                        .foregroundColor(Theme.neutral600)
                }
                ForEach(store.data.settings.tags, id: \.self) { tag in
                    TagEditRow(tag: tag,
                               isDefault: tag == store.data.settings.defaultTag,
                               canDelete: store.data.settings.tags.count > 1,
                               onMakeDefault: { store.data.settings.defaultTag = tag },
                               onRename: { store.renameTag(tag, to: $0) },
                               onDelete: { store.deleteTag(tag) })
                }
                HStack(spacing: 6) {
                    Circle()
                        .strokeBorder(Color.clear, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    PlaceholderField(placeholder: "New tag…", text: $newTag, size: 12.5, onSubmit: addTag)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.neutral300))
                        .frame(width: 132)
                    Button("Add", action: addTag)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? Theme.neutral500 : Theme.accent700)
                        .pointingCursor()
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(.vertical, 11)
    }

    // MARK: - Bindings

    private func binding<T>(_ keyPath: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(
            get: { store.data.settings[keyPath: keyPath] },
            set: { store.data.settings[keyPath: keyPath] = $0 }
        )
    }

    private var weekStartBinding: Binding<String> {
        Binding(
            get: { store.data.settings.weekStart.rawValue },
            set: { store.data.settings.weekStart = WeekStart(rawValue: $0) ?? .monday }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: store.data.settings.reminderHour,
                                      minute: store.data.settings.reminderMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.data.settings.reminderHour = comps.hour ?? 17
                store.data.settings.reminderMinute = comps.minute ?? 0
            }
        )
    }

    private func addTag() {
        store.addTag(newTag)
        newTag = ""
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
            alert.informativeText = "It doesn't look like a Daybook backup (expected the JSON produced by “Export all data”)."
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

/// One editable tag row: radio marks the default, rename via Enter/Save, delete via ×.
private struct TagEditRow: View {
    let tag: String
    let isDefault: Bool
    let canDelete: Bool
    let onMakeDefault: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    @State private var text: String

    init(tag: String, isDefault: Bool, canDelete: Bool,
         onMakeDefault: @escaping () -> Void,
         onRename: @escaping (String) -> Void,
         onDelete: @escaping () -> Void) {
        self.tag = tag
        self.isDefault = isDefault
        self.canDelete = canDelete
        self.onMakeDefault = onMakeDefault
        self.onRename = onRename
        self.onDelete = onDelete
        _text = State(initialValue: tag)
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onMakeDefault) {
                ZStack {
                    Circle().strokeBorder(isDefault ? Theme.accent : Theme.neutral500, lineWidth: 1.5)
                    if isDefault {
                        Circle().fill(Theme.accent).frame(width: 7, height: 7)
                    }
                }
                .frame(width: 14, height: 14)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help("Use as default tag")

            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5))
                .frame(width: 132)
                .onSubmit { onRename(text) }

            if text.trimmingCharacters(in: .whitespacesAndNewlines) != tag {
                Button("Save") { onRename(text) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.accent700)
                    .pointingCursor()
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(canDelete ? Theme.neutral500 : Theme.neutral300)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canDelete)
            .pointingCursor(canDelete)
            .help(canDelete ? "Delete tag (existing entries keep it)" : "At least one tag is required")
        }
    }
}
