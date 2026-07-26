import Foundation

nonisolated enum BrowserNavigationFailureKind: Equatable {
    case offline
    case dns
    case timedOut
    case unreachable
    case secureConnection
    case server
    case unknown
}

nonisolated enum BrowserNavigationError: LocalizedError, Equatable {
    case invalidAddress
    case navigationFailed(
        kind: BrowserNavigationFailureKind,
        address: String?,
        technicalDescription: String
    )
    case processTerminated

    static func navigationFailure(from error: NSError, failingURL: URL?) -> Self {
        let kind: BrowserNavigationFailureKind
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorInternationalRoamingOff,
                 NSURLErrorDataNotAllowed:
                kind = .offline
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                kind = .dns
            case NSURLErrorTimedOut:
                kind = .timedOut
            case NSURLErrorCannotConnectToHost:
                kind = .unreachable
            case NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid,
                 NSURLErrorClientCertificateRejected,
                 NSURLErrorClientCertificateRequired:
                kind = .secureConnection
            case NSURLErrorBadServerResponse,
                 NSURLErrorCannotParseResponse:
                kind = .server
            default:
                kind = .unknown
            }
        } else {
            kind = .unknown
        }

        return .navigationFailed(
            kind: kind,
            address: failingURL?.absoluteString,
            technicalDescription: error.localizedDescription
        )
    }

    var failureKind: BrowserNavigationFailureKind? {
        guard case .navigationFailed(let kind, _, _) = self else { return nil }
        return kind
    }

    var title: String {
        switch self {
        case .invalidAddress: "That address does not look right"
        case .navigationFailed(let kind, _, _):
            switch kind {
            case .offline: "You're offline"
            case .dns: "Website not found"
            case .timedOut: "The website took too long"
            case .unreachable: "Website can't be reached"
            case .secureConnection: "Secure connection failed"
            case .server: "The website sent an invalid response"
            case .unknown: "This page couldn't be opened"
            }
        case .processTerminated: "The page stopped unexpectedly"
        }
    }

    var guidance: String {
        switch self {
        case .invalidAddress:
            "Enter a complete web address, a domain, or a search term."
        case .navigationFailed(let kind, _, _):
            switch kind {
            case .offline:
                "Check your Wi-Fi or Ethernet connection, then try again."
            case .dns:
                "Check the spelling of the address. If it is correct, the website may be temporarily unavailable."
            case .timedOut:
                "The server did not respond in time. Your connection may be slow, or the website may be busy."
            case .unreachable:
                "The server refused the connection or is currently unavailable."
            case .secureConnection:
                "LeafOrLeave could not establish a trusted encrypted connection to this website."
            case .server:
                "The server returned data the browser could not understand."
            case .unknown:
                "A navigation error prevented this page from loading."
            }
        case .processTerminated:
            "The website process was closed by the system. Reloading usually restores the page."
        }
    }

    var systemImage: String {
        switch self {
        case .invalidAddress: "text.magnifyingglass"
        case .navigationFailed(let kind, _, _):
            switch kind {
            case .offline: "wifi.slash"
            case .dns: "globe.badge.chevron.backward"
            case .timedOut: "clock.badge.exclamationmark"
            case .unreachable: "network.slash"
            case .secureConnection: "lock.trianglebadge.exclamationmark"
            case .server: "server.rack"
            case .unknown: "exclamationmark.triangle"
            }
        case .processTerminated: "arrow.clockwise.circle"
        }
    }

    var address: String? {
        guard case .navigationFailed(_, let address, _) = self else { return nil }
        return address
    }

    var technicalDescription: String? {
        guard case .navigationFailed(_, _, let description) = self else { return nil }
        return description
    }

    var errorDescription: String? { "\(title). \(guidance)" }
}
