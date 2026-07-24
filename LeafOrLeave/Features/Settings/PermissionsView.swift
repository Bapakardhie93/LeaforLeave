import AVFoundation
import AppKit
import SwiftUI

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var selectedFolder: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "hand.raised.fill").foregroundStyle(LeafColors.accent)
                VStack(alignment: .leading) {
                    Text("Permissions & Privacy").font(.headline) //London Bridge Funkot - Wuenak tenan boss
                    Text("System and website access used by LeafOrLeave").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 26, height: 26) }
                    .buttonStyle(.plain).background(.white.opacity(0.07), in: Circle())
            }.padding(20)
            Divider()
            VStack(spacing: 12) {
                permissionRow("Camera", icon: "camera.fill", status: camera) { request(.video) }
                permissionRow("Microphone", icon: "mic.fill", status: microphone) { request(.audio) }
                HStack(spacing: 14) {
                    Image(systemName: "folder.fill").foregroundStyle(LeafColors.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Files and Folders").font(.subheadline.weight(.semibold))
                        Text(selectedFolder?.path ?? "Choose a folder when a website or download needs access.")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Button("Choose Folder…", action: chooseFolder).buttonStyle(.bordered)
                }.padding(14).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
                Text("Website camera and microphone requests still require a separate per-site confirmation. LeafOrLeave never grants them silently.")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                Spacer()
                HStack {
                    Button("Open macOS Privacy Settings", action: openPrivacySettings)
                    Spacer()
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(LeafColors.accent)
                }
            }.padding(20)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 430, idealHeight: 480)
        .background(.regularMaterial)
    }

    private func permissionRow(_ title: String, icon: String, status: AVAuthorizationStatus,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(LeafColors.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(statusText(status)).font(.caption).foregroundStyle(status == .authorized ? LeafColors.secure : .secondary)
            }
            Spacer()
            Button(status == .notDetermined ? "Request Access" : "Manage…",
                   action: status == .notDetermined ? action : openPrivacySettings).buttonStyle(.bordered)
        }.padding(14).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
    }

    private func request(_ mediaType: AVMediaType) {
        AVCaptureDevice.requestAccess(for: mediaType) { _ in
            Task { @MainActor in
                camera = AVCaptureDevice.authorizationStatus(for: .video)
                microphone = AVCaptureDevice.authorizationStatus(for: .audio)
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = "Allow Access"
        panel.message = "Choose a folder that LeafOrLeave may access."
        panel.begin { response in if response == .OK { selectedFolder = panel.url } }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") { NSWorkspace.shared.open(url) }
    }

    private func statusText(_ status: AVAuthorizationStatus) -> String {
        switch status { case .authorized: "Allowed"; case .denied: "Denied — change in System Settings"; case .restricted: "Restricted by macOS"; case .notDetermined: "Not requested yet"; @unknown default: "Unknown" }
    }
}
