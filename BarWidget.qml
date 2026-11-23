import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.phiberr.linksheet"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  property bool enabled: true

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  Component.onCompleted: root.refreshStatus()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: statusProc
    command: ["omarchy-linksheet", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          root.enabled = data.enabled === true
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.phiberr.linksheet"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.refreshStatus() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌹"
    tooltipText: root.enabled ? "LinkSheet (on)" : "LinkSheet (off)"
    active: root.opened || root.enabled
    onPressed: function(b) { root.togglePanel() }
  }
}
