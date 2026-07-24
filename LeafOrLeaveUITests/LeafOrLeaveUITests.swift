//
//  LeafOrLeaveUITests.swift
//  LeafOrLeaveUITests
//
//  Created by Bapakardhie Pacarnya Yaya on 11/07/26.
//

import XCTest

final class LeafOrLeaveUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testModernSettingsNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 2) {
            skip.click()
        }

        let applicationMenu = app.menuBars.menuBarItems["LeafOrLeave"]
        XCTAssertTrue(applicationMenu.waitForExistence(timeout: 3))
        applicationMenu.click()

        let settingsMenuItem = app.menuBars.menuItems["Settings…"]
        XCTAssertTrue(settingsMenuItem.waitForExistence(timeout: 3))
        settingsMenuItem.click()

        // SwiftUI Settings windows do not consistently expose their title to
        // Accessibility on every macOS release. Wait for stable sidebar
        // content instead of coupling the test to a window-title attribute.
        XCTAssertTrue(app.buttons["Workspaces"].waitForExistence(timeout: 8))

        try verifySection(
            "Workspaces",
            shows: "New Workspace",
            in: app,
            screenshotName: "Settings - Workspaces"
        )
        try verifySection(
            "Performance",
            shows: "Smart Tab Suspension",
            in: app,
            screenshotName: "Settings - Performance"
        )
        try verifySection(
            "Appearance",
            shows: "New Tab shortcuts",
            in: app,
            screenshotName: "Settings - Appearance"
        )
        try verifySection(
            "Developer",
            shows: "Developer Mode",
            in: app,
            screenshotName: "Settings - Developer"
        )
        try verifySection(
            "Advanced",
            shows: "Passwords & Autofill",
            in: app,
            screenshotName: "Settings - Advanced"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func verifySection(
        _ sidebarTitle: String,
        shows expectedLabel: String,
        in app: XCUIApplication,
        screenshotName: String
    ) throws {
        let section = app.buttons[sidebarTitle]
        XCTAssertTrue(section.waitForExistence(timeout: 3))
        section.click()
        let expected = app.descendants(matching: .any)[expectedLabel]
        XCTAssertTrue(expected.waitForExistence(timeout: 3))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
