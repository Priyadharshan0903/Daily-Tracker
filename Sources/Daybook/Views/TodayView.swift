import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var draft = ""
    @State private var draftTag: String?
    /// Owned by RootView so the app header can drive the date. nil = the real today.
    @Binding var selectedDay: String?
    @Binding var showCalendar: Bool

    private var dayKey: String { selectedDay ?? store.todayKey }
    private var isToday: Bool { dayKey == store.todayKey }

    /// nil draft = untouched (use the default); "" = deliberately untagged.
    private var currentTag: String {
        if let tag = draftTag, tag.isEmpty || store.data.settings.tags.contains(tag) { return tag }
        return store.data.settings.defaultTag
    }

    var body: some View {
        let dayEntries = store.entries(on: dayKey)
        // Future days are planning space — don't clutter them with today's leftovers.
        let carried = dayKey <= store.todayKey ? store.carriedOver(before: dayKey) : []
        VStack(alignment: .leading, spacing: 12) {
            if !isToday && !showCalendar {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selectedDay = nil }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Today")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent100))
                    .foregroundColor(Theme.accent700)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .help("Jump back to today")
            }

            if showCalendar {
                // Replaces the list while open so the popover doesn't balloon.
                CalendarPanel(selectedDay: dayKey,
                              todayKey: store.todayKey,
                              daysWithEntries: store.daysWithEntries,
                              daysWithUnfinished: store.daysWithUnfinished,
                              calendar: store.calendar) { picked in
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedDay = picked == store.todayKey ? nil : picked
                        showCalendar = false
                    }
                }
            } else {
                inputRow

                FlowLayout(spacing: 6, lineSpacing: 6) {
                    Text("File under")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.neutral600)
                        .padding(.vertical, 4)
                    ForEach(store.data.settings.tags, id: \.self) { tag in
                        TagChip(label: tag, selected: tag == currentTag) { draftTag = tag }
                    }
                    TagChip(label: "No tag", selected: currentTag.isEmpty) { draftTag = "" }
                }

                entriesSection(dayEntries: dayEntries, carried: carried)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
        // No container-wide tap gesture here. Inside a ScrollView, a SwiftUI tap
        // gesture wins the click over AppKit-backed text fields — even from the
        // background layer — which left the task field unfocusable. Editing is
        // committed by Return, the Save button, Esc, or focus moving away.
    }

    // MARK: - Entries

    @ViewBuilder
    private func entriesSection(dayEntries: [Entry], carried: [Entry]) -> some View {
        if dayEntries.isEmpty && carried.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 2) {
                if !carried.isEmpty {
                    sectionHeader("Carried over · \(carried.count) unfinished", color: Theme.orange700)
                    ForEach(carried) { entry in
                        EntryRow(entry: entry, originLabel: store.shortLabel(forDayKey: entry.day))
                    }
                    if !dayEntries.isEmpty {
                        sectionHeader(isToday ? "Today" : store.shortLabel(forDayKey: dayKey),
                                      color: Theme.neutral700)
                    }
                }
                ForEach(dayEntries) { entry in
                    EntryRow(entry: entry)
                }
            }
            // Breathing room so row highlights aren't flush against the clip edge.
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
        }
    }

    /// Fills the leftover height so the mark sits centred in the card.
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            VStack(spacing: 12) {
                Image(nsImage: TrayIcon.largeMark)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 46, height: 46)
                    .foregroundColor(Theme.neutral300)
                VStack(spacing: 3) {
                    Text(isToday ? "Nothing logged yet"
                                 : "Nothing planned for \(store.shortLabel(forDayKey: dayKey))")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(Theme.neutral600)
                    Text("The first line is the hardest.")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(Theme.neutral500)
                }
            }
            Spacer(minLength: 8)
        }
        // Roughly the space left under the input row, so the mark sits centred.
        .frame(maxWidth: .infinity, minHeight: 215)
    }

    private func sectionHeader(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.8)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    // MARK: - Input

    private var inputRow: some View {
        HStack(spacing: 8) {
            PlaceholderField(placeholder: isToday ? "Add a task for today…"
                                                  : "Add a task for \(store.shortLabel(forDayKey: dayKey))…",
                             text: $draft,
                             onSubmit: add)
            Button(action: add) {
                Text("Add")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundColor(.white)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .pointingCursor()
            .help("Add task (⌘↩)")
        }
        .padding(.leading, 14)
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.neutral200))
    }

    private func add() {
        store.addEntry(text: draft, tag: currentTag, day: dayKey)
        draft = ""
    }
}
