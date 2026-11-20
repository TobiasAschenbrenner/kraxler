import XCTest

final class ApprovedScreenTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testAuthenticationButtonStatesInBothAppearances() throws {
        for appearance in ["light", "dark"] {
            for mode in ["create-account", "sign-in"] {
                let app = XCUIApplication()
                app.launchArguments = ["-ui-test-signed-out", "-ui-test-capture", "-appAppearance", appearance]
                app.launch()
                let entryButton = app.buttons["authentication-\(mode)"]
                XCTAssertTrue(entryButton.waitForExistence(timeout: 10))
                if mode == "create-account" { capture("\(appearance)-welcome") }
                entryButton.tap()

                let submitButton = app.buttons["authentication-submit"]
                XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
                XCTAssertFalse(submitButton.isEnabled)
                capture("\(appearance)-\(mode)-incomplete")

                let emailField = app.textFields["authentication-email"].firstMatch
                XCTAssertTrue(emailField.waitForExistence(timeout: 5))
                emailField.tap()
                emailField.typeText("climber@example.com")
                XCTAssertFalse(submitButton.isEnabled)

                let passwordField = app.secureTextFields["authentication-password"].firstMatch
                passwordField.tap()
                if app.buttons["Fill Strong Password"].waitForExistence(timeout: 2) {
                    app.buttons["Close"].tap()
                }
                passwordField.typeText("a sample passphrase")
                XCTAssertTrue(submitButton.isEnabled)
                passwordField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(
                        forDuration: 0.1,
                        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
                    )
                XCTAssertTrue(submitButton.isHittable)
                capture("\(appearance)-\(mode)-complete")
                app.terminate()
            }
        }
    }

    @MainActor
    func testApprovedScreensInBothAppearances() throws {
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-test-signed-out", "-ui-test-capture", "-appAppearance", appearance]
            app.launch()
            XCTAssertTrue(app.buttons["authentication-create-account"].waitForExistence(timeout: 10))
            capture("\(appearance)-welcome")
            app.buttons["authentication-create-account"].tap()
            XCTAssertTrue(app.staticTexts["authentication-form-title"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Use at least 15 characters"].exists)
            capture("\(appearance)-create-account")
            app.terminate()
            app.launch()
            app.buttons["authentication-sign-in"].tap()
            XCTAssertTrue(app.staticTexts["authentication-form-title"].waitForExistence(timeout: 5))
            capture("\(appearance)-sign-in")

            app.terminate()
            app.launchArguments = ["-ui-test-authenticated", "-ui-test-capture", "-appAppearance", appearance]
            app.launch()
            XCTAssertTrue(app.tabBars.buttons["Library"].waitForExistence(timeout: 10))
            capture("\(appearance)-map")
            app.tabBars.buttons["Library"].tap()
            XCTAssertTrue(app.buttons["library-route-marie-rose"].waitForExistence(timeout: 8))
            capture("\(appearance)-library")
            app.buttons["library-route-marie-rose"].tap()
            XCTAssertTrue(app.staticTexts["route-detail-name"].waitForExistence(timeout: 8))
            XCTAssertFalse(app.staticTexts["route-detail-location"].exists)
            XCTAssertEqual(app.staticTexts.matching(identifier: "Overhang").count, 1)
            capture("\(appearance)-route")

            app.tabBars.buttons["Profile"].tap()
            XCTAssertTrue(app.staticTexts["profile-name"].waitForExistence(timeout: 5))
            capture("\(appearance)-profile")
            app.buttons["profile-edit"].tap()
            XCTAssertTrue(app.textFields["profile-name-field"].waitForExistence(timeout: 5))
            capture("\(appearance)-edit-profile")
            let nameField = app.textFields["profile-name-field"]
            let originalName = nameField.value as? String ?? ""
            nameField.tap()
            nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalName.count) + "Tobias")
            app.buttons["profile-save"].tap()
            XCTAssertTrue(app.staticTexts["profile-name"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["profile-name"].label, "Tobias")
            app.buttons["profile-edit"].tap()
            XCTAssertTrue(app.textFields["profile-name-field"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.textFields["profile-name-field"].value as? String, "Tobias")
            app.buttons["Cancel"].tap()
            app.buttons["profile-downloads"].tap()
            XCTAssertTrue(app.staticTexts["No downloads"].waitForExistence(timeout: 5))
            capture("\(appearance)-downloads")

            app.tabBars.buttons["Map"].tap()
            app.buttons["map-search-button"].tap()
            let searchField = app.textFields["map-search-field"]
            XCTAssertTrue(searchField.waitForExistence(timeout: 5))
            searchField.tap()
            searchField.typeText("cuvier\n")
            XCTAssertTrue(app.buttons["search-area-cuvier"].waitForExistence(timeout: 5))
            app.buttons["Sheet Grabber"].swipeUp()
            capture("\(appearance)-search")
            XCTAssertFalse(app.staticTexts["Climbing area"].exists)
            app.buttons["search-area-cuvier"].tap()
            XCTAssertTrue(app.buttons["route-link-marie-rose"].waitForExistence(timeout: 8))
            capture("\(appearance)-area")
            app.buttons["route-filter-button"].tap()
            XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
            capture("\(appearance)-filters")
            app.terminate()
        }
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
