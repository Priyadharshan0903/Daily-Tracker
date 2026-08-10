import SwiftUI

/// Compact month grid built from the Daybook design tokens — the system
/// DatePicker's chrome looks foreign inside the popover.
struct CalendarPanel: View {
    let selectedDay: String
    let todayKey: String
    let daysWithEntries: Set<String>
    let daysWithUnfinished: Set<String>
    let calendar: Calendar
    let onSelect: (String) -> Void

    @State private var monthAnchor: Date

    private let cellHeight: CGFloat = 28
    private let markSize: CGFloat = 24

    init(selectedDay: String,
         todayKey: String,
         daysWithEntries: Set<String>,
         daysWithUnfinished: Set<String>,
         calendar: Calendar,
         onSelect: @escaping (String) -> Void) {
        self.selectedDay = selectedDay
        self.todayKey = todayKey
        self.daysWithEntries = daysWithEntries
        self.daysWithUnfinished = daysWithUnfinished
        self.calendar = calendar
        self.onSelect = onSelect
        let anchor = Store.dayFormatter.date(from: selectedDay) ?? Date()
        _monthAnchor = State(initialValue: calendar.dateInterval(of: .month, for: anchor)?.start ?? anchor)
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            weekdayRow
            grid
            legend
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.neutral300))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 4) {
            Text(monthTitle)
                .font(.system(size: 13, weight: .semibold))

            Spacer(minLength: 0)

            Button {
                onSelect(todayKey)
            } label: {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent100))
                    .foregroundColor(Theme.accent700)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .help("Jump to today")

            monthButton("chevron.left", disabled: false) { shiftMonth(-1) }
            monthButton("chevron.right", disabled: false) { shiftMonth(1) }
        }
    }

    private func monthButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(disabled ? Theme.neutral300 : Theme.neutral700)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .pointingCursor(!disabled)
    }

    // MARK: - Grid

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.neutral500)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 2) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: cellHeight)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = Store.dayFormatter.string(from: date)
        let isSelected = key == selectedDay
        let isToday = key == todayKey
        let hasUnfinished = daysWithUnfinished.contains(key)
        let hasEntries = daysWithEntries.contains(key)

        return Button {
            onSelect(key)
        } label: {
            VStack(spacing: 1) {
                ZStack {
                    if isSelected {
                        Circle().fill(Theme.accent)
                    } else if isToday {
                        Circle().strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1)
                    }
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 12, weight: isSelected || isToday ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : Theme.text)
                }
                .frame(width: markSize, height: markSize)

                Circle()
                    .fill(dotColor(isSelected: isSelected, hasUnfinished: hasUnfinished, hasEntries: hasEntries))
                    .frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }

    private func dotColor(isSelected: Bool, hasUnfinished: Bool, hasEntries: Bool) -> Color {
        guard hasEntries else { return .clear }
        if isSelected { return .white }
        return hasUnfinished ? Theme.orange500 : Theme.accent
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(color: Theme.orange500, label: "Unfinished")
            legendItem(color: Theme.accent, label: "All done")
            Spacer()
        }
        .padding(.top, 2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 3, height: 3)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundColor(Theme.neutral500)
        }
    }

    // MARK: - Derived

    private var monthTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: monthAnchor)
    }

    /// Two-letter weekday initials, rotated to match the week-start setting.
    /// Single letters would show two "T"s and two "S"s.
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols.map { String($0.prefix(2)) }
        let start = calendar.firstWeekday - 1
        guard start < symbols.count else { return symbols }
        return Array(symbols[start...] + symbols[..<start])
    }

    private var weeks: [[Date?]] {
        guard let monthStart = calendar.dateInterval(of: .month, for: monthAnchor)?.start,
              let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count else { return [] }
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: monthStart))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        withAnimation(.easeOut(duration: 0.15)) { monthAnchor = next }
    }
}
