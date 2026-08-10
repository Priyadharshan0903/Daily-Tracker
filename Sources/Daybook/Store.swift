import Foundation
import Combine

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

    private var saveTask: Task<Void, Never>?

    init() {
        data = Store.load()
        Reminders.sync(settings: data.settings)
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
        cal.firstWeekday = data.settings.weekStart.firstWeekday
        return cal
    }

    static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    static let dowFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEEE"
        return df
    }()

    static let monthDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMM d"
        return df
    }()

    func dayKey(for date: Date) -> String { Store.dayFormatter.string(from: date) }

    func date(fromDayKey key: String) -> Date? { Store.dayFormatter.date(from: key) }

    func weekStart(containing date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    // MARK: - Today

    var todayKey: String { dayKey(for: Date()) }

    var todayLabel: String {
        let now = Date()
        return "\(Store.dowFormatter.string(from: now)), \(Store.monthDayFormatter.string(from: now))"
    }

    var todayEntries: [Entry] {
        let key = todayKey
        return data.entries.filter { $0.day == key }
    }

    // MARK: - Entry operations

    func addEntry(text: String, tag: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        data.entries.append(Entry(text: trimmed, tag: tag, day: todayKey))
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
