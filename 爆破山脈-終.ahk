/*  爆破山脈-終 (AHI 版)
 *  15 秒連打 1 → 按 2 x3 → 每 N 輪連按空白 X 秒
 *  空白階段若偵測 Lib\滿包 或 Lib\包不足 → 執行丟山脈雜物（三頁）
 *  丟完後 3 分 30 秒完全暫停（等地面垃圾消失）再繼續練功
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global infoText := "
(
【功能】
1. 連打 1 → 按 2 x3 循環
2. 每 N 輪連按空白 X 秒
3. 空白階段偵測滿包/包不足 → 自動丟山脈雜物
   （包不足會先等 5 秒再丟）
4. 丟完後 3 分 30 秒完全暫停再繼續

【備註】
F2 立即停止
)"
global hotkeyText := "
(
【熱鍵】
F1/F2 或下方按鈕
F5/F6 調每 N 輪
Ctrl+↑/↓ 調空白秒數
F3 重載  Ctrl+Esc 關
)"

InitAllCfg()
InitApp()
return

F1::StartTrain()
F2::StopTrain()
F3::{
    StopTrain()
    Reload
}
F5::{
    global spaceEveryN
    spaceEveryN := Max(1, spaceEveryN - 1)
    writeCfg("train_space_rounds", spaceEveryN)
    state()
}
F6::{
    global spaceEveryN
    spaceEveryN += 1
    writeCfg("train_space_rounds", spaceEveryN)
    state()
}
^Up::{
    global spaceSec
    spaceSec += 1
    writeCfg("train_space_sec", spaceSec)
    state()
}
^Down::{
    global spaceSec
    spaceSec := Max(1, spaceSec - 1)
    writeCfg("train_space_sec", spaceSec)
    state()
}
^Esc::ExitApp

OnExit(*) {
    StopTrain()
    SetTimer(TrainTick, 0)
    SetTimer(EnsureStopped, 0)
    SetTimer(RefreshGamePos, 0)
}

InitAllCfg() {
    global spamSec, press2Count, spamInterval, spaceEveryN, spaceSec
    global loopCount, dropCount, currentPhase, trainPhase
    global spamEndTick, spaceEndTick, nextTick, nextBagCheck
    global key1Held, key2Held, keySpaceHeld, press2Left, press2Step
    global SC1, SC2, SCSpace, bagDropDoneThisSpace
    global shfitX, shfitY, dlyDrop, dlyRelease, itv, imgVar
    global bagMinX, bagMinY, fullBagImg, bagShortImg, bagCheckItv
    global pickupCooldownUntil, pickupCooldownMs, lastCooldownDispSec
    global lockNX, lockNY
    global lastStuckName, lastStuckX, lastStuckY, stuckCount, skipPageDiscard
    global bagShortDropDelayMs, lastBagShortWaitSec
    global spacePrepMs

    spamSec := 15
    press2Count := 3
    spamInterval := 10
    spaceEveryN := Max(1, readNum("train_space_rounds", 5))
    spaceSec := Max(1, readNum("train_space_sec", 3))
    loopCount := 0
    dropCount := 0
    currentPhase := "待機"
    trainPhase := "idle"
    spamEndTick := 0
    spaceEndTick := 0
    nextTick := 0
    nextBagCheck := 0
    key1Held := false
    key2Held := false
    keySpaceHeld := false
    press2Left := 0
    press2Step := ""
    bagDropDoneThisSpace := false
    SC1 := 0
    SC2 := 0
    SCSpace := 0

    shfitX := readNum("shiftX", 7)
    shfitY := readNum("shiftY", 35)
    dlyDrop := Max(10, readNum("drop_delay", 50))
    dlyRelease := Max(10, readNum("release_delay", 50))
    itv := 300
    imgVar := 30
    bagMinX := readNum("bag_minX", 80)
    bagMinY := readNum("bag_minY", 80)
    fullBagImg := "滿包"
    bagShortImg := "包不足"
    bagCheckItv := 500
    pickupCooldownUntil := 0
    pickupCooldownMs := 210000
    lastCooldownDispSec := -1
    lockNX := 0
    lockNY := 0
    lastStuckName := ""
    lastStuckX := 0
    lastStuckY := 0
    stuckCount := 0
    skipPageDiscard := false
    bagShortDropDelayMs := 5000
    lastBagShortWaitSec := -1
    spacePrepMs := 500
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

KeySpaceDown() {
    global keyboardId, AHI, keySpaceHeld, SCSpace, running
    if !running || keySpaceHeld
        return
    AHI.SendKeyEvent(keyboardId, SCSpace, 1)
    keySpaceHeld := true
}

KeySpaceUp() {
    global keyboardId, AHI, keySpaceHeld, SCSpace
    if !keySpaceHeld
        return
    AHI.SendKeyEvent(keyboardId, SCSpace, 0)
    keySpaceHeld := false
}

ForceReleaseAll() {
    global keyboardId, AHI, SC1, SC2, SCSpace, key1Held, key2Held, keySpaceHeld
    key1Held := false
    key2Held := false
    keySpaceHeld := false
    ReleaseAllKeys()
    try AHI.SendKeyEvent(keyboardId, SC1, 0)
    try AHI.SendKeyEvent(keyboardId, SC2, 0)
    try AHI.SendKeyEvent(keyboardId, SCSpace, 0)
    EnsureMouseUp()
}

EnsureStopped(*) {
    global running
    if running
        return
    ForceReleaseAll()
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

IsBagFull() {
    global fullBagImg
    return SearchInGame(fullBagImg, &x, &y, "*30 ")
}

IsBagShort() {
    global bagShortImg
    return SearchInGame(bagShortImg, &x, &y, "*30 ")
}

NeedsDropDuringSpace() {
    return IsBagFull() || IsBagShort()
}

SetDropPhase(msg) {
    global currentPhase
    currentPhase := msg
    state()
}

WaitBeforeBagShortDrop() {
    global running, bagShortDropDelayMs, lastBagShortWaitSec
    deadline := A_TickCount + bagShortDropDelayMs
    lastBagShortWaitSec := -1
    while A_TickCount < deadline {
        if !running
            return false
        remain := Ceil((deadline - A_TickCount) / 1000)
        if remain != lastBagShortWaitSec {
            lastBagShortWaitSec := remain
            SetDropPhase("包不足 → " remain " 秒後開始丟垃圾")
        }
        if !SleepCheck(100)
            return false
    }
    return true
}

IsPickupOnCooldown() {
    global pickupCooldownUntil
    return A_TickCount < pickupCooldownUntil
}

PickupCooldownRemainSec() {
    global pickupCooldownUntil
    remain := pickupCooldownUntil - A_TickCount
    return remain > 0 ? Ceil(remain / 1000) : 0
}

UpdatePickupCooldownPhase() {
    global lastCooldownDispSec, currentPhase
    remain := PickupCooldownRemainSec()
    if remain == lastCooldownDispSec
        return
    lastCooldownDispSec := remain
    currentPhase := "等垃圾消失 (剩 " remain " 秒，完全暫停)"
    state()
}

StartPickupCooldown() {
    global pickupCooldownUntil, pickupCooldownMs, lastCooldownDispSec
    pickupCooldownUntil := A_TickCount + pickupCooldownMs
    lastCooldownDispSec := -1
    UpdatePickupCooldownPhase()
}

BeginCooldown() {
    global trainPhase, running
    if !running
        return
    Key1Up()
    Key2Up()
    KeySpaceUp()
    ForceReleaseAll()
    trainPhase := "cooldown"
    StartPickupCooldown()
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

IsValidBagCoord(x, y) {
    global bagMinX, bagMinY
    return x >= bagMinX && y >= bagMinY
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

GetYamaJunkNames() {
    names := []
    Loop 13
        names.Push("山雜" A_Index)
    return names
}

GetYamaWuNames() {
    names := []
    Loop 23
        names.Push("山雜武" A_Index)
    return names
}

GetYamaShoNames() {
    names := []
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

FindJunkInNames(names, &outX, &outY, &outName) {
    idx := 1
    return SearchJunkList(names, &outX, &outY, &outName, &idx)
}

ResetPageSearchIdx() {
    global stuckCount, lastStuckName
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

DiscardOneConfirmList(names) {
    global running
    if !running
        return false
    EnsureMouseUp()
    if !FindJunkInNames(names, &nx, &ny, &name)
        return false
    if !DiscardWithConfirm(nx, ny)
        return false
    return true
}

DiscardOneSimple() {
    global running
    if !running
        return false
    EnsureMouseUp()
    if !FindJunkInNames(GetSimpleJunkNames(), &nx, &ny, &name)
        return false
    if !DiscardSimple(nx, ny)
        return false
    return true
}

DiscardOneTreasure() {
    global running
    if !running
        return false
    EnsureMouseUp()
    if !FindJunkInNames(GetTreasureNames(), &nx, &ny, &name)
        return false
    if !DiscardTreasure(nx, ny)
        return false
    return true
}

DiscardPageJunk(pageLabel := "") {
    global running, dlyDrop
    prefix := pageLabel != "" ? pageLabel " → " : ""

    ResetPageSearchIdx()
    SetDropPhase(prefix "丟山雜")
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneConfirmList(GetYamaJunkNames())
            break
    }
    SetDropPhase(prefix "丟山雜武")
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneConfirmList(GetYamaWuNames())
            break
    }
    SetDropPhase(prefix "丟山雜書")
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneConfirmList(GetYamaShoNames())
            break
    }
    SetDropPhase(prefix "丟山雜裝")
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneSimple()
            break
    }
    SetDropPhase(prefix "丟山寶")
    Loop {
        if !running
            return false
        if !SleepCheck(dlyDrop)
            return false
        if !DiscardOneTreasure()
            break
    }
    SetDropPhase(prefix "本頁清完")
    return running
}

OpenAndUnlockBag() {
    global running, lockNX, lockNY, itv

    if !running
        return false
    SetDropPhase("開啟背包")
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
    SetDropPhase("解鎖背包")
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

DismissBagShortagePopup() {
    global running, dlyDrop, bagShortImg, itv
    if !running
        return false
    if !SearchInGame(bagShortImg, &x, &y, "*30 ")
        return true
    SetDropPhase("包不足 → 關閉提示")
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

DismissBagShortage() {
    global running, skipPageDiscard, currentPhase, bagShortImg
    skipPageDiscard := false
    if !running
        return false
    if !SearchInGame(bagShortImg, &x, &y, "*30 ")
        return true
    if !DismissBagShortagePopup()
        return false
    skipPageDiscard := true
    SetDropPhase("包不足 → 跳過本頁丟棄")
    return true
}

SwitchBagPage(offsetX) {
    global lockNX, lockNY, running, dlyDrop, itv
    if !running || !lockNX
        return false
    SetDropPhase("切換背包分頁")
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

RunDropOnce(reason := "") {
    global running, currentPhase, dlyDrop, dropCount, skipPageDiscard

    if !running
        return false
    skipPageDiscard := false
    KeySpaceUp()
    ResetPageSearchIdx()
    if reason == ""
        reason := IsBagShort() ? "包不足" : "滿包"
    RefreshGameRect()
    if !OpenAndUnlockBag()
        return false
    if !SleepCheck(dlyDrop)
        return false
    if !DiscardPageJunk("第一頁")
        return false
    SetDropPhase("準備第二頁")
    if !SwitchBagPage(-160)
        return false
    if !SleepCheck(dlyDrop)
        return false
    if !skipPageDiscard {
        if !DiscardPageJunk("第二頁")
            return false
    } else {
        skipPageDiscard := false
        SetDropPhase("第二頁 → 包不足跳過")
    }
    SetDropPhase("準備第三頁")
    if !SwitchBagPage(-120)
        return false
    if !SleepCheck(dlyDrop)
        return false
    if !skipPageDiscard {
        if !DiscardPageJunk("第三頁")
            return false
    } else {
        skipPageDiscard := false
        SetDropPhase("第三頁 → 包不足跳過")
    }
    SetDropPhase("關閉背包")
    press("X", 100, 0)
    if !SleepCheck(500)
        return false
    dropCount++
    SetDropPhase(reason " → 丟垃圾完成")
    EnsureMouseUp()
    Key1Up()
    Key2Up()
    KeySpaceUp()
    return true
}

TryDropDuringSpace() {
    global running, bagDropDoneThisSpace, trainPhase, nextTick, nextBagCheck
    global bagCheckItv, currentPhase, spaceSec

    if bagDropDoneThisSpace || !NeedsDropDuringSpace()
        return false

    dropReason := IsBagShort() ? "包不足" : "滿包"
    bagDropDoneThisSpace := true
    trainPhase := "drop"
    KeySpaceUp()
    SetTimer(TrainTick, 0)
    if dropReason == "包不足" {
        if !WaitBeforeBagShortDrop() {
            SetTimer(TrainTick, 10)
            return false
        }
        DismissBagShortagePopup()
    }
    ok := RunDropOnce(dropReason)
    SetTimer(TrainTick, 10)
    if !running
        return ok

    if ok {
        BeginCooldown()
    } else {
        BeginSpam1()
    }
    return ok
}

BeginSpam1() {
    global trainPhase, spamEndTick, nextTick, currentPhase, spamSec, running
    if !running
        return
    Key2Up()
    KeySpaceUp()
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
    KeySpaceUp()
    trainPhase := "press2"
    press2Left := press2Count
    press2Step := "down"
    nextTick := A_TickCount
    currentPhase := "按 2 x" press2Count
    state()
}

BeginSpace() {
    global trainPhase, spaceEndTick, nextTick, nextBagCheck, currentPhase, spaceSec, running
    global bagDropDoneThisSpace, bagCheckItv
    if !running
        return
    Key1Up()
    Key2Up()
    KeySpaceUp()
    bagDropDoneThisSpace := false
    trainPhase := "space"
    spaceEndTick := A_TickCount + spaceSec * 1000
    nextTick := A_TickCount
    nextBagCheck := A_TickCount
    currentPhase := "連按空白 (" spaceSec " 秒)"
    state()
    TryDropDuringSpace()
}

NeedSpaceBreak() {
    global loopCount, spaceEveryN
    return spaceEveryN > 0 && Mod(loopCount, spaceEveryN) == 0
}

StartTrain() {
    global running, currentStatus, loopCount, dropCount, pickupCooldownUntil, lastCooldownDispSec
    if running
        return
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    if !FileExist(ImgPath(fullBagImg)) {
        FlashMsg("缺少 Lib\" fullBagImg)
        return
    }
    if !FileExist(ImgPath(bagShortImg)) {
        FlashMsg("缺少 Lib\" bagShortImg)
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
    if !FileExist(ImgPath("max")) {
        FlashMsg("缺少 Lib\max")
        return
    }
    SetTimer(EnsureStopped, 0)
    loopCount := 0
    dropCount := 0
    pickupCooldownUntil := 0
    lastCooldownDispSec := -1
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
    global running, trainPhase, spamEndTick, spaceEndTick, nextTick, nextBagCheck, bagCheckItv
    global press2Left, press2Step, loopCount, spamInterval, currentPhase, spacePrepMs
    global key1Held, key2Held, keySpaceHeld

    if !IsTrainActive()
        return

    now := A_TickCount

    if trainPhase == "cooldown" {
        if IsPickupOnCooldown() {
            UpdatePickupCooldownPhase()
            return
        }
        if !IsTrainActive()
            return
        BeginSpam1()
        return
    }

    if trainPhase == "spam1" {
        if now >= spamEndTick {
            Key1Up()
            if !IsTrainActive()
                return
            BeginPress2()
            return
        }
        if now < nextTick
            return
        if !key1Held
            Key1Down()
        else
            Key1Up()
        nextTick := now + spamInterval
        return
    }

    if trainPhase == "press2" {
        if now < nextTick
            return
        if press2Step == "down" {
            Key2Down()
            press2Step := "up"
            nextTick := now + 80
            return
        }
        Key2Up()
        press2Left--
        if press2Left <= 0 {
            loopCount++
            currentPhase := "第 " loopCount " 輪完成"
            state()
            if !IsTrainActive()
                return
            if NeedSpaceBreak() {
                currentPhase := "等待撿物 (0.5 秒)"
                state()
                if !SleepCheck(spacePrepMs)
                    return
                if !IsTrainActive()
                    return
                BeginSpace()
            } else
                BeginSpam1()
            return
        }
        press2Step := "down"
        nextTick := now + 150
        return
    }

    if trainPhase == "space" {
        if bagDropDoneThisSpace {
            KeySpaceUp()
            return
        }
        if now >= nextBagCheck {
            nextBagCheck := now + bagCheckItv
            TryDropDuringSpace()
            if !IsTrainActive()
                return
        }
        if now >= spaceEndTick {
            KeySpaceUp()
            if !IsTrainActive()
                return
            BeginSpam1()
            return
        }
        if now < nextTick
            return
        if !keySpaceHeld
            KeySpaceDown()
        else
            KeySpaceUp()
        nextTick := now + spamInterval
    }
}

state() {
    global currentStatus, currentPhase, loopCount, dropCount, spamSec, press2Count
    global spaceEveryN, spaceSec, win_width, win_height, winPosSet, clientW, clientH

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"

    SetStatusText("【現況】`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . "練功: " loopCount " 輪  丟垃圾: " dropCount " 次`r`n"
        . "────────────────`r`n"
        . "設定: 1 連打 " spamSec " 秒 → 2 x" press2Count "`r`n"
        . "每 " spaceEveryN " 輪 → 空白 " spaceSec " 秒`r`n"
        . posInfo)
}

InitApp() {
    global SC1, SC2, SCSpace
    SC1 := GetKeySC("1")
    SC2 := GetKeySC("2")
    SCSpace := GetKeySC("Space")
    ini()
    BuildMacroPanel("爆破山脈-終", infoText, hotkeyText, StartTrain, StopTrain)
    state()
    SetTimer(RefreshGamePos, 500)
}
