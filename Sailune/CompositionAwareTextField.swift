import AppKit
import SwiftUI

struct CompositionAwareTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: NSFont
    let onEditingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> CompositionAwareTextView {
        let textStorage = NSTextStorage()
        let layoutManager = CompositionUnderlineLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 1, height: 32))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = CompositionAwareTextView(frame: .zero, textContainer: textContainer)
        layoutManager.editorTextView = textView
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.textColor = .textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.maximumNumberOfLines = 1
        textView.textContainer?.lineBreakMode = .byClipping
        textView.typingAttributes = [.font: font, .foregroundColor: NSColor.textColor]
        return textView
    }

    func updateNSView(_ textView: CompositionAwareTextView, context: Context) {
        context.coordinator.parent = self
        textView.font = font
        if textView.string != text, textView.window?.firstResponder !== textView {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CompositionAwareTextField
        init(parent: CompositionAwareTextField) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onEditingChanged(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onEditingChanged(false)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

