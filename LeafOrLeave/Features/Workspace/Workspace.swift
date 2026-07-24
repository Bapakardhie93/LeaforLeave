import Foundation

struct BrowserWorkspace: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var symbolName: String
    var accentToken: String
    var tabIDs: [UUID]
    var pinnedTabIDs: [UUID]
    var selectedTabID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool
    var homePage: String?
    var accentName: String?
}
