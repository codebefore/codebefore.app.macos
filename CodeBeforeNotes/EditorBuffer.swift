import Foundation

struct EditorBuffer: Equatable {
    private(set) var userText: String = ""
    private(set) var liveTranscript: String = ""

    var displayedText: String {
        guard !liveTranscript.isEmpty else { return userText }
        return userText + liveTranscriptSeparator(after: userText) + liveTranscript
    }

    mutating func setUserFacingText(_ newValue: String) {
        guard !liveTranscript.isEmpty else {
            userText = newValue
            return
        }

        let currentTranscriptBlock = liveTranscriptSeparator(after: userText) + liveTranscript

        if let strippedValue = Self.removingLastOccurrence(of: currentTranscriptBlock, from: newValue) {
            userText = strippedValue
            return
        }

        if let strippedValue = Self.removingLastOccurrence(of: liveTranscript, from: newValue) {
            userText = strippedValue
            return
        }

        userText = newValue
    }

    mutating func replaceUserText(_ text: String) {
        userText = text
    }

    mutating func applyLiveTranscript(_ text: String) {
        liveTranscript = text
    }

    mutating func commitLiveTranscript() {
        userText = displayedText
        liveTranscript = ""
    }

    mutating func reset() {
        userText = ""
        liveTranscript = ""
    }

    private func liveTranscriptSeparator(after text: String) -> String {
        guard !text.isEmpty else { return "" }
        if text.hasSuffix("\n\n") { return "" }
        if text.hasSuffix("\n") { return "\n" }
        return "\n\n"
    }

    private static func removingLastOccurrence(of needle: String, from haystack: String) -> String? {
        guard !needle.isEmpty, let range = haystack.range(of: needle, options: .backwards) else {
            return nil
        }

        var updatedText = haystack
        updatedText.removeSubrange(range)
        return updatedText
    }
}
