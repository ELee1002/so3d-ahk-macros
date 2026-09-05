# 希望戀曲 AHK 巨集（自寫）

AutoHotkey v2 + AHI（AutoHotInterception）遊戲自動化腳本。

## 主要腳本

| 腳本 | 說明 |
|------|------|
| `爆破山脈-終.ahk` | 練功 + 滿包自動丟山脈雜物 + 丟完暫停 3:30 |
| `爆破廢墟-終.ahk` | 練功 + 滿包自動丟寶石 + 丟完暫停 3:30 |
| `爆破山脈.ahk` | 純練功（無自動丟棄） |
| `丟山脈雜物.ahk` | 手動三頁丟山脈雜物 |
| `丟廢墟垃圾.ahk` | 手動三頁丟寶石 |
| `補師補血.ahk` | 補血循環 |
| `聖賢掛機.ahk` | 掛機 |
| `喊收.ahk` | 定時喊收 |

## 設定

- 共用設定：`cfg.txt`（滑鼠/鍵盤 ID、shift、延遲等）
- 找圖素材：`Lib\` 目錄（無副檔名）

## 需求

- AutoHotkey v2.0
- [AutoHotInterception](https://github.com/evilC/AutoHotInterception)
- 遊戲視窗：`SO3DPlus.exe` / `ahk_class SO3D`

## 熱鍵（多數腳本）

- F1 開始 / F2 停止
- F3 重載 / Ctrl+Esc 關閉
