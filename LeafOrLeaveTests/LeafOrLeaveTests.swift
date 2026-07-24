//
//  LeafOrLeaveTests.swift
//  LeafOrLeaveTests
//
//  Created by Bapakardhie Pacarnya Yaya on 11/07/26.
//

import Foundation
import Testing
import WebKit
@testable import LeafOrLeave

@MainActor
struct LeafOrLeaveTests {
    private let resolver = URLResolver()

    @Test func resolvesCompleteURL() {
        #expect(resolver.resolve("https://developer.apple.com")?.absoluteString == "https://developer.apple.com")
    }

    @Test func resolvesDomainWithoutScheme() {
        #expect(resolver.resolve("github.com")?.absoluteString == "https://github.com")
    }

    @Test func resolvesLocalNetworkAddressesOverHTTP() {
        #expect(resolver.resolve("192.168.1.1")?.absoluteString == "http://192.168.1.1")
        #expect(resolver.resolve("192.168.1.1:8080/admin")?.absoluteString == "http://192.168.1.1:8080/admin")
        #expect(resolver.resolve("router.local")?.absoluteString == "http://router.local")
        #expect(resolver.resolve("localhost:3000")?.absoluteString == "http://localhost:3000")
        #expect(resolver.resolve("8.8.8.8")?.absoluteString == "https://8.8.8.8")
        #expect(resolver.resolve("https://192.168.1.1")?.absoluteString == "https://192.168.1.1")
        #expect(resolver.localHTTPFallback(for: URL(string: "https://192.168.1.1/admin")!)?.absoluteString == "http://192.168.1.1/admin")
        #expect(resolver.localHTTPFallback(for: URL(string: "https://github.com")!) == nil)
    }

    @Test func resolvesKeywordsAsGoogleSearch() {
        let url = resolver.resolve("Swift WKWebView")
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        #expect(components?.host == "www.google.com")
        #expect(components?.queryItems?.first?.value == "Swift WKWebView")
    }

    @Test func resolvesConfiguredSearchEngines() {
        #expect(resolver.resolve("privacy browser", engine: .duckDuckGo)?.host == "duckduckgo.com")
        #expect(resolver.resolve("swift webkit", engine: .bing)?.host == "www.bing.com")
        let custom = resolver.resolve("hello world", engine: .custom,
                                      customTemplate: "https://search.example/?term={query}")
        #expect(custom?.host == "search.example")
        #expect(URLComponents(url: custom!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "hello world")
    }

    @Test func webViewAdvertisesSafariCompatibility() async throws {
        let webView = WebViewFactory(configuration: .default).makeWebView()
        let result = try await webView.evaluateJavaScript("navigator.userAgent")
        let userAgent = try #require(result as? String)

        #expect(userAgent.contains("AppleWebKit/"))
        #expect(userAgent.contains(" Version/"))
        #expect(userAgent.contains(" Safari/"))
    }

    @Test func workspaceDefaultsAndMutation() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let manager = WorkspaceManager(defaults: suite)
        #expect(manager.workspaces.map(\.name) == ["Study", "Coding", "Media"])
        manager.createWorkspace(name: "Research")
        let custom = manager.workspaces.last!
        manager.renameWorkspace(id: custom.id, name: "Thesis")
        #expect(manager.workspaces.last?.name == "Thesis")
        manager.deleteWorkspace(id: custom.id)
        #expect(manager.workspaces.count == 3)
    }

    @Test func workspaceMovesAndPinsTab() {
        let manager = WorkspaceManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let tab = UUID(), target = manager.workspaces[1].id
        manager.moveTab(tab, to: target); manager.pinTab(tab, in: target)
        #expect(manager.workspaces[1].tabIDs.contains(tab))
        #expect(manager.workspaces[1].pinnedTabIDs.contains(tab))
        manager.unpinTab(tab, in: target)
        #expect(!manager.workspaces[1].pinnedTabIDs.contains(tab))
    }

    @Test func workspaceReconciliationKeepsTabOwnershipSeparate() {
        let manager = WorkspaceManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let studyID = manager.workspaces[0].id
        let codingID = manager.workspaces[1].id
        let studyTab = UUID()
        let staleTab = UUID()
        let codingTab = UUID()

        manager.moveTab(studyTab, to: studyID)
        manager.moveTab(staleTab, to: studyID)
        manager.selectWorkspace(id: codingID)
        manager.reconcileTabs([studyTab, codingTab], assigningUnownedTo: codingID)

        #expect(manager.workspaces[0].tabIDs == [studyTab])
        #expect(manager.workspaces[1].tabIDs == [codingTab])
        #expect(manager.workspaces[1].selectedTabID == codingTab)

        manager.rememberSelection(studyTab)
        #expect(manager.workspaces[1].selectedTabID == codingTab)
    }

    @Test func settingsDefaultsAndSearchValidation() {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(settings.value.appearance == .graphiteDark)
        #expect(settings.value.suspensionAggressiveness == 0.6)
        #expect(settings.value.keepPinnedTabsAlive)
        #expect(settings.value.autoFillPasswords)
        #expect(settings.value.offerToSavePasswords)
        settings.value.customSearchTemplate = "https://search.example/?q={query}"
        #expect(settings.validCustomSearchTemplate())
        settings.value.customSearchTemplate = "https://search.example/"
        #expect(!settings.validCustomSearchTemplate())
    }

    @Test func settingsMigrationSuppliesSecureAndPerformanceDefaults() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        suite.set(Data("{}".utf8), forKey: "settings.typed.v1")
        let settings = SettingsStore(defaults: suite)

        #expect(settings.value.smartSuspension)
        #expect(settings.value.idleTimeout == 900)
        #expect(settings.value.suspensionAggressiveness == 0.6)
        #expect(settings.value.keepExamTabsAlive)
        #expect(settings.value.passwordAutoLockMinutes == 5)
        #expect(settings.value.autoFillPasswords)
    }

    @Test func webKitUsesPersistentWebsiteSessions() {
        let configuration = BrowserConfiguration.default.makeWebViewConfiguration()
        #expect(configuration.websiteDataStore.isPersistent)
    }

    @Test func startupCanSkipTheSavedTabSession() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let store = SessionStore(defaults: suite)
        store.save(BrowserSession(
            tabs: [
                TabSessionRecord(
                    url: URL(string: "https://example.com"),
                    title: "Saved",
                    isPinned: false,
                    lastActiveAt: .now
                )
            ],
            selectedIndex: 0
        ))

        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: store,
            restoresPreviousSession: false
        )
        #expect(manager.tabs.count == 1)
        #expect(manager.selectedTab?.url == nil)
        #expect(manager.selectedTab?.title == "New Tab")
    }

    @Test func passwordCredentialsNormalizeHostsAndEscapeAutofillPayload() throws {
        let credential = PasswordCredential(
            host: "https://WWW.Example.COM/login",
            username: " captain@example.com ",
            password: "secret"
        )
        #expect(credential.host == "example.com")
        #expect(credential.username == "captain@example.com")

        let script = try #require(
            PasswordScriptProvider.autofillScript(
                username: "captain\"@example.com",
                password: "</script>\"quoted"
            )
        )
        #expect(script.contains("captain\\\"@example.com"))
        #expect(script.contains("<\\/script>"))
    }

    @Test func passwordCaptureSupportsButtonDrivenMultiStepSignIn() async throws {
        let recorder = PasswordMessageRecorder()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(
            recorder,
            name: PasswordScriptProvider.name
        )
        configuration.userContentController.addUserScript(PasswordScriptProvider.script)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.loadHTMLString(
            """
            <!doctype html>
            <html>
              <body>
                <input id="identifierId" type="email" autocomplete="username">
                <div id="identifierNext" role="button">Next</div>
              </body>
            </html>
            """,
            baseURL: URL(string: "https://accounts.google.test")
        )

        for _ in 0..<50 {
            let fixtureLoaded = (try? await webView.evaluateJavaScript(
                "document.getElementById('identifierId') !== null"
            )) as? Bool
            if fixtureLoaded == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let fixtureLoaded = try await webView.evaluateJavaScript(
            "document.getElementById('identifierId') !== null"
        ) as? Bool
        #expect(fixtureLoaded == true)

        _ = try await webView.evaluateJavaScript(
            """
            const email = document.getElementById('identifierId');
            email.value = 'captain@gmail.com';
            email.dispatchEvent(new Event('input', { bubbles: true }));
            document.getElementById('identifierNext').click();
            document.body.innerHTML = `
              <input type="hidden" name="identifier" value="selected.account@gmail.com">
              <input id="password" name="login_password" type="text" placeholder="PIC/Password">
              <div id="passwordNext" role="button">Next</div>
            `;
            window.__leafPasswordCaptureEnabled = true;
            document.getElementById('password').value = 'automatic-secret';
            document.getElementById('passwordNext').click();
            """
        )

        var submission: [String: Any]?
        for _ in 0..<50 {
            submission = recorder.messages.last {
                $0["type"] as? String == "submitted"
            }
            if submission != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(submission?["host"] as? String == "accounts.google.test")
        #expect(submission?["username"] as? String == "selected.account@gmail.com")
        #expect(submission?["password"] as? String == "automatic-secret")
        #expect(submission?["passwordKind"] as? String == "current")

        let submittedDocumentID = try #require(submission?["documentID"] as? String)
        _ = try await webView.evaluateJavaScript(
            "document.body.innerHTML = '<main id=\"signedIn\">Signed in</main>';"
        )
        var successfulPageState: [String: Any]?
        for _ in 0..<50 {
            successfulPageState = recorder.messages.last {
                $0["type"] as? String == "pageState" &&
                $0["documentID"] as? String == submittedDocumentID &&
                $0["hasPassword"] as? Bool == false
            }
            if successfulPageState != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(successfulPageState != nil)

        _ = try await webView.evaluateJavaScript(
            """
            document.body.innerHTML = `
              <input id="studentNumber" type="text" name="student_number">
              <input id="picPassword" type="text" placeholder="PIC/Password">
            `;
            """
        )
        let autofillScript = try #require(
            PasswordScriptProvider.autofillScript(
                username: "202410370110053",
                password: "saved-umm-password"
            )
        )
        _ = try await webView.evaluateJavaScript(autofillScript)
        let autofilled = try await webView.evaluateJavaScript(
            """
            ({
              username: document.getElementById('studentNumber').value,
              password: document.getElementById('picPassword').value
            })
            """
        ) as? [String: String]
        #expect(autofilled?["username"] == "202410370110053")
        #expect(autofilled?["password"] == "saved-umm-password")

        let selectedAccountScript = try #require(
            PasswordScriptProvider.autofillScript(
                username: "202410370110248",
                password: "other-account-password",
                replacingExistingValues: true
            )
        )
        _ = try await webView.evaluateJavaScript(selectedAccountScript)
        let selectedAccount = try await webView.evaluateJavaScript(
            """
            ({
              username: document.getElementById('studentNumber').value,
              password: document.getElementById('picPassword').value
            })
            """
        ) as? [String: String]
        #expect(selectedAccount?["username"] == "202410370110248")
        #expect(selectedAccount?["password"] == "other-account-password")

        _ = try await webView.evaluateJavaScript(
            """
            document.body.innerHTML = `
              <input id="signupEmail" type="email" autocomplete="username">
              <input id="newPassword" type="password" autocomplete="new-password">
            `;
            """
        )
        let returningUserScript = try #require(
            PasswordScriptProvider.autofillScript(
                username: "returning@example.com",
                password: "must-not-fill-a-new-password"
            )
        )
        _ = try await webView.evaluateJavaScript(returningUserScript)
        let signupAutofill = try await webView.evaluateJavaScript(
            """
            ({
              username: document.getElementById('signupEmail').value,
              password: document.getElementById('newPassword').value
            })
            """
        ) as? [String: String]
        #expect(signupAutofill?["username"] == "returning@example.com")
        #expect(signupAutofill?["password"] == "")
    }

    @Test func passwordSaveOfferWaitsForSuccessfulLoginEvidence() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = SettingsStore(defaults: defaults)
        settings.value.onboardingCompleted = true
        settings.value.offerToSavePasswords = true
        let vault = PasswordVault(
            service: "app.leaforleave.tests.pending-password.\(UUID().uuidString)",
            authenticator: { _ in }
        )
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        manager.settings = settings
        manager.passwordVault = vault
        let tab = try #require(manager.selectedTab)

        tab.webView.loadHTMLString(
            """
            <!doctype html>
            <html>
              <body>
                <form id="login">
                  <input id="email" type="email" autocomplete="username">
                  <input id="password" type="password" autocomplete="current-password">
                  <button id="submit" type="submit">Sign in</button>
                </form>
                <script>
                  document.getElementById('login').addEventListener(
                    'submit',
                    event => event.preventDefault()
                  );
                </script>
              </body>
            </html>
            """,
            baseURL: URL(string: "https://accounts.flow.test/signin")
        )

        for _ in 0..<75 {
            let ready = (try? await tab.webView.evaluateJavaScript(
                "document.getElementById('login') !== null && window.__leafPasswordManagerInstalled"
            )) as? Bool
            if ready == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(100))

        _ = try await tab.webView.evaluateJavaScript(
            """
            const email = document.getElementById('email');
            const password = document.getElementById('password');
            email.value = 'captain@example.com';
            email.dispatchEvent(new Event('input', { bubbles: true }));
            password.value = 'wrong-password';
            document.getElementById('submit').click();
            """
        )
        try await Task.sleep(for: .milliseconds(1_300))
        #expect(tab.passwordSaveOffer == nil)

        _ = try await tab.webView.evaluateJavaScript(
            """
            document.getElementById('password').value = 'accepted-password';
            document.getElementById('submit').click();
            setTimeout(() => {
              document.getElementById('login')?.remove();
              document.body.insertAdjacentHTML('beforeend', '<main id="account">Account</main>');
            }, 50);
            """
        )
        for _ in 0..<100 {
            if tab.passwordSaveOffer != nil { break }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(tab.passwordSaveOffer?.host == "accounts.flow.test")
        #expect(tab.passwordSaveOffer?.username == "captain@example.com")
        tab.dismissPasswordSaveOffer()
    }

    @Test func passwordVaultRoundTripsThroughKeychain() async throws {
        let service = "app.leaforleave.tests.passwords.\(UUID().uuidString)"
        let vault = PasswordVault(
            service: service,
            authenticator: { _ in }
        )

        #expect(await vault.unlock(reason: "Test Keychain access"))
        let saved = try vault.save(
            host: "https://accounts.example.com/login",
            username: "captain@example.com",
            password: "correct horse battery staple"
        )

        vault.lock()
        #expect(await vault.unlock(reason: "Test Keychain reload"))
        #expect(vault.credential(for: "accounts.example.com") == saved)

        let second = try vault.save(
            host: "accounts.example.com",
            username: "first.mate@example.com",
            password: "another secure password"
        )
        #expect(Set(vault.credentials(for: "accounts.example.com").map(\.username)) == [
            "captain@example.com",
            "first.mate@example.com"
        ])

        try vault.delete(saved)
        try vault.delete(second)
        #expect(vault.storedCredentialCount == 0)
        vault.lock()
    }

    @Test func equalizerCompensatesPositiveGain() {
        let model = EqualizerViewModel()
        model.select(EqualizerPreset(name: "Test", gains: [6, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(model.preamp == -6)
    }

    @Test func sharedFormattingProducesStableBrowserLabels() {
        #expect(LeafFormatting.mediaTime(0) == "0:00")
        #expect(LeafFormatting.mediaTime(65) == "1:05")
        #expect(LeafFormatting.mediaTime(3_661) == "1:01:01")
        #expect(LeafFormatting.percentage(-1) == "0%")
        #expect(LeafFormatting.percentage(0.426) == "43%")
        #expect(LeafFormatting.percentage(2) == "100%")
        #expect(
            LeafFormatting.displayHost(URL(string: "https://www.example.com/path"))
                == "example.com"
        )
    }

    @Test func diagnosticLogBufferIsBoundedAndKeepsNewestEvents() {
        let store = LeafLogStore(capacity: 2)
        store.append(
            LeafLogEntry(
                date: .distantPast,
                level: .info,
                category: .app,
                message: "first"
            )
        )
        store.append(
            LeafLogEntry(
                date: .distantPast,
                level: .notice,
                category: .network,
                message: "second"
            )
        )
        store.append(
            LeafLogEntry(
                date: .distantPast,
                level: .warning,
                category: .browser,
                message: "third"
            )
        )

        #expect(store.entries().map(\.message) == ["second", "third"])
        #expect(store.entries(limit: 1).map(\.message) == ["third"])

        store.setCollectionEnabled(false)
        store.append(
            LeafLogEntry(
                date: .distantFuture,
                level: .error,
                category: .app,
                message: "disabled"
            )
        )
        #expect(store.entries().isEmpty)
    }
}

@MainActor
private final class PasswordMessageRecorder: NSObject, WKScriptMessageHandler {
    private(set) var messages: [[String: Any]] = []

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }
        messages.append(body)
    }
}
