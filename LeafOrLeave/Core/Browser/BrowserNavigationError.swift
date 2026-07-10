import Foundation

enum BrowserNavigationError: LocalizedError, Equatable {
    case invalidAddress
    case navigationFailed(String)
    case processTerminated

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            "Alamat tidak valid. Masukkan URL, domain, atau kata kunci pencarian."
        case .navigationFailed(let message):
            "Halaman tidak dapat dibuka: \(message)"
        case .processTerminated:
            "Proses halaman berhenti. Muat ulang halaman untuk mencoba kembali."
        }
    }
}
