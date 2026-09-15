/*  新爆破練功 (AHI 版)
 *  找快捷鍵錨點 → X+30 每 0.25 秒點一次共 15 秒 → 再 +30 點 3 次 → 循環
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global spamSec := 15
global press2Count := 3
global spamInterval := 250
global clickHoldMs := 50
global click2HoldMs := 80
global click2GapMs := 150
global slotSwitchMs := 400
global loopCount := 0
global currentPhase := "待機"

global trainPhase := "idle"       ; idle | click1 | gap12 | click2 | gap21
global spamEndTick := 0
global nextTick := 0
global mouseHeld := false
global press2Left := 0
global clickStep := ""            ; down | up

global imgVar := 30
global anchorImg := "快捷鍵錨點.bmp"
global slotOffset := 30
global anchorX := 0
global anchorY := 0
global click1X := 0
global click1Y := 0
global click2X := 0
global click2Y := 0
global anchorSet := false

global infoText := "
(
【功能】
循環執行：
1. 找快捷鍵錨點
2. 錨點 X+30 每 0.25 秒點一次（點擊1）共 15 秒
3. 先放開再等待，避免拖拽
4. 再 +30 點 3 次（點擊2）
5. 回到步驟 2

【備註】
需 Lib\快捷鍵錨點.bmp
F2 立即停止並放開滑鼠
)"
global hotkeyText := "
(
【熱鍵】
F1/F2 或下方按鈕
F3 重載  Ctrl+Esc 關
)"

InitApp()
return

F1::StartTrain()
F2::StopTrain()
F3::{
    StopTrain()
    Reload
}
^Esc::ExitApp

OnExit(*) {
    StopTrain()
    SetTimer(TrainTick, 0)
    SetTimer(EnsureStopped, 0)
    SetTimer(RefreshGamePos, 0)
}

IsTrainActive() {
    global running, trainPhase
    return running && trainPhase != "idle"
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

MoveGame(x, y) {
    global winX, winY, shfitX, shfitY, mouseID, AHI
    RefreshGameRect()
    AHI.SendMouseMoveAbsolute(mouseID
        , ((x + winX + shfitX) / A_ScreenWidth) * 65535
        , ((y + winY + shfitY) / A_ScreenHeight) * 65535)
}

MouseDown() {
    global mouseID, AHI, mouseHeld, running
    if !running || mouseHeld
        return
    AHI.SendMouseButtonEvent(mouseID, 0, 1)
    mouseHeld := true
}

MouseUp() {
    global mouseID, AHI, mouseHeld
    if !mouseHeld
        return
    AHI.SendMouseButtonEvent(mouseID, 0, 0)
    mouseHeld := false
}

EnsureMouseUp() {
    global mouseHeld, mouseID, AHI
    mouseHeld := false
    Loop 2
        try AHI.SendMouseButtonEvent(mouseID, 0, 0)
}

ForceReleaseAll() {
    EnsureMouseUp()
    ReleaseAllKeys()
}

EnsureStopped(*) {
    global running
    if running
        return
    ForceReleaseAll()
}

FindHotkeyAnchor() {
    global anchorImg, anchorX, anchorY, click1X, click1Y, click2X, click2Y
    global slotOffset, anchorSet, currentStatus

    if !FileExist(ImgPath(anchorImg)) {
        currentStatus := "找不到圖檔"
        state()
        FlashMsg("缺少 Lib\" . anchorImg)
        return false
    }
    if !SearchInGame(anchorImg, &ax, &ay, "*30 ") {
        currentStatus := "找不到錨點"
        state()
        FlashMsg("找不到快捷鍵錨點")
        return false
    }
    anchorX := ax
    anchorY := ay
    click1X := ax + slotOffset
    click1Y := ay
    click2X := click1X + slotOffset
    click2Y := ay
    anchorSet := true
    return true
}

BeginClick1() {
    global trainPhase, spamEndTick, nextTick, currentPhase, spamSec, running, clickStep
    if !running
        return
    MouseUp()
    trainPhase := "click1"
    clickStep := "down"
    spamEndTick := A_TickCount + spamSec * 1000
    nextTick := A_TickCount
    currentPhase := "點擊1 (" spamSec " 秒)"
    state()
}

BeginGap(nextPhase, label) {
    global trainPhase, nextTick, currentPhase, running, slotSwitchMs
    if !running
        return
    MouseUp()
    trainPhase := nextPhase
    nextTick := A_TickCount + slotSwitchMs
    currentPhase := label
    state()
}

BeginClick2() {
    global trainPhase, press2Left, clickStep, nextTick, currentPhase, press2Count, running
    if !running
        return
    MouseUp()
    trainPhase := "click2"
    press2Left := press2Count
    clickStep := "down"
    nextTick := A_TickCount
    currentPhase := "點擊2 x" press2Count
    state()
}

StartTrain() {
    global running, currentStatus, loopCount
    if running
        return
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    if !FindHotkeyAnchor()
        return
    SetTimer(EnsureStopped, 0)
    loopCount := 0
    running := true
    currentStatus := "運行中"
    BeginClick1()
    SetTimer(TrainTick, 10)
    state()
}

StopTrain() {
    global running, currentStatus, currentPhase, trainPhase
    running := false
    trainPhase := "idle"
    Thread "NoTimers", true
    SetTimer(TrainTick, 0)
    ForceReleaseAll()
    Thread "NoTimers", false
    SetTimer(EnsureStopped, -20)
    SetTimer(EnsureStopped, -80)
    SetTimer(EnsureStopped, -200)
    currentStatus := "已暫停"
    currentPhase := "待機"
    state()
}

TrainTick() {
    global trainPhase, spamEndTick, nextTick, press2Left, clickStep
    global loopCount, spamInterval, clickHoldMs, click2HoldMs, click2GapMs
    global currentPhase, click1X, click1Y, click2X, click2Y, spamSec

    if !IsTrainActive()
        return

    now := A_TickCount

    if trainPhase == "click1" {
        if now >= spamEndTick {
            MouseUp()
            if !IsTrainActive()
                return
            BeginGap("gap12", "放開後等待，再點擊2")
            return
        }
        if now < nextTick
            return
        if !IsTrainActive()
            return
        remainSec := Max(0, Ceil((spamEndTick - now) / 1000))
        currentPhase := "點擊1 剩 " remainSec " 秒"
        if clickStep == "down" {
            MoveGame(click1X, click1Y)
            MouseDown()
            if !IsTrainActive()
                return
            clickStep := "up"
            nextTick := now + clickHoldMs
            state()
            return
        }
        MouseUp()
        if !IsTrainActive()
            return
        clickStep := "down"
        nextTick := now + Max(1, spamInterval - clickHoldMs)
        return
    }

    if trainPhase == "gap12" {
        if now < nextTick
            return
        if !IsTrainActive()
            return
        BeginClick2()
        return
    }

    if trainPhase == "gap21" {
        if now < nextTick
            return
        if !IsTrainActive()
            return
        BeginClick1()
        return
    }

    if trainPhase == "click2" {
        if now < nextTick
            return
        if !IsTrainActive()
            return
        if clickStep == "down" {
            MoveGame(click2X, click2Y)
            MouseDown()
            if !IsTrainActive()
                return
            clickStep := "up"
            nextTick := now + click2HoldMs
            return
        }
        MouseUp()
        if !IsTrainActive()
            return
        press2Left--
        if press2Left <= 0 {
            loopCount++
            currentPhase := "第 " loopCount " 輪完成"
            state()
            if !IsTrainActive()
                return
            BeginGap("gap21", "放開後等待，再點擊1")
            return
        }
        clickStep := "down"
        nextTick := now + click2GapMs
        currentPhase := "點擊2 剩 " press2Left " 次"
        state()
    }
}

state() {
    global currentStatus, currentPhase, loopCount, spamSec, press2Count
    global win_width, win_height, winPosSet, clientW, clientH
    global anchorSet, anchorX, anchorY, click1X, click2X

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"
    anchorInfo := anchorSet
        ? "錨點: " anchorX "," anchorY "  點1x=" click1X "  點2x=" click2X
        : "錨點: 尚未定位"

    SetStatusText("【現況】`r`n"
        . "設定: 點1 " spamSec " 秒/0.25s → 點2 x" press2Count "`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . "已完成: " loopCount " 輪`r`n"
        . anchorInfo "`r`n"
        . posInfo)
}

InitApp() {
    ini()
    BuildMacroPanel("新爆破練功", infoText, hotkeyText, StartTrain, StopTrain)
    state()
    SetTimer(RefreshGamePos, 500)
}
