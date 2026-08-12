import SwiftUI

/// Today against the plan: the rhythm slots for this weekday, plus anything
/// extra you logged. The rhythm is fixed — the week is what changes.
struct RoadmapTodayView: View {
    @EnvironmentObject var store: Store
    @State private var draft = ""
    @State private var pickedTrack: String?

    private var dayIndex: Int { store.roadmapDayIndex }
    private var day: RoadmapPlan.RhythmDay { RoadmapPlan.rhythm[dayIndex] }
    private var week: RoadmapPlan.PlanWeek { store.roadmapWeek }
    private var track: String { pickedTrack ?? RoadmapPlan.tracks[0] }

    private var todayEntries: [RoadmapEntry] {
        store.roadmapWeekEntries.filter { $0.dayIndex == dayIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            heading
            slots
            addRow
            trackChips
            logged
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Kicker(text: "\(day.dow) · rhythm")
            Text(week.focus)
                .font(Theme.font(15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(week.also)
                .font(Theme.font(12.5))
                .foregroundColor(Theme.neutral600)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var slots: some View {
        VStack(spacing: 2) {
            ForEach(Array(day.slots.enumerated()), id: \.offset) { index, slot in
                let done = store.isSlotDone(day: dayIndex, slot: index)
                HStack(spacing: 10) {
                    SquareCheck(done: done) { store.toggleSlot(day: dayIndex, slot: index) }
                    Text(RoadmapPlan.slotLabel(slot, week: week))
                        .font(Theme.font(14.5))
                        .strikethrough(done)
                        .foregroundColor(done ? Theme.neutral600 : Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 7)
            }
        }
    }

    private var addRow: some View {
        InputPill(placeholder: "Log something extra…", text: $draft, onSubmit: add) {
            PillButton(title: "Add", action: add)
        }
    }

    private var trackChips: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(RoadmapPlan.tracks, id: \.self) { name in
                TagChip(label: name, selected: name == track) { pickedTrack = name }
            }
        }
    }

    @ViewBuilder
    private var logged: some View {
        if todayEntries.isEmpty {
            Text("Just the rhythm today. Anything extra you log lands here.")
                .font(Theme.font(13.5))
                .italic()
                .foregroundColor(Theme.neutral500)
                .padding(.horizontal, 6)
        } else {
            VStack(spacing: 2) {
                ForEach(todayEntries) { entry in
                    HStack(spacing: 10) {
                        SquareCheck(done: entry.done) { store.toggleRoadmapEntry(entry.id) }
                        Text(entry.text)
                            .font(Theme.font(14.5))
                            .strikethrough(entry.done)
                            .foregroundColor(entry.done ? Theme.neutral600 : Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TagBadge(label: entry.track)
                        RowIconButton(systemName: "xmark", help: "Delete", size: 10, danger: true) {
                            store.removeRoadmapEntry(entry.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 7)
                }
            }
        }
    }

    private func add() {
        store.addRoadmapEntry(draft, track: track)
        draft = ""
    }
}
