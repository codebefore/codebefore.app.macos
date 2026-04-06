@preconcurrency import AVFoundation
import Foundation

enum AudioRecordingStoreError: LocalizedError {
    case exportSessionUnavailable
    case exportFailed(String)
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .exportSessionUnavailable:
            return "Ses kaydi m4a formatina donusturulemedi."
        case .exportFailed(let details):
            return "Ses kaydi m4a formatina donusturulemedi: \(details)"
        case .exportCancelled:
            return "Ses kaydi donusumu iptal edildi."
        }
    }
}

enum AudioRecordingStore {
    static func makeRecordingURL(
        createdAt: Date,
        fileManager: FileManager = .default
    ) throws -> URL {
        let recordingsDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("codbefore-note", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)

        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        let filename = "recording-\(formatter.string(from: createdAt)).caf"
        return recordingsDirectory.appendingPathComponent(filename, isDirectory: false)
    }

    static func finalizeRecording(
        at sourceURL: URL,
        matchingMarkdownURL markdownURL: URL,
        fileManager: FileManager = .default
    ) async throws -> URL {
        let fileExtension = "m4a"
        let preferredTargetURL = markdownURL
            .deletingPathExtension()
            .appendingPathExtension(fileExtension)

        let targetURL = uniqueRecordingDestination(
            preferredURL: preferredTargetURL,
            sourceURL: sourceURL,
            fileManager: fileManager
        )

        if sourceURL.standardizedFileURL == targetURL.standardizedFileURL {
            return targetURL
        }

        try await transcodeRecording(at: sourceURL, to: targetURL)
        try? fileManager.removeItem(at: sourceURL)
        return targetURL
    }

    static func removeTemporaryRecordingIfNeeded(
        at url: URL?,
        fileManager: FileManager = .default
    ) {
        guard let url else { return }
        guard isTemporaryRecordingURL(url, fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: url)
    }

    static func isTemporaryRecordingURL(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("codbefore-note", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
            .standardizedFileURL

        return url.standardizedFileURL.path.hasPrefix(temporaryRoot.path)
    }

    private static func uniqueRecordingDestination(
        preferredURL: URL,
        sourceURL: URL,
        fileManager: FileManager
    ) -> URL {
        if sourceURL.standardizedFileURL == preferredURL.standardizedFileURL {
            return preferredURL
        }

        guard fileManager.fileExists(atPath: preferredURL.path) else {
            return preferredURL
        }

        let directoryURL = preferredURL.deletingLastPathComponent()
        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        let pathExtension = preferredURL.pathExtension
        var suffix = 2

        while true {
            let candidateURL = directoryURL
                .appendingPathComponent("\(baseName)-\(suffix)", isDirectory: false)
                .appendingPathExtension(pathExtension)

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            suffix += 1
        }
    }

    private static func transcodeRecording(at sourceURL: URL, to targetURL: URL) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioRecordingStoreError.exportSessionUnavailable
        }

        exportSession.outputURL = targetURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    let message = exportSession.error?.localizedDescription ?? "Bilinmeyen hata"
                    continuation.resume(throwing: AudioRecordingStoreError.exportFailed(message))
                case .cancelled:
                    continuation.resume(throwing: AudioRecordingStoreError.exportCancelled)
                default:
                    let message = exportSession.error?.localizedDescription ?? "Beklenmeyen export durumu"
                    continuation.resume(throwing: AudioRecordingStoreError.exportFailed(message))
                }
            }
        }
    }
}
