import SwiftUI

/// Frames of the reorderable rows, in the task list's coordinate space.
struct RowFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Drives drag-to-reorder inside the popover.
///
/// AppKit drag and drop (`.draggable` / `.dropDestination`) cannot be used here:
/// beginning a system drag session makes the MenuBarExtra panel resign key, which
/// dismisses the popover and cancels the drag before it starts. Tracking the drag
/// ourselves keeps the whole interaction inside the window.
@MainActor
final class ReorderController: ObservableObject {
    /// Named coordinate space the row frames and drag locations share.
    static let space = "daybook.tasklist"

    /// How far the pointer must move before we start proposing a drop target,
    /// so a click on the handle isn't read as a reorder.
    private static let threshold: CGFloat = 4

    @Published private(set) var draggingID: UUID?
    @Published private(set) var targetID: UUID?
    @Published private(set) var offset: CGFloat = 0

    /// Reported by the rows themselves; not published because it changes during
    /// layout and must not feed back into it.
    var frames: [UUID: CGRect] = [:]

    func drag(_ id: UUID, to location: CGPoint, translation: CGFloat) {
        draggingID = id
        offset = translation

        guard abs(translation) > Self.threshold else {
            targetID = nil
            return
        }
        // Nearest other row by vertical centre — works past the ends of the list
        // too, where no row contains the pointer.
        targetID = frames
            .filter { $0.key != id }
            .min { abs($0.value.midY - location.y) < abs($1.value.midY - location.y) }?
            .key
    }

    func finish(_ commit: (_ dragged: UUID, _ target: UUID) -> Void) {
        if let draggingID, let targetID, draggingID != targetID {
            commit(draggingID, targetID)
        }
        reset()
    }

    func reset() {
        draggingID = nil
        targetID = nil
        offset = 0
    }
}
