import AVFoundation
import Foundation
import Speech

enum PermissionState: Equatable {
    case authorized
    case microphoneDenied
    case speechDenied
    case restricted
    case unavailable(String)

    var message: String {
        switch self {
        case .authorized:
            return AppStrings.ready
        case .microphoneDenied:
            return AppStrings.microphoneDenied
        case .speechDenied:
            return AppStrings.speechDenied
        case .restricted:
            return AppStrings.permissionsRestricted
        case .unavailable(let reason):
            return reason
        }
    }
}

enum TranscriptUpdate: Equatable {
    case partial(String)
    case final(String)
}

protocol SpeechRecognitionServing: AnyObject {
    var currentAudioRecordingURL: URL? { get }
    func requestPermissions() async -> PermissionState
    func startTranscription(
        localeIdentifier: String,
        onUpdate: @escaping @Sendable (TranscriptUpdate) -> Void
    ) throws
    func stopTranscription() async -> String?
}

enum SpeechRecognitionError: LocalizedError {
    case unsupportedLocale(String)
    case recognizerUnavailable(String)
    case microphoneInputUnavailable
    case audioRecordingSetupFailure(String)
    case audioEngineFailure(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale(let localeIdentifier):
            return AppStrings.unsupportedLocale(localeIdentifier)
        case .recognizerUnavailable(let localeIdentifier):
            return AppStrings.recognizerUnavailable(localeIdentifier)
        case .microphoneInputUnavailable:
            return AppStrings.microphoneInputUnavailable
        case .audioRecordingSetupFailure(let details):
            return AppStrings.audioRecordingSetupFailure(details)
        case .audioEngineFailure(let details):
            return AppStrings.audioEngineFailure(details)
        }
    }
}

final class AppleSpeechRecognitionService: NSObject, SpeechRecognitionServing {
    private let audioEngine = AVAudioEngine()
    private let fileManager: FileManager
    private let now: () -> Date
    private let stateLock = NSLock()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var audioFile: AVAudioFile?
    private var activeSessionID: UUID?
    private var latestTranscript: String = ""
    private var isStopping: Bool = false
    private var stopContinuations: [CheckedContinuation<String?, Never>] = []
    private var stopTimeoutWorkItem: DispatchWorkItem?
    private(set) var currentAudioRecordingURL: URL?

    init(
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.now = now
    }

    func requestPermissions() async -> PermissionState {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        let microphoneGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }

        switch speechStatus {
        case .authorized:
            return microphoneGranted ? .authorized : .microphoneDenied
        case .denied:
            return .speechDenied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unavailable(AppStrings.permissionNotDetermined)
        @unknown default:
            return .unavailable(AppStrings.unknownAuthorizationState)
        }
    }

    func startTranscription(
        localeIdentifier: String,
        onUpdate: @escaping @Sendable (TranscriptUpdate) -> Void
    ) throws {
        cancelRecognitionSession()
        let sessionID = UUID()

        let locale = Locale(identifier: localeIdentifier)
        guard let speechRecognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechRecognitionError.unsupportedLocale(localeIdentifier)
        }

        guard speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable(localeIdentifier)
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            recognitionRequest.addsPunctuation = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.channelCount > 0 else {
            throw SpeechRecognitionError.microphoneInputUnavailable
        }

        let outputURL: URL
        let audioFile: AVAudioFile
        do {
            outputURL = try AudioRecordingStore.makeRecordingURL(createdAt: now(), fileManager: fileManager)
            audioFile = try AVAudioFile(forWriting: outputURL, settings: recordingFormat.settings)
        } catch {
            throw SpeechRecognitionError.audioRecordingSetupFailure(error.localizedDescription)
        }

        self.speechRecognizer = speechRecognizer
        self.recognitionRequest = recognitionRequest
        self.audioFile = audioFile
        withStateLock {
            activeSessionID = sessionID
            latestTranscript = ""
            isStopping = false
            stopTimeoutWorkItem?.cancel()
            stopTimeoutWorkItem = nil
        }
        self.currentAudioRecordingURL = outputURL

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            guard self.isSessionActive(sessionID) else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.withStateLock {
                    self.latestTranscript = text
                }

                if !self.isStoppingSession {
                    let update: TranscriptUpdate = result.isFinal ? .final(text) : .partial(text)
                    DispatchQueue.main.async {
                        onUpdate(update)
                    }
                }

                if result.isFinal {
                    self.completeStopIfNeeded(with: text)
                }
            }

            if error != nil {
                self.completeStopIfNeeded(with: nil)
                self.stopAudioEngine()
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            if let audioFile = self?.audioFile {
                try? audioFile.write(from: buffer)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cancelRecognitionSession()
            throw SpeechRecognitionError.audioEngineFailure(error.localizedDescription)
        }
    }

    func stopTranscription() async -> String? {
        var immediateTranscript: String?
        var shouldStartGracefulStop = false
        var shouldCompleteImmediately = false

        return await withCheckedContinuation { continuation in
            withStateLock {
                let hasActiveSession = activeSessionID != nil || recognitionTask != nil || recognitionRequest != nil
                if !hasActiveSession && !isStopping {
                    immediateTranscript = normalizedTranscript(latestTranscript)
                    latestTranscript = ""
                    return
                }

                stopContinuations.append(continuation)

                if !isStopping {
                    isStopping = true
                    shouldStartGracefulStop = true
                }

                if recognitionTask == nil {
                    shouldCompleteImmediately = true
                }
            }

            if let immediateTranscript {
                continuation.resume(returning: immediateTranscript)
                return
            }

            if shouldStartGracefulStop {
                recognitionRequest?.endAudio()
                stopAudioEngine()
                scheduleStopTimeout()
            }

            if shouldCompleteImmediately {
                completeStopIfNeeded(with: nil)
            }
        }
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func scheduleStopTimeout() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.completeStopIfNeeded(with: nil)
        }

        withStateLock {
            stopTimeoutWorkItem?.cancel()
            stopTimeoutWorkItem = workItem
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: workItem)
    }

    private func completeStopIfNeeded(with transcript: String?) {
        var pendingContinuations: [CheckedContinuation<String?, Never>] = []
        var resolvedTranscript: String?

        withStateLock {
            guard !stopContinuations.isEmpty else { return }

            pendingContinuations = stopContinuations
            stopContinuations.removeAll()
            stopTimeoutWorkItem?.cancel()
            stopTimeoutWorkItem = nil
            resolvedTranscript = normalizedTranscript(transcript ?? latestTranscript)
            latestTranscript = ""
            activeSessionID = nil
            isStopping = false
        }

        cancelRecognitionResources()
        pendingContinuations.forEach { $0.resume(returning: resolvedTranscript) }
    }

    private func cancelRecognitionSession() {
        var pendingContinuations: [CheckedContinuation<String?, Never>] = []
        var resolvedTranscript: String?

        withStateLock {
            pendingContinuations = stopContinuations
            stopContinuations.removeAll()
            stopTimeoutWorkItem?.cancel()
            stopTimeoutWorkItem = nil
            resolvedTranscript = normalizedTranscript(latestTranscript)
            latestTranscript = ""
            activeSessionID = nil
            isStopping = false
        }

        cancelRecognitionResources()
        pendingContinuations.forEach { $0.resume(returning: resolvedTranscript) }
    }

    private func cancelRecognitionResources() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil
        stopAudioEngine()
        audioFile = nil
    }

    private func isSessionActive(_ sessionID: UUID) -> Bool {
        withStateLock { activeSessionID == sessionID }
    }

    private var isStoppingSession: Bool {
        withStateLock { isStopping }
    }

    private func normalizedTranscript(_ transcript: String?) -> String? {
        guard let transcript else { return nil }
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTranscript.isEmpty ? nil : transcript
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
}
