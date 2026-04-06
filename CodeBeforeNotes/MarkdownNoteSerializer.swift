import Foundation

enum MarkdownNoteSerializer {
    static func markdown(for draft: NoteDraft) -> String {
        let title = normalizedTitle(from: draft.title)
        let created = timestampString(from: draft.createdAt)

        return """
        # \(title)

        - Created: \(created)
        - Language: \(draft.selectedLocaleIdentifier)

        ---

        \(draft.body)
        """
    }

    static func suggestedFilename(for title: String, createdAt: Date) -> String {
        let slug = slugifiedTitle(from: title)
        if !slug.isEmpty {
            return "\(slug).md"
        }

        return "note-\(filenameTimestamp(from: createdAt)).md"
    }

    private static func normalizedTitle(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Note" : trimmed
    }

    private static func slugifiedTitle(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let folded = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        var slug = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }

        while slug.contains(where: { $0 == "-" }) && String(slug).contains("--") {
            let collapsed = String(slug).replacingOccurrences(of: "--", with: "-")
            slug = Array(collapsed)
        }

        let cleaned = String(slug).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return cleaned
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func filenameTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}
