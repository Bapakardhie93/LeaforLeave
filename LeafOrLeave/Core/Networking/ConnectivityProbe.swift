import Foundation

struct ConnectivityProbe {
    func validate() async -> Bool {
        var request = URLRequest(url: URL(string: "https://www.apple.com/library/test/success.html")!)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        guard let response = try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse else { return false }
        return (200..<400).contains(response.statusCode)
    }
}
