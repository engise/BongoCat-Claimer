; =============================================
;  Bongo Cat - All-in-One Script
;  AutoHotkey v2
;
;  PURPOSE:
;    Automates three things for the Bongo Cat Steam overlay:
;      1. Auto-claims both chests every ~30.5 minutes
;      2. Realistic Typing � generates keystrokes in a human-like
;         burst/pause pattern to accumulate points passively
;      3. Spam � sends keystrokes as fast as possible for maximum
;         point generation when away from the computer
;
;  FIXED HOTKEY:
;    F5 = Settings (cannot be rebound)
;
;  ALL OTHER HOTKEYS are configurable from Settings (F5 > Hotkeys).
;  Default bindings:
;    F6  = Toggle Realistic Typing
;    F7  = Quit
;    F8  = Toggle Spam
;    F9  = Toggle overlay timer GUI
;    F10 = Run chest coordinate setup
;    F12 = Force claim both chests now
;
;  CONFIG FILE:
;    BongoCat.ini is created automatically next to this .ahk file
;    on first run. It stores all settings, chest coordinates, and
;    claim timestamps so they survive script restarts.
; =============================================

#Requires AutoHotkey v2.0
#SingleInstance Force  ; Prevent multiple instances of this script running at once

; -------------------------------------------------------
;  VERSION
;  Checked against version.txt on GitHub at startup.
;  To release a new version: bump this string and push
;  version.txt with the same value to the repo.
; -------------------------------------------------------
currentVersion := "1.1.2"
githubRawBase  := "https://raw.githubusercontent.com/engise/BongoCat-Claimer/main/"

; -------------------------------------------------------
;  DEFAULT VALUES
;  These are the fallback values used if BongoCat.ini
;  doesn't exist yet. Once the .ini is created, all values
;  are read from there instead.
; -------------------------------------------------------

iniFile       := A_ScriptDir "\BongoCat.ini"  ; Config file sits next to the script
exeName       := "BongoCat.exe"               ; Process name to target for clicks

; --- Claimer ---
claimOffset   := 30.5 * 60 * 1000  ; Milliseconds between auto-claims (30.5 min default).
                                    ; Slightly over 30 to handle any timer drift in Bongo Cat.
guiOffsetY    := 40                 ; How many pixels above each chest the overlay timer appears

; --- Spam / Typing ---
clicking      := false   ; Whether Realistic Typing is currently active
spamming      := false   ; Whether Spam is currently active
userIdle      := false   ; True when the user hasn't moved/clicked for idleTimeout ms.
                         ; Realistic Typing only fires when userIdle = true.
idleTimeout   := 1000    ; ms of inactivity before userIdle flips to true

; Realistic Typing rhythm settings:
burstMin      := 3       ; Minimum keystrokes sent in one burst
burstMax      := 8       ; Maximum keystrokes sent in one burst
fastDelayMin  := 60      ; Minimum ms delay between keystrokes within a burst
fastDelayMax  := 140     ; Maximum ms delay between keystrokes within a burst
pauseMin      := 300     ; Minimum ms pause between bursts
pauseMax      := 900     ; Maximum ms pause between bursts

spamInterval  := 1       ; ms between spam keystroke batches (lower = faster)
clickCount    := 3       ; How many times to click each chest per claim attempt.
                         ; More clicks = more reliable on laggy systems.
chestOffset   := 82      ; Horizontal pixel distance from cat center to each chest.
                         ; Left chest = centerX - chestOffset, Right chest = centerX + chestOffset.
                         ; Measured at default Bongo Cat scale � adjust in Settings if needed.

; --- Chest state ---
catCenterX    := 0       ; Screen X coordinate of the cat center (clicked during setup)
catCenterY    := 0       ; Screen Y coordinate of the cat center (clicked during setup)
; Chest positions are derived at claim time: skinX = catCenterX - chestOffset, cosX = catCenterX + chestOffset
skinX         := 0       ; Derived: catCenterX - chestOffset (recalculated each claim)
skinY         := 0       ; Same Y as cat center
cosX          := 0       ; Derived: catCenterX + chestOffset
cosY          := 0       ; Same Y as cat center
skinNext      := 0       ; A_TickCount timestamp when Skin chest can next be claimed
cosNext       := 0       ; A_TickCount timestamp when Cosmetic chest can next be claimed
setupStep      := 0       ; Tracks setup wizard progress: 0=idle, 1=waiting for cat center click
bongohwnd      := 0       ; Window handle of BongoCat.exe (used for focus restoration after clicks)
claiming       := false   ; True while DoClick is running � used to pause Spam during a claim
isInitialSetup := false   ; True when .ini doesn't exist yet � initial setup claims chests immediately.
                           ; False on subsequent setups � only updates coordinates, timers unchanged.

; --- Overlay GUI state ---
guiVisible    := false   ; Whether the countdown overlay windows are currently shown
skinGui       := ""      ; GUI object for the Skin chest timer overlay
cosGui        := ""      ; GUI object for the Cosmetic chest timer overlay

; --- Hotkey bindings (defaults, overridden by .ini) ---
hkTyping      := "F6"
hkSpam        := "F8"
hkOverlay     := "F9"
hkSetup       := "F10"
hkClaim       := "F12"
hkQuit        := "F7"

; -------------------------------------------------------
;  STARTUP
;  If this file has "_new" in its name, it was downloaded
;  as an update � run SelfUpdate() to replace the old file.
;  Otherwise do the normal startup sequence.
; -------------------------------------------------------
if InStr(A_ScriptFullPath, "_new.ahk") {
    SelfUpdate()
    return
}

CheckForUpdate()
LoadConfig()
RegisterHotkeys()

; -------------------------------------------------------
;  LOADCONFIG
;  Reads all settings from BongoCat.ini.
;  If the file doesn't exist, writes default values and
;  exits early (user still needs to run setup via F10).
;  If coordinates are missing, shows a reminder tooltip.
; -------------------------------------------------------
LoadConfig() {
    global iniFile, claimOffset, idleTimeout
    global burstMin, burstMax, fastDelayMin, fastDelayMax
    global pauseMin, pauseMax, spamInterval
    global skinX, skinY, cosX, cosY, skinNext, cosNext

    if !FileExist(iniFile) {
        WriteDefaultIni()
        isInitialSetup := true   ; Flag for StartSetup � first run needs to claim chests
        ToolTip("No config found. Press F10 to set up chest coordinates.")
        Sleep(3000)
        ToolTip()
        return
    }

    ; Settings section
    claimMins    := Float(IniRead(iniFile,   "Settings", "ClaimMinutes",  30.5))
    claimOffset  := claimMins * 60 * 1000  ; Convert minutes ? milliseconds
    idleTimeout  := Integer(IniRead(iniFile, "Settings", "IdleTimeout",   1000))

    ; Typing section
    burstMin     := Integer(IniRead(iniFile, "Typing", "BurstMin",     3))
    burstMax     := Integer(IniRead(iniFile, "Typing", "BurstMax",     8))
    fastDelayMin := Integer(IniRead(iniFile, "Typing", "FastDelayMin", 60))
    fastDelayMax := Integer(IniRead(iniFile, "Typing", "FastDelayMax", 140))
    pauseMin     := Integer(IniRead(iniFile, "Typing", "PauseMin",     300))
    pauseMax     := Integer(IniRead(iniFile, "Typing", "PauseMax",     900))
    spamInterval := Integer(IniRead(iniFile, "Typing", "SpamInterval", 1))
    clickCount   := Integer(IniRead(iniFile, "Typing", "ClickCount",   3))
    chestOffset  := Integer(IniRead(iniFile, "Typing", "ChestOffset",  82))

    ; Hotkeys section � read saved bindings, fall back to defaults if missing
    hkTyping    := IniRead(iniFile, "Hotkeys", "Typing",    "F6")
    hkSpam      := IniRead(iniFile, "Hotkeys", "Spam",      "F8")
    hkOverlay   := IniRead(iniFile, "Hotkeys", "Overlay",   "F9")
    hkSetup     := IniRead(iniFile, "Hotkeys", "Setup",     "F10")
    hkClaim     := IniRead(iniFile, "Hotkeys", "Claim",     "F12")
    hkQuit      := IniRead(iniFile, "Hotkeys", "Quit",      "F7")

    ; Coords section � center of the cat, chests are derived from chestOffset
    catCenterX := Integer(IniRead(iniFile, "Coords", "CatCenterX", 0))
    catCenterY := Integer(IniRead(iniFile, "Coords", "CatCenterY", 0))

    ; Derive chest positions from center + offset
    skinX := catCenterX - chestOffset
    skinY := catCenterY
    cosX  := catCenterX + chestOffset
    cosY  := catCenterY

    ; Timestamps section � A_TickCount values of next scheduled claim
    ; These persist across restarts so the timer survives closing the script
    skinNext := Integer(IniRead(iniFile, "Timestamps", "SkinNext", 0))
    cosNext  := Integer(IniRead(iniFile, "Timestamps", "CosNext",  0))

    if (catCenterX = 0) {
        ToolTip("No chest coordinates found. Press F10 to run setup.")
        Sleep(3000)
        ToolTip()
        return
    }

    ; All good � start the auto-claim checker, build the overlay, start the GUI update loop
    SetTimer(AutoClaim, 1000)   ; Check every second whether a chest is ready
    CreateOverlayGuis()
    ShowOverlayGuis()
    SetTimer(UpdateGui, 1000)   ; Refresh overlay countdown text every second
}

; -------------------------------------------------------
;  WRITEDEFAULTINI
;  Creates BongoCat.ini with all default values.
;  Called only when the file doesn't exist yet.
; -------------------------------------------------------
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
    IniWrite(82,   iniFile, "Typing",   "ChestOffset")
    IniWrite("F6",  iniFile, "Hotkeys", "Typing")
    IniWrite("F8",  iniFile, "Hotkeys", "Spam")
    IniWrite("F9",  iniFile, "Hotkeys", "Overlay")
    IniWrite("F10", iniFile, "Hotkeys", "Setup")
    IniWrite("F12", iniFile, "Hotkeys", "Claim")
    IniWrite("F7",  iniFile, "Hotkeys", "Quit")
}

; -------------------------------------------------------
;  CHECKFORUPDATE
;  Fetches version.txt from GitHub and compares it to
;  currentVersion. If a newer version is available, asks
;  the user whether to update.
;
;  Update process (no extra software needed):
;    1. Download new .ahk via WinHTTP (built into Windows)
;    2. Save as BongoCat_Claimer_new.ahk next to current file
;    3. Launch the new file
;    4. The new instance detects it has "_new" in its path,
;       waits briefly, then replaces the old file and relaunches
;       from the final path
;
;  If GitHub is unreachable (no internet, rate limit, etc.)
;  the check silently fails and the script continues normally.
; -------------------------------------------------------
CheckForUpdate() {
    global currentVersion, githubRawBase

    ; Fetch version.txt from GitHub using WinHTTP (no external tools needed)
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", githubRawBase "version.txt", false)
        http.Send()
        latestVersion := Trim(http.ResponseText)
    } catch {
        return  ; No internet or GitHub unreachable � silently skip
    }

    ; Validate response looks like a version string
    if !RegExMatch(latestVersion, "^\d+\.\d+\.\d+$")
        return  ; Unexpected response � skip

    ; Compare versions � only prompt if remote is strictly newer
    if !IsNewerVersion(currentVersion, latestVersion)
        return

    ; Ask the user
    result := MsgBox(
        "A new version of Bongo Cat Claimer is available!`n`n"
        "Current version:  " currentVersion "`n"
        "Latest version:   " latestVersion "`n`n"
        "Update now?",
        "Update Available",
        0x4 | 0x20  ; Yes/No + question icon
    )

    if (result != "Yes")
        return

    ; Download new script
    newPath := A_ScriptDir "\BongoCat_Claimer_new.ahk"
    try {
        http.Open("GET", githubRawBase "BongoCat_Claimer.ahk", false)
        http.Send()
        if (http.Status != 200)
            throw Error("HTTP " http.Status)
        FileOpen(newPath, "w").Write(http.ResponseText)
    } catch as e {
        MsgBox("Update failed: " e.Message "`n`nPlease download manually from GitHub.", "Update Error", 0x10)
        return
    }

    ; Launch the new version � it will handle replacing this file
    Run('"' A_AhkPath '" "' newPath '"')
    ExitApp()
}

; -------------------------------------------------------
;  SELFUPDATE
;  Called automatically when the script detects it was
;  launched as a "_new" file (i.e. it IS the update).
;  Waits for the old instance to exit, replaces the file,
;  then relaunches from the clean path.
; -------------------------------------------------------
SelfUpdate() {
    oldPath  := StrReplace(A_ScriptFullPath, "_new.ahk", ".ahk")
    Sleep(800)  ; Give the old instance time to exit

    try {
        FileDelete(oldPath)
        FileMove(A_ScriptFullPath, oldPath)
    } catch as e {
        MsgBox("Could not replace old file: " e.Message "`n`nPlease rename manually.", "Update Error", 0x10)
        return
    }

    Run('"' A_AhkPath '" "' oldPath '"')
    ExitApp()
}

; -------------------------------------------------------
;  ISNEWERVERSIONERSION
;  Compares two "major.minor.patch" version strings.
;  Returns true if `latest` is strictly greater than `current`.
; -------------------------------------------------------
IsNewerVersion(current, latest) {
    cs := StrSplit(current, ".")
    ls := StrSplit(latest,  ".")
    loop 3 {
        cv := (cs.Length >= A_Index) ? Integer(cs[A_Index]) : 0
        lv := (ls.Length >= A_Index) ? Integer(ls[A_Index]) : 0
        if (lv > cv)
            return true
        if (lv < cv)
            return false
    }
    return false  ; Versions are equal
}

; -------------------------------------------------------
;  HOTKEY REGISTRATION
;  RegisterHotkeys() binds all configurable actions to
;  their current hk* values. Called once on startup and
;  again after settings are saved with new bindings.
;
;  UnregisterHotkeys() disables all current bindings
;  before re-registering with new keys, so there are no
;  conflicts or duplicate bindings.
; -------------------------------------------------------
RegisterHotkeys() {
    global hkTyping, hkSpam, hkOverlay, hkSetup, hkClaim, hkQuit
    Hotkey(hkTyping,  ToggleTyping)
    Hotkey(hkSpam,    ToggleSpam)
    Hotkey(hkOverlay, ToggleOverlay)
    Hotkey(hkSetup,   StartSetup)
    Hotkey(hkClaim,   ManualClaim)
    Hotkey(hkQuit,    QuitScript)
}

UnregisterHotkeys() {
    global hkTyping, hkSpam, hkOverlay, hkSetup, hkClaim, hkQuit
    ; try/catch each one individually � if a binding doesn't exist yet it won't crash
    try Hotkey(hkTyping,  "Off")
    try Hotkey(hkSpam,    "Off")
    try Hotkey(hkOverlay, "Off")
    try Hotkey(hkSetup,   "Off")
    try Hotkey(hkClaim,   "Off")
    try Hotkey(hkQuit,    "Off")
}

; -------------------------------------------------------
;  F5 � SETTINGS (fixed hotkey, cannot be rebound)
;
;  Opens a native Windows-style settings dialog with four
;  sections: Claimer, Realistic Typing, Spam, and Hotkeys.
;  Changes are applied immediately on OK without restart.
; -------------------------------------------------------
F5:: OpenSettings()

OpenSettings() {
    global iniFile, claimOffset, idleTimeout
    global burstMin, burstMax, fastDelayMin, fastDelayMax
    global pauseMin, pauseMax, spamInterval
    global hkTyping, hkSpam, hkOverlay, hkSetup, hkClaim, hkQuit

    sg := Gui("+AlwaysOnTop", "Bongo Cat � Settings")
    sg.SetFont("s9", "Segoe UI")
    sg.MarginX := 12
    sg.MarginY := 10

    ; Layout constants � adjust these to change column widths
    lw  := 190          ; Label column width (px)
    ew  := 90           ; Edit field width (px)
    gw  := lw + ew + 30 ; GroupBox width (auto-calculated)
    row := "y+4"        ; Vertical gap between rows inside a GroupBox

    ; --- Claimer section ---
    sg.Add("GroupBox", "w" gw " h104 Section", "Claimer")
    sg.Add("Text",  "xp+10 yp+22 w" lw " h20 +0x200", "Claim interval (minutes):")
    sg.Add("Edit",  "vClaimMinutes x+8 w" ew " h20",
        Float(IniRead(iniFile, "Settings", "ClaimMinutes", 30.5)))
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Clicks per chest:")
    sg.Add("Edit",  "vClickCount x+8 w" ew " h20 Number", clickCount)
    sg.Add("Text",  "xs+10 " row " w" lw " h20 +0x200", "Chest offset from center (px):")
    sg.Add("Edit",  "vChestOffset x+8 w" ew " h20 Number", chestOffset)

    ; --- Realistic Typing section ---
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

    ; --- Spam section ---
    sg.Add("GroupBox", "xs w" gw " h52 y+10 Section", "Spam")
    sg.Add("Text",  "xp+10 yp+22 w" lw " h20 +0x200", "Spam interval (ms):")
    sg.Add("Edit",  "vSpamInterval x+8 w" ew " h20 Number", spamInterval)

    ; --- Hotkeys section ---
    ; Current values live in hkMap (a Map object).
    ; Each button calls StartCapture() when clicked, which listens for
    ; the next keypress and updates both the button label and hkMap.
    ; The actual save to .ini happens when OK is clicked.
    hkMap := Map(
        "Typing",  hkTyping,
        "Spam",    hkSpam,
        "Overlay", hkOverlay,
        "Setup",   hkSetup,
        "Claim",   hkClaim,
        "Quit",    hkQuit
    )

    sg.Add("GroupBox", "xs w" gw " h182 y+10 Section", "Hotkeys  (click a button, then press the desired key)")

    ; MakeHkRow is a nested helper that adds one label+button row per hotkey
    MakeHkRow(label, key, sg, lw, ew, row) {
        sg.Add("Text", "xs+10 " row " w" lw " h20 +0x200", label)
        btn := sg.Add("Button", "x+8 w" ew " h20", hkMap[key])
        btn.OnEvent("Click", StartCapture.Bind(btn, key, hkMap))
        return btn
    }

    MakeHkRow("Toggle Realistic Typing:", "Typing",  sg, lw, ew, "yp+22")
    MakeHkRow("Toggle Spam:",             "Spam",    sg, lw, ew, row)
    MakeHkRow("Toggle Overlay GUI:",      "Overlay", sg, lw, ew, row)
    MakeHkRow("Setup chest coordinates:", "Setup",   sg, lw, ew, row)
    MakeHkRow("Force Claim:",             "Claim",   sg, lw, ew, row)
    MakeHkRow("Quit:",                    "Quit",    sg, lw, ew, row)

    ; OK saves everything; Cancel discards changes
    btnOK     := sg.Add("Button", "xs w" (gw//2 - 4) " y+14 Default", "OK")
    btnCancel := sg.Add("Button", "w" (gw//2 - 4) " x+8", "Cancel")

    btnOK.OnEvent("Click", SaveSettingsFromMap.Bind(sg, hkMap))
    btnCancel.OnEvent("Click", (*) => sg.Destroy())
    sg.OnEvent("Close", (*) => sg.Destroy())

    sg.Show("AutoSize Center")
}

; -------------------------------------------------------
;  STARTCAPTURE
;  Called when a hotkey button in Settings is clicked.
;  Waits for exactly one keypress (with optional modifiers),
;  validates it as a usable hotkey, and updates the button
;  label and hkMap entry.
;
;  The `capturing` flag prevents two captures running at once
;  if the user clicks multiple buttons quickly.
; -------------------------------------------------------
capturing := false

StartCapture(btn, key, hkMap, *) {
    global capturing
    if capturing
        return
    capturing := true
    origText  := btn.Text
    btn.Text  := "[ press a key... ]"

    ; InputHook: L1 = stop after 1 key, B = block the keypress from reaching other apps
    ih := InputHook("L1 B")
    ih.KeyOpt("{All}", "ES")  ; E = end on any key, S = suppress it
    ih.Start()
    ih.Wait()

    key2 := ih.EndKey

    ; Check which modifier keys are held at the moment of the keypress
    mods := ""
    if GetKeyState("LCtrl",  "P") || GetKeyState("RCtrl",  "P")
        mods .= "^"   ; Ctrl
    if GetKeyState("LAlt",   "P") || GetKeyState("RAlt",   "P")
        mods .= "!"   ; Alt
    if GetKeyState("LShift", "P") || GetKeyState("RShift", "P")
        mods .= "+"   ; Shift
    if GetKeyState("LWin",   "P") || GetKeyState("RWin",   "P")
        mods .= "#"   ; Win

    hk := mods . key2

    ; Try registering the hotkey temporarily to validate the syntax.
    ; If AHK throws an error, the key combination is not usable.
    try {
        Hotkey(hk, ToggleTyping, "Off")
        hkMap[key] := hk
        btn.Text   := hk
    } catch {
        btn.Text := origText
        MsgBox("Invalid key: '" hk "'", "Error", 16)
    }

    capturing := false
}

; -------------------------------------------------------
;  SAVESETTINGSFROMMAP
;  Triggered when OK is clicked in Settings.
;  Validates input, unregisters old hotkeys, writes all
;  values to .ini, applies them to live variables, and
;  re-registers hotkeys with the new bindings.
; -------------------------------------------------------
SaveSettingsFromMap(sg, hkMap, *) {
    global iniFile, claimOffset, idleTimeout
    global burstMin, burstMax, fastDelayMin, fastDelayMax
    global pauseMin, pauseMax, spamInterval, clickCount
    global hkTyping, hkSpam, hkOverlay, hkSetup, hkClaim, hkQuit

    saved := sg.Submit()  ; Reads all vName control values into an object

    ; Basic validation
    cm := Float(saved.ClaimMinutes)
    if (cm <= 0) {
        MsgBox("Claim interval must be greater than 0.", "Error", 16)
        return
    }

    UnregisterHotkeys()  ; Remove old bindings before applying new ones

    ; Persist to .ini
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
    IniWrite(saved.ChestOffset,   iniFile, "Typing",   "ChestOffset")
    IniWrite(hkMap["Typing"],     iniFile, "Hotkeys",  "Typing")
    IniWrite(hkMap["Spam"],       iniFile, "Hotkeys",  "Spam")
    IniWrite(hkMap["Overlay"],    iniFile, "Hotkeys",  "Overlay")
    IniWrite(hkMap["Setup"],      iniFile, "Hotkeys",  "Setup")
    IniWrite(hkMap["Claim"],      iniFile, "Hotkeys",  "Claim")
    IniWrite(hkMap["Quit"],       iniFile, "Hotkeys",  "Quit")

    ; Apply to live variables immediately (no restart needed)
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
    chestOffset  := Integer(saved.ChestOffset)

    ; Recalculate chest positions from saved center + new offset
    skinX := catCenterX - chestOffset
    cosX  := catCenterX + chestOffset
    hkTyping     := hkMap["Typing"]
    hkSpam       := hkMap["Spam"]
    hkOverlay    := hkMap["Overlay"]
    hkSetup      := hkMap["Setup"]
    hkClaim      := hkMap["Claim"]
    hkQuit       := hkMap["Quit"]

    RegisterHotkeys()

    sg.Destroy()
    ToolTip("Settings saved!")
    Sleep(1500)
    ToolTip()
}

; -------------------------------------------------------
;  USER ACTIVITY DETECTION
;  Used by Realistic Typing to detect whether the user
;  is actively at the keyboard/mouse.
;
;  How it works:
;    - Any mouse button click or keyboard press (via ~* prefix,
;      meaning "don't block the key") resets a one-shot timer.
;    - Mouse movement is caught via OnMessage (WM_MOUSEMOVE = 0x0200).
;    - After idleTimeout ms of no activity, ResumeAfterIdle fires
;      and sets userIdle = true, allowing Realistic Typing to resume.
;    - Any new activity sets userIdle = false immediately, pausing it.
;
;  The ~* prefix means the hotkey fires but the key still passes through
;  to whatever application is active � so this is purely passive monitoring.
; -------------------------------------------------------
~*LButton:: SetTimer(ResumeAfterIdle, -idleTimeout)
~*RButton:: SetTimer(ResumeAfterIdle, -idleTimeout)
~*MButton:: SetTimer(ResumeAfterIdle, -idleTimeout)
~*$a::      SetTimer(ResumeAfterIdle, -idleTimeout)  ; Any 'a' keypress acts as a proxy for general keyboard activity

OnMessage(0x0200, WM_MOUSEMOVE)  ; Register WM_MOUSEMOVE message handler
WM_MOUSEMOVE(wParam, lParam, msg, hwnd2) {
    global userIdle
    userIdle := false
    SetTimer(ResumeAfterIdle, -idleTimeout)  ; Restart the idle countdown
}

ResumeAfterIdle() {
    global userIdle
    userIdle := true  ; No activity for idleTimeout ms � safe to resume typing
}

; -------------------------------------------------------
;  SENDF13
;  Sends a single F13 keypress.
;  F13 is used because it's a real key that Bongo Cat counts
;  as a point, but no application uses it, so it won't
;  interfere with anything. F13-F23 are all blocked below
;  so they can't accidentally trigger anything.
; -------------------------------------------------------
SendF13() {
    SendMode("Event")
    SendEvent("{F13 down}")
    Sleep(20)
    SendEvent("{F13 up}")
    Sleep(20)
}

; -------------------------------------------------------
;  TOGGLE ACTIONS
;  These are called by the registered hotkeys.
;  Each toggle turns off the other mode if it's active
;  (Spam and Realistic Typing are mutually exclusive).
; -------------------------------------------------------

; Toggle Realistic Typing on/off
ToggleTyping(*) {
    global clicking, spamming, userIdle
    ; If spam is running, turn it off first
    if spamming {
        spamming := false
        SetTimer(DoSpam, 0)
        ToolTip("Spam: OFF")
        Sleep(1000)
        ToolTip()
    }
    clicking := !clicking
    userIdle := true  ; Assume idle so typing can start immediately
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

; Toggle Spam on/off
ToggleSpam(*) {
    global spamming, clicking, userIdle, spamInterval
    ; If realistic typing is running, turn it off first
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
        ; No tooltip on enable � intentionally silent to avoid interrupting work
    } else {
        SetTimer(DoSpam, 0)
        ToolTip("Bongo Cat: OFF")
        Sleep(1000)
        ToolTip()
    }
}

; Toggle the overlay countdown GUI
ToggleOverlay(*) {
    global guiVisible, skinX
    if (catCenterX = 0) {
        ToolTip("No config. Run setup first.")
        Sleep(2000)
        ToolTip()
        return
    }
    if guiVisible
        HideOverlayGuis()
    else
        ShowOverlayGuis()
}

; Start the chest coordinate setup wizard.
; Behaviour differs based on whether this is the first run:
;   - Initial setup (no .ini existed): claims chests immediately after clicking, starts timers
;   - Subsequent setup (.ini exists): only updates cat center coordinates, timers are NOT reset
StartSetup(*) {
    global setupStep, bongohwnd, exeName, isInitialSetup, iniFile
    bongohwnd := WinExist("ahk_exe " exeName)
    if !bongohwnd {
        MsgBox("Bongo Cat not found! Make sure it's running.", "Error", 16)
        return
    }
    HideOverlayGuis()
    setupStep := 1

    if isInitialSetup
        ToolTip("SETUP (first run): Click the CENTER of your cat � chests will be claimed immediately")
    else
        ToolTip("SETUP: Click the CENTER of your cat � timers will NOT be reset")

    InstallSetupHook()
}

; Force claim both chests right now and reset the timers
ManualClaim(*) {
    global skinX, skinY, cosX, cosY, bongohwnd, exeName
    global skinNext, cosNext, claimOffset, iniFile

    if (catCenterX = 0) {
        MsgBox("No coordinates saved. Run setup first.", "Error", 16)
        return
    }
    bongohwnd := WinExist("ahk_exe " exeName)
    if !bongohwnd {
        MsgBox("Bongo Cat not found!", "Error", 16)
        return
    }

    ; Recalculate in case chestOffset changed since last setup
    skinX := catCenterX - chestOffset
    skinY := catCenterY
    cosX  := catCenterX + chestOffset
    cosY  := catCenterY

    now      := A_TickCount
    DoClick(skinX, skinY, bongohwnd)
    skinNext := now + claimOffset          ; Schedule next skin claim
    Sleep(300)
    DoClick(cosX, cosY, bongohwnd)
    cosNext  := skinNext + 1000            ; Cosmetic is offset by 1 second to avoid overlap

    ; Persist timestamps so they survive a script restart
    IniWrite(skinNext, iniFile, "Timestamps", "SkinNext")
    IniWrite(cosNext,  iniFile, "Timestamps", "CosNext")

    ToolTip("Claimed! Next in: " MsToMMSS(skinNext - A_TickCount))
    Sleep(2000)
    ToolTip()
}

; Clean shutdown � stop all timers and exit
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
;  BLOCK F13-F23
;  These keys are used as the keystroke payload for both
;  Spam and Realistic Typing. Blocking them here ensures
;  they don't accidentally trigger shortcuts or actions
;  in any application while the script is running.
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
;  DOTYPINGRHYTHM
;  The Realistic Typing timer callback.
;  Called repeatedly by SetTimer while `clicking` is true.
;
;  Pattern:
;    1. Skip if user is active (userIdle = false)
;    2. Pick a random burst length
;    3. Send that many F13 keypresses with random delays between them
;       (occasionally inserts a longer "hesitation" pause)
;    4. Wait a random pause before the next burst
; -------------------------------------------------------
DoTypingRhythm() {
    global clicking, userIdle, burstMin, burstMax, fastDelayMin, fastDelayMax, pauseMin, pauseMax
    if !userIdle
        return
    burstLen := Random(burstMin, burstMax)
    Loop burstLen {
        if (!clicking || !userIdle)
            return  ; Stop mid-burst if user becomes active
        SendF13()
        ; 1-in-5 chance of a longer "hesitation" pause between keystrokes
        if (Random(1, 5) = 1)
            Sleep(Random(150, 300))
        else
            Sleep(Random(fastDelayMin, fastDelayMax))
    }
    Sleep(Random(pauseMin, pauseMax))  ; Pause between bursts
}

; -------------------------------------------------------
;  DOSPAM
;  The Spam timer callback.
;  Runs in a tight while-loop sending F13�F23 in batches.
;  Pauses briefly if a chest claim is in progress (claiming = true)
;  to avoid the two operations conflicting.
;
;  WARNING: This sends ~11 keystrokes every 2ms and will
;  significantly load your CPU. Not suitable for use while
;  actively using the computer.
; -------------------------------------------------------
DoSpam() {
    global spamming, claiming
    while spamming {
        if claiming {
            Sleep(20)   ; Wait for DoClick to finish before continuing
            continue
        }
        SendMode("Event")
        loop 11 {
            SendEvent("{F" (12 + A_Index) " down}")  ; F13 through F23
            Sleep(1)
            SendEvent("{F" (12 + A_Index) " up}")
            Sleep(1)
        }
    }
}

; -------------------------------------------------------
;  SETUP � LOW-LEVEL MOUSE HOOK
;
;  Bongo Cat is a DirectX overlay with click-through enabled,
;  meaning normal AHK ~LButton hooks don't fire when you click
;  on it � the click passes through to whatever is behind it.
;
;  To detect clicks on the overlay during setup, we use a
;  Windows low-level mouse hook (WH_MOUSE_LL, id=14) via DllCall.
;  This intercepts all mouse events system-wide at the OS level,
;  before Windows even processes them.
;
;  IMPORTANT: This only works if the script and Bongo Cat are
;  running at the same privilege level. If Bongo Cat is running
;  as Administrator, this script must also run as Administrator.
;  The reverse is also true � do NOT run Bongo Cat as admin
;  if you can avoid it.
;
;  Flow:
;    StartSetup()         ? InstallSetupHook()
;    User clicks anywhere ? SetupMouseProc fires (on OS thread)
;                         ? schedules SetupPoll() via SetTimer
;    SetupPoll()          ? reads mouse position, records coordinates
;                         ? after step 2, UninstallSetupHook()
; -------------------------------------------------------
SetupPoll() {
    global setupStep, catCenterX, catCenterY, skinX, skinY, cosX, cosY
    global iniFile, claimOffset, skinNext, cosNext, bongohwnd, chestOffset
    global isInitialSetup

    if (setupStep = 0) {
        SetTimer(SetupPoll, 0)
        return
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    if (setupStep = 1) {
        ; Record cat center and derive chest positions
        catCenterX := mx
        catCenterY := my
        skinX      := catCenterX - chestOffset
        skinY      := catCenterY
        cosX       := catCenterX + chestOffset
        cosY       := catCenterY

        setupStep := 0
        SetTimer(SetupPoll, 0)
        UninstallSetupHook()
        ToolTip("")

        ; Always save the new center coordinates
        IniWrite(catCenterX, iniFile, "Coords", "CatCenterX")
        IniWrite(catCenterY, iniFile, "Coords", "CatCenterY")

        if isInitialSetup {
            ; First run � claim chests immediately and start all timers
            isInitialSetup := false

            Sleep(200)
            now      := A_TickCount
            DoClick(skinX, skinY, bongohwnd)
            skinNext := now + claimOffset
            Sleep(300)
            DoClick(cosX, cosY, bongohwnd)
            cosNext  := skinNext + 1000

            IniWrite(skinNext, iniFile, "Timestamps", "SkinNext")
            IniWrite(cosNext,  iniFile, "Timestamps", "CosNext")

            ToolTip("Setup complete! Chests claimed.")
            Sleep(2000)
            ToolTip()

            SetTimer(AutoClaim, 1000)
            CreateOverlayGuis()
            ShowOverlayGuis()
            SetTimer(UpdateGui, 1000)
        } else {
            ; Subsequent run � only update position, leave timers completely untouched
            ToolTip("Position updated. Timers unchanged.")
            Sleep(2000)
            ToolTip()

            ; Rebuild overlay GUIs at the new position
            CreateOverlayGuis()
            ShowOverlayGuis()
        }
    }
}

setupMouseHook := 0   ; Handle to the installed Windows hook (0 = not installed)
setupMouseCB   := 0   ; Callback pointer � must be kept alive to prevent garbage collection

InstallSetupHook() {
    global setupMouseHook, setupMouseCB
    ; Create a C-compatible callback from the AHK function SetupMouseProc
    ; "Fast" means it runs on the calling thread without an AHK thread switch
    setupMouseCB   := CallbackCreate(SetupMouseProc, "Fast")
    setupMouseHook := DllCall("SetWindowsHookEx",
        "int",  14,           ; WH_MOUSE_LL � low-level mouse hook
        "ptr",  setupMouseCB, ; Our callback function
        "ptr",  0,            ; hMod (0 = current process)
        "uint", 0,            ; dwThreadId (0 = all threads)
        "ptr")                ; Return type: hook handle
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

; Called by Windows on every mouse event while the hook is installed.
; Must return quickly � heavy work is dispatched via SetTimer.
SetupMouseProc(nCode, wParam, lParam) {
    global setupStep
    ; nCode >= 0 means we should process the event
    ; wParam 0x0201 = WM_LBUTTONDOWN (left mouse button pressed)
    if (nCode >= 0 && wParam = 0x0201 && setupStep > 0)
        SetTimer(SetupPoll, -1)  ; -1 = run once immediately on AHK's thread
    ; Always call the next hook in the chain � required by Windows hook protocol
    return DllCall("CallNextHookEx", "ptr", 0, "int", nCode, "ptr", wParam, "ptr", lParam, "ptr")
}

; -------------------------------------------------------
;  OVERLAY GUI
;
;  Two small frameless always-on-top windows, one above each
;  chest, showing a MM:SS countdown and "READY" in green when
;  the chest is claimable.
;
;  Window flags used:
;    -Caption    = no title bar
;    +ToolWindow = smaller taskbar presence
;    +E0x20      = WS_EX_TRANSPARENT (click-through)
;
;  WinSetTransparent(210, ...) = ~82% opacity (0=invisible, 255=solid)
; -------------------------------------------------------
CreateOverlayGuis() {
    global skinGui, cosGui

    ; Destroy existing windows if re-running setup
    if IsObject(skinGui)
        skinGui.Destroy()
    if IsObject(cosGui)
        cosGui.Destroy()

    skinGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    skinGui.BackColor := "111111"
    skinGui.SetFont("s9 cWhite bold", "Segoe UI")
    skinGui.Add("Text", "vSkinLabel w110 Center", "?? Skin")
    skinGui.Add("Text", "vSkinTimer w110 Center", "--:--")
    WinSetTransparent(210, skinGui)

    cosGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    cosGui.BackColor := "111111"
    cosGui.SetFont("s9 cWhite bold", "Segoe UI")
    cosGui.Add("Text", "vCosLabel w110 Center", "? Cosmetic")
    cosGui.Add("Text", "vCosTimer w110 Center", "--:--")
    WinSetTransparent(210, cosGui)
}

ShowOverlayGuis() {
    global skinGui, cosGui, skinX, skinY, cosX, cosY, guiOffsetY, guiVisible
    if (!IsObject(skinGui) || !IsObject(cosGui))
        return
    ; Position each window centred horizontally above its chest (window is 110px wide)
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

; Called every second by SetTimer to refresh the countdown text
UpdateGui() {
    global skinGui, cosGui, skinNext, cosNext, guiVisible
    if (!guiVisible || !IsObject(skinGui) || !IsObject(cosGui))
        return
    now := A_TickCount

    skinMs := skinNext - now
    if (skinMs <= 0) {
        skinGui["SkinTimer"].Text := "READY"
        skinGui["SkinTimer"].SetFont("cLime")   ; Green when claimable
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
;  AUTOCLAIM
;  Called every second by SetTimer.
;  Checks whether either chest's timestamp has elapsed
;  and claims it if so, then reschedules for next time.
; -------------------------------------------------------
AutoClaim() {
    global skinX, skinY, cosX, cosY, bongohwnd, exeName
    global skinNext, cosNext, claimOffset, iniFile

    if (catCenterX = 0)
        return  ; Setup hasn't been run yet

    bongohwnd := WinExist("ahk_exe " exeName)
    if !bongohwnd
        return  ; Bongo Cat isn't running

    ; Always recalculate from center � picks up any chestOffset changes from Settings
    skinX := catCenterX - chestOffset
    skinY := catCenterY
    cosX  := catCenterX + chestOffset
    cosY  := catCenterY

    now := A_TickCount

    if (skinNext > 0 && now >= skinNext) {
        DoClick(skinX, skinY, bongohwnd)
        skinNext := now + claimOffset            ; Schedule next claim
        IniWrite(skinNext, iniFile, "Timestamps", "SkinNext")
        Sleep(300)  ; Small gap between the two chest clicks
    }

    if (cosNext > 0 && now >= cosNext) {
        DoClick(cosX, cosY, bongohwnd)
        cosNext := now + claimOffset
        IniWrite(cosNext, iniFile, "Timestamps", "CosNext")
    }
}

; -------------------------------------------------------
;  DOCLICK
;  Moves the mouse to (x, y), clicks clickCount times,
;  and returns the cursor to its original position.
;
;  BlockInput("MouseMove") freezes physical mouse movement
;  during the operation so the cursor doesn't drift if the
;  user is moving their mouse at the same time.
;
;  After clicking, WinActivate restores focus to whichever
;  window was active before � preventing the click from
;  stealing keyboard focus away from the user's work.
;
;  The `claiming` flag is set during the click so DoSpam
;  knows to pause and not conflict with the input events.
; -------------------------------------------------------
DoClick(x, y, hwnd) {
    global claiming, clickCount
    CoordMode("Mouse", "Screen")  ; Absolute screen coords (works across monitors)

    activeHwnd := WinExist("A")   ; Remember which window has focus right now
    claiming   := true

    MouseGetPos(&origX, &origY)
    BlockInput("MouseMove")       ; Freeze physical mouse movement
    MouseMove(x, y, 0)            ; Teleport to target (speed=0, instant)
    Sleep(30)                     ; Give the overlay time to register the hover
    Loop clickCount {
        SendEvent("{LButton down}")
        Sleep(60)                 ; Hold duration � needs to be long enough for the overlay to register
        SendEvent("{LButton up}")
        Sleep(30)                 ; Gap between repeated clicks
    }
    MouseMove(origX, origY, 0)    ; Return cursor to original position
    BlockInput("MouseMoveOff")    ; Unfreeze physical mouse

    claiming := false

    ; Restore focus to the previously active window (if it wasn't Bongo Cat itself)
    if (activeHwnd && activeHwnd != hwnd) {
        try WinActivate("ahk_id " activeHwnd)
    }
}

; -------------------------------------------------------
;  HELPERS
; -------------------------------------------------------

; Converts a millisecond duration to MM:SS display string
; e.g. 125000ms ? "02:05"
MsToMMSS(ms) {
    if (ms <= 0)
        return "00:00"
    ms   := Integer(Round(ms))  ; Avoid float errors from A_TickCount arithmetic
    secs := ms // 1000
    mins := secs // 60
    secs := Mod(secs, 60)
    return Format("{:02d}:{:02d}", mins, secs)
}
