import AppKit
import Foundation
import UniformTypeIdentifiers

struct WorkspaceBackupTemplate: Codable, Equatable {
    let name: String
    let symbolName: String
    let accentToken: String
    let homePage: String?
    let accentName: String?

    init(_ workspace: BrowserWorkspace) {
        name = workspace.name
        symbolName = workspace.symbolName
        accentToken = workspace.accentToken
        homePage = workspace.homePage
        accentName = workspace.accentName
    }
}

struct BrowserDataBackup: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let bookmarks: [LibraryEntry]
    let archivedTabs: [LibraryEntry]
    let workspaceTemplates: [WorkspaceBackupTemplate]
    let settings: SettingsData
}

enum BrowserDataBackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "This backup uses unsupported format version \(version)."
        }
    }
}

@MainActor
enum BrowserDataBackupService {
    static func makeBackup(settings: SettingsStore, library: LibraryManager,
                           workspaces: WorkspaceManager) -> BrowserDataBackup {
        BrowserDataBackup(
            formatVersion: 1,
            exportedAt: .now,
            bookmarks: library.bookmarks,
            archivedTabs: library.archivedTabs,
            workspaceTemplates: workspaces.workspaces.map(WorkspaceBackupTemplate.init),
            settings: settings.value
        )
    }

    static func encode(_ backup: BrowserDataBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> BrowserDataBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BrowserDataBackup.self, from: data)
        guard backup.formatVersion == 1 else {
            throw BrowserDataBackupError.unsupportedVersion(backup.formatVersion)
        }
        return backup
    }

    static func restore(_ backup: BrowserDataBackup, settings: SettingsStore,
                        library: LibraryManager, workspaces: WorkspaceManager) {
        library.restoreCollections(
            bookmarks: backup.bookmarks,
            archivedTabs: backup.archivedTabs
        )
        workspaces.restoreTemplates(backup.workspaceTemplates)
        settings.value = backup.settings
    }

    static func exportUsingPanel(settings: SettingsStore, library: LibraryManager,
                                 workspaces: WorkspaceManager) {
        let panel = NSSavePanel()
        panel.title = "Export LeafOrLeave Data"
        panel.nameFieldStringValue = "LeafOrLeave Backup.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = "Exports settings, workspace templates, bookmarks, and archived tabs. Passwords, cookies, and history are excluded."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try encode(makeBackup(settings: settings, library: library, workspaces: workspaces))
            try data.write(to: url, options: .atomic)
            showResult(title: "Backup Exported", message: "LeafOrLeave data was saved successfully.")
        } catch {
            show(error)
        }
    }

    static func importUsingPanel(settings: SettingsStore, library: LibraryManager,
                                 workspaces: WorkspaceManager) {
        let panel = NSOpenPanel()
        panel.title = "Import LeafOrLeave Data"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a LeafOrLeave JSON backup. Passwords, cookies, history, and open tabs are not imported."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let backup = try decode(Data(contentsOf: url))
            restore(backup, settings: settings, library: library, workspaces: workspaces)
            showResult(title: "Backup Imported", message: "Settings and saved collections were restored.")
        } catch {
            show(error)
        }
    }

    private static func show(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private static func showResult(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
