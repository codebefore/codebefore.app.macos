import SwiftUI
import Translation

@MainActor
struct ContentView: View {
    @StateObject private var viewModel: NoteEditorViewModel
    @State private var translationConfiguration: TranslationSession.Configuration?

    init() {
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel())
    }

    init(viewModel: NoteEditorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(AppStrings.noteTitlePlaceholder, text: titleBinding)
                .textFieldStyle(.roundedBorder)

            ViewThatFits(in: .horizontal) {
                controlsRow
                compactControls
            }

            Label(viewModel.statusMessage, systemImage: viewModel.statusSystemImageName)
                .foregroundStyle(viewModel.statusColor)
                .font(.callout)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let lastSavedPath = viewModel.lastSavedPath {
                Text(AppStrings.lastSaved(lastSavedPath))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let audioRecordingPath = viewModel.audioRecordingPath {
                Text(AppStrings.lastAudioRecording(audioRecordingPath))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            editorArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 320, minHeight: 260)
        .onChange(of: viewModel.isTranslateEnabled) { _, enabled in
            updateTranslationConfiguration(enabled: enabled, direction: viewModel.translationDirection)
        }
        .onChange(of: viewModel.draft.selectedLocaleIdentifier) { _, _ in
            updateTranslationConfiguration(enabled: viewModel.isTranslateEnabled, direction: viewModel.translationDirection)
        }
        .translationTask(translationConfiguration) { session in
            await runTranslation(session: session)
        }
    }

    @ViewBuilder
    private var editorArea: some View {
        if viewModel.isTranslateEnabled, viewModel.translationDirection != nil {
            HSplitView {
                sourceEditor
                translatedPane
            }
        } else {
            sourceEditor
        }
    }

    private var sourceEditor: some View {
        TextEditor(text: editorBinding)
            .font(.system(size: 15, weight: .regular, design: .monospaced))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var translatedPane: some View {
        ScrollView {
            Text(viewModel.translatedText.isEmpty ? AppStrings.translationPlaceholder : viewModel.translatedText)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundStyle(viewModel.translatedText.isEmpty ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controlsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            localePicker
            translateToggle

            Spacer(minLength: 0)

            actionButtons
        }
    }

    private var compactControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            localePicker
            translateToggle
            compactActionButtons
        }
    }

    private var localePicker: some View {
        Picker(AppStrings.localePickerLabel, selection: localeBinding) {
            ForEach(viewModel.localeOptions) { option in
                Text(option.displayName).tag(option.identifier)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 280, alignment: .leading)
        .disabled(viewModel.recordingStatus.isRecording)
    }

    private var translateToggle: some View {
        HStack(spacing: 8) {
            Toggle(AppStrings.translateToggleLabel, isOn: translateBinding)
                .toggleStyle(.switch)
                .disabled(viewModel.translationDirection == nil)

            translationStatusIndicator
        }
    }

    @ViewBuilder
    private var translationStatusIndicator: some View {
        switch viewModel.translationStatus {
        case .idle:
            EmptyView()
        case .translating:
            ProgressView()
                .controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(viewModel.translationStatus.failureMessage ?? "")
        }
    }

    private var actionButtons: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(AppStrings.newNoteButton) {
                Task { await viewModel.newNote() }
            }
            .disabled(viewModel.recordingStatus.isBusy)

            Button(recordingButtonTitle) {
                viewModel.toggleRecording()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(viewModel.recordingStatus.isBusy)

            Button(AppStrings.saveMarkdownButton) {
                Task { await viewModel.saveMarkdown() }
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(viewModel.recordingStatus.isBusy)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var compactActionButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(AppStrings.newNoteButton) {
                Task { await viewModel.newNote() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(viewModel.recordingStatus.isBusy)

            Button(recordingButtonTitle) {
                viewModel.toggleRecording()
            }
            .keyboardShortcut(.space, modifiers: [])
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(viewModel.recordingStatus.isBusy)

            Button(AppStrings.saveMarkdownButton) {
                Task { await viewModel.saveMarkdown() }
            }
            .keyboardShortcut("s", modifiers: [.command])
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(viewModel.recordingStatus.isBusy)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recordingButtonTitle: String {
        viewModel.recordingStatus.isRecording ? AppStrings.stopRecordingButton : AppStrings.startRecordingButton
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.title },
            set: { viewModel.updateTitle($0) }
        )
    }

    private var localeBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.selectedLocaleIdentifier },
            set: { viewModel.updateSelectedLocale($0) }
        )
    }

    private var editorBinding: Binding<String> {
        Binding(
            get: { viewModel.editorText },
            set: { viewModel.updateEditorText($0) }
        )
    }

    private var translateBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isTranslateEnabled },
            set: { viewModel.setTranslateEnabled($0) }
        )
    }

    private func updateTranslationConfiguration(enabled: Bool, direction: TranslationDirection?) {
        guard enabled, let direction else {
            translationConfiguration = nil
            return
        }
        let source = Locale.Language(identifier: direction.sourceLanguageCode)
        let target = Locale.Language(identifier: direction.targetLanguageCode)
        if let existing = translationConfiguration,
           existing.source == source,
           existing.target == target {
            return
        }
        translationConfiguration = TranslationSession.Configuration(source: source, target: target)
    }

    private func runTranslation(session: TranslationSession) async {
        var lastTranslatedText = ""
        var lastToken = -1
        while !Task.isCancelled {
            let currentText = viewModel.editorText
            let currentToken = viewModel.translationRequestToken
            if currentToken != lastToken, currentText != lastTranslatedText, !currentText.isEmpty {
                viewModel.reportTranslationStarted()
                do {
                    let response = try await session.translate(currentText)
                    viewModel.applyTranslatedText(response.targetText)
                    lastTranslatedText = currentText
                } catch {
                    viewModel.reportTranslationFailed(error.localizedDescription)
                }
                lastToken = currentToken
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }
}
