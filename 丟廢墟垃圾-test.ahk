/*  丟廢墟垃圾-TEST
 *  偵測到 Lib\滿包 才開始丟棄
 *  面板顯示找圖過程，每張圖間隔 700ms
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
global pollItv := 1000
global imgVar := 30
global bagMinX := readNum("bag_minX", 80)
global bagMinY := readNum("bag_minY", 80)
global fullBagImg := "滿包"
global lockNX := 0
global lockNY := 0
global currentPhase := "待機"
global bagFull := false
global lastTryImg := "-"
global lastHitImg := "-"
global lastHitX := 0
global lastHitY := 0
global gemIdx := 1
global lastStuckName := ""
global lastStuckX := 0
global lastStuckY := 0
global stuckCount := 0
global bagShortImg := "包不足"

global infoText := "
(
【TEST 版】
啟動時偵測 Lib\滿包 一次
偵測到後直接跑完整三頁丟棄
面板顯示正在找 / 抓到哪張圖
每張圖間隔 700ms

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

IsBagFull() {
    global fullBagImg, bagFull
    if SearchInGame(fullBagImg, &x, &y, "*30 ", true) {
        bagFull := true
        state()
        return true
    }
    bagFull := false
    state()
    return false
}

WaitForFullBag() {
    global running, currentPhase, pollItv, bagFull
    if !running
        return false
    currentPhase := "等待滿包"
    bagFull := false
    state()
    Loop {
        if !running
            return false
        if IsBagFull()
            return true
        if !SleepCheck(pollItv)
            return false
    }
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
    global running, imgItv, lastStuckName, lastStuckX, lastStuckY, stuckCount
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
                press("Esc", 100, 0)
                Sleep 200
                MoveGame(0, 0)
                EnsureMouseUp()
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

DiscardGem(nx, ny, itemName) {
    global dlyDrop, dlyRelease, running, currentPhase, stuckCount, lastStuckName
    if !running
        return false
    currentPhase := "丟棄: " itemName
    state()
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
    currentPhase := "點 max"
    state()
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
    global running, gemIdx, name
    if !running
        return false
    EnsureMouseUp()
    if !FindGem(&nx, &ny, &name)
        return false
    if !DiscardGem(nx, ny, name)
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

RunDropOnce() {
    global running, currentPhase, dlyDrop

    if !running
        return false
    currentPhase := "滿包 → 開始丟棄"
    state()
    if !ActivateGame()
        return false
    RefreshGameRect()
    if !OpenAndUnlockBag()
        return false

    currentPhase := "第一頁"
    state()
    if !SleepCheck(dlyDrop)
        return false
    if !DiscardPageJunk()
        return false

    currentPhase := "第二頁"
    state()
    if !SwitchBagPage(-160)
        return false
    if !SleepCheck(dlyDrop)
        return false
    if !DiscardPageJunk()
        return false

    currentPhase := "第三頁"
    state()
    if !SwitchBagPage(-120)
        return false
    if !SleepCheck(dlyDrop)
        return false
    if !DiscardPageJunk()
        return false

    currentPhase := "關閉背包"
    state()
    press("X", 100, 0)
    if !SleepCheck(1000)
        return false
    ForceReleaseAll()
    return true
}

RunDropCycle() {
    global running

    if !WaitForFullBag() {
        ForceReleaseAll()
        return
    }
    RunDropOnce()
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
    if !FileExist(ImgPath(fullBagImg)) {
        FlashMsg("缺少 Lib\" fullBagImg)
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
    running := true
    currentStatus := "運行中"
    state()
    RunDropCycle()
    if running {
        running := false
        currentStatus := "已結束"
        currentPhase := "待機"
        bagFull := false
        ForceReleaseAll()
        state()
    }
}

StopDrop() {
    global running, currentStatus, currentPhase, bagFull
    running := false
    ForceReleaseAll()
    currentStatus := "已暫停"
    currentPhase := "待機"
    bagFull := false
    state()
}

state() {
    global currentStatus, currentPhase, bagFull, lastTryImg, lastHitImg, lastHitX, lastHitY
    global imgItv, pollItv, gemIdx, shfitX, shfitY, dlyDrop, dlyRelease
    global win_width, win_height, winPosSet, clientW, clientH

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height
        : "視窗: 尚未定位"
    fullInfo := bagFull ? "是" : "否"

    SetStatusText("【TEST 現況】`r`n"
        . "滿包: " fullInfo "`r`n"
        . "階段: " currentPhase "`r`n"
        . "正在找: " lastTryImg "`r`n"
        . "上次抓到: " lastHitImg "`r`n"
        . "座標: (" lastHitX ", " lastHitY ")`r`n"
        . "搜尋進度: 寶" gemIdx "`r`n"
        . "圖片間隔: " imgItv "ms  滿包輪詢: " pollItv "ms`r`n"
        . "狀態: " currentStatus "`r`n"
        . posInfo)
}

InitApp() {
    ini()
    BuildMacroPanel("丟廢墟垃圾-TEST", infoText, hotkeyText, StartDrop, StopDrop)
    state()
    SetTimer(RefreshGamePos, 500)
}
