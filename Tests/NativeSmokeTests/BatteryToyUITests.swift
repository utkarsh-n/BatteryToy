import XCTest

final class BatteryToyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHologramLayerInspectionAndExplodedView() {
        let app = launchLab()
        XCTAssertTrue(element("battery-hologram", in: app).exists)

        let anode = element("inspect-layer-0", in: app)
        reveal(anode, in: app)
        anode.tap()
        let negativeElectrode = app.staticTexts["NEGATIVE ELECTRODE"]
        reveal(negativeElectrode, in: app)
        XCTAssertTrue(negativeElectrode.exists)

        let separator = element("inspect-layer-1", in: app)
        reveal(separator, in: app, direction: .down)
        separator.tap()
        let separatorDetail = app.staticTexts["Ions move through this region. Electrons take the external circuit."]
        reveal(separatorDetail, in: app)
        XCTAssertTrue(separatorDetail.exists)

        let seeInside = element("see-inside", in: app)
        reveal(seeInside, in: app, direction: .down)
        XCTAssertTrue(seeInside.label.contains("See inside"))
        seeInside.tap()
        XCTAssertTrue(seeInside.label.contains("Assemble"), "Opening the cutaway should expose its reverse action.")
        seeInside.tap()
        XCTAssertTrue(seeInside.label.contains("See inside"))
    }

    @MainActor
    func testPrimaryBatteryRejectsCharging() {
        let app = launchLab()
        element("choose-battery", in: app).tap()
        let alkaline = element("specimen-option-alkaline-aa", in: app)
        reveal(alkaline, in: app)
        alkaline.tap()
        XCTAssertTrue(element("choose-battery", in: app).label.contains("Alkaline AA"))

        let mode = element("operating-mode", in: app)
        reveal(mode, in: app)
        let charge = mode.buttons["Charge"]
        XCTAssertTrue(charge.exists, "Charge should be selected through the operating-mode control.")
        charge.tap()

        let phase = element("phase-readout", in: app)
        reveal(phase, in: app, direction: .down)
        let label = phase.label.uppercased()
        XCTAssertTrue(label.contains("PRIMARY") && label.contains("CHARGE BLOCKED"), label)
        XCTAssertTrue(label.contains("NO CHARGING CURRENT"), "The primary-cell controller must reject the requested charging current.")
    }

    @MainActor
    func testDischargeTimeAdvancesAndUpdatesLiveTrace() {
        let app = launchLab()
        let phase = element("phase-readout", in: app)
        let trace = element("live-trace", in: app)
        reveal(phase, in: app)
        let originalPhase = phase.label
        reveal(trace, in: app)
        let originalTrace = trace.label
        XCTAssertTrue(app.staticTexts["Run or advance time to draw the trace."].exists)

        let advance = element("advance-time", in: app)
        reveal(advance, in: app, direction: .down)
        advance.tap()

        reveal(phase, in: app, direction: .down)
        XCTAssertNotEqual(phase.label, originalPhase)
        XCTAssertTrue(phase.label.contains("10.0 min"), "The 10-minute control must advance simulated time by ten minutes. \(phase.label)")
        XCTAssertFalse(app.staticTexts["Run or advance time to draw the trace."].exists)
        reveal(trace, in: app)
        XCTAssertNotEqual(trace.label, originalTrace, "The plotted terminal voltage must respond to discharge, rather than only updating the clock.")
        XCTAssertTrue(trace.label.contains("Voltage over time"))

        let run = element("run-simulation", in: app)
        reveal(run, in: app, direction: .down)
        run.tap()
        XCTAssertTrue(run.label.contains("Pause"))
        run.tap()
        XCTAssertTrue(run.label.contains("Run"))
    }

    @MainActor
    func testAtlasOpensChemistryExplanation() {
        let app = launchLab()
        selectTab("Atlas", in: app)
        let specimen = element("atlas-specimen-nano-solid-state", in: app)
        reveal(specimen, in: app)
        specimen.tap()

        let chemistry = element("open-chemistry", in: app)
        reveal(chemistry, in: app)
        chemistry.tap()
        XCTAssertTrue(app.navigationBars["Inside the cell"].waitForExistence(timeout: 5))
        let materials = app.staticTexts["THE ACTIVE MATERIALS"]
        reveal(materials, in: app)
        XCTAssertTrue(materials.exists)
        XCTAssertTrue(element("physicsDone", in: app).exists)
    }

    @MainActor
    func testComparisonProducesNormalizedVoltageChart() {
        let app = launchLab()
        selectTab("Compare", in: app)
        let run = element("run-comparison", in: app)
        reveal(run, in: app)
        run.tap()

        let chart = element("comparison-chart", in: app)
        XCTAssertTrue(chart.waitForExistence(timeout: 20), "Completing a comparison must create its voltage chart.")
        reveal(chart, in: app)
        XCTAssertTrue(chart.label.contains("normalized terminal voltage"))
        XCTAssertTrue(app.staticTexts["VOLTAGE UNDER LOAD"].exists)
    }

    @MainActor
    private func launchLab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(element("choose-battery", in: app).waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func selectTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    private enum ScrollDirection { case up, down }

    @MainActor
    private func reveal(_ target: XCUIElement, in app: XCUIApplication, direction: ScrollDirection = .up,
                        maxSwipes: Int = 9, file: StaticString = #filePath, line: UInt = #line) {
        for attempt in 0...maxSwipes {
            if target.exists && target.isHittable {
                let tabBar = app.tabBars.firstMatch
                if !tabBar.exists || target.frame.maxY < tabBar.frame.minY - 8 { return }
            }
            guard attempt < maxSwipes else { break }
            let surface: XCUIElement
            if app.scrollViews.firstMatch.exists {
                surface = app.scrollViews.firstMatch
            } else if app.collectionViews.firstMatch.exists {
                surface = app.collectionViews.firstMatch
            } else if app.tables.firstMatch.exists {
                surface = app.tables.firstMatch
            } else {
                surface = app
            }
            // Swipe in the scroll view's gutter, outside the hologram's drag-to-inspect region.
            let upper = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.28))
            let lower = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.78))
            if direction == .up {
                lower.press(forDuration: 0.05, thenDragTo: upper)
            } else {
                upper.press(forDuration: 0.05, thenDragTo: lower)
            }
        }
        XCTAssertTrue(target.exists && target.isHittable, "Could not reveal \(target.identifier.isEmpty ? target.label : target.identifier).", file: file, line: line)
    }
}
