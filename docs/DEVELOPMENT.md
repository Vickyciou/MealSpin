# MealSpin 開發說明

[使用者介紹與安裝方式](../README.md) · [完整安裝教學](INSTALL.md)

## 專案概況

原生 SwiftUI iOS App，最低支援 iOS 17，適用於 iPhone 與 iPad。沒有外部套件或網路服務依賴。

開啟 `MealSpin.xcodeproj`，選擇 `MealSpin` scheme 與已安裝 runtime 的 iPhone 模擬器，按 Run。實體裝置的簽署方式見安裝教學；專案未預設開發團隊。

## 資料與抽選

- `MealSpin/Models.swift` 定義清單、抽選紀錄、資料儲存與分享格式。
- 清單與最近 100 筆紀錄以 JSON 原子寫入 App 的 `Documents/meals.json`；刪除 App 會移除本機資料。
- 每個參與選項機率相同，轉盤依抽選結果計算停下的位置，使指針與結果對齊。
- 本次參與設定只保存在記憶體，切換清單後保留，重新啟動 App 後恢復全部參與；不會寫入儲存資料或分享檔案。
- 超過 20 個參與選項時，轉盤隱藏扇區文字；完整名稱仍可在參與項目面板查看。
- 沒有權重、雲端同步、地圖查詢或訂餐功能。

## 介面行為

首頁使用全寬清單選擇器、固定底部抽選按鈕與結果區。清單卡片開啟搜尋／管理面板；可直接查看參與項目、編輯及分享。

支援深色模式、Dynamic Type、觸覺回饋、VoiceOver 結果朗讀、減少動態效果、放棄修改確認與記住上次清單。

## 分享與匯入

- `MealSpin/ListSharing.swift` 處理檔案讀寫、文字分享、原生分享面板與匯入預覽。
- `.mealspin` 內容包含格式版本、清單名稱、圖示與選項，不包含本機識別碼或抽選紀錄。
- 匯入預覽按「加入我的清單」後才寫入；取消不改變資料。同名清單建立獨立副本。
- 匯入限制為 1 MB、名稱 120 字、最多 500 個選項、每項 200 字。空白與重複項目會整理，不支援的圖示使用預設值。
- 編輯或抽選時收到外部檔案，會等待目前操作結束後才顯示匯入預覽。
- 分享與編輯使用完整清單，不受本次暫停項目影響。
- AirDrop 與訊息的跨裝置傳送，需要以實體裝置另外驗證。

## 驗證方式

請把以下 simulator destination 換成自己電腦已安裝的裝置與 runtime。

```sh
xcodebuild -project MealSpin.xcodeproj -scheme MealSpin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO test
```

`Tests/FlowTests.swift` 包含建立清單、抽選、重開後的清單與紀錄、放棄修改、空白清單、匯入預覽／取消／同名副本、系統分享面板與暫時參與項目測試，並保留畫面附件。測試使用獨立的 `ui-tests.json`；選取清單仍透過 App 的 `selectedFoodList` 偏好設定記憶。

不需啟動模擬器的資料與轉盤幾何測試：

```sh
xcrun swiftc -parse-as-library MealSpin/Models.swift Tests/ModelChecks.swift -o /tmp/mealspin-checks
/tmp/mealspin-checks
```

`Tests/ModelChecks.swift` 涵蓋 1–100 個選項的 5,050 組指針位置，以及新增／修改／刪除／重讀、紀錄、儲存失敗、損壞資料保留、分享格式往返、獨立匯入副本、隱私欄位、異常檔案與暫時參與設定。

## README 圖片

`docs/images/` 使用實際執行的 App 截圖。更新介面後，請重新擷取相應畫面並確認 README 的圖說與按鈕名稱。
