import Foundation

/// Roadmap reads and writes, scoped to the active workspace like everything else.
///
/// The plan never advances on its own: a week ends when its checkpoint is ticked
/// and you say so. That is the whole point of the gate — the calendar moving is
/// not evidence that the work happened.
extension Store {

    // MARK: - Reading

    var roadmap: RoadmapState { activeWorkspace.roadmap }

    var roadmapWeekNumber: Int {
        min(max(activeWorkspace.roadmap.planWeek, 1), RoadmapPlan.totalWeeks)
    }

    var roadmapWeek: RoadmapPlan.PlanWeek { RoadmapPlan.week(roadmapWeekNumber) }

    var roadmapPhase: RoadmapPlan.Phase { RoadmapPlan.phase(forWeek: roadmapWeekNumber) }

    /// Today as a rhythm index: 0 = Monday … 6 = Sunday. Independent of the
    /// week-start preference — the rhythm itself is written Monday-first.
    var roadmapDayIndex: Int {
        let weekday = calendar.component(.weekday, from: Date()) // 1 = Sunday
        return (weekday + 5) % 7
    }

    var isCheckpointTicked: Bool { roadmap.ticked.contains(roadmapWeekNumber) }

    var roadmapAttempts: Int { roadmap.attempts[String(roadmapWeekNumber)] ?? 0 }

    func isSlotDone(day: Int, slot: Int) -> Bool {
        roadmap.slotDone.contains(RoadmapState.slotKey(week: roadmapWeekNumber, day: day, slot: slot))
    }

    /// Entries logged against the current plan week.
    var roadmapWeekEntries: [RoadmapEntry] {
        roadmap.entries.filter { $0.week == roadmapWeekNumber }
    }

    func isResourceRead(_ id: String) -> Bool { roadmap.resourceDone.contains(id) }

    // MARK: - Writing

    private func mutateRoadmap(_ change: (inout RoadmapState) -> Void) {
        mutateActive { change(&$0.roadmap) }
    }

    func toggleSlot(day: Int, slot: Int) {
        let key = RoadmapState.slotKey(week: roadmapWeekNumber, day: day, slot: slot)
        mutateRoadmap { state in
            if state.slotDone.contains(key) {
                state.slotDone.remove(key)
            } else {
                state.slotDone.insert(key)
            }
        }
    }

    func toggleCheckpoint() {
        let week = roadmapWeekNumber
        mutateRoadmap { state in
            if state.ticked.contains(week) {
                state.ticked.remove(week)
            } else {
                state.ticked.insert(week)
            }
        }
    }

    /// Moves to the next week. Only reachable once the checkpoint is ticked, so
    /// the streak resets here.
    func advanceRoadmapWeek() {
        guard isCheckpointTicked else { return }
        mutateRoadmap { state in
            state.planWeek = min(RoadmapPlan.totalWeeks, state.planWeek + 1)
            state.missStreak = 0
        }
    }

    /// Repeats the week. Costs seven days; skipping costs an interview.
    func repeatRoadmapWeek() {
        let week = roadmapWeekNumber
        mutateRoadmap { state in
            state.attempts[String(week), default: 0] += 1
            state.missStreak += 1
            state.ticked.remove(week)
        }
    }

    var shouldRenegotiate: Bool { roadmap.missStreak >= 4 }

    func addRoadmapEntry(_ text: String, track: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = RoadmapEntry(text: trimmed,
                                 track: track,
                                 week: roadmapWeekNumber,
                                 dayIndex: roadmapDayIndex)
        mutateRoadmap { $0.entries.append(entry) }
    }

    func toggleRoadmapEntry(_ id: UUID) {
        mutateRoadmap { state in
            guard let index = state.entries.firstIndex(where: { $0.id == id }) else { return }
            state.entries[index].done.toggle()
        }
    }

    func removeRoadmapEntry(_ id: UUID) {
        mutateRoadmap { $0.entries.removeAll { $0.id == id } }
    }

    func toggleResourceRead(_ id: String) {
        mutateRoadmap { state in
            if state.resourceDone.contains(id) {
                state.resourceDone.remove(id)
            } else {
                state.resourceDone.insert(id)
            }
        }
    }

    /// Bare hostnames are common when pasting; assume https rather than failing
    /// to open later.
    func addCustomResource(title: String, url: String, track: String) {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !address.isEmpty else { return }
        let normalised = address.hasPrefix("http://") || address.hasPrefix("https://")
            ? address
            : "https://\(address)"
        mutateRoadmap {
            $0.customResources.append(CustomResource(title: name, url: normalised, track: track))
        }
    }

    func removeCustomResource(_ id: UUID) {
        mutateRoadmap { $0.customResources.removeAll { $0.id == id } }
    }
}
