/*  聖賢掛機 (AHI 版)
 *  開場技能 → 1號循環 x5 → 重新開始
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global steps := []
global stepIdx := 0
global macroPhase := "idle"       ; idle | wait | step
global waitUntil := 0
global loopRound := 0
global currentPhase := "待機"

global infoText := "
(
【功能】
完整循環：
1. 開場技能序列
2. 1 號循環 x5
3. 回到步驟 1 無限重複

【1號循環】
每輪含 2 段：
等待34秒 → 1 → 3 → 等待20秒 → 3
→ 再等34秒 → 1 → 等待20秒 → 3 → 5
)"
global hotkeyText := "
(
【熱鍵】
F1/F2 或下方按鈕
Ctrl+R 開始  Ctrl+S 停止
F3 重載  Ctrl+Esc 關
)"

InitApp()
return

F1::StartMacro()
F2::StopMacro()
^r::StartMacro()
^s::StopMacro()
F3::{
    StopMacro()
    Reload
}
^Esc::ExitApp

OnExit(*) {
    StopMacro()
    SetTimer(MacroTick, 0)
    SetTimer(EnsureStopped, 0)
    SetTimer(RefreshGamePos, 0)
}

AddWait(stepsArr, ms, label := "") {
    stepsArr.Push({ t: "wait", ms: ms, label: label })
}

AddPress(stepsArr, key, dly := 0, label := "") {
    stepsArr.Push({ t: "press", k: key, dly: dly, label: label })
}

BuildSteps() {
    global steps
    steps := []

    AddWait(steps, 500, "開場準備")
    AddPress(steps, "5", 1000, "開場技能")
    AddPress(steps, "F2", 1000)
    AddPress(steps, "F3", 1000)
    AddPress(steps, "F4", 1000)
    AddPress(steps, "F5", 1000)
    AddPress(steps, "F6", 1000)
    AddPress(steps, "F8", 1000)
    AddPress(steps, "3", 1000)
    AddPress(steps, "1", 1000)
    AddPress(steps, "5", 0)
    AddWait(steps, 20000, "開場等待 20 秒")
    AddPress(steps, "3", 0, "開場收尾")

    Loop 5 {
        outer := A_Index
        Loop 2 {
            inner := A_Index
            AddWait(steps, 34000, "第 " outer "/5 輪 - 等待34秒 (" inner "/2)")
            AddPress(steps, "1", 1000)
            AddPress(steps, "3", 20000)
            AddPress(steps, "3", 0)
            AddWait(steps, 34000, "第 " outer "/5 輪 - 第二階段34秒 (" inner "/2)")
            AddPress(steps, "1", 20000)
            AddPress(steps, "3", 0)
        }
        AddWait(steps, 1000, "第 " outer "/5 輪 - 收尾")
        AddPress(steps, "5", 0)
    }
}

ForceReleaseAll() {
    global keyboardId, AHI
    ReleaseAllKeys()
    for key in ["1", "2", "3", "5", "F2", "F3", "F4", "F5", "F6", "F8"] {
        try
            AHI.SendKeyEvent(keyboardId, GetKeySC(key), 0)
    }
}

EnsureStopped(*) {
    global running
    if running
        return
    ForceReleaseAll()
}

StartMacro() {
    global running, currentStatus, stepIdx, loopRound, macroPhase
    if running
        return
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    SetTimer(EnsureStopped, 0)
    stepIdx := 0
    loopRound := 0
    running := true
    macroPhase := "step"
    currentStatus := "運行中"
    currentPhase := "開場技能"
    SetTimer(MacroTick, 50)
    state()
}

StopMacro() {
    global running, currentStatus, currentPhase, macroPhase, stepIdx
    running := false
    macroPhase := "idle"
    stepIdx := 0
    Thread "NoTimers", true
    SetTimer(MacroTick, 0)
    ForceReleaseAll()
    Thread "NoTimers", false
    SetTimer(EnsureStopped, -20)
    SetTimer(EnsureStopped, -80)
    SetTimer(EnsureStopped, -200)
    currentStatus := "已暫停"
    currentPhase := "待機"
    state()
}

MacroTick(*) {
    global running, macroPhase, waitUntil, stepIdx, steps
    global currentPhase, loopRound

    if !running || macroPhase == "idle"
        return

    if macroPhase == "wait" {
        if A_TickCount < waitUntil
            return
        macroPhase := "step"
    }

    if macroPhase != "step"
        return

    if !running
        return

    if stepIdx >= steps.Length {
        stepIdx := 0
        loopRound++
        currentPhase := "第 " loopRound " 輪完成 - 重新開場"
        state()
    }

    step := steps[stepIdx++]

    if step.t == "wait" {
        if step.label
            currentPhase := step.label
        waitUntil := A_TickCount + step.ms
        macroPhase := "wait"
        state()
        return
    }

    if step.t == "press" {
        if step.label
            currentPhase := step.label
        if !running
            return
        if !press(step.k, 30, 0)
            return
        if step.dly > 0 {
            waitUntil := A_TickCount + step.dly
            macroPhase := "wait"
        }
        state()
    }
}

state() {
    global currentStatus, currentPhase, loopRound
    global win_width, win_height, winPosSet, clientW, clientH, running

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"

    roundInfo := loopRound > 0
        ? "已完成大輪: " loopRound
        : "已完成大輪: 0"

    SetStatusText("【現況】`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . roundInfo "`r`n"
        . posInfo)
}

InitApp() {
    BuildSteps()
    ini()
    BuildMacroPanel("聖賢掛機", infoText, hotkeyText, StartMacro, StopMacro)
    state()
    SetTimer(RefreshGamePos, 500)
}
