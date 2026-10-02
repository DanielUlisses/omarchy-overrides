#Requires AutoHotkey v2.0
#SingleInstance Force

; Omarchy keybindings on Windows: Super becomes Win. Mirrors Omarchy's defaults plus
; overrides/omarchy-overrides.lua, remapped to the apps and Chrome profiles on this box.
; Tiling, workspaces and window rules belong to GlazeWM (windows/glazewm/config.yaml);
; this script keeps the app launchers and the omarchy-context client keys.

SetTitleMatchMode 2

; This script is the one started at login (Startup folder), and it starts GlazeWM. Both
; hook the keyboard and the newest hook sees keys first, so whenever GlazeWM (re)starts,
; the hook is reinstalled on top: the app keys here must reach AutoHotkey, the rest
; passes through to GlazeWM.
GLAZEWM_EXE := A_ProgramFiles "\glzr.io\GlazeWM\glazewm.exe"
glazewmPid := 0

KeepHookOnTop() {
    global glazewmPid
    pid := ProcessExist("glazewm.exe")
    if pid && pid != glazewmPid {
        glazewmPid := pid
        Sleep 1500 ; let GlazeWM finish installing its own hook first
        InstallKeybdHook true, true
    }
}

if !ProcessExist("glazewm.exe") && FileExist(GLAZEWM_EXE)
    Run '"' GLAZEWM_EXE '" start'
SetTimer KeepHookOnTop, 3000

; ---------------------------------------------------------------------------------------
; Taskbar
; ---------------------------------------------------------------------------------------

; Fully hidden, as Omarchy has none: Zebar is the bar, tray icons included. Auto-hide
; hands the taskbar's space to windows, and hiding its windows (one per monitor) removes
; the strip auto-hide leaves at the screen edge. Explorer shows them again now and then
; (its restarts, display changes), hence the timer. It leaves them alone while Start or
; Search is open. Win+Alt+B brings the taskbar back until pressed again; leaving the
; script brings it back too.
taskbarHidden := true

SetTaskbarAutoHide(on) {
    abd := Buffer(A_PtrSize = 8 ? 48 : 36, 0) ; APPBARDATA
    NumPut "UInt", abd.Size, abd, 0
    NumPut "Ptr", WinExist("ahk_class Shell_TrayWnd"), abd, A_PtrSize
    NumPut "Ptr", on ? 1 : 2, abd, abd.Size - A_PtrSize ; ABS_AUTOHIDE / ABS_ALWAYSONTOP
    DllCall "Shell32\SHAppBarMessage", "UInt", 0xA, "Ptr", abd ; ABM_SETSTATE
}

TaskbarWindows() {
    list := WinGetList("ahk_class Shell_TrayWnd")
    for hwnd in WinGetList("ahk_class Shell_SecondaryTrayWnd")
        list.Push(hwnd)
    return list
}

HideTaskbar() {
    if !taskbarHidden
        || WinActive("ahk_exe StartMenuExperienceHost.exe")
        || WinActive("ahk_exe SearchHost.exe")
        return
    for hwnd in TaskbarWindows() ; visible ones only (DetectHiddenWindows is off)
        WinHide hwnd
}

ShowTaskbar() {
    DetectHiddenWindows true
    for hwnd in TaskbarWindows()
        WinShow hwnd
}

#!b:: {
    global taskbarHidden := !taskbarHidden
    taskbarHidden ? HideTaskbar() : ShowTaskbar()
}

SetTaskbarAutoHide(true)
HideTaskbar()
SetTimer HideTaskbar, 2000
OnExit (*) => (ShowTaskbar(), 0)

; ---------------------------------------------------------------------------------------
; Launch helpers
; ---------------------------------------------------------------------------------------

LOCALAPPDATA := EnvGet("LOCALAPPDATA")
; The user-local copy bundles a current ConPTY (conpty.dll + OpenConsole.exe, see
; wsl-setup-shell.sh). Windows' built-in one re-renders full-screen programs and leaves
; stray characters behind in herdr and Claude Code.
ALACRITTY := FileExist(LOCALAPPDATA "\Programs\Alacritty\conpty.dll")
    ? LOCALAPPDATA "\Programs\Alacritty\alacritty.exe"
    : A_ProgramFiles "\Alacritty\alacritty.exe"
CHROME := A_ProgramFiles "\Google\Chrome\Application\chrome.exe"

; Chrome profile directories on this machine (Local State), not the Linux ones:
;   Default   = Pythian (dsilva@pythian.com)
;   Profile 3 = personal (daniel.u.silva@gmail.com)
;   Profile 7 = Lanvera (renamed from codingband.com)
;   Profile 8 = BSS
PERSONAL := "Profile 3"
PYTHIAN := "Default"
LANVERA := "Profile 7"
BSS := "Profile 8"

; Bring an existing window forward, otherwise start the app (Omarchy's focus = true).
; target is a command line, or a function for launches that need more than Run.
FocusOrRun(winTitle, target) {
    if WinExist(winTitle)
        WinActivate
    else if target is Func
        target()
    else
        Run target
}

; Windows Store apps have no stable exe path; start them through their AppUserModelID.
StoreApp(appId) => "explorer.exe shell:AppsFolder\" appId

; A command inside WSL in a new Alacritty window, with the full interactive shell setup.
; Alacritty on Windows hands its -e arguments to wsl.exe joined with spaces and without
; re-quoting, so a plain "cmd" reached bash as separate words and only the first one ran.
; The escaped quotes survive that hand-off. cmd must not contain double quotes itself.
; opts are extra Alacritty options, placed before -e.
Terminal(cmd := "", opts := "") {
    if cmd = ""
        Run '"' ALACRITTY '" ' opts
    else
        Run '"' ALACRITTY '" ' opts ' -e wsl.exe -d Arch --cd ~ -e bash -lic "\"' cmd '\""'
}

Browser(profile, extra := "") => Run('"' CHROME '" --profile-directory="' profile '" ' extra)
WebApp(url, profile) => Browser(profile, "--app=" url)

; ---------------------------------------------------------------------------------------
; Applications
; ---------------------------------------------------------------------------------------

#Enter:: Terminal()
#!Enter:: Terminal("tmux attach || tmux new -s Work")
#^Enter:: Terminal("herdr")
#+d:: Terminal("lazydocker")
#+!a:: Terminal("claude")
; The "machine" agent (.claude/agents/machine.md) for quick tweaks to this setup, as a
; quake-style drop-down: Win+Alt+C opens it across the top of the primary monitor, always on
; top, and from then on hides it (session kept running) or brings it back. Its fixed title
; is what GlazeWM ignores (config.yaml) so it is never tiled.
MACHINE_AGENT := "machine-agent ahk_exe alacritty.exe"

#!c:: {
    DetectHiddenWindows true
    if !WinExist(MACHINE_AGENT) {
        Terminal("cd ~/repos/daniel/omarchy-overrides && claude --agent machine",
            "--title machine-agent -o window.dynamic_title=false")
        if WinWait(MACHINE_AGENT, , 10)
            ShowDropDown(MACHINE_AGENT)
    } else if WinActive(MACHINE_AGENT) && DllCall("IsWindowVisible", "Ptr", WinExist(MACHINE_AGENT))
        WinHide MACHINE_AGENT ; a hidden window can still count as the active one
    else
        ShowDropDown(MACHINE_AGENT)
}

ShowDropDown(win) {
    MonitorGetWorkArea MonitorGetPrimary(), &left, &top, &right, &bottom
    WinShow win
    WinSetAlwaysOnTop true, win
    WinMove left, top, right - left, Round((bottom - top) * 0.6), win
    ; Windows sometimes refuses focus to a window that was just unhidden; ask again.
    Loop 3 {
        WinActivate win
        if WinWaitActive(win, , 0.3)
            break
    }
}

#+b:: Browser(PERSONAL)
#+!b:: Browser(PERSONAL, "--incognito")
#e:: Run '"' LOCALAPPDATA '\Programs\Microsoft VS Code\Code.exe"'
#+f:: Run "explorer.exe"

; No Win+\ for Quick Access: 1Password ignores injected keystrokes and keeps its hidden
; Quick Access window from being shown by other programs, and cannot register Win combos
; itself. Quick Access is set in 1Password to Ctrl+Shift+\ (Ctrl+|), next to Win+Shift+\ below.
#+\:: FocusOrRun("ahk_exe 1Password.exe", StoreApp("Agilebits.1Password_amwd9z03whsfe!Agilebits.OnePassword"))

#+a:: FocusOrRun("ahk_exe claude.exe", StoreApp("Claude_pzs8sxrjxfjjc!Claude"))
#+s:: FocusOrRun("ahk_exe slack.exe", '"' LOCALAPPDATA '\slack\slack.exe"')
#+t:: FocusOrRun("ahk_exe ms-teams.exe", StoreApp("MSTeams_8wekyb3d8bbwe!MSTeams"))
; Match the main window by title: Spark also keeps a visible "Active Transcription" widget,
; and from the tray its main window is hidden, where rerunning the exe brings it back.
#+e:: FocusOrRun("Spark Desktop ahk_exe Spark Desktop.exe",'"' LOCALAPPDATA '\Programs\SparkDesktop\Spark Desktop.exe"')
#+w:: FocusOrRun("WhatsApp ahk_exe chrome.exe", () => WebApp("https://web.whatsapp.com/", PERSONAL))

#+y:: WebApp("https://youtube.com/", PERSONAL)
#+m:: WebApp("https://meet.google.com/", PYTHIAN)
#+g:: WebApp("https://vertexaisearch.cloud.google.com/home/cid/a72e70f2-3125-4270-916e-2c345f90d694", PYTHIAN)
#+h:: WebApp("https://pythian.atlassian.net/jira/apps/fa75e928-007a-4af4-9530-76503bcd4cba/ea7fda46-2015-4367-bd93-992fbf0c58ca/my-work/week?type=LIST", PYTHIAN)

; Universal copy/paste, as Omarchy does it: Ctrl+Insert / Shift+Insert work in terminals
; (Alacritty binds both) as well as in regular apps. Win+Ctrl+V is Windows' own
; clipboard history, which normally sits on the Win+V taken here.
#c:: Send "^{Insert}"
#v:: Send "+{Insert}"
#^v:: Send "#v"

; Print Screen selects a region, like Omarchy: Snipping Tool's capture overlay instead of
; copying the whole desktop.
PrintScreen:: Run "ms-screenclip:"

; Cloud PCs, from the .rdp/.rdpw files in %APPDATA%\omarchy\rdp (never in this public repo).
; Opened as they are, the files win over the Windows App's own display settings and span
; every monitor full screen (use multimon:i:1, or screen mode id's full-screen default).
; So each launch opens a regenerated copy with only the display properties rewritten to
; a window on one monitor, which GlazeWM then tiles onto the client's 4n row. Windows key
; combos also stay on this machine (keyboardhook:i:0): by default the session grabs them
; while it has focus, so GlazeWM and the keys below go dead inside it. Remote Start is
; still Ctrl+Esc. None of these properties are in the files' signscope, so the Microsoft
; signature stays valid.
RDP_DIR := A_AppData "\omarchy\rdp\"

OpenRdp(rdpFile, *) {
    src := RDP_DIR rdpFile
    if !FileExist(src) {
        TrayTip "Missing " src, "Cloud PC", 3
        return
    }
    out := ""
    for line in StrSplit(FileRead(src), "`n", "`r")
        if line != "" && !RegExMatch(line, "i)^(screen mode id|use multimon|selectedmonitors|singlemoninwindowedmode|maximizetocurrentdisplays|dynamic resolution|keyboardhook):")
            out .= line "`r`n"
    out .= "screen mode id:i:1`r`nuse multimon:i:0`r`nsinglemoninwindowedmode:i:1`r`ndynamic resolution:i:1`r`nkeyboardhook:i:0`r`n"
    dir := A_Temp "\omarchy-rdp"
    DirCreate dir
    dst := dir "\" rdpFile
    try FileDelete dst
    FileAppend out, dst, "UTF-16"
    Run dst
}

#+r:: OpenRdp("f5.rdpw")
#+!r:: OpenRdp("sharedBss.rdpw")
#+l:: OpenRdp("lanvera.rdpw")

; Kill the focused cloud PC. A locked session has no disconnect button, and closing the
; window only asks the remote side. Each session is its own msrdc.exe; the remote session
; stays signed in, so relaunching reconnects to it. There is no keep-alive against the
; idle lock, unlike FreeRDP's /prevent-session-lock: messages posted to the session's input
; window never reach the remote, and F5's file signs ClientRejectInjectedInput.
#^q:: {
    if WinActive("ahk_class TscShellContainerClass ahk_exe msrdc.exe")
        ProcessClose WinGetPID("A")
}

; ---------------------------------------------------------------------------------------
; Windows
; ---------------------------------------------------------------------------------------

IsDesktopShell(hwnd) {
    cls := WinGetClass(hwnd)
    return cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
}


; Focus the topmost window on the next/previous monitor.
MonitorOf(hwnd) {
    WinGetPos &x, &y, &w, &h, hwnd
    cx := x + w // 2, cy := y + h // 2
    Loop MonitorGetCount() {
        MonitorGet A_Index, &l, &t, &r, &b
        if cx >= l && cx < r && cy >= t && cy < b
            return A_Index
    }
    return 1
}

FocusMonitor(step) {
    count := MonitorGetCount()
    if count < 2
        return
    active := WinExist("A")
    current := active ? MonitorOf(active) : 1
    target := Mod(current - 1 + step + count, count) + 1
    for hwnd in WinGetList() {
        if hwnd = active || IsDesktopShell(hwnd) || WinGetTitle(hwnd) = ""
            continue
        if WinGetMinMax(hwnd) = -1 || !(WinGetStyle(hwnd) & 0x10000000) ; minimized or hidden
            continue
        if MonitorOf(hwnd) = target {
            WinActivate hwnd
            return
        }
    }
}

^!Tab:: FocusMonitor(1)
^!+Tab:: FocusMonitor(-1)

; ---------------------------------------------------------------------------------------
; Client contexts, ported from bin/omarchy-context on top of GlazeWM workspaces.
;   dev monitor:      1 Pythian   2 Lanvera   3 BSS   4 Personal
;   portrait monitor: 2n browser  3n chat     4n cloud PC (Personal: 34 Spark, 44 Claude)
;   Win+F1..F4        switch to that client; pressing it again walks its portrait rows
;   Win+F5            walk the current client's portrait rows
;   Win+Shift+F1..F4  launch that client's apps onto its workspaces, then switch there
;   Win+Shift+Q       close every window on the current client's portrait rows
; Slack, Teams, Spark, WhatsApp, Claude and the cloud PCs are placed by GlazeWM's rules; Chrome
; shares one process across profiles, so its windows are placed here, by opening them
; on the browser row.
; ---------------------------------------------------------------------------------------

GLAZEWM := A_ProgramFiles "\glzr.io\GlazeWM\cli\glazewm.exe"
Glaze(cmd) => RunWait('"' GLAZEWM '" command ' cmd, , "Hide")

; win identifies a running copy (AutoHotkey WinTitle); cloud PC sessions are titled by the
; resource's remotedesktopname from its .rdpw.
CONTEXTS := Map(
    1, {chrome: PYTHIAN, rows: [21, 31, 41], apps: [
        {win: "ahk_exe slack.exe", run: '"' LOCALAPPDATA '\slack\slack.exe"'},
        {win: "Cloud PC Enterprise", run: OpenRdp.Bind("f5.rdpw")}]},
    2, {chrome: LANVERA, rows: [22, 32, 42], apps: [
        {win: "@Lanvera.org | Microsoft Teams ahk_exe ms-teams.exe", run: StoreApp("MSTeams_8wekyb3d8bbwe!MSTeams")},
        {win: "SessionDesktop", run: OpenRdp.Bind("lanvera.rdpw")}]},
    ; BSS is Teams' Personal-account window, which GlazeWM puts on 33.
    3, {chrome: BSS, rows: [23, 33, 43], apps: [
        {win: "| Personal | ahk_exe ms-teams.exe", run: StoreApp("MSTeams_8wekyb3d8bbwe!MSTeams")},
        {win: "Shared BSS", run: OpenRdp.Bind("sharedBss.rdpw")}]},
    4, {chrome: PERSONAL, rows: [24, 34, 44], apps: []},
)

; Kept here rather than queried from GlazeWM: a stale guess only costs one extra keypress.
currentContext := 0
rowIndex := Map(1, 1, 2, 1, 3, 1, 4, 1)
contextChrome := Map()

; Same client: advance the portrait row only, so focus stays where you were typing.
; Another client: land on its browser row, then on its dev workspace. (Refocusing the
; workspace already shown would toggle back, so a single-row client stays put.)
SwitchContext(n, *) {
    global currentContext
    rows := CONTEXTS[n].rows
    if n = currentContext {
        if rows.Length > 1 {
            rowIndex[n] := Mod(rowIndex[n], rows.Length) + 1
            Glaze("focus --workspace " rows[rowIndex[n]])
        }
        return
    }
    rowIndex[n] := 1
    Glaze("focus --workspace " rows[1])
    Glaze("focus --workspace " n)
    currentContext := n
}

ChromeWindows() {
    found := Map()
    for hwnd in WinGetList("ahk_exe chrome.exe ahk_class Chrome_WidgetWin_1")
        if InStr(WinGetTitle(hwnd), " - Google Chrome")
            found[hwnd] := true
    return found
}

; Idempotent, like omarchy-context launch: apps already running are left alone.
LaunchContext(n, *) {
    global currentContext
    ctx := CONTEXTS[n]
    Glaze("focus --workspace " ctx.rows[1])
    if !(contextChrome.Has(n) && WinExist("ahk_id " contextChrome[n])) {
        before := ChromeWindows()
        Browser(ctx.chrome)
        Loop 40 { ; a new window opens on the focused workspace, the browser row
            Sleep 250
            for hwnd in ChromeWindows()
                if !before.Has(hwnd) {
                    contextChrome[n] := hwnd
                    break 2
                }
        }
    }
    for app in ctx.apps
        if !WinExist(app.win) {
            if app.run is Func
                app.run()
            else
                Run app.run
            Sleep 800 ; stagger, as omarchy-context does, so windows map in order
        }
    rowIndex[n] := 1
    Glaze("focus --workspace " n)
    currentContext := n
}

; Closes everything on the client's portrait rows, through GlazeWM: a WinClose sent to a
; window on a hidden (cloaked) workspace did not close it. Its apps that wandered off the
; rows are closed by WinTitle afterwards.
QuitContext(*) {
    n := currentContext
    if !CONTEXTS.Has(n)
        return
    tmp := A_Temp "\omarchy-workspaces.json"
    RunWait(A_ComSpec ' /c ""' GLAZEWM '" query workspaces > "' tmp '""', , "Hide")
    json := FileRead(tmp)
    FileDelete tmp
    for chunk in StrSplit(json, '{"type":"workspace",') {
        if !RegExMatch(chunk, '^"id":"[^"]+","name":"(\d+)"', &ws)
            continue
        for row in CONTEXTS[n].rows
            if ws[1] = row {
                pos := 1
                while pos := RegExMatch(chunk, '"type":"window","id":"([^"]+)"', &win, pos) {
                    Glaze("--id " win[1] " close")
                    pos += win.Len
                }
            }
    }
    for app in CONTEXTS[n].apps
        for hwnd in WinGetList(app.win)
            WinClose "ahk_id " hwnd
    if contextChrome.Has(n)
        contextChrome.Delete(n)
}

Loop 4 {
    Hotkey "#F" A_Index, SwitchContext.Bind(A_Index)
    Hotkey "#+F" A_Index, LaunchContext.Bind(A_Index)
}

; Step through the contexts in order, wrapping 4 -> 1, like pressing the next/previous
; Win+F<n>. Meant for mouse buttons (Logi Options+ keystrokes): down = next, as Omarchy's
; Super+scroll-down goes to the next workspace.
StepContext(delta, *) {
    n := CONTEXTS.Count
    SwitchContext(currentContext ? Mod(currentContext - 1 + delta + n, n) + 1 : 1)
}
#PgDn:: StepContext(1)
#PgUp:: StepContext(-1)
#F5:: {
    if currentContext
        SwitchContext(currentContext)
}
#+q:: QuitContext()

; Omarchy's scratchpad toggle (Super+S / Super+`). GlazeWM's own refocus toggle is off
; because it would also bounce the context keys, so the toggle state lives here.
scratchShown := false
ToggleScratchpad(*) {
    global scratchShown
    Glaze(scratchShown ? "focus --recent-workspace" : "focus --workspace S")
    scratchShown := !scratchShown
}
#s:: ToggleScratchpad()
#SC029:: ToggleScratchpad() ; the ` key
