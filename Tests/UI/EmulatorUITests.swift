import XCTest
import UIKit

final class EmulatorUITests: XCTestCase {
    @MainActor func testWidgetGameRoutesOpenAndResume() {
        // Host prepares two copies of the bundled licensed homebrew in the isolated QA library.
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-showFrameGraph", "YES", "-prepareCachedShaders", "NO", "-resolutionFactor", "1"]
        app.launch(); XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20))
        openWidgetRoute("AA170000-0000-4000-8000-000000000001", in: app)
        assertGamePixels(app); attach(app, "Live frame-time graph and homebrew renderer")
        returnToLibrary(app)
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 45))
        openWidgetRoute("AA170000-0000-4000-8000-000000000002", in: app)
        XCTAssertTrue(app.staticTexts["Homebrew widget route 2"].waitForExistence(timeout: 45))
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
    @MainActor private func openWidgetRoute(_ id: String, in app: XCUIApplication) {
        app.open(URL(string: "emuden://play/" + id)!)
        let open = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if open.waitForExistence(timeout: 3) { open.tap() }
    }
    @MainActor func testGameProfilePersistsIndependentlyAndWidgetsPreview() {
        let app = XCUIApplication(); app.launch()
        let tile = app.buttons["selectedGameTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: 20))
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["Game settings"].waitForExistence(timeout: 4)); app.buttons["Game settings"].tap()
        let custom = app.switches["customizeGame"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5)); setSwitch(custom, on: true, in: app)
        app.buttons["internalResolution"].tap(); app.buttons["3× · Sharpest"].tap()
        app.buttons["textureSampling"].tap(); app.buttons["Smooth"].tap()
        attach(app, "Per-game graphics profile")
        app.buttons["playerSettingsDone"].tap()
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.1); app.buttons["Game settings"].tap()
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
        app.launch(); XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        let avatar = app.buttons["miiAvatar"]; reveal(avatar, in: app)
        XCTAssertTrue(avatar.waitForExistence(timeout: 5)); XCTAssertEqual(avatar.value as? String, "Custom portrait"); attach(app, "Chosen profile portrait and separate Mii resource status")
        app.terminate(); app.launchArguments = []; app.launchEnvironment = [:]; app.launch(); app.buttons["System setup"].tap()
        reveal(avatar, in: app); XCTAssertTrue(avatar.waitForExistence(timeout: 5)); XCTAssertEqual(avatar.value as? String, "Custom portrait")
        app.buttons["miiAvatar"].press(forDuration: 1.1); app.buttons["Reset profile picture"].tap(); XCTAssertEqual(avatar.value as? String, "Default portrait")
    }
    @MainActor func testControllerFillsOuterDisplayAndKeepsTouchCoordinates() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication(); app.launchArguments = ["--input-test", "--controller-preview"]; app.launch()
        XCTAssertTrue(app.buttons["Controller connected"].waitForExistence(timeout: 15))
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap(); openPlayerLayout(app)
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
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap(); openPlayerLayout(app)
        app.buttons["Console skin"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
    }
    @MainActor func testKnownBackgroundWaitsInDarkThenFadesIn() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["EMUDEN_TEST_SCENE_DELAY"] = "45"; app.launch()
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
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        let initialFPS = app.switches["showFPS"]
        XCTAssertTrue(initialFPS.waitForExistence(timeout: 5))
        setSwitch(initialFPS, on: false, in: app)
        app.terminate(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; app.launch()
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
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
        let fps = app.switches["showFPS"]
        XCTAssertTrue(fps.waitForExistence(timeout: 5)); XCTAssertEqual(fps.value as? String, "0")
        setSwitch(fps, on: true, in: app)
        app.buttons["playerSettingsDone"].tap(); app.buttons["Resume game"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hidden, object: wake)], timeout: 8), .completed)
        Thread.sleep(forTimeInterval: 0.4) // Capture the completed fade, not its first animation frame.
        XCTAssertTrue(app.buttons["frameRate"].exists)
        attach(app, "Faded game header with optional corner FPS")
        app.terminate(); app.launch(); assertGamePixels(app)
        XCTAssertTrue(app.buttons["frameRate"].exists, "FPS preference persists after relaunch")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
        XCTAssertTrue(fps.waitForExistence(timeout: 5)); XCTAssertEqual(fps.value as? String, "1")
        attach(app, "Player settings with FPS enabled")
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
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25)); app.buttons["System setup"].tap()
        let picker = app.buttons["internalResolution"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        for label in ["2× · Sharper", "3× · Sharpest"] {
            picker.tap(); app.buttons[label].tap()
            XCTAssertEqual(picker.value as? String, label)
        }
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 25)); app.buttons["System setup"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); XCTAssertEqual(picker.value as? String, "3× · Sharpest")
        attach(app, "3DS resolution options")
        app.terminate(); app.launchArguments = ["--input-test"]; app.launch()
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 20)); openGameMenu(app)
        app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); XCTAssertEqual(picker.value as? String, "3× · Sharpest")
        picker.tap(); app.buttons["1× · Best performance"].tap()
        XCTAssertEqual(picker.value as? String, "1× · Best performance")
        attach(app, "Native resolution recommended in player settings")
    }

    @MainActor func testArtworkCollectionShowcase() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launch()
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
    @MainActor func testArtworkMatchingConsolePreferenceAndReset() throws {
        let app = XCUIApplication(); app.launch()
        guard app.staticTexts["selectedGameTitle"].waitForExistence(timeout: 20), app.staticTexts["selectedGameTitle"].label.contains("Donkey Kong") else { throw XCTSkip("Run with the isolated artwork QA fixtures") }
        openArtworkEditor(app)
        let setting = app.switches["consoleBackground"]
        XCTAssertTrue(setting.waitForExistence(timeout: 5))
        if !setting.isHittable { app.swipeUp() }
        if setting.value as? String != "1" { setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        app.terminate(); app.launch(); openArtworkEditor(app)
        XCTAssertEqual(setting.value as? String, "1")
        let match = app.buttons["chooseArtworkMatch"]
        if !match.isHittable { app.swipeDown() }; match.tap()
        let field = app.textFields["Find artwork"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        app.buttons["Clear artwork search"].tap()
        field.typeText("Tomodachi")
        let result = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Use artwork for Tomodachi Life'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5)); result.tap()
        let matched = app.staticTexts["artworkMatchedTitle"]
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Tomodachi'"), object: matched)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
        app.buttons["artworkDone"].tap()
        XCTAssertTrue(app.staticTexts["selectedGameTitle"].label.contains("Donkey Kong"), "Artwork choices must not rename the game or change its save identity")
        app.terminate(); app.launch(); openArtworkEditor(app)
        XCTAssertTrue(matched.label.contains("Tomodachi"))
        let reset = app.buttons["resetArtwork"]
        if !reset.isHittable { app.swipeUp() }; reset.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Restore automatic artwork' AND identifier != 'resetArtwork'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Donkey Kong'"), object: matched)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 8), .completed)
        XCTAssertEqual(setting.value as? String, "0")
        attach(app, "Artwork matching and console preferences")
        app.buttons["artworkDone"].tap()
        attach(app, "Console background and full card artwork")
    }
    @MainActor func testArtworkFilePickerAndCustomCover() throws {
        let app = XCUIApplication(); app.launch()
        guard app.staticTexts["selectedGameTitle"].waitForExistence(timeout: 20), app.staticTexts["selectedGameTitle"].label.contains("Donkey Kong") else { throw XCTSkip("Run with the isolated artwork QA fixtures") }
        openArtworkEditor(app)
        app.buttons["importCoverImage"].tap()
        chooseArtworkFixture(app)
        XCTAssertTrue(app.descendants(matching: .any)["artworkImportComplete"].firstMatch.waitForExistence(timeout: 10))
        attach(app, "Imported cover overrides automatic artwork")
        app.buttons["artworkDone"].tap()
        app.terminate(); app.launch(); openArtworkEditor(app)
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
    @MainActor func testPlannedConsolesAreClearlyUnavailable() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["consoleCollection"].waitForExistence(timeout: 20))
        app.buttons["consoleCollection"].tap()
        XCTAssertTrue(app.buttons["consoleFilter"].waitForExistence(timeout: 5))
        for system in ["psp", "ps1", "gamecube"] {
            if !app.buttons["consoleFilter"].exists { app.buttons["consoleCollection"].tap() }
            app.buttons["consoleFilter"].tap()
            app.buttons["system-\(system)"].tap()
            XCTAssertTrue(app.staticTexts["COMING SOON"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["startSelectedGame"].exists)
            XCTAssertTrue(app.buttons["backToPlayableLibrary"].isHittable)
            XCTAssertLessThan(app.buttons["backToPlayableLibrary"].frame.maxY, app.buttons["addGames"].frame.minY)
            attach(app, "Planned console \(system)")
        }
        app.buttons["backToPlayableLibrary"].tap()
        XCTAssertTrue(app.buttons["startSelectedGame"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["backToPlayableLibrary"].exists)
    }

    @MainActor func testMenuSoundPreferencePersists() {
        let app = XCUIApplication()
        app.launch()
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
        app.terminate(); app.launch()
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
        app.launch()
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
        app.launchArguments = ["--library-tabletop-preview"]; app.launch()
        let browse = app.descendants(matching: .any)["consoleBrowsePanel"].firstMatch
        XCTAssertTrue(browse.waitForExistence(timeout: 20))
        XCTAssertLessThan(app.staticTexts["selectedGameTitle"].frame.maxY, app.buttons["selectedGameTile"].frame.minY)
        XCTAssertTrue(app.buttons["selectedGameTile"].isHittable)
        XCTAssertTrue(app.buttons["System setup"].isHittable)
        attach(app, "Console home Duo tabletop")
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["--library-book-preview"]; app.launch()
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
        app.launch()
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
        let setting = app.switches["Reduce shader pauses"]
        XCTAssertTrue(setting.waitForExistence(timeout: 10))
        let initial = setting.value as? String
        let changed = initial == "1" ? "0" : "1"
        // Form exposes the whole row as a switch; tap its actual control on the right.
        setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", changed), object: setting)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 3), .completed)
        app.terminate(); app.launch()
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
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
        app.launch()
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
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 45))
    }
    @MainActor private func assertLocalStartup(_ file: String, name: String) throws {
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let rom = project.appendingPathComponent("TestGames/\(file)")
        guard FileManager.default.fileExists(atPath: rom.path) else { throw XCTSkip("Local user-provided \(name) ROM is unavailable") }
        let app = XCUIApplication()
        app.launchArguments = ["--boot-test-game", "--fresh-start"]
        app.launchEnvironment["EMULATOR_TEST_ROM_PATH"] = rom.path
        app.launch()
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
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 10))
    }
    @MainActor func testDuoTabletopLayoutAndControllerExpansion() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--input-test", "--duo-tabletop-preview", "--touch-controls-preview"]; app.launch()
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
        app.launchArguments = ["--input-test", "--duo-tabletop-preview", "--controller-preview"]; app.launch()
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
        app.launchArguments = ["--input-test", "--duo-book-preview", "--controller-preview"]; app.launch()
        let top = app.otherElements["topScreenRegion"], bottom = app.otherElements["bottomScreenRegion"]
        XCTAssertTrue(bottom.waitForExistence(timeout: 10))
        XCTAssertLessThan(top.frame.maxX, bottom.frame.minX)
        attach(app, "Duo book layout")
    }
    @MainActor func testControllerCanFillDuoPanelsAndKeepSkin() {
        let app = XCUIApplication()
        app.launchArguments = ["--input-test", "--duo-tabletop-preview", "--controller-preview"]; app.launch()
        let bottom = app.otherElements["bottomScreenRegion"]
        XCTAssertTrue(bottom.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Controller connected"].waitForExistence(timeout: 10))
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
        openPlayerLayout(app)
        app.buttons["Console skin"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
        if app.buttons["Resume game"].exists { app.buttons["Resume game"].tap() }
        let skinWidth = bottom.frame.width
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
        openPlayerLayout(app)
        XCTAssertTrue(app.descendants(matching: .any)["openingConsolePreview"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Fill display"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
        if app.buttons["Resume game"].exists { app.buttons["Resume game"].tap() }
        XCTAssertGreaterThan(bottom.frame.width, skinWidth)
        XCTAssertFalse(app.buttons["A"].exists)
        attach(app, "Duo controller full panels")
        openGameMenu(app); app.buttons["moreGameOptions"].tap(); app.buttons["Player Settings"].tap()
        openPlayerLayout(app)
        app.buttons["Console skin"].tap(); app.buttons["duoLayoutDone"].tap(); app.buttons["playerSettingsDone"].tap()
        if app.buttons["Resume game"].exists { app.buttons["Resume game"].tap() }
        XCTAssertEqual(bottom.frame.width, skinWidth, accuracy: 2)
        attach(app, "Duo graphite console skin")
        returnToLibrary(app)
    }
    @MainActor func testLibraryAndMiiSetup() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 10))
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
        let app = XCUIApplication(); app.launch()
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
        let app = XCUIApplication(); app.launch()
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
        app.launchArguments = ["--input-test", "--controller-preview"]; app.launch()
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
        let app = XCUIApplication(); app.launchArguments = ["--input-test", "--touch-controls-preview"]; app.launch()
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
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 5))
    }
    @MainActor func test3DSHomebrewBootAndClose() {
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; app.launch()
        assertGamePixels(app)
        attach(app, "Actual 3DS emulation")
        returnToLibrary(app)
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 10))
        app.buttons["System setup"].tap()
        app.buttons["Help, tests & open-source notices"].tap()
        app.buttons["Launch 3DS test"].tap()
        assertGamePixels(app)
        attach(app, "3DS emulation after reopening")
        returnToLibrary(app)
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 10))
    }
    @MainActor func testAutomaticSavePointSurvivesUncleanRelaunch() {
        // The shortened interval is compiled only for Simulator; device builds use five minutes.
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start", "--autosave-test", "-automaticResumeSaves", "YES"]; app.launch()
        assertGamePixels(app)
        XCTAssertTrue(app.staticTexts["Resume point saved"].waitForExistence(timeout: 45))
        app.terminate(); app.launchArguments = ["--boot-homebrew"]; app.launch()
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
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; app.launch()
        assertGamePixels(app)
        for _ in 0..<2 {
            openGameMenu(app); app.buttons["Quick Save"].tap()
            XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 45))
            XCTAssertTrue(app.buttons["showPlayerControls"].waitForExistence(timeout: 10))
        }
        openGameMenu(app); app.buttons["openSaveHistory"].tap()
        let older = app.buttons["saveHistory-quick-1"]
        XCTAssertTrue(older.waitForExistence(timeout: 10)); reveal(older, in: app)
        let previousAutomatic = app.buttons["saveHistory-resume-0"].exists ? (app.buttons["saveHistory-resume-0"].value as? String ?? "") : ""
        attach(app, "Dated save history with game thumbnails")
        older.tap(); app.buttons["Load save point"].tap()
        XCTAssertTrue(app.staticTexts["Save point loaded"].waitForExistence(timeout: 45)); assertGamePixels(app)
        XCUIDevice.shared.press(.home)
        sleep(2)
        XCTAssertNotEqual(app.state, .runningForeground, "Exercise a real background transition")
        app.activate()
        openGameMenu(app); app.buttons["openSaveHistory"].tap()
        let automatic = app.buttons["saveHistory-resume-0"]
        XCTAssertTrue(automatic.waitForExistence(timeout: 45)); reveal(automatic, in: app)
        XCTAssertNotEqual(automatic.value as? String ?? "", previousAutomatic, "Backgrounding must create a new point, not merely show an existing one")
        attach(app, "Background resume point kept separately")
        app.buttons["saveHistoryDone"].tap(); returnToLibrary(app)
        app.terminate(); app.launchArguments = ["--boot-homebrew"]; app.launch()
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
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["System setup"].waitForExistence(timeout: 20)); app.buttons["System setup"].tap()
        let privacy = app.descendants(matching: .any)["privacyPolicyLink"]
        reveal(privacy, in: app); XCTAssertTrue(privacy.exists)
        XCTAssertTrue(app.descendants(matching: .any)["supportLink"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["correspondingSourceLink"].exists)
        let notices = app.buttons["openSourceNotices"]; reveal(notices, in: app); notices.tap()
        XCTAssertTrue(app.navigationBars["ThirdPartyNotices"].waitForExistence(timeout: 10))
        attach(app, "Offline open-source notices")
    }
    @MainActor func testQuickSaveLoadAndResumeAfterRelaunch() {
        let app = XCUIApplication(); app.launchArguments = ["--boot-homebrew", "--fresh-start"]; app.launch()
        assertGamePixels(app)
        openGameMenu(app); app.buttons["Quick Save"].tap()
        XCTAssertTrue(app.staticTexts["Quick save ready"].waitForExistence(timeout: 45))
        openGameMenu(app); app.buttons["Quick Load"].tap()
        XCTAssertTrue(app.staticTexts["Quick save loaded"].waitForExistence(timeout: 45))
        assertGamePixels(app)
        returnToLibrary(app)
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 45))
        app.terminate(); app.launchArguments = ["--boot-homebrew"]; app.launch()
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 45))
        app.buttons["Resume session"].tap()
        XCTAssertTrue(app.staticTexts["Session resumed"].waitForExistence(timeout: 45))
        assertGamePixels(app)
        returnToLibrary(app)
        XCTAssertTrue(app.staticTexts["EMUDEN"].waitForExistence(timeout: 45))
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
        if menuBack.exists { menuBack.tap() }
        else { showPlayerHeader(app); app.buttons["playerBack"].tap() }
        let player = app.otherElements["topScreenRegion"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !player.exists }, object: nil)], timeout: 45), .completed, "Wait for resume capture and player dismissal before relaunching")
    }
    @MainActor private func openPlayerLayout(_ app: XCUIApplication) {
        let layout = app.buttons["openPlayerDuoLayout"]
        reveal(layout, in: app); layout.tap()
    }
    @MainActor private func setSwitch(_ setting: XCUIElement, on: Bool, in app: XCUIApplication) {
        let desired = on ? "1" : "0"
        if setting.value as? String != desired {
            reveal(setting, in: app)
            setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", desired), object: setting)], timeout: 4), .completed)
        }
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            if element.exists && element.frame.minY < app.frame.minY + 90 { app.scrollViews.firstMatch.swipeDown() }
            else { app.scrollViews.firstMatch.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func hasColoredContent(_ app: XCUIApplication, in frame: CGRect) -> Bool {
        guard let cg = app.screenshot().image.cgImage else { return false }
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
        guard let cg = app.screenshot().image.cgImage else { return 255 }
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
