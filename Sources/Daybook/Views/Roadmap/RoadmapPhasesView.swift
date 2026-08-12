import SwiftUI

/// The whole two years at a glance: ten phases, where you are in them.
struct RoadmapPhasesView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let current = store.roadmapWeekNumber

        VStack(spacing: 9) {
            ForEach(RoadmapPlan.phases) { phase in
                card(for: phase, currentWeek: current)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 16, trailing: 18))
    }

    private func card(for phase: RoadmapPlan.Phase, currentWeek: Int) -> some View {
        let isCurrent = currentWeek >= phase.from && currentWeek <= phase.to
        let isPast = currentWeek > phase.to
        // Weeks finished inside this phase — the current week is still in play.
        let done = max(0, min(phase.to, currentWeek - 1) - phase.from + 1)
        let status = isPast ? "done" : (isCurrent ? "in progress" : "ahead")

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Phase \(phase.n)")
                    .font(Theme.font(13.5, weight: .bold))
                Spacer(minLength: 4)
                Text("Weeks \(phase.from)–\(phase.to) · \(status)")
                    .font(Theme.font(11.5))
                    .foregroundColor(Theme.neutral600)
                    .fixedSize()
            }
            Text(phase.theme)
                .font(Theme.font(13))
                .foregroundColor(Theme.neutral700)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 3)
            ProgressBar(value: Double(done) / Double(phase.weekCount))
                .padding(.top, 7)
        }
        .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
        .background(RoundedRectangle(cornerRadius: 12).fill(isCurrent ? Theme.accent100 : Theme.neutral200))
        .opacity(isPast ? 0.6 : 1)
    }
}
