import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var draft = ""
    @State private var draftTag: String?

    private var currentTag: String {
        if let tag = draftTag, store.data.settings.tags.contains(tag) { return tag }
        return store.data.settings.defaultTag
    }

    var body: some View {
        let entries = store.todayEntries
        let done = entries.filter(\.done).count

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.todayLabel.uppercased())
                    .font(.system(size: 12))
                    .kerning(0.9)
                    .foregroundColor(Theme.neutral700)
                Spacer()
                Text("\(done) of \(entries.count) done")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.neutral600)
            }

            inputRow

            HStack(spacing: 6) {
                Text("File under")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.neutral600)
                ForEach(store.data.settings.tags, id: \.self) { tag in
                    TagChip(label: tag, selected: tag == currentTag) { draftTag = tag }
                }
            }

            if entries.isEmpty {
                Text("Nothing logged yet. The first line is the hardest.")
                    .font(.system(size: 13.5))
                    .italic()
                    .foregroundColor(Theme.neutral500)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(entries) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 330)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Add a task for today…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit(add)
            Button(action: add) {
                Text("Add")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundColor(.white)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
        .padding(.leading, 14)
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.neutral200))
    }

    private func add() {
        store.addEntry(text: draft, tag: currentTag)
        draft = ""
    }
}
