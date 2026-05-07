; =============================================
;  Bongo Cat - All-in-One Script
;  AutoHotkey v2
;  F5 = Settings (фиксиран)
;  Всички останали hotkey-и са конфигурируеми
;  от Settings > Hotkeys
; =============================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; -------------------------------------------------------
;  Defaults
; -------------------------------------------------------
iniFile       := A_ScriptDir "\BongoCat.ini"
exeName       := "BongoCat.exe"

; Claimer
claimOffset   := 30.5 * 60 * 1000
guiOffsetY    := 40

; Spam / Typing
clicking      := false
spamming      := false
userIdle      := false
idleTimeout   := 1000
burstMin      := 3
burstMax      := 8
fastDelayMin  := 60
fastDelayMax  := 140
pauseMin      := 300
pauseMax      := 900
spamInterval  := 1
clickCount    := 3

; Chest state
skinX         := 0
skinY         := 0
cosX          := 0
cosY          := 0
skinNext      := 0
cosNext       := 0
setupStep     := 0
bongohwnd     := 0
claiming      := false

; Overlay GUI
guiVisible    := false
skinGui       := ""
cosGui        := ""

; Hotkey defaults
hkTyping      := "F6"
hkSpam        := "F8"
hkOverlay     := "F9"
hkSetup       := "F10"
hkClaim       := "F12"
hkQuit        := "F7"

; -------------------------------------------------------
;  Startup
; -------------------------------------------------------
LoadConfig()
RegisterHotkeys()

; -------------------------------------------------------
;  LoadConfig
; -------------------------------------------------------
LoadConfig() {
    global iniFile, claimOffset, idleTimeout
    global burstMin, burstMax, fastDelayMin, fastDelayMax
    global pauseMin, pauseMax, spamInterval
    global skinX, skinY, cosX, cosY, skinNext, cosNext

    if !FileExist(iniFile) {
        WriteDefaultIni()
        ToolTip("Няма config. Натисни F10 за Setup на chest-овете.")
        Sleep(3000)
        ToolTip()
        return
    }

    ; Settings
    claimMins    := Float(IniRead(iniFile,   "Settings", "ClaimMinutes",  30.5))
    claimOffset  := claimMins * 60 * 1000
    idleTimeout  := Integer(IniRead(iniFile, "Settings", "IdleTimeout",   1000))

    ; Typing
    burstMin     := Integer(IniRead(iniFile, "Typing", "BurstMin",     3))
    burstMax     := Integer(IniRead(iniFile, "Typing", "BurstMax",     8))
    fastDelayMin := Integer(IniRead(iniFile, "Typing", "FastDelayMin", 60))
    fastDelayMax := Integer(IniRead(iniFile, "Typing", "FastDelayMax", 140))
    pauseMin     := Integer(IniRead(iniFile, "Typing", "PauseMin",     300))
    pauseMax     := Integer(IniRead(iniFile, "Typing", "PauseMax",     900))
    spamInterval := Integer(IniRead(iniFile, "Typing", "SpamInterval", 1))
    clickCount   := Integer(IniRead(iniFile, "Typing", "ClickCount",   3))

    ; Hotkeys
    hkTyping    := IniRead(iniFile, "Hotkeys", "Typing",    "F6")
    hkSpam      := IniRead(iniFile, "Hotkeys", "Spam",      "F8")
    hkOverlay   := IniRead(iniFile, "Hotkeys", "Overlay",   "F9")
    hkSetup     := IniRead(iniFile, "Hotkeys", "Setup",     "F10")
    hkClaim     := IniRead(iniFile, "Hotkeys", "Claim",     "F12")
    hkQuit      := IniRead(iniFile, "Hotkeys", "Quit",      "F7")

    ; Coords
    skinX    := Integer(IniRead(iniFile, "Coords",     "SkinX",    0))
    skinY    := Integer(IniRead(iniFile, "Coords",     "SkinY",    0))
    cosX     := Integer(IniRead(iniFile, "Coords",     "CosX",     0))
    cosY     := Integer(IniRead(iniFile, "Coords",     "CosY",     0))
    skinNext := Integer(IniRead(iniFile, "Timestamps", "SkinNext", 0))
    cosNext  := Integer(IniRead(iniFile, "Timestamps", "CosNext",  0))

    if (skinX = 0 || cosX = 0) {
        ToolTip("Няма chest координати. Натисни F10 за Setup.")
        Sleep(3000)
        ToolTip()
        return
    }

    SetTimer(AutoClaim, 1000)
    CreateOverlayGuis()
    ShowOverlayGuis()
    SetTimer(UpdateGui, 1000)
}

WriteDefaultIni() {
    global iniFile
    IniWrite(30.5, iniFile, "Settings", "ClaimMinutes")
    IniWrite(1000, iniFile, "Settings", "IdleTimeout")
    IniWrite(3,    iniFile, "Typing",   "BurstMin")
    IniWrite(8,    iniFile, "Typing",   "BurstMax")
    IniWrite(60,   iniFile, "Typing",   "FastDelayMin")
    IniWrite(140,  iniFile, "Typing",   "FastDelayMax")
    IniWrite(300,  iniFile, "Typing",   "PauseMin")
    IniWrite(900,  iniFile, "Typing",   "PauseMax")
    IniWrite(1,    iniFile, "Typing",   "SpamInterval")
    IniWrite(3,    iniFile, "Typing",   "ClickCount")
    IniWrite("F6",  iniFile, "Hotkeys", "Typing")
    IniWrite("F8",  iniFile, "Hotkeys", "Spam")
    IniWrite("F9",  iniFile, "Hotkeys", "Overlay")
    IniWrite("F10", iniFile, "Hotkeys", "Setup")
    IniWrite("F12", iniFile, "Hotkeys", "Claim")
    IniWrite("F7",  iniFile, "Hotkeys", "Quit")
}

; -------------------------------------------------------
;  Динамична регистрация на hotkey-и
; -------------------------------------------------------
RegisterHotkeys() {

    Hotkey(hkTyping,    ToggleTyping)
    Hotkey(hkSpam,      ToggleSpam)
    Hotkey(hkOverlay,   ToggleOverlay)
    Hotkey(hkSetup,     StartSetup)
    Hotkey(hkClaim,     ManualClaim)
    Hotkey(hkQuit,      QuitScript)
}

UnregisterHotkeys() {

    try Hotkey(hkTyping,    "Off")
    try Hotkey(hkSpam,      "Off")
    try Hotkey(hkOverlay,   "Off")
    try Hotkey(hkSetup,     "Off")
    try Hotkey(hkClaim,     "Off")
    try Hotkey(hkQuit,      "Off")
}

; -------------------------------------------------------
;  F5 — Settings (фиксиран)
; -------------------------------------------------------
F5:: OpenSettings()

OpenSettings() {
    global iniFile, claimOffset, idleTimeout
    global burstMin, burstMax, fastDelayMin, fastDelayMax
    global pauseMin, pauseMax, spamInterval

    sg := Gui("+AlwaysOnTop", "Bongo Cat — Settings")
    sg.SetFont("s9", "Segoe UI")
    sg.MarginX := 12
    sg.MarginY := 10

    lw  := 190  ; ширина на label колоната
    ew  := 90   ; ширина на edit колоната
    gw  := lw + ew + 30  ; ширина на GroupBox
    row := "y+4"  ; вертикален gap между редовете

    ; --- Claimer ---
    sg.Add("GroupBox", "w" gw " h78 Section", "Claimer")
    sg.Add("Text",  "xp+10 yp+22 w" lw " h20 +0x200", "Claim интервал (минути):")
    sg.Add("Edit",  "vClaimMinutes x+8 w" ew " h20",
        Float(IniRead(iniFile, "Settings", "ClaimMinutes", 30.5)))
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Кликове на chest:")
    sg.Add("Edit",  "vClickCount x+8 w" ew " h20 Number", clickCount)

    ; --- Realistic Typing ---
    sg.Add("GroupBox", "xs w" gw " h188 y+10 Section", "Realistic Typing")
    sg.Add("Text",  "xp+10 yp+22 w" lw " h20 +0x200", "Burst min:")
    sg.Add("Edit",  "vBurstMin x+8 w" ew " h20 Number", burstMin)
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Burst max:")
    sg.Add("Edit",  "vBurstMax x+8 w" ew " h20 Number", burstMax)
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Fast delay min (ms):")
    sg.Add("Edit",  "vFastDelayMin x+8 w" ew " h20 Number", fastDelayMin)
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Fast delay max (ms):")
    sg.Add("Edit",  "vFastDelayMax x+8 w" ew " h20 Number", fastDelayMax)
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Pause min (ms):")
    sg.Add("Edit",  "vPauseMin x+8 w" ew " h20 Number", pauseMin)
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Pause max (ms):")
    sg.Add("Edit",  "vPauseMax x+8 w" ew " h20 Number", pauseMax)
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Idle timeout (ms):")
    sg.Add("Edit",  "vIdleTimeout x+8 w" ew " h20 Number", idleTimeout)

    ; --- Spam ---
    sg.Add("GroupBox", "xs w" gw " h52 y+10 Section", "Spam")
    sg.Add("Text",  "xp+10 yp+22 w" lw " h20 +0x200", "Spam интервал (ms):")
    sg.Add("Edit",  "vSpamInterval x+8 w" ew " h20 Number", spamInterval)

    ; --- Hotkeys ---
    ; Текущите стойности се пазят в Map — бутоните ги update-ват
    hkMap := Map(
        "Typing",  hkTyping,
        "Spam",    hkSpam,
        "Overlay", hkOverlay,
        "Setup",   hkSetup,
        "Claim",   hkClaim,
        "Quit",    hkQuit
    )

    sg.Add("GroupBox", "xs w" gw " h182 y+10 Section", "Hotkeys  (натисни бутона, после натисни желания клавиш)")

    MakeHkRow(label, key, sg, lw, ew, row) {
        sg.Add("Text", "xs+10 " row " w" lw " h20 +0x200", label)
        btn := sg.Add("Button", "x+8 w" ew " h20", hkMap[key])
        btn.OnEvent("Click", StartCapture.Bind(btn, key, hkMap))
        return btn
    }

    MakeHkRow("Toggle Realistic Typing:", "Typing",  sg, lw, ew, "yp+22")
    MakeHkRow("Toggle Spam:",             "Spam",    sg, lw, ew, row)
    MakeHkRow("Toggle Overlay GUI:",      "Overlay", sg, lw, ew, row)
    MakeHkRow("Setup chest координати:",  "Setup",   sg, lw, ew, row)
    MakeHkRow("Force Claim:",             "Claim",   sg, lw, ew, row)
    MakeHkRow("Quit:",                    "Quit",    sg, lw, ew, row)

    ; --- Бутони ---
    btnOK     := sg.Add("Button", "xs w" (gw//2 - 4) " y+14 Default", "OK")
    btnCancel := sg.Add("Button", "w" (gw//2 - 4) " x+8", "Cancel")

    btnOK.OnEvent("Click", SaveSettingsFromMap.Bind(sg, hkMap))
    btnCancel.OnEvent("Click", (*) => sg.Destroy())
    sg.OnEvent("Close", (*) => sg.Destroy())

    sg.Show("AutoSize Center")
}

; -------------------------------------------------------
;  Hotkey capture — натисни бутон, после клавиш
; -------------------------------------------------------
capturing := false

StartCapture(btn, key, hkMap, *) {
    global capturing
    if capturing
        return
    capturing    := true
    origText     := btn.Text
    btn.Text     := "[ натисни клавиш... ]"

    ; Слушай следващия клавиш с Input
    ih := InputHook("L1 B")  ; L1 = 1 клавиш, B = блокира го
    ih.KeyOpt("{All}", "ES") ; E = end on key, S = suppress
    ih.Start()
    ih.Wait()

    key2    := ih.EndKey
    mods    := ""
    if GetKeyState("LCtrl",  "P") || GetKeyState("RCtrl",  "P")
        mods .= "^"
    if GetKeyState("LAlt",   "P") || GetKeyState("RAlt",   "P")
        mods .= "!"
    if GetKeyState("LShift", "P") || GetKeyState("RShift", "P")
        mods .= "+"
    if GetKeyState("LWin",   "P") || GetKeyState("RWin",   "P")
        mods .= "#"

    hk := mods . key2

    ; Тествай дали е валиден
    try {
        Hotkey(hk, ToggleTyping, "Off")
        hkMap[key] := hk
        btn.Text   := hk
    } catch {
        btn.Text := origText
        MsgBox("Невалиден клавиш: '" hk "'", "Грешка", 16)
    }

    capturing := false
}

SaveSettingsFromMap(sg, hkMap, *) {
    global iniFile, claimOffset, idleTimeout
    global burstMin, burstMax, fastDelayMin, fastDelayMax
    global pauseMin, pauseMax, spamInterval, clickCount
    global hkTyping, hkSpam, hkOverlay, hkSetup, hkClaim, hkQuit

    saved := sg.Submit()

    ; Валидация
    cm := Float(saved.ClaimMinutes)
    if (cm <= 0) {
        MsgBox("Claim минутите трябва да са > 0", "Грешка", 16)
        return
    }

    ; Деregister стари hotkey-и
    UnregisterHotkeys()

    ; Запази в .ini
    IniWrite(saved.ClaimMinutes,  iniFile, "Settings", "ClaimMinutes")
    IniWrite(saved.IdleTimeout,   iniFile, "Settings", "IdleTimeout")
    IniWrite(saved.BurstMin,      iniFile, "Typing",   "BurstMin")
    IniWrite(saved.BurstMax,      iniFile, "Typing",   "BurstMax")
    IniWrite(saved.FastDelayMin,  iniFile, "Typing",   "FastDelayMin")
    IniWrite(saved.FastDelayMax,  iniFile, "Typing",   "FastDelayMax")
    IniWrite(saved.PauseMin,      iniFile, "Typing",   "PauseMin")
    IniWrite(saved.PauseMax,      iniFile, "Typing",   "PauseMax")
    IniWrite(saved.SpamInterval,  iniFile, "Typing",   "SpamInterval")
    IniWrite(saved.ClickCount,    iniFile, "Typing",   "ClickCount")
    IniWrite(hkMap["Typing"],     iniFile, "Hotkeys",  "Typing")
    IniWrite(hkMap["Spam"],       iniFile, "Hotkeys",  "Spam")
    IniWrite(hkMap["Overlay"],    iniFile, "Hotkeys",  "Overlay")
    IniWrite(hkMap["Setup"],      iniFile, "Hotkeys",  "Setup")
    IniWrite(hkMap["Claim"],      iniFile, "Hotkeys",  "Claim")
    IniWrite(hkMap["Quit"],       iniFile, "Hotkeys",  "Quit")

    ; Приложи веднага
    claimOffset  := cm * 60 * 1000
    idleTimeout  := Integer(saved.IdleTimeout)
    burstMin     := Integer(saved.BurstMin)
    burstMax     := Integer(saved.BurstMax)
    fastDelayMin := Integer(saved.FastDelayMin)
    fastDelayMax := Integer(saved.FastDelayMax)
    pauseMin     := Integer(saved.PauseMin)
    pauseMax     := Integer(saved.PauseMax)
    spamInterval := Integer(saved.SpamInterval)
    clickCount   := Integer(saved.ClickCount)
    hkTyping     := hkMap["Typing"]
    hkSpam       := hkMap["Spam"]
    hkOverlay    := hkMap["Overlay"]
    hkSetup      := hkMap["Setup"]
    hkClaim      := hkMap["Claim"]
    hkQuit       := hkMap["Quit"]

    ; Регистрирай новите hotkey-и
    RegisterHotkeys()

    sg.Destroy()
    ToolTip("Settings запазени!")
    Sleep(1500)
    ToolTip()
}

; -------------------------------------------------------
;  Spam — Detect user activity
; -------------------------------------------------------
~*LButton:: SetTimer(ResumeAfterIdle, -idleTimeout)
~*RButton:: SetTimer(ResumeAfterIdle, -idleTimeout)
~*MButton:: SetTimer(ResumeAfterIdle, -idleTimeout)
~*$a::      SetTimer(ResumeAfterIdle, -idleTimeout)

OnMessage(0x0200, WM_MOUSEMOVE)
WM_MOUSEMOVE(wParam, lParam, msg, hwnd2) {
    global userIdle
    userIdle := false
    SetTimer(ResumeAfterIdle, -idleTimeout)
}

ResumeAfterIdle() {
    global userIdle
    userIdle := true
}

SendF13() {
    SendMode("Event")
    SendEvent("{F13 down}")
    Sleep(20)
    SendEvent("{F13 up}")
    Sleep(20)
}

; -------------------------------------------------------
;  Actions (извикват се от hotkey-ите)
; -------------------------------------------------------
ToggleTyping(*) {
    global clicking, spamming, userIdle
    if spamming {
        spamming := false
        SetTimer(DoSpam, 0)
        ToolTip("Spam: OFF")
        Sleep(1000)
        ToolTip()
    }
    clicking := !clicking
    userIdle := true
    if clicking {
        ToolTip("Bongo Cat: ON (Realistic)")
        SetTimer(DoTypingRhythm, 1)
    } else {
        SetTimer(DoTypingRhythm, 0)
        ToolTip("Bongo Cat: OFF")
        Sleep(1000)
        ToolTip()
    }
}

ToggleSpam(*) {
    global spamming, clicking, userIdle, spamInterval
    if clicking {
        clicking := false
        SetTimer(DoTypingRhythm, 0)
        ToolTip("Realistic: OFF")
        Sleep(1000)
        ToolTip()
    }
    spamming := !spamming
    userIdle := true
    if spamming {
        SetTimer(DoSpam, spamInterval)
    } else {
        SetTimer(DoSpam, 0)
        ToolTip("Bongo Cat: OFF")
        Sleep(1000)
        ToolTip()
    }
}

ToggleOverlay(*) {
    global guiVisible, skinX
    if (skinX = 0) {
        ToolTip("Няма config. Направи Setup.")
        Sleep(2000)
        ToolTip()
        return
    }
    if guiVisible
        HideOverlayGuis()
    else
        ShowOverlayGuis()
}

StartSetup(*) {
    global setupStep, bongohwnd, exeName
    bongohwnd := WinExist("ahk_exe " exeName)
    if !bongohwnd {
        MsgBox("Bongo Cat не е намерен!", "Грешка", 16)
        return
    }
    HideOverlayGuis()
    setupStep := 1
    ToolTip("SETUP | Стъпка 1/2: Кликни върху SKIN chest-а")
    InstallSetupHook()
}

ManualClaim(*) {
    global skinX, skinY, cosX, cosY, bongohwnd, exeName
    global skinNext, cosNext, claimOffset, iniFile

    if (skinX = 0) {
        MsgBox("Няма координати. Направи Setup.", "Грешка", 16)
        return
    }
    bongohwnd := WinExist("ahk_exe " exeName)
    if !bongohwnd {
        MsgBox("Bongo Cat не е намерен!", "Грешка", 16)
        return
    }

    now      := A_TickCount
    DoClick(skinX, skinY, bongohwnd)
    skinNext := now + claimOffset
    Sleep(300)
    DoClick(cosX, cosY, bongohwnd)
    cosNext  := skinNext + 1000

    IniWrite(skinNext, iniFile, "Timestamps", "SkinNext")
    IniWrite(cosNext,  iniFile, "Timestamps", "CosNext")

    ToolTip("Claimed! Следващ: " MsToMMSS(skinNext - A_TickCount))
    Sleep(2000)
    ToolTip()
}

QuitScript(*) {
    SetTimer(AutoClaim, 0)
    SetTimer(UpdateGui, 0)
    SetTimer(DoTypingRhythm, 0)
    SetTimer(DoSpam, 0)
    HideOverlayGuis()
    ToolTip("Bongo Cat: QUIT")
    Sleep(800)
    ToolTip()
    ExitApp()
}

; -------------------------------------------------------
;  Block F13-F23
; -------------------------------------------------------
F13:: return
F14:: return
F15:: return
F16:: return
F17:: return
F18:: return
F19:: return
F20:: return
F21:: return
F22:: return
F23:: return

; -------------------------------------------------------
;  Spam / Typing timers
; -------------------------------------------------------
DoTypingRhythm() {
    global clicking, userIdle, burstMin, burstMax, fastDelayMin, fastDelayMax, pauseMin, pauseMax
    if !userIdle
        return
    burstLen := Random(burstMin, burstMax)
    Loop burstLen {
        if (!clicking || !userIdle)
            return
        SendF13()
        if (Random(1, 5) = 1)
            Sleep(Random(150, 300))
        else
            Sleep(Random(fastDelayMin, fastDelayMax))
    }
    Sleep(Random(pauseMin, pauseMax))
}

DoSpam() {
    global spamming, claiming
    while spamming {
        if claiming {
            Sleep(20)
            continue
        }
        SendMode("Event")
        loop 11 {
            SendEvent("{F" (12 + A_Index) " down}")
            Sleep(1)
            SendEvent("{F" (12 + A_Index) " up}")
            Sleep(1)
        }
    }
}

; -------------------------------------------------------
;  Setup — слушай кликове чрез hook
; -------------------------------------------------------
SetupPoll() {
    global setupStep, skinX, skinY, cosX, cosY, iniFile, claimOffset
    global skinNext, cosNext, bongohwnd

    if (setupStep = 0) {
        SetTimer(SetupPoll, 0)
        return
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    if (setupStep = 1) {
        skinX     := mx
        skinY     := my
        setupStep := 2
        ToolTip("SETUP | Стъпка 2/2: Кликни върху COSMETIC chest-а")
        return
    }

    if (setupStep = 2) {
        cosX      := mx
        cosY      := my
        setupStep := 0
        SetTimer(SetupPoll, 0)
        UninstallSetupHook()
        ToolTip("")

        IniWrite(skinX, iniFile, "Coords", "SkinX")
        IniWrite(skinY, iniFile, "Coords", "SkinY")
        IniWrite(cosX,  iniFile, "Coords", "CosX")
        IniWrite(cosY,  iniFile, "Coords", "CosY")

        Sleep(200)
        now      := A_TickCount
        DoClick(skinX, skinY, bongohwnd)
        skinNext := now + claimOffset
        Sleep(300)
        DoClick(cosX, cosY, bongohwnd)
        cosNext  := skinNext + 1000

        IniWrite(skinNext, iniFile, "Timestamps", "SkinNext")
        IniWrite(cosNext,  iniFile, "Timestamps", "CosNext")

        ToolTip("Setup завършен!")
        Sleep(2000)
        ToolTip()

        SetTimer(AutoClaim, 1000)
        CreateOverlayGuis()
        ShowOverlayGuis()
        SetTimer(UpdateGui, 1000)
    }
}

; Hook за LButton — засича кликове навсякъде включително click-through
setupMouseHook := 0
setupMouseCB   := 0

InstallSetupHook() {
    global setupMouseHook, setupMouseCB
    setupMouseCB   := CallbackCreate(SetupMouseProc, "Fast")
    setupMouseHook := DllCall("SetWindowsHookEx",
        "int",  14,
        "ptr",  setupMouseCB,
        "ptr",  0,
        "uint", 0,
        "ptr")
}

UninstallSetupHook() {
    global setupMouseHook, setupMouseCB
    if setupMouseHook {
        DllCall("UnhookWindowsHookEx", "ptr", setupMouseHook)
        setupMouseHook := 0
    }
    if setupMouseCB {
        CallbackFree(setupMouseCB)
        setupMouseCB := 0
    }
}

SetupMouseProc(nCode, wParam, lParam) {
    global setupStep
    if (nCode >= 0 && wParam = 0x0201 && setupStep > 0)
        SetTimer(SetupPoll, -1)
    return DllCall("CallNextHookEx", "ptr", 0, "int", nCode, "ptr", wParam, "ptr", lParam, "ptr")
}

; -------------------------------------------------------
;  Overlay GUI
; -------------------------------------------------------
CreateOverlayGuis() {
    global skinGui, cosGui

    if IsObject(skinGui)
        skinGui.Destroy()
    if IsObject(cosGui)
        cosGui.Destroy()

    skinGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    skinGui.BackColor := "111111"
    skinGui.SetFont("s9 cWhite bold", "Segoe UI")
    skinGui.Add("Text", "vSkinLabel w110 Center", "🎁 Skin")
    skinGui.Add("Text", "vSkinTimer w110 Center", "--:--")
    WinSetTransparent(210, skinGui)

    cosGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    cosGui.BackColor := "111111"
    cosGui.SetFont("s9 cWhite bold", "Segoe UI")
    cosGui.Add("Text", "vCosLabel w110 Center", "✨ Cosmetic")
    cosGui.Add("Text", "vCosTimer w110 Center", "--:--")
    WinSetTransparent(210, cosGui)
}

ShowOverlayGuis() {
    global skinGui, cosGui, skinX, skinY, cosX, cosY, guiOffsetY, guiVisible
    if (!IsObject(skinGui) || !IsObject(cosGui))
        return
    skinGui.Show("x" (skinX - 55) " y" (skinY - guiOffsetY) " NoActivate")
    cosGui.Show("x" (cosX - 55) " y" (cosY - guiOffsetY) " NoActivate")
    guiVisible := true
}

HideOverlayGuis() {
    global skinGui, cosGui, guiVisible
    if IsObject(skinGui)
        skinGui.Hide()
    if IsObject(cosGui)
        cosGui.Hide()
    guiVisible := false
}

UpdateGui() {
    global skinGui, cosGui, skinNext, cosNext, guiVisible
    if (!guiVisible || !IsObject(skinGui) || !IsObject(cosGui))
        return
    now := A_TickCount

    skinMs := skinNext - now
    if (skinMs <= 0) {
        skinGui["SkinTimer"].Text := "READY"
        skinGui["SkinTimer"].SetFont("cLime")
    } else {
        skinGui["SkinTimer"].Text := MsToMMSS(skinMs)
        skinGui["SkinTimer"].SetFont("cWhite")
    }

    cosMs := cosNext - now
    if (cosMs <= 0) {
        cosGui["CosTimer"].Text := "READY"
        cosGui["CosTimer"].SetFont("cLime")
    } else {
        cosGui["CosTimer"].Text := MsToMMSS(cosMs)
        cosGui["CosTimer"].SetFont("cWhite")
    }
}

; -------------------------------------------------------
;  Auto claim
; -------------------------------------------------------
AutoClaim() {
    global skinX, skinY, cosX, cosY, bongohwnd, exeName
    global skinNext, cosNext, claimOffset, iniFile

    if (skinX = 0)
        return
    bongohwnd := WinExist("ahk_exe " exeName)
    if !bongohwnd
        return

    now := A_TickCount

    if (skinNext > 0 && now >= skinNext) {
        DoClick(skinX, skinY, bongohwnd)
        skinNext := now + claimOffset
        IniWrite(skinNext, iniFile, "Timestamps", "SkinNext")
        Sleep(300)
    }

    if (cosNext > 0 && now >= cosNext) {
        DoClick(cosX, cosY, bongohwnd)
        cosNext := now + claimOffset
        IniWrite(cosNext, iniFile, "Timestamps", "CosNext")
    }
}

; -------------------------------------------------------
;  DoClick
; -------------------------------------------------------
DoClick(x, y, hwnd) {
    global claiming, clickCount
    CoordMode("Mouse", "Screen")

    activeHwnd := WinExist("A")
    claiming   := true

    MouseGetPos(&origX, &origY)
    BlockInput("MouseMove")
    MouseMove(x, y, 0)
    Sleep(30)
    Loop clickCount {
        SendEvent("{LButton down}")
        Sleep(60)
        SendEvent("{LButton up}")
        Sleep(30)
    }
    MouseMove(origX, origY, 0)
    BlockInput("MouseMoveOff")

    claiming := false

    if (activeHwnd && activeHwnd != hwnd)
        WinActivate("ahk_id " activeHwnd)
}

; -------------------------------------------------------
;  Helpers
; -------------------------------------------------------
MsToMMSS(ms) {
    if (ms <= 0)
        return "00:00"
    ms   := Integer(Round(ms))
    secs := ms // 1000
    mins := secs // 60
    secs := Mod(secs, 60)
    return Format("{:02d}:{:02d}", mins, secs)
}
