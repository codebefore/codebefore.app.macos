import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var viewModel: NoteEditorViewModel

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 320, minHeight: 260)
    }

    private var controlsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            localePicker

            Spacer(minLength: 0)

            actionButtons
        }
    }

    private var compactControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            localePicker
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
}
