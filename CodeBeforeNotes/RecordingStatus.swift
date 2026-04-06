import Foundation

enum RecordingStatus: Equatable {
    case idle
    case authorizing
    case recording
    case stopping
    case stopped
    case error(String)

    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    var isRecordingSessionActive: Bool {
        switch self {
        case .recording, .stopping:
            return true
        case .idle, .authorizing, .stopped, .error:
            return false
        }
    }

    var isBusy: Bool {
        switch self {
        case .authorizing, .stopping:
            return true
        case .idle, .recording, .stopped, .error:
            return false
        }
    }
}
