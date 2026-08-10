import Foundation

struct Entry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var tag: String
    var done: Bool = false
    /// Day the entry belongs to, as "yyyy-MM-dd" in local time.
    var day: String
}

struct WeekNotes: Codable, Equatable {
    var highlights: String = ""
    var blockers: String = ""
}

enum WeekStart: String, Codable, CaseIterable, Identifiable {
    case monday = "Monday"
    case sunday = "Sunday"
    var id: String { rawValue }
    /// Calendar.firstWeekday value (1 = Sunday, 2 = Monday).
    var firstWeekday: Int { self == .sunday ? 1 : 2 }
}

struct Settings: Codable, Equatable {
    var reminderEnabled: Bool = false
    var reminderHour: Int = 17
    var reminderMinute: Int = 0
    var weekStart: WeekStart = .monday
    var launchAtLogin: Bool = false
    var defaultTag: String = "Cadence"
    var tags: [String] = ["Cadence", "Reports", "Bugs", "Meetings"]
}

struct StoreData: Codable {
    var entries: [Entry] = []
    /// Keyed by the week-start day string ("yyyy-MM-dd").
    var weekNotes: [String: WeekNotes] = [:]
    var settings: Settings = Settings()
}

// MARK: - Derived view models

struct DayVM: Identifiable {
    let date: Date
    let key: String
    let dow: String        // "Monday"
    let dateLabel: String  // "Aug 10"
    let isWeekend: Bool
    let entries: [Entry]
    var id: String { key }
}

struct WeekVM {
    let start: Date
    let id: String        // week-start day string, e.g. "2026-08-10"
    let label: String     // "Aug 10 – 14, 2026"
    /// Days shown in the UI: Mon–Fri always, weekend days only when they have entries.
    let days: [DayVM]
    var totalEntries: Int { days.reduce(0) { $0 + $1.entries.count } }
}

// MARK: - Export shape (matches the design prototype's JSON export)

struct ExportEntry: Codable {
    let id: String
    let text: String
    let tag: String
    let done: Bool
}

struct ExportDay: Codable {
    let dow: String
    let dateLabel: String
    let entries: [ExportEntry]
}

struct ExportWeek: Codable {
    let id: String
    let label: String
    let highlights: String
    let blockers: String
    let days: [ExportDay]

    init(week: WeekVM, notes: WeekNotes) {
        id = week.id
        label = week.label
        highlights = notes.highlights
        blockers = notes.blockers
        days = week.days.map { day in
            ExportDay(dow: day.dow, dateLabel: day.dateLabel,
                      entries: day.entries.map { ExportEntry(id: $0.id.uuidString, text: $0.text, tag: $0.tag, done: $0.done) })
        }
    }
}
