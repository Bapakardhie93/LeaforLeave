import Foundation

struct ExamProtectedTab: Identifiable, Equatable {
    let id: UUID
    let enabledAt: Date
    init(id: UUID, enabledAt: Date = Date()) { self.id = id; self.enabledAt = enabledAt }
}
