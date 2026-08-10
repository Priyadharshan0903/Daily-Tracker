import AppKit
import Foundation

/// Renders a week as a self-contained HTML page matching the "Weekly Report" design,
/// then opens it in the default browser (Print / PDF comes free from there).
enum ReportGenerator {
    static func openReport(week: WeekVM, notes: WeekNotes) {
        let html = generate(week: week, notes: notes)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Daybook-Report-\(week.id).html")
        do {
            try html.data(using: .utf8)?.write(to: url, options: .atomic)
            NSWorkspace.shared.open(url)
        } catch {
            NSLog("Daybook: failed to write report — \(error)")
        }
    }

    static func generate(week: WeekVM, notes: WeekNotes, generatedOn: Date = Date()) -> String {
        let generated = generatedOn.formatted(date: .long, time: .omitted)
        let daysHTML = week.days.map { day -> String in
            let rows = day.entries.map { entry in
                let tag = entry.tag.isEmpty ? "" : "<span class=\"tag\">\(escape(entry.tag))</span>"
                return """
                <div class="row">
                  <span class="mark">\(entry.done ? "✓" : "○")</span>
                  <span class="row-text">\(escape(entry.text))</span>
                  \(tag)
                </div>
                """
            }.joined(separator: "\n")
            return """
            <div>
              <h3>\(escape(day.dow)), \(escape(day.dateLabel))</h3>
              <div class="rows">\(rows.isEmpty ? "<div class=\"empty\">—</div>" : rows)</div>
            </div>
            """
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Weekly Work Report — \(escape(week.label))</title>
        <style>
          :root {
            --bg: #f4f7fd; --text: #1d1d1f; --accent: #3767b0; --accent-700: #24437c;
            --orange-700: #a56203; --divider: rgba(29, 29, 31, 0.1);
            --n200: #eef2f8; --n500: #9ca6b5; --n600: #7d8798; --n700: #5f6878;
          }
          * { box-sizing: border-box; }
          body { margin: 0; background: var(--bg); color: var(--text);
                 font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Helvetica Neue", sans-serif; }
          .page { max-width: 760px; margin: 0 auto; padding: 48px 24px 80px; }
          .toolbar { display: flex; justify-content: flex-end; margin-bottom: 40px; }
          .btn { border: none; border-radius: 8px; padding: 8px 16px; font-size: 13.5px; font-weight: 600;
                 cursor: pointer; background: var(--accent); color: #fff; }
          .kicker { font-size: 12px; letter-spacing: 0.14em; text-transform: uppercase; color: var(--n700); }
          h1 { font-size: 44px; line-height: 1.05; margin: 8px 0 20px; }
          .meta { border-top: 2px solid var(--accent); border-bottom: 1px solid var(--divider);
                  padding: 7px 2px; display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 32px; }
          .days { display: grid; gap: 20px; }
          h3 { font-size: 18px; margin: 0 0 7px; }
          .rows { display: grid; gap: 6px; }
          .row { display: flex; gap: 10px; align-items: baseline; font-size: 15px; }
          .mark { color: var(--accent-700); flex: none; width: 14px; }
          .row-text { flex: 1; text-wrap: pretty; }
          .tag { background: var(--n200); color: var(--n700); font-size: 11px; border-radius: 999px; padding: 2px 9px; }
          .empty { font-style: italic; color: var(--n500); font-size: 13px; }
          .notes { display: grid; grid-template-columns: 1fr 1fr; gap: 28px; margin-top: 40px; }
          .note-label { font-size: 12px; letter-spacing: 0.12em; text-transform: uppercase;
                        color: var(--accent-700); margin-bottom: 6px; }
          .note-label.blockers { color: var(--orange-700); }
          .notes p { margin: 0; font-size: 15px; line-height: 1.5; text-wrap: pretty; }
          .footer { margin-top: 40px; border-top: 1px solid var(--divider); padding-top: 10px;
                    font-size: 12.5px; color: var(--n600); display: flex; justify-content: space-between; }
          @media print { .no-print { display: none !important; } body { background: #fff; } }
        </style>
        </head>
        <body>
        <div class="page">
          <div class="toolbar no-print"><button class="btn" onclick="window.print()">Print / PDF</button></div>
          <div class="kicker">Klenty · Engineering</div>
          <h1>Weekly Work Report</h1>
          <div class="meta">
            <span>Week of \(escape(week.label))</span>
            <span>Prepared in Daybook</span>
            <span>Generated \(escape(generated))</span>
          </div>
          <div class="days">
          \(daysHTML)
          </div>
          <div class="notes">
            <div>
              <div class="note-label">Highlights</div>
              <p>\(escape(notes.highlights))</p>
            </div>
            <div>
              <div class="note-label blockers">Blockers</div>
              <p>\(escape(notes.blockers))</p>
            </div>
          </div>
          <div class="footer">
            <span>\(week.totalEntries) entries · \(week.days.count) working days</span>
            <span>Daybook · exported as HTML</span>
          </div>
        </div>
        </body>
        </html>
        """
    }

    static func escape(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
