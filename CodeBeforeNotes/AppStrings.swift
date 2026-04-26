import Foundation

private final class AppStringsBundleToken {}

enum AppStrings {
    private static let bundle: Bundle = {
        let candidates = [Bundle.main, Bundle(for: AppStringsBundleToken.self)]
        return candidates.first(where: { bundle in
            bundle.path(forResource: "en", ofType: "lproj") != nil ||
            bundle.path(forResource: "tr", ofType: "lproj") != nil
        }) ?? Bundle.main
    }()

    static var ready: String {
        localized("status.ready", defaultValue: "Hazir.")
    }

    static var noteTitlePlaceholder: String {
        localized("editor.title.placeholder", defaultValue: "Not basligi")
    }

    static var localePickerLabel: String {
        localized("editor.locale.label", defaultValue: "Dil")
    }

    static var newNoteButton: String {
        localized("action.newNote", defaultValue: "Yeni Not")
    }

    static var startRecordingButton: String {
        localized("action.startRecording", defaultValue: "Kayda Basla")
    }

    static var stopRecordingButton: String {
        localized("action.stopRecording", defaultValue: "Durdur")
    }

    static var saveMarkdownButton: String {
        localized("action.saveMarkdown", defaultValue: "Markdown Kaydet")
    }

    static var translateToggleLabel: String {
        localized("editor.translate.toggle", defaultValue: "Cevir")
    }

    static var translationPlaceholder: String {
        localized("editor.translate.placeholder", defaultValue: "Ceviri burada gorunecek.")
    }

    static var audioRecordingFolderReady: String {
        localized("status.audioRecording.folderReady", defaultValue: "Ses kaydi da kaydediliyor.")
    }

    static var savePanelTitle: String {
        localized("save.title", defaultValue: "Markdown olarak kaydet")
    }

    static var savePanelPrompt: String {
        localized("save.prompt", defaultValue: "Kaydet")
    }

    static var saveCancelled: String {
        localized("save.cancelled", defaultValue: "Kaydetme iptal edildi.")
    }

    static var savePreparingRecording: String {
        localized("save.preparingRecording", defaultValue: "Kaydi bitirip dosyalar hazirlaniyor...")
    }

    static var authorizingPermissions: String {
        localized("status.authorizing", defaultValue: "Izinler kontrol ediliyor...")
    }

    static var recordingStarted: String {
        localized("status.recording.started", defaultValue: "Kayit basladi.")
    }

    static var recordingFailed: String {
        localized("status.recording.failed", defaultValue: "Kayit baslatilamadi.")
    }

    static var recordingStopped: String {
        localized("status.recording.stopped", defaultValue: "Kayit durdu.")
    }

    static var recordingStopping: String {
        localized("status.recording.stopping", defaultValue: "Kayit durduruluyor...")
    }

    static var newNoteReady: String {
        localized("status.newNoteReady", defaultValue: "Yeni not hazir.")
    }

    static var microphoneDenied: String {
        localized("permission.microphoneDenied", defaultValue: "Mikrofon izni verilmedigi icin kayit baslatilamadi.")
    }

    static var speechDenied: String {
        localized("permission.speechDenied", defaultValue: "Speech recognition izni verilmedigi icin kayit baslatilamadi.")
    }

    static var permissionsRestricted: String {
        localized("permission.restricted", defaultValue: "Bu cihazda gerekli izinler kisitli.")
    }

    static var permissionNotDetermined: String {
        localized("permission.notDetermined", defaultValue: "Izin durumu henuz belirlenemedi.")
    }

    static var unknownAuthorizationState: String {
        localized("permission.unknown", defaultValue: "Bilinmeyen bir speech authorization durumu olustu.")
    }

    static var microphoneInputUnavailable: String {
        localized("speech.microphoneUnavailable", defaultValue: "Mikrofon girisi bulunamadi.")
    }

    static var audioRecordingSetupFailed: String {
        localized("speech.audioRecordingSetupFailed", defaultValue: "Ses dosyasi olusturulamadi.")
    }

    static func lastSaved(_ path: String) -> String {
        localized("editor.lastSaved", defaultValue: "Son kayit: %@", path)
    }

    static func lastAudioRecording(_ path: String) -> String {
        localized("editor.lastAudioRecording", defaultValue: "Son ses kaydi: %@", path)
    }

    static func localeUpdated(_ localeDisplayName: String) -> String {
        localized("status.locale.updated", defaultValue: "Dil guncellendi: %@.", localeDisplayName)
    }

    static func recordingStartedWithAudio(_ path: String) -> String {
        localized("status.recording.startedWithAudio", defaultValue: "Kayit basladi. Ses dosyasi: %@", path)
    }

    static func recordingStoppedWithAudio(_ path: String) -> String {
        localized("status.recording.stoppedWithAudio", defaultValue: "Kayit durdu. Ses dosyasi hazir: %@", path)
    }

    static func saveSucceeded(_ filename: String) -> String {
        localized("save.success", defaultValue: "Markdown kaydedildi: %@", filename)
    }

    static func saveSucceededWithAudio(_ markdownFilename: String, _ audioFilename: String) -> String {
        localized("save.successWithAudio", defaultValue: "Markdown ve ses kaydi kaydedildi: %@, %@", markdownFilename, audioFilename)
    }

    static func saveFailed(_ details: String) -> String {
        localized("save.failed", defaultValue: "Dosya kaydedilemedi: %@", details)
    }

    static func audioSaveFailed(_ details: String) -> String {
        localized("save.audioFailed", defaultValue: "Ses dosyasi kaydedilemedi: %@", details)
    }

    static func unsupportedLocale(_ localeIdentifier: String) -> String {
        localized("speech.unsupportedLocale", defaultValue: "Secilen dil desteklenmiyor: %@", localeIdentifier)
    }

    static func recognizerUnavailable(_ localeIdentifier: String) -> String {
        localized("speech.recognizerUnavailable", defaultValue: "Speech recognizer su anda kullanilamiyor: %@", localeIdentifier)
    }

    static func audioEngineFailure(_ details: String) -> String {
        localized("speech.audioEngineFailure", defaultValue: "Ses motoru baslatilamadi: %@", details)
    }

    static func audioRecordingSetupFailure(_ details: String) -> String {
        localized("speech.audioRecordingSetupFailure", defaultValue: "Ses kaydi hazirlanamadi: %@", details)
    }

    private static func localized(_ key: String, defaultValue: String) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    private static func localized(_ key: String, defaultValue: String, _ arguments: CVarArg...) -> String {
        let format = localized(key, defaultValue: defaultValue)
        return String(format: format, locale: Locale.autoupdatingCurrent, arguments: arguments)
    }
}
