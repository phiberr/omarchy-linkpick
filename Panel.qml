import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.phiberr.linksheet"
  ipcTarget: "io.github.phiberr.linksheet"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property bool enabledFlag: true
  property bool askByDefault: true
  property bool stripTracking: true
  property string summary: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string helper: "omarchy-linksheet"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runHelper(args) {
    helperProc.command = [root.helper].concat(args)
    helperProc.running = true
  }

  onOpenedChanged: if (opened) refresh()

  implicitWidth: 1
  implicitHeight: 1

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          root.enabledFlag = data.enabled === true
          root.askByDefault = data.ask_by_default === true
          root.stripTracking = data.strip_tracking === true
          var always = data.always || {}
          var preferred = data.preferred || {}
          root.summary = Object.keys(always).length + " always · " + Object.keys(preferred).length + " preferred"
          if (root.hostWidget && "enabled" in root.hostWidget)
            root.hostWidget.enabled = root.enabledFlag
        } catch (e) {
          root.summary = "status unavailable"
        }
      }
    }
  }

  Process {
    id: helperProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        Text {
          text: "LinkSheet"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          font.bold: true
          width: parent.width
        }

        Text {
          text: root.summary
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          width: parent.width
          wrapMode: Text.Wrap
        }

        Toggle {
          width: parent.width
          label: "Intercept links"
          description: "Ask or apply host rules instead of always using the browser"
          checked: root.enabledFlag
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.runHelper([root.enabledFlag ? "disable" : "enable"])
        }

        Toggle {
          width: parent.width
          label: "Ask when unsure"
          description: "Chooser lists Chrome profiles; then Just once / Always / Prefer"
          checked: root.askByDefault
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.runHelper(["set-ask", root.askByDefault ? "off" : "on"])
        }

        Toggle {
          width: parent.width
          label: "Strip tracking"
          description: "Remove utm_*, fbclid, gclid and similar query params"
          checked: root.stripTracking
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.runHelper(["set-strip", root.stripTracking ? "off" : "on"])
        }

        PanelSeparator {
          foreground: root.foreground
          width: parent.width
        }

        Button {
          width: parent.width
          text: "Open clipboard URL"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: {
            root.runHelper(["clipboard"])
            root.close()
          }
        }

        Button {
          width: parent.width
          text: "Edit rules in terminal"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: {
            Quickshell.execDetached([
              "omarchy-launch-terminal",
              "bash", "-lc",
              "omarchy-linksheet status; echo; omarchy-linksheet handlers; echo; echo 'Examples:'; echo '  omarchy-linksheet always youtube.com youtube'; echo '  omarchy-linksheet preferred github.com browser'; echo '  omarchy-linksheet always example.com clear'; echo; exec bash"
            ])
            root.close()
          }
        }

        Button {
          width: parent.width
          text: "Doctor"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: {
            Quickshell.execDetached([
              "omarchy-launch-terminal",
              "bash", "-lc",
              "omarchy-linksheet doctor; echo; read -n1 -s -p 'Press any key'"
            ])
            root.close()
          }
        }
      }
    }
  }
}
