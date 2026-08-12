import SwiftUI

/// The week's gate. A checkpoint is a thing that exists — a repo, a measured
/// result, a written document — and the plan only moves when you say it does.
struct RoadmapWeekView: View {
    @EnvironmentObject var store: Store

    private var weekNumber: Int { store.roadmapWeekNumber }
    private var week: RoadmapPlan.PlanWeek { store.roadmapWeek }
    private var ticked: Bool { store.isCheckpointTicked }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.shouldRenegotiate { renegotiateBanner }
            checkpointCard
            rhythmSection
            trackBalanceSection
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: - Renegotiate

    private var renegotiateBanner: some View {
        Text("Four unticked weeks in a row. The plan is wrong for your life right now — cut a track (usually Kotlin or NoSQL breadth) rather than abandoning the spine.")
            .font(Theme.font(13))
            .foregroundColor(Theme.orange700)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.orange100))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.orange300))
    }

    // MARK: - Checkpoint

    private var attemptLabel: String {
        let attempts = store.roadmapAttempts
        return attempts > 0 ? "Attempt \(attempts + 1)" : "First attempt"
    }

    private var ruleNote: String {
        let streak = store.roadmap.missStreak
        guard streak > 0 else {
            return "The checkpoint is a thing that exists — a repo, a measured result, a written document. Ticked on Sunday morning."
        }
        let weeks = streak == 1 ? "1 unticked week." : "\(streak) unticked weeks in a row."
        return "\(weeks) Repeating costs seven days; skipping costs an interview."
    }

    private var checkpointCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Kicker(text: "Checkpoint · Week \(weekNumber)", color: Theme.accent700)
                Spacer(minLength: 4)
                Text(attemptLabel)
                    .font(Theme.font(11.5))
                    .foregroundColor(Theme.neutral600)
                    .fixedSize()
            }

            HStack(alignment: .top, spacing: 10) {
                SquareCheck(done: ticked) { store.toggleCheckpoint() }
                Text(week.checkpoint)
                    .font(Theme.font(15))
                    .foregroundColor(ticked ? Theme.neutral700 : Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                PrimaryButton(title: nextLabel, enabled: ticked) { store.advanceRoadmapWeek() }
                SecondaryButton(title: "Couldn't tick — repeat") { store.repeatRoadmapWeek() }
            }

            Text(ruleNote)
                .font(Theme.font(12))
                .foregroundColor(Theme.neutral600)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent100))
    }

    /// Week 120 has nowhere to advance to; the plan is done.
    private var nextLabel: String {
        weekNumber >= RoadmapPlan.totalWeeks ? "Ticked — plan complete" : "Ticked — start week \(weekNumber + 1)"
    }

    // MARK: - Rhythm

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Kicker(text: "This week's rhythm")
            VStack(spacing: 5) {
                ForEach(RoadmapPlan.rhythm) { day in
                    let total = day.slots.count
                    let done = (0..<total).filter { store.isSlotDone(day: day.index, slot: $0) }.count
                    MeterRow(label: day.dow,
                             value: total == 0 ? 0 : Double(done) / Double(total),
                             trailing: "\(done)/\(total)")
                }
            }
        }
    }

    // MARK: - Track balance

    private var trackBalanceSection: some View {
        let entries = store.roadmapWeekEntries
        let counts = RoadmapPlan.tracks.map { name in
            (name, entries.filter { $0.track == name }.count)
        }
        let peak = max(1, counts.map(\.1).max() ?? 1)

        return VStack(alignment: .leading, spacing: 7) {
            Kicker(text: "Track balance")
            VStack(spacing: 5) {
                ForEach(counts, id: \.0) { name, count in
                    MeterRow(label: name,
                             value: Double(count) / Double(peak),
                             trailing: "\(count)",
                             labelWidth: 96,
                             trailingWidth: 22,
                             tint: Theme.orange500)
                }
            }
        }
    }
}
