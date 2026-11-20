.pragma library

// Pure helpers for the cellular widget: parse cellular-status output and
// derive one status from ModemManager + NetworkManager state. No QML here,
// so it can be exercised from node (see tests/model.test.js).

// Material Design glyphs from the Nerd Font, same family as Wi-Fi's icons.
var ICON_OFF = "󰣼"          // network_strength_off
var ICON_NO_SERVICE = "󰣽"   // network_strength_off_outline
var ICON_SIM_ALERT = "󰒨"    // sim_alert
var ICON_OUTLINE = "󰣾"      // network_strength_outline
var STRENGTH = ["󰣾", "󰣴", "󰣶", "󰣸", "󰣺"]

var MAX_FIELD = 256

function parse(raw) {
  var out = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length && i < 100; i++) {
    var line = lines[i]
    var tab = line.indexOf("\t")
    if (tab <= 0) continue
    var key = line.slice(0, tab)
    if (!/^[a-z_]{1,32}$/.test(key)) continue
    out[key] = line.slice(tab + 1).slice(0, MAX_FIELD)
  }
  return out
}

function signalPercent(info) {
  var n = parseInt(info.signal, 10)
  return isFinite(n) ? Math.max(0, Math.min(100, n)) : 0
}

function strengthIcon(percent) {
  if (percent >= 75) return STRENGTH[4]
  if (percent >= 50) return STRENGTH[3]
  if (percent >= 25) return STRENGTH[2]
  if (percent > 0) return STRENGTH[1]
  return STRENGTH[0]
}

// Collapses everything into one of:
//   off, absent, no-sim, locked, failed, no-service, denied, searching,
//   registered, connecting, connected, unknown
function status(info) {
  if (!info || info.present !== "yes") return "absent"
  if (info.radio === "disabled" || info.state === "disabled" || info.state === "disabling") return "off"
  if (info.state === "failed") return info.failed_reason === "sim-missing" ? "no-sim" : "failed"
  if (info.sim === "no") return "no-sim"
  if (info.state === "locked") return "locked"
  if (info.device_state === "connected" || info.state === "connected") return "connected"
  if (info.registration === "denied") return "denied"
  if (info.registration === "searching") return "searching"
  var registered = info.registration === "home" || info.registration === "roaming"
    || info.state === "registered" || info.state === "connecting"
  if (!registered) {
    if (info.state === "enabling" || info.state === "initializing") return "searching"
    if (info.state === "enabled" || info.state === "searching") return info.registration === "idle" ? "no-service" : "searching"
    return "unknown"
  }
  if (info.state === "connecting" || /^connecting/.test(info.device_state || "")) return "connecting"
  return "registered"
}

function icon(st, info) {
  switch (st) {
    case "absent":
    case "off": return ICON_OFF
    case "no-sim":
    case "locked":
    case "failed":
    case "denied": return ICON_SIM_ALERT
    case "no-service":
    case "unknown": return ICON_NO_SERVICE
    case "searching": return ICON_OUTLINE
    default: return strengthIcon(signalPercent(info))
  }
}

// True when the bar icon should render at full strength rather than dimmed.
function lit(st) {
  return st === "connected"
}

// Translation key for the short status line.
function statusKey(st, info) {
  if (st === "registered" && info.registration === "roaming") return "status.roaming"
  return "status." + st
}

// Translation key for the explanatory hint shown under the hero, or "".
function hintKey(st) {
  switch (st) {
    case "absent": return "hint.absent"
    case "no-sim": return "hint.noSim"
    case "locked": return "hint.locked"
    case "failed": return "hint.failed"
    case "no-service": return "hint.noService"
    case "denied": return "hint.denied"
    case "registered": return "hint.registered"
    default: return ""
  }
}

function isProblem(st) {
  return st === "no-sim" || st === "locked" || st === "failed" || st === "denied" || st === "no-service"
}

// Access technology list from ModemManager ("lte", "umts,hsdpa", "5gnr") to
// a short label.
function techLabel(tech) {
  var t = String(tech || "").toLowerCase()
  if (t === "") return ""
  if (t.indexOf("5gnr") !== -1) return "5G"
  if (t.indexOf("lte") !== -1) return "LTE"
  if (/hspa|hsdpa|hsupa/.test(t)) return "3G+"
  if (/umts|evdo/.test(t)) return "3G"
  if (/edge|gprs|gsm|1xrtt/.test(t)) return "2G"
  return t.split(",")[0].toUpperCase()
}

function carrierName(info) {
  return String(info.operator || info.sim_operator || "")
}

function humanBytes(raw, formatNumber) {
  var n = parseFloat(raw)
  if (!isFinite(n) || n < 0) return ""
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  var decimals = i === 0 || n >= 100 ? 0 : 1
  return (formatNumber ? formatNumber(n, decimals) : n.toFixed(decimals)) + " " + units[i]
}

// "Sierra Wireless EM7455 Qualcomm® Snapdragon™ X7 LTE-A" -> "Sierra Wireless EM7455"
function shortModel(model) {
  var m = String(model || "").trim()
  var cut = m.search(/\s+(Qualcomm|Snapdragon|LTE|\()/)
  return cut > 0 ? m.slice(0, cut) : m
}

// Whether a manual connect makes sense in this state.
function canConnect(st, info) {
  return !!info.profile && (st === "registered" || st === "connecting")
}

function canDisconnect(st, info) {
  return !!info.device && (st === "connected" || st === "connecting")
}
