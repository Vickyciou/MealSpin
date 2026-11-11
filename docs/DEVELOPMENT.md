# MealSpin 開發說明

本文件提供開發環境、建置、測試與畫面素材的操作方式。產品範圍、狀態及檔案契約分別見對應文件。

審查改善項目與尚待完成的驗收見 [iOS 程式碼審查改善計畫](ios-improvement-plan.md)。

[專案總覽](overview.md) · [架構](architecture.md) · [模組責任](modules.md) · [手機安裝](INSTALL.md)

## 開發環境與啟動

使用 Mac 與已安裝 iOS 平台支援的 Xcode。請選擇同時支援目前 macOS、目標裝置系統或模擬器 runtime 的 Xcode 版本；平台設定見 [專案總覽](overview.md#技術與執行環境)。

開啟 `MealSpin.xcodeproj`，選擇 `MealSpin` scheme 與一台可用的 iPhone／iPad 模擬器，按 **Run**。專案沒有需要另外安裝的外部套件。安裝到實體裝置時，依 [完整安裝教學](INSTALL.md) 設定個人簽署帳號。

命令列使用目前 `xcode-select` 選定的 Xcode。先確認工具位置與可用裝置：

```sh
xcode-select -p
xcrun simctl list devices available
```

下列建置與 UI 測試範例使用 `iPhone 17 Pro`／`iOS 26.5`，請將 destination 換成自己電腦已安裝的裝置與 runtime。

```sh
xcodebuild -project MealSpin.xcodeproj -scheme MealSpin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO build
```

## 依變更選擇驗證

| 變更範圍 | 建議檢查 |
| --- | --- |
| 資料模型、儲存、分享格式、暫停邏輯或轉盤幾何 | 模型檢查；若涉及畫面入口，再執行相關 UI 流程 |
| 清單管理、編輯、抽選、紀錄或 sheet 協調 | 模擬器建置及相關 UI 流程，核對正常、取消與空狀態 |
| `.mealspin` 系統整合 | 格式檢查、外部開啟／App 內匯入、原生分享面板；跨裝置部分另做實機驗證 |
| 佈局、文字、輔助使用或主題 | 模擬器查看相關尺寸、深色模式、放大文字及減少動態效果，按需實測 VoiceOver 與觸覺 |
| 文件與截圖 | 核對程式依據、相對連結、圖說及圖片所呈現的版本 |

## 模型檢查

[Tests/ModelChecks.swift](../Tests/ModelChecks.swift) 與 `Models.swift` 可直接編譯成命令列程式，不需啟動模擬器：

```sh
xcrun swiftc -parse-as-library MealSpin/Models.swift Tests/ModelChecks.swift -o /tmp/mealspin-checks
/tmp/mealspin-checks
```

程式使用 `precondition` 驗證行為，成功時印出 `PASS`。涵蓋：

- 1–100 個選項、共 5,050 組指針位置。
- 預設清單建立、儲存／修改／刪除／重讀與紀錄清除。
- 儲存失敗後的狀態、損壞資料下每個寫入入口保留原始 bytes、重新讀取、備份內容與重建失敗保護。
- 分享格式往返、新 UUID 與獨立副本、隱私欄位、格式／版本／大小／長度驗證、圖示備援及空清單。
- 暫時排除、跨清單保留、重新啟動／全部參與恢復、分享完整清單與編輯／刪除後的設定整理。

## 匯入競態檢查

[Tests/ImportChecks.swift](../Tests/ImportChecks.swift) 使用可注入 reader 與 continuation 控制讀取完成順序，直接等待每個工作的完成，不以固定等待時間排序。

```sh
xcrun swiftc -parse-as-library MealSpin/Models.swift MealSpin/ListImportCoordinator.swift Tests/ImportChecks.swift -o /tmp/mealspin-import-checks
/tmp/mealspin-import-checks
```

檢查 A、B 反序完成、過期成功與錯誤、取消後遲到結果、清除待處理值及離開畫面所使用的 teardown 操作。這些是協調器檢查，不能代替真實檔案入口與草稿保持的 UI 驗收。

## UI 流程測試

共用的 [MealSpin scheme](../MealSpin.xcodeproj/xcshareddata/xcschemes/MealSpin.xcscheme) 將 [Tests/FlowTests.swift](../Tests/FlowTests.swift) 納入 `MealSpinUITests`：

```sh
xcodebuild -project MealSpin.xcodeproj -scheme MealSpin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO test
```

| 測試 | 流程範圍 |
| --- | --- |
| `testCreateSpinAndReload` | 切換清單、建立單選項清單、抽選、重開後選取偏好與紀錄 |
| `testDiscardAndEmptyList` | 繼續編輯、放棄修改、空清單導向新增選項 |
| `testImportPreviewCancelAndSave` | 外部檔案開啟、預覽／取消、儲存與同名副本 |
| `testSharingPresentsSystemSheet` | 檔案分享與系統面板的儲存／拷貝動作 |
| `testTemporaryParticipation` | 暫停、過濾後抽選、切換清單保留、全部暫停、恢復與重新啟動 |
| `testRecoveryRebuildRetainsExportAfterRelaunch` | 損壞資料、備份、放棄重建、確認重建及重開後副本匯出入口 |
| `testReduceMotionRecordsEachSpinOnce` | 無動畫分支連續抽選兩次，紀錄只有兩筆 |
| `testMaximumTypeOperationsInPortraitAndLandscape` | 最大字級選取、編輯入口、抽選、分享及橫向操作 |
| `testMaximumTypeRecoveryRemainsReachable` | 最大字級備份、匯出入口及重建後主操作 |
| `testPseudoLocalizedLongContentAtMaximumType` | 雙倍 App 文案、最大字級、長名稱與長食物的建立、抽選、分享頁與實際檔案匯入 |

`--ui-testing` 使用獨立的 `Documents/ui-tests.json` 與 `Documents/UITest Recovery` 副本目錄。`--reset-test-data` 刪除這兩處測試資料並清除 `selectedFoodList` 偏好，不刪除正式資料或正式回復副本。正式資料契約見 [架構文件](architecture.md#狀態與儲存)。

以下附加參數只在 `--ui-testing` 下生效：

- `--corrupt-test-data` 在測試檔案寫入無效資料，進入回復流程。
- `--maximum-type` 透過 iOS 17 的 `UIWindowScene.traitOverrides` 將整個視窗設為最大輔助使用字級，涵蓋 SwiftUI 與呈現的 sheet。
- `--reduce-motion` 讓轉盤採用相同的無動畫完成分支。這能驗證分支與紀錄次數，不能代替從系統設定切換 Reduce Motion 的操作驗收。

外部檔案測試會將後續啟動參數改為只含 `--ui-testing`，避免開啟文件時再次清除已建立的測試資料。

### 驗證延遲匯入與草稿

開啟編輯畫面並輸入尚未儲存的內容。從系統「檔案」或其他 App 將 `.mealspin` 交給正在執行的 MealSpin，確認編輯內容仍在，結束編輯後才顯示匯入預覽。讀取期間亦須檢查取消與離開清單庫。

XCTest 的 `XCUIApplication.open(_:)` 具有啟動 App 的語意，不能用它證明原有程序中的草稿得以保留。現有外部檔案測試涵蓋開啟、預覽、取消與儲存；延遲讀取期間的真實草稿保持仍須另外操作驗收。

## 核對文字擷取與輔助使用

建置設定啟用 `SWIFT_EMIT_LOC_STRINGS`，`Localizable.xcstrings` 納入 App Resources。先以固定的 DerivedData 位置建置，再同步 App target 的擷取結果。以下陣列語法適用於 macOS 預設的 zsh：

```sh
xcodebuild -project MealSpin.xcodeproj -scheme MealSpin \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/mealspin-localization CODE_SIGNING_ALLOWED=NO build
app_stringsdata=(/tmp/mealspin-localization/Build/Intermediates.noindex/MealSpin.build/Debug-iphonesimulator/MealSpin.build/Objects-normal/*/*.stringsdata)
xcrun xcstringstool sync MealSpin/Localizable.xcstrings --stringsdata "${app_stringsdata[@]}"
```

同步後核對繁體中文資源，再執行相同建置命令確認 Catalog 可編譯。不要傳入 UI 測試 target 的擷取結果，也不要將清單名稱、食物與歷史快照當成翻譯文案。

以 Xcode 偽本地化的長文字檢查首頁、編輯、分享、匯入與回復。`testPseudoLocalizedLongContentAtMaximumType` 以 `-NSDoubleLocalizedStrings YES` 啟用雙倍文案，先確認 App 標題確實加長，再確認使用者食物名稱仍保持原文。此參數的語意見 [Apple 的偽本地化測試說明](https://developer-mdn.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/TestingYourInternationalApp/TestingYourInternationalApp.html)。雙倍文案模式的數值插值可能顯示額外的 placeholder 文字，須與一般語系的數值顯示分開判讀。以最大字級操作，記錄裝置、OS、視窗尺寸、方向、明暗模式與操作結果。使用 VoiceOver 完成建立、抽選與匯入，另在系統開關 Reduce Motion 後重驗抽選。一般字級截圖不代表最大字級驗收；測試旗標也不代表系統設定已實測。

## 截圖素材

[docs/images](images) 保存 README 與安裝教學使用的實際 App 畫面。UI 測試使用 `XCTAttachment`，並將畫面附件設為 `keepAlways`；測試結果可在 Xcode 的 Report navigator 檢視。

更新圖片時，先確定目標畫面已完成轉場、內容與按鈕可讀，再擷取相關功能。將匯出的 PNG 放入 `docs/images/`，沿用引用檔名或同步更新文件引用，並檢查圖說與介面文字。

現有素材涵蓋首頁、清單庫、編輯、參與項目與分享選擇；測試附件中的資料可能包含測試用名稱，挑選素材時應核對是否適合作為使用者教學。

## 實機驗證範圍

模擬器測試可確認操作流程、格式與系統面板；AirDrop、訊息實際跨裝置傳送、個人帳號簽署與到期後重新安裝，需在實體裝置上另外驗證。回報結果時，區分已執行的測試、程式核對與尚未執行的實機情境。
