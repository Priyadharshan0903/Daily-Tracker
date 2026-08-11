import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab: Tab = .today
    /// Date state lives here so the header can drive it. nil = the real today.
    @State private var selectedDay: String?
    @State private var showCalendar = false
    @State private var showWorkspaces = false
    @Namespace private var tabNamespace

    enum Tab: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case settings = "Settings"
    }

    private var dayKey: String { selectedDay ?? store.todayKey }
    private var isToday: Bool { dayKey == store.todayKey }

    private func select(_ item: Tab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            tab = item
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
                    switch tab {
                    case .today: TodayView(selectedDay: $selectedDay, showCalendar: $showCalendar)
                    case .week: WeekView()
                    case .settings: SettingsView()
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
                .font(.system(size: 17, weight: .semibold))
                .fixedSize()
            Spacer(minLength: 8)
            if tab == .today {
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
                    .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 10, weight: .bold))
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
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button {
                    select(item)
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if tab == item {
                                Capsule()
                                    .fill(Theme.accent)
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                        .foregroundColor(tab == item ? .white : Theme.neutral700)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .pointingCursor()
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.neutral200))
        .padding(EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18))
    }

    private var quipFooter: some View {
        let entries = store.entries(on: dayKey)
        let done = entries.filter(\.done).count
        let quip: String
        if entries.isEmpty {
            quip = "Nothing in the books yet — add the first one."
        } else if done == entries.count {
            quip = "All \(entries.count) in the books. Nice work."
        } else {
            quip = "\(done) of \(entries.count) in the books. Keep it rolling."
        }
        return VStack(spacing: 0) {
            Rectangle().fill(Theme.divider).frame(height: 1)
            HStack(spacing: 10) {
                // The quip absorbs the slack; the switcher keeps its natural
                // width so the footer can never push the popover wider.
                Text(quip)
                    .font(.system(size: 13))
                    .italic()
                    .foregroundColor(Theme.neutral600)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                WorkspaceButton(isOpen: $showWorkspaces)
                    .fixedSize()
            }
            .padding(EdgeInsets(top: 8, leading: 18, bottom: 9, trailing: 14))
        }
    }

    private func closeWorkspaces() {
        withAnimation(.easeOut(duration: 0.18)) { showWorkspaces = false }
    }
}
