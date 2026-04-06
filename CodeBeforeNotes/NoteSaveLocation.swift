import Foundation

struct NoteSaveDestination: Equatable {
    let directoryURL: URL
    let markdownURL: URL
}

enum NoteSaveLocation {
    static func defaultRootDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("voices", isDirectory: true)
    }

    static func reuseOrCreateSaveDestination(
        for draft: NoteDraft,
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> NoteSaveDestination {
        if let existingMarkdownURL = draft.lastSavedURL {
            return NoteSaveDestination(
                directoryURL: existingMarkdownURL.deletingLastPathComponent(),
                markdownURL: existingMarkdownURL
            )
        }

        return try makeSaveDestination(
            createdAt: draft.createdAt,
            baseDirectory: baseDirectory,
            fileManager: fileManager
        )
    }

    static func makeSaveDestination(
        createdAt: Date,
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> NoteSaveDestination {
        let rootDirectory = (baseDirectory ?? defaultRootDirectory(fileManager: fileManager)).standardizedFileURL
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let baseFolderName = folderTimestamp(from: createdAt)
        let folderName = uniqueFolderName(for: baseFolderName, in: rootDirectory, fileManager: fileManager)
        let directoryURL = rootDirectory.appendingPathComponent(folderName, isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let markdownURL = directoryURL
            .appendingPathComponent(folderName, isDirectory: false)
            .appendingPathExtension("md")

        return NoteSaveDestination(directoryURL: directoryURL, markdownURL: markdownURL)
    }

    private static func uniqueFolderName(
        for baseName: String,
        in rootDirectory: URL,
        fileManager: FileManager
    ) -> String {
        var folderName = baseName
        var suffix = 2

        while fileManager.fileExists(atPath: rootDirectory.appendingPathComponent(folderName, isDirectory: true).path) {
            folderName = "\(baseName)-\(suffix)"
            suffix += 1
        }

        return folderName
    }

    private static func folderTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}
