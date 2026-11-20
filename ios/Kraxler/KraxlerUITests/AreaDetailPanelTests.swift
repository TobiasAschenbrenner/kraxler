import XCTest

final class AreaDetailPanelTests: XCTestCase {
    @MainActor
    func testAreaPanelPresentationAndDismissalInBothAppearances() throws {
        continueAfterFailure = false
        for appearance in ["light", "dark"] {
            let app = launchApp(appearance: appearance)
            let searchTop = openCuvierFromSearch(in: app)
            let panel = app.otherElements["area-detail-panel"].firstMatch
            let handle = app.buttons["area-detail-grabber"]
            XCTAssertTrue(panel.waitForExistence(timeout: 8))
            waitForStablePosition(of: handle)
            let collapsedTop = handle.frame.minY
            XCTAssertEqual(collapsedTop, searchTop, accuracy: 3)
            XCTAssertEqual(panel.frame.minX, app.frame.minX, accuracy: 1)
            XCTAssertEqual(panel.frame.maxX, app.frame.maxX, accuracy: 1)

            let filter = app.buttons["route-filter-button"]
            let download = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier IN %@", ["offline-download-button", "offline-download-menu"])
            ).firstMatch
            XCTAssertTrue(download.exists)
            XCTAssertGreaterThan(filter.frame.midY - download.frame.midY, 110)
            XCTAssertGreaterThanOrEqual(app.buttons["route-link-marie-rose"].frame.minY - filter.frame.maxY, 12)
            XCTAssertEqual(app.staticTexts["area-detail-name"].frame.minX,
                app.staticTexts["area-routes-heading"].frame.minX, accuracy: 1)
            capture("\(appearance)-approved-area-card")

            handle.swipeUp()
            waitForStablePosition(of: handle)
            XCTAssertLessThan(handle.frame.minY, collapsedTop - 100)
            XCTAssertEqual(handle.value as? String, "Expanded")
            capture("\(appearance)-approved-area-expanded")
            handle.swipeDown()
            waitForStablePosition(of: handle)
            XCTAssertEqual(handle.frame.minY, collapsedTop, accuracy: 3)
            XCTAssertEqual(handle.value as? String, "Collapsed")
            handle.swipeDown()
            XCTAssertTrue(panel.waitForNonExistence(timeout: 5))

            let pin = app.descendants(matching: .any)["map-area-cuvier"].firstMatch
            XCTAssertTrue(pin.waitForExistence(timeout: 8))
            pin.tap()
            XCTAssertTrue(app.buttons["area-detail-close"].waitForExistence(timeout: 8))
            app.buttons["area-detail-close"].tap()
            XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
            pin.tap()
            XCTAssertTrue(app.buttons["area-detail-close"].waitForExistence(timeout: 8))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)).tap()
            XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["map-search-button"].isHittable)
            app.terminate()
        }
    }

    @MainActor
    func testFilteringAndRouteNavigationInBothAppearances() throws {
        continueAfterFailure = false
        for appearance in ["light", "dark"] {
            let app = launchApp(appearance: appearance)
            _ = openCuvierFromSearch(in: app)
            app.buttons["route-filter-button"].tap()
            XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.progressIndicators["offline-download-progress"].exists)
            let slab = app.switches["Slab"]
            XCTAssertTrue(slab.waitForExistence(timeout: 5))
            let toggle = slab.switches.firstMatch
            if toggle.exists { toggle.tap() } else { slab.tap() }
            app.buttons["Apply"].tap()
            let chip = app.buttons["Remove Slab filter"]
            XCTAssertTrue(chip.waitForExistence(timeout: 8))
            capture("\(appearance)-area-with-filter")
            chip.tap()
            XCTAssertTrue(chip.waitForNonExistence(timeout: 8))

            let handle = app.buttons["area-detail-grabber"]
            handle.swipeUp()
            waitForStablePosition(of: handle)
            app.buttons["route-link-marie-rose"].tap()
            XCTAssertTrue(app.staticTexts["route-detail-name"].waitForExistence(timeout: 8))
            XCTAssertEqual(app.staticTexts["route-detail-name"].label, "La Marie-Rose")
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.isHittable)
            capture("\(appearance)-route-from-area")
            back.tap()
            XCTAssertTrue(app.staticTexts["area-detail-name"].waitForExistence(timeout: 5))
            XCTAssertFalse(chip.exists)
            app.buttons["area-detail-close"].tap()
            XCTAssertTrue(app.otherElements["area-detail-panel"].firstMatch.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["map-search-button"].isHittable)
            app.terminate()
        }
    }

    @MainActor
    private func launchApp(appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-authenticated", "-ui-test-capture", "-appAppearance", appearance]
        app.launch()
        XCTAssertTrue(app.buttons["map-search-button"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func openCuvierFromSearch(in app: XCUIApplication) -> CGFloat {
        app.buttons["map-search-button"].tap()
        let search = app.textFields["map-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let searchTop = app.buttons["Sheet Grabber"].firstMatch.frame.minY
        search.tap()
        search.typeText("cuvier\n")
        XCTAssertTrue(app.buttons["search-area-cuvier"].waitForExistence(timeout: 8))
        app.buttons["search-area-cuvier"].tap()
        XCTAssertTrue(app.buttons["route-link-marie-rose"].waitForExistence(timeout: 8))
        return searchTop
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
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
