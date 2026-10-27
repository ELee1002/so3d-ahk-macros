/*  聖賢掛機-天神 (AHI 版)
 *  開場 F1～F10 → 1號循環 x5 → 重新開始
 *  開場間隔、34 秒、20 秒都可調
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global steps := []
global stepIdx := 0
global macroPhase := "idle"
global waitUntil := 0
global loopRound := 0
global currentPhase := "待機"
global openGapMs := 400
global wait34Sec := 34
global wait20Sec := 20

global infoText := "
(
【功能】
開場 F1～F10，間隔預設 400ms
接著 1 號循環 x5，再重來

【1號循環】
等 N 秒 → 1 → 3 → 等 M 秒 → 3
→ 再等 N 秒 → 1 → 等 M 秒 → 3 → 5
N 預設 34 秒，M 預設 20 秒
)"
global hotkeyText := "
(
【熱鍵】
Ctrl+R 開始  Ctrl+S 停止
Alt+↑↓ 開場間隔 ±100ms
Ctrl+↑↓ 20秒 ±1  Ctrl+←→ 34秒 ±1
Ctrl+F3 重載  Ctrl+Esc 關
)"

InitApp()
return

^r::StartMacro()
^s::StopMacro()
!Up::AdjustOpenGap(100)
!Down::AdjustOpenGap(-100)
^Up::AdjustWait20(1)
^Down::AdjustWait20(-1)
^Left::AdjustWait34(-1)
^Right::AdjustWait34(1)
^F3::{
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
    global steps, openGapMs, wait34Sec, wait20Sec
    steps := []
    wait34 := wait34Sec * 1000
    wait20 := wait20Sec * 1000

    AddWait(steps, 500, "開場準備")
    Loop 10 {
        key := "F" A_Index
        AddPress(steps, key, openGapMs, "開場 " key)
    }
    AddWait(steps, wait20, "開場等待 " wait20Sec " 秒")
    AddPress(steps, "3", 0, "開場收尾")

    Loop 5 {
        outer := A_Index
        Loop 2 {
            inner := A_Index
            AddWait(steps, wait34, "第 " outer "/5 輪 - 等待" wait34Sec "秒 (" inner "/2)")
            AddPress(steps, "1", 1000)
            AddPress(steps, "3", wait20)
            AddPress(steps, "3", 0)
            AddWait(steps, wait34, "第 " outer "/5 輪 - 第二階段" wait34Sec "秒 (" inner "/2)")
            AddPress(steps, "1", wait20)
            AddPress(steps, "3", 0)
        }
        AddWait(steps, 1000, "第 " outer "/5 輪 - 收尾")
        AddPress(steps, "5", 0)
    }
}

AdjustOpenGap(delta) {
    global openGapMs, running, stepIdx
    openGapMs := Max(0, openGapMs + delta)
    idx := stepIdx
    BuildSteps()
    if running
        stepIdx := idx
    state()
}

AdjustWait20(delta) {
    global wait20Sec, running, stepIdx
    wait20Sec := Max(0, wait20Sec + delta)
    idx := stepIdx
    BuildSteps()
    if running
        stepIdx := idx
    state()
}

AdjustWait34(delta) {
    global wait34Sec, running, stepIdx
    wait34Sec := Max(0, wait34Sec + delta)
    idx := stepIdx
    BuildSteps()
    if running
        stepIdx := idx
    state()
}

ForceReleaseAll() {
    global keyboardId, AHI
    ReleaseAllKeys()
    keys := ["1", "3", "5"]
    Loop 10
        keys.Push("F" A_Index)
    for key in keys {
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
    BuildSteps()
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
        BuildSteps()
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
    global openGapMs, wait34Sec, wait20Sec

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"

    roundInfo := loopRound > 0
        ? "已完成大輪: " loopRound
        : "已完成大輪: 0"

    SetStatusText("【現況】`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . "開場間隔: " openGapMs " ms`r`n"
        . "等待: " wait34Sec " 秒 / " wait20Sec " 秒`r`n"
        . roundInfo "`r`n"
        . posInfo)
}

InitApp() {
    BuildSteps()
    ini()
    BuildMacroPanel("聖賢掛機-天神", infoText, hotkeyText, StartMacro, StopMacro)
    state()
    SetTimer(RefreshGamePos, 500)
}
