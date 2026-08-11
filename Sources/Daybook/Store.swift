import AppKit
import Combine
import Foundation

@MainActor
final class Store: ObservableObject {
    @Published var data: StoreData {
        didSet {
            scheduleSave()
            if oldValue.settings != data.settings {
                applySettingsChanges(from: oldValue.settings)
            }
        }
    }

    /// Stored rather than computed from `Date()`: a computed value is always
    /// correct when read, but reading it never tells SwiftUI to re-render, so the
    /// popover kept showing yesterday's date after midnight.
    @Published private(set) var todayKey: String

    private var saveTask: Task<Void, Never>?

    init() {
        data = Store.load()
        todayKey = Store.dayFormatter.string(from: Date())
        Reminders.sync(settings: data.settings)
        observeSystemDateChanges()
    }

    // MARK: - Following the system clock

    /// Recomputes the current day. Assigns only on a real change so we don't
    /// trigger redundant renders.
    func refreshToday() {
        let key = dayKey(for: Date())
        if key != todayKey { todayKey = key }
    }

    private func observeSystemDateChanges() {
        let refresh: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.refreshToday() }
        }
        // Posted from arbitrary threads, hence the hop to the main actor above.
        for name: Notification.Name in [.NSCalendarDayChanged, .NSSystemTimeZoneDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: refresh)
        }
        // Insurance for a Mac that slept through midnight.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: refresh
        )
    }

    // MARK: - Persistence

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Daybook/daybook.json")
    }

    private static func load() -> StoreData {
        guard let raw = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(StoreData.self, from: raw) else {
            return StoreData()
        }
        return decoded
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        let url = Store.fileURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: url, options: .atomic)
        } catch {
            NSLog("Daybook: failed to save — \(error)")
        }
    }

    private func applySettingsChanges(from old: Settings) {
        if old.launchAtLogin != data.settings.launchAtLogin {
            LaunchAtLogin.set(data.settings.launchAtLogin)
        }
        if old.reminderEnabled != data.settings.reminderEnabled
            || old.reminderHour != data.settings.reminderHour
            || old.reminderMinute != data.settings.reminderMinute {
            Reminders.sync(settings: data.settings)
        }
    }

    // MARK: - Calendar / date helpers

    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        cal.firstWeekday = data.settings.weekStart.firstWeekday
        return cal
    }

    /// `autoupdatingCurrent` tracks a live timezone change (travel, DST); the
    /// implicit default is a snapshot taken when the formatter is created.
    /// The POSIX locale is deliberate and must stay — `dayFormatter` produces the
    /// "yyyy-MM-dd" keys entries are stored under, so it has to be locale-stable.
    private static func formatter(_ format: String) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .autoupdatingCurrent
        df.dateFormat = format
        return df
    }

    static let dayFormatter = formatter("yyyy-MM-dd")
    static let dowFormatter = formatter("EEEE")
    static let monthDayFormatter = formatter("MMM d")
    static let fullDateFormatter = formatter("EEEE, MMMM d")

    func dayKey(for date: Date) -> String { Store.dayFormatter.string(from: date) }

    /// "Monday, August 10" — used for the calligraphic date header.
    func longLabel(forDayKey key: String) -> String {
        guard let d = date(fromDayKey: key) else { return key }
        return Store.fullDateFormatter.string(from: d)
    }

    /// "Aug 10"
    func shortLabel(forDayKey key: String) -> String {
        guard let d = date(fromDayKey: key) else { return key }
        return Store.monthDayFormatter.string(from: d)
    }

    func shiftDay(_ key: String, by days: Int) -> String {
        guard let d = date(fromDayKey: key),
              let shifted = calendar.date(byAdding: .day, value: days, to: d) else { return key }
        return dayKey(for: shifted)
    }

    func date(fromDayKey key: String) -> Date? { Store.dayFormatter.date(from: key) }

    func weekStart(containing date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    // MARK: - Today

    var todayEntries: [Entry] {
        entries(on: todayKey)
    }

    func entries(on dayKey: String) -> [Entry] {
        data.entries.filter { $0.day == dayKey }
    }

    /// Unfinished entries from earlier days. They keep their original date — the weekly
    /// report stays truthful about when work started — but keep surfacing until done.
    /// Day keys are "yyyy-MM-dd", so string ordering is chronological.
    func carriedOver(before dayKey: String) -> [Entry] {
        data.entries
            .filter { !$0.done && $0.day < dayKey }
            .sorted { $0.day < $1.day }
    }

    var daysWithEntries: Set<String> {
        Set(data.entries.map(\.day))
    }

    var daysWithUnfinished: Set<String> {
        Set(data.entries.filter { !$0.done }.map(\.day))
    }

    // MARK: - Entry operations

    func addEntry(text: String, tag: String, day: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        data.entries.append(Entry(text: trimmed, tag: tag, day: day ?? todayKey))
    }

    func toggle(_ id: UUID) {
        guard let i = data.entries.firstIndex(where: { $0.id == id }) else { return }
        data.entries[i].done.toggle()
    }

    func remove(_ id: UUID) {
        data.entries.removeAll { $0.id == id }
    }

    func updateEntryText(_ id: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = data.entries.firstIndex(where: { $0.id == id }) else { return }
        data.entries[i].text = trimmed
    }

    /// Reorders by moving the dragged entry next to the target. Order is the
    /// array's own order — `entries(on:)` filters while preserving it — so this
    /// needs no extra field on `Entry` and no migration.
    func moveEntry(_ id: UUID, onto targetID: UUID) {
        guard id != targetID,
              let from = data.entries.firstIndex(where: { $0.id == id }) else { return }
        let item = data.entries.remove(at: from)
        guard let to = data.entries.firstIndex(where: { $0.id == targetID }) else {
            data.entries.insert(item, at: min(from, data.entries.count))
            return
        }
        // Dragging down lands after the target, dragging up lands before it.
        data.entries.insert(item, at: from <= to ? to + 1 : to)
    }

    /// Moves an entry one place within its own day and completion group, so a
    /// keyboard reorder can't jump it into a different section of the list.
    func moveEntry(_ id: UUID, by offset: Int) {
        guard let index = data.entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = data.entries[index]
        let siblings = data.entries.indices.filter {
            data.entries[$0].day == entry.day && data.entries[$0].done == entry.done
        }
        guard let position = siblings.firstIndex(of: index),
              siblings.indices.contains(position + offset) else { return }
        data.entries.swapAt(index, siblings[position + offset])
    }

    func setEntryTag(_ id: UUID, tag: String) {
        guard let i = data.entries.firstIndex(where: { $0.id == id }) else { return }
        data.entries[i].tag = tag
    }

    // MARK: - Tag management

    func addTag(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !data.settings.tags.contains(trimmed) else { return }
        data.settings.tags.append(trimmed)
    }

    /// Renames a tag everywhere: the tag list, every entry filed under it, and the default tag.
    func renameTag(_ old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old,
              !data.settings.tags.contains(trimmed),
              let idx = data.settings.tags.firstIndex(of: old) else { return }
        data.settings.tags[idx] = trimmed
        for i in data.entries.indices where data.entries[i].tag == old {
            data.entries[i].tag = trimmed
        }
        if data.settings.defaultTag == old {
            data.settings.defaultTag = trimmed
        }
    }

    /// Removes a tag from the list (existing entries keep their label). Always keeps at least one tag.
    func deleteTag(_ name: String) {
        guard data.settings.tags.count > 1,
              let idx = data.settings.tags.firstIndex(of: name) else { return }
        data.settings.tags.remove(at: idx)
        if data.settings.defaultTag == name {
            data.settings.defaultTag = data.settings.tags[0]
        }
    }

    // MARK: - Full backup / restore

    func exportAllData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(data)
    }

    func replaceAllData(_ new: StoreData) {
        data = new
    }

    // MARK: - Weeks

    /// Week-start dates to navigate between: every week that has entries, plus the current week.
    var weekStarts: [Date] {
        var starts: Set<Date> = [weekStart(containing: Date())]
        for entry in data.entries {
            if let d = date(fromDayKey: entry.day) {
                starts.insert(weekStart(containing: d))
            }
        }
        return starts.sorted()
    }

    func weekVM(startingAt start: Date) -> WeekVM {
        let cal = calendar
        let allDays: [DayVM] = (0..<7).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = dayKey(for: date)
            let weekday = cal.component(.weekday, from: date)
            return DayVM(date: date,
                         key: key,
                         dow: Store.dowFormatter.string(from: date),
                         dateLabel: Store.monthDayFormatter.string(from: date),
                         isWeekend: weekday == 1 || weekday == 7,
                         entries: data.entries.filter { $0.day == key })
        }
        let visible = allDays.filter { !$0.isWeekend || !$0.entries.isEmpty }
        let days = visible.isEmpty ? allDays : visible
        return WeekVM(start: start,
                      id: dayKey(for: start),
                      label: Store.weekLabel(from: days.first!.date, to: days.last!.date, calendar: cal),
                      days: days)
    }

    static func weekLabel(from: Date, to: Date, calendar: Calendar) -> String {
        let year = DateFormatter()
        year.locale = Locale(identifier: "en_US_POSIX")
        year.dateFormat = "yyyy"
        let sameMonth = calendar.component(.month, from: from) == calendar.component(.month, from: to)
            && calendar.component(.year, from: from) == calendar.component(.year, from: to)
        let start = monthDayFormatter.string(from: from)
        let end = sameMonth ? String(calendar.component(.day, from: to)) : monthDayFormatter.string(from: to)
        return "\(start) – \(end), \(year.string(from: to))"
    }

    // MARK: - Week notes

    func notes(forWeek id: String) -> WeekNotes {
        data.weekNotes[id] ?? WeekNotes()
    }

    func setNotes(_ notes: WeekNotes, forWeek id: String) {
        data.weekNotes[id] = notes
    }
}
