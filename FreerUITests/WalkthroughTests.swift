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
        app.swipeUp()
        snap("home-scrolled")
        app.swipeDown()

        // Every tile, in grid order. A tile that pushes a pane has a Back
        // button to come home by; Receive is a sheet with Done.
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
            let back = app.navigationBars.buttons.firstMatch
            if back.exists {
                back.tap()
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
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Identity — switch the live FID"].tap()
        sleep(1)
        snap("person-menu")
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
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
        app.buttons["设置"].firstMatch.tap()
        sleep(1)
        snap("zh-设置")
    }
}
