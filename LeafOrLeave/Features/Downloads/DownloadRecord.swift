import Foundation

enum DownloadStatus: String, Codable { case queued, downloading, paused, completed, failed, cancelled }
struct DownloadRecord: Identifiable, Codable, Equatable {
    let id: UUID; var filename: String; var sourceHost: String; var destination: URL?; var progress: Double; var bytesWritten: Int64; var totalBytes: Int64; var status: DownloadStatus; var errorMessage: String?; let createdAt: Date
}
