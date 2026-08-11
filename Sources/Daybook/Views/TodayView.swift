import AppKit
import SwiftUI

/// Keyboard selection state. A reference type because the key monitor's closure
/// would otherwise capture a stale snapshot of the view's `@State`.
@MainActor
final class ListNavigator: ObservableObject {
    @Published var selectedID: UUID?
    /// Visible order, refreshed by the view as the list changes.
    var visibleIDs: [UUID] = []

    func move(_ delta: Int) {
        guard !visibleIDs.isEmpty else { return }
        guard let current = selectedID, let index = visibleIDs.firstIndex(of: current) else {
            selectedID = delta > 0 ? visibleIDs.first : visibleIDs.last
            return
        }
        let next = index + delta
        guard visibleIDs.indices.contains(next) else { return }
        selectedID = visibleIDs[next]
    }

    /// Keep a sensible selection after the current row disappears.
    func selectNeighbour(of id: UUID) {
        guard let index = visibleIDs.firstIndex(of: id) else { return }
        if visibleIDs.indices.contains(index + 1) {
            selectedID = visibleIDs[index + 1]
        } else if visibleIDs.indices.contains(index - 1) {
            selectedID = visibleIDs[index - 1]
        } else {
            selectedID = nil
        }
    }
}

struct TodayView: View {
    @EnvironmentObject var store: Store
    @StateObject private var nav = ListNavigator()
    @StateObject private var reorder = ReorderController()
    @State private var keyMonitor: Any?
    @State private var draft = ""
    @State private var draftTag: String?
    @State private var addFocused = false
    @State private var showFilters = false
    @State private var tagFilter: String?
    @State private var showDone = false
    /// Owned by RootView so the app header can drive the date. nil = the real today.
    @Binding var selectedDay: String?
    @Binding var showCalendar: Bool

    private var dayKey: String { selectedDay ?? store.todayKey }
    private var isToday: Bool { dayKey == store.todayKey }

    /// nil draft = untouched (use the default); "" = deliberately untagged.
    private var currentTag: String {
        if let tag = draftTag, tag.isEmpty || store.tags.contains(tag) { return tag }
        return store.defaultTag
    }

    /// The tag picker only earns its space while you're actually composing.
    private var composing: Bool { addFocused || !draft.isEmpty }

    private func matchesFilter(_ entry: Entry) -> Bool {
        guard let tagFilter else { return true }
        return entry.tag == tagFilter
    }

    var body: some View {
        let allDay = store.entries(on: dayKey)
        // Future days are planning space — don't clutter them with today's leftovers.
        let allCarried = dayKey <= store.todayKey ? store.carriedOver(before: dayKey) : []
        let carried = allCarried.filter(matchesFilter)
        let dayEntries = allDay.filter(matchesFilter)
        let active = dayEntries.filter { !$0.done }
        let done = dayEntries.filter(\.done)
        let visibleIDs = carried.map(\.id) + active.map(\.id) + (showDone ? done.map(\.id) : [])

        VStack(alignment: .leading, spacing: 12) {
            if !isToday && !showCalendar { backToToday }

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

                if composing { fileUnderRow }
                if showFilters { filterChips }

                entriesSection(active: active,
                               done: done,
                               carried: carried,
                               hasAnyEntries: !allDay.isEmpty || !allCarried.isEmpty)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
        .environmentObject(reorder)
        .coordinateSpace(name: ReorderController.space)
        .onPreferenceChange(RowFramesKey.self) { reorder.frames = $0 }
        .onAppear {
            nav.visibleIDs = visibleIDs
            installKeyMonitor()
        }
        .onDisappear(perform: removeKeyMonitor)
        .onChange(of: visibleIDs) { nav.visibleIDs = $0 }
        // No container-wide tap gesture here. Inside a ScrollView, a SwiftUI tap
        // gesture wins the click over AppKit-backed text fields — even from the
        // background layer — which left the task field unfocusable. Editing is
        // committed by Return, the Save button, Esc, or focus moving away.
    }

    // MARK: - Header bits

    private var backToToday: some View {
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

    private var fileUnderRow: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            Text("File under")
                .font(.system(size: 12))
                .foregroundColor(Theme.neutral600)
                .padding(.vertical, 4)
            ForEach(store.tags, id: \.self) { tag in
                TagChip(label: tag, selected: tag == currentTag) { draftTag = tag }
            }
            TagChip(label: "No tag", selected: currentTag.isEmpty) { draftTag = "" }
        }
    }

    private var filterChips: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            Text("Show")
                .font(.system(size: 12))
                .foregroundColor(Theme.neutral600)
                .padding(.vertical, 4)
            TagChip(label: "All", selected: tagFilter == nil) { setFilter(nil) }
            ForEach(store.tags, id: \.self) { tag in
                TagChip(label: tag, selected: tagFilter == tag) { setFilter(tag) }
            }
            TagChip(label: "No tag", selected: tagFilter == "") { setFilter("") }
        }
    }

    private func setFilter(_ tag: String?) {
        withAnimation(.easeOut(duration: 0.18)) {
            tagFilter = tag
            showFilters = false
        }
    }

    // MARK: - Entries

    @ViewBuilder
    private func entriesSection(active: [Entry], done: [Entry], carried: [Entry], hasAnyEntries: Bool) -> some View {
        if active.isEmpty && done.isEmpty && carried.isEmpty {
            if hasAnyEntries {
                noMatchesState
            } else {
                emptyState
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                if !carried.isEmpty {
                    sectionHeader("Carried over · \(carried.count) unfinished", color: Theme.orange700)
                    ForEach(carried) { entry in
                        EntryRow(entry: entry,
                                 originLabel: store.shortLabel(forDayKey: entry.day),
                                 isSelected: nav.selectedID == entry.id)
                    }
                    if !active.isEmpty || !done.isEmpty {
                        sectionHeader(isToday ? "Today" : store.shortLabel(forDayKey: dayKey),
                                      color: Theme.neutral700)
                    }
                }

                ForEach(active) { entry in
                    EntryRow(entry: entry,
                             isSelected: nav.selectedID == entry.id,
                             isReorderable: true)
                }

                // Finished work folds away so the live list stays at the top.
                if !done.isEmpty {
                    doneDisclosure(count: done.count)
                    if showDone {
                        ForEach(done) { entry in
                            EntryRow(entry: entry, isSelected: nav.selectedID == entry.id)
                        }
                    }
                }
            }
            // Breathing room so row highlights aren't flush against the clip edge.
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
        }
    }

    private func doneDisclosure(count: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { showDone.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(showDone ? 90 : 0))
                Text("\(count) done")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
            }
            .foregroundColor(Theme.neutral500)
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingCursor()
        .help(showDone ? "Hide completed" : "Show completed")
    }

    private var noMatchesState: some View {
        VStack(spacing: 6) {
            Text("Nothing tagged \(tagFilter?.isEmpty == false ? tagFilter! : "“No tag”")")
                .font(.system(size: 13))
                .foregroundColor(Theme.neutral600)
            Button("Clear filter") { setFilter(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.accent700)
                .pointingCursor()
        }
        .frame(maxWidth: .infinity, minHeight: 160)
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
                             isFocused: $addFocused,
                             onSubmit: add)

            Button {
                withAnimation(.easeOut(duration: 0.18)) { showFilters.toggle() }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tagFilter == nil ? Theme.neutral500 : Theme.accent)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle().fill(tagFilter == nil ? Color.clear : Theme.accent200)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help(tagFilter == nil ? "Filter by tag" : "Filtered by \(tagFilter!.isEmpty ? "No tag" : tagFilter!)")

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

    // MARK: - Keyboard navigation

    /// ↑/↓ to move, Space to toggle, ⌘⌫ to delete. A local monitor rather than
    /// SwiftUI focus: the rows aren't focusable controls, and this also lets us
    /// stand down cleanly whenever a text field has the keyboard.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Never steal keys while typing.
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }

            let command = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .contains(.command)

            switch event.keyCode {
            case 126 where command:                     // ⌘↑ — reorder up
                guard let id = nav.selectedID else { return event }
                store.moveEntry(id, by: -1)
                return nil
            case 125 where command:                     // ⌘↓ — reorder down
                guard let id = nav.selectedID else { return event }
                store.moveEntry(id, by: 1)
                return nil
            case 126:                                   // ↑
                nav.move(-1)
                return nil
            case 125:                                   // ↓
                nav.move(1)
                return nil
            case 49:                                    // space
                guard let id = nav.selectedID else { return event }
                store.toggle(id)
                return nil
            case 51 where command:                      // ⌘⌫
                guard let id = nav.selectedID else { return event }
                nav.selectNeighbour(of: id)
                store.remove(id)
                return nil
            case 53:                                    // esc clears the selection
                guard nav.selectedID != nil else { return event }
                nav.selectedID = nil
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
