import XCTest

/// Walks the app the way a new user would — make a vault, add an
/// identity, open every tile — and keeps a screenshot of each screen.
///
/// Less a test of behaviour than a way to *look* at the app without a
/// hand on the simulator: the assertions are only that each screen it
/// expects is reached. The pictures and a dump of each screen's elements
/// go to `$SHOTS_DIR` when it is set (pass `TEST_RUNNER_SHOTS_DIR=…` to
/// `xcodebuild test`), and are attached to the test result either way.
final class WalkthroughTests: XCTestCase {

    private var app: XCUIApplication!
    private var step = 0

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
    }

    private func snap(_ name: String) {
        step += 1
        let label = String(format: "%02d-%@", step, name)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"], !dir.isEmpty else { return }
        let base = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: base.appendingPathComponent(label + ".png"))
        try? app.debugDescription.write(
            to: base.appendingPathComponent(label + ".txt"), atomically: true, encoding: .utf8
        )
    }

    /// Unlock, creating the vault and its first identity on a fresh install.
    private func reachHome() {
        let password = app.secureTextFields["Password"]
        XCTAssertTrue(password.waitForExistence(timeout: 20), "the password screen")
        password.tap()
        password.typeText("walkthrough-vault-1")

        // Opens the vault this password already has, or makes it: a
        // fresh install and a rerun take the same button.
        app.buttons["Create new password"].tap()
        XCTAssertTrue(app.staticTexts["Choose identity"].waitForExistence(timeout: 30), "the identity chooser")
        snap("choose-identity")

        let add = app.buttons["Add identity"]
        if add.waitForExistence(timeout: 2) {
            add.tap()
            XCTAssertTrue(app.textFields["Label (optional)"].waitForExistence(timeout: 10), "the add-identity form")
            snap("add-identity")
            // The button is the form's last row, under ten candidate FIDs.
            let confirm = app.buttons["Add identity"].firstMatch
            for _ in 0..<4 where !(confirm.exists && confirm.isHittable) { app.swipeUp() }
            confirm.tap()
        } else {
            // Rerun: the identity made last time is the only row.
            app.cells.firstMatch.tap()
        }
        XCTAssertTrue(app.buttons["Lock vault"].waitForExistence(timeout: 40), "the home screen")
    }

    func testWalkthrough() {
        // By name, in English, whatever language the simulator is set to.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        snap("launch")
        reachHome()
        snap("home")

        // The backup sheet, from the getting-started card while it still
        // asks: its icon rows, and the cipher row once there is a cipher.
        let backup = app.buttons["Back up now"]
        if backup.waitForExistence(timeout: 3), backup.isHittable {
            backup.tap()
            sleep(2)
            snap("backup-prikey")
            let vault = app.secureTextFields["Vault password"]
            if vault.waitForExistence(timeout: 3) {
                vault.tap()
                vault.typeText("walkthrough-vault-1\n")
                _ = app.buttons["Copy cipher"].waitForExistence(timeout: 30)
                snap("backup-prikey-cipher")
                if app.buttons["QR code"].firstMatch.exists {
                    app.buttons["QR code"].firstMatch.tap()
                    sleep(1)
                    app.swipeUp()
                    snap("backup-prikey-qr")
                }
            }
            app.buttons["Back"].firstMatch.tap()
            sleep(1)
        }

        app.swipeUp()
        snap("home-scrolled")
        app.swipeDown()

        // Every tile, in grid order.
        let tiles = ["News", "Convert", "Tools", "Protocol", "Service", "Code",
                     "Proof", "Token", "APP", "Overview", "Secret", "Files",
                     "Logs", "TX", "Cash", "First FCH", "Receive", "Pay",
                     "Square", "Team", "Room", "Contact", "Cmail", "Talk",
                     "Image", "Text", "Statement", "Sound", "Video"]
        for title in tiles {
            let tile = app.buttons[title].firstMatch
            if !tile.isHittable { app.swipeUp() }
            guard tile.waitForExistence(timeout: 3), tile.isHittable else {
                XCTFail("tile \(title) is not on screen")
                continue
            }
            tile.tap()
            sleep(2)
            snap("pane-" + title.replacingOccurrences(of: " ", with: "-"))
            // Back is the last button of the bottom bar; Receive is a
            // sheet of the shared package's, with its own Done.
            if app.buttons["Back"].exists {
                app.buttons["Back"].firstMatch.tap()
            } else if app.buttons["Done"].exists {
                app.buttons["Done"].firstMatch.tap()
            } else {
                XCTFail("no way back from \(title)")
                return
            }
            sleep(1)
        }

        app.buttons["Settings"].firstMatch.tap()
        sleep(1)
        snap("pane-Settings")
        app.buttons["Back"].firstMatch.tap()
        app.buttons["Identity — switch the live FID"].tap()
        sleep(1)
        snap("person-menu")
    }

    /// A pane's bottom bar and a sheet's: opens a few panes, and from
    /// each the sheet its primary button presents, then backs out of both
    /// with the bars' own Back. Run after ``testWalkthrough()`` has made
    /// the vault.
    func testBottomBarScreens() {
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        reachHome()
        // The topmost Back: a sheet's, when one is up over a pane.
        func back() {
            let all = app.buttons.matching(identifier: "Back").allElementsBoundByIndex
            XCTAssertFalse(all.isEmpty, "a Back button")
            all.last?.tap()
            sleep(1)
        }
        let stops = [("Cash", "More"), ("Contact", "Add"), ("Cmail", "Write"), ("Token", "Deploy"),
                     ("Statement", "Declare"), ("Secret", "Add"), ("Pay", "Advanced")]
        for (title, primary) in stops {
            let tile = app.buttons[title].firstMatch
            for _ in 0..<3 where !(tile.exists && tile.isHittable) { app.swipeUp() }
            tile.tap()
            sleep(2)
            snap("bar-" + title)
            let button = app.buttons[primary].firstMatch
            XCTAssertTrue(button.exists, "\(primary) in the bottom bar of \(title)")
            if button.isEnabled {
                button.tap()
                sleep(1)
                snap("bar-" + title + "-" + primary)
                if title == "Cash" {
                    app.buttons["Refresh"].firstMatch.tap()
                    sleep(1)
                } else {
                    back()
                }
            }
            back()
        }
        XCTAssertTrue(app.buttons["Lock vault"].exists, "home again")
    }

    /// The same app in Simplified Chinese: the unlock screen, the home
    /// grid and a few panes, to see that the translation is found and fits.
    ///
    /// Run after ``testWalkthrough()`` has made the vault. Controls are
    /// found by position or by their Chinese names, since the English
    /// ones are exactly what is absent here.
    func testChineseScreens() {
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let password = app.secureTextFields.firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 20), "the password screen")
        snap("zh-password")
        password.tap()
        password.typeText("walkthrough-vault-1")
        app.buttons["创建新密码"].tap()
        XCTAssertTrue(app.staticTexts["选择身份"].waitForExistence(timeout: 30), "the identity chooser")
        snap("zh-choose-identity")
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.buttons["锁定密钥库"].waitForExistence(timeout: 40), "the home screen")
        sleep(3)
        snap("zh-home")
        app.swipeUp()
        snap("zh-home-grid")
        for title in ["对话", "钞票", "支付", "密信", "协议", "概览"] {
            let tile = app.buttons[title].firstMatch
            guard tile.waitForExistence(timeout: 3) else {
                XCTFail("tile \(title) is not on screen")
                continue
            }
            if !tile.isHittable { app.swipeDown() }
            tile.tap()
            sleep(2)
            snap("zh-" + title)
            app.buttons["返回"].firstMatch.tap()
            sleep(1)
        }
        app.buttons["设置"].firstMatch.tap()
        sleep(1)
        snap("zh-设置")

        // The language picker: choose English, and the note about
        // restarting appears. Then put the choice back, so the next run
        // starts as this one did.
        let language = app.staticTexts["语言"]
        // Short drags, not swipes: the form only holds the rows on screen,
        // and a flick can carry the one being looked for straight past.
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        // Until the label is in the upper part of the form, so the picker
        // under it is clear of the bottom bar.
        for _ in 0..<50 where !(language.exists && language.isHittable && language.frame.minY < 480) {
            bottom.press(forDuration: 0.05, thenDragTo: top)
        }
        XCTAssertTrue(language.exists, "the Language setting")
        snap("zh-语言")
        // Theme sits above Language and reads Follow system too, when it
        // is on screen: the language picker is the one under its label.
        let followers = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "跟随系统"))
        func languagePicker() -> XCUIElement? {
            followers.allElementsBoundByIndex
                .filter { $0.frame.minY >= language.frame.minY && $0.frame.width <= 200 }
                .min { $0.frame.minY < $1.frame.minY }
        }
        // Open the picker reading English and choose Follow system: the
        // way back at the end of this test, and the repair at its start
        // when an earlier run stopped halfway and left English behind.
        func followSystem() {
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "English")).firstMatch.tap()
            sleep(1)
            snap("zh-语言-menu")
            // Up to two controls read Follow system now: Theme's picker on
            // the page, and the item in the open menu. The menu's rows are
            // the wide ones.
            let choices = app.buttons.matching(NSPredicate(format: "label == %@", "跟随系统")).allElementsBoundByIndex
            if let item = choices.first(where: { $0.frame.width > 200 }) {
                item.tap()
            } else {
                XCTFail("no Follow system item in the language menu")
            }
            sleep(1)
        }
        if languagePicker() == nil { followSystem() }
        guard let picker = languagePicker() else {
            XCTFail("Language on Follow system")
            return
        }
        picker.tap()
        app.buttons["English"].tap()
        sleep(1)
        snap("zh-语言-English")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "下次启动时显示新语言")).firstMatch.exists,
            "the restart note"
        )
        followSystem()
        XCTAssertNotNil(languagePicker(), "Language back on Follow system")
    }
}
