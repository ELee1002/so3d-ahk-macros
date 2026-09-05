; 自寫巨集共用基礎（AutoHotkey v2.0 + AHI）
#Requires AutoHotkey v2.0

RequireAdmin()

global WinTitle := "TW_LIVE"
global WinTitleExe := "ahk_exe SO3DPlus.exe"
global fname := A_ScriptDir "\cfg.txt"

global winPosSet := 0
global winX := 0
global winY := 0
global win_width := 2000
global win_height := 0
global centerX := 0
global centerY := 0
global shfitX := 7
global shfitY := 35
global clientW := 0
global clientH := 0

global running := false
global keyboardId := 1
global mouseID := 11

GetKeySC(keyName) {
    ; AHI 延伸鍵須用壓縮掃描碼（base + 256）；MapVirtualKey 常拿不到 E0，Up 會變成 8
    static extSC := Map(
        "Up", 0x148, "Down", 0x150, "Left", 0x14B, "Right", 0x14D,
        "Home", 0x147, "End", 0x14F, "PgUp", 0x149, "PgDn", 0x151,
        "Insert", 0x152, "Delete", 0x153, "Del", 0x153,
        "NumpadEnter", 0x11C, "RShift", 0x136, "RControl", 0x11D,
        "RCtrl", 0x11D, "RAlt", 0x138, "LWin", 0x15B, "RWin", 0x15C,
        "AppsKey", 0x15D
    )
    if extSC.Has(keyName)
        return extSC[keyName]
    vk := GetKeyVK(keyName)
    if !vk
        return 0
    return DllCall("MapVirtualKey", "UInt", vk, "UInt", 0, "UInt")
}

read(nm, md := 0) {
    global fname
    if !FileExist(fname)
        return ""
    for line in StrSplit(FileRead(fname), "`n") {
        line := StrReplace(line, Chr(13), "")
        if InStr(line, nm "=") != 1
            continue
        val := SubStr(line, StrLen(nm) + 2)
        if md
            return StrSplit(val, ",", " ")
        return StrSplit(val, ",", " ")[1]
    }
    return ""
}

readNum(nm, default := 0) {
    val := read(nm, 0)
    if val != "" && IsNumber(val)
        return Integer(val)
    return default
}

writeCfg(nm, val) {
    global fname
    lines := FileExist(fname) ? StrSplit(FileRead(fname), "`n") : []
    found := false
    for i, line in lines {
        line := StrReplace(line, Chr(13), "")
        if InStr(line, nm "=") == 1 {
            lines[i] := nm "=" val
            found := true
            break
        }
    }
    if !found
        lines.Push(nm "=" val)
    out := ""
    for i, line in lines {
        if i > 1
            out .= "`n"
        out .= line
    }
    FileOpen(fname, "w", "UTF-8").Write(out "`n")
}

GetGameHwnd() {
    global WinTitleExe, WinTitle
    if hwnd := WinExist(WinTitleExe)
        return hwnd
    if hwnd := WinExist(WinTitle)
        return hwnd
    return WinExist("ahk_class SO3D")
}

RefreshClientMetrics(hwnd) {
    global clientW, clientH
    WinGetClientPos(, , &clientW, &clientH, "ahk_id " hwnd)
}

GetTipX() {
    global win_width, winPosSet, winX
    if winPosSet && win_width
        return winX + win_width
    return A_ScreenWidth - 300
}

GetTipY() {
    return 20
}

ini() {
    global winPosSet, winX, winY, win_width, win_height, centerX, centerY
    hwnd := GetGameHwnd()
    if !hwnd
        return false
    WinGetPos(&winX, &winY, &win_width, &win_height, hwnd)
    winPosSet := win_width ? 1 : 0
    if !winPosSet
        return false
    centerX := win_width / 2
    centerY := win_height / 2
    RefreshClientMetrics(hwnd)
    return true
}

ActivateGame() {
    global winPosSet, winX, winY, win_width, win_height, centerX, centerY
    hwnd := GetGameHwnd()
    if !hwnd
        return false
    WinActivate(hwnd)
    WinWaitActive(hwnd, , 2)
    WinGetPos(&winX, &winY, &win_width, &win_height, hwnd)
    centerX := win_width / 2
    centerY := win_height / 2
    RefreshClientMetrics(hwnd)
    winPosSet := win_width ? 1 : 0
    return winPosSet
}

SleepCheck(ms) {
    global running
    if ms <= 0
        return running
    end := A_TickCount + ms
    while running && A_TickCount < end
        Sleep(10)
    return running
}

ReleaseAllKeys() {
    global keyboardId, AHI
    for key in ["4", "5", "1", "2", "3", "6", "7", "8", "9", "0",
        "Up", "Down", "Left", "Right",
        "Ctrl", "Alt", "Shift", "Enter", "Escape", "Tab", "Space"] {
        try
            AHI.SendKeyEvent(keyboardId, GetKeySC(key), 0)
    }
}

press(key, itv := 30, dly := 0) {
    global keyboardId, running, AHI
    if !running
        return false
    sc := GetKeySC(key)
    AHI.SendKeyEvent(keyboardId, sc, 1)
    if !SleepCheck(itv) {
        AHI.SendKeyEvent(keyboardId, sc, 0)
        return false
    }
    AHI.SendKeyEvent(keyboardId, sc, 0)
    if dly > 0 && !SleepCheck(dly)
        return false
    return true
}

show(str := "", t := 0, n := 2, x := 0, y := 0) {
    x := x ? x : GetTipX()
    y := y ? y : GetTipY() + 30
    ToolTip(str, x, y, n)
    if t > 0 {
        Sleep t
        ToolTip(,,, n)
        try
            state()
    }
}

LoadCommonCfg() {
    global keyboardId, mouseID, shfitX, shfitY
    keyboardId := readNum("keyboardId", 1)
    mouseID := readNum("mouseID", 11)
    shfitX := readNum("shiftX", 7)
    shfitY := readNum("shiftY", 35)
}

; ── 標準 GUI 模板（單一視窗：功能/備註 + 現況 + 開始/停止）──

global panelGui := ""
global statusEdit := ""
global currentStatus := "待機"
global gStartFn := ""
global gStopFn := ""

OnBtnStart(*) {
    global gStartFn
    if gStartFn is Func
        gStartFn.Call()
}

OnBtnStop(*) {
    global gStopFn
    if gStopFn is Func
        gStopFn.Call()
}

BuildMacroPanel(title, infoText, hotkeyText, startFn, stopFn) {
    global panelGui, statusEdit, gStartFn, gStopFn

    if !(startFn is Func) || !(stopFn is Func)
        throw Error("BuildMacroPanel: startFn / stopFn 必須是函式")

    gStartFn := startFn
    gStopFn := stopFn

    if IsObject(panelGui)
        panelGui.Destroy()

    panelGui := Gui("+AlwaysOnTop +Caption -MaximizeBox -MinimizeBox -DPIScale", title)
    panelGui.SetFont("s8", "Microsoft JhengHei UI")
    panelGui.BackColor := "FFFFE0"
    panelGui.MarginX := 8
    panelGui.MarginY := 6

    panelGui.AddText("w158 Center", title).SetFont("s9 Bold")
    panelGui.AddText("w158", infoText)
    statusEdit := panelGui.AddEdit("w158 h90 ReadOnly -Wrap", "")
    panelGui.AddText("w158", hotkeyText)

    btnStart := panelGui.AddButton("w75 h26", "▶ 開始")
    btnStop := panelGui.AddButton("x+8 w75 h26", "■ 停止")
    btnStart.OnEvent("Click", OnBtnStart)
    btnStop.OnEvent("Click", OnBtnStop)
    panelGui.OnEvent("Close", GuiClose)

    ShowMacroPanel()
}

GuiClose(*) {
    ExitApp()
}

ShowMacroPanel() {
    global panelGui
    if !IsObject(panelGui)
        return
    MonitorGetWorkArea(, &wl, &wt, &wr, &wb)
    panelGui.Show("x" (wr - 185) " y" (wt + 10) " AutoSize")
    SetPanelTopMost()
}

SetPanelTopMost() {
    global panelGui
    if IsObject(panelGui)
        WinSetAlwaysOnTop(true, panelGui.Hwnd)
}

RefreshGamePos(*) {
    global winPosSet, winX, winY, win_width, win_height
    hwnd := GetGameHwnd()
    if hwnd {
        WinGetPos(&winX, &winY, &win_width, &win_height, hwnd)
        winPosSet := win_width ? 1 : 0
        if winPosSet
            RefreshClientMetrics(hwnd)
    } else {
        winPosSet := 0
    }
    try state()
}

SetStatusText(text) {
    global statusEdit
    if IsObject(statusEdit)
        statusEdit.Value := text
    SetPanelTopMost()
}

FlashMsg(msg, ms := 1200) {
    global currentStatus
    oldStatus := currentStatus
    SetStatusText("【提示】`r`n" msg)
    Sleep(ms)
    currentStatus := oldStatus
    try state()
}

RequireAdmin() {
    if A_IsAdmin
        return
    try {
        if A_IsCompiled
            Run('*RunAs "' A_ScriptFullPath '"')
        else
            Run('*RunAs "' A_AhkPath '" /script "' A_ScriptFullPath '"')
    }
    ExitApp()
}
