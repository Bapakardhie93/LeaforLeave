import AppKit
import AVFoundation
import Contacts
import CoreGraphics
import CoreLocation
import EventKit
import Observation
import Photos
import Speech
import SwiftUI
import UserNotifications

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.leafAccentColor) private var accentColor
    @State private var permissions = PrivacyPermissionController()
    @State private var selectedFolder: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    permissionSection(
                        "Website essentials",
                        detail: "A website must ask before LeafOrLeave requests these system permissions."
                    ) {
                        permissionRow("Camera", icon: "camera.fill", state: permissions.camera) {
                            permissions.requestCamera()
                        }
                        rowDivider
                        permissionRow("Microphone", icon: "mic.fill", state: permissions.microphone) {
                            permissions.requestMicrophone()
                        }
                        rowDivider
                        permissionRow("Location", icon: "location.fill", state: permissions.location) {
                            permissions.requestLocation()
                        }
                        rowDivider
                        permissionRow("Screen Recording", icon: "rectangle.dashed.badge.record", state: permissions.screenRecording) {
                            permissions.requestScreenRecording()
                        }
                        rowDivider
                        permissionRow("Notifications", icon: "bell.badge.fill", state: permissions.notifications) {
                            permissions.requestNotifications()
                        }
                    }

                    permissionSection(
                        "Optional website integrations",
                        detail: "These remain off until you explicitly allow them. Most websites never need them."
                    ) {
                        permissionRow("Contacts", icon: "person.crop.circle.fill", state: permissions.contacts) {
                            permissions.requestContacts()
                        }
                        rowDivider
                        permissionRow("Calendars", icon: "calendar", state: permissions.calendars) {
                            permissions.requestCalendars()
                        }
                        rowDivider
                        permissionRow("Reminders", icon: "checklist", state: permissions.reminders) {
                            permissions.requestReminders()
                        }
                        rowDivider
                        permissionRow("Photos", icon: "photo.on.rectangle.angled", state: permissions.photos) {
                            permissions.requestPhotos()
                        }
                        rowDivider
                        permissionRow("Speech Recognition", icon: "waveform.badge.mic", state: permissions.speechRecognition) {
                            permissions.requestSpeechRecognition()
                        }
                    }

                    permissionSection(
                        "Files, devices & network",
                        detail: "Access is limited by the macOS sandbox and can be revoked in System Settings."
                    ) {
                        folderRow
                        rowDivider
                        managedRow(
                            "Downloads Folder",
                            icon: "arrow.down.circle.fill",
                            detail: "Used only to save files you choose to download.",
                            status: "Sandboxed"
                        ) { openPrivacySettings(anchor: "Privacy_FilesAndFolders") }
                        rowDivider
                        managedRow(
                            "Local Network",
                            icon: "network",
                            detail: "Needed for localhost, .local sites, routers, and nearby web devices.",
                            status: "On request"
                        ) { openPrivacySettings(anchor: "Privacy_LocalNetwork") }
                        rowDivider
                        managedRow(
                            "Bluetooth",
                            icon: "wave.3.right.circle.fill",
                            detail: "Reserved for websites or devices that support browser-based Bluetooth access.",
                            status: "On request"
                        ) { openPrivacySettings(anchor: "Privacy_Bluetooth") }
                    }

                    Label(
                        "System permission and website permission are separate. Allowing LeafOrLeave in macOS does not automatically grant access to every website.",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .scrollIndicators(.automatic)

            footer
        }
        .frame(minWidth: 650, idealWidth: 720, minHeight: 580, idealHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            .shadow(color: accentColor.opacity(0.2), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text("Permissions & Privacy")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("You stay in control of system and website access")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.055), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close Permissions & Privacy")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background {
            LinearGradient(
                colors: [accentColor.opacity(0.065), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func permissionSection<Content: View>(
        _ title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.75)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            VStack(spacing: 0, content: content)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.055))
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    private func permissionRow(
        _ title: String,
        icon: String,
        state: PrivacyPermissionState,
        request: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            permissionIcon(icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12.5, weight: .medium))
                Text(state.detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            statusBadge(state)
            Button(state.canRequest ? "Request" : "Manage…") {
                if state.canRequest { request() }
                else { openPrivacySettings(anchor: state.settingsAnchor) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 58)
    }

    private var folderRow: some View {
        HStack(spacing: 12) {
            permissionIcon("folder.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text("Files & Folders").font(.system(size: 12.5, weight: .medium))
                Text(selectedFolder?.path ?? "Choose folders individually when access is needed.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Text(selectedFolder == nil ? "On request" : "Selected")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selectedFolder == nil ? Color.secondary : LeafColors.secure)
            Button("Choose…", action: chooseFolder)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 58)
    }

    private func managedRow(
        _ title: String,
        icon: String,
        detail: String,
        status: String,
        manage: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            permissionIcon(icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12.5, weight: .medium))
                Text(detail).font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(status)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Button("Manage…", action: manage)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 58)
    }

    private func permissionIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(accentColor)
            .frame(width: 34, height: 34)
            .background(accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func statusBadge(_ state: PrivacyPermissionState) -> some View {
        HStack(spacing: 5) {
            Circle().fill(state.color).frame(width: 6, height: 6)
            Text(state.title)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(state.color)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 59)
    }

    private var footer: some View {
        HStack {
            Button("Open macOS Privacy Settings") { openPrivacySettings(anchor: nil) }
                .controlSize(.small)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentColor)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
        .background(.bar)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Allow Access"
        panel.message = "Choose a folder that LeafOrLeave may access."
        panel.begin { response in
            if response == .OK { selectedFolder = panel.url }
        }
    }

    private func openPrivacySettings(anchor: String?) {
        let suffix = anchor.map { "?\($0)" } ?? ""
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security\(suffix)") else { return }
        NSWorkspace.shared.open(url)
    }
}

private enum PrivacyPermissionState: Equatable {
    case notRequested(anchor: String)
    case allowed(anchor: String)
    case limited(anchor: String)
    case denied(anchor: String)
    case restricted(anchor: String)
    case unavailable(anchor: String)

    var settingsAnchor: String {
        switch self {
        case let .notRequested(anchor), let .allowed(anchor), let .limited(anchor),
             let .denied(anchor), let .restricted(anchor), let .unavailable(anchor): anchor
        }
    }

    var canRequest: Bool {
        if case .notRequested = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .notRequested: "Not requested"
        case .allowed: "Allowed"
        case .limited: "Limited"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .unavailable: "Unavailable"
        }
    }

    var detail: String {
        switch self {
        case .notRequested: "macOS will ask only after you choose Request."
        case .allowed: "LeafOrLeave may use this only after a website or you request it."
        case .limited: "macOS currently permits limited access."
        case .denied: "Access is off and can be changed in System Settings."
        case .restricted: "Access is restricted by macOS or device policy."
        case .unavailable: "This permission is not available on this Mac."
        }
    }

    var color: Color {
        switch self {
        case .allowed: LeafColors.secure
        case .limited: .orange
        case .denied: .red
        case .restricted: .orange
        case .notRequested, .unavailable: .secondary
        }
    }
}

@MainActor
@Observable
private final class PrivacyPermissionController: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let contactStore = CNContactStore()
    private let eventStore = EKEventStore()

    var camera: PrivacyPermissionState = .notRequested(anchor: "Privacy_Camera")
    var microphone: PrivacyPermissionState = .notRequested(anchor: "Privacy_Microphone")
    var location: PrivacyPermissionState = .notRequested(anchor: "Privacy_LocationServices")
    var screenRecording: PrivacyPermissionState = .notRequested(anchor: "Privacy_ScreenCapture")
    var notifications: PrivacyPermissionState = .notRequested(anchor: "Privacy_Notifications")
    var contacts: PrivacyPermissionState = .notRequested(anchor: "Privacy_Contacts")
    var calendars: PrivacyPermissionState = .notRequested(anchor: "Privacy_Calendars")
    var reminders: PrivacyPermissionState = .notRequested(anchor: "Privacy_Reminders")
    var photos: PrivacyPermissionState = .notRequested(anchor: "Privacy_Photos")
    var speechRecognition: PrivacyPermissionState = .notRequested(anchor: "Privacy_SpeechRecognition")

    override init() {
        super.init()
        locationManager.delegate = self
        refresh()
    }

    func refresh() {
        camera = Self.state(AVCaptureDevice.authorizationStatus(for: .video), anchor: "Privacy_Camera")
        microphone = Self.state(AVCaptureDevice.authorizationStatus(for: .audio), anchor: "Privacy_Microphone")
        location = Self.state(locationManager.authorizationStatus, anchor: "Privacy_LocationServices")
        screenRecording = CGPreflightScreenCaptureAccess()
            ? .allowed(anchor: "Privacy_ScreenCapture")
            : .notRequested(anchor: "Privacy_ScreenCapture")
        contacts = Self.state(CNContactStore.authorizationStatus(for: .contacts), anchor: "Privacy_Contacts")
        calendars = Self.state(EKEventStore.authorizationStatus(for: .event), anchor: "Privacy_Calendars")
        reminders = Self.state(EKEventStore.authorizationStatus(for: .reminder), anchor: "Privacy_Reminders")
        photos = Self.state(PHPhotoLibrary.authorizationStatus(for: .readWrite), anchor: "Privacy_Photos")
        speechRecognition = Self.state(SFSpeechRecognizer.authorizationStatus(), anchor: "Privacy_SpeechRecognition")
        refreshNotifications()
    }

    func requestCamera() { requestMedia(.video) }
    func requestMicrophone() { requestMedia(.audio) }
    func requestLocation() { locationManager.requestWhenInUseAuthorization() }

    func requestScreenRecording() {
        screenRecording = CGRequestScreenCaptureAccess()
            ? .allowed(anchor: "Privacy_ScreenCapture")
            : .denied(anchor: "Privacy_ScreenCapture")
    }

    func requestNotifications() {
        let reference = PermissionControllerReference(self)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            Task { @MainActor in reference.value?.refreshNotifications() }
        }
    }

    func requestContacts() {
        let reference = PermissionControllerReference(self)
        contactStore.requestAccess(for: .contacts) { _, _ in
            Task { @MainActor in reference.value?.refresh() }
        }
    }

    func requestCalendars() {
        let reference = PermissionControllerReference(self)
        eventStore.requestFullAccessToEvents { _, _ in
            Task { @MainActor in reference.value?.refresh() }
        }
    }

    func requestReminders() {
        let reference = PermissionControllerReference(self)
        eventStore.requestFullAccessToReminders { _, _ in
            Task { @MainActor in reference.value?.refresh() }
        }
    }

    func requestPhotos() {
        let reference = PermissionControllerReference(self)
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            Task { @MainActor in reference.value?.refresh() }
        }
    }

    func requestSpeechRecognition() {
        let reference = PermissionControllerReference(self)
        SFSpeechRecognizer.requestAuthorization { _ in
            Task { @MainActor in reference.value?.refresh() }
        }
    }

    private func requestMedia(_ type: AVMediaType) {
        let reference = PermissionControllerReference(self)
        AVCaptureDevice.requestAccess(for: type) { _ in
            Task { @MainActor in reference.value?.refresh() }
        }
    }

    private func refreshNotifications() {
        let reference = PermissionControllerReference(self)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let state: PrivacyPermissionState
            switch settings.authorizationStatus {
            case .notDetermined: state = .notRequested(anchor: "Privacy_Notifications")
            case .authorized, .provisional, .ephemeral: state = .allowed(anchor: "Privacy_Notifications")
            case .denied: state = .denied(anchor: "Privacy_Notifications")
            @unknown default: state = .unavailable(anchor: "Privacy_Notifications")
            }
            Task { @MainActor in reference.value?.notifications = state }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.location = Self.state(status, anchor: "Privacy_LocationServices")
        }
    }

    private static func state(_ value: AVAuthorizationStatus, anchor: String) -> PrivacyPermissionState {
        switch value {
        case .notDetermined: .notRequested(anchor: anchor)
        case .authorized: .allowed(anchor: anchor)
        case .denied: .denied(anchor: anchor)
        case .restricted: .restricted(anchor: anchor)
        @unknown default: .unavailable(anchor: anchor)
        }
    }

    private static func state(_ value: CLAuthorizationStatus, anchor: String) -> PrivacyPermissionState {
        switch value {
        case .notDetermined: .notRequested(anchor: anchor)
        case .authorizedAlways: .allowed(anchor: anchor)
        case .denied: .denied(anchor: anchor)
        case .restricted: .restricted(anchor: anchor)
        @unknown default: .unavailable(anchor: anchor)
        }
    }

    private static func state(_ value: CNAuthorizationStatus, anchor: String) -> PrivacyPermissionState {
        switch value {
        case .notDetermined: .notRequested(anchor: anchor)
        case .authorized: .allowed(anchor: anchor)
        case .limited: .limited(anchor: anchor)
        case .denied: .denied(anchor: anchor)
        case .restricted: .restricted(anchor: anchor)
        @unknown default: .unavailable(anchor: anchor)
        }
    }

    private static func state(_ value: EKAuthorizationStatus, anchor: String) -> PrivacyPermissionState {
        switch value {
        case .notDetermined: .notRequested(anchor: anchor)
        case .fullAccess, .authorized: .allowed(anchor: anchor)
        case .writeOnly: .limited(anchor: anchor)
        case .denied: .denied(anchor: anchor)
        case .restricted: .restricted(anchor: anchor)
        @unknown default: .unavailable(anchor: anchor)
        }
    }

    private static func state(_ value: PHAuthorizationStatus, anchor: String) -> PrivacyPermissionState {
        switch value {
        case .notDetermined: .notRequested(anchor: anchor)
        case .authorized: .allowed(anchor: anchor)
        case .limited: .limited(anchor: anchor)
        case .denied: .denied(anchor: anchor)
        case .restricted: .restricted(anchor: anchor)
        @unknown default: .unavailable(anchor: anchor)
        }
    }

    private static func state(_ value: SFSpeechRecognizerAuthorizationStatus, anchor: String) -> PrivacyPermissionState {
        switch value {
        case .notDetermined: .notRequested(anchor: anchor)
        case .authorized: .allowed(anchor: anchor)
        case .denied: .denied(anchor: anchor)
        case .restricted: .restricted(anchor: anchor)
        @unknown default: .unavailable(anchor: anchor)
        }
    }
}

private final class PermissionControllerReference: @unchecked Sendable {
    nonisolated(unsafe) weak var value: PrivacyPermissionController?

    init(_ value: PrivacyPermissionController) {
        self.value = value
    }
}
