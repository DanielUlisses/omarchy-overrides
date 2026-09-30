#Requires AutoHotkey v2.0
#SingleInstance Force

; Omarchy-style numbered workspaces on top of Windows virtual desktops.
;   Win+1..9        go to desktop N
;   Win+Shift+1..9  move the active window to desktop N
; Missing desktops are created on the way, like Hyprland workspaces.
; Win+1..9 normally opens the Nth taskbar app; this takes those keys over.
;
; Needs VirtualDesktopAccessor.dll next to this script, from
; github.com/Ciantic/VirtualDesktopAccessor (the build must match the Windows release).

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
