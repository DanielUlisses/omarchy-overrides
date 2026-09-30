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

; Chrome profiles on this machine (Local State), not the Linux ones:
;   Default   = Pythian (dsilva@pythian.com)
;   Profile 3 = personal (daniel.u.silva@gmail.com)
;   Profile 7 = codingband.com
PERSONAL := "Profile 3"
PYTHIAN := "Default"

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
