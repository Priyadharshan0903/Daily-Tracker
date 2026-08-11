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

            // spacing 0 — each day carries its own bottom padding so the timeline
            // rail runs unbroken from one day's dot to the next.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(week.days.enumerated()), id: \.element.id) { index, day in
                    daySection(day,
                               isFirst: index == 0,
                               isLast: index == week.days.count - 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)

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
    private func daySection(_ day: DayVM, isFirst: Bool, isLast: Bool) -> some View {
        let isEmpty = day.entries.isEmpty

        return HStack(alignment: .top, spacing: 10) {
            timelineRail(isFirst: isFirst,
                         isLast: isLast,
                         hasEntries: !isEmpty,
                         isToday: day.key == store.todayKey)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    dayLabel(day, muted: isEmpty)
                    Spacer(minLength: 8)
                    dayCount(day)
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.neutral500)
                        .fixedSize()
                }
                if !isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(day.entries) { entry in
                            WeekEntryLine(entry: entry)
                        }
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }

    private func dayCount(_ day: DayVM) -> Text {
        if day.entries.isEmpty { return Text("No entries").italic() }
        return Text(day.entries.count == 1 ? "1 entry" : "\(day.entries.count) entries")
    }

    /// Dot for the day, joined to its neighbours by a hairline so the week reads
    /// as one continuous thread.
    private func timelineRail(isFirst: Bool, isLast: Bool, hasEntries: Bool, isToday: Bool) -> some View {
        VStack(spacing: 0) {
            // 1pt stub keeps the dot's centre aligned with the day label,
            // and continues the line coming down from the previous day.
            Rectangle()
                .fill(isFirst ? Color.clear : Theme.neutral300)
                .frame(width: 1, height: 1)

            ZStack {
                if isToday {
                    Circle().fill(Theme.accent200)
                }
                Circle()
                    .fill(hasEntries ? Theme.accent : Theme.neutral300)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 13, height: 13)

            Rectangle()
                .fill(isLast ? Color.clear : Theme.neutral300)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 13)
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
            // Padding lives on the ZStack so the placeholder and the text view
            // share one origin — no per-child tuning against AppKit's insets.
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.neutral500)
                        .allowsHitTesting(false)
                }
                NotesTextView(text: text, fontSize: 13)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
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
