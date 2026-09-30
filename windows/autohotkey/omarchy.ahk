#Requires AutoHotkey v2.0
#SingleInstance Force

; Omarchy keybindings on Windows: Super becomes Win. Mirrors Omarchy's defaults plus
; overrides/omarchy-overrides.lua, remapped to the apps and Chrome profiles on this box.
; Win+key combos Windows already owns (Win+E, Win+W, Win+1..9, Win+Shift+S, ...) are taken over.

SetTitleMatchMode 2

; ---------------------------------------------------------------------------------------
; Numbered workspaces on top of Windows virtual desktops
;   Win+1..9        go to desktop N
;   Win+Shift+1..9  move the active window to desktop N
; Missing desktops are created on the way, like Hyprland workspaces.
; Needs VirtualDesktopAccessor.dll next to this script, from
; github.com/Ciantic/VirtualDesktopAccessor (the build must match the Windows release).
; ---------------------------------------------------------------------------------------

dllPath := A_ScriptDir "\VirtualDesktopAccessor.dll"
hVDA := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
if !hVDA {
    MsgBox "Could not load " dllPath
    ExitApp
}

VDA(name) => DllCall("GetProcAddress", "Ptr", hVDA, "AStr", name, "Ptr")
GetDesktopCountProc := VDA("GetDesktopCount")
CreateDesktopProc := VDA("CreateDesktop")
GoToDesktopNumberProc := VDA("GoToDesktopNumber")
MoveWindowToDesktopNumberProc := VDA("MoveWindowToDesktopNumber")

EnsureDesktops(n) {
    while DllCall(GetDesktopCountProc, "Int") < n
        DllCall(CreateDesktopProc, "Int")
}

GoToDesktop(n, *) {
    EnsureDesktops(n)
    DllCall(GoToDesktopNumberProc, "Int", n - 1, "Int")
}

MoveActiveToDesktop(n, *) {
    hwnd := WinExist("A")
    if !hwnd
        return
    EnsureDesktops(n)
    DllCall(MoveWindowToDesktopNumberProc, "Ptr", hwnd, "Int", n - 1, "Int")
}

Loop 9 {
    Hotkey "#" A_Index, GoToDesktop.Bind(A_Index)
    Hotkey "#+" A_Index, MoveActiveToDesktop.Bind(A_Index)
}

; ---------------------------------------------------------------------------------------
; Launch helpers
; ---------------------------------------------------------------------------------------

LOCALAPPDATA := EnvGet("LOCALAPPDATA")
ALACRITTY := A_ProgramFiles "\Alacritty\alacritty.exe"
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
Terminal(cmd := "") {
    if cmd = ""
        Run '"' ALACRITTY '"'
    else
        Run '"' ALACRITTY '" -e wsl.exe -d Arch --cd ~ -e bash -lic "' cmd '"'
}

Browser(profile, extra := "") => Run('"' CHROME '" --profile-directory="' profile '" ' extra)
WebApp(url, profile) => Browser(profile, "--app=" url)

; Cloud PC files are kept out of the (public) repo, in %APPDATA%\omarchy\rdp. The AVD ones
; are .rdpw (Windows App format); plain .rdp opens in Remote Desktop Connection.
OpenRdp(file) {
    file := A_AppData "\omarchy\rdp\" file
    if FileExist(file)
        Run file
    else
        TrayTip "Missing " file, "Cloud PC", 3
}

; ---------------------------------------------------------------------------------------
; Applications
; ---------------------------------------------------------------------------------------

#Enter:: Terminal()
#!Enter:: Terminal("tmux attach || tmux new -s Work")
#^Enter:: Terminal("herdr")
#+d:: Terminal("lazydocker")
#+!a:: Terminal("claude")

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

#+r:: OpenRdp("f5.rdpw")
#+!r:: OpenRdp("sharedBss.rdpw")
#+l:: OpenRdp("lanvera.rdpw")
#+^r:: OpenRdp("Pythian.rdp") ; 172.16.0.16

; ---------------------------------------------------------------------------------------
; Windows
; ---------------------------------------------------------------------------------------

IsDesktopShell(hwnd) {
    cls := WinGetClass(hwnd)
    return cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
}

#w:: {
    hwnd := WinExist("A")
    if hwnd && !IsDesktopShell(hwnd)
        WinClose hwnd
}

#f:: {
    hwnd := WinExist("A")
    if !hwnd || IsDesktopShell(hwnd)
        return
    if WinGetMinMax(hwnd) = 1
        WinRestore hwnd
    else
        WinMaximize hwnd
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
; Client contexts, like bin/omarchy-context: one virtual desktop per client.
;   1 Pythian   2 Lanvera   3 BSS   4 Personal
;   Win+1..4           switch to that client (the desktop keys above)
;   Win+Shift+F1..F4   launch that client's apps onto its desktop, then switch there
;   Win+Shift+Q        close the current client's apps
; Window rules place an app on its client's desktop when its window opens, however it was
; started. A virtual desktop spans every monitor, so there are no per-monitor rows here.
; ---------------------------------------------------------------------------------------

GetCurrentDesktopNumberProc := VDA("GetCurrentDesktopNumber")
GetWindowDesktopNumberProc := VDA("GetWindowDesktopNumber")

RDP_DIR := A_AppData "\omarchy\rdp\"

; exe and/or title (substring) identify the window. run marks an app the context launches.
; Chrome app windows are titled by the page alone ("WhatsApp"); a normal tab carries
; " - Google Chrome", so a tab called WhatsApp does not drag the whole browser along.
RULES := [
    {desktop: 1, exe: "slack.exe", run: '"' LOCALAPPDATA '\slack\slack.exe"'},
    {desktop: 1, title: "Cloud PC Enterprise", run: RDP_DIR "f5.rdpw"},
    {desktop: 2, exe: "ms-teams.exe", run: StoreApp("MSTeams_8wekyb3d8bbwe!MSTeams")},
    {desktop: 2, title: "SessionDesktop", run: RDP_DIR "lanvera.rdpw"},
    {desktop: 3, title: "Shared BSS", run: RDP_DIR "sharedBss.rdpw"},
    {desktop: 4, exe: "mstsc.exe", title: "172.16.0.16", run: RDP_DIR "Pythian.rdp"},
    {desktop: 4, exe: "Spark Desktop.exe"},
    {desktop: 4, exe: "claude.exe"},
    {desktop: 4, exe: "chrome.exe", title: "WhatsApp", appOnly: true},
]

; Chrome shares one process across profiles, so its windows cannot be told apart by rule;
; like omarchy-context, the context launch places them instead (by opening them on the
; client's desktop).
CONTEXT_CHROME := Map(1, PYTHIAN, 2, LANVERA, 3, BSS, 4, PERSONAL)

RuleMatches(rule, hwnd) {
    try {
        if rule.HasProp("exe") && WinGetProcessName(hwnd) != rule.exe
            return false
        title := WinGetTitle(hwnd)
    } catch
        return false
    if rule.HasProp("title") && !InStr(title, rule.title)
        return false
    if rule.HasProp("appOnly") && InStr(title, " - Google Chrome")
        return false
    return true
}

WindowDesktop(hwnd) => DllCall(GetWindowDesktopNumberProc, "Ptr", hwnd, "Int") + 1
CurrentDesktop() => DllCall(GetCurrentDesktopNumberProc, "Int") + 1

MoveToDesktop(hwnd, n) {
    EnsureDesktops(n)
    DllCall(MoveWindowToDesktopNumberProc, "Ptr", hwnd, "Int", n - 1, "Int")
}

; Rules apply once, while a window is new (titles often arrive a moment after the window
; does). Moving it somewhere else by hand later sticks, as with Hyprland window rules.
created := Map()
placed := Map()

PlaceWindow(hwnd) {
    if placed.Has(hwnd) || !created.Has(hwnd) || A_TickCount - created[hwnd] > 15000
        return
    for rule in RULES {
        if RuleMatches(rule, hwnd) {
            placed[hwnd] := true
            if WindowDesktop(hwnd) != rule.desktop
                MoveToDesktop(hwnd, rule.desktop)
            return
        }
    }
}

ShellMessage(wParam, lParam, *) {
    static HSHELL_WINDOWCREATED := 1, HSHELL_REDRAW := 6
    if wParam = HSHELL_WINDOWCREATED {
        created[lParam] := A_TickCount
        for delay in [300, 1500, 5000]
            SetTimer PlaceWindow.Bind(lParam), -delay
    } else if wParam = HSHELL_REDRAW && created.Has(lParam) {
        PlaceWindow(lParam)
    }
}

DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
OnMessage(DllCall("RegisterWindowMessage", "Str", "SHELLHOOK"), ShellMessage)

; Forget windows that are long gone so the maps do not grow forever.
SetTimer () => (PruneMap(created), PruneMap(placed)), 600000
PruneMap(m) {
    for hwnd in [m*]
        if !WinExist("ahk_id " hwnd)
            m.Delete(hwnd)
}

MatchingWindows(rule) {
    found := []
    for hwnd in WinGetList()
        if RuleMatches(rule, hwnd)
            found.Push(hwnd)
    return found
}

ChromeOnDesktop(n) {
    for hwnd in WinGetList("ahk_exe chrome.exe ahk_class Chrome_WidgetWin_1")
        if WinGetTitle(hwnd) != "" && InStr(WinGetTitle(hwnd), " - Google Chrome") && WindowDesktop(hwnd) = n
            return true
    return false
}

; Idempotent, like omarchy-context launch: running apps are pulled onto the desktop,
; missing ones are started there.
LaunchContext(n, *) {
    GoToDesktop(n)
    if !ChromeOnDesktop(n)
        Browser(CONTEXT_CHROME[n])
    for rule in RULES {
        if rule.desktop != n || !rule.HasProp("run")
            continue
        windows := MatchingWindows(rule)
        if windows.Length {
            for hwnd in windows
                MoveToDesktop(hwnd, n)
        } else if InStr(rule.run, RDP_DIR) && !FileExist(rule.run) {
            TrayTip "Missing " rule.run, "Cloud PC", 3
        } else {
            Run rule.run
            ; An app coming back from the tray may reopen on the desktop it last used.
            SetTimer RegroupRule.Bind(rule, n), -4000
            Sleep 800 ; stagger, as omarchy-context does, so windows map in order
        }
    }
}

RegroupRule(rule, n) {
    for hwnd in MatchingWindows(rule)
        if WindowDesktop(hwnd) != n
            MoveToDesktop(hwnd, n)
}

QuitContext(*) {
    n := CurrentDesktop()
    if !CONTEXT_CHROME.Has(n)
        return
    for hwnd in WinGetList("ahk_exe chrome.exe ahk_class Chrome_WidgetWin_1")
        if InStr(WinGetTitle(hwnd), " - Google Chrome") && WindowDesktop(hwnd) = n
            WinClose hwnd
    for rule in RULES
        if rule.desktop = n && rule.HasProp("run")
            for hwnd in MatchingWindows(rule)
                WinClose hwnd
}

Loop 4
    Hotkey "#+F" A_Index, LaunchContext.Bind(A_Index)
#+q:: QuitContext()
