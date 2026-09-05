/*  補師補血 (AHI 版) — 使用標準 Template 面板
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global N := Max(1, readNum("heal_interval", 3))
global healMax := Max(1, readNum("heal_count", 5))
global healProgress := 0
global healPhase := "idle"
global healCount := 0
global nextActionTick := 0

global infoText := "
(
【功能】
每 N 秒按 4 補血
啟動立即按 1 次
X 次後按 5 喝藍水

【備註】
4=補血 5=藍水
X=補血量/耗魔量
)"
global hotkeyText := "
(
【熱鍵】
F1/F2 或下方按鈕
F5/F6 調 N
Ctrl+↑/↓ 調 X
F3 重載  Ctrl+Esc 關
)"

InitApp()
return

F1::StartHeal()
F2::StopHeal()
F3::{
    StopHeal()
    Reload
}
F5::{
    global N, healMax
    N := Max(1, N - 1)
    writeCfg("heal_interval", N)
    state()
}
F6::{
    global N, healMax
    N += 1
    writeCfg("heal_interval", N)
    state()
}
^Up::{
    global healMax
    healMax += 1
    writeCfg("heal_count", healMax)
    state()
}
^Down::{
    global healMax
    healMax := Max(1, healMax - 1)
    writeCfg("heal_count", healMax)
    state()
}
^Esc::ExitApp

OnExit(*) {
    StopHeal()
    SetTimer(RefreshGamePos, 0)
}

StartHeal() {
    global running, currentStatus, healProgress, healPhase, healCount, nextActionTick
    if running
        return
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    running := true
    healProgress := 0
    healCount := 0
    healPhase := "heal"
    nextActionTick := 0
    currentStatus := "運行中"
    SetTimer(HealTick, 10)
    state()
}

StopHeal() {
    global running, currentStatus, healProgress, healPhase, healCount
    running := false
    SetTimer(HealTick, 0)
    ReleaseAllKeys()
    healPhase := "idle"
    healCount := 0
    healProgress := 0
    currentStatus := "已暫停"
    state()
}

HealTick(*) {
    global running, N, healMax, healPhase, healCount, healProgress, nextActionTick
    if !running
        return

    now := A_TickCount

    if healPhase == "heal" {
        if now < nextActionTick
            return
        if !press("4", 30, 0)
            return
        healCount++
        healProgress := healCount
        state()
        if healCount >= healMax {
            healPhase := "drink"
            nextActionTick := now
        } else {
            healPhase := "wait"
            nextActionTick := now + N * 1000
        }
        return
    }

    if healPhase == "wait" {
        if now < nextActionTick
            return
        healPhase := "heal"
        nextActionTick := now
        return
    }

    if healPhase == "drink" {
        if now < nextActionTick
            return
        if !press("5", 30, 0)
            return
        healCount := 0
        healProgress := 0
        healPhase := "heal"
        nextActionTick := now
        state()
    }
}

state() {
    global currentStatus, healProgress, N, healMax
    global win_width, win_height, winPosSet, clientW, clientH, running

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"

    progressInfo := running
        ? "本輪: " healProgress " / " healMax
        : "本輪: -- / " healMax

    SetStatusText("【現況】`r`n"
        . "當前 N: " N " 秒`r`n"
        . "當前 X: " healMax "`r`n"
        . "狀態: " currentStatus "`r`n"
        . progressInfo "`r`n"
        . posInfo)
}

InitApp() {
    ini()
    BuildMacroPanel("補師補血", infoText, hotkeyText, StartHeal, StopHeal)
    state()
    SetTimer(RefreshGamePos, 500)
}
