import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab: Tab = .today
    /// Date state lives here so the header can drive it. nil = the real today.
    @State private var selectedDay: String?
    @State private var showCalendar = false
    @State private var showWorkspaces = false
    /// The roadmap is a second mode rather than a fourth tab: it has its own
    /// four screens, and none of them are about a calendar date.
    @State private var roadmapMode = false
    @State private var roadTab: RoadTab = .today
    @Namespace private var tabNamespace
    @Namespace private var roadNamespace

    enum Tab: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case settings = "Settings"
    }

    enum RoadTab: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case phases = "Phases"
        case library = "Library"
    }

    private var dayKey: String { selectedDay ?? store.todayKey }
    private var isToday: Bool { dayKey == store.todayKey }
    private var roadmapEnabled: Bool { store.data.settings.roadmapEnabled }

    private func select(_ item: Tab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            tab = item
        }
    }

    private func select(_ item: RoadTab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            roadTab = item
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Rectangle().fill(Theme.divider).frame(height: 1)

            // One scroll view for the whole content area; the tabs are plain
            // content. Nothing measures itself, so nothing can under-report and
            // spill over the footer.
            ScrollView {
                Group {
                    if roadmapMode {
                        switch roadTab {
                        case .today: RoadmapTodayView()
                        case .week: RoadmapWeekView()
                        case .phases: RoadmapPhasesView()
                        case .library: RoadmapLibraryView()
                        }
                    } else {
                        switch tab {
                        case .today: TodayView(selectedDay: $selectedDay, showCalendar: $showCalendar)
                        case .week: WeekView()
                        case .settings: SettingsView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .transition(.opacity)
            }
            .scrollIndicators(.never)
            .frame(height: Theme.contentHeight)

            quipFooter
        }
        .frame(width: Theme.popoverWidth)
        // Floats over the content, anchored to the switcher in the footer.
        .overlay {
            if showWorkspaces {
                ZStack(alignment: .bottomTrailing) {
                    Color.black.opacity(0.05)
                        .contentShape(Rectangle())
                        .onTapGesture { closeWorkspaces() }
                    WorkspacePanel(onDismiss: closeWorkspaces)
                        .padding(.trailing, 14)
                        .padding(.bottom, 42)
                }
                .transition(.opacity)
            }
        }
        // The date must be right the moment the popover is shown, whatever
        // happened while it was closed.
        .onAppear { store.refreshToday() }
        // Switching the feature off must never leave the popover on a screen
        // that is no longer reachable.
        .onChange(of: roadmapEnabled) { enabled in
            if !enabled { roadmapMode = false }
        }
        .background(Theme.surface)
        .foregroundColor(Theme.text)
        .tint(Theme.accent)
    }

    private var header: some View {
        HStack(spacing: 9) {
            // Full colour, so keep the template rendering off.
            Image(nsImage: TrayIcon.headerMark)
                .resizable()
                .frame(width: 20, height: 20)
            Text("Daybook")
                .font(Theme.font(17, weight: .semibold))
                .fixedSize()
            Spacer(minLength: 8)
            if !roadmapMode && tab == .today {
                dateNav
            }
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 0, trailing: 18))
    }

    private var dateNav: some View {
        HStack(spacing: 2) {
            stepButton("chevron.left", disabled: false) { step(-1) }

            Button {
                withAnimation(.easeOut(duration: 0.18)) { showCalendar.toggle() }
            } label: {
                Text(store.longLabel(forDayKey: dayKey))
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help(showCalendar ? "Close the date picker" : "Pick a date")

            stepButton("chevron.right", disabled: false) { step(1) }
        }
    }

    private func stepButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Theme.font(10, weight: .bold))
                .foregroundColor(disabled ? Theme.neutral300 : Theme.neutral700)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .pointingCursor(!disabled)
    }

    /// Any date, past or future — future days are for planning ahead.
    private func step(_ delta: Int) {
        let next = store.shiftDay(dayKey, by: delta)
        withAnimation(.easeOut(duration: 0.15)) {
            selectedDay = next == store.todayKey ? nil : next
        }
    }

    private var tabBar: some View {
        VStack(spacing: 10) {
            if roadmapMode {
                pillRow(labels: RoadTab.allCases.map(\.rawValue),
                        selected: RoadTab.allCases.firstIndex(of: roadTab) ?? 0,
                        namespace: roadNamespace,
                        geometryID: "activeRoadTab") { select(RoadTab.allCases[$0]) }
                progressStrip
            } else {
                pillRow(labels: Tab.allCases.map(\.rawValue),
                        selected: Tab.allCases.firstIndex(of: tab) ?? 0,
                        namespace: tabNamespace,
                        geometryID: "activeTab") { select(Tab.allCases[$0]) }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18))
    }

    /// The pill row itself. Shared so the roadmap's four tabs slide exactly the
    /// way the work tabs do — with their own geometry id, since the two bars
    /// replace each other rather than coexisting.
    private func pillRow(labels: [String],
                         selected: Int,
                         namespace: Namespace.ID,
                         geometryID: String,
                         onSelect: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Button {
                    onSelect(index)
                } label: {
                    Text(label)
                        .font(Theme.font(13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if index == selected {
                                Capsule()
                                    .fill(Theme.accent)
                                    .matchedGeometryEffect(id: geometryID, in: namespace)
                            }
                        }
                        .foregroundColor(index == selected ? .white : Theme.neutral700)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .pointingCursor()
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.neutral200))
    }

    /// Where you are in the 120 weeks. Replaces the date stepper, which has no
    /// meaning once the plan rather than the calendar decides what "now" is.
    private var progressStrip: some View {
        HStack(spacing: 10) {
            Kicker(text: "Week \(store.roadmapWeekNumber) / \(RoadmapPlan.totalWeeks)", color: Theme.accent700)
                .fixedSize()
            ProgressBar(value: Double(store.roadmapWeekNumber) / Double(RoadmapPlan.totalWeeks), height: 4)
            Text("Phase \(store.roadmapPhase.n)")
                .font(Theme.font(11.5))
                .foregroundColor(Theme.neutral600)
                .fixedSize()
        }
    }

    private var quipFooter: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.divider).frame(height: 1)
            HStack(spacing: 8) {
                // The quip absorbs the slack; the buttons keep their natural
                // width so the footer can never push the popover wider.
                Text(quip)
                    .font(Theme.font(13))
                    .italic()
                    .foregroundColor(Theme.neutral600)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if roadmapEnabled {
                    RoadmapButton(isOn: $roadmapMode)
                        .fixedSize()
                }
                WorkspaceButton(isOpen: $showWorkspaces)
                    .fixedSize()
            }
            .padding(EdgeInsets(top: 8, leading: 18, bottom: 9, trailing: 14))
        }
    }

    private var quip: String {
        if roadmapMode {
            let week = store.roadmapWeekNumber
            if store.isCheckpointTicked {
                return "Checkpoint ticked. Week \(week) is real."
            }
            let phase = store.roadmapPhase
            return "Week \(week) of \(RoadmapPlan.totalWeeks) · Phase \(phase.n) — \(phase.theme)"
        }
        let entries = store.entries(on: dayKey)
        let done = entries.filter(\.done).count
        if entries.isEmpty {
            return "Nothing in the books yet — add the first one."
        } else if done == entries.count {
            return "All \(entries.count) in the books. Nice work."
        } else {
            return "\(done) of \(entries.count) in the books. Keep it rolling."
        }
    }

    private func closeWorkspaces() {
        withAnimation(.easeOut(duration: 0.18)) { showWorkspaces = false }
    }
}
