import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Per-monitor workspaces: each bar lists only the workspaces Hyprland's workspace rules
// pin to its own monitor (hyprmoncfg writes them as "desc:<description>"), plus any
// workspace currently living there. The marker shows that monitor's active workspace,
// not the globally focused one. Cloned from omarchy.workspaces, which lists 1..5 plus
// every open workspace on every bar.
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property var screen: root.QsWindow.window ? root.QsWindow.window.screen : null
  readonly property var hyprMonitor: root.screen ? Hyprland.monitorFor(root.screen) : null
  readonly property string monitorName: root.hyprMonitor ? String(root.hyprMonitor.name || "") : ""
  readonly property string monitorDesc: root.hyprMonitor ? String(root.hyprMonitor.description || "") : ""

  // [{ id, monitor }] from `hyprctl workspacerules`, refreshed on config reload.
  property var rules: []

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function ruleMatchesMonitor(monitor) {
    if (!monitor) return false
    if (monitor === root.monitorName) return true
    return monitor.indexOf("desc:") === 0 && root.monitorDesc !== "" && root.monitorDesc.indexOf(monitor.slice(5)) === 0
  }

  readonly property var ids: {
    var ids = []
    for (var r = 0; r < root.rules.length; r++) {
      var rule = root.rules[r]
      if (rule.id > 0 && rule.id <= 10 && root.ruleMatchesMonitor(rule.monitor) && ids.indexOf(rule.id) === -1) ids.push(rule.id)
    }

    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (ws.id > 0 && ws.id <= 10 && ws.monitor && ws.monitor.name === root.monitorName && ids.indexOf(ws.id) === -1) ids.push(ws.id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  Component.onCompleted: rulesProc.running = true

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "configreloaded") rulesProc.running = true
    }
  }

  Process {
    id: rulesProc
    command: ["hyprctl", "-j", "workspacerules"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var listed
        try {
          listed = JSON.parse(text || "[]")
        } catch (e) {
          return
        }

        var rules = []
        for (var i = 0; i < listed.length; i++) {
          var id = parseInt(listed[i].workspaceString, 10)
          if (String(id) === listed[i].workspaceString && listed[i].monitor) rules.push({ id: id, monitor: String(listed[i].monitor) })
        }
        root.rules = rules
      }
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.ids.length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.ids

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.hyprMonitor !== null && root.hyprMonitor.activeWorkspace !== null && root.hyprMonitor.activeWorkspace.id === modelData

        bar: root.bar
        text: focused ? "󱓻" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
