# MealSpin 開發說明

本文件提供開發環境、建置、測試與畫面素材的操作方式。產品範圍、狀態及檔案契約分別見對應文件。

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
- 儲存失敗後的狀態，以及讀取損壞資料時保留原始檔案。
- 分享格式往返、新 UUID 與獨立副本、隱私欄位、格式／版本／大小／長度驗證、圖示備援及空清單。
- 暫時排除、跨清單保留、重新啟動／全部參與恢復、分享完整清單與編輯／刪除後的設定整理。

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

`--ui-testing` 讓 App 使用獨立的 `Documents/ui-tests.json`；加上 `--reset-test-data` 會在啟動時刪除該測試檔案。選取清單仍使用一般的 `selectedFoodList` 偏好設定，因此這兩個參數不是完整的偏好重設；正式資料檔案與狀態契約見 [架構文件](architecture.md#狀態與儲存)。

外部檔案測試會將後續啟動參數改為只含 `--ui-testing`，避免開啟文件時再次清除已建立的測試資料。

## 截圖素材

[docs/images](images) 保存 README 與安裝教學使用的實際 App 畫面。UI 測試使用 `XCTAttachment`，並將畫面附件設為 `keepAlways`；測試結果可在 Xcode 的 Report navigator 檢視。

更新圖片時，先確定目標畫面已完成轉場、內容與按鈕可讀，再擷取相關功能。將匯出的 PNG 放入 `docs/images/`，沿用引用檔名或同步更新文件引用，並檢查圖說與介面文字。

現有素材涵蓋首頁、清單庫、編輯、參與項目與分享選擇；測試附件中的資料可能包含測試用名稱，挑選素材時應核對是否適合作為使用者教學。

## 實機驗證範圍

模擬器測試可確認操作流程、格式與系統面板；AirDrop、訊息實際跨裝置傳送、個人帳號簽署與到期後重新安裝，需在實體裝置上另外驗證。回報結果時，區分已執行的測試、程式核對與尚未執行的實機情境。
