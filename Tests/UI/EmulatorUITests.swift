import XCTest
import UIKit
import StoreKitTest

final class EmulatorUITests: XCTestCase {
    @MainActor func testLiveQuickSaveBannerForAllConsoles() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        for (platform,flag) in [("ps1","--boot-ps1-demo"),("gamecube","--boot-gamecube-demo"),("3ds","--boot-homebrew")] {
            let app = XCUIApplication()
            app.launchArguments = [flag,"--gamecube-qa-status","--fresh-start","--save-feedback-test","--controller-preview","-onlineArtworkEnabled","NO","-automaticResumeSaves","NO"]
            launchPrepared(app)
            if platform == "ps1" { assertPS1Pixels(app) } else if platform == "gamecube" { assertGameCubePixels(app) } else { assertGamePixels(app) }
            openGameMenu(app)
            app.buttons["Quick Save"].tap()
            let banner = app.descendants(matching: .any)["saveBanner"].firstMatch
            XCTAssertTrue(banner.waitForExistence(timeout: 10))
            XCTAssertFalse(app.staticTexts["Updating save state…"].exists)
            XCTAssertTrue(app.buttons["Pause"].exists, "Save must leave the live session unpaused")
            XCTAssertLessThan(banner.frame.height, 70)
            let top = app.descendants(matching: .any)["topScreen"].firstMatch
            let frames = Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0) > frames
            }, object: nil)], timeout: 4), .completed, "Frames must continue while the detached save writes")
            attach(app, "\(platform) compact live-save banner")
            XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 40))
            XCTAssertFalse(app.staticTexts["Paused"].exists)
            openGameMenu(app); app.buttons["Quick Load"].tap()
            XCTAssertTrue(app.staticTexts["Quick save loaded"].waitForExistence(timeout: 40))
            XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5)); app.buttons["Pause"].tap()
            openGameMenu(app); app.buttons["Quick Save"].tap()
            XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 40))
            XCTAssertTrue(app.buttons["Resume"].exists, "Save completion must preserve an already paused session")
            XCTAssertFalse(app.buttons["Pause"].exists)
            app.buttons["Resume"].tap()
            returnToLibrary(app); app.terminate()
        }
    }
    @MainActor func testRenameAndNoBlanketAgeLabelsSurviveRelaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["-favoriteConsole","gamecube","-importedGameAccess","under18","-onlineArtworkEnabled","NO"]
        launchPrepared(app)
        app.buttons["consoleCollection"].tap()
        let original = app.buttons["Select QA Sonic Riders.nkit"]
        XCTAssertTrue(original.waitForExistence(timeout: 20)); original.press(forDuration: 1)
        XCTAssertFalse(app.staticTexts["Age rating: Unrated · Adult access required"].exists)
        app.buttons["renameGame"].tap()
        // UIKit's alert text field retains its placeholder but drops the SwiftUI identifier.
        let field = app.alerts["Rename game"].textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // The alert already focuses the field at the end. Tapping its middle moves
        // the caret; UIKit's editing menu also triggers XCTest's alert interrupter.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count))
        XCTAssertTrue(["", "Game name"].contains(field.value as? String ?? ""))
        field.typeText("Sonic Riders (My favorite)")
        app.buttons["confirmRenameGame"].firstMatch.tap()
        let renamed = app.buttons["Select Sonic Riders (My favorite)"]
        XCTAssertTrue(renamed.waitForExistence(timeout: 10)); renamed.tap()
        XCTAssertTrue(app.staticTexts["selectedGameTitle"].label.contains("Sonic Riders (My favorite)"))
        attach(app, "Custom game name retains punctuation without rating labels")
        app.terminate(); launchPrepared(app); app.buttons["consoleCollection"].tap()
        XCTAssertTrue(renamed.waitForExistence(timeout: 20))
        app.buttons["System setup"].tap()
        XCTAssertFalse(app.buttons["importedGameAccess"].exists)
        XCTAssertFalse(app.staticTexts["Unrated imports require adult confirmation"].exists)
        attach(app, "Rename persists; old age preference does not restore the removed box")
    }
    @MainActor func testGameCubeFoldedControllerQuickPanelAndBlankPersistence() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo", "--gamecube-qa-status", "--fresh-start", "--controller-preview", "--duo-tabletop-preview", "-gameCubeFolded", "YES", "-gameCubePanelBlank", "NO", "-gameCubePanelFPS", "YES", "-gameCubePanelSaves", "YES", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGameCubePixels(app)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        setSwitch(app.switches["customizeGame"], on: false, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        let panel = app.descendants(matching: .any)["gameCubeQuickPanel"].firstMatch, top = app.otherElements["topScreen"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(top.frame.maxY, panel.frame.minY)
        XCTAssertTrue(app.descendants(matching: .any)["gameCubePanelFrameRate"].firstMatch.exists)
        XCTAssertFalse(app.buttons["control-0"].exists)
        XCTAssertFalse(app.buttons["ps1Speed-1.5"].exists)
        app.buttons["gameCubePanelSave"].tap()
        let load = app.buttons["gameCubePanelLoad"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: load)], timeout: 45), .completed)
        load.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "Snapshot counter restored"), object: top)], timeout: 45), .completed)
        attach(app, "GameCube folded native video with controller FPS and working Quick Save Load")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height && top.frame.maxY <= panel.frame.minY
        }, object: nil)], timeout: 15), .completed)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        setSwitch(app.switches["customizeGame"], on: true, in: app)
        app.segmentedControls["graphicsCategory"].buttons["Controls"].tap()
        setSwitch(app.switches["gameCubePanelBlank"], on: true, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        XCTAssertFalse(load.exists); XCTAssertFalse(app.buttons["gameCubePanelSave"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["gameCubePanelFrameRate"].firstMatch.exists)
        XCTAssertLessThanOrEqual(top.frame.maxY, panel.frame.minY)
        attach(app, "GameCube lower panel during menu transition")
        let blank = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let black = self.meanColor(app, in: panel.frame.insetBy(dx: 20, dy: 20))
            return max(black.0, black.1, black.2) < 10
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [blank], timeout: 8), .completed, "Blank lower panel after the menu transition: app \(app.frame), panel \(panel.frame)")
        attach(app, "GameCube folded blank lower panel after transition settles")
        returnToLibrary(app); app.terminate(); XCUIDevice.shared.orientation = .portrait
        launchPrepared(app); assertGameCubePixels(app)
        XCTAssertTrue(panel.exists); XCTAssertFalse(load.exists)
        XCTAssertLessThanOrEqual(top.frame.maxY, panel.frame.minY)
        attach(app, "GameCube blank panel preference survives relaunch")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        setSwitch(app.switches["customizeGame"], on: false, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        returnToLibrary(app)
    }
    @MainActor func testGameCubeFoldedTouchExcursionAndEditableLayout() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo", "--gamecube-qa-status", "--fresh-start", "--touch-controls-preview", "--duo-tabletop-preview", "--touch-excursion-test", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGameCubePixels(app)
        let panel = app.descendants(matching: .any)["gameCubeQuickPanel"].firstMatch, top = app.otherElements["topScreen"]
        let left = app.descendants(matching: .any)["leftAnalogStick"].firstMatch, right = app.descendants(matching: .any)["rightAnalogStick"].firstMatch
        XCTAssertTrue(left.waitForExistence(timeout: 10), app.debugDescription); XCTAssertTrue(right.exists)
        let panelFrame = panel.frame, startFrame = app.buttons["control-3"].frame
        for stick in [left, right] {
            let from = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let to = stick.coordinate(withNormalizedOffset: CGVector(dx: -0.7, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 1.5)
        }
        XCTAssertEqual(panel.frame, panelFrame); XCTAssertEqual(app.buttons["control-3"].frame, startFrame, "Stick excursion must never scroll the panel")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@ AND value CONTAINS %@", "Touch SI 3", "Center true"), object: top)], timeout: 20), .completed)
        app.buttons["control-0"].press(forDuration: 1.5)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "A press/release verified"), object: top)], timeout: 20), .completed)
        XCTAssertGreaterThan(app.buttons["control-0"].frame.width, app.buttons["control-8"].frame.width * 1.4)
        let face = app.buttons["control-0"].frame.insetBy(dx: 1, dy: 1)
        for id in ["1", "8", "9"] { XCTAssertFalse(face.intersects(app.buttons["control-" + id].frame.insetBy(dx: 1, dy: 1)), "A must not overlap another face-button target") }
        attach(app, "Fixed folded GameCube controls, colored proportions and native SI excursion/release")
        let original = app.buttons["control-0"].frame
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["customizeTouchControls"].tap()
        let movable = app.descendants(matching: .any)["move-0"].firstMatch
        XCTAssertTrue(movable.waitForExistence(timeout: 10))
        movable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: movable.coordinate(withNormalizedOffset: CGVector(dx: -0.3, dy: 0.4)))
        let moved = movable.frame
        XCTAssertLessThan(moved.midX, original.midX - 30)
        app.buttons["finishTouchLayout"].tap()
        XCTAssertEqual(app.buttons["control-0"].frame.midX, moved.midX, accuracy: 2)
        returnToLibrary(app); app.terminate(); launchPrepared(app); assertGameCubePixels(app)
        XCTAssertEqual(app.buttons["control-0"].frame.midX, moved.midX, accuracy: 2, "Layout survives player and app relaunch")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["customizeTouchControls"].tap()
        app.buttons["resetTouchLayout"].tap(); app.buttons["finishTouchLayout"].tap()
        XCTAssertEqual(app.buttons["control-0"].frame.midX, original.midX, accuracy: 2)
        attach(app, "Persisted per-console folded layout with Reset and Done")
        returnToLibrary(app)
    }
    @MainActor func testPlayStationDualAnalogTouchAndRelease() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--touch-controls-preview", "--duo-tabletop-preview", "--ps1-analog-test", "-ps1Analog", "YES", "-ps1PanelSpeed", "NO", "-ps1PanelFPS", "NO", "-ps1PanelSaves", "NO", "-ps1PanelTouch", "YES", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertPS1Pixels(app)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        setSwitch(app.switches["customizeGame"], on: true, in: app)
        app.segmentedControls["graphicsCategory"].buttons["Controls"].tap()
        setSwitch(app.switches["ps1Folded"], on: true, in: app)
        setSwitch(app.switches["ps1PanelTouch"], on: true, in: app)
        setSwitch(app.switches["ps1Analog"], on: true, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        let top = app.images["topScreen"]
        let left = app.descendants(matching: .any)["leftAnalogStick"].firstMatch, right = app.descendants(matching: .any)["rightAnalogStick"].firstMatch
        XCTAssertTrue(left.waitForExistence(timeout: 10), app.debugDescription); XCTAssertTrue(right.exists)
        for stick in [left, right] {
            stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: stick.coordinate(withNormalizedOffset: CGVector(dx: -0.6, dy: -0.6)), withVelocity: .slow, thenHoldForDuration: 1)
        }
        let released = NSPredicate(format: "value CONTAINS %@", "PS1 axes L(0,0) R(0,0) seen=15 excursion=15 mode=1")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: released, object: top)], timeout: 15), .completed, "Actual core must poll both sticks and receive neutral after touch-up: \(top.value ?? "missing")")
        app.buttons["control-0"].press(forDuration: 1)
        attach(app, "PlayStation dual analog touch controls and actual libretro polls")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        app.segmentedControls["graphicsCategory"].buttons["Controls"].tap()
        setSwitch(app.switches["customizeGame"], on: true, in: app)
        setSwitch(app.switches["ps1Analog"], on: false, in: app)
        setSwitch(app.switches["ps1PanelTouch"], on: false, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "mode=0"), object: top)], timeout: 15), .completed)
        XCTAssertFalse(left.exists)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["customizeTouchControls"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["move-stick"].firstMatch.waitForExistence(timeout: 10), "Editing must reveal controls even when the folded panel normally hides them")
        app.buttons["finishTouchLayout"].tap()
        XCTAssertFalse(left.exists, "Done restores the hidden-touch preference")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        app.segmentedControls["graphicsCategory"].buttons["Controls"].tap()
        setSwitch(app.switches["ps1PanelTouch"], on: true, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        returnToLibrary(app)
    }
    @MainActor func testSettingsOrganizationGameCubeBackgroundAndDeleteConfirmation() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["-favoriteConsole", "gamecube", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); XCTAssertTrue(app.buttons["headerConsolePicker"].waitForExistence(timeout: 25))
        waitForConsole("GameCube", in: app)
        attach(app, "GameCube default console background")
        app.buttons["System setup"].tap()
        XCTAssertTrue(app.staticTexts["Graphics & display"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Controls & Duo"].exists)
        app.buttons["advancedPlayerSettings"].tap()
        XCTAssertTrue(app.staticTexts["Graphics settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["GameCube graphics"].exists)
        app.buttons["playerSettingsDone"].tap()
        attach(app, "Organized bento settings with console-specific Graphics settings")
        app.buttons["consoleCollection"].tap()
        let fixture = app.buttons["Select QA Delete Only"]
        reveal(fixture, in: app); XCTAssertTrue(fixture.exists)
        fixture.press(forDuration: 1); app.buttons["deleteGame"].tap()
        XCTAssertTrue(app.buttons["confirmDeleteGame"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap(); XCTAssertTrue(fixture.exists)
        fixture.press(forDuration: 1); app.buttons["deleteGame"].tap(); app.buttons["confirmDeleteGame"].firstMatch.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: fixture)], timeout: 10), .completed)
        XCTAssertTrue(app.buttons["Select QA GC Alpha"].exists)
        attach(app, "Confirmed deletion of a disposable original fixture, other games retained")
    }
    @MainActor func testThreeDSFreelyMovableTouchControls() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["--input-test", "--touch-controls-preview"]
        launchPrepared(app)
        let a = app.buttons["control-8"]
        XCTAssertTrue(a.waitForExistence(timeout: 20))
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["customizeTouchControls"].tap()
        app.buttons["resetTouchLayout"].tap(); app.buttons["finishTouchLayout"].tap()
        let original = a.frame
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["customizeTouchControls"].tap()
        let movable = app.descendants(matching: .any)["move-8"].firstMatch
        XCTAssertTrue(movable.waitForExistence(timeout: 10))
        movable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: movable.coordinate(withNormalizedOffset: CGVector(dx: -0.8, dy: -0.3)))
        let moved = movable.frame
        app.buttons["finishTouchLayout"].tap()
        XCTAssertLessThan(a.frame.midX, original.midX - 30)
        a.tap(); XCTAssertTrue(app.staticTexts["A pressed"].exists)
        app.terminate(); launchPrepared(app)
        XCTAssertTrue(a.waitForExistence(timeout: 20)); XCTAssertEqual(a.frame.midX, moved.midX, accuracy: 2)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(a.exists)
        XCUIDevice.shared.orientation = .portrait
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.height > app.frame.width && app.frame.contains(a.frame) && abs(a.frame.midX - moved.midX) <= 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed, "Rotation must settle inside the display at the saved portrait position")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["customizeTouchControls"].tap()
        app.buttons["resetTouchLayout"].tap(); app.buttons["finishTouchLayout"].tap()
        XCTAssertEqual(a.frame.midX, original.midX, accuracy: 2)
        attach(app, "3DS independently movable controls, orientation isolation and persisted Reset")
        returnToLibrary(app)
    }
    @MainActor func testConsoleNavigationFavoriteAndLibraryFilters() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); launchPrepared(app)
        let header = app.buttons["headerConsolePicker"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: header)], timeout: 60), .completed)
        header.tap(); app.buttons["header-system-ps1"].tap()
        waitForConsole("PlayStation", in: app)
        app.buttons["consoleCollection"].tap()
        let grid = app.scrollViews["gameCollection"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Select QA PS1 Alpha"].exists)
        XCTAssertFalse(app.buttons["Select QA GC Alpha"].exists)
        app.buttons["librarySort"].tap(); app.buttons["A–Z"].tap()
        XCTAssertEqual(app.buttons["librarySort"].value as? String, "A–Z")
        let sorted = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Select QA PS1'")).allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(sorted, ["Select QA PS1 Alpha", "Select QA PS1 Zulu"])
        app.buttons["consoleFilter"].tap(); app.buttons["system-gamecube"].tap()
        XCTAssertTrue(grid.exists, "Console filtering must stay on the Library tab")
        XCTAssertTrue(app.buttons["Select QA GC Alpha"].exists)
        XCTAssertFalse(app.buttons["Select QA PS1 Alpha"].exists)
        app.buttons["librarySort"].tap(); app.buttons["Recently added"].tap()
        let recent = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Select QA GC'")).allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(recent, ["Select QA GC Zulu", "Select QA GC Alpha"])
        attach(app, "Console-filtered GameCube library and persistent sort menu")
        app.buttons["System setup"].tap()
        app.buttons["favoriteConsole"].tap(); app.buttons["PlayStation"].firstMatch.tap()
        app.buttons["consoleHome"].tap()
        waitForConsole("PlayStation", in: app)
        app.terminate(); launchPrepared(app)
        XCTAssertTrue(header.waitForExistence(timeout: 20))
        waitForConsole("PlayStation", in: app)
        header.tap(); app.buttons["header-system-gamecube"].tap()
        waitForConsole("GameCube", in: app)
        app.buttons["consoleHome"].tap()
        waitForConsole("PlayStation", in: app)
        app.buttons["System setup"].tap()
        app.buttons["favoriteConsole"].tap(); app.buttons["Nintendo 3DS"].firstMatch.tap()
        app.buttons["consoleHome"].tap()
        waitForConsole("Nintendo 3DS", in: app)
        attach(app, "Header console switcher and favorite Home destination")
    }
    @MainActor private func waitForConsole(_ name: String, in app: XCUIApplication) {
        let header = app.buttons["headerConsolePicker"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", name), object: header)], timeout: 10), .completed, "Selected console should be \(name); actual \(header.value ?? "missing")")
    }
    @MainActor func testConsoleSpecificControllerConnections() {
        continueAfterFailure = false
        let app = XCUIApplication(); launchPrepared(app)
        for (console, name) in [("ps1", "PlayStation"), ("gamecube", "GameCube"), ("3ds", "Nintendo 3DS")] {
            let header = app.buttons["headerConsolePicker"]
            XCTAssertTrue(header.waitForExistence(timeout: 20))
            header.tap(); app.buttons["header-system-\(console)"].tap()
            app.buttons["Controller layout"].tap()
            let preview = app.descendants(matching: .any)["openingConsolePreview"].firstMatch
            XCTAssertTrue(preview.waitForExistence(timeout: 5))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Open'"), object: preview)], timeout: 5), .completed)
            if console == "3ds" { XCTAssertTrue(app.buttons["Console skin"].exists) }
            else {
                XCTAssertTrue(preview.label.contains(name)); XCTAssertFalse(app.buttons["Console skin"].exists)
                let start = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                start.press(forDuration: 0.1, thenDragTo: preview.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.72)))
            }
            attach(app, "\(name) native responsive controller presentation")
            if console != "3ds" {
                XCUIDevice.shared.orientation = .landscapeLeft
                XCTAssertLessThanOrEqual(preview.frame.maxX, app.frame.maxX + 1)
                attach(app, "\(name) controller presentation in landscape")
                XCUIDevice.shared.orientation = .portrait
            }
            reveal(app.buttons["replayControllerAnimation"], in: app); app.buttons["replayControllerAnimation"].tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Open'"), object: preview)], timeout: 5), .completed)
            reveal(app.buttons["duoLayoutDone"], in: app); app.buttons["duoLayoutDone"].tap()
        }
    }
    @MainActor func testGameCubeGraphicsChangeActualEFBAndReturnToNative() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-gx-card", "--gamecube-qa-status", "--fresh-start", "--controller-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app)
        let top = app.otherElements["topScreen"]
        XCTAssertTrue(top.waitForExistence(timeout: 90))
        for (scale, width, height) in [(2,1280,1056), (4,2560,2112), (1,640,528)] {
            openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
            setSwitch(app.switches["customizeGame"], on: true, in: app)
            let resolution = app.segmentedControls["gameCubeResolution"]
            reveal(resolution, in: app); resolution.buttons[scale == 1 ? "1× · Native" : "\(scale)×"].tap()
            if scale == 2 {
                app.buttons["gameCubeSampling"].tap(); app.buttons["Smooth"].tap()
                app.buttons["gameCubeAnisotropy"].tap(); app.buttons["16×"].tap()
            }
            if scale == 1 {
                app.buttons["gameCubeSampling"].tap(); app.buttons["Game default"].tap()
                app.buttons["gameCubeAnisotropy"].tap(); app.buttons["Game default"].tap()
            }
            app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
            let expected = "GFX \(scale)x \(width)×\(height) filter\(scale == 1 ? 0 : 2) AF\(scale == 1 ? -1 : 4)"
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", expected), object: top)], timeout: 45), .completed, "Actual Metal EFB and config should change: \(top.value ?? "missing")")
            attach(app, "GameCube actual \(scale)x EFB with original GX geometry")
        }
        returnToLibrary(app)
    }
    @MainActor func testGameCubeGXDepthAndNativeCardRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-gx-card","--gamecube-qa-status","--fresh-start","--controller-preview","-onlineArtworkEnabled","NO"]
        launchPrepared(app)
        let top = app.otherElements["topScreen"]
        XCTAssertTrue(top.waitForExistence(timeout:90))
        let colored = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let center = self.meanColor(app,in: CGRect(x:top.frame.midX-12,y:top.frame.midY-12,width:24,height:24))
            return center.0 > 120 && center.0 > center.2*2
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[colored],timeout:90),.completed,"GX near triangle must occlude the later far triangle")
        let blue = meanColor(app,in:CGRect(x:top.frame.minX+top.frame.width*0.175-4,y:top.frame.minY+top.frame.height*0.75-4,width:8,height:8))
        XCTAssertGreaterThan(blue.2,blue.0*1.5,"Far blue geometry remains visible outside the red near triangle")
        attach(app,"Original guest GX geometry and native memory-card write")
        returnToLibrary(app); app.terminate(); launchPrepared(app)
        XCTAssertTrue(top.waitForExistence(timeout:90))
        let persisted = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value CONTAINS %@","Native card 454d4338"),object:top)
        XCTAssertEqual(XCTWaiter.wait(for:[persisted],timeout:60),.completed,"Guest reads its own native raw-card marker after core teardown/relaunch")
        attach(app,"Original guest native memory-card marker read after relaunch")
        returnToLibrary(app)
    }
    @MainActor private func meanColor(_ app:XCUIApplication,in frame:CGRect) -> (Double,Double,Double) {
        let captured = XCUIScreen.main.screenshot().image
        // Draw through UIKit so landscape UIImage orientation matches accessibility coordinates.
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let screenshot = UIGraphicsImageRenderer(size: captured.size, format: format).image { _ in captured.draw(at: .zero) }
        guard let cg = screenshot.cgImage else { return (0,0,0) }
        let display = app.frame
        let sx = CGFloat(cg.width)/display.width, sy = CGFloat(cg.height)/display.height
        guard let crop = cg.cropping(to:CGRect(x:frame.minX*sx,y:frame.minY*sy,width:frame.width*sx,height:frame.height*sy)) else { return (0,0,0) }
        var pixel=[UInt8](repeating:0,count:4)
        pixel.withUnsafeMutableBytes { memory in
            let context=CGContext(data:memory.baseAddress,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.draw(crop,in:CGRect(x:0,y:0,width:1,height:1))
        }
        return (Double(pixel[0]),Double(pixel[1]),Double(pixel[2]))
    }
    @MainActor func testGameCubeBothSticksAnalogTriggersAndDisconnect() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo","--gamecube-qa-status","--gamecube-controller-test","--fresh-start","-onlineArtworkEnabled","NO"]
        launchPrepared(app); assertGameCubePixels(app)
        let top = app.otherElements["topScreen"]
        let input = XCTNSPredicateExpectation(predicate: NSPredicate(format:"value CONTAINS %@","GameCube full input passed"),object:top)
        XCTAssertEqual(XCTWaiter.wait(for:[input],timeout:60),.completed,"\(top.value ?? "No native status")")
        XCTAssertFalse(app.buttons["A"].exists)
        attach(app,"Real GameCube SI main/C-stick, partial/full triggers, clamping, pause and controller disconnect")
        returnToLibrary(app)
    }
    @MainActor func testGameCubeSettingsUseSingleScreenOptions() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo","--gamecube-qa-status","--fresh-start","--touch-controls-preview","-onlineArtworkEnabled","NO"]
        launchPrepared(app); assertGameCubePixels(app)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        XCTAssertTrue(app.scrollViews["playerSettingsScroll"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["prepareShaders"].exists)
        XCTAssertFalse(app.switches["motionControls"].exists)
        XCTAssertFalse(app.segmentedControls["ps1Resolution"].exists)
        XCTAssertFalse(app.sliders["screenBalance"].exists)
        XCTAssertTrue(app.staticTexts["GameCube graphics"].exists)
        attach(app,"GameCube single-screen settings without3DS shader or dual-screen options")
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        returnToLibrary(app)
    }
    @MainActor func testThreeDSCoreRequestsMotionAndPauseStopsInput() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-homebrew", "--fresh-start", "--motion-interface-test", "--controller-preview", "-motionControls", "YES", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGamePixels(app)
        let top = app.images["topScreen"]
        let requested = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "MotionQA 3"), object: top)
        XCTAssertEqual(XCTWaiter.wait(for: [requested], timeout: 15), .completed)
        showPlayerHeader(app); app.buttons["Pause"].tap()
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "MotionQA 1"), object: top)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 10), .completed)
        app.buttons["Resume"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "MotionQA 3"), object: top)], timeout: 10), .completed)
        attach(app, "Real3DS core requests both motion sensors; pause and resume gate input")
        returnToLibrary(app)
    }
    @MainActor func testPlayStationEnhancedResolutionAndLiveReturnToNative() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--controller-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertPS1Pixels(app)
        let top = app.images["topScreen"]
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        setSwitch(app.switches["customizeGame"], on: true, in: app)
        let resolution = app.segmentedControls["ps1Resolution"]
        reveal(resolution, in: app); resolution.buttons["1× · Original"].tap()
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "Video 320x240"), object: top)], timeout: 25), .completed, "Establish native through UI even if a previous QA run left an enhanced per-game profile")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        reveal(resolution, in: app); resolution.buttons["2× · Enhanced"].tap()
        setSwitch(app.switches["ps1Smooth"], on: true, in: app)
        setSwitch(app.switches["ps1Dithering"], on: false, in: app)
        setSwitch(app.switches["ps1TextureFix"], on: false, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        let enhanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "Video 640x480"), object: top)
        XCTAssertEqual(XCTWaiter.wait(for: [enhanced], timeout: 25), .completed)
        attach(app, "PS1 actual 2x internal framebuffer")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        XCTAssertEqual(app.switches["ps1Smooth"].value as? String, "1")
        XCTAssertEqual(app.switches["ps1Dithering"].value as? String, "0")
        setSwitch(app.switches["ps1Smooth"], on: false, in: app)
        setSwitch(app.switches["ps1Dithering"], on: true, in: app)
        setSwitch(app.switches["ps1TextureFix"], on: true, in: app)
        reveal(resolution, in: app); resolution.buttons["1× · Original"].tap()
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        let native = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "Video 320x240"), object: top)
        XCTAssertEqual(XCTWaiter.wait(for: [native], timeout: 25), .completed)
        returnToLibrary(app)
    }
    @MainActor func testPlayStationFoldedQuickPanelSpeedAndBlankOptions() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--duo-tabletop-preview", "--controller-preview", "-ps1Resolution", "1", "-ps1Folded", "YES", "-ps1PanelSpeed", "YES", "-ps1PanelFPS", "YES", "-ps1PanelSaves", "YES", "-ps1PanelTouch", "YES", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertPS1Pixels(app)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        setSwitch(app.switches["customizeGame"], on: false, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        let top = app.images["topScreen"], panel = app.descendants(matching: .any)["ps1QuickPanel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(top.frame.maxY, panel.frame.minY)
        XCTAssertFalse(app.buttons["Cross"].exists)
        let speeds = app.descendants(matching: .any)["ps1PlaybackSpeed"].firstMatch
        for (speed, minimum) in [(1.5, 75), (2.0, 100), (1.0, 45)] {
            let button = app.buttons["ps1Speed-\(speed)"]
            XCTAssertTrue(button.isHittable); button.tap()
            let paced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let value = top.value as? String ?? ""
                guard let range = value.range(of: "Core FPS ") else { return false }
                let fps = Int(value[range.upperBound...].split(separator: " ").first ?? "0") ?? 0
                return fps >= minimum && (speed != 1 || fps < 75)
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [paced], timeout: 20), .completed, "Actual core pacing at \(speed)×: \(top.value ?? "missing value")")
        }
        attach(app, "PS1 folded video and quick controls with controller")
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height && top.frame.maxY <= panel.frame.minY
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 15), .completed,
                       "Rotation frames: app=\(app.frame), top=\(top.frame), panel=\(panel.frame)")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        setSwitch(app.switches["customizeGame"], on: true, in: app)
        app.segmentedControls["graphicsCategory"].buttons["Controls"].tap()
        for key in ["ps1PanelSpeed", "ps1PanelFPS", "ps1PanelSaves", "ps1PanelTouch"] {
            setSwitch(app.switches[key], on: false, in: app)
        }
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        XCTAssertTrue(app.buttons["ps1Speed-1.5"].waitForNonExistence(timeout: 8), "Wait for the folded panel and menu dismissal to settle")
        XCTAssertFalse(app.buttons["ps1Speed-1.5"].exists)
        XCTAssertFalse(app.buttons["ps1PanelSave"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["ps1PanelFrameRate"].firstMatch.exists)
        XCTAssertLessThanOrEqual(top.frame.maxY, panel.frame.minY)
        attach(app, "PS1 folded blank lower panel in landscape")
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
        launchPrepared(app); assertPS1Pixels(app)
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        XCTAssertFalse(speeds.exists); XCTAssertFalse(app.buttons["ps1PanelSave"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["ps1PanelFrameRate"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Cross"].exists)
        attach(app, "PS1 folded blank lower panel")
        returnToLibrary(app)
    }
    @MainActor func testLibraryPostersKeepPortraitProportionsInBothOrientations() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-onlineArtworkEnabled", "NO"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        launchPrepared(app)
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (app.frame.width > app.frame.height) == (orientation == .landscapeLeft)
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed)
            let tile = app.buttons["selectedGameTile"]
            XCTAssertTrue(tile.waitForExistence(timeout: 15))
            if orientation == .landscapeLeft { app.swipeUp() }
            let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let display = app.frame, frame = tile.frame
                return abs(frame.width / frame.height - 0.71) < 0.025 &&
                    frame.intersection(display).height >= frame.height - 2
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 10), .completed,
                           "Cover frame=\(tile.frame), display=\(app.frame)")
            attach(app, "Portrait game covers in \(orientation == .portrait ? "portrait" : "landscape")")
        }
    }
    @MainActor func testGameCubeOriginalDiscImportBootAndState() {
        checkGameCubeDiscImport("--boot-gamecube-disc")
    }
    @MainActor func testGameCubeGCMImportBootAndState() {
        checkGameCubeDiscImport("--boot-gamecube-gcm")
    }
    @MainActor private func checkGameCubeDiscImport(_ argument: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [argument, "--gamecube-qa-status", "--fresh-start", "--touch-controls-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGameCubePixels(app)
        let audio = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "Audio PCM verified"), object: app.otherElements["topScreen"])
        XCTAssertEqual(XCTWaiter.wait(for: [audio], timeout: 30), .completed)
        app.buttons["control-0"].press(forDuration: 2.2)
        let top = app.otherElements["topScreen"]
        let input = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (top.value as? String ?? "").contains("A press/release verified")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [input], timeout: 15), .completed)
        openGameMenu(app); app.buttons["Quick Save"].tap()
        XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 35))
        openGameMenu(app); app.buttons["Quick Load"].tap()
        XCTAssertTrue(app.staticTexts["Quick save loaded"].waitForExistence(timeout: 35))
        XCTAssertTrue((top.value as? String ?? "").contains("Snapshot counter restored"))
        attach(app, "Original GameCube disc imported and booted with state restore")
        returnToLibrary(app)
    }
    @MainActor func testGameCubeHomebrewInputStateHistoryAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo", "--gamecube-qa-status", "--fresh-start", "--touch-controls-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGameCubePixels(app)
        app.buttons["control-0"].press(forDuration: 2.2)
        let top = app.otherElements["topScreen"]
        let input = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (top.value as? String ?? "").contains("A press/release verified")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [input], timeout: 15), .completed)
        attach(app, "GameCube homebrew native EmuDen player")
        openGameMenu(app); app.buttons["Quick Save"].tap()
        XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 35))
        openGameMenu(app); app.buttons["Quick Load"].tap()
        XCTAssertTrue(app.staticTexts["Quick save loaded"].waitForExistence(timeout: 35))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (top.value as? String ?? "").contains("Snapshot counter restored")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        assertGameCubePixels(app)
        openGameMenu(app); app.buttons["Quick Save"].tap()
        XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 35))
        openGameMenu(app); app.buttons["openSaveHistory"].tap()
        XCTAssertTrue(app.buttons["saveHistory-quick-1"].waitForExistence(timeout: 10))
        attach(app, "GameCube independent save history and native preview")
        app.buttons["saveHistoryDone"].tap()
        returnToLibrary(app)
        app.terminate(); app.launchArguments = ["--boot-gamecube-demo", "--gamecube-qa-status", "--touch-controls-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app)
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 90)); app.buttons["Resume session"].tap()
        XCTAssertTrue(app.staticTexts["Session resumed"].waitForExistence(timeout: 35))
        assertGameCubePixels(app)
        returnToLibrary(app)
    }
    @MainActor func testGameCubeLandscapeControllerFillsDisplay() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo", "--gamecube-qa-status", "--fresh-start", "--controller-preview", "-screenSizing", "automatic", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGameCubePixels(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let top = app.otherElements["topScreen"]
        let filled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(top.frame.width - app.frame.width) < 2 && abs(top.frame.height - app.frame.height) < 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [filled], timeout: 15), .completed)
        XCTAssertFalse(app.buttons["control-0"].exists)
        attach(app, "GameCube landscape full display with controller")
        returnToLibrary(app)
    }
    @MainActor func testGameCubeLandscapeTouchControlsHaveSpace() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo", "--gamecube-qa-status", "--fresh-start", "--touch-controls-preview", "-screenSizing", "automatic", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGameCubePixels(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let wide = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [wide], timeout: 15), .completed)
        let a = app.buttons["control-0"], left = app.buttons["control-6"], top = app.otherElements["topScreen"]
        XCTAssertTrue(app.frame.contains(a.frame)); XCTAssertTrue(app.frame.contains(left.frame))
        XCTAssertGreaterThanOrEqual(a.frame.width, 52)
        XCTAssertLessThanOrEqual(left.frame.maxX, top.frame.minX)
        XCTAssertGreaterThanOrEqual(a.frame.minX, top.frame.maxX)
        attach(app, "GameCube landscape with separate touch controls")
        returnToLibrary(app)
    }
    @MainActor private func assertGameCubePixels(_ app: XCUIApplication) {
        let top = app.otherElements["topScreen"]
        XCTAssertTrue(top.waitForExistence(timeout: 90))
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let value = top.value as? String ?? ""
            let frames = Int(value.split(separator: " ").first ?? "0") ?? 0
            return frames >= 90 && value.contains("PowerPC boot verified") && self.hasColoredContent(app, in: top.frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 90), .completed,"Native GameCube: \(top.value ?? "No status")")
    }
    @MainActor func testGameCubeTeardownAllowsPlayStationAndThreeDS() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-gamecube-demo", "--gamecube-qa-status", "--fresh-start", "--touch-controls-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertGameCubePixels(app)
        returnToLibrary(app)
        app.buttons["headerConsolePicker"].tap(); app.buttons["header-system-ps1"].tap()
        waitForConsole("PlayStation", in: app)
        XCTAssertTrue(app.buttons["launchPS1Demo"].waitForExistence(timeout: 10)); app.buttons["launchPS1Demo"].tap()
        if app.buttons["Resume session"].waitForExistence(timeout: 8) { app.buttons["Resume session"].tap() }
        assertPS1Pixels(app)
        attach(app, "PS1 video after GameCube teardown")
        returnToLibrary(app)
        app.buttons["headerConsolePicker"].tap(); app.buttons["header-system-3ds"].tap()
        waitForConsole("Nintendo 3DS", in: app)
        XCTAssertTrue(app.buttons["launchHomebrew"].waitForExistence(timeout: 10)); app.buttons["launchHomebrew"].tap()
        if app.buttons["Resume session"].waitForExistence(timeout: 8) { app.buttons["Resume session"].tap() }
        assertGamePixels(app)
        attach(app, "3DS video after GameCube and PS1 teardown")
        returnToLibrary(app)
        app.buttons["headerConsolePicker"].tap(); app.buttons["header-system-gamecube"].tap()
        XCTAssertTrue(app.buttons["selectedGameTile"].waitForExistence(timeout: 10))
        attach(app, "All three consoles available in the internal candidate")
    }
    @MainActor func testPlayStationDemoSaveHistoryAndSwitchBackTo3DS() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--touch-controls-preview", "-onlineArtworkEnabled", "NO", "-hasArtworkChoice", "YES"]
        launchPrepared(app)
        assertPS1Pixels(app)
        attach(app, "PS1 initial native layout")
        for label in ["Triangle", "Square", "Circle", "Cross", "L1", "L2", "R1", "R2"] { XCTAssertTrue(app.buttons[label].exists, label) }
        app.buttons["Cross"].press(forDuration: 0.15)
        attach(app, "PS1 homebrew with native PlayStation controls")
        for _ in 0..<2 {
            openGameMenu(app); app.buttons["Quick Save"].tap()
            XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 30))
        }
        openGameMenu(app); app.buttons["openSaveHistory"].tap()
        let older = app.buttons["saveHistory-quick-1"]
        XCTAssertTrue(older.waitForExistence(timeout: 10)); reveal(older, in: app)
        attach(app, "PS1 independent save history")
        older.tap(); app.buttons["Load save point"].tap()
        XCTAssertTrue(app.staticTexts["Save point loaded"].waitForExistence(timeout: 30)); assertPS1Pixels(app)
        returnToLibrary(app)
        app.terminate(); app.launchArguments = ["--boot-ps1-demo", "--touch-controls-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app)
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 30)); app.buttons["Resume session"].tap()
        XCTAssertTrue(app.staticTexts["Session resumed"].waitForExistence(timeout: 30)); assertPS1Pixels(app)
        returnToLibrary(app)
        app.buttons["System setup"].tap()
        let help = app.buttons["Help, tests & open-source notices"]
        reveal(help, in: app); help.tap()
        let threeDS = app.buttons["Launch 3DS test"]
        reveal(threeDS, in: app); threeDS.tap()
        if app.buttons["Resume session"].waitForExistence(timeout: 8) { app.buttons["Resume session"].tap() }
        assertGamePixels(app)
        attach(app, "3DS renderer after PS1 teardown")
        returnToLibrary(app)
        app.buttons["consoleFilter"].firstMatch.tap()
        app.buttons["system-ps1"].tap()
        XCTAssertTrue(app.buttons["launchPS1Demo"].waitForExistence(timeout: 10)); app.buttons["launchPS1Demo"].tap()
        if app.buttons["Resume session"].waitForExistence(timeout: 8) { app.buttons["Resume session"].tap() }
        assertPS1Pixels(app)
        returnToLibrary(app)
    }
    @MainActor func testPlayStationControllerHidesTouchControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--controller-preview", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertPS1Pixels(app)
        XCTAssertFalse(app.buttons["Cross"].exists); XCTAssertFalse(app.buttons["L1"].exists)
        showPlayerHeader(app); XCTAssertTrue(app.buttons["Controller connected"].exists)
        attach(app, "PS1 controller presentation")
        returnToLibrary(app)
    }
    @MainActor func testPlayStationAppleVirtualControllerReachesEmulatedPAD() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--ps1-controller-test", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertPS1Pixels(app)
        let result = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "Controller input passed"), object: app.images["topScreen"])
        XCTAssertEqual(XCTWaiter.wait(for: [result], timeout: 30), .completed)
        attach(app, "Apple controller Cross, analog D-pad and disconnect check")
        returnToLibrary(app)
    }
    @MainActor func testPlayStationLandscapeControllerFillsScreen() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--controller-preview", "-screenSizing", "automatic", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertPS1Pixels(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let top = app.images["topScreen"]
        let fullscreen = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(top.frame.width - app.frame.width) < 2 && abs(top.frame.height - app.frame.height) < 2
        }, object: nil)
        let filled = XCTWaiter.wait(for: [fullscreen], timeout: 10)
        if filled != .completed { print("LANDSCAPE app=\(app.frame), screen=\(top.frame), orientation=\(XCUIDevice.shared.orientation.rawValue)") }
        attach(app, "PS1 landscape controller frame check")
        XCTAssertEqual(filled, .completed)
        XCTAssertFalse(app.buttons["Cross"].exists)
        attach(app, "PS1 landscape full display with controller")
        returnToLibrary(app)
    }
    @MainActor func testPlayStationLandscapeTouchControlsHaveSpace() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-ps1-demo", "--fresh-start", "--touch-controls-preview", "-screenSizing", "automatic", "-onlineArtworkEnabled", "NO"]
        launchPrepared(app); assertPS1Pixels(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let wide = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [wide], timeout: 10), .completed)
        let cross = app.buttons["Cross"], up = app.buttons["control-4"], top = app.images["topScreen"]
        print("LANDSCAPE_TOUCH app=\(app.frame) cross=\(cross.frame) up=\(up.frame) screen=\(top.frame)")
        XCTAssertTrue(cross.exists); XCTAssertTrue(up.exists)
        XCTAssertTrue(app.frame.contains(cross.frame)); XCTAssertTrue(app.frame.contains(up.frame))
        XCTAssertGreaterThanOrEqual(cross.frame.width, 52)
        XCTAssertLessThanOrEqual(up.frame.maxX, top.frame.minX)
        XCTAssertGreaterThanOrEqual(cross.frame.minX, top.frame.maxX)
        attach(app, "PS1 landscape with comfortable side controls")
        returnToLibrary(app)
    }
    @MainActor private func assertPS1Pixels(_ app: XCUIApplication) {
        let top = app.images["topScreen"]
        XCTAssertTrue(top.waitForExistence(timeout: 30)); XCTAssertFalse(app.images["bottomScreen"].exists)
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let count = Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0
            return count >= 120 && self.hasColoredContent(app, in: top.frame)
        }, object: nil)
        let result = XCTWaiter.wait(for: [rendered], timeout: 45)
        if result != .completed { print("PS1 failed render probe: \(String(describing: top.value))\n\(app.debugDescription)") }
        XCTAssertEqual(result, .completed)
    }

    @MainActor func testOriginalBoxCoverSourceAndOfflineRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["EMUDEN_TEST_ARTWORK"] = "1"
        app.launchArguments = ["-hasArtworkChoice", "YES", "-onlineArtworkEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25)); app.buttons["System setup"].tap()
        let catalog = app.buttons["openArtworkCatalog"]; reveal(catalog, in: app); catalog.tap()
        let field = app.textFields["boxArtworkLink"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
        field.typeText("https://artwork-test.example/Named_Boxarts/")
        app.buttons["connectBoxCovers"].tap()
        let status = app.staticTexts["boxArtworkStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Saved 4 original covers.'"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 30), .completed)
        attach(app, "One source fills matching covers while protecting a manual image")
        app.terminate(); app.launchEnvironment["EMUDEN_TEST_ARTWORK_OFFLINE"] = "1"; app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        reveal(catalog, in: app); catalog.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "https://artwork-test.example/Named_Boxarts/")
        app.buttons["connectBoxCovers"].tap()
        let cached = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Saved 0 original covers.'"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [cached], timeout: 15), .completed)
        app.buttons["disconnectBoxCovers"].tap()
        XCTAssertFalse(app.buttons["disconnectBoxCovers"].exists)
        attach(app, "Offline relaunch and disconnect retain saved covers")
    }
    @MainActor func testMultiConsoleArtworkFillAndOfflineRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["EMUDEN_TEST_ARTWORK"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25)); app.buttons["System setup"].tap()
        let catalog = app.buttons["openArtworkCatalog"]; reveal(catalog, in: app); catalog.tap()
        let field = app.textFields["artworkCatalogLink"]
        func showCatalogControl(_ control: XCUIElement) {
            let scroll = app.scrollViews["artworkCatalogScroll"].firstMatch
            XCTAssertTrue(scroll.waitForExistence(timeout: 8))
            for _ in 0..<7 {
                let visible = scroll.frame.intersection(app.frame).insetBy(dx: 0, dy: 12)
                if control.exists, control.isHittable, visible.contains(control.frame) { return }
                scroll.swipeUp()
            }
        }
        XCTAssertTrue(field.waitForExistence(timeout: 8)); showCatalogControl(field); field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) { field.tap() }
        field.typeText("https://artwork-test.example/")
        app.buttons["previewArtworkCatalog"].tap()
        let matches = app.staticTexts["artworkCatalogMatches"]
        XCTAssertTrue(matches.waitForExistence(timeout: 10)); XCTAssertEqual(matches.label, "2 covers · 2 backgrounds")
        let fill = app.buttons["fillArtworkCatalog"]; showCatalogControl(fill); fill.tap()
        let status = app.staticTexts["artworkCatalogStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Saved 4 images.'"), object: status)], timeout: 20), .completed)
        attach(app, "All three consoles fill while manual cover and console background stay selected")
        app.terminate(); app.launchEnvironment["EMUDEN_TEST_ARTWORK_OFFLINE"] = "1"; app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        reveal(catalog, in: app); catalog.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 8)); XCTAssertEqual(field.value as? String, "https://artwork-test.example/catalog.json")
        showCatalogControl(app.buttons["disconnectArtworkCatalog"]); app.buttons["disconnectArtworkCatalog"].tap()
        XCTAssertFalse(app.buttons["disconnectArtworkCatalog"].exists)
        attach(app, "Multi-console source persists offline; disconnect keeps saved images")
    }
    @MainActor func testFoldedLibraryPlayDispatchesForEachConsole() {
        continueAfterFailure = false
        let app = XCUIApplication()
        for pose in ["--library-tabletop-preview", "--library-book-preview"] {
            XCUIDevice.shared.orientation = pose == "--library-book-preview" ? .landscapeLeft : .portrait
            for platform in ["3ds", "ps1", "gamecube"] {
                app.launchArguments = [pose, "-favoriteConsole", platform, "-importedGameAccess", "undecided", "-menuSoundsEnabled", "NO"]
                app.launch()
                let play = app.buttons["startSelectedGame"]
                XCTAssertTrue(play.waitForExistence(timeout: 25)); XCTAssertTrue(play.isHittable)
                play.tap()
                XCTAssertFalse(app.buttons["confirmAdultAccess"].exists)
                let dispatched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    app.descendants(matching: .any)["topScreen"].firstMatch.exists || app.alerts["Something needs attention"].exists || app.buttons["Start normally"].exists
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [dispatched], timeout: 30), .completed, "Play must dispatch without the removed local declaration; OS regional checks may fail closed in Simulator")
                attach(app, "Folded Play dispatch \(pose) \(platform)")
                app.terminate()
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }
    @MainActor func testArtworkCatalogBulkFillAndOfflineRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["EMUDEN_TEST_ARTWORK"] = "1"
        app.launchArguments = ["-hasArtworkChoice", "YES", "-onlineArtworkEnabled", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25)); app.buttons["System setup"].tap()
        let catalog = app.buttons["openArtworkCatalog"]; reveal(catalog, in: app); catalog.tap()
        let field = app.textFields["artworkCatalogLink"]
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText("http://artwork-test.example/")
        app.buttons["previewArtworkCatalog"].tap()
        XCTAssertTrue(app.staticTexts["artworkCatalogError"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        reveal(catalog, in: app); catalog.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap()
        field.typeText("https://artwork-test.example/")
        app.buttons["previewArtworkCatalog"].tap()
        let matches = app.staticTexts["artworkCatalogMatches"]
        XCTAssertTrue(matches.waitForExistence(timeout: 10)); XCTAssertEqual(matches.label, "1 cover · 1 background")
        let fill = app.buttons["fillArtworkCatalog"]; reveal(fill, in: app); fill.tap()
        let status = app.staticTexts["artworkCatalogStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Saved 2 images.'"), object: status)], timeout: 20), .completed)
        attach(app, "Bulk artwork fill preserves a manual cover and console preference")
        app.terminate(); app.launchEnvironment["EMUDEN_TEST_ARTWORK_OFFLINE"] = "1"; app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        reveal(catalog, in: app); catalog.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        XCTAssertEqual(field.value as? String, "https://artwork-test.example/catalog.json")
        app.buttons["previewArtworkCatalog"].tap()
        XCTAssertTrue(app.staticTexts["artworkCatalogError"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["disconnectArtworkCatalog"].exists)
        reveal(app.buttons["disconnectArtworkCatalog"], in: app)
        app.buttons["disconnectArtworkCatalog"].tap()
        XCTAssertFalse(app.buttons["disconnectArtworkCatalog"].exists)
        attach(app, "Offline error and catalog disconnect keep saved artwork")
    }
    @MainActor func testWidgetGameRoutesOpenAndResume() throws {
        // Host prepares two copies of the bundled licensed homebrew in the isolated QA library.
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-showFrameGraph", "YES", "-prepareCachedShaders", "NO", "-resolutionFactor", "1"]
        launchPrepared(app); XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20))
        openWidgetRoute("AA170000-0000-4000-8000-000000000001", in: app)
        if app.buttons["Start normally"].waitForExistence(timeout: 8) { app.buttons["Start normally"].tap() }
        let unavailable = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Apple’s regional age check is unavailable.")).firstMatch
        if unavailable.waitForExistence(timeout: 10) {
            XCTAssertFalse(app.staticTexts["Starting your game…"].exists)
            attach(app, "Regional service unavailable: access fails closed without a stuck launch")
            app.buttons["OK"].tap()
            throw XCTSkip("Regional Apple age service unavailable in this Simulator; imported game link requires signed-device validation")
        }
        assertGamePixels(app); attach(app, "Live frame-time graph and homebrew renderer")
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 45))
        openWidgetRoute("AA170000-0000-4000-8000-000000000002", in: app)
        XCTAssertTrue(app.staticTexts["Homebrew widget route 2"].waitForExistence(timeout: 45))
        if app.buttons["Start normally"].waitForExistence(timeout: 8) { app.buttons["Start normally"].tap() }
        assertGamePixels(app)
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 45))
        openWidgetRoute("AA170000-0000-4000-8000-000000000001", in: app)
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 45)); app.buttons["Resume session"].tap()
        XCTAssertTrue(app.staticTexts["Session resumed"].waitForExistence(timeout: 45)); assertGamePixels(app)
        openWidgetRoute("AA170000-0000-4000-8000-000000000099", in: app)
        XCTAssertTrue(app.staticTexts["This game is no longer in your library."].waitForExistence(timeout: 45))
        attach(app, "Missing widget game handled safely"); app.buttons["OK"].tap()
    }
    @MainActor func testCaptureStoreScreenshotsWithLicensedDemo() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-onlineArtworkEnabled", "NO", "-hasArtworkChoice", "YES", "-importedGameAccess", "under18"]
        launchPrepared(app)
        XCTAssertTrue(app.staticTexts["selectedGameTitle"].waitForExistence(timeout: 25))
        XCTAssertEqual(app.staticTexts["selectedGameTitle"].label, "3DS Homebrew Menu")
        attach(app, "Store - Library with licensed homebrew")
        app.buttons["System setup"].tap()
        let layout = app.buttons["openDuoLayout"]; reveal(layout, in: app); layout.tap()
        let model = app.descendants(matching: .any)["openingConsolePreview"].firstMatch
        XCTAssertTrue(model.waitForExistence(timeout: 8))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Open'"), object: model)], timeout: 8), .completed)
        attach(app, "Store - Console layout and screen options")
        app.terminate(); app.launchArguments = ["--boot-homebrew", "--fresh-start", "-onlineArtworkEnabled", "NO", "-showFPS", "NO"]
        launchPrepared(app); assertGamePixels(app)
        openGameMenu(app)
        attach(app, "Store - Homebrew play and save controls")
        returnToLibrary(app)
    }

    @MainActor private func launchPrepared(_ app: XCUIApplication) {
        for (key, value) in [("-hasArtworkChoice", "YES"), ("-onlineArtworkEnabled", "YES"), ("-importedGameAccess", "adult")] {
            if !app.launchArguments.contains(key) { app.launchArguments += [key, value] }
        }
        app.launch()
    }

    @MainActor func testLocalArtworkReleaseIgnoresLegacyOnlinePreference() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasArtworkChoice", "YES", "-onlineArtworkEnabled", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25))
        XCTAssertFalse(app.buttons["allowOnlineArtwork"].exists)
        app.buttons["System setup"].tap()
        let policy = app.staticTexts["localArtworkPolicy"]; reveal(policy, in: app)
        XCTAssertTrue(policy.exists)
        XCTAssertFalse(app.switches["onlineArtwork"].exists)
        attach(app, "Local artwork release with legacy online preference enabled")
    }

    @MainActor func testDemoLinkRemainsAvailableWithoutLocalAgeChoice() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-importedGameAccess","under18"]
        launchPrepared(app)
        app.open(URL(string:"emuden://demo/homebrew")!)
        let open = XCUIApplication(bundleIdentifier:"com.apple.springboard").buttons["Open"]
        if open.waitForExistence(timeout:3) { open.tap() }
        if app.buttons["Start normally"].waitForExistence(timeout:8) { app.buttons["Start normally"].tap() }
        assertGamePixels(app); XCTAssertFalse(app.buttons["confirmAdultAccess"].exists)
        returnToLibrary(app)
    }
    @MainActor func testOptionalTipsUseVerifiedRepeatableStoreKitPurchases() throws {
        continueAfterFailure = false
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TipJar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        let small = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Small thank-you")).firstMatch
        reveal(small, in: app); XCTAssertTrue(small.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Extra support")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Big thank-you")).firstMatch.exists)
        attach(app, "Optional tips use localized Apple prices with every feature free")
        for _ in 0..<2 {
            small.tap()
            let thanked = app.staticTexts["Thank you for supporting EmuDen! Every feature remains free for everyone."].waitForExistence(timeout: 20)
            if !thanked {
                print("Local StoreKit transactions: \(session.allTransactions().count)")
                attach(app, "Tip purchase result requiring investigation")
            }
            XCTAssertTrue(thanked)
            app.buttons["OK"].tap()
        }
        XCTAssertEqual(session.allTransactions().filter { $0.productIdentifier == "com.brandonaleman.Emulator.tip.small" }.count, 2)
    }

    @MainActor private func openWidgetRoute(_ id: String, in app: XCUIApplication) {
        app.open(URL(string: "emuden://play/" + id)!)
        let open = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if open.waitForExistence(timeout: 3) { open.tap() }
    }
    @MainActor func testGameProfilePersistsIndependentlyAndWidgetsPreview() {
        let app = XCUIApplication(); launchPrepared(app)
        let tile = app.buttons["selectedGameTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: 20))
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["Graphics settings"].waitForExistence(timeout: 4)); app.buttons["Graphics settings"].tap()
        let custom = app.switches["customizeGame"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5)); setSwitch(custom, on: true, in: app)
        app.buttons["internalResolution"].tap(); app.buttons["3× · Sharpest"].tap()
        app.buttons["textureSampling"].tap(); app.buttons["Smooth"].tap()
        attach(app, "Per-game graphics profile")
        app.buttons["playerSettingsDone"].tap()
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.1); app.buttons["Graphics settings"].tap()
        XCTAssertEqual(app.buttons["internalResolution"].value as? String, "3× · Sharpest")
        XCTAssertTrue(custom.value as? String == "1")
        setSwitch(custom, on: false, in: app); app.buttons["playerSettingsDone"].tap()
        app.buttons["System setup"].tap()
        let widgets = app.buttons["widgetShowcase"]; reveal(widgets, in: app); widgets.tap()
        XCTAssertTrue(app.descendants(matching: .any)["continueWidgetPreview"].waitForExistence(timeout: 6))
        attach(app, "Continue Playing widgets in color and glass")
        app.swipeUp(); attach(app, "Recent Games widget shelf")
    }
    @MainActor func testChosenAvatarPersistsAndDoesNotReplaceSystemData() {
        let app = XCUIApplication(); app.launchArguments = ["--avatar-import-test"]
        app.launchEnvironment["EMUDEN_TEST_AVATAR_PATH"] = "/Volumes/SamsungT7/EmulatorApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
        launchPrepared(app); XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        let avatar = app.buttons["miiAvatar"]; reveal(avatar, in: app)
        XCTAssertTrue(avatar.waitForExistence(timeout: 5)); XCTAssertEqual(avatar.value as? String, "Custom portrait"); attach(app, "Chosen profile portrait and separate Mii resource status")
        app.terminate(); app.launchArguments = []; app.launchEnvironment = [:]; launchPrepared(app); app.buttons["System setup"].tap()
        reveal(avatar, in: app); XCTAssertTrue(avatar.waitForExistence(timeout: 5)); XCTAssertEqual(avatar.value as? String, "Custom portrait")
        app.buttons["miiAvatar"].press(forDuration: 1.1); app.buttons["Reset profile picture"].tap(); XCTAssertEqual(avatar.value as? String, "Default portrait")
    }
    @MainActor func testControllerFillsOuterDisplayAndKeepsTouchCoordinates() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication(); app.launchArguments = ["--input-test", "--controller-preview"]; launchPrepared(app)
        XCTAssertTrue(app.buttons["Controller connected"].waitForExistence(timeout: 15))
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap(); openPlayerLayout(app)
        app.buttons["Fill display"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
        if app.buttons["Resume game"].exists { app.buttons["Resume game"].tap() }
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let top = app.otherElements["topScreenRegion"], bottom = app.otherElements["bottomScreenRegion"]
            XCTAssertTrue(bottom.waitForExistence(timeout: 10))
            let filled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let combined = top.frame.union(bottom.frame), display = app.frame
                return abs(combined.minX - display.minX) < 2 && abs(combined.minY - display.minY) < 2 &&
                       abs(combined.maxX - display.maxX) < 2 && abs(combined.maxY - display.maxY) < 2
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [filled], timeout: 8), .completed)
            XCTAssertFalse(app.buttons["A"].exists)
            bottom.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.75)).tap()
            let input = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Touch '")).firstMatch
            XCTAssertTrue(input.waitForExistence(timeout: 3))
            let coordinates = input.label.dropFirst(6).split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            XCTAssertEqual(coordinates.count, 2)
            if coordinates.count == 2 { XCTAssertEqual(coordinates[0], 80, accuracy: 2); XCTAssertEqual(coordinates[1], 180, accuracy: 2) }
            attach(app, app.frame.width > app.frame.height ? "Outer display filled in landscape" : "Outer display filled in portrait")
        }
        XCUIDevice.shared.orientation = .portrait
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap(); openPlayerLayout(app)
        app.buttons["Console skin"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
    }
    @MainActor func testKnownBackgroundWaitsInDarkThenFadesIn() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["EMUDEN_TEST_SCENE_DELAY"] = "45"; launchPrepared(app)
        guard app.staticTexts["selectedGameTitle"].waitForExistence(timeout: 20), app.staticTexts["selectedGameTitle"].label.contains("Donkey Kong") else { throw XCTSkip("Run with isolated cached artwork fixtures") }
        let patch = CGRect(x: app.frame.width * 0.30, y: app.frame.height * 0.12,
                           width: app.frame.width * 0.42, height: app.frame.height * 0.14)
        XCTAssertLessThan(meanIntensity(app, in: patch), 3, "A known scene must load against black, without a console placeholder")
        attach(app, "Known background loading against dark ambience")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.hasColoredContent(app, in: patch) }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 50), .completed)
        attach(app, "Known background after its fade")
    }
    @MainActor func testPlayerHeaderAutoHideAndFPSPreference() {
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        let initialFPS = app.switches["showFPS"]
        XCTAssertTrue(initialFPS.waitForExistence(timeout: 5))
        setSwitch(initialFPS, on: false, in: app)
        app.terminate(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; launchPrepared(app)
        assertGamePixels(app)
        let menu = app.buttons["Game menu"]
        let wake = app.buttons["showPlayerControls"]
        let hidden = NSPredicate(format: "value == 'Controls hidden'")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hidden, object: wake)], timeout: 8), .completed)
        XCTAssertFalse(app.buttons["frameRate"].exists)
        let size = app.images["topScreen"].frame.size
        app.images["bottomScreen"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(wake.value as? String, "Controls hidden", "Lower-screen input must not wake the header")
        app.buttons["showPlayerControls"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        XCTAssertEqual(app.images["topScreen"].frame.width, size.width, accuracy: 1)
        XCTAssertEqual(app.images["topScreen"].frame.height, size.height, accuracy: 1)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        let fps = app.switches["showFPS"]
        XCTAssertTrue(fps.waitForExistence(timeout: 5)); XCTAssertEqual(fps.value as? String, "0")
        setSwitch(fps, on: true, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hidden, object: wake)], timeout: 8), .completed)
        Thread.sleep(forTimeInterval: 0.4) // Capture the completed fade, not its first animation frame.
        XCTAssertTrue(app.buttons["frameRate"].exists)
        attach(app, "Faded game header with optional corner FPS")
        app.terminate(); launchPrepared(app); assertGamePixels(app)
        XCTAssertTrue(app.buttons["frameRate"].exists, "FPS preference persists after relaunch")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        XCTAssertTrue(fps.waitForExistence(timeout: 5)); XCTAssertEqual(fps.value as? String, "1")
        attach(app, "Graphics settings with FPS enabled")
        setSwitch(fps, on: false, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hidden, object: wake)], timeout: 8), .completed)
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(app.buttons["frameRate"].exists)
        attach(app, "Unobstructed 3DS screens with FPS off")
        returnToLibrary(app)
    }

    @MainActor func testResolutionChoicesPersistAcrossSettings() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["-favoriteConsole", "3ds"]; launchPrepared(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25)); app.buttons["System setup"].tap(); app.buttons["advancedPlayerSettings"].tap()
        let picker = app.buttons["internalResolution"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        for label in ["2× · Sharper", "3× · Sharpest"] {
            picker.tap(); app.buttons[label].tap()
            XCTAssertEqual(picker.value as? String, label)
        }
        app.terminate(); launchPrepared(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25)); app.buttons["System setup"].tap(); app.buttons["advancedPlayerSettings"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); XCTAssertEqual(picker.value as? String, "3× · Sharpest")
        attach(app, "3DS resolution options")
        app.terminate(); app.launchArguments = ["--input-test"]; launchPrepared(app)
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 20)); openGameMenu(app)
        app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); XCTAssertEqual(picker.value as? String, "3× · Sharpest")
        picker.tap(); app.buttons["1× · Best performance"].tap()
        XCTAssertEqual(picker.value as? String, "1× · Best performance")
        attach(app, "Native resolution recommended in player settings")
    }

    @MainActor func testArtworkCollectionShowcase() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); launchPrepared(app)
        guard app.staticTexts["selectedGameTitle"].waitForExistence(timeout: 20), app.staticTexts["selectedGameTitle"].label.contains("Donkey Kong") else { throw XCTSkip("Run with the isolated artwork collection fixtures") }
        attach(app, "Collection Donkey Kong scene with existing cover")
        for (query, title) in [("Tomodachi", "Tomodachi Life"), ("Dark Moon", "Luigi"), ("A Link Between Worlds", "A Link Between Worlds"), ("Super Smash", "Super Smash"), ("Pokémon", "Pokémon")] {
            app.buttons["Search games"].tap()
            let field = app.textFields["Search your library"]
            XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(query)
            XCTAssertFalse(app.descendants(matching: .any)["liquidGlassDock"].firstMatch.exists)
            let result = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Select ' AND label CONTAINS %@", title)).firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 5)); result.tap()
            let selected = app.staticTexts["selectedGameTitle"]
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", title), object: selected)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
            XCTAssertTrue(app.buttons["startSelectedGame"].isHittable)
            let cover = app.buttons["selectedGameTile"]
            XCTAssertTrue(cover.waitForExistence(timeout: 5)); XCTAssertTrue(cover.isHittable, "Search selection must bring its cover into the Home shelf")
            attach(app, "Collection \(query)")
        }
    }
    @MainActor func testConsoleBackgroundPreferenceAndLocalArtworkReset() throws {
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.staticTexts["selectedGameTitle"].waitForExistence(timeout: 20))
        openArtworkEditor(app)
        let setting = app.switches["consoleBackground"]
        XCTAssertTrue(setting.waitForExistence(timeout: 5))
        if !setting.isHittable { app.swipeUp() }
        if setting.value as? String != "1" { setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        app.terminate(); launchPrepared(app); openArtworkEditor(app)
        XCTAssertEqual(setting.value as? String, "1")
        XCTAssertFalse(app.buttons["chooseArtworkMatch"].exists)
        let reset = app.buttons["resetArtwork"]; reveal(reset, in: app); reset.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Reset artwork' AND identifier != 'resetArtwork'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        let resetFinished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: setting)
        XCTAssertEqual(XCTWaiter.wait(for: [resetFinished], timeout: 8), .completed)
        attach(app, "Local image imports and console preference")
    }
    @MainActor func testArtworkFilePickerAndCustomCover() throws {
        let app = XCUIApplication(); launchPrepared(app)
        guard app.staticTexts["selectedGameTitle"].waitForExistence(timeout: 20), app.staticTexts["selectedGameTitle"].label.contains("Donkey Kong") else { throw XCTSkip("Run with the isolated artwork QA fixtures") }
        openArtworkEditor(app)
        app.buttons["importCoverImage"].tap()
        chooseArtworkFixture(app)
        XCTAssertTrue(app.descendants(matching: .any)["artworkImportComplete"].firstMatch.waitForExistence(timeout: 10))
        attach(app, "Imported cover overrides automatic artwork")
        app.buttons["artworkDone"].tap()
        app.terminate(); launchPrepared(app); openArtworkEditor(app)
        XCTAssertTrue(app.buttons["importCoverImage"].exists)
        attach(app, "Custom cover after relaunch")
        let background = app.buttons["importBackgroundImage"]
        if !background.isHittable { app.swipeUp() }; background.tap()
        chooseArtworkFixture(app)
        XCTAssertTrue(app.descendants(matching: .any)["artworkImportComplete"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["artworkDone"].tap()
        attach(app, "Custom background and cover")
    }
    @MainActor private func chooseArtworkFixture(_ app: XCUIApplication) {
        let image = app.cells.matching(NSPredicate(format: "label BEGINSWITH 'Console Cover'")).firstMatch
        // Files remembers its last location, including the fixture folder or Recents.
        if image.waitForExistence(timeout: 3) { image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap(); return }
        let browse = app.buttons["Browse"].firstMatch
        XCTAssertTrue(browse.waitForExistence(timeout: 25), "Allow the system document service to initialize on a fresh simulator")
        browse.tap()
        if image.waitForExistence(timeout: 3) { image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap(); return }
        let fixtures = app.cells["Artwork Fixtures, Folder"].firstMatch
        // Files can reopen the app's Documents folder instead of the locations list.
        if !fixtures.waitForExistence(timeout: 5) {
            let local = app.staticTexts["On My iPhone"].firstMatch
            if local.waitForExistence(timeout: 5) { local.tap() }
            let folder = app.cells.matching(NSPredicate(format: "label BEGINSWITH 'EmuDen,'")).firstMatch
            XCTAssertTrue(folder.waitForExistence(timeout: 10)); folder.tap()
        }
        XCTAssertTrue(fixtures.waitForExistence(timeout: 10)); fixtures.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(image.waitForExistence(timeout: 10)); image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
    }
    @MainActor private func openArtworkEditor(_ app: XCUIApplication) {
        let tile = app.buttons["selectedGameTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: 25)); tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 2)
        let change = app.buttons["changeArtwork"]
        if !change.waitForExistence(timeout: 5) {
            app.buttons["consoleHome"].tap()
            tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 2)
        }
        XCTAssertTrue(change.waitForExistence(timeout: 10)); change.tap()
        XCTAssertTrue(app.buttons["artworkDone"].waitForExistence(timeout: 5))
    }
    @MainActor func testReleaseMenuOnlyOffersPlayableConsoles() {
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.buttons["consoleCollection"].waitForExistence(timeout: 20))
        app.buttons["consoleCollection"].tap()
        XCTAssertTrue(app.buttons["consoleFilter"].waitForExistence(timeout: 5))
        app.buttons["consoleFilter"].tap()
        XCTAssertTrue(app.buttons["system-3ds"].waitForExistence(timeout: 3))
        for system in ["psp", "ps1", "gamecube", "ds", "ps2"] {
            XCTAssertFalse(app.buttons["system-\(system)"].exists)
        }
        attach(app, "Release library offers playable 3DS only")
    }

    @MainActor func testMenuSoundPreferencePersists() {
        let app = XCUIApplication()
        launchPrepared(app)
        app.buttons["System setup"].tap()
        app.buttons["Sound options"].tap()
        let setting = app.switches["menuSoundsEnabled"]
        XCTAssertTrue(setting.waitForExistence(timeout: 10))
        let initial = setting.value as? String
        let changed = initial == "1" ? "0" : "1"
        setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", changed), object: setting)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 3), .completed)
        XCTAssertEqual(app.buttons["previewMenuSound"].isEnabled, changed == "1")
        app.terminate(); launchPrepared(app)
        app.buttons["System setup"].tap()
        app.buttons["Sound options"].tap()
        XCTAssertTrue(setting.waitForExistence(timeout: 10))
        XCTAssertEqual(setting.value as? String, changed)
        setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", initial ?? "1"), object: setting)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 3), .completed)
        if initial == "1" { app.buttons["previewMenuSound"].tap() }
        attach(app, "Original menu sound settings")
        app.buttons["consoleHome"].tap()
    }

    @MainActor func testConsoleHomeBrowsingSearchAndLaunch() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        launchPrepared(app)
        let title = app.staticTexts["selectedGameTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        let firstTitle = title.label
        let shelf = app.descendants(matching: .any)["gameCarousel"].firstMatch
        XCTAssertTrue(shelf.exists)
        let otherGame = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'gameTile-'")).firstMatch
        XCTAssertTrue(otherGame.exists); otherGame.tap()
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in title.label != firstTitle }, object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        attach(app, "Console home game shelf")
        app.buttons["consoleCollection"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gameCollection"].firstMatch.exists)
        app.buttons["Search games"].tap()
        let search = app.textFields["Search your library"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Mario")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Select Mario Golf'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ocarina'")).firstMatch.exists)
        app.buttons["Close search"].tap()
        app.buttons["consoleHome"].tap()
        XCTAssertTrue(title.label.contains("Mario Golf"))
        attach(app, "Console home selected game")
        app.buttons["startSelectedGame"].tap()
        let top = app.images["topScreen"]
        XCTAssertTrue(top.waitForExistence(timeout: 60))
        if app.buttons["Start normally"].waitForExistence(timeout: 3) { app.buttons["Start normally"].tap() }
        let running = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0) >= 60
        }, object: top)
        XCTAssertEqual(XCTWaiter.wait(for: [running], timeout: 45), .completed)
        assertGamePixels(app)
        returnToLibrary(app)
        XCTAssertTrue(title.waitForExistence(timeout: 45))
    }
    @MainActor func testConsoleHomeAvoidsDuoFold() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--library-tabletop-preview"]; launchPrepared(app)
        let browse = app.descendants(matching: .any)["consoleBrowsePanel"].firstMatch
        XCTAssertTrue(browse.waitForExistence(timeout: 20))
        XCTAssertLessThan(app.staticTexts["selectedGameTitle"].frame.maxY, app.buttons["selectedGameTile"].frame.minY)
        XCTAssertTrue(app.buttons["selectedGameTile"].isHittable)
        XCTAssertTrue(app.buttons["System setup"].isHittable)
        attach(app, "Console home Duo tabletop")
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["--library-book-preview"]; launchPrepared(app)
        XCTAssertTrue(browse.waitForExistence(timeout: 20))
        XCTAssertLessThan(app.buttons["Search games"].frame.maxX, app.buttons["selectedGameTile"].frame.minX)
        XCTAssertTrue(app.buttons["selectedGameTile"].isHittable)
        XCTAssertTrue(app.buttons["addGames"].isHittable)
        attach(app, "Console home Duo book")
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
    }
    @MainActor func testShaderPausePreferencePersists() {
        let app = XCUIApplication()
        app.launchArguments = ["--input-test", "--duo-tabletop-preview", "--controller-preview"]
        launchPrepared(app)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        let setting = app.switches["Reduce shader pauses"]
        XCTAssertTrue(setting.waitForExistence(timeout: 10))
        let initial = setting.value as? String
        let changed = initial == "1" ? "0" : "1"
        // Form exposes the whole row as a switch; tap its actual control on the right.
        setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", changed), object: setting)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 3), .completed)
        app.terminate(); launchPrepared(app)
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        XCTAssertEqual(setting.value as? String, changed)
        setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", initial ?? "0"), object: setting)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 3), .completed)
        attach(app, "Shader pause preference")
    }
    @MainActor func testMarioGolfLocalStartup() throws {
        try assertLocalStartup("Mario Golf - World Tour (USA) (En,Fr,Es).3ds", name: "Mario Golf")
    }
    @MainActor func testOcarinaOfTimeLocalStartup() throws {
        try assertLocalStartup("Legend of Zelda, The - Ocarina of Time 3D (USA) (En,Fr,Es) (Rev 1).cci", name: "Ocarina of Time")
    }
    @MainActor func testMarioGolfGameplayAndStateRoundTrip() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let rom = root.appendingPathComponent("TestGames/Mario Golf - World Tour (USA) (En,Fr,Es).3ds")
        guard FileManager.default.fileExists(atPath: rom.path) else { throw XCTSkip("Local user-provided game is unavailable") }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-test-game", "--fresh-start", "--touch-controls-preview"]
        app.launchEnvironment["EMULATOR_TEST_ROM_PATH"] = rom.path
        launchPrepared(app)
        let top = app.images["topScreen"]
        XCTAssertTrue(top.waitForExistence(timeout: 60))
        for stage in 0..<8 {
            app.buttons["A"].tap()
            let current = Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0
            let next = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let count = Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0
                return count >= current + 90
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [next], timeout: 30), .completed)
            if stage % 2 == 1 { attach(app, "Mario Golf gameplay stage \(stage)") }
        }
        openGameMenu(app); app.buttons["Quick Save"].tap()
        XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 45))
        app.buttons["A"].tap()
        openGameMenu(app); app.buttons["Quick Load"].tap()
        XCTAssertTrue(app.staticTexts["Quick save loaded"].waitForExistence(timeout: 45))
        assertGamePixels(app)
        attach(app, "Mario Golf after state restore")
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 45))
    }
    @MainActor private func assertLocalStartup(_ file: String, name: String) throws {
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let rom = project.appendingPathComponent("TestGames/\(file)")
        guard FileManager.default.fileExists(atPath: rom.path) else { throw XCTSkip("Local user-provided \(name) ROM is unavailable") }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-test-game", "--fresh-start"]
        app.launchEnvironment["EMULATOR_TEST_ROM_PATH"] = rom.path
        launchPrepared(app)
        let top = app.images["topScreen"]
        XCTAssertTrue(top.waitForExistence(timeout: 45))
        let frames = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard top.exists else { return false }
            return (Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0) >= 600
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [frames], timeout: 120), .completed)
        XCTAssertTrue(hasColoredContent(app, in: top.frame))
        attach(app, "\(name) native startup")
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 10))
    }
    @MainActor func testDuoTabletopLayoutAndControllerExpansion() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--input-test", "--duo-tabletop-preview", "--touch-controls-preview"]; launchPrepared(app)
        let top = app.otherElements["topScreenRegion"]
        let bottom = app.otherElements["bottomScreenRegion"]
        XCTAssertTrue(bottom.waitForExistence(timeout: 10))
        XCTAssertLessThan(top.frame.maxY, bottom.frame.minY)
        let a = app.buttons["A"]
        XCTAssertTrue(a.waitForExistence(timeout: 5))
        a.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1)
        XCTAssertTrue(app.staticTexts["A pressed"].waitForExistence(timeout: 3))
        for label in ["↓", "SELECT", "START", "B"] { XCTAssertTrue(app.buttons[label].isHittable) }
        let touchWidth = bottom.frame.width
        attach(app, "Duo tabletop with touch controls")
        app.terminate()
        app.launchArguments = ["--input-test", "--duo-tabletop-preview", "--controller-preview"]; launchPrepared(app)
        XCTAssertTrue(bottom.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(bottom.frame.width, touchWidth)
        XCTAssertFalse(app.buttons["A"].exists)
        XCTAssertTrue(app.buttons["Controller connected"].exists)
        bottom.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Touch '")).firstMatch.waitForExistence(timeout: 3))
        attach(app, "Duo tabletop with controller preview")
    }
    @MainActor func testDuoBookLayout() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--input-test", "--duo-book-preview", "--controller-preview"]; launchPrepared(app)
        let top = app.otherElements["topScreenRegion"], bottom = app.otherElements["bottomScreenRegion"]
        XCTAssertTrue(bottom.waitForExistence(timeout: 10))
        XCTAssertLessThan(top.frame.maxX, bottom.frame.minX)
        attach(app, "Duo book layout")
    }
    @MainActor func testControllerCanFillDuoPanelsAndKeepSkin() {
        let app = XCUIApplication()
        app.launchArguments = ["--input-test", "--duo-tabletop-preview", "--controller-preview"]; launchPrepared(app)
        let bottom = app.otherElements["bottomScreenRegion"]
        XCTAssertTrue(bottom.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Controller connected"].waitForExistence(timeout: 10))
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        openPlayerLayout(app)
        app.buttons["Console skin"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
        if app.buttons["Resume game"].exists { app.buttons["Resume game"].tap() }
        let skinWidth = bottom.frame.width
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        openPlayerLayout(app)
        XCTAssertTrue(app.descendants(matching: .any)["openingConsolePreview"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Fill display"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
        if app.buttons["Resume game"].exists { app.buttons["Resume game"].tap() }
        XCTAssertGreaterThan(bottom.frame.width, skinWidth)
        XCTAssertFalse(app.buttons["A"].exists)
        attach(app, "Duo controller full panels")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Graphics settings"].tap()
        openPlayerLayout(app)
        app.buttons["Console skin"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
        if app.buttons["Resume game"].exists { app.buttons["Resume game"].tap() }
        XCTAssertEqual(bottom.frame.width, skinWidth, accuracy: 2)
        attach(app, "Duo graphite console skin")
        returnToLibrary(app)
    }
    @MainActor func testLibraryAndMiiSetup() {
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["addGames"].exists)
        app.buttons["System setup"].tap()
        app.buttons["openMiiSetup"].tap()
        XCTAssertTrue(app.buttons["Mii resource archive"].waitForExistence(timeout: 5))
        app.buttons["I have a NAND folder"].tap()
        XCTAssertTrue(app.buttons["Import system folder"].exists)
        attach(app, "System setup")
        app.buttons["miiSetupDone"].tap()
        app.buttons["consoleHome"].tap()
        attach(app, "Library")
    }
    @MainActor func testCinematicDuoOpeningAndSearch() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.buttons["Search games"].waitForExistence(timeout: 20))
        app.buttons["Search games"].tap()
        let field = app.textFields["Search your library"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Mario")
        let dock = app.descendants(matching: .any)["liquidGlassDock"].firstMatch
        XCTAssertFalse(dock.exists, "The dock stays hidden throughout search, including while typing")
        attach(app, "Option A expanding glass search")
        field.typeText("\n")
        XCTAssertTrue(field.exists)
        XCTAssertFalse(dock.exists, "Dismissing the keyboard must not restore the dock before search closes")
        app.buttons["Close search"].tap()
        XCTAssertFalse(field.exists)
        XCTAssertTrue(dock.waitForExistence(timeout: 5), "Closing search restores the dock")
        XCTAssertTrue(app.buttons["startSelectedGame"].isHittable)
        app.buttons["System setup"].tap()
        let layout = app.buttons["openDuoLayout"]
        XCTAssertTrue(layout.waitForExistence(timeout: 5))
        reveal(layout, in: app); layout.tap()
        let model = app.descendants(matching: .any)["openingConsolePreview"].firstMatch
        XCTAssertTrue(model.waitForExistence(timeout: 5))
        let opened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Open'"), object: model)
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 4), .completed)
        XCTAssertTrue(app.buttons["Console skin"].exists)
        XCTAssertTrue(app.buttons["Fill display"].exists)
        attach(app, "Option A opening console and Duo settings")
        app.buttons["duoLayoutDone"].tap(); app.buttons["consoleHome"].tap()
        XCTAssertTrue(app.buttons["startSelectedGame"].waitForExistence(timeout: 5))
    }
    @MainActor func testCinematicReducedMotionAndTransparency() throws {
        guard UIAccessibility.isReduceMotionEnabled, UIAccessibility.isReduceTransparencyEnabled else {
            throw XCTSkip("Enable Reduce Motion and Reduce Transparency in the simulator's Accessibility settings to run this visual check.")
        }
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.buttons["Search games"].waitForExistence(timeout: 20))
        app.buttons["Search games"].tap()
        XCTAssertTrue(app.textFields["Search your library"].waitForExistence(timeout: 3))
        app.buttons["Close search"].tap()
        app.buttons["System setup"].tap()
        let layout = app.buttons["openDuoLayout"]
        if !layout.isHittable { app.swipeUp() }; layout.tap()
        let model = app.descendants(matching: .any)["openingConsolePreview"].firstMatch
        XCTAssertTrue(model.waitForExistence(timeout: 3))
        XCTAssertEqual(model.value as? String, "Open")
        XCTAssertTrue(app.buttons["duoLayoutDone"].isHittable)
        attach(app, "Option A accessibility appearance")
    }
    @MainActor func testCinematicPauseMenuAndReturn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--input-test", "--controller-preview"]; launchPrepared(app)
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 10))
        openGameMenu(app)
        XCTAssertTrue(app.buttons["Quick Save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Quick Save"].isEnabled)
        XCTAssertFalse(app.buttons["Quick Load"].isEnabled)
        XCTAssertTrue(app.buttons["openGameDuoLayout"].exists)
        attach(app, "Option A paused-game menu")
        let exits = app.buttons.matching(NSPredicate(format: "label == 'Return to library'"))
        if !exits.allElementsBoundByIndex.contains(where: \.isHittable) { app.swipeUp() }
        let exit = try XCTUnwrap(exits.allElementsBoundByIndex.first(where: \.isHittable))
        exit.tap()
        XCTAssertTrue(app.buttons["startSelectedGame"].waitForExistence(timeout: 15))
    }
    @MainActor func testInputPauseAndReturn() {
        let app = XCUIApplication(); app.launchArguments = ["--input-test", "--touch-controls-preview"]; launchPrepared(app)
        XCTAssertTrue(app.staticTexts["Ready, player one."].waitForExistence(timeout: 10))
        app.buttons["A"].tap()
        XCTAssertTrue(app.staticTexts["A pressed"].waitForExistence(timeout: 3))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        app.buttons["Resume"].tap()
        attach(app, "Dual screen player")
        XCUIDevice.shared.orientation = .landscapeLeft
        for label in ["A", "B", "START", "SELECT", "↑"] {
            XCTAssertTrue(app.buttons[label].isHittable, "Control must fit after orientation changes: \(label)")
        }
        attach(app, "Controls after orientation change")
        XCUIDevice.shared.orientation = .portrait
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 5))
    }
    @MainActor func test3DSHomebrewBootAndClose() {
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; launchPrepared(app)
        assertGamePixels(app)
        attach(app, "Actual 3DS emulation")
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 10))
        app.buttons["System setup"].tap()
        app.buttons["Help, tests & open-source notices"].tap()
        app.buttons["Launch 3DS test"].tap()
        assertGamePixels(app)
        attach(app, "3DS emulation after reopening")
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 10))
    }
    @MainActor func testAutomaticSavePointSurvivesUncleanRelaunch() {
        // The shortened interval is compiled only for Simulator; device builds use five minutes.
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start", "--autosave-test", "-automaticResumeSaves", "YES"]; launchPrepared(app)
        assertGamePixels(app)
        XCTAssertTrue(app.staticTexts["Resume point saved"].waitForExistence(timeout: 45))
        app.terminate(); app.launchArguments = ["--boot-homebrew"]; launchPrepared(app)
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 45)); app.buttons["Resume session"].tap()
        XCTAssertTrue(app.staticTexts["Session resumed"].waitForExistence(timeout: 45)); assertGamePixels(app)
        openGameMenu(app); app.buttons["openSaveHistory"].tap()
        let automatic = app.buttons["saveHistory-resume-0"]
        XCTAssertTrue(automatic.waitForExistence(timeout: 10)); reveal(automatic, in: app)
        attach(app, "Periodic automatic snapshot after forced relaunch")
        app.buttons["saveHistoryDone"].tap(); returnToLibrary(app)
    }
    @MainActor func testSaveHistoryLoadsEarlierPointAndSurvivesRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; launchPrepared(app)
        assertGamePixels(app)
        for _ in 0..<2 {
            openGameMenu(app); app.buttons["Quick Save"].tap()
            XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 45))
            XCTAssertTrue(app.buttons["showPlayerControls"].waitForExistence(timeout: 10))
        }
        openGameMenu(app); app.buttons["openSaveHistory"].tap()
        let older = app.buttons["saveHistory-quick-1"]
        XCTAssertTrue(older.waitForExistence(timeout: 10)); reveal(older, in: app)
        attach(app, "Dated save history with game thumbnails")
        older.tap(); app.buttons["Load save point"].tap()
        XCTAssertTrue(app.staticTexts["Save point loaded"].waitForExistence(timeout: 45)); assertGamePixels(app)
        // Duo's Home button may leave the other display active. Genuine background
        // capture is exercised separately on the owned single-screen QA simulator.
        returnToLibrary(app)
        app.terminate(); app.launchArguments = ["--boot-homebrew"]; launchPrepared(app)
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 45)); app.buttons["Resume session"].tap()
        XCTAssertTrue(app.staticTexts["Session resumed"].waitForExistence(timeout: 45)); assertGamePixels(app)
        openGameMenu(app); app.buttons["openSaveHistory"].tap()
        XCTAssertTrue(older.waitForExistence(timeout: 10)); reveal(older, in: app)
        older.tap(); app.buttons["Load save point"].tap()
        XCTAssertTrue(app.staticTexts["Save point loaded"].waitForExistence(timeout: 45)); assertGamePixels(app)
        returnToLibrary(app)
    }
    @MainActor func testPublicPolicyLinksAndOfflineNoticesAreAccessible() {
        continueAfterFailure = false
        let app = XCUIApplication(); launchPrepared(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        let notices = app.buttons["openSourceNotices"]; reveal(notices, in: app)
        let privacy = app.descendants(matching: .any)["privacyPolicyLink"]
        XCTAssertTrue(privacy.exists)
        XCTAssertTrue(app.descendants(matching: .any)["supportLink"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["correspondingSourceLink"].exists)
        notices.tap()
        XCTAssertTrue(app.navigationBars["Open-source notices"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["noticeFileCount"].label, "148 license and notice files")
        let coreLicense = app.buttons["notice-Vendor/Azahar/Source/LICENSE.txt"]
        for _ in 0..<6 { if coreLicense.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(coreLicense.isHittable); coreLicense.tap()
        let text = app.textViews["openSourceNoticeText"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (text.value as? String)?.contains("GNU GENERAL PUBLIC LICENSE") == true
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 10), .completed)
        attach(app, "Offline open-source notices")
    }
    @MainActor func testQuickSaveLoadAndResumeAfterRelaunch() {
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; launchPrepared(app)
        assertGamePixels(app)
        openGameMenu(app); app.buttons["Quick Save"].tap()
        XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 45))
        openGameMenu(app); app.buttons["Quick Load"].tap()
        XCTAssertTrue(app.staticTexts["Quick save loaded"].waitForExistence(timeout: 45))
        assertGamePixels(app)
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 45))
        app.terminate(); app.launchArguments = ["--boot-homebrew"]; launchPrepared(app)
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 45))
        app.buttons["Resume session"].tap()
        XCTAssertTrue(app.staticTexts["Session resumed"].waitForExistence(timeout: 45))
        assertGamePixels(app)
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 45))
    }
    @MainActor private func assertGamePixels(_ app: XCUIApplication) {
        XCTAssertTrue(app.images["topScreen"].waitForExistence(timeout: 45))
        XCTAssertTrue(app.images["bottomScreen"].exists)
        let top = app.images["topScreen"]
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let count = Int((top.value as? String ?? "").split(separator: " ").first ?? "0") ?? 0
            return count >= 60 && self.hasColoredContent(app, in: top.frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 60), .completed)
    }
    @MainActor private func showPlayerHeader(_ app: XCUIApplication) {
        let menu = app.buttons["Game menu"]
        let wake = app.buttons["showPlayerControls"]
        XCTAssertTrue(wake.waitForExistence(timeout: 5)); wake.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
    }
    @MainActor private func openGameMenu(_ app: XCUIApplication) {
        // A cold Simulator AX lookup can outlast the three-second toolbar timeout.
        for _ in 0..<2 {
            showPlayerHeader(app); app.buttons["Game menu"].tap()
            if app.buttons["Quick Save"].waitForExistence(timeout: 2) { return }
        }
        XCTFail("Game menu did not open after waking its controls")
    }
    @MainActor private func returnToLibrary(_ app: XCUIApplication) {
        let menuBack = app.buttons["gameMenuBack"]
        // Resume dismisses asynchronously after its chime; let that transition settle.
        if !menuBack.waitForNonExistence(timeout: 2) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: menuBack)], timeout: 10), .completed)
            menuBack.tap()
        } else { showPlayerHeader(app); app.buttons["playerBack"].tap() }
        let player = app.otherElements["topScreenRegion"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !player.exists }, object: nil)], timeout: 45), .completed, "Wait for resume capture and player dismissal before relaunching")
    }
    @MainActor private func openPlayerLayout(_ app: XCUIApplication) {
        let category = app.segmentedControls["graphicsCategory"]
        if category.exists { category.buttons["Controls"].tap() }
        let layout = app.buttons["openPlayerDuoLayout"]
        reveal(layout, in: app); layout.tap()
    }
    @MainActor private func setSwitch(_ setting: XCUIElement, on: Bool, in app: XCUIApplication) {
        let desired = on ? "1" : "0"
        if setting.value as? String != desired {
            reveal(setting, in: app)
            setting.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", desired), object: setting)], timeout: 10), .completed,
                           "\(setting.identifier): value=\(setting.value ?? "nil"), enabled=\(setting.isEnabled), frame=\(setting.frame)")
        }
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            let settings = app.scrollViews["playerSettingsScroll"]
            let scroll = settings.exists ? settings : app.scrollViews.firstMatch
            let viewport = scroll.frame.intersection(app.frame)
            let up = !element.exists || element.frame.midY > viewport.midY
            // Short drags avoid jumping over a whole card and oscillating in landscape.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: up ? 0.70 : 0.30)).press(forDuration: 0.05,
                thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: up ? 0.30 : 0.70)))
        }
        XCTAssertTrue(element.isHittable, "Reveal \(element.identifier): app \(app.frame), element \(element.exists ? element.frame : .zero)")
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func hasColoredContent(_ app: XCUIApplication, in frame: CGRect) -> Bool {
        guard let cg = XCUIScreen.main.screenshot().image.cgImage else { return false }
        let scaleX = CGFloat(cg.width) / app.frame.width, scaleY = CGFloat(cg.height) / app.frame.height
        let area = frame.insetBy(dx: 8, dy: 8)
        let rect = CGRect(x: (area.minX - app.frame.minX) * scaleX, y: (area.minY - app.frame.minY) * scaleY,
                          width: area.width * scaleX, height: area.height * scaleY)
        guard let crop = cg.cropping(to: rect) else { return false }
        var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
        pixels.withUnsafeMutableBytes { memory in
            let context = CGContext(data: memory.baseAddress, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.draw(crop, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return stride(from: 0, to: pixels.count, by: 4).contains {
            let channels = [Int(pixels[$0]), Int(pixels[$0 + 1]), Int(pixels[$0 + 2])]
            return channels.max()! > 80 && channels.max()! - channels.min()! > 30
        }
    }
    @MainActor private func meanIntensity(_ app: XCUIApplication, in frame: CGRect) -> Double {
        guard let cg = XCUIScreen.main.screenshot().image.cgImage else { return 255 }
        let scaleX = CGFloat(cg.width) / app.frame.width, scaleY = CGFloat(cg.height) / app.frame.height
        let rect = CGRect(x: (frame.minX - app.frame.minX) * scaleX, y: (frame.minY - app.frame.minY) * scaleY,
                          width: frame.width * scaleX, height: frame.height * scaleY)
        guard let crop = cg.cropping(to: rect) else { return 255 }
        var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
        pixels.withUnsafeMutableBytes { memory in
            let context = CGContext(data: memory.baseAddress, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.draw(crop, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return stride(from: 0, to: pixels.count, by: 4).reduce(0.0) { $0 + Double(pixels[$1]) + Double(pixels[$1 + 1]) + Double(pixels[$1 + 2]) } / (16 * 16 * 3)
    }
}
