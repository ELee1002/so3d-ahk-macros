/*  丟山脈雜物-TEST
 *  同正式版，面板顯示正在找 / 抓到哪張圖，每張圖間隔 700ms
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global shfitX := readNum("shiftX", 7)
global shfitY := readNum("shiftY", 35)
global dlyDrop := Max(50, readNum("drop_delay", 300))
global dlyRelease := Max(50, readNum("release_delay", 300))
global itv := 500
global imgItv := 700
global imgVar := 30
global bagMinX := readNum("bag_minX", 80)
global bagMinY := readNum("bag_minY", 80)
global lockNX := 0
global lockNY := 0
global currentPhase := "待機"
global lastTryImg := "-"
global lastHitImg := "-"
global lastHitX := 0
global lastHitY := 0
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
【TEST 版】
面板顯示正在找 / 抓到哪張圖
每張圖間隔 700ms，不顯示完成輪數

F2 停止
)"
global hotkeyText := "
(
【熱鍵】
F1/F2 或下方按鈕
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
^Esc::ExitApp

OnExit(*) {
    StopDrop()
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

SearchInGame(name, &outX, &outY, variation := "", showTry := true) {
    global imgVar, win_width, win_height, lastTryImg, lastHitImg, lastHitX, lastHitY, running
    if !running
        return false
    if !RefreshGameRect()
        return false
    if showTry {
        lastTryImg := name
        state()
    }
    path := ImgPath(name)
    if !FileExist(path)
        return false
    if !running
        return false
    var := variation != "" ? variation : "*" imgVar " "
    outX := 0, outY := 0
    try {
        if ImageSearch(&outX, &outY, 0, 0, win_width, win_height, var path) {
            if showTry {
                lastHitImg := name
                lastHitX := outX
                lastHitY := outY
                state()
            }
            return true
        }
    }
    return false
}

SearchDialog(name, &outX, &outY, variation := "*20 ", showTry := true) {
    global imgVar, win_width, win_height, lastTryImg, lastHitImg, lastHitX, lastHitY, running
    if !running
        return false
    if !RefreshGameRect()
        return false
    if showTry {
        lastTryImg := name . " (確認框)"
        state()
    }
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
        if ImageSearch(&outX, &outY, x1, y1, x2, y2, var path) {
            if showTry {
                lastHitImg := name
                lastHitX := outX
                lastHitY := outY
                state()
            }
            return true
        }
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
        if !SearchDialog(name, &mx, &my, "*20 ", false)
            return true
        if !SleepCheck(80)
            return false
    }
    press("Esc", 100, 0)
    Sleep 200
    return true
}

CancelStuckDialog() {
    global running, currentPhase
    if !running
        return
    currentPhase := "關閉卡住的確認框"
    state()
    if SearchDialog("山M", &mx, &my, "*20 ", false) {
        press("Esc", 100, 0)
        Sleep 200
    }
    MoveGame(0, 0)
    EnsureMouseUp()
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
    global lastHitImg, lastHitX, lastHitY, running, imgItv
    global lastStuckName, lastStuckX, lastStuckY, stuckCount
    while idx <= names.Length {
        if !running
            return false
        name := names[idx]
        if !SearchInGame(name, &x, &y) {
            idx++
            if !SleepCheck(imgItv)
                return false
            continue
        }
        if !IsValidBagCoord(x, y) {
            idx++
            if !SleepCheck(imgItv)
                return false
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
                if !SleepCheck(imgItv)
                    return false
                continue
            }
        } else {
            stuckCount := 0
        }
        outX := x
        outY := y
        outName := name
        lastHitImg := name
        lastHitX := x
        lastHitY := y
        state()
        return true
    }
    idx := 1
    stuckCount := 0
    lastStuckName := ""
    return false
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
    global dlyDrop, running
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

DiscardWithConfirm(nx, ny, itemName) {
    global dlyDrop, dlyRelease, running, itv, currentPhase, stuckCount, lastStuckName
    if !running
        return false
    currentPhase := "丟棄: " itemName
    state()
    MoveGame(nx, ny)
    if !SleepCheck(dlyDrop)
        return false
    if !DragDropToCorner()
        return false
    if !SleepCheck(dlyRelease)
        return false
    currentPhase := "等確認框"
    state()
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
    EnsureDialogClosed("山M", 1500)
    EnsureMouseUp()
    stuckCount := 0
    lastStuckName := ""
    return true
}

DiscardSimple(nx, ny, itemName) {
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
    if !SearchInGame("max", &mx, &my, "*30 ", true)
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

DiscardTreasure(nx, ny, itemName) {
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
    global running, name, confirmIdx
    if !running
        return false
    EnsureMouseUp()
    if !FindConfirmJunk(&nx, &ny, &name)
        return false
    if !DiscardWithConfirm(nx, ny, name)
        return false
    confirmIdx++
    return true
}

DiscardOneSimple() {
    global running, name, simpleIdx
    if !running
        return false
    EnsureMouseUp()
    if !FindSimpleJunk(&nx, &ny, &name)
        return false
    if !DiscardSimple(nx, ny, name)
        return false
    simpleIdx++
    return true
}

DiscardOneTreasure() {
    global running, name, treasureIdx
    if !running
        return false
    EnsureMouseUp()
    if !FindTreasure(&nx, &ny, &name)
        return false
    if !DiscardTreasure(nx, ny, name)
        return false
    treasureIdx++
    return true
}

DiscardPageJunk() {
    global running, currentPhase, dlyDrop

    ResetPageSearchIdx()
    currentPhase := "第一階段：山雜/武/書"
    state()
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneConfirm()
            break
    }

    currentPhase := "第二階段：山雜裝"
    state()
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneSimple()
            break
    }

    currentPhase := "第三階段：山寶"
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
        if SearchInGame("鎖1", &lockNX, &lockNY, "*30 ", true)
            break
        press("I", 500, 0)
        if !SleepCheck(500)
            return false
        press("Enter", 100, 0)
        if !SleepCheck(500)
            return false
        if SearchInGame("鎖1", &lockNX, &lockNY, "*30 ", true)
            break
    }
    if !lockNX
        return false

    currentPhase := "解鎖背包"
    state()
    MoveGame(lockNX - 200, lockNY)
    if !SleepCheck(itv)
        return false
    MouseDown()
    if !SleepCheck(itv)
        return false
    MouseUp()
    if !SleepCheck(itv)
        return false
    MouseDown()
    if !SleepCheck(itv)
        return false
    MouseUp()
    if !SleepCheck(itv)
        return false
    MoveGame(0, 0)
    return true
}

DismissBagShortage() {
    global running, dlyDrop, currentPhase, bagShortImg, itv
    if !running
        return false
    if !SearchInGame(bagShortImg, &x, &y, "*30 ", true)
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
    currentPhase := "切換背包分頁 " offsetX
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
    global running, currentPhase, dlyDrop

    while running {
        currentPhase := "準備中"
        state()
        if !ActivateGame()
            break
        RefreshGameRect()
        if !OpenAndUnlockBag()
            break

        currentPhase := "第一頁"
        state()
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "第二頁"
        state()
        if !SwitchBagPage(-160)
            break
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "第三頁"
        state()
        if !SwitchBagPage(-120)
            break
        if !SleepCheck(dlyDrop)
            break
        if !DiscardPageJunk()
            break

        currentPhase := "關閉背包"
        state()
        press("X", 100, 0)
        if !SleepCheck(1000)
            break
        ForceReleaseAll()
    }
    ForceReleaseAll()
}

StartDrop() {
    global running, currentStatus
    if running
        return
    if !GetGameHwnd() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
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
    currentStatus := "已暫停"
    currentPhase := "待機"
    state()
}

state() {
    global currentStatus, currentPhase, lastTryImg, lastHitImg, lastHitX, lastHitY, imgItv
    global confirmIdx, simpleIdx, treasureIdx
    global shfitX, shfitY, dlyDrop, dlyRelease, win_width, win_height, winPosSet, clientW, clientH

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height
        : "視窗: 尚未定位"

    SetStatusText("【TEST 現況】`r`n"
        . "階段: " currentPhase "`r`n"
        . "正在找: " lastTryImg "`r`n"
        . "上次抓到: " lastHitImg "`r`n"
        . "座標: (" lastHitX ", " lastHitY ")`r`n"
        . "搜尋進度: 雜" confirmIdx " / 裝" simpleIdx " / 寶" treasureIdx "`r`n"
        . "圖片間隔: " imgItv "ms`r`n"
        . "狀態: " currentStatus "`r`n"
        . posInfo)
}

InitApp() {
    ini()
    BuildMacroPanel("丟山脈雜物-TEST", infoText, hotkeyText, StartDrop, StopDrop)
    state()
    SetTimer(RefreshGamePos, 500)
}
