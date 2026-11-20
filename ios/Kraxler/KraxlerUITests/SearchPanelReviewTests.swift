import XCTest

final class SearchPanelReviewTests: XCTestCase {
    @MainActor
    func testEdgeToEdgeSearchInBothAppearances() throws {
        continueAfterFailure = false
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-test-authenticated", "-ui-test-capture", "-appAppearance", appearance]
            app.launch()
            XCTAssertTrue(app.buttons["map-search-button"].waitForExistence(timeout: 10))
            app.buttons["map-search-button"].tap()
            let panel = app.otherElements["map-search-panel"].firstMatch
            XCTAssertTrue(panel.waitForExistence(timeout: 8))
            XCTAssertEqual(panel.frame.minX, app.frame.minX, accuracy: 1)
            XCTAssertEqual(panel.frame.maxX, app.frame.maxX, accuracy: 1)
            let search = app.textFields["map-search-field"]
            let close = app.buttons["map-search-close"]
            XCTAssertTrue(search.exists)
            XCTAssertTrue(close.exists)
            XCTAssertGreaterThan(close.frame.minX, search.frame.maxX)
            XCTAssertFalse(app.staticTexts["Search"].exists)
            XCTAssertFalse(app.keyboards.firstMatch.exists)
            capture("\(appearance)-search-idle")

            let handle = app.buttons["Sheet Grabber"].firstMatch
            XCTAssertTrue(handle.exists)
            let collapsedTop = handle.frame.minY
            drag(handle, by: -220)
            XCTAssertLessThan(handle.frame.minY, collapsedTop - 100)
            waitForStablePosition(of: handle)
            drag(handle, by: 220)
            expectation(for: NSPredicate { _, _ in
                abs(handle.frame.minY - collapsedTop) <= 2
            }, evaluatedWith: handle)
            waitForExpectations(timeout: 3)
            close.tap()
            XCTAssertTrue(app.buttons["map-search-button"].waitForExistence(timeout: 5))
            app.buttons["map-search-button"].tap()

            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            search.typeText("cuvier")
            XCTAssertTrue(app.buttons["search-area-cuvier"].waitForExistence(timeout: 8))
            XCTAssertGreaterThan(close.frame.minX, search.frame.maxX)
            XCTAssertFalse(app.staticTexts["Search"].exists)
            capture("\(appearance)-search-typing")
            close.tap()
            XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["map-search-button"].isHittable)

            app.buttons["map-search-button"].tap()
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText("cuvier\n")
            XCTAssertTrue(app.buttons["search-area-cuvier"].waitForExistence(timeout: 8))
            capture("\(appearance)-search-results")
            app.buttons["search-route-marie-rose"].tap()
            XCTAssertTrue(app.staticTexts["route-detail-name"].waitForExistence(timeout: 8))
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.exists)
            back.tap()
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            XCTAssertEqual(search.value as? String, "cuvier")
            search.tap()
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
            XCTAssertTrue(app.buttons["search-area-cuvier"].waitForNonExistence(timeout: 5))
            XCTAssertTrue(close.exists)
            search.typeText("cuvier\n")
            XCTAssertTrue(app.buttons["search-area-cuvier"].waitForExistence(timeout: 8))
            app.buttons["search-area-cuvier"].tap()
            XCTAssertTrue(app.buttons["route-link-marie-rose"].waitForExistence(timeout: 8))
            app.terminate()
        }
    }

    @MainActor
    private func waitForStablePosition(of element: XCUIElement) {
        var previousPosition: CGFloat?
        expectation(for: NSPredicate { _, _ in
            guard element.exists else { return false }
            let position = element.frame.minY
            defer { previousPosition = position }
            guard let previousPosition else { return false }
            return abs(position - previousPosition) < 0.5
        }, evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func drag(_ handle: XCUIElement, by distance: CGFloat) {
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
