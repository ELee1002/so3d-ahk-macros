/*  喊收 (AHI 版)
 *  每 N 分鐘：Enter → 上鍵 → Enter
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global intervalMin := Max(1, readNum("shout_interval", 5))
global lastRunTime := "尚未執行"

global infoText := "
(
【功能】
每 N 分鐘執行一次：
Enter → 上鍵 → Enter

【備註】
啟動時立即執行 1 次
N 預設 5 分鐘
)"
global hotkeyText := "
(
【熱鍵】
F1/F2 或下方按鈕
F5/F6 調 N (±1 分)
Ctrl+↑/↓ 調 N (±1 分)
F3 重載  Ctrl+Esc 關
)"

InitApp()
return

F1::StartShout()
F2::StopShout()
F3::{
    StopShout()
    Reload
}
F5::{
    AdjustInterval(-1)
}
F6::{
    AdjustInterval(1)
}
^Up::{
    AdjustInterval(1)
}
^Down::{
    AdjustInterval(-1)
}
^Esc::ExitApp

OnExit(*) {
    StopShout()
    SetTimer(RefreshGamePos, 0)
}

AdjustInterval(delta) {
    global intervalMin, running
    intervalMin := Max(1, Min(120, intervalMin + delta))
    writeCfg("shout_interval", intervalMin)
    if running
        SetTimer(DoShout, intervalMin * 60000)
    state()
    FlashMsg("間隔: " intervalMin " 分鐘", 800)
}

StartShout() {
    global running, currentStatus, intervalMin
    if running
        return
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    running := true
    currentStatus := "運行中"
    DoShout()
    SetTimer(DoShout, intervalMin * 60000)
    state()
}

StopShout() {
    global running, currentStatus
    running := false
    SetTimer(DoShout, 0)
    ReleaseAllKeys()
    currentStatus := "已暫停"
    state()
}

DoShout(*) {
    global running, lastRunTime
    if !running
        return
    press("Enter", 80, 100)
    if !running
        return
    press("Up", 80, 100)
    if !running
        return
    press("Enter", 80, 100)
    lastRunTime := FormatTime(, "HH:mm:ss")
    state()
}

state() {
    global currentStatus, intervalMin, lastRunTime
    global win_width, win_height, winPosSet, clientW, clientH, running

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"

    SetStatusText("【現況】`r`n"
        . "當前 N: " intervalMin " 分鐘`r`n"
        . "狀態: " currentStatus "`r`n"
        . "上次執行: " lastRunTime "`r`n"
        . posInfo)
}

InitApp() {
    ini()
    BuildMacroPanel("喊收", infoText, hotkeyText, StartShout, StopShout)
    state()
    SetTimer(RefreshGamePos, 500)
}
