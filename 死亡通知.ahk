/*  死亡通知
 *  偵測 Lib\有人死亡.bmp → Discord webhook 通知
 *  可與練功／小幫手並行（熱鍵不用 F1/F2）
 */
#Requires AutoHotkey v2.0
#Include Common.ahk
#SingleInstance Force

LoadCommonCfg()

global deathImg := "有人死亡.bmp"
global imgVar := 30
global scanMs := 500
global notifyCount := 0
global deathSeen := false
global lastNotifyAt := ""
global currentPhase := "待機"
global lastWebhookOk := ""

global infoText := "
(
【功能】
循環找圖：有人死亡.bmp
找到就發 Discord 通知
圖還在畫面上不會重複發
圖消失後再出現才再通知

【備註】
cfg.txt 設定 discord_webhook=
圖檔放 Lib\有人死亡.bmp
)"
global hotkeyText := "
(
【熱鍵】
F7/F8 或下方按鈕
F3 重載  Ctrl+Esc 關
)"

InitApp()
return

F7::StartWatch()
F8::StopWatch()
F3::{
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

GetWebhookUrl() {
    url := read("discord_webhook", 0)
    url := Trim(url)
    if url == "" || !InStr(url, "https://")
        return ""
    return url
}

JsonEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    return s
}

SendDiscord(content) {
    global lastWebhookOk
    url := GetWebhookUrl()
    if url == "" {
        lastWebhookOk := "未設定 webhook"
        return false
    }
    body := '{"content":"' JsonEscape(content) '"}'
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", url, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(body)
        code := Integer(http.Status)
        lastWebhookOk := (code >= 200 && code < 300) ? "已送出" : "HTTP " code
        return code >= 200 && code < 300
    } catch as e {
        lastWebhookOk := "送出失敗"
        return false
    }
}

StartWatch() {
    global running, currentStatus, currentPhase, deathImg, deathSeen, notifyCount
    if running
        return
    if !FileExist(ImgPath(deathImg)) {
        currentStatus := "找不到圖檔"
        state()
        FlashMsg("缺少 Lib\" . deathImg)
        return
    }
    if GetWebhookUrl() == "" {
        currentStatus := "未設定 webhook"
        state()
        FlashMsg("請在 cfg.txt 設定 discord_webhook=")
        return
    }
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    deathSeen := false
    running := true
    currentStatus := "運行中"
    currentPhase := "監看中"
    SetTimer(WatchTick, scanMs)
    state()
}

StopWatch() {
    global running, currentStatus, currentPhase
    running := false
    SetTimer(WatchTick, 0)
    currentStatus := "已暫停"
    currentPhase := "待機"
    state()
}

WatchTick(*) {
    global running, deathImg, deathSeen, notifyCount, lastNotifyAt, currentPhase
    if !running
        return
    found := SearchInGame(deathImg, &x, &y, "*30 ")
    if found {
        if deathSeen
            return
        deathSeen := true
        currentPhase := "偵測到死亡，發送 DC"
        state()
        stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        msg := "【希望戀曲】偵測到有人死亡  " stamp
        if SendDiscord(msg) {
            notifyCount++
            lastNotifyAt := stamp
            currentPhase := "已通知 Discord"
        } else {
            currentPhase := "DC 發送失敗"
            deathSeen := false
        }
        state()
        return
    }
    if deathSeen {
        deathSeen := false
        currentPhase := "監看中"
        state()
    }
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
    state()
    SetTimer(RefreshGamePos, 500)
}
