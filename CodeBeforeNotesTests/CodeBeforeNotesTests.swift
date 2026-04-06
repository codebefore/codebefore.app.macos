import AVFoundation
import XCTest
@testable import CodeBeforeNotes

final class MarkdownNoteSerializerTests: XCTestCase {
    func testSuggestedFilenameUsesSlugifiedTitle() {
        let date = fixedDate()

        let filename = MarkdownNoteSerializer.suggestedFilename(for: "Simdi Yeni Repo", createdAt: date)

        XCTAssertEqual(filename, "simdi-yeni-repo.md")
    }

    func testMarkdownSerializationIncludesHeaderMetadataAndBody() {
        let draft = NoteDraft(
            title: "Toplanti Notu",
            body: "Bugun kararlar:\n- Uygulama native olsun",
            createdAt: fixedDate(),
            selectedLocaleIdentifier: "tr-TR"
        )

        let markdown = MarkdownNoteSerializer.markdown(for: draft)

        XCTAssertEqual(
            markdown,
            """
            # Toplanti Notu

            - Created: 2026-04-06 10:30
            - Language: tr-TR

            ---

            Bugun kararlar:
            - Uygulama native olsun
            """
        )
    }

    func testDefaultLocaleFallsBackToPreferredThenCurrentThenFirstSupported() {
        let selected = LocaleResolver.defaultLocaleIdentifier(
            supportedIdentifiers: ["en-US", "de-DE", "fr-FR"],
            preferredIdentifier: "tr-TR",
            currentLocale: Locale(identifier: "de-DE")
        )

        XCTAssertEqual(selected, "de-DE")
    }

    func testFinalizeRecordingMovesAudioNextToMarkdownWithMatchingName() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sourceURL = tempDirectory.appendingPathComponent("recording-temp.caf")
        let markdownURL = tempDirectory
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("toplanti.md")

        try FileManager.default.createDirectory(at: markdownURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeTestRecording(to: sourceURL)

        let finalizedURL = try await AudioRecordingStore.finalizeRecording(
            at: sourceURL,
            matchingMarkdownURL: markdownURL
        )

        XCTAssertEqual(finalizedURL.lastPathComponent, "toplanti.m4a")
        XCTAssertEqual(finalizedURL.deletingLastPathComponent(), markdownURL.deletingLastPathComponent())
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalizedURL.path))
    }

    func testFinalizeRecordingKeepsExistingAudioAndCreatesUniqueName() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sourceURL = tempDirectory.appendingPathComponent("recording-temp.caf")
        let markdownURL = tempDirectory
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("toplanti.md")
        let existingAudioURL = markdownURL.deletingPathExtension().appendingPathExtension("m4a")
        let existingData = Data("existing-audio".utf8)

        try FileManager.default.createDirectory(at: markdownURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try existingData.write(to: existingAudioURL)
        try writeTestRecording(to: sourceURL)

        let finalizedURL = try await AudioRecordingStore.finalizeRecording(
            at: sourceURL,
            matchingMarkdownURL: markdownURL
        )

        XCTAssertEqual(finalizedURL.lastPathComponent, "toplanti-2.m4a")
        XCTAssertEqual(try Data(contentsOf: existingAudioURL), existingData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalizedURL.path))
    }

    func testMakeSaveDestinationCreatesTimestampedFolderAndMatchingMarkdownFile() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let destination = try NoteSaveLocation.makeSaveDestination(
            createdAt: fixedDate(),
            baseDirectory: baseDirectory
        )

        XCTAssertEqual(destination.directoryURL.lastPathComponent, "2026-04-06-1030")
        XCTAssertEqual(destination.markdownURL.lastPathComponent, "2026-04-06-1030.md")
        XCTAssertEqual(destination.markdownURL.deletingLastPathComponent(), destination.directoryURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.directoryURL.path))
    }

    private func fixedDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 60 * 60) ?? .current
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 6,
            hour: 10,
            minute: 30
        )) ?? Date(timeIntervalSince1970: 0)
    }

    private func writeTestRecording(to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frameCount: AVAudioFrameCount = 4_096
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Audio buffer olusturulamadi.")
            return
        }

        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        for index in 0 ..< Int(frameCount) {
            samples[index] = sinf(2 * .pi * Float(index) / 32) * 0.2
        }

        try audioFile.write(from: buffer)
    }
}

@MainActor
final class NoteEditorViewModelTests: XCTestCase {
    func testNewNoteResetsDraftAndStopsActiveRecording() async {
        let speechService = MockSpeechRecognitionService()
        let date = Date(timeIntervalSince1970: 1_775_470_200)
        let viewModel = NoteEditorViewModel(
            speechService: speechService,
            localeOptions: [LocaleOption(identifier: "tr-TR", displayName: "Turkce")],
            currentLocale: Locale(identifier: "tr-TR"),
            now: { date }
        )

        viewModel.updateTitle("Eski Not")
        viewModel.updateEditorText("Elle yazilan kisim")
        speechService.currentAudioRecordingURL = URL(fileURLWithPath: "/tmp/test-recording.caf")
        await viewModel.startRecording()
        speechService.send(.partial("Canli transcript"))

        XCTAssertEqual(viewModel.draft.audioRecordingURL?.path, "/tmp/test-recording.caf")

        await viewModel.newNote()

        XCTAssertEqual(viewModel.draft.title, "")
        XCTAssertEqual(viewModel.editorText, "")
        XCTAssertEqual(viewModel.draft.selectedLocaleIdentifier, "tr-TR")
        XCTAssertNil(viewModel.draft.audioRecordingURL)
        XCTAssertNil(viewModel.draft.lastSavedURL)
        XCTAssertEqual(viewModel.recordingStatus, .idle)
        XCTAssertEqual(speechService.stopCallCount, 1)
    }

    func testSaveMarkdownStopsRecordingAndMovesAudioNextToMarkdown() async throws {
        let speechService = MockSpeechRecognitionService()
        let date = Date(timeIntervalSince1970: 1_775_470_200)
        let saveDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: saveDirectory) }

        let temporaryAudioURL = saveDirectory.appendingPathComponent("temp-recording.caf")
        try writeTestRecording(to: temporaryAudioURL)
        let destination = try NoteSaveLocation.makeSaveDestination(
            createdAt: date,
            baseDirectory: saveDirectory
        )

        let viewModel = NoteEditorViewModel(
            speechService: speechService,
            localeOptions: [LocaleOption(identifier: "tr-TR", displayName: "Turkce")],
            currentLocale: Locale(identifier: "tr-TR"),
            now: { date },
            saveDestinationFactory: { _ in destination }
        )

        viewModel.updateTitle("Toplanti")
        viewModel.updateEditorText("Kayit notu")
        speechService.currentAudioRecordingURL = temporaryAudioURL
        speechService.stopResult = "Kayit notu final"
        await viewModel.startRecording()

        await viewModel.saveMarkdown()

        XCTAssertEqual(speechService.stopCallCount, 1)
        XCTAssertEqual(viewModel.draft.lastSavedURL, destination.markdownURL)
        let expectedAudioFilename = "\(destination.directoryURL.lastPathComponent).m4a"
        XCTAssertEqual(viewModel.draft.audioRecordingURL?.lastPathComponent, expectedAudioFilename)
        XCTAssertEqual(viewModel.editorText, "Kayit notu\n\nKayit notu final")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.markdownURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.directoryURL.appendingPathComponent(expectedAudioFilename).path))
        XCTAssertTrue(
            try String(contentsOf: destination.markdownURL).contains("Kayit notu\n\nKayit notu final")
        )
    }

    func testEditorBufferKeepsManualEditsWhenTranscriptUpdates() {
        var buffer = EditorBuffer()
        buffer.setUserFacingText("Elle yazilan not")
        buffer.applyLiveTranscript("Ilk transcript")

        buffer.setUserFacingText("Elle guncellenen not\n\nIlk transcript")
        buffer.applyLiveTranscript("Son transcript")

        XCTAssertEqual(buffer.displayedText, "Elle guncellenen not\n\nSon transcript")
    }

    func testLateTranscriptAfterStopIsIgnored() async {
        let speechService = MockSpeechRecognitionService()
        speechService.stopResult = "Merhaba dunya"
        let viewModel = NoteEditorViewModel(
            speechService: speechService,
            localeOptions: [LocaleOption(identifier: "tr-TR", displayName: "Turkce")],
            currentLocale: Locale(identifier: "tr-TR")
        )

        await viewModel.startRecording()
        speechService.send(.partial("Merhaba dunya"))
        await Task.yield()

        XCTAssertEqual(viewModel.editorText, "Merhaba dunya")

        await viewModel.stopRecording()
        speechService.sendStale(.final("Merhaba dunya"))
        await Task.yield()

        XCTAssertEqual(viewModel.editorText, "Merhaba dunya")
    }

    private func writeTestRecording(to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frameCount: AVAudioFrameCount = 4_096
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Audio buffer olusturulamadi.")
            return
        }

        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        for index in 0 ..< Int(frameCount) {
            samples[index] = sinf(2 * .pi * Float(index) / 32) * 0.2
        }

        try audioFile.write(from: buffer)
    }
}

private final class MockSpeechRecognitionService: SpeechRecognitionServing {
    var permissionState: PermissionState = .authorized
    var stopCallCount = 0
    var stopResult: String?
    var currentAudioRecordingURL: URL?
    private var updateHandler: (@Sendable (TranscriptUpdate) -> Void)?
    private var staleUpdateHandler: (@Sendable (TranscriptUpdate) -> Void)?

    func requestPermissions() async -> PermissionState {
        permissionState
    }

    func startTranscription(
        localeIdentifier: String,
        onUpdate: @escaping @Sendable (TranscriptUpdate) -> Void
    ) throws {
        updateHandler = onUpdate
        staleUpdateHandler = onUpdate
    }

    func stopTranscription() async -> String? {
        stopCallCount += 1
        updateHandler = nil
        return stopResult
    }

    func send(_ update: TranscriptUpdate) {
        updateHandler?(update)
    }

    func sendStale(_ update: TranscriptUpdate) {
        staleUpdateHandler?(update)
    }
}
