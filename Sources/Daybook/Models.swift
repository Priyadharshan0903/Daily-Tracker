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

// MARK: - Workspaces

/// A self-contained tracking space: its own entries, week notes and tags.
/// Keeping tags per workspace is the point — work tags and career tags differ.
struct Workspace: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var entries: [Entry] = []
    /// Keyed by the week-start day string ("yyyy-MM-dd").
    var weekNotes: [String: WeekNotes] = [:]
    var tags: [String] = Workspace.starterTags
    /// "" means new tasks start untagged.
    var defaultTag: String = ""
    /// An emoji shown instead of the name's initial. "" falls back to the letter.
    var avatar: String = ""

    static let starterTags = ["Cadence", "Reports", "Bugs", "Meetings"]

    // Tolerant decoding so a file written by an older build still loads.
    init(id: UUID = UUID(),
         name: String,
         entries: [Entry] = [],
         weekNotes: [String: WeekNotes] = [:],
         tags: [String] = Workspace.starterTags,
         defaultTag: String = "",
         avatar: String = "") {
        self.id = id
        self.name = name
        self.entries = entries
        self.weekNotes = weekNotes
        self.tags = tags
        self.defaultTag = defaultTag
        self.avatar = avatar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Workspace"
        entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        weekNotes = try container.decodeIfPresent([String: WeekNotes].self, forKey: .weekNotes) ?? [:]
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? Workspace.starterTags
        defaultTag = try container.decodeIfPresent(String.self, forKey: .defaultTag) ?? ""
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar) ?? ""
    }
}

/// Preferences that belong to the app rather than to any one workspace.
struct AppSettings: Codable, Equatable {
    var reminderEnabled: Bool = false
    var reminderHour: Int = 17
    var reminderMinute: Int = 0
    var weekStart: WeekStart = .monday
    var launchAtLogin: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 17
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        weekStart = try container.decodeIfPresent(WeekStart.self, forKey: .weekStart) ?? .monday
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }
}

struct StoreData: Codable {
    var workspaces: [Workspace]
    var activeWorkspaceID: UUID
    var settings: AppSettings

    init(workspaces: [Workspace], activeWorkspaceID: UUID, settings: AppSettings = AppSettings()) {
        self.workspaces = workspaces
        self.activeWorkspaceID = activeWorkspaceID
        self.settings = settings
    }

    static func initial() -> StoreData {
        let workspace = Workspace(name: "Work")
        return StoreData(workspaces: [workspace], activeWorkspaceID: workspace.id)
    }
}

// MARK: - Migration

/// The pre-workspace file format. Kept solely so existing data survives the
/// upgrade; `StoreData` decoding fails on these files because `workspaces` is
/// absent, and `Store.load()` then falls back to this.
struct LegacyStoreData: Codable {
    struct LegacySettings: Codable {
        var reminderEnabled: Bool = false
        var reminderHour: Int = 17
        var reminderMinute: Int = 0
        var weekStart: WeekStart = .monday
        var launchAtLogin: Bool = false
        var defaultTag: String = ""
        var tags: [String] = Workspace.starterTags

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
            reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 17
            reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
            weekStart = try container.decodeIfPresent(WeekStart.self, forKey: .weekStart) ?? .monday
            launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
            defaultTag = try container.decodeIfPresent(String.self, forKey: .defaultTag) ?? ""
            tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? Workspace.starterTags
        }
    }

    var entries: [Entry]
    var weekNotes: [String: WeekNotes]
    var settings: LegacySettings
}

extension StoreData {
    init(migrating legacy: LegacyStoreData) {
        let workspace = Workspace(name: "Work",
                                  entries: legacy.entries,
                                  weekNotes: legacy.weekNotes,
                                  tags: legacy.settings.tags,
                                  defaultTag: legacy.settings.defaultTag)
        var settings = AppSettings()
        settings.reminderEnabled = legacy.settings.reminderEnabled
        settings.reminderHour = legacy.settings.reminderHour
        settings.reminderMinute = legacy.settings.reminderMinute
        settings.weekStart = legacy.settings.weekStart
        settings.launchAtLogin = legacy.settings.launchAtLogin
        self.init(workspaces: [workspace], activeWorkspaceID: workspace.id, settings: settings)
    }
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

// MARK: - Export shape

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
    let workspace: String
    let highlights: String
    let blockers: String
    let days: [ExportDay]

    init(week: WeekVM, notes: WeekNotes, workspace: String) {
        id = week.id
        label = week.label
        self.workspace = workspace
        highlights = notes.highlights
        blockers = notes.blockers
        days = week.days.map { day in
            ExportDay(dow: day.dow, dateLabel: day.dateLabel,
                      entries: day.entries.map {
                          ExportEntry(id: $0.id.uuidString, text: $0.text, tag: $0.tag, done: $0.done)
                      })
        }
    }
}
