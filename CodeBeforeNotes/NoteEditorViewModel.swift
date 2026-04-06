import SwiftUI

@MainActor
final class NoteEditorViewModel: ObservableObject {
    @Published private(set) var draft: NoteDraft
    @Published private(set) var editorText: String = ""
    @Published private(set) var recordingStatus: RecordingStatus = .idle
    @Published private(set) var localeOptions: [LocaleOption]
    @Published private(set) var statusMessage: String = AppStrings.ready
    @Published private(set) var statusIsError: Bool = false

    private let speechService: SpeechRecognitionServing
    private let saveDestinationFactory: (NoteDraft) throws -> NoteSaveDestination
    private let now: () -> Date
    private var editorBuffer = EditorBuffer()

    init(
        speechService: SpeechRecognitionServing = AppleSpeechRecognitionService(),
        localeOptions: [LocaleOption]? = nil,
        currentLocale: Locale = .current,
        now: @escaping () -> Date = Date.init,
        saveDestinationFactory: @escaping (NoteDraft) throws -> NoteSaveDestination = { draft in
            try NoteSaveLocation.reuseOrCreateSaveDestination(for: draft)
        }
    ) {
        self.speechService = speechService
        self.saveDestinationFactory = saveDestinationFactory
        self.now = now

        let availableLocales = localeOptions ?? LocaleResolver.supportedLocaleOptions(currentLocale: currentLocale)
        let selectedLocale = LocaleResolver.defaultLocaleIdentifier(
            supportedIdentifiers: availableLocales.map(\.identifier),
            currentLocale: currentLocale
        )
        self.localeOptions = availableLocales
        self.draft = NoteDraft(createdAt: now(), selectedLocaleIdentifier: selectedLocale)
    }

    var statusSystemImageName: String {
        switch recordingStatus {
        case .recording:
            return "waveform"
        case .stopping:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        case .authorizing:
            return "lock.shield"
        case .stopped:
            return "pause.circle"
        case .idle:
            return "note.text"
        }
    }

    var statusColor: Color {
        statusIsError ? .red : .secondary
    }

    var lastSavedPath: String? {
        draft.lastSavedURL?.path
    }

    var audioRecordingPath: String? {
        draft.audioRecordingURL?.path
    }

    func updateTitle(_ title: String) {
        draft.title = title
    }

    func updateSelectedLocale(_ identifier: String) {
        draft.selectedLocaleIdentifier = identifier
        setStatus(AppStrings.localeUpdated(LocaleResolver.displayName(for: identifier)), isError: false)
    }

    func updateEditorText(_ text: String) {
        editorBuffer.setUserFacingText(text)
        syncEditorText()
    }

    func toggleRecording() {
        Task {
            if recordingStatus.isRecordingSessionActive {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    func startRecording() async {
        guard !recordingStatus.isRecording else { return }

        recordingStatus = .authorizing
        setStatus(AppStrings.authorizingPermissions, isError: false)

        let permissionState = await speechService.requestPermissions()
        guard permissionState == .authorized else {
            recordingStatus = .error(permissionState.message)
            setStatus(permissionState.message, isError: true)
            return
        }

        do {
            try speechService.startTranscription(localeIdentifier: draft.selectedLocaleIdentifier) { [weak self] update in
                Task { @MainActor in
                    self?.handleTranscriptUpdate(update)
                }
            }
            draft.audioRecordingURL = speechService.currentAudioRecordingURL
            recordingStatus = .recording
            if let audioRecordingURL = draft.audioRecordingURL {
                setStatus(AppStrings.recordingStartedWithAudio(audioRecordingURL.lastPathComponent), isError: false)
            } else {
                setStatus(AppStrings.recordingStarted, isError: false)
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? AppStrings.recordingFailed
            recordingStatus = .error(message)
            setStatus(message, isError: true)
        }
    }

    func stopRecording() async {
        guard recordingStatus.isRecordingSessionActive else { return }
        guard recordingStatus != .stopping else { return }

        recordingStatus = .stopping
        setStatus(AppStrings.recordingStopping, isError: false)

        if let finalizedTranscript = await speechService.stopTranscription() {
            editorBuffer.applyLiveTranscript(finalizedTranscript)
        }

        draft.audioRecordingURL = speechService.currentAudioRecordingURL
        editorBuffer.commitLiveTranscript()
        syncEditorText()
        recordingStatus = .stopped
        if let audioRecordingURL = draft.audioRecordingURL {
            setStatus(AppStrings.recordingStoppedWithAudio(audioRecordingURL.lastPathComponent), isError: false)
        } else {
            setStatus(AppStrings.recordingStopped, isError: false)
        }
    }

    func newNote() async {
        if recordingStatus.isRecordingSessionActive {
            await stopRecording()
        }

        AudioRecordingStore.removeTemporaryRecordingIfNeeded(at: draft.audioRecordingURL)

        let selectedLocale = draft.selectedLocaleIdentifier
        draft = NoteDraft(createdAt: now(), selectedLocaleIdentifier: selectedLocale)
        editorBuffer.reset()
        editorText = ""
        recordingStatus = .idle
        setStatus(AppStrings.newNoteReady, isError: false)
    }

    func saveMarkdown() async {
        if recordingStatus.isRecordingSessionActive {
            setStatus(AppStrings.savePreparingRecording, isError: false)
            await stopRecording()
        }

        let outputURL: URL
        do {
            outputURL = try saveDestinationFactory(draft).markdownURL
        } catch {
            let message = AppStrings.saveFailed(error.localizedDescription)
            recordingStatus = .error(message)
            setStatus(message, isError: true)
            return
        }
        var savedDraft = draft
        savedDraft.body = editorBuffer.displayedText
        savedDraft.lastSavedURL = outputURL

        let markdown = MarkdownNoteSerializer.markdown(for: savedDraft)

        do {
            try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
            draft.lastSavedURL = outputURL
            draft.body = savedDraft.body

            if let audioRecordingURL = draft.audioRecordingURL {
                do {
                    let finalizedAudioURL = try await AudioRecordingStore.finalizeRecording(
                        at: audioRecordingURL,
                        matchingMarkdownURL: outputURL
                    )
                    draft.audioRecordingURL = finalizedAudioURL
                    setStatus(
                        AppStrings.saveSucceededWithAudio(
                            outputURL.lastPathComponent,
                            finalizedAudioURL.lastPathComponent
                        ),
                        isError: false
                    )
                } catch {
                    setStatus(AppStrings.audioSaveFailed(error.localizedDescription), isError: true)
                }
            } else {
                setStatus(AppStrings.saveSucceeded(outputURL.lastPathComponent), isError: false)
            }
        } catch {
            let message = AppStrings.saveFailed(error.localizedDescription)
            recordingStatus = .error(message)
            setStatus(message, isError: true)
        }
    }

    private func handleTranscriptUpdate(_ update: TranscriptUpdate) {
        guard recordingStatus.isRecording else { return }

        switch update {
        case .partial(let text):
            editorBuffer.applyLiveTranscript(text)
            syncEditorText()
        case .final(let text):
            editorBuffer.applyLiveTranscript(text)
            syncEditorText()
        }
    }

    private func syncEditorText() {
        editorText = editorBuffer.displayedText
        draft.body = editorText
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }
}
