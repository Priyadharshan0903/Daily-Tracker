import AppKit
import SwiftUI

/// Every link in the roadmap, filterable by phase or track, plus whatever you
/// add yourself. Ticking a row is "I've read this", not "I've done the week".
struct RoadmapLibraryView: View {
    @EnvironmentObject var store: Store
    @State private var filter: String = Filter.thisPhase
    @State private var query = ""
    @State private var newTitle = ""
    @State private var newURL = ""

    private enum Filter {
        static let thisPhase = "This phase"
        static let all = "All"
    }

    private var phase: RoadmapPlan.Phase { store.roadmapPhase }

    /// Baked-in catalogue plus the user's own, which carry no phase or topic.
    private var everything: [RoadmapResource] {
        RoadmapLibrary.all + store.roadmap.customResources.map {
            RoadmapResource(id: $0.id.uuidString,
                            title: $0.title,
                            url: $0.url,
                            kind: .article,
                            track: $0.track,
                            topic: "Yours",
                            phase: phase.n)
        }
    }

    private var shown: [RoadmapResource] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return everything.filter { resource in
            let matchesFilter: Bool
            switch filter {
            case Filter.all: matchesFilter = true
            case Filter.thisPhase: matchesFilter = resource.phase == phase.n
            default: matchesFilter = resource.track == filter
            }
            guard matchesFilter else { return false }
            guard !needle.isEmpty else { return true }
            return "\(resource.title) \(resource.topic) \(resource.track)".lowercased().contains(needle)
        }
    }

    /// Where a new link is filed when the filter isn't a track.
    private var addTrack: String {
        filter == Filter.all || filter == Filter.thisPhase ? RoadmapPlan.tracks[0] : filter
    }

    var body: some View {
        let rows = shown

        return VStack(alignment: .leading, spacing: 12) {
            searchRow(count: rows.count)
            chips
            list(rows)
            addSection
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 16, trailing: 18))
    }

    private func searchRow(count: Int) -> some View {
        InputPill(placeholder: "Search the library…", text: $query, onSubmit: {}) {
            Text("\(count) of \(everything.count)")
                .font(Theme.font(11.5))
                .foregroundColor(Theme.neutral600)
                .fixedSize()
                .padding(.trailing, 10)
        }
    }

    private var chips: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach([Filter.thisPhase, Filter.all] + RoadmapPlan.tracks, id: \.self) { name in
                TagChip(label: name == Filter.thisPhase ? "Phase \(phase.n)" : name,
                        selected: name == filter) { filter = name }
            }
        }
    }

    @ViewBuilder
    private func list(_ rows: [RoadmapResource]) -> some View {
        if rows.isEmpty {
            Text("Nothing here. Try another track, or add your own below.")
                .font(Theme.font(13.5))
                .foregroundColor(Theme.neutral500)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 3) {
                ForEach(rows) { resource in
                    row(resource)
                }
            }
        }
    }

    private func row(_ resource: RoadmapResource) -> some View {
        let read = store.isResourceRead(resource.id)
        return HStack(alignment: .top, spacing: 10) {
            SquareCheck(done: read) { store.toggleResourceRead(resource.id) }
            VStack(alignment: .leading, spacing: 2) {
                Button { open(resource.url) } label: {
                    Text(resource.title)
                        .font(Theme.font(14))
                        .strikethrough(read)
                        .foregroundColor(read ? Theme.neutral500 : Theme.accent700)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .help(resource.url)

                Text("\(resource.track) · \(resource.topic)")
                    .font(Theme.font(11.5))
                    .foregroundColor(Theme.neutral600)
            }
            KindBadge(kind: resource.kind)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
    }

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Theme.divider).frame(height: 1)
            Kicker(text: "Add your own")
                .padding(.top, 4)
            InputPill(placeholder: "Title", text: $newTitle, onSubmit: addResource) { EmptyView() }
            InputPill(placeholder: "https://…", text: $newURL, onSubmit: addResource) {
                PillButton(title: "Add", action: addResource)
            }
            Text("Filed under \(addTrack). Pick a track chip above to change that.")
                .font(Theme.font(11.5))
                .foregroundColor(Theme.neutral600)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func addResource() {
        guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !newURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.addCustomResource(title: newTitle, url: newURL, track: addTrack)
        newTitle = ""
        newURL = ""
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}
