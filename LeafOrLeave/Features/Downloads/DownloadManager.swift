import AppKit
import Observation
import WebKit

@MainActor @Observable
final class DownloadManager: NSObject, WKDownloadDelegate {
    private(set) var records: [DownloadRecord] = []
    private var ids: [ObjectIdentifier: UUID] = [:]
    private var activeDownloads: [UUID: WKDownload] = [:]
    private var progressObservations: [UUID: NSKeyValueObservation] = [:]
    private let asksForDestination: () -> Bool
    private let key = "downloads.history.v1"
    init(asksForDestination: @escaping () -> Bool = { false }) {
        self.asksForDestination = asksForDestination
        super.init()
        if let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode([DownloadRecord].self, from: data) {
            records = value.map { var r = $0; if r.status == .downloading { r.status = .failed }; return r }
        }
    }
    func register(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        guard ids[key] == nil else { return }
        let id = UUID()
        download.delegate = self
        ids[key] = id
        activeDownloads[id] = download
        records.insert(.init(id: id, filename: "Download", sourceHost: download.originalRequest?.url?.host ?? "Unknown", destination: nil, progress: 0, bytesWritten: 0, totalBytes: 0, status: .downloading, errorMessage: nil, createdAt: Date()), at: 0)
        progressObservations[id] = download.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak manager = self] progress, _ in
            let fraction = progress.fractionCompleted
            let completed = progress.completedUnitCount
            let total = progress.totalUnitCount
            Task { @MainActor [weak manager] in
                manager?.mutate(id) {
                    $0.progress = fraction
                    $0.bytesWritten = max(0, completed)
                    $0.totalBytes = max(0, total)
                }
            }
        }
        LeafLog.info("Download registered", category: .downloads)
        save()
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let name = safeName(suggestedFilename)
        update(download) { $0.filename = name }

        guard asksForDestination() else {
            let url = uniqueURL(name)
            update(download) { $0.destination = url }
            completionHandler(url)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Download"
        panel.nameFieldStringValue = name
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.canCreateDirectories = true
        panel.prompt = "Download"
        panel.message = "Choose where LeafOrLeave may save this file."
        panel.begin { [weak self, weak download] response in
            guard let self, let download else { completionHandler(nil); return }
            guard response == .OK, let url = panel.url else {
                self.update(download) { $0.status = .cancelled }
                self.ids[ObjectIdentifier(download)] = nil
                LeafLog.notice("Download destination selection cancelled", category: .downloads)
                completionHandler(nil)
                return
            }
            self.update(download) { $0.destination = url }
            completionHandler(url)
        }
    }
    func downloadDidFinish(_ download: WKDownload) {
        update(download) { $0.status = .completed; $0.progress = 1 }
        LeafLog.notice("Download completed", category: .downloads)
        finish(download)
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        update(download) { $0.status = .failed; $0.errorMessage = error.localizedDescription }
        let value = error as NSError
        LeafLog.error("Download failed (\(value.domain) \(value.code))", category: .downloads)
        finish(download)
    }
    func cancel(_ id: UUID) {
        activeDownloads[id]?.cancel()
        cleanup(id)
        mutate(id) { $0.status = .cancelled }
        LeafLog.notice("Download cancelled", category: .downloads)
    }
    func open(_ record: DownloadRecord) { if let url = record.destination, !["app","pkg","dmg","command"].contains(url.pathExtension.lowercased()) { NSWorkspace.shared.open(url) } }
    func reveal(_ record: DownloadRecord) { if let url = record.destination { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
    func remove(_ id: UUID) { records.removeAll { $0.id == id }; save() }
    func clearCompleted() { records.removeAll { $0.status == .completed }; save() }
    private func update(_ download: WKDownload, mutation: (inout DownloadRecord) -> Void) { guard let id = ids[ObjectIdentifier(download)] else { return }; mutate(id, mutation) }
    private func finish(_ download: WKDownload) { if let id = ids.removeValue(forKey: ObjectIdentifier(download)) { cleanup(id) } }
    private func cleanup(_ id: UUID) { activeDownloads[id] = nil; progressObservations[id]?.invalidate(); progressObservations[id] = nil; ids = ids.filter { $0.value != id } }
    private func mutate(_ id: UUID, _ mutation: (inout DownloadRecord) -> Void) { guard let i = records.firstIndex(where: { $0.id == id }) else { return }; mutation(&records[i]); save() }
    private func safeName(_ name: String) -> String { let value = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-"); return value.isEmpty ? "Download" : value }
    private func uniqueURL(_ name: String) -> URL { let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]; let base = folder.appendingPathComponent(name); guard FileManager.default.fileExists(atPath: base.path) else { return base }; let ext = base.pathExtension, stem = base.deletingPathExtension().lastPathComponent; for n in 2...999 { let candidate = folder.appendingPathComponent("\(stem) \(n)" + (ext.isEmpty ? "" : ".\(ext)")); if !FileManager.default.fileExists(atPath: candidate.path) { return candidate } }; return folder.appendingPathComponent(UUID().uuidString + "-" + name) }
    private func save() { if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: key) } }
}
