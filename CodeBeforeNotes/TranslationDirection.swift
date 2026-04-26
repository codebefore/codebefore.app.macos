import Foundation

enum TranslationStatus: Equatable {
    case idle
    case translating
    case failed(String)

    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

struct TranslationDirection: Equatable {
    let sourceLanguageCode: String
    let targetLanguageCode: String
    let sourceLocaleIdentifier: String
    let targetLocaleIdentifier: String

    static func from(sourceLocaleIdentifier: String) -> TranslationDirection? {
        let language = Locale(identifier: sourceLocaleIdentifier).language.languageCode?.identifier
        switch language {
        case "en":
            return TranslationDirection(
                sourceLanguageCode: "en",
                targetLanguageCode: "tr",
                sourceLocaleIdentifier: sourceLocaleIdentifier,
                targetLocaleIdentifier: "tr-TR"
            )
        case "tr":
            return TranslationDirection(
                sourceLanguageCode: "tr",
                targetLanguageCode: "en",
                sourceLocaleIdentifier: sourceLocaleIdentifier,
                targetLocaleIdentifier: "en-US"
            )
        case "de":
            return TranslationDirection(
                sourceLanguageCode: "de",
                targetLanguageCode: "tr",
                sourceLocaleIdentifier: sourceLocaleIdentifier,
                targetLocaleIdentifier: "tr-TR"
            )
        default:
            return nil
        }
    }
}
