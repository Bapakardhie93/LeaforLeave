import AppKit
import SwiftUI

struct OmniboxTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let selectionRequest: Int
    let suggestion: (String) -> String?
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.textColor = .labelColor
        field.placeholderString = "Search Google or enter an address"
        field.usesSingleLineMode = true
        field.cell?.lineBreakMode = .byTruncatingTail
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self

        let editor = field.currentEditor() as? NSTextView
        let displayedText = editor?.string ?? field.stringValue
        if displayedText != text {
            field.stringValue = text
            editor?.string = text
        }

        if isFocused, field.currentEditor() == nil {
            DispatchQueue.main.async {
                guard isFocused else { return }
                field.window?.makeFirstResponder(field)
            }
        }

        if context.coordinator.lastSelectionRequest != selectionRequest {
            context.coordinator.lastSelectionRequest = selectionRequest
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                field.currentEditor()?.selectAll(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: OmniboxTextField
        var lastSelectionRequest: Int
        private var suppressNextSuggestion = false

        init(parent: OmniboxTextField) {
            self.parent = parent
            lastSelectionRequest = parent.selectionRequest
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
            guard let field = notification.object as? NSTextField else { return }
            DispatchQueue.main.async {
                field.currentEditor()?.selectAll(nil)
            }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let typedText = field.stringValue
            parent.text = typedText

            if suppressNextSuggestion {
                suppressNextSuggestion = false
                return
            }

            guard let editor = field.currentEditor() as? NSTextView else { return }
            let selection = editor.selectedRange()
            let typedLength = (typedText as NSString).length
            guard selection.length == 0, selection.location == typedLength,
                  let completion = parent.suggestion(typedText),
                  completion.localizedCaseInsensitiveCompare(typedText) != .orderedSame,
                  completion.lowercased().hasPrefix(typedText.lowercased()) else { return }

            field.stringValue = completion
            editor.string = completion
            editor.setSelectedRange(NSRange(location: typedLength, length: (completion as NSString).length - typedLength))
            parent.text = completion
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }

            if commandSelector == #selector(NSResponder.deleteBackward(_:)), textView.selectedRange().length > 0 {
                suppressNextSuggestion = true
                return false
            }

            if commandSelector == #selector(NSResponder.cancelOperation(_:)), textView.selectedRange().length > 0 {
                let prefixLength = textView.selectedRange().location
                let value = (textView.string as NSString).substring(to: prefixLength)
                textView.string = value
                (control as? NSTextField)?.stringValue = value
                textView.setSelectedRange(NSRange(location: prefixLength, length: 0))
                parent.text = value
                return true
            }

            return false
        }
    }
}
