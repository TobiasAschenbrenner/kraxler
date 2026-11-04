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
        let locationControl = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier IN %@",
                    ["map-user-location-button", "map-location-permission-button"]
                )
            )
            .firstMatch
        XCTAssertTrue(
            locationControl.waitForExistence(timeout: 5),
            "The map should expose either location permission or recentering."
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
