import Foundation

struct NoteDraft: Equatable {
    var title: String
    var body: String
    var createdAt: Date
    var selectedLocaleIdentifier: String
    var audioRecordingURL: URL?
    var lastSavedURL: URL?

    init(
        title: String = "",
        body: String = "",
        createdAt: Date = Date(),
        selectedLocaleIdentifier: String,
        audioRecordingURL: URL? = nil,
        lastSavedURL: URL? = nil
    ) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.selectedLocaleIdentifier = selectedLocaleIdentifier
        self.audioRecordingURL = audioRecordingURL
        self.lastSavedURL = lastSavedURL
    }
}
