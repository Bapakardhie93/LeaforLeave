import Foundation

struct URLResolver {
    private let searchEndpoint = "https://www.google.com/search"

    nonisolated init() {}

    func resolve(_ input: String) -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let completeURL = completeURL(from: value) {
            return completeURL
        }

        if looksLikeDomain(value) {
            return URL(string: "https://\(value)")
        }

        var components = URLComponents(string: searchEndpoint)
        components?.queryItems = [URLQueryItem(name: "q", value: value)]
        return components?.url
    }

    private func completeURL(from value: String) -> URL? {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return nil
        }
        return components.url
    }

    private func looksLikeDomain(_ value: String) -> Bool {
        guard !value.contains(where: { $0.isWhitespace }),
              let components = URLComponents(string: "https://\(value)"),
              let host = components.host else {
            return false
        }
        return host == "localhost" || host.contains(".")
    }
}
