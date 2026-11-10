# AI iOS 開發原則

本文件定義 MealSpin 的 AI 開發要求，適用於開發規劃、實作、重構、測試、建置設定與程式審查。依任務套用相關原則；目前架構與資料契約以對應專案文件為準。

本文結合官方 API 語意與本專案採納的工程判斷。各節附官方參考；抽象程度、依賴設計、常數分類及錯誤回復要求是專案規範，引用時保留這個區別。

## 執行順序

1. 依 [模組責任](modules.md) 找到本次修改或審查的入口；涉及狀態、儲存、抽選或分享時，讀取 [架構契約](architecture.md)。完成時能指出受影響的功能與邊界。
2. 核對相關原始碼、測試及 Xcode 設定，確認現有行為與變更範圍。採用 API 或並行特性前，查明最低 OS、語言模式及必要的 SDK 可用性。
3. 依下列原則實作當次需求。既有差異只在影響本次正確性或使用者明確要求時處理；把其他觀察另列，維持任務範圍。
4. 依 [開發說明](DEVELOPMENT.md#依變更選擇驗證) 執行必要檢查，按文末完成條件核對並回報。

## 1. 文案與使用者內容

- 先分類文字來源：App 標題、按鈕、提示與錯誤使用可本地化 API；使用者輸入的清單或食物名稱使用一般 `String` 並保留原文。
- 保留 SwiftUI 的文字語意：`Text("儲存")` 可作為本地化 key；`Text(someString)` 預設顯示一般字串。轉接文案時選用 `LocalizedStringResource` 等適當型別。

官方參考：[Text](https://developer.apple.com/documentation/swiftui/text)、[可翻譯文案](https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation)。

## 2. 共用元件與抽象

- 真正共用的元件由呼叫端提供可變文案、資料與 action；可翻譯文案保留適當型別，需要組合不同版面時才採用 `@ViewBuilder`。
- 抽出元件時，指出它承擔的共用版面、獨立行為、複雜呈現或維護邊界；單一使用處也適用。功能專屬的簡單 UI 可在使用處保留固定文案，優先直接表達意圖。

官方參考：[可本地化元件範例](https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation)。抽象程度依本節專案規範判斷。

## 3. 本地化資源與格式

- 新增或變更可翻譯 App 文案時，使用可擷取的本地化 API 與 String Catalog（`.xcstrings`）；完整句子一起本地化，數量使用插值與複數規則。
- 日期與數字使用 Foundation 的語系感知格式。本次變更檢查文字擷取及長文案；涉及翻譯時，再核對目標語言的插值、複數與版面。尚未具備資源或未執行的檢查列入回報。
- 目前沒有 Catalog 時，依本次文案需求納入相應資源；整體翻譯與舊文案遷移另按任務範圍處理。將文字移至常數檔，只改變存放位置，仍須完成本地化檢查。

官方參考：[String Catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)、[日期與數字格式](https://developer.apple.com/documentation/xcode/preparing-dates-numbers-with-formatters)。

## 4. 狀態歸屬與持久化

- 每份狀態指定單一擁有者，放在需要它的最小共同範圍。唯讀輸入使用一般 property；需要雙向修改才使用 `Binding`；畫面自有 `@State` 設為 private。
- 編輯草稿及呈現狀態留在畫面，共享清單及紀錄交由 store 管理。草稿副本要有明確的提交、取消與失敗行為，避免長期複製共享資料再手動同步。
- 分開短暫狀態與持久化資料，核對畫面重建、切換及 App 重新啟動的行為；`@State` 本身不提供磁碟保存。

官方參考：[UI 狀態管理](https://developer.apple.com/documentation/swiftui/managing-user-interface-state/)。本機保存邊界見 [狀態與儲存](architecture.md#狀態與儲存)。

## 5. 模型、Observation 與依賴

- 將資料規則與畫面呈現分開，使重要行為能直接驗證。共享 store 在明確入口建立，再提供給使用處。
- Observation 負責追蹤畫面讀取的模型變動；Environment 負責沿 view tree 提供資料或設定。局部依賴可由 initializer 傳入，跨樹共享需求再考慮 `@Environment`。
- 新增 ViewModel、protocol 或架構層時，說明它解決的實際分工、替換或測試需求。沿用能滿足需求的既有結構；MVVM、TCA、Clean Architecture 都是可選工程決策。

官方參考：[模型資料與 Observation](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)、[Environment](https://developer.apple.com/documentation/swiftui/environment)。

## 6. 型別、命名與常數

- 從呼叫端檢查 API 可讀性，使用領域名稱及清楚的 Swift argument labels。選單、流程、錯誤等封閉集合優先以 enum／具名型別表示。
- 依角色區分值：環境差異集中設定；固定協定值、SF Symbols 名稱及有意義的局部常數可保留在合適位置。

官方參考：[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)。常數分類依本節專案規範判斷。

## 7. 並行、isolation 與取消

- UI-facing store 明訂 isolation，例如 `@MainActor`。對 CPU 工作及同步 I/O，確認實際執行位置；`async` 本身不保證背景執行。
- 與畫面輸入或生命週期相關的工作，明訂取消與過期結果的處理方式；使用 `.task(id:)` 時，實作仍須配合取消，避免舊結果覆寫新狀態。
- 依量測需要移出耗時工作或增加並行。核對現有 Swift 語言模式與檢查設定；模式遷移須屬於任務範圍，Swift 6 的完整檢查只能在已啟用並驗證後宣稱。

官方參考：[Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)、[Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)、[task(id:)](https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:))。

## 8. 原生控制項與自適應版面

- 優先使用 `Button`、`List`、`Form`、`NavigationStack`、系統 sheet 及分享面板；自訂替代要有產品理由。
- 版面以可用空間及內容配置，核對 iPhone／iPad、小視窗、方向與長文案。有意義的間距及轉盤幾何常數可保留。
- 採用新 API 前核對 deployment target；需要時使用 availability 分支並提供可用的替代行為。

官方參考：[HIG Layout](https://developer.apple.com/design/human-interface-guidelines/layout)。

## 9. Accessibility 與互動驗收

- UI 變更依影響核對 Dynamic Type 最大級距、對比、VoiceOver 名稱／順序／動作及 Reduce Motion，確認任務仍能完成。
- 原生語意足夠時直接沿用；自訂轉盤等視覺內容提供文字結果與可操作入口，狀態以文字或語意補足顏色、動畫。
- 自動化掃描搭配人工操作。一般尺寸截圖只能支持該畫面的觀察；回報已檢查的尺寸與操作方式。

官方參考：[HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[Motion](https://developer.apple.com/design/human-interface-guidelines/motion)、[輔助功能測試](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app)。

## 10. 行為測試與錯誤回復

- 依變更選擇測試：資料契約、轉盤幾何與儲存失敗採快速小範圍檢查；關鍵操作保留代表性的真實 UI 流程，涵蓋相關正常、取消、空狀態及失敗路徑。
- 沿用符合需求的 `ModelChecks.swift` 與 XCTest。新增 Swift Testing 或遷移框架時，以實際需求說明選擇。
- 可預期的外部錯誤提供可理解的訊息及回復路徑；確認儲存、匯入等操作成功後才呈現成功狀態。

官方參考：[Testing](https://developer.apple.com/documentation/xcode/testing)、[加入測試](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)。錯誤回復依本節專案規範；命令見 [開發說明](DEVELOPMENT.md)。

## 11. 效能證據

- 效能修改先建立可重現情境與基準，以 Instruments 等工具定位原因，再選擇改動，於相同條件下比較前後結果。
- 增加 cache、task 或複雜狀態前，指出量測支持的需求。實機結果與 simulator 結果分別記錄；尚未量測時僅描述假設。

官方參考：[效能改善流程](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)。

## 12. 資料、權限與外部輸入

- 只讀取、保存與分享功能需要的欄位。敏感權限在功能實際需要時要求，說明用途並設計拒絕後的行為。
- 外部檔案在入口驗證格式、版本、大小及內容限制，遵守 [分享檔案契約](architecture.md#分享檔案契約)。
- 若任務引入登入或秘密資料，使用 Keychain 等適當儲存並選擇存取限制；token 不放入 `UserDefaults`、原始碼或 log。App 內嵌私密 API key 不能視為可保密，需重新設計秘密的使用邊界。
- Keychain、登入與網路層隨實際功能需求引入；原則文件本身不是新增這些功能的需求。

官方參考：[使用者隱私](https://developer.apple.com/documentation/uikit/protecting-the-user-s-privacy)、[Keychain](https://developer.apple.com/documentation/security/using-the-keychain-to-manage-user-secrets)、[Keychain 存取限制](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility)。

## 完成條件

- 每個修改或審查單元均已對應適用原則；判斷正確性的依據可回查至程式、SDK、測試或官方文件。
- 依開發說明選定的必要檢查已完成；回報檢查結果、失敗或未執行項目及其原因，區分靜態核對、編譯、模擬器與實機證據。
- 影響模組責任、整合契約、建置或操作方式時，更新對應專案文件。純文件修改以內容、連結及一致性核對為主。
- 若採取不同於本文預設的工程方案，回報適用原則、選擇及原因；讓使用者能理解其影響。
