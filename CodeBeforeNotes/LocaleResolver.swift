import Foundation
import Speech

struct LocaleOption: Identifiable, Equatable {
    let identifier: String
    let displayName: String

    var id: String { identifier }
}

enum LocaleResolver {
    static func supportedLocaleOptions(
        preferredIdentifier: String = "tr-TR",
        currentLocale: Locale = .current,
        supportedLocales: Set<Locale> = SFSpeechRecognizer.supportedLocales()
    ) -> [LocaleOption] {
        let identifiers = supportedLocales.map(\.identifier)
        let orderedIdentifiers = identifiers.sorted {
            displayName(for: $0, currentLocale: currentLocale) < displayName(for: $1, currentLocale: currentLocale)
        }

        let defaultIdentifier = defaultLocaleIdentifier(
            supportedIdentifiers: orderedIdentifiers,
            preferredIdentifier: preferredIdentifier,
            currentLocale: currentLocale
        )

        let options = orderedIdentifiers.map {
            LocaleOption(identifier: $0, displayName: displayName(for: $0, currentLocale: currentLocale))
        }

        guard let defaultOption = options.first(where: { $0.identifier == defaultIdentifier }) else {
            return options
        }

        return [defaultOption] + options.filter { $0.identifier != defaultOption.identifier }
    }

    static func defaultLocaleIdentifier(
        supportedIdentifiers: [String],
        preferredIdentifier: String = "tr-TR",
        currentLocale: Locale = .current
    ) -> String {
        if supportedIdentifiers.contains(preferredIdentifier) {
            return preferredIdentifier
        }

        let currentIdentifier = currentLocale.identifier
        if supportedIdentifiers.contains(currentIdentifier) {
            return currentIdentifier
        }

        let normalizedCurrentLanguage = currentLocale.language.languageCode?.identifier
        if let languageMatch = supportedIdentifiers.first(where: { identifier in
            Locale(identifier: identifier).language.languageCode?.identifier == normalizedCurrentLanguage
        }) {
            return languageMatch
        }

        return supportedIdentifiers.first ?? preferredIdentifier
    }

    static func displayName(for identifier: String, currentLocale: Locale = .current) -> String {
        currentLocale.localizedString(forIdentifier: identifier) ?? identifier
    }
}
