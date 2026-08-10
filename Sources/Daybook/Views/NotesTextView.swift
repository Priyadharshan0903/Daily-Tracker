import AppKit
import SwiftUI

/// A multi-line text view for the weekly notes.
///
/// SwiftUI's `TextEditor` can't be aligned reliably against an overlaid placeholder:
/// the `NSTextView` behind it adds its own `lineFragmentPadding` and
/// `textContainerInset` on top of whatever SwiftUI padding you apply, so matching
/// the two means guessing at undocumented insets. Here both are zeroed, which
/// leaves SwiftUI padding as the only thing positioning the text — so a placeholder
/// sharing that padding lines up exactly.
struct NotesTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 13

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay

        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = NSColor(Theme.text)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        // The crux: with both zeroed, SwiftUI padding alone positions the glyphs.
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0

        textView.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? NSTextView else { return }
        // Never write into the view while it's being edited — a re-render carrying
        // a stale binding value would wipe out what's on screen.
        guard textView.window?.firstResponder !== textView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NotesTextView

        init(_ parent: NotesTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
