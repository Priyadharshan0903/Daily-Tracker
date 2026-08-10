import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WeekView: View {
    @EnvironmentObject var store: Store
    /// nil = current (latest) week.
    @State private var weekIdx: Int?

    var body: some View {
        let starts = store.weekStarts
        let idx = min(weekIdx ?? starts.count - 1, starts.count - 1)
        let week = store.weekVM(startingAt: starts[max(idx, 0)])

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                navButton(system: "chevron.left", disabled: idx <= 0) { weekIdx = idx - 1 }
                Spacer(minLength: 0)
                Text(week.label)
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 0)
                navButton(system: "chevron.right", disabled: idx >= starts.count - 1) { weekIdx = idx + 1 }
            }
            .padding(.bottom, 10)

            divider

            FittedScrollView(maxHeight: 250) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(week.days) { day in
                        daySection(day)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            }

            divider

            VStack(alignment: .leading, spacing: 10) {
                noteField(title: "Highlights", titleColor: Theme.neutral700,
                          placeholder: "What went well this week?",
                          text: notesBinding(week.id, \.highlights))
                noteField(title: "Blockers", titleColor: Theme.orange700,
                          placeholder: "Anything in the way?",
                          text: notesBinding(week.id, \.blockers))
            }
            .padding(.top, 14)

            HStack(spacing: 8) {
                SecondaryButton(title: "Download .json") { exportJSON(week: week) }
                PrimaryButton(title: "Open report page") {
                    ReportGenerator.openReport(week: week, notes: store.notes(forWeek: week.id))
                }
            }
            .padding(.top, 14)
        }
        .padding(EdgeInsets(top: 12, leading: 18, bottom: 16, trailing: 18))
    }

    private var divider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
    }

    private func navButton(system: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundColor(disabled ? Theme.neutral500 : Theme.text)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .pointingCursor(!disabled)
    }

    /// Empty days collapse to a single line — a lone "—" under every empty day
    /// left the list full of orphaned dashes and dead space.
    @ViewBuilder
    private func daySection(_ day: DayVM) -> some View {
        if day.entries.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                dayLabel(day, muted: true)
                Spacer(minLength: 8)
                Text("No entries")
                    .font(.system(size: 11.5))
                    .italic()
                    .foregroundColor(Theme.neutral500)
                    .fixedSize()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    dayLabel(day, muted: false)
                    Spacer(minLength: 8)
                    Text(day.entries.count == 1 ? "1 entry" : "\(day.entries.count) entries")
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.neutral500)
                        .fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(day.entries) { entry in
                        WeekEntryLine(entry: entry)
                    }
                }
            }
        }
    }

    private func dayLabel(_ day: DayVM, muted: Bool) -> some View {
        Text("\(day.dow.uppercased()) · \(day.dateLabel.uppercased())")
            .font(.system(size: 11.5, weight: .semibold))
            .kerning(0.8)
            .foregroundColor(muted ? Theme.neutral500 : Theme.neutral700)
            .lineLimit(1)
    }

    private func noteField(title: String, titleColor: Color, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(titleColor)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.neutral500)
                        .padding(.top, 6)
                        .padding(.leading, 7)
                }
                TextEditor(text: text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 3)
            }
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.neutral100))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.neutral300))
        }
    }

    private func notesBinding(_ weekID: String, _ keyPath: WritableKeyPath<WeekNotes, String>) -> Binding<String> {
        Binding(
            get: { store.notes(forWeek: weekID)[keyPath: keyPath] },
            set: { value in
                var notes = store.notes(forWeek: weekID)
                notes[keyPath: keyPath] = value
                store.setNotes(notes, forWeek: weekID)
            }
        )
    }

    private func exportJSON(week: WeekVM) {
        let export = ExportWeek(week: week, notes: store.notes(forWeek: week.id))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(export) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "daybook-\(week.id).json"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
