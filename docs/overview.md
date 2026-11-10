# MealSpin 專案總覽

本文件說明產品用途、功能邊界與技術背景，供初次接觸專案的維護者快速掌握全貌。

[專案指引](../AGENTS.md) · [架構](architecture.md) · [模組](modules.md) · [開發](DEVELOPMENT.md) · [安裝](INSTALL.md)

## 產品目的

MealSpin（手機顯示名稱為「今天吃什麼」）讓使用者將餐廳或食物放進清單，再用轉盤決定下一餐。操作介紹與實際畫面見 [README](../README.md)。

App 以個人裝置上的清單為中心，日常操作可離線使用，沒有 App 帳號、廣告、訂閱或付費功能。

## 功能範圍

| 功能 | 目前提供的行為 |
| --- | --- |
| 清單 | 首次使用提供早餐、平價晚餐與奢華晚餐範例；可建立、搜尋、切換、編輯與刪除清單 |
| 選項 | 可新增、修改、刪除、排序與貼上多行文字；可暫停部分項目參與抽選 |
| 轉盤 | 從參與項目等機率抽選，轉盤停下後顯示結果 |
| 紀錄 | 自動保留近期抽選結果，可檢視或清除 |
| 分享 | 可傳文字，或匯出／匯入 `.mealspin` 清單檔案 |
| 輔助使用 | 支援深色模式、Dynamic Type、VoiceOver 結果朗讀、減少動態效果與觸覺回饋 |

目前沒有權重設定、附近餐廳搜尋、地圖、訂餐、App 提供的雲端同步或多人即時共用。資料保存與暫停設定的生命週期見 [架構文件](architecture.md#狀態與儲存)。

## 技術與執行環境

| 項目 | 現況 |
| --- | --- |
| 平台 | iOS／iPadOS 17 起，支援 iPhone 與 iPad |
| 專案 | 單一 Xcode 專案，包含 `MealSpin` App target 與 `MealSpinUITests` UI 測試 target |
| 語言與畫面 | Swift、SwiftUI；專案設定為 Swift 5 語言模式 |
| 狀態與資料 | Observation、Foundation；儲存及整合細節見架構文件 |
| 系統整合 | UIKit 原生分享面板、UniformTypeIdentifiers 檔案型別 |
| 驗證 | XCTest UI 流程，以及可獨立執行的模型檢查 |
| 相依性 | 專案沒有外部套件相依性，也沒有自建後端或網路 API 整合 |

平台與 target 設定以 [project.pbxproj](../MealSpin.xcodeproj/project.pbxproj) 為準；實際裝置安裝方式見 [安裝教學](INSTALL.md)。

## 文件分工

| 文件 | 內容與使用時機 |
| --- | --- |
| [架構與整合契約](architecture.md) | 理解共用狀態、資料保存、抽選流程與分享格式 |
| [模組責任](modules.md) | 找到功能所在檔案，確認呼叫與資料擁有關係 |
| [開發說明](DEVELOPMENT.md) | 建置、選擇測試、擷取畫面及確認驗證範圍 |
| [安裝教學](INSTALL.md) | 從下載專案到安裝進自己的手機 |

主要證據：[App 入口](../MealSpin/MealSpinApp.swift)、[首頁](../MealSpin/ContentView.swift)、[資料模型](../MealSpin/Models.swift)、[檔案分享](../MealSpin/ListSharing.swift)。
