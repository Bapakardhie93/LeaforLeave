import Foundation

struct URLResolver {
    nonisolated init() {}

    func resolve(_ input: String, engine: SearchEngine = .google, customTemplate: String = "") -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let completeURL = completeURL(from: value) {
            return completeURL
        }

        if let inferredURL = inferredURL(from: value) {
            return inferredURL
        }

        return searchURL(for: value, engine: engine, customTemplate: customTemplate)
    }

    func localHTTPFallback(for url: URL) -> URL? {
        guard url.scheme?.lowercased() == "https",
              let host = url.host,
              isLocalNetworkHost(host),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "http"
        return components.url
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

    private func inferredURL(from value: String) -> URL? {
        guard !value.contains(where: { $0.isWhitespace }),
              var components = URLComponents(string: "https://\(value)"),
              let host = components.host else {
            return nil
        }
        guard host == "localhost" || host.contains(".") || host.contains(":") else {
            return nil
        }

        // Router dashboards and other LAN appliances commonly expose only an
        // HTTP endpoint. Use HTTP only when the user omitted a scheme and the
        // destination is provably local; explicit http:// or https:// input is
        // always preserved by completeURL(from:).
        components.scheme = isLocalNetworkHost(host) ? "http" : "https"
        return components.url
    }

    private func isLocalNetworkHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        if normalized == "localhost" || normalized.hasSuffix(".local") {
            return true
        }

        if normalized.contains(":") {
            return normalized == "::1"
                || normalized.hasPrefix("fc")
                || normalized.hasPrefix("fd")
                || ["fe8", "fe9", "fea", "feb"].contains { normalized.hasPrefix($0) }
        }

        let octets = normalized.split(separator: ".", omittingEmptySubsequences: false)
            .compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }

        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (192, 168), (169, 254):
            return true
        case (172, 16...31):
            return true
        case (100, 64...127):
            return true
        default:
            return false
        }
    }

    private func searchURL(for query: String, engine: SearchEngine, customTemplate: String) -> URL? {
        if engine == .custom, customTemplate.contains("{query}") {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return URL(string: customTemplate.replacingOccurrences(of: "{query}", with: encoded))
        }
        let endpoint: String
        switch engine {
        case .google: endpoint = "https://www.google.com/search"
        case .duckDuckGo: endpoint = "https://duckduckgo.com/"
        case .bing: endpoint = "https://www.bing.com/search"
        case .custom: endpoint = "https://www.google.com/search"
        }
        var components = URLComponents(string: endpoint)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}
