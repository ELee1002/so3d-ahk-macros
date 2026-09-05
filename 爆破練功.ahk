/*  爆破練功 (AHI 版)
 *  功能1：高速連打 1 共 15 秒 → 按 2 共 3 次 → 循環
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global spamSec := 15
global press2Count := 3
global spamInterval := 10
global loopCount := 0
global currentPhase := "待機"

global trainPhase := "idle"       ; idle | spam1 | press2
global spamEndTick := 0
global nextTick := 0
global key1Held := false
global key2Held := false
global press2Left := 0
global press2Step := ""           ; down | up

global SC1 := 0
global SC2 := 0

global infoText := "
(
【功能1】
循環執行：
1. 高速連打 1 共 15 秒
2. 按 2 共 3 次
3. 回到步驟 1

【備註】
F2 立即停止並放開所有按鍵
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

Key1Down() {
    global keyboardId, AHI, key1Held, SC1, running
    if !running || key1Held
        return
    AHI.SendKeyEvent(keyboardId, SC1, 1)
    key1Held := true
}

Key1Up() {
    global keyboardId, AHI, key1Held, SC1
    if !key1Held
        return
    AHI.SendKeyEvent(keyboardId, SC1, 0)
    key1Held := false
}

Key2Down() {
    global keyboardId, AHI, key2Held, SC2, running
    if !running || key2Held
        return
    AHI.SendKeyEvent(keyboardId, SC2, 1)
    key2Held := true
}

Key2Up() {
    global keyboardId, AHI, key2Held, SC2
    if !key2Held
        return
    AHI.SendKeyEvent(keyboardId, SC2, 0)
    key2Held := false
}

ForceReleaseAll() {
    global keyboardId, AHI, SC1, SC2, key1Held, key2Held
    key1Held := false
    key2Held := false
    ReleaseAllKeys()
    try AHI.SendKeyEvent(keyboardId, SC1, 0)
    try AHI.SendKeyEvent(keyboardId, SC2, 0)
}

EnsureStopped(*) {
    global running
    if running
        return
    ForceReleaseAll()
}

BeginSpam1() {
    global trainPhase, spamEndTick, nextTick, currentPhase, spamSec, running
    if !running
        return
    Key2Up()
    trainPhase := "spam1"
    spamEndTick := A_TickCount + spamSec * 1000
    nextTick := A_TickCount
    currentPhase := "連打 1 (" spamSec " 秒)"
    state()
}

BeginPress2() {
    global trainPhase, press2Left, press2Step, nextTick, currentPhase, press2Count, running
    if !running
        return
    Key1Up()
    trainPhase := "press2"
    press2Left := press2Count
    press2Step := "down"
    nextTick := A_TickCount
    currentPhase := "按 2 x" press2Count
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
    SetTimer(EnsureStopped, 0)
    loopCount := 0
    running := true
    currentStatus := "運行中"
    BeginSpam1()
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
    global running, trainPhase, spamEndTick, nextTick
    global press2Left, press2Step, loopCount, spamInterval, currentPhase

    if !IsTrainActive()
        return

    now := A_TickCount

    if trainPhase == "spam1" {
        if !IsTrainActive()
            return
        if now >= spamEndTick {
            Key1Up()
            if !IsTrainActive()
                return
            BeginPress2()
            return
        }
        if now < nextTick
            return
        if !IsTrainActive()
            return
        if !key1Held
            Key1Down()
        else
            Key1Up()
        if !IsTrainActive()
            return
        nextTick := now + spamInterval
        return
    }

    if trainPhase == "press2" {
        if !IsTrainActive()
            return
        if now < nextTick
            return
        if !IsTrainActive()
            return
        if press2Step == "down" {
            Key2Down()
            if !IsTrainActive()
                return
            press2Step := "up"
            nextTick := now + 80
            return
        }
        Key2Up()
        if !IsTrainActive()
            return
        press2Left--
        if press2Left <= 0 {
            loopCount++
            currentPhase := "第 " loopCount " 輪完成"
            state()
            if !IsTrainActive()
                return
            BeginSpam1()
            return
        }
        press2Step := "down"
        nextTick := now + 150
    }
}

state() {
    global currentStatus, currentPhase, loopCount, spamSec, press2Count
    global win_width, win_height, winPosSet, clientW, clientH, running

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"

    SetStatusText("【現況】`r`n"
        . "設定: 1 連打 " spamSec " 秒 → 2 x" press2Count "`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . "已完成: " loopCount " 輪`r`n"
        . posInfo)
}

InitApp() {
    global SC1, SC2
    SC1 := GetKeySC("1")
    SC2 := GetKeySC("2")
    ini()
    BuildMacroPanel("爆破練功", infoText, hotkeyText, StartTrain, StopTrain)
    state()
    SetTimer(RefreshGamePos, 500)
}
