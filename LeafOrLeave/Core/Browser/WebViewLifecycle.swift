import Foundation

struct WebViewLifecycleSnapshot: Codable, Equatable {
    let url: URL?
    let title: String
    let scrollY: Double
}
