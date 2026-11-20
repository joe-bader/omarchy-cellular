import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Cellular bar widget: signal/carrier icon in the bar, and a panel with the
// cellular radio switch, connection details, and connect/disconnect.
//
// State comes from the bundled `cellular-status` helper (read-only mmcli +
// nmcli). Changes go through nmcli with argv arrays, never a shell string.
Panel {
  id: root
  moduleName: "joe.cellular"
  ipcTarget: "joe.cellular"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property int refreshIntervalSec: Math.max(5, Number(setting("refreshIntervalSec", 15)) || 15)

  property var info: ({})
  property bool loaded: false
  property bool busy: false
  // Optimistic radio state while an on/off is in flight; null otherwise.
  property var desiredRadio: null
  property string lastError: ""

  property bool cursorActive: false
  property int cursorIndex: 0

  readonly property string st: Model.status(info)
  readonly property bool radioOn: desiredRadio !== null ? desiredRadio : (info.radio === "enabled")
  readonly property bool hasModem: info.present === "yes"
  readonly property bool showConnect: Model.canConnect(st, info)
  readonly property bool showDisconnect: Model.canDisconnect(st, info)
  readonly property bool hasAction: radioOn && (showConnect || showDisconnect)
  readonly property int cursorCount: hasAction ? 2 : 1

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string statusText: strings.t(Model.statusKey(st, info))
  readonly property string hintText: {
    var key = Model.hintKey(st)
    if (key === "") return ""
    var text = strings.t(key)
    return key === "hint.failed" ? text.arg(info.failed_reason || "?") : text
  }
  readonly property string titleText: Model.carrierName(info) || strings.t("title")
  readonly property string signalText: {
    if (st !== "connected" && st !== "registered" && st !== "connecting") return ""
    var parts = [Commons.I18n.formatNumber(Model.signalPercent(info)) + "%"]
    var tech = Model.techLabel(info.tech)
    if (tech !== "") parts.push(tech)
    return parts.join(" · ")
  }
  readonly property string networkText: {
    if (!hasModem || st === "off") return ""
    if (info.registration === "home") return strings.t("home")
    if (info.registration === "roaming") return strings.t("roaming")
    return strings.t("notRegistered")
  }
  readonly property string dataText: {
    if (info.rx_bytes === undefined) return ""
    return "↓ " + Model.humanBytes(info.rx_bytes, Commons.I18n.formatNumber)
      + "   ↑ " + Model.humanBytes(info.tx_bytes, Commons.I18n.formatNumber)
  }
  readonly property string apnText: info.apn === "auto" ? strings.t("apnAuto") : String(info.apn || "")

  readonly property string tooltipText: {
    var parts = [titleText, statusText]
    if (signalText !== "") parts.push(signalText)
    return parts.join(" — ")
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyStatus(raw) {
    var next = Model.parse(raw)
    if (Object.keys(next).length === 0) return
    info = next
    loaded = true
    // Once the real radio state catches up, drop the optimistic value.
    if (desiredRadio !== null && (next.radio === "enabled") === desiredRadio) desiredRadio = null
  }

  function run(argv) {
    if (actionProc.running) return
    busy = true
    lastError = ""
    actionProc.command = argv
    actionProc.running = true
  }

  function toggleRadio() {
    if (busy) return
    var on = !radioOn
    desiredRadio = on
    run(["nmcli", "radio", "wwan", on ? "on" : "off"])
  }

  function connectData() {
    if (!info.profile) return
    run(["nmcli", "--wait", "45", "connection", "up", "id", String(info.profile)])
  }

  function disconnectData() {
    if (!info.device) return
    run(["nmcli", "device", "disconnect", String(info.device)])
  }

  function activateCursor() {
    if (!cursorActive) return
    if (cursorIndex === 0) toggleRadio()
    else if (showDisconnect) disconnectData()
    else if (showConnect) connectData()
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      cursorIndex = 0
      refresh()
    }
  }
  onCursorCountChanged: cursorIndex = Math.min(cursorIndex, cursorCount - 1)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: [root.pluginDir + "/cellular-status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyStatus(text) }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var msg = String(text || "").trim().split("\n")[0] || ""
        if (msg !== "") root.lastError = msg.slice(0, 200)
      }
    }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode === 0) root.lastError = ""
      else root.desiredRadio = null
      root.refresh()
      settleTimer.restart()
    }
  }

  // Modem state keeps moving for a few seconds after an action (enabling,
  // registering, getting an address); look again shortly afterwards.
  Timer { id: settleTimer; interval: 4000; repeat: false; onTriggered: root.refresh() }

  Timer {
    interval: root.opened ? 3000 : root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.icon(root.st, root.info)
    dimmed: root.loaded && !Model.lit(root.st)
    tooltipText: root.opened ? "" : root.tooltipText
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleRadio()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        var delta = dy !== 0 ? dy : dx
        root.cursorIndex = Math.max(0, Math.min(root.cursorCount - 1, root.cursorIndex + delta))
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          id: hero
          width: parent.width
          title: root.titleText
          meta: root.statusText
          detail: root.st === "connected" ? Model.techLabel(root.info.tech) : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: Model.lit(root.st) ? 1.0 : 0.5
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: Model.icon(root.st, root.info)
              color: Model.isProblem(root.st) ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              id: radioSwitch
              visible: root.hasModem
              checked: root.radioOn
              busy: root.busy
              hasCursor: root.cursorActive && root.cursorIndex === 0
              foreground: root.foreground
              onHovered: function(on) { if (on) { root.cursorActive = true; root.cursorIndex = 0 } }
              onToggled: root.toggleRadio()

              PanelToolTip {
                visible: radioSwitch.containsMouse
                text: root.radioOn ? strings.t("turnOff") : strings.t("turnOn")
                fontFamily: root.fontFamily
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: text !== ""
          width: parent.width
          text: root.lastError !== "" ? root.lastError : (root.radioOn || !root.hasModem ? root.hintText : "")
          color: root.lastError !== "" || Model.isProblem(root.st) ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        PanelSeparator {
          visible: details.visible
          foreground: root.foreground
        }

        Column {
          id: details
          visible: root.hasModem
          width: parent.width
          spacing: Style.spacing.labelGap

          InfoPair { label: strings.t("signal"); value: root.signalText }
          InfoPair { label: strings.t("network"); value: root.networkText }
          InfoPair { label: strings.t("ipAddress"); value: String(root.info.ip || "") }
          InfoPair { label: strings.t("dataUsed"); value: root.dataText }
          InfoPair { label: strings.t("apn"); value: root.apnText }
          InfoPair { label: strings.t("modem"); value: Model.shortModel(root.info.model) }
        }

        Button {
          visible: root.hasAction
          width: parent.width
          text: root.showDisconnect ? strings.t("disconnect") : strings.t("connect")
          fontSize: Style.font.bodySmall
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          hasCursor: root.cursorActive && root.cursorIndex === 1
          onClicked: root.showDisconnect ? root.disconnectData() : root.connectData()
          onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = 1 } }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    visible: value !== ""
    width: parent.width
    spacing: Style.space(8)

    InfoText { id: labelText; text: parent.label; opacity: 0.6 }
    Item { width: Math.max(0, parent.width - labelText.implicitWidth - valueText.width - parent.spacing * 2); height: 1 }
    InfoText {
      id: valueText
      text: parent.value
      width: Math.min(implicitWidth, parent.width * 0.62)
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignRight
    }
  }

  component InfoText: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
