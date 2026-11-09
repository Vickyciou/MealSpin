import XCTest

final class FlowTests: XCTestCase {
    @MainActor private func screenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testCreateSpinAndReload() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        XCTAssertTrue(app.buttons["spinButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["spinButton"].isHittable, "主按鈕不需捲動畫面即可操作")
        screenshot("01-Home", app: app)
        app.buttons["listSelector"].tap()
        XCTAssertTrue(app.buttons["list-早餐吃什麼"].waitForExistence(timeout: 5))
        screenshot("02-Lists", app: app)
        app.buttons["list-早餐吃什麼"].tap()
        XCTAssertTrue(app.buttons["listSelector"].label.contains("早餐吃什麼"))
        app.buttons["編輯選項"].tap()
        XCTAssertTrue(app.textFields["listNameField"].waitForExistence(timeout: 5))
        screenshot("03-Editor", app: app)
        app.buttons["取消"].tap()
        app.buttons["新增清單"].firstMatch.tap()
        let name = app.textFields["listNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("UI早餐測試")
        let food = app.textFields["newFoodField"]
        food.tap()
        food.typeText("測試蛋餅")
        app.buttons["儲存"].tap()
        let spin = app.buttons["spinButton"]
        XCTAssertTrue(spin.waitForExistence(timeout: 3))
        XCTAssertTrue(spin.isHittable)
        spin.tap()
        let result = app.staticTexts["spinResult"].firstMatch
        expectation(for: NSPredicate(format: "label CONTAINS %@", "測試蛋餅"), evaluatedWith: result)
        waitForExpectations(timeout: 15)
        screenshot("04-Result", app: app)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let selector = app.buttons["listSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        XCTAssertTrue(selector.label.contains("UI早餐測試"), "重開後保留上次使用的清單")
        app.buttons["抽選紀錄"].tap()
        XCTAssertTrue(app.staticTexts["測試蛋餅"].waitForExistence(timeout: 3))
        screenshot("05-History", app: app)
    }

    @MainActor func testDiscardAndEmptyList() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        app.buttons["新增清單"].tap()
        let name = app.textFields["listNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("尚未儲存的清單")
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["繼續編輯"].waitForExistence(timeout: 3))
        app.buttons["繼續編輯"].tap()
        XCTAssertTrue(name.exists)
        app.buttons["取消"].tap()
        app.buttons["放棄修改"].tap()
        XCTAssertTrue(app.buttons["listSelector"].waitForExistence(timeout: 3))
        app.buttons["新增清單"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("空白清單")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.buttons["spinButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["spinButton"].label.contains("加入想吃的選項"))
        app.buttons["spinButton"].tap()
        XCTAssertTrue(app.textFields["newFoodField"].waitForExistence(timeout: 3))
    }

    @MainActor func testImportPreviewCancelAndSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        XCTAssertTrue(app.buttons["listSelector"].waitForExistence(timeout: 5))
        let original = app.buttons["listSelector"].label
        // Do not reset stored data when opening/relaunching with a document URL.
        app.launchArguments = ["--ui-testing"]
        let file = URL.temporaryDirectory.appendingPathComponent("friend-breakfast.mealspin")
        let payload: [String: Any] = ["format": "mealspin-list", "version": 1, "name": "朋友的早餐名單", "symbol": "sun.max.fill", "items": ["起司蛋餅", "飯糰", "蘿蔔糕"]]
        try JSONSerialization.data(withJSONObject: payload).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        app.open(file)
        XCTAssertTrue(app.buttons["confirmImport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["起司蛋餅"].exists)
        screenshot("06-ImportPreview", app: app)
        app.buttons["取消"].tap()
        XCTAssertEqual(app.buttons["listSelector"].label, original)
        app.open(file)
        XCTAssertTrue(app.buttons["confirmImport"].waitForExistence(timeout: 5))
        app.buttons["confirmImport"].tap()
        XCTAssertTrue(app.buttons["listSelector"].label.contains("朋友的早餐名單"))
        app.open(file)
        XCTAssertTrue(app.buttons["confirmImport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已有同名清單")).firstMatch.exists)
        app.buttons["confirmImport"].tap()
        app.buttons["listSelector"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "list-朋友的早餐名單").count, 2)
    }

    @MainActor func testSharingPresentsSystemSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        let share = app.buttons["分享清單"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.buttons["shareListText"].waitForExistence(timeout: 5))
        screenshot("07-SharingOptions", app: app)
        app.buttons["shareListFile"].tap()
        let sharingService = XCUIApplication(bundleIdentifier: "com.apple.SharingUIService")
        let actions = NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label == %@ OR label == %@ OR label == %@", "儲存", "Save to Files", "Copy", "拷貝", "複製")
        let serviceAction = sharingService.descendants(matching: .any).matching(actions).firstMatch
        let localAction = app.descendants(matching: .any).matching(actions).firstMatch
        let visible = serviceAction.waitForExistence(timeout: 10) || localAction.waitForExistence(timeout: 3)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "08-SystemShareSheet"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(visible, "分享面板需實際顯示儲存或拷貝動作")
    }

    @MainActor func testTemporaryParticipation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        XCTAssertTrue(app.buttons["participationOptions"].waitForExistence(timeout: 5))
        app.buttons["participationOptions"].tap()
        let foods = ["滷肉飯", "牛肉麵", "水餃", "雞腿便當", "鍋燒意麵", "炒飯"]
        XCTAssertTrue(app.buttons["participation-滷肉飯"].waitForExistence(timeout: 5))
        for food in foods.dropFirst() { app.buttons["participation-\(food)"].tap() }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "participation-")).count, 6)
        screenshot("09-TemporaryParticipation", app: app)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["participationStatus"].label.contains("本次 1 項參與"))
        app.buttons["spinButton"].tap()
        expectation(for: NSPredicate(format: "label == %@", "滷肉飯"), evaluatedWith: app.staticTexts["spinResult"].firstMatch)
        waitForExpectations(timeout: 15)
        screenshot("10-FilteredWheel", app: app)
        app.buttons["listSelector"].tap()
        app.buttons["list-早餐吃什麼"].tap()
        app.buttons["listSelector"].tap()
        app.buttons["list-晚餐吃什麼（平價版）"].tap()
        XCTAssertTrue(app.staticTexts["participationStatus"].label.contains("本次 1 項參與"))
        app.buttons["participationOptions"].tap()
        app.buttons["participation-滷肉飯"].tap()
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["spinButton"].label.contains("選擇參與項目"))
        XCTAssertTrue(app.staticTexts["沒有參與抽選的項目"].exists)
        app.buttons["spinButton"].tap()
        app.buttons["includeAllOptions"].tap()
        for food in foods { XCTAssertEqual(app.buttons["participation-\(food)"].value as? String, "參與抽選") }
        app.buttons["participation-滷肉飯"].tap()
        app.buttons["完成"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["participationOptions"].tap()
        for food in foods { XCTAssertEqual(app.buttons["participation-\(food)"].value as? String, "參與抽選") }
    }
}
