import AppKit
import SwiftUI

/// An NSTextField wrapper used for inline entry editing.
///
/// SwiftUI's TextField + @FocusState can't do this cleanly: AppKit selects a
/// field's whole contents when it becomes first responder, and undoing that from
/// SwiftUI means waiting a frame, which flashes the selection on screen. Here the
/// focus and the caret placement happen in one runloop pass, so the selected
/// state is never drawn. Submit / cancel / blur are reported by the delegate.
struct InlineTextField: NSViewRepresentable {
    @Binding var text: String
    /// The authoritative starting value. The field seeds itself from this rather
    /// than from the binding, so no ordering of SwiftUI state writes can leave it blank.
    let initialText: String
    var fontSize: CGFloat = 14.5
    var onSubmit: () -> Void = {}
    var onCancel: () -> Void = {}
    var onBlur: () -> Void = {}

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: fontSize)
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.cell?.sendsActionOnEndEditing = false
        // The whole design is a hardcoded light theme; without pinning the
        // appearance, AppKit draws white-on-white text under a dark system.
        field.appearance = NSAppearance(named: .aqua)
        field.textColor = NSColor(Theme.text)
        field.stringValue = initialText
        context.coordinator.takeFocus(field)
        context.coordinator.startWatching(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        // Deliberately does NOT push `text` into the field. The field owns its
        // contents for its whole (edit-only) lifetime and reports changes
        // outward; writing back in races with focus and blanks the field.
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ nsView: NSTextField, coordinator: Coordinator) {
        coordinator.stopWatching()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InlineTextField
        private var cancelled = false
        private weak var field: NSTextField?
        private var keyMonitor: Any?
        private var mouseMonitor: Any?
        private var resignObserver: NSObjectProtocol?

        init(_ parent: InlineTextField) { self.parent = parent }

        deinit { stopWatching() }

        /// The field has no window until it is installed in the hierarchy, so
        /// retry across runloop turns until it does.
        func takeFocus(_ field: NSTextField, attempt: Int = 0) {
            DispatchQueue.main.async { [weak field] in
                guard let field else { return }
                guard let window = field.window else {
                    if attempt < 10 { self.takeFocus(field, attempt: attempt + 1) }
                    return
                }
                window.makeFirstResponder(field)
                // Same pass as makeFirstResponder — the select-all never paints.
                if let editor = field.currentEditor() {
                    let end = (field.stringValue as NSString).length
                    editor.selectedRange = NSRange(location: end, length: 0)
                }
            }
        }

        func startWatching(_ field: NSTextField) {
            self.field = field
            watchForCommandReturn()
            watchForClickAway()
            watchForWindowResign()
        }

        /// ⌘↩ is not in AppKit's standard key bindings, so it never arrives as an
        /// `insertNewline:` command. A local monitor sees the key press before the
        /// responder chain and before SwiftUI's own ⌘↩ shortcut on the Add button,
        /// so the edit is saved instead of a stray add being triggered.
        private func watchForCommandReturn() {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      let field = self.field,
                      field.currentEditor() != nil else { return event }

                let isReturn = event.keyCode == 36 || event.keyCode == 76  // Return, keypad Enter
                let isCommand = event.modifierFlags
                    .intersection(.deviceIndependentFlagsMask)
                    .contains(.command)
                guard isReturn, isCommand else { return event }

                self.parent.onSubmit()
                return nil  // consume, so nothing else reacts to it
            }
        }

        /// `controlTextDidEndEditing` only fires when focus actually moves to another
        /// control — clicking blank space in the popover doesn't resign first
        /// responder, so an edit sat there unsaved. This watches mouse-downs and
        /// commits when one lands outside the field. It deliberately returns the
        /// event untouched: consuming it is what previously made the task field
        /// unclickable.
        private func watchForClickAway() {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self,
                      let field = self.field,
                      field.currentEditor() != nil else { return event }

                if event.window === field.window {
                    let point = field.convert(event.locationInWindow, from: nil)
                    // Generous inset so the field's own padded box counts as inside.
                    if field.bounds.insetBy(dx: -8, dy: -6).contains(point) { return event }
                }

                // Commit after the click is delivered, so the field isn't torn
                // down in the middle of event handling.
                DispatchQueue.main.async { [weak self] in self?.parent.onBlur() }
                return event
            }
        }

        /// Dismissing the popover mid-edit would otherwise lose the change — that
        /// click happens outside the app, so the mouse monitor never sees it.
        private func watchForWindowResign() {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.parent.onBlur() }
            }
        }

        func stopWatching() {
            for monitor in [keyMonitor, mouseMonitor].compactMap({ $0 }) {
                NSEvent.removeMonitor(monitor)
            }
            if let resignObserver {
                NotificationCenter.default.removeObserver(resignObserver)
            }
            keyMonitor = nil
            mouseMonitor = nil
            resignObserver = nil
            field = nil
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            // Esc already reported a cancel; don't also save on the way out.
            guard !cancelled else {
                cancelled = false
                return
            }
            parent.onBlur()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                cancelled = true
                parent.onCancel()
                return true
            default:
                return false
            }
        }
    }
}
