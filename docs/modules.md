# MealSpin 模組責任

本文件依功能列出原始碼入口、責任與直接依賴，供追查行為及評估跨檔案修改範圍時使用。

[專案總覽](overview.md) · [架構與整合契約](architecture.md) · [開發說明](DEVELOPMENT.md)

## 功能與程式入口

以下均為同一個 App target 內的邏輯分工，並非獨立的 Swift package 或 framework。

| 功能 | 原始碼與主要型別 | 責任 | 直接依賴／交接 |
| --- | --- | --- | --- |
| App 入口與共用樣式 | [MealSpinApp.swift](../MealSpin/MealSpinApp.swift)：`MealSpinApp`、`Theme`、按鈕樣式 | 建立 store、切換測試資料入口、提供儲存錯誤提醒與共用視覺樣式 | 將 store 傳入 `ContentView`；各畫面使用 `Theme` 與按鈕樣式 |
| 首頁與畫面協調 | [ContentView.swift](../MealSpin/ContentView.swift)：`ContentView`、`HomeSheet` | 選取清單、開啟各功能 sheet、處理外部 URL 與待匯入資料 | 持有選取偏好與抽選狀態；持有首頁 `ListImportCoordinator`，將 store 傳入子畫面 |
| 資料與契約 | [Models.swift](../MealSpin/Models.swift)：`FoodList`、`MealDecision`、`SavedMeals`、`MealStore`、`WheelMath`、`ListPackage` | 清單／紀錄模型、本機讀寫保護、回復與副本保存、暫停項目、轉盤角度與分享格式驗證 | 使用 Foundation、Observation；畫面透過 store 方法更新共用資料 |
| 抽選與參與項目 | [WheelView.swift](../MealSpin/WheelView.swift)：`WheelScreen`、`WheelDisc` | 呈現轉盤、管理抽選動畫與目前結果、設定本次候選項目 | 透過 `MealStore` 讀取候選並記錄結果；使用 `WheelMath` 對齊指針；編輯及分享交回首頁 |
| 清單庫 | [ListLibrary.swift](../MealSpin/ListLibrary.swift)：`ListLibrary`、`LibrarySheet` | 搜尋、選取與刪除清單，開啟編輯／分享／匯入 | 將選取 UUID 透過 callback 回傳；使用 `ListFileReader` 與各清單 sheet |
| 匯入工作 | [ListImportCoordinator.swift](../MealSpin/ListImportCoordinator.swift)：`ListImportCoordinator` | 管理最新請求、取消、讀取狀態與單一待處理結果 | 注入 reader；首頁與清單庫各自決定呈現條件 |
| 資料回復 | [RecoveryView.swift](../MealSpin/RecoveryView.swift)：`RecoveryView`、`RecoveryBackupsView` | 持續呈現重讀、備份、確認重建與副本匯出 | 呼叫 `MealStore` 的回復方法，不直接寫入資料 |
| 清單編輯 | [ListEditor.swift](../MealSpin/ListEditor.swift)：`ListEditor` | 維護編輯草稿、整理多行選項、排序、確認放棄修改 | 使用 `store.save` 儲存；成功後回傳清單 UUID |
| 分享與匯入 | [ListSharing.swift](../MealSpin/ListSharing.swift)：`ListFileReader`、`ListFileExporter`、`ListShareView`、`ListImportView`、`NativeShareSheet` | 檔案讀寫、匯入預覽、檔案／文字分享與 UIKit 橋接 | 使用 `ListPackage` 驗證格式；匯入確認後呼叫 `store.save`；系統分享透過 `UIActivityViewController` |
| 抽選紀錄 | [HistoryView.swift](../MealSpin/HistoryView.swift)：`HistoryView` | 依日期顯示歷史結果，確認後清除紀錄 | 讀取 `store.history`，使用 `store.clearHistory` 清除 |

## 跨功能修改入口

| 要修改的行為 | 一起核對的檔案 | 契約位置 |
| --- | --- | --- |
| 持久化或改變狀態生命週期 | `MealSpinApp.swift`、`Models.swift`、`ContentView.swift` | [狀態與儲存](architecture.md#狀態與儲存) |
| 調整參與項目、抽選或指針對齊 | `Models.swift`、`WheelView.swift` | [清單編輯與抽選](architecture.md#清單編輯與抽選) |
| 調整本機編輯與可分享的內容 | `ListEditor.swift`、`Models.swift`、`ListSharing.swift` | [分享檔案契約](architecture.md#分享檔案契約) |
| 修改 `.mealspin` 格式或系統開啟行為 | `Models.swift`、`ListSharing.swift`、`Info.plist`、`ContentView.swift`、`ListLibrary.swift` | [系統檔案整合與匯入](architecture.md#系統檔案整合與匯入) |
| 新增或調整畫面入口 | `ContentView.swift` 的 `HomeSheet`、`ListLibrary.swift` 的 `LibrarySheet`、目標畫面 | [結構與依賴](architecture.md#結構與依賴) |

## 設定、資產與驗證

| 位置 | 責任 |
| --- | --- |
| [project.pbxproj](../MealSpin.xcodeproj/project.pbxproj) | App／UI 測試 target、來源與資產納入、部署平台及簽署設定 |
| [MealSpin.xcscheme](../MealSpin.xcodeproj/xcshareddata/xcschemes/MealSpin.xcscheme) | 共用 scheme 的建置、啟動與 UI 測試入口 |
| [Info.plist](../MealSpin/Info.plist) | `.mealspin` 文件與自訂 UTType 宣告 |
| [Localizable.xcstrings](../MealSpin/Localizable.xcstrings) | 繁體中文 App 文案與翻譯資源 |
| [Assets.xcassets](../MealSpin/Assets.xcassets) | App 圖示等 Xcode 資產 |
| [Design/AppIcon-Source.png](../Design/AppIcon-Source.png) | 儲存庫中的 App 圖示來源圖片 |
| [Tests/ModelChecks.swift](../Tests/ModelChecks.swift) | 不依賴模擬器的資料、分享契約與轉盤幾何檢查 |
| [Tests/ImportChecks.swift](../Tests/ImportChecks.swift) | 以可控制 reader 與工作完成順序檢查取消、反序結果及過期錯誤 |
| [Tests/FlowTests.swift](../Tests/FlowTests.swift) | 模擬器操作流程與畫面附件 |
| [docs/images](images) | README 與安裝教學使用的實際畫面素材 |

各類檢查的執行方式、適用變更與截圖更新方式見 [開發說明](DEVELOPMENT.md)。
