import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var draft = ""
    @State private var draftTag: String?
    /// nil = the real today; set when browsing another day.
    @State private var selectedDay: String?
    @State private var showCalendar = false

    private var dayKey: String { selectedDay ?? store.todayKey }
    private var isToday: Bool { dayKey == store.todayKey }

    /// nil draft = untouched (use the default); "" = deliberately untagged.
    private var currentTag: String {
        if let tag = draftTag, tag.isEmpty || store.data.settings.tags.contains(tag) { return tag }
        return store.data.settings.defaultTag
    }

    var body: some View {
        let dayEntries = store.entries(on: dayKey)
        let carried = store.carriedOver(before: dayKey)
        let done = dayEntries.filter(\.done).count

        VStack(alignment: .leading, spacing: 12) {
            header(done: done, total: dayEntries.count)

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
        .contentShape(Rectangle())
        // Buttons and fields consume their own taps, so this only fires on blank space.
        .onTapGesture { store.dismissEditingToken += 1 }
    }

    // MARK: - Header

    private func header(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                stepButton("chevron.left", disabled: false) { step(-1) }

                Button {
                    withAnimation(.easeOut(duration: 0.18)) { showCalendar.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text(store.longLabel(forDayKey: dayKey))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.neutral500)
                            .rotationEffect(.degrees(showCalendar ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .help(showCalendar ? "Close the date picker" : "Pick a date")

                stepButton("chevron.right", disabled: isToday) { step(1) }

                Spacer(minLength: 4)

                Text("\(done) of \(total) done")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.neutral600)
                    .fixedSize()
            }

            if !isToday {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selectedDay = nil }
                } label: {
                    Text("← Back to today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.accent700)
                }
                .buttonStyle(.plain)
                .pointingCursor()
            }
        }
    }

    private func stepButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(disabled ? Theme.neutral300 : Theme.neutral700)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .pointingCursor(!disabled)
    }

    private func step(_ delta: Int) {
        let next = store.shiftDay(dayKey, by: delta)
        guard next <= store.todayKey else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            selectedDay = next == store.todayKey ? nil : next
        }
    }

    // MARK: - Entries

    @ViewBuilder
    private func entriesSection(dayEntries: [Entry], carried: [Entry]) -> some View {
        if dayEntries.isEmpty && carried.isEmpty {
            Text("Nothing logged yet. The first line is the hardest.")
                .font(.system(size: 13.5))
                .italic()
                .foregroundColor(Theme.neutral500)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
        } else {
            FittedScrollView(maxHeight: 300) {
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
            }
        }
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
            .pointingCursor()
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
