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
        XCTAssertTrue(app.staticTexts["6 climbing areas in view"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)["map-user-location-button"]
                .waitForExistence(timeout: 5)
        )
    }
}
