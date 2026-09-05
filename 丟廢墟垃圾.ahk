/*  丟廢墟垃圾 (AHI 版)
 *  仿丟山脈雜物：三頁背包掃描
 *  搜尋 Lib\金寶~暗寶 → 拖曳 → max → Enter
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

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
global gemIdx := 1
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
金寶、木寶、水寶、火寶
土寶、光寶、暗寶
→ 先點 max 再確認

【設定】
shift 7,35（與 XL 相同）
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
    global mouseID, AHI
    AHI.SendMouseButtonEvent(mouseID, 0, 1)
}

MouseUp() {
    global mouseID, AHI
    AHI.SendMouseButtonEvent(mouseID, 0, 0)
}

EnsureMouseUp() {
    global itv
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
                press("Esc", 100, 0)
                Sleep 200
                MoveGame(0, 0)
                EnsureMouseUp()
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

GetGemNames() {
    return ["金寶", "木寶", "水寶", "火寶", "土寶", "光寶", "暗寶"]
}

FindGem(&outX, &outY, &outName) {
    global gemIdx
    if SearchJunkList(GetGemNames(), &outX, &outY, &outName, &gemIdx)
        return true
    gemIdx := 1
    return false
}

ResetPageSearchIdx() {
    global gemIdx, stuckCount, lastStuckName
    gemIdx := 1
    stuckCount := 0
    lastStuckName := ""
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

DiscardGem(nx, ny) {
    global dlyDrop, dlyRelease, running, stuckCount, lastStuckName
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
    stuckCount := 0
    lastStuckName := ""
    return true
}

DiscardOneGem() {
    global running, gemIdx
    if !running
        return false
    EnsureMouseUp()
    if !FindGem(&nx, &ny, &name)
        return false
    if !DiscardGem(nx, ny)
        return false
    gemIdx++
    return true
}

DiscardPageJunk() {
    global running, currentPhase, dlyDrop

    ResetPageSearchIdx()
    currentPhase := "丟金木水火土光暗寶"
    state()
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneGem()
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

        currentPhase := "第一頁 - 丟寶石"
        state()
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "第二頁 - 丟寶石"
        state()
        if !SleepCheck(dlyDrop)
            break
        if !SwitchBagPage(-160)
            break
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "第三頁 - 丟寶石"
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
    if !FileExist(ImgPath("金寶")) {
        FlashMsg("缺少 Lib\金寶")
        return
    }
    if !FileExist(ImgPath("鎖1")) {
        FlashMsg("缺少 Lib\鎖1")
        return
    }
    if !FileExist(ImgPath("max")) {
        FlashMsg("缺少 Lib\max")
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
    BuildMacroPanel("丟廢墟垃圾", infoText, hotkeyText, StartDrop, StopDrop)
    state()
    SetTimer(RefreshGamePos, 500)
}
