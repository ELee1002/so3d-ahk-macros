/*  綜合輔助：吃小幫手 + 死亡通知
 *  幫手 Ctrl+Z/X；死亡 Alt+Z/X 啟動／暫停（不自動開）
 */
#Requires AutoHotkey v2.0
#Include Lib\AutoHotInterception.ahk
#Include Common.ahk
#SingleInstance Force

global AHI := AutoHotInterception()
LoadCommonCfg()

; ── 吃小幫手 ──
global helperHours := 12
global eatRemainSec := 60
global helperExpire := ""
global lastRemainDisp := -1
global currentPhase := "待機"
global eating := false
global trainPauseMs := 500
global trainResumeMs := 300
global trainStopCount := 4
global imgVar := 30
global itv := 300
global wrongEatTimeoutMs := 20000
global wrongEatAppearMs := 6000
global lateWrongEatMs := 5000
global eatHoldMs := 120
global eatGapMs := 150
global trainKeyHoldMs := 60
global trainKeyGapMs := 120
global eatPressTries := 3
global activateWaitMs := 1500
global eatLogPath := A_ScriptDir "\吃小幫手_log.txt"
global helperWarnSent := false

; ── 死亡通知（獨立開關，不共用 running）──
global deathImg := "血條"
global deathImgVar := 20
global scanMs := 500
global notifyCount := 0
global deathSeen := false
global lastNotifyAt := ""
global deathRunning := false
global deathStatus := "待機"
global deathPhase := "待機"
global hitScansNeeded := 3
global clearScansNeeded := 20
global notifyCooldownMs := 120000
global hitScans := 0
global clearScans := 0
global lastNotifyTick := 0

global infoText := "
(
【功能】
幫手：12 小時倒數，剩 1 分鐘自動喝
死亡：找血條，確認後發 DC

【備註】
快捷 0 放藥水；喝前後 F2/F1
啟動幫手必開小幫手
Ctrl+1 不喝只開幫手
設定要勾[狀態資訊]
)"
global hotkeyText := "
(
【熱鍵】
Ctrl+Z 幫手開始  Ctrl+X 停
Alt+Z 死亡開始  Alt+X 停
F4 現在喝  Ctrl+1 只開幫手
Ctrl+F3 重載  Ctrl+Esc 關
)"

InitApp()
return

^z::StartHelper()
^x::StopHelper()
!z::StartWatch()
!x::StopWatch()
F4::DrinkNow()
^1::StartHelperMenuOnly()
^F3::{
    StopHelper()
    StopWatch()
    Reload
}
^Esc::ExitApp

OnExit(*) {
    StopHelper()
    StopWatch()
    SetTimer(HelperTick, 0)
    SetTimer(WatchTick, 0)
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
    global helperExpire, helperHours, helperWarnSent
    helperExpire := DateAdd(A_Now, helperHours, "Hours")
    writeCfg("helper_expire", helperExpire)
    helperWarnSent := false
}

StartHelper() {
    global running, currentStatus, currentPhase, lastRemainDisp, helperExpire
    if running
        return
    gameFound := ActivateGame()
    LoadHelperExpire()
    lastRemainDisp := -1
    running := true
    currentStatus := gameFound ? "啟動先喝一次" : "找不到遊戲視窗"
    currentPhase := "啟動先喝一次"
    state()

    EatHelper("啟動先喝一次")

    if !IsValidStamp(helperExpire) {
        ResetExpireFromNow()
        currentPhase := "沒喝到，先假設滿 12 小時"
    }
    lastRemainDisp := -1
    currentStatus := gameFound ? "倒數中" : "倒數中（找不到遊戲視窗）"
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

WaitWrongEatAppear(timeoutMs, label := "等誤吃") {
    global currentPhase
    deadline := A_TickCount + timeoutMs
    while running && A_TickCount < deadline {
        currentPhase := label
        state()
        if SearchInGame("誤吃", &wx, &wy, "*100 ")
            return true
        if !SleepCheck(200)
            return false
    }
    return false
}

HandleWrongEat(forceStart := false) {
    global currentPhase, wrongEatTimeoutMs, wrongEatAppearMs
    if !SleepCheck(300)
        return false

    if !forceStart && !WaitWrongEatAppear(wrongEatAppearMs)
        return running

    deadline := A_TickCount + wrongEatTimeoutMs
    useAltConfirm := false

    while running && A_TickCount < deadline {
        currentPhase := "找誤吃"
        state()
        if SearchInGame("誤吃", &wx, &wy, "*100 ") {
            currentPhase := "點誤吃確認"
            state()
            ox := useAltConfirm ? 120 : 70
            if !ClickGame(wx + ox, wy + 90)
                return false
            useAltConfirm := !useAltConfirm
            if !SleepCheck(400)
                return false
            continue
        }

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
            LogEat("小幫手已啟動（" startName "）")
            return SleepCheck(300)
        }
        if !SleepCheck(300)
            return false
    }
    currentPhase := forceStart ? "啟動小幫手逾時" : "誤吃流程逾時"
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

StartHelperMenuOnly() {
    global running, eating, currentStatus, currentPhase
    if eating
        return
    if !ActivateGame() {
        currentStatus := "找不到遊戲視窗"
        state()
        FlashMsg("找不到希望視窗")
        return
    }
    was := running
    running := true
    eating := true
    currentPhase := "只開小幫手"
    state()
    LogEat("=== 開始：只開小幫手（不按 0） ===")

    ok := false
    if SendTrainStop() {
        ok := HandleWrongEat(true)
        Loop 2
            MouseUp()
        if was
            SendTrainResume()
    }

    currentPhase := ok ? "小幫手已開，未喝藥" : "只開小幫手未完成"
    LogEat("=== 結束：" currentPhase " ===")
    eating := false
    if !was {
        running := false
        ReleaseAllKeys()
    }
    state()
}

LogEat(msg) {
    global eatLogPath
    try FileAppend(FormatTime(A_Now, "MM-dd HH:mm:ss") "  [" A_TickCount "]  " msg "`r`n", eatLogPath, "UTF-8")
}

EnsureGameActive() {
    global running, activateWaitMs
    hwnd := GetGameHwnd()
    if !hwnd
        return false
    if WinActive("ahk_id " hwnd)
        return true
    try WinActivate("ahk_id " hwnd)
    deadline := A_TickCount + activateWaitMs
    while running && A_TickCount < deadline {
        if WinActive("ahk_id " hwnd)
            return true
        Sleep(50)
    }
    return WinActive("ahk_id " hwnd) ? true : false
}

PressEatKey() {
    global currentPhase, eatHoldMs, eatGapMs, eatPressTries
    Loop eatPressTries {
        n := A_Index
        if !EnsureGameActive() {
            currentPhase := "等遊戲到前景（第 " n " 次）"
            state()
            LogEat("遊戲不在前景，放棄按 0（第 " n " 次）")
            if !SleepCheck(300)
                return false
            continue
        }
        currentPhase := "按快捷 0（第 " n " 次）"
        state()
        t0 := A_TickCount
        LogEat("送出 0 down（第 " n " 次）")
        ok := press("0", eatHoldMs, eatGapMs)
        used := A_TickCount - t0
        LogEat((ok ? "0 已送完" : "0 被中斷") "，耗時 " used " ms")
        currentPhase := (ok ? "0 已送出" : "0 被中斷") "，" used " ms"
        state()
        if ok
            return true
    }
    return false
}

SendTrainKey(key) {
    global trainKeyHoldMs, trainKeyGapMs
    EnsureGameActive()
    return press(key, trainKeyHoldMs, trainKeyGapMs)
}

SendTrainStop() {
    global currentPhase, trainStopCount, trainPauseMs
    currentPhase := "F2 停止練功"
    state()
    Loop trainStopCount {
        if !SendTrainKey("F2")
            return false
    }
    LogEat("F2 x" trainStopCount " 已用 AHI 送出")
    return SleepCheck(trainPauseMs)
}

SendTrainResume() {
    global currentPhase, trainResumeMs
    currentPhase := "F1 重開練功"
    state()
    if !SleepCheck(trainResumeMs)
        return false
    ok := SendTrainKey("F1")
    LogEat(ok ? "F1 已用 AHI 送出" : "F1 送出被中斷")
    return ok
}

EatHelper(reason := "自動喝") {
    global running, eating, currentPhase, lastRemainDisp, lateWrongEatMs
    global trainStopCount, trainPauseMs, helperExpire
    if eating
        return
    eating := true
    currentPhase := reason
    state()
    LogEat("=== 開始：" reason " ===")
    if !ActivateGame() {
        LogEat("ActivateGame 失敗，整個流程取消")
        eating := false
        state()
        return
    }

    if !SendTrainStop() {
        LogEat("F2 停練功被中斷，流程取消")
        eating := false
        state()
        return
    }
    LogEat("已等 " trainPauseMs " ms，開始按 0")

    ok := PressEatKey()
    if ok {
        ResetExpireFromNow()
        lastRemainDisp := -1
        LogEat("已重算 12 小時，到期 " helperExpire)
        NotifyHelperDc(InStr(reason, "啟動") ? "小幫手已吃開始倒數" : "小幫手已吃")
        state()
        ok := HandleWrongEat(InStr(reason, "啟動"))
    }

    Loop 2
        MouseUp()

    if running && SendTrainResume() {
        if WaitWrongEatAppear(lateWrongEatMs, "復原後再確認誤吃") {
            if SendTrainStop() {
                ok := HandleWrongEat()
                Loop 2
                    MouseUp()
                if running
                    SendTrainResume()
            }
        }
    }

    lastRemainDisp := -1
    currentPhase := ok ? "已按 0，練功已重開" : "誤吃未處理完，已試著重開練功"
    LogEat("=== 結束：" currentPhase " ===")
    eating := false
    state()
}

HelperTick(*) {
    global running, eatRemainSec, currentPhase, lastRemainDisp, eating, helperWarnSent
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
    if !helperWarnSent {
        helperWarnSent := true
        NotifyHelperDc("該吃小幫手")
    }
    EatHelper("剩 " eatRemainSec " 秒，自動喝")
}

NotifyHelperDc(text) {
    global lastWebhookOk
    stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    msg := "【希望戀曲】" text "  " stamp
    dcOk := SendDiscord(msg)
    LogEat((dcOk ? "DC 已送出" : "DC 未送出：" lastWebhookOk) "  " text)
}

StartWatch() {
    global deathRunning, deathStatus, deathPhase, deathSeen, hitScans, clearScans
    if deathRunning
        return
    deathSeen := false
    hitScans := 0
    clearScans := 0
    deathRunning := true
    deathStatus := "持續監看"
    deathPhase := "監看中"
    SetTimer(WatchTick, scanMs)
    state()
}

StopWatch(*) {
    global deathRunning, deathStatus, deathPhase
    deathRunning := false
    SetTimer(WatchTick, 0)
    deathStatus := "已暫停"
    deathPhase := "待機"
    state()
}

WatchTick(*) {
    global deathRunning, deathImg, deathSeen, notifyCount, lastNotifyAt
    global deathPhase, deathStatus, deathImgVar
    global hitScans, clearScans, hitScansNeeded, clearScansNeeded, notifyCooldownMs, lastNotifyTick
    if !deathRunning
        return
    if !FileExist(ImgPath(deathImg)) {
        if deathStatus != "找不到圖檔" {
            deathStatus := "找不到圖檔"
            deathPhase := "等待 Lib\" . deathImg
            state()
        }
        return
    }
    if GetWebhookUrl() == "" {
        if deathStatus != "未設定 webhook" {
            deathStatus := "未設定 webhook"
            deathPhase := "等待 cfg discord_webhook"
            state()
        }
        return
    }
    if deathStatus != "持續監看" {
        deathStatus := "持續監看"
        state()
    }
    found := SearchInGame(deathImg, &x, &y, "*" deathImgVar " ")
    if found {
        clearScans := 0
        if deathSeen
            return
        hitScans++
        if hitScans < hitScansNeeded {
            deathPhase := "疑似死亡 " hitScans "/" hitScansNeeded
            state()
            return
        }
        if A_TickCount - lastNotifyTick < notifyCooldownMs {
            deathPhase := "冷卻中，不重複通知"
            state()
            return
        }
        deathSeen := true
        deathPhase := "確認死亡，發送 DC"
        state()
        stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        msg := "【希望戀曲】偵測到死亡（血條）  " stamp
        if SendDiscord(msg) {
            notifyCount++
            lastNotifyAt := stamp
            lastNotifyTick := A_TickCount
            deathPhase := "已通知 Discord"
        } else {
            deathPhase := "DC 發送失敗"
            deathSeen := false
            hitScans := 0
        }
        state()
        return
    }
    hitScans := 0
    if !deathSeen
        return
    clearScans++
    if clearScans < clearScansNeeded {
        deathPhase := "已復活 " clearScans "/" clearScansNeeded
        state()
        return
    }
    deathSeen := false
    clearScans := 0
    deathPhase := "監看中"
    state()
}

state() {
    global currentStatus, currentPhase, helperHours, eatRemainSec
    global win_width, win_height, winPosSet, clientW, clientH, running
    global helperExpire, lastWebhookOk
    global deathStatus, deathPhase, notifyCount, lastNotifyAt, deathImg, deathRunning

    posInfo := winPosSet
        ? "視窗: " win_width "x" win_height
        : "視窗: 尚未定位"
    remainInfo := IsValidStamp(helperExpire)
        ? "剩餘: " FormatRemain(RemainSec())
        : "剩餘: 尚未計時"
    lastInfo := lastNotifyAt != "" ? lastNotifyAt : "尚無"
    hookInfo := lastWebhookOk != "" ? lastWebhookOk : (GetWebhookUrl() != "" ? "已設定" : "未設定")

    SetStatusText("【幫手】 " (running ? "開" : "關") "`r`n"
        . remainInfo "  " currentStatus "`r`n"
        . currentPhase "`r`n"
        . "【死亡】 " (deathRunning ? "開" : "關") "  " deathImg "`r`n"
        . deathStatus " / " deathPhase "`r`n"
        . "已通知 " notifyCount "  上次 " lastInfo "`r`n"
        . "DC: " hookInfo "`r`n"
        . posInfo)
}

InitApp() {
    global panelGui, statusEdit
    LoadHelperExpire()
    ini()

    if IsObject(panelGui)
        panelGui.Destroy()
    panelGui := Gui("+AlwaysOnTop +Caption -MaximizeBox -MinimizeBox -DPIScale", "綜合輔助")
    panelGui.SetFont("s8", "Microsoft JhengHei UI")
    panelGui.BackColor := "FFFFE0"
    panelGui.MarginX := 8
    panelGui.MarginY := 6
    panelGui.AddText("w158 Center", "綜合輔助").SetFont("s9 Bold")
    panelGui.AddText("w158", infoText)
    statusEdit := panelGui.AddEdit("w158 h110 ReadOnly -Wrap", "")
    panelGui.AddText("w158", hotkeyText)
    b1 := panelGui.AddButton("w75 h26", "幫手開始")
    b2 := panelGui.AddButton("x+8 w75 h26", "幫手停止")
    b3 := panelGui.AddButton("xm w75 h26", "死亡開始")
    b4 := panelGui.AddButton("x+8 w75 h26", "死亡停止")
    b1.OnEvent("Click", (*) => StartHelper())
    b2.OnEvent("Click", (*) => StopHelper())
    b3.OnEvent("Click", (*) => StartWatch())
    b4.OnEvent("Click", (*) => StopWatch())
    panelGui.OnEvent("Close", (*) => ExitApp())
    ShowMacroPanel()
    state()
    SetTimer(RefreshGamePos, 500)
}
