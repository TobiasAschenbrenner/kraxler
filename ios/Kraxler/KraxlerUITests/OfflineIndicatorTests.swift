import XCTest

final class OfflineIndicatorTests: XCTestCase {
    @MainActor
    func testDelayedIndicatorDownloadedRoutesAndRecoveryInBothAppearances() {
        continueAfterFailure = false
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-ui-test-authenticated", "-ui-test-capture", "-ui-test-offline", "-appAppearance",
                appearance,
            ]
            app.launch()
            XCTAssertTrue(app.buttons["map-search-button"].waitForExistence(timeout: 10))
            let indicator = app.descendants(matching: .any)["map-offline-indicator"].firstMatch
            XCTAssertFalse(indicator.exists, "Brief interruptions must stay quiet")
            XCTAssertFalse(app.staticTexts["Areas unavailable"].exists)
            XCTAssertTrue(indicator.waitForExistence(timeout: 12))
            let tabs = app.tabBars.firstMatch
            XCTAssertLessThanOrEqual(indicator.frame.maxY, tabs.frame.minY)
            XCTAssertLessThan(tabs.frame.minY - indicator.frame.maxY, 35)
            XCTAssertLessThan(indicator.frame.height, 32)
            XCTAssertFalse(app.staticTexts["Areas unavailable"].exists)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "\(appearance)-compact-offline-indicator"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            app.buttons["map-search-button"].tap()
            let search = app.textFields["map-search-field"]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText("cuvier\n")
            let area = app.buttons["search-area-cuvier"]
            XCTAssertTrue(area.waitForExistence(timeout: 5))
            area.tap()
            let route = app.buttons["route-link-marie-rose"]
            XCTAssertTrue(route.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["offline-routes-indicator"].waitForExistence(timeout: 3))
            route.tap()
            XCTAssertTrue(app.staticTexts["route-detail-name"].waitForExistence(timeout: 5))
            let localImage = app.images.matching(
                NSPredicate(format: "value == %@", "Available offline")
            ).firstMatch
            for _ in 0..<3 {
                if localImage.exists && localImage.isHittable { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(localImage.waitForExistence(timeout: 5))
            XCTAssertTrue(localImage.isHittable)
            XCTAssertFalse(app.staticTexts["Topo unavailable"].exists)
            let photo = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            photo.name = "\(appearance)-downloaded-topo-from-disk"
            photo.lifetime = .keepAlways
            add(photo)
            let cardBack = app.buttons["area-route-back"]
            if cardBack.exists {
                cardBack.tap()
            } else {
                app.navigationBars.buttons.firstMatch.tap()
            }
            app.buttons["area-detail-close"].tap()
            XCTAssertTrue(indicator.waitForNonExistence(timeout: 25))
            XCTAssertFalse(app.staticTexts["Areas unavailable"].exists)
            app.terminate()
        }
    }
}
