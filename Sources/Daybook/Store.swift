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
        let loaded = Store.load()
        data = loaded.data
        todayKey = Store.dayFormatter.string(from: Date())
        Store.applyTextScale(loaded.data.settings.textScale)
        Reminders.sync(settings: data.settings)
        observeSystemDateChanges()
        // Write the upgraded shape straight away rather than waiting for the
        // first edit, so the file on disk matches what the app is running.
        if loaded.migrated { persist() }
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

    private static func load() -> (data: StoreData, migrated: Bool) {
        guard let raw = try? Data(contentsOf: fileURL) else { return (.initial(), false) }
        let decoder = JSONDecoder()
        if let current = try? decoder.decode(StoreData.self, from: raw), !current.workspaces.isEmpty {
            return (current, false)
        }
        // Pre-workspace file: fold everything into one workspace.
        if let legacy = try? decoder.decode(LegacyStoreData.self, from: raw) {
            return (StoreData(migrating: legacy), true)
        }
        return (.initial(), true)
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
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: url, options: .atomic)
        } catch {
            NSLog("Daybook: failed to save — \(error)")
        }
    }

    /// Clamped so a bad value on disk can't make the app unusable.
    private static func applyTextScale(_ scale: Double) {
        Theme.textScale = min(max(CGFloat(scale), Theme.minTextScale), Theme.maxTextScale)
    }

    /// Steps the text size and keeps it inside the supported range.
    func nudgeTextScale(by delta: CGFloat) {
        let next = min(max(CGFloat(data.settings.textScale) + delta, Theme.minTextScale), Theme.maxTextScale)
        guard next != CGFloat(data.settings.textScale) else { return }
        data.settings.textScale = Double(next)
    }

    var canGrowText: Bool { CGFloat(data.settings.textScale) < Theme.maxTextScale }
    var canShrinkText: Bool { CGFloat(data.settings.textScale) > Theme.minTextScale }

    private func applySettingsChanges(from old: AppSettings) {
        if old.textScale != data.settings.textScale {
            // Set before the publish lands so the next render uses the new size.
            Store.applyTextScale(data.settings.textScale)
        }
        if old.launchAtLogin != data.settings.launchAtLogin {
            LaunchAtLogin.set(data.settings.launchAtLogin)
        }
        if old.reminderEnabled != data.settings.reminderEnabled
            || old.reminderHour != data.settings.reminderHour
            || old.reminderMinute != data.settings.reminderMinute {
            // Confirm only on the off → on transition, not on every time tweak.
            Reminders.sync(settings: data.settings,
                           confirming: !old.reminderEnabled && data.settings.reminderEnabled)
        }
    }

    // MARK: - Active workspace
    //
    // Everything below reads and writes the active workspace only, so the views
    // never have to know which one is in play.

    var workspaces: [Workspace] { data.workspaces }

    var activeWorkspace: Workspace {
        data.workspaces.first { $0.id == data.activeWorkspaceID } ?? data.workspaces[0]
    }

    var tags: [String] { activeWorkspace.tags }
    var defaultTag: String { activeWorkspace.defaultTag }

    private var activeIndex: Int {
        data.workspaces.firstIndex { $0.id == data.activeWorkspaceID } ?? 0
    }

    func mutateActive(_ change: (inout Workspace) -> Void) {
        let index = activeIndex
        guard data.workspaces.indices.contains(index) else { return }
        change(&data.workspaces[index])
    }

    func activate(_ id: UUID) {
        guard data.workspaces.contains(where: { $0.id == id }) else { return }
        data.activeWorkspaceID = id
    }

    @discardableResult
    func addWorkspace(named name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let workspace = Workspace(name: trimmed)
        data.workspaces.append(workspace)
        data.activeWorkspaceID = workspace.id
        return workspace.id
    }

    func setWorkspaceAvatar(_ id: UUID, to emoji: String) {
        guard let index = data.workspaces.firstIndex(where: { $0.id == id }) else { return }
        data.workspaces[index].avatar = emoji
    }

    func renameWorkspace(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = data.workspaces.firstIndex(where: { $0.id == id }) else { return }
        data.workspaces[index].name = trimmed
    }

    /// Removes a workspace and everything in it. Always keeps at least one.
    func deleteWorkspace(_ id: UUID) {
        guard data.workspaces.count > 1,
              let index = data.workspaces.firstIndex(where: { $0.id == id }) else { return }
        data.workspaces.remove(at: index)
        if data.activeWorkspaceID == id {
            data.activeWorkspaceID = data.workspaces[min(index, data.workspaces.count - 1)].id
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

    /// "Monday, August 10"
    func longLabel(forDayKey key: String) -> String {
        guard let date = date(fromDayKey: key) else { return key }
        return Store.fullDateFormatter.string(from: date)
    }

    /// "Aug 10"
    func shortLabel(forDayKey key: String) -> String {
        guard let date = date(fromDayKey: key) else { return key }
        return Store.monthDayFormatter.string(from: date)
    }

    func shiftDay(_ key: String, by days: Int) -> String {
        guard let date = date(fromDayKey: key),
              let shifted = calendar.date(byAdding: .day, value: days, to: date) else { return key }
        return dayKey(for: shifted)
    }

    func date(fromDayKey key: String) -> Date? { Store.dayFormatter.date(from: key) }

    func weekStart(containing date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    // MARK: - Entries

    var todayEntries: [Entry] { entries(on: todayKey) }

    func entries(on dayKey: String) -> [Entry] {
        activeWorkspace.entries.filter { $0.day == dayKey }
    }

    /// Unfinished entries from earlier days. They keep their original date — the
    /// weekly report stays truthful about when work started — but keep surfacing
    /// until done. Day keys are "yyyy-MM-dd", so string ordering is chronological.
    func carriedOver(before dayKey: String) -> [Entry] {
        activeWorkspace.entries
            .filter { !$0.done && $0.day < dayKey }
            .sorted { $0.day < $1.day }
    }

    var daysWithEntries: Set<String> { Set(activeWorkspace.entries.map(\.day)) }

    var daysWithUnfinished: Set<String> {
        Set(activeWorkspace.entries.filter { !$0.done }.map(\.day))
    }

    func addEntry(text: String, tag: String, day: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = Entry(text: trimmed, tag: tag, day: day ?? todayKey)
        mutateActive { $0.entries.append(entry) }
    }

    func toggle(_ id: UUID) {
        mutateActive { workspace in
            guard let index = workspace.entries.firstIndex(where: { $0.id == id }) else { return }
            workspace.entries[index].done.toggle()
        }
    }

    func remove(_ id: UUID) {
        mutateActive { $0.entries.removeAll { $0.id == id } }
    }

    func updateEntryText(_ id: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutateActive { workspace in
            guard let index = workspace.entries.firstIndex(where: { $0.id == id }) else { return }
            workspace.entries[index].text = trimmed
        }
    }

    func setEntryTag(_ id: UUID, tag: String) {
        mutateActive { workspace in
            guard let index = workspace.entries.firstIndex(where: { $0.id == id }) else { return }
            workspace.entries[index].tag = tag
        }
    }

    /// Reorders by moving the dragged entry next to the target. Order is the
    /// array's own order — `entries(on:)` filters while preserving it — so this
    /// needs no extra field on `Entry` and no migration.
    func moveEntry(_ id: UUID, onto targetID: UUID) {
        guard id != targetID else { return }
        mutateActive { workspace in
            guard let from = workspace.entries.firstIndex(where: { $0.id == id }) else { return }
            let item = workspace.entries.remove(at: from)
            guard let to = workspace.entries.firstIndex(where: { $0.id == targetID }) else {
                workspace.entries.insert(item, at: min(from, workspace.entries.count))
                return
            }
            // Dragging down lands after the target, dragging up lands before it.
            workspace.entries.insert(item, at: from <= to ? to + 1 : to)
        }
    }

    /// Moves an entry one place within its own day and completion group, so a
    /// keyboard reorder can't jump it into a different section of the list.
    func moveEntry(_ id: UUID, by offset: Int) {
        mutateActive { workspace in
            guard let index = workspace.entries.firstIndex(where: { $0.id == id }) else { return }
            let entry = workspace.entries[index]
            let siblings = workspace.entries.indices.filter {
                workspace.entries[$0].day == entry.day && workspace.entries[$0].done == entry.done
            }
            guard let position = siblings.firstIndex(of: index),
                  siblings.indices.contains(position + offset) else { return }
            workspace.entries.swapAt(index, siblings[position + offset])
        }
    }

    // MARK: - Tags

    func addTag(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutateActive { workspace in
            guard !workspace.tags.contains(trimmed) else { return }
            workspace.tags.append(trimmed)
        }
    }

    /// Renames a tag everywhere in this workspace: the tag list, every entry
    /// filed under it, and the default tag.
    func renameTag(_ old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old else { return }
        mutateActive { workspace in
            guard !workspace.tags.contains(trimmed),
                  let index = workspace.tags.firstIndex(of: old) else { return }
            workspace.tags[index] = trimmed
            for i in workspace.entries.indices where workspace.entries[i].tag == old {
                workspace.entries[i].tag = trimmed
            }
            if workspace.defaultTag == old { workspace.defaultTag = trimmed }
        }
    }

    /// Removes a tag from the list; existing entries keep their label.
    func deleteTag(_ name: String) {
        mutateActive { workspace in
            guard let index = workspace.tags.firstIndex(of: name) else { return }
            workspace.tags.remove(at: index)
            if workspace.defaultTag == name { workspace.defaultTag = "" }
        }
    }

    func setDefaultTag(_ tag: String) {
        mutateActive { $0.defaultTag = tag }
    }

    // MARK: - Week notes

    func notes(forWeek id: String) -> WeekNotes {
        activeWorkspace.weekNotes[id] ?? WeekNotes()
    }

    func setNotes(_ notes: WeekNotes, forWeek id: String) {
        mutateActive { $0.weekNotes[id] = notes }
    }

    // MARK: - Weeks

    /// Week-start dates to navigate between: every week that has entries, plus
    /// the current week.
    var weekStarts: [Date] {
        var starts: Set<Date> = [weekStart(containing: Date())]
        for entry in activeWorkspace.entries {
            if let date = date(fromDayKey: entry.day) {
                starts.insert(weekStart(containing: date))
            }
        }
        return starts.sorted()
    }

    func weekVM(startingAt start: Date) -> WeekVM {
        let cal = calendar
        let entries = activeWorkspace.entries
        let allDays: [DayVM] = (0..<7).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = dayKey(for: date)
            let weekday = cal.component(.weekday, from: date)
            return DayVM(date: date,
                         key: key,
                         dow: Store.dowFormatter.string(from: date),
                         dateLabel: Store.monthDayFormatter.string(from: date),
                         isWeekend: weekday == 1 || weekday == 7,
                         entries: entries.filter { $0.day == key })
        }
        let visible = allDays.filter { !$0.isWeekend || !$0.entries.isEmpty }
        let days = visible.isEmpty ? allDays : visible
        return WeekVM(start: start,
                      id: dayKey(for: start),
                      label: Store.weekLabel(from: days.first!.date, to: days.last!.date, calendar: cal),
                      days: days)
    }

    static func weekLabel(from: Date, to: Date, calendar: Calendar) -> String {
        let year = formatter("yyyy")
        let sameMonth = calendar.component(.month, from: from) == calendar.component(.month, from: to)
            && calendar.component(.year, from: from) == calendar.component(.year, from: to)
        let start = monthDayFormatter.string(from: from)
        let end = sameMonth ? String(calendar.component(.day, from: to)) : monthDayFormatter.string(from: to)
        return "\(start) – \(end), \(year.string(from: to))"
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
}
