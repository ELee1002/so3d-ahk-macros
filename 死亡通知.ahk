/*  死亡通知
 *  偵測 Lib\血條（倒地血條）→ Discord webhook 通知
 *  可與練功／小幫手並行（熱鍵不用 F1/F2）
 */
#Requires AutoHotkey v2.0
#Include Common.ahk
#SingleInstance Force

LoadCommonCfg()

global deathImg := "血條"
global imgVar := 20
global scanMs := 500
global notifyCount := 0
global deathSeen := false
global lastNotifyAt := ""
global currentPhase := "監看中"
global lastWebhookOk := ""
global hitScansNeeded := 3
global clearScansNeeded := 20
global notifyCooldownMs := 120000
global hitScans := 0
global clearScans := 0
global lastNotifyTick := 0

global infoText := "
(
【功能】
開啟後持續找圖：血條
連續找到 3 次才當死亡
發過後要消失 10 秒才重新武裝
兩次通知至少間隔 2 分鐘

【備註】
開啟後自動監看
設定要勾[狀態資訊]
cfg.txt 設定 discord_webhook=
圖檔放 Lib\血條（倒地才對得上）
)"
global hotkeyText := "
(
【熱鍵】
Ctrl+Z 開始
Ctrl+X 暫停
Ctrl+C 重載
Ctrl+Esc 關閉
)"

InitApp()
return

^z::StartWatch()
^x::StopWatch()
^c::{
    StopWatch()
    Reload
}
^Esc::ExitApp

OnExit(*) {
    StopWatch()
    SetTimer(WatchTick, 0)
    SetTimer(RefreshGamePos, 0)
}

RefreshGameRect() {
    global winX, winY, win_width, win_height, winPosSet
    hwnd := GetGameHwnd()
    if !hwnd
        return false
    WinGetPos(&winX, &winY, &win_width, &win_height, "ahk_id " hwnd)
    winPosSet := win_width ? 1 : 0
    return winPosSet
}

ImgPath(name) {
    return A_ScriptDir "\Lib\" name
}

SearchInGame(name, &outX, &outY, variation := "") {
    global imgVar, win_width, win_height
    if !RefreshGameRect()
        return false
    path := ImgPath(name)
    if !FileExist(path)
        return false
    var := variation != "" ? variation : "*" imgVar " "
    outX := 0, outY := 0
    try {
        if ImageSearch(&outX, &outY, 0, 0, win_width, win_height, var path)
            return true
    }
    return false
}

StartWatch() {
    global running, currentStatus, currentPhase, deathSeen, hitScans, clearScans
    if running
        return
    deathSeen := false
    hitScans := 0
    clearScans := 0
    running := true
    currentStatus := "持續監看"
    currentPhase := "監看中"
    SetTimer(WatchTick, scanMs)
    state()
}

StopWatch(*) {
    global running, currentStatus, currentPhase
    running := false
    SetTimer(WatchTick, 0)
    currentStatus := "已暫停"
    currentPhase := "待機"
    state()
}

WatchTick(*) {
    global running, deathImg, deathSeen, notifyCount, lastNotifyAt, currentPhase, currentStatus, imgVar
    global hitScans, clearScans, hitScansNeeded, clearScansNeeded, notifyCooldownMs, lastNotifyTick
    if !running
        return
    if !FileExist(ImgPath(deathImg)) {
        if currentStatus != "找不到圖檔" {
            currentStatus := "找不到圖檔"
            currentPhase := "等待 Lib\" . deathImg
            state()
        }
        return
    }
    if GetWebhookUrl() == "" {
        if currentStatus != "未設定 webhook" {
            currentStatus := "未設定 webhook"
            currentPhase := "等待 cfg discord_webhook"
            state()
        }
        return
    }
    if currentStatus != "持續監看" {
        currentStatus := "持續監看"
        state()
    }
    found := SearchInGame(deathImg, &x, &y, "*" imgVar " ")
    if found {
        clearScans := 0
        if deathSeen
            return
        hitScans++
        if hitScans < hitScansNeeded {
            currentPhase := "疑似死亡 " hitScans "/" hitScansNeeded
            state()
            return
        }
        if A_TickCount - lastNotifyTick < notifyCooldownMs {
            currentPhase := "冷卻中，不重複通知"
            state()
            return
        }
        deathSeen := true
        currentPhase := "確認死亡，發送 DC"
        state()
        stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        msg := "【希望戀曲】偵測到死亡（血條）  " stamp
        if SendDiscord(msg) {
            notifyCount++
            lastNotifyAt := stamp
            lastNotifyTick := A_TickCount
            currentPhase := "已通知 Discord"
        } else {
            currentPhase := "DC 發送失敗"
            deathSeen := false
            hitScans := 0
        }
        state()
        return
    }
    hitScans := 0
    if !deathSeen
        return
    ; 復活瞬間血條可能閃現，要連續消失一段時間才重新武裝
    clearScans++
    if clearScans < clearScansNeeded {
        currentPhase := "已復活 " clearScans "/" clearScansNeeded
        state()
        return
    }
    deathSeen := false
    clearScans := 0
    currentPhase := "監看中"
    state()
}

state() {
    global currentStatus, currentPhase, notifyCount, lastNotifyAt, lastWebhookOk
    global win_width, win_height, winPosSet, clientW, clientH, deathImg

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"
    lastInfo := lastNotifyAt != "" ? lastNotifyAt : "尚無"
    hookInfo := lastWebhookOk != "" ? lastWebhookOk : (GetWebhookUrl() != "" ? "已設定" : "未設定")

    SetStatusText("【現況】`r`n"
        . "找圖: " deathImg "`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . "已通知: " notifyCount " 次  上次: " lastInfo "`r`n"
        . "DC: " hookInfo "`r`n"
        . posInfo)
}

InitApp() {
    ini()
    BuildMacroPanel("死亡通知", infoText, hotkeyText, StartWatch, StopWatch)
    StartWatch()
    SetTimer(RefreshGamePos, 500)
}
