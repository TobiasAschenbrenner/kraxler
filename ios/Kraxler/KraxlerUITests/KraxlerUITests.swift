//
//  KraxlerUITests.swift
//  KraxlerUITests
//
//  Created by Tobias Aschenbrenner on 29.10.26.
//

import XCTest

final class KraxlerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMapLoadsAreasFromAPI() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Kraxler"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2 climbing areas in view"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)["map-user-location-button"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testPresentsRouteDetails() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-route-detail")
        app.launch()

        XCTAssertTrue(
            app.staticTexts["route-detail-name"].waitForExistence(timeout: 5)
        )
        XCTAssertEqual(app.staticTexts["route-detail-name"].label, "La Marie Rose")
        XCTAssertEqual(app.staticTexts["route-detail-grade"].label, "6A")
        XCTAssertEqual(
            app.staticTexts["route-detail-discipline"].label,
            "Bouldering"
        )
        XCTAssertTrue(app.staticTexts["route-detail-description"].exists)
        XCTAssertTrue(app.staticTexts["route-detail-location"].exists)
    }
}
