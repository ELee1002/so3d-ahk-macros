/*  丟山脈雜物 (AHI 版)
 *  座標/找圖/延遲與 XL 一鍵丟垃圾相同
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()
; XL 原版固定值（與 forest 腳本一致）
global shfitX := readNum("shiftX", 7)
global shfitY := readNum("shiftY", 35)
global dlyDrop := Max(10, readNum("drop_delay", 50))
global dlyRelease := Max(10, readNum("release_delay", 50))
global itv := 300
global imgVar := 30
global bagMinX := readNum("bag_minX", 80)
global bagMinY := readNum("bag_minY", 80)
global lockNX := 0
global lockNY := 0
global currentPhase := "待機"
global roundCount := 0
global confirmIdx := 1
global simpleIdx := 1
global treasureIdx := 1
global lastStuckName := ""
global lastStuckX := 0
global lastStuckY := 0
global stuckCount := 0
global bagShortImg := "包不足"

global infoText := "
(
【功能】
自動開背包 → 三頁掃描
搜尋並拖曳丟棄：
山雜1~13、山雜武1~23
山雜書1~2 → 有確認框
山雜裝1~49 → 無確認框
山寶1 → 先點 max 再確認

【設定】
與 XL 相同：shift 7,35
找圖區域 0,0~視窗寬高

【備註】
F2 立即停止
)"
global hotkeyText := "
(
【熱鍵】
F1/F2 或下方按鈕
Ctrl+←/→ 丟東西延遲 ±10
Ctrl+↑/↓ 放開延遲 ±10
Ctrl+Shift+←/→ shiftX ±1
Ctrl+Shift+↑/↓ shiftY ±1
F3 重載  Ctrl+Esc 關
)"

InitApp()
return

F1::StartDrop()
F2::StopDrop()
F3::{
    StopDrop()
    Reload
}
^Left::{
    AdjustDelay("drop", -10)
}
^Right::{
    AdjustDelay("drop", 10)
}
^Up::{
    AdjustDelay("release", 10)
}
^Down::{
    AdjustDelay("release", -10)
}
^+Left::{
    AdjustShift("x", -1)
}
^+Right::{
    AdjustShift("x", 1)
}
^+Up::{
    AdjustShift("y", -1)
}
^+Down::{
    AdjustShift("y", 1)
}
^Esc::ExitApp

OnExit(*) {
    StopDrop()
    SetTimer(RefreshGamePos, 0)
}

AdjustDelay(kind, delta) {
    global dlyDrop, dlyRelease, running
    if kind == "drop"
        dlyDrop := Max(10, dlyDrop + delta)
    else
        dlyRelease := Max(10, dlyRelease + delta)
    writeCfg(kind == "drop" ? "drop_delay" : "release_delay", kind == "drop" ? dlyDrop : dlyRelease)
    state()
    if !running
        FlashMsg("丟:" dlyDrop "ms 放:" dlyRelease "ms", 800)
}

AdjustShift(axis, delta) {
    global shfitX, shfitY, running
    if axis == "x"
        shfitX += delta
    else
        shfitY += delta
    writeCfg(axis == "x" ? "shiftX" : "shiftY", axis == "x" ? shfitX : shfitY)
    state()
    if !running
        FlashMsg("shiftX=" shfitX " shiftY=" shfitY, 800)
}

; XL ini()：WinGetPos 取視窗位置
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

; XL：ImageSearch 0,0, win_width,win_height
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

; XL move(x,y)
MoveGame(x, y) {
    global winX, winY, shfitX, shfitY, mouseID, AHI
    RefreshGameRect()
    AHI.SendMouseMoveAbsolute(mouseID
        , ((x + winX + shfitX) / A_ScreenWidth) * 65535
        , ((y + winY + shfitY) / A_ScreenHeight) * 65535)
}

MouseDown() {
    global mouseID, AHI
    AHI.SendMouseButtonEvent(mouseID, 0, 1)
}

MouseUp() {
    global mouseID, AHI
    AHI.SendMouseButtonEvent(mouseID, 0, 0)
}

EnsureMouseUp() {
    global itv, dlyDrop
    Loop 2
        MouseUp()
    Sleep(itv)
}

ForceReleaseAll() {
    EnsureMouseUp()
    ReleaseAllKeys()
}

IsValidBagCoord(x, y) {
    global bagMinX, bagMinY
    return x >= bagMinX && y >= bagMinY
}

SearchJunkList(names, &outX, &outY, &outName, &idx) {
    global running, lastStuckName, lastStuckX, lastStuckY, stuckCount
    while idx <= names.Length {
        if !running
            return false
        name := names[idx]
        if !SearchInGame(name, &x, &y) {
            idx++
            continue
        }
        if !IsValidBagCoord(x, y) {
            idx++
            continue
        }
        if (name == lastStuckName
            && Abs(x - lastStuckX) < 8
            && Abs(y - lastStuckY) < 8) {
            stuckCount++
            if stuckCount >= 2 {
                CancelStuckDialog()
                idx++
                stuckCount := 0
                lastStuckName := ""
                continue
            }
        } else {
            stuckCount := 0
        }
        outX := x
        outY := y
        outName := name
        lastStuckName := name
        lastStuckX := x
        lastStuckY := y
        return true
    }
    idx := 1
    stuckCount := 0
    lastStuckName := ""
    return false
}

SearchDialog(name, &outX, &outY, variation := "*20 ") {
    global imgVar, win_width, win_height
    if !RefreshGameRect()
        return false
    path := ImgPath(name)
    if !FileExist(path)
        return false
    x1 := Round(win_width * 0.15)
    y1 := Round(win_height * 0.15)
    x2 := Round(win_width * 0.85)
    y2 := Round(win_height * 0.85)
    var := variation != "" ? variation : "*" imgVar " "
    outX := 0, outY := 0
    try {
        if ImageSearch(&outX, &outY, x1, y1, x2, y2, var path)
            return true
    }
    return false
}

WaitForDialog(name, &outX, &outY, timeoutMs := 1200) {
    deadline := A_TickCount + timeoutMs
    while A_TickCount < deadline {
        if SearchDialog(name, &outX, &outY)
            return true
        if !SleepCheck(80)
            return false
    }
    return false
}

EnsureDialogClosed(name, timeoutMs := 1500) {
    deadline := A_TickCount + timeoutMs
    while A_TickCount < deadline {
        if !SearchDialog(name, &mx, &my)
            return true
        if !SleepCheck(80)
            return false
    }
    press("Esc", 100, 0)
    Sleep 200
    return true
}

CancelStuckDialog() {
    global running
    if !running
        return
    if SearchDialog("山M", &mx, &my) {
        press("Esc", 100, 0)
        Sleep 200
    }
    MoveGame(0, 0)
    EnsureMouseUp()
}

GetConfirmJunkNames() {
    names := []
    Loop 13
        names.Push("山雜" A_Index)
    Loop 23
        names.Push("山雜武" A_Index)
    Loop 2
        names.Push("山雜書" A_Index)
    return names
}

GetSimpleJunkNames() {
    names := []
    Loop 49
        names.Push("山雜裝" A_Index)
    return names
}

GetTreasureNames() {
    return ["山寶1"]
}

FindConfirmJunk(&outX, &outY, &outName) {
    global confirmIdx
    if SearchJunkList(GetConfirmJunkNames(), &outX, &outY, &outName, &confirmIdx)
        return true
    confirmIdx := 1
    return false
}

FindSimpleJunk(&outX, &outY, &outName) {
    global simpleIdx
    if SearchJunkList(GetSimpleJunkNames(), &outX, &outY, &outName, &simpleIdx)
        return true
    simpleIdx := 1
    return false
}

FindTreasure(&outX, &outY, &outName) {
    global treasureIdx
    if SearchJunkList(GetTreasureNames(), &outX, &outY, &outName, &treasureIdx)
        return true
    treasureIdx := 1
    return false
}

ResetPageSearchIdx() {
    global confirmIdx, simpleIdx, treasureIdx, stuckCount, lastStuckName
    confirmIdx := 1
    simpleIdx := 1
    treasureIdx := 1
    stuckCount := 0
    lastStuckName := ""
}

DragDropToCorner() {
    global dlyDrop, dlyRelease, running
    if !running
        return false
    MouseDown()
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    MouseUp()
    if !SleepCheck(dlyDrop)
        return false
    MouseUp()
    return true
}

; 山雜/武/書：有山M確認框（同 XL 森雜）
DiscardWithConfirm(nx, ny) {
    global dlyDrop, dlyRelease, running, itv, stuckCount, lastStuckName
    if !running
        return false
    MoveGame(nx, ny)
    if !SleepCheck(dlyDrop)
        return false
    if !DragDropToCorner()
        return false
    if !SleepCheck(dlyRelease)
        return false
    if WaitForDialog("山M", &mx, &my, 1200) {
        MoveGame(mx, my)
        if !SleepCheck(dlyDrop)
            return false
        MouseDown()
        if !SleepCheck(itv)
            return false
        MouseUp()
        if !SleepCheck(dlyDrop)
            return false
    }
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    press("Enter", 100, 0)
    if !SleepCheck(dlyDrop)
        return false
    press("Enter", 100, 0)
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    EnsureDialogClosed("山M", 1500)
    EnsureMouseUp()
    stuckCount := 0
    lastStuckName := ""
    return true
}

; 山雜裝：無確認框（同 XL 森）
DiscardSimple(nx, ny) {
    global dlyDrop, dlyRelease, running
    if !running
        return false
    MoveGame(nx, ny)
    if !SleepCheck(dlyDrop)
        return false
    MouseDown()
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    MouseUp()
    if !SleepCheck(dlyDrop)
        return false
    MouseUp()
    if !SleepCheck(dlyRelease)
        return false
    press("Enter", 100, 0)
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    press("Enter", 100, 0)
    if !SleepCheck(dlyDrop)
        return false
    EnsureMouseUp()
    return true
}

ClickMaxButton() {
    global dlyDrop, running, itv
    if !SearchInGame("max", &mx, &my, "*30 ")
        return false
    MoveGame(mx, my)
    if !SleepCheck(dlyDrop)
        return false
    MouseDown()
    if !SleepCheck(itv)
        return false
    MouseUp()
    if !SleepCheck(dlyDrop)
        return false
    return true
}

; 山寶1：拖曳後先點 max 再 Enter
DiscardTreasure(nx, ny) {
    global dlyDrop, dlyRelease, running
    if !running
        return false
    MoveGame(nx, ny)
    if !SleepCheck(dlyDrop)
        return false
    MouseDown()
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    MouseUp()
    if !SleepCheck(dlyDrop)
        return false
    MouseUp()
    if !SleepCheck(dlyRelease)
        return false
    if !SleepCheck(dlyDrop)
        return false
    ClickMaxButton()
    if !SleepCheck(dlyDrop)
        return false
    press("Enter", 100, 0)
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    press("Enter", 100, 0)
    if !SleepCheck(dlyDrop)
        return false
    EnsureMouseUp()
    return true
}

DiscardOneConfirm() {
    global running, confirmIdx
    if !running
        return false
    EnsureMouseUp()
    if !FindConfirmJunk(&nx, &ny, &name)
        return false
    if !DiscardWithConfirm(nx, ny)
        return false
    confirmIdx++
    return true
}

DiscardOneSimple() {
    global running, simpleIdx
    if !running
        return false
    EnsureMouseUp()
    if !FindSimpleJunk(&nx, &ny, &name)
        return false
    if !DiscardSimple(nx, ny)
        return false
    simpleIdx++
    return true
}

DiscardOneTreasure() {
    global running, treasureIdx
    if !running
        return false
    EnsureMouseUp()
    if !FindTreasure(&nx, &ny, &name)
        return false
    if !DiscardTreasure(nx, ny)
        return false
    treasureIdx++
    return true
}

DiscardPageJunk() {
    global running, currentPhase, dlyDrop

    ResetPageSearchIdx()
    currentPhase := "丟山雜/武/書"
    state()
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneConfirm()
            break
    }

    currentPhase := "丟山雜裝"
    state()
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneSimple()
            break
    }

    currentPhase := "丟山寶"
    state()
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneTreasure()
            break
    }

    currentPhase := "本頁已清完"
    state()
    return running
}

OpenAndUnlockBag() {
    global running, currentPhase, lockNX, lockNY, itv

    if !running
        return false
    currentPhase := "開啟背包"
    state()

    Loop {
        if !running
            return false
        if SearchInGame("鎖1", &lockNX, &lockNY, "*30 ")
            break
        press("I", 500, 0)
        if !SleepCheck(200)
            return false
        press("Enter", 100, 0)
        if !SleepCheck(200)
            return false
        if SearchInGame("鎖1", &lockNX, &lockNY, "*30 ")
            break
    }
    if !lockNX
        return false

    currentPhase := "解鎖背包"
    state()
    if !SleepCheck(100)
        return false
    MoveGame(lockNX - 200, lockNY)
    if !SleepCheck(300)
        return false
    MouseDown()
    if !SleepCheck(itv)
        return false
    MouseUp()
    if !SleepCheck(100)
        return false
    MouseDown()
    if !SleepCheck(itv)
        return false
    MouseUp()
    if !SleepCheck(100)
        return false
    MoveGame(0, 0)
    return true
}

DismissBagShortage() {
    global running, dlyDrop, currentPhase, bagShortImg, itv
    if !running
        return false
    if !SearchInGame(bagShortImg, &x, &y, "*30 ")
        return true
    currentPhase := "包不足 → 點 X+120"
    state()
    if !SleepCheck(200)
        return false
    MoveGame(x + 120, y)
    if !SleepCheck(dlyDrop)
        return false
    MouseDown()
    if !SleepCheck(itv)
        return false
    MouseUp()
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    return true
}

SwitchBagPage(offsetX) {
    global lockNX, lockNY, running, currentPhase, dlyDrop, itv
    if !running || !lockNX
        return false
    currentPhase := "切換背包分頁"
    state()
    MoveGame(lockNX + offsetX, lockNY)
    if !SleepCheck(dlyDrop)
        return false
    MouseDown()
    if !SleepCheck(itv)
        return false
    MouseUp()
    if !SleepCheck(dlyDrop)
        return false
    MoveGame(0, 0)
    if !SleepCheck(dlyDrop)
        return false
    if !DismissBagShortage()
        return false
    return true
}

RunDropCycle() {
    global running, roundCount, currentPhase, dlyDrop

    while running {
        roundCount++
        currentPhase := "第 " roundCount " 輪 - 準備"
        state()
        if !ActivateGame()
            break
        RefreshGameRect()
        if !OpenAndUnlockBag()
            break

        currentPhase := "第一頁 - 丟山雜"
        state()
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "第二頁 - 丟山雜"
        state()
        if !SleepCheck(dlyDrop)
            break
        if !SwitchBagPage(-160)
            break
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "第三頁 - 丟山雜"
        state()
        if !SleepCheck(dlyDrop)
            break
        if !SwitchBagPage(-120)
            break
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "關閉背包"
        state()
        press("X", 100, 0)
        if !SleepCheck(500)
            break
        ForceReleaseAll()
    }
    ForceReleaseAll()
}

StartDrop() {
    global running, currentStatus, roundCount
    if running
        return
    if !GetGameHwnd() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    if !FileExist(ImgPath("山雜1")) {
        FlashMsg("缺少 Lib\山雜1")
        return
    }
    if !FileExist(ImgPath("鎖1")) {
        FlashMsg("缺少 Lib\鎖1")
        return
    }
    roundCount := 0
    running := true
    currentStatus := "運行中"
    state()
    RunDropCycle()
    if running {
        running := false
        currentStatus := "已結束"
        currentPhase := "待機"
        ForceReleaseAll()
        state()
    }
}

StopDrop() {
    global running, currentStatus, currentPhase
    running := false
    ForceReleaseAll()
    SetTimer(EnsureStopped, -20)
    SetTimer(EnsureStopped, -80)
    currentStatus := "已暫停"
    currentPhase := "待機"
    state()
}

EnsureStopped(*) {
    global running
    if running
        return
    ForceReleaseAll()
}

state() {
    global currentStatus, currentPhase, roundCount, dlyDrop, dlyRelease
    global shfitX, shfitY, bagMinX, bagMinY, win_width, win_height, winPosSet, clientW, clientH

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"

    SetStatusText("【現況】`r`n"
        . "shift: " shfitX "," shfitY "  背包區>" bagMinX "," bagMinY "`r`n"
        . "延遲: 丟 " dlyDrop "ms / 放 " dlyRelease "ms`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . "已完成: " roundCount " 輪`r`n"
        . posInfo)
}

InitApp() {
    ini()
    BuildMacroPanel("丟山脈雜物", infoText, hotkeyText, StartDrop, StopDrop)
    state()
    SetTimer(RefreshGamePos, 500)
}
