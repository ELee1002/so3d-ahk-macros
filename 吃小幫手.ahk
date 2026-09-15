/*  吃小幫手 (AHI 版，獨立 timer)
 *  與其他巨集並行：12 小時倒數，剩 1 分鐘時按快捷 0
 *  到期時間寫入 cfg.txt，重載／關再開仍接續
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

global helperHours := 12
global eatRemainSec := 60
global helperExpire := ""
global lastRemainDisp := -1
global currentPhase := "待機"
global eating := false
global trainPauseMs := 500
global trainResumeMs := 300
global imgVar := 30
global itv := 300
global wrongEatTimeoutMs := 20000

global infoText := "
(
【功能】
獨立倒數，可與練功巨集同時開
小幫手 12 小時
剩 1 分鐘自動按快捷 0
喝完後重算 12 小時

【備註】
快捷 0 放小幫手藥水
動作前 F2 停練功，完後 F1 再開
按 0 後若跳出誤吃：點確認 → 目錄 → 幫手 → start → Enter
需 Lib\誤吃、目錄、幫手、start（找不到再找 start2）
F4 現在喝並重置倒數
第一次若沒紀錄，先假設滿 12 小時
)"
global hotkeyText := "
(
【熱鍵】
Ctrl+Z 開始  Ctrl+X 停止
或下方按鈕
F4 現在喝並重置
F3 重載  Ctrl+Esc 關
)"

InitApp()
return

^z::StartHelper()
^x::StopHelper()
F3::{
    StopHelper()
    Reload
}
F4::DrinkNow()
^Esc::ExitApp

OnExit(*) {
    StopHelper()
    SetTimer(HelperTick, 0)
    SetTimer(RefreshGamePos, 0)
}

LoadHelperExpire() {
    global helperExpire
    val := read("helper_expire", 0)
    helperExpire := IsValidStamp(val) ? val : ""
}

IsValidStamp(val) {
    return val != "" && StrLen(val) == 14 && IsNumber(val)
}

RemainSec() {
    global helperExpire
    if !IsValidStamp(helperExpire)
        return 0
    return DateDiff(helperExpire, A_Now, "Seconds")
}

FormatRemain(sec) {
    if sec < 0
        sec := 0
    h := sec // 3600
    m := Mod(sec, 3600) // 60
    s := Mod(sec, 60)
    return Format("{:02}:{:02}:{:02}", h, m, s)
}

ResetExpireFromNow() {
    global helperExpire, helperHours
    helperExpire := DateAdd(A_Now, helperHours, "Hours")
    writeCfg("helper_expire", helperExpire)
}

StartHelper() {
    global running, currentStatus, currentPhase, lastRemainDisp
    if running
        return
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    LoadHelperExpire()
    if !IsValidStamp(helperExpire) {
        ResetExpireFromNow()
        currentPhase := "無紀錄，已假設滿 12 小時"
    } else {
        currentPhase := "倒數中"
    }
    lastRemainDisp := -1
    running := true
    currentStatus := "運行中"
    SetTimer(HelperTick, 1000)
    state()
}

StopHelper() {
    global running, currentStatus, currentPhase, eating
    running := false
    eating := false
    SetTimer(HelperTick, 0)
    ReleaseAllKeys()
    currentStatus := "已暫停"
    currentPhase := "待機"
    state()
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

ClickGame(x, y, holdMs := 0) {
    global itv
    if holdMs <= 0
        holdMs := itv
    MoveGame(x, y)
    if !SleepCheck(300)
        return false
    MouseDown()
    if !SleepCheck(holdMs) {
        MouseUp()
        return false
    }
    MouseUp()
    return SleepCheck(300)
}

HandleWrongEat() {
    global currentPhase, wrongEatTimeoutMs
    if !SleepCheck(500)
        return false
    currentPhase := "檢查誤吃"
    state()
    if !SleepCheck(300)
        return false
    if !SearchInGame("誤吃", &wx, &wy, "*100 ")
        return true

    currentPhase := "點誤吃確認"
    state()
    if !ClickGame(wx + 70, wy + 90)
        return false

    deadline := A_TickCount + wrongEatTimeoutMs
    while running && A_TickCount < deadline {
        MoveGame(0, 0)
        if !SleepCheck(300)
            return false

        currentPhase := "找目錄"
        state()
        if SearchInGame("目錄", &dx, &dy, "*30 ") {
            if !ClickGame(dx, dy)
                return false
        }
        if !SleepCheck(300)
            return false

        currentPhase := "找幫手"
        state()
        if SearchInGame("幫手", &hx, &hy, "*30 ") {
            if !ClickGame(hx + 10, hy + 10)
                return false
        }

        currentPhase := "找 start"
        state()
        if !SleepCheck(300)
            return false
        foundStart := SearchInGame("start", &sx, &sy, "*20 ")
        startName := "start"
        if !foundStart {
            currentPhase := "找 start2"
            state()
            foundStart := SearchInGame("start2", &sx, &sy, "*20 ")
            startName := "start2"
        }
        if foundStart {
            currentPhase := "點 " startName
            state()
            if !ClickGame(sx, sy)
                return false
            if !press("Enter", 100, 0)
                return false
            if !SleepCheck(300)
                return false
            if !press("Enter", 100, 0)
                return false
            return SleepCheck(300)
        }
        if !SleepCheck(300)
            return false
    }
    currentPhase := "誤吃流程逾時"
    state()
    return false
}

DrinkNow() {
    global running, currentStatus
    if running
        return EatHelper("F4 手動喝")
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    was := running
    running := true
    EatHelper("F4 手動喝")
    if !was {
        running := false
        ReleaseAllKeys()
    }
}

EatHelper(reason := "自動喝") {
    global running, eating, currentPhase, lastRemainDisp, trainPauseMs, trainResumeMs
    if eating
        return
    eating := true
    currentPhase := reason
    state()
    if !ActivateGame() {
        eating := false
        return
    }

    currentPhase := "F2 停止練功"
    state()
    Send("{F2}")
    if !SleepCheck(trainPauseMs) {
        eating := false
        return
    }

    currentPhase := "按快捷 0"
    state()
    ok := press("0", 500, 100)
    if ok {
        ResetExpireFromNow()
        ok := HandleWrongEat()
    }

    Loop 2
        MouseUp()

    if running {
        currentPhase := "F1 重開練功"
        state()
        if !SleepCheck(trainResumeMs) {
            eating := false
            lastRemainDisp := -1
            state()
            return
        }
        Send("{F1}")
    }

    lastRemainDisp := -1
    currentPhase := ok ? "已按 0，練功已重開" : "按 0 失敗，已試著重開練功"
    eating := false
    state()
}

HelperTick(*) {
    global running, eatRemainSec, currentPhase, lastRemainDisp, eating
    if !running || eating
        return
    remain := RemainSec()
    if remain != lastRemainDisp {
        lastRemainDisp := remain
        currentPhase := remain <= eatRemainSec ? "準備喝小幫手" : "倒數中"
        state()
    }
    if remain > eatRemainSec
        return
    EatHelper("剩 " eatRemainSec " 秒，自動喝")
}

state() {
    global currentStatus, currentPhase, helperHours, eatRemainSec
    global win_width, win_height, winPosSet, clientW, clientH, running
    global helperExpire

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height "  客戶區: " clientW "x" clientH
        : "視窗: 尚未定位"
    remainInfo := IsValidStamp(helperExpire)
        ? "剩餘: " FormatRemain(RemainSec())
        : "剩餘: 尚未計時"

    SetStatusText("【現況】`r`n"
        . "週期: " helperHours " 小時  提前: " eatRemainSec " 秒`r`n"
        . remainInfo "`r`n"
        . "狀態: " currentStatus "`r`n"
        . "階段: " currentPhase "`r`n"
        . posInfo)
}

InitApp() {
    LoadHelperExpire()
    ini()
    BuildMacroPanel("吃小幫手", infoText, hotkeyText, StartHelper, StopHelper)
    state()
    SetTimer(RefreshGamePos, 500)
}
