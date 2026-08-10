import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab: Tab = .today
    @Namespace private var tabNamespace

    enum Tab: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case settings = "Settings"
    }

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

            Group {
                switch tab {
                case .today: TodayView()
                case .week: WeekView()
                case .settings: SettingsView()
                }
            }
            .transition(.opacity)

            quipFooter
        }
        .frame(width: Theme.popoverWidth)
        .background(Theme.surface)
        .foregroundColor(Theme.text)
        .tint(Theme.accent)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Circle().fill(Theme.accent).frame(width: 9, height: 9)
            Text("Daybook")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            Button {
                select(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.neutral600)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help("Settings")
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 0, trailing: 18))
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
        let entries = store.todayEntries
        let done = entries.filter(\.done).count
        let quip: String
        if entries.isEmpty {
            quip = "nothing in the books yet — add the first one."
        } else if done == entries.count {
            quip = "all in the books. bear approves ʕ•ᴥ•ʔ"
        } else {
            quip = "\(done) in the books. keep it rolling."
        }
        return VStack(spacing: 0) {
            Rectangle().fill(Theme.divider).frame(height: 1)
            Text(quip)
                .font(.system(size: 13))
                .italic()
                .foregroundColor(Theme.neutral600)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 10, leading: 18, bottom: 12, trailing: 18))
        }
    }
}
