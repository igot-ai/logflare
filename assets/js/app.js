import "../css/app.scss"
import { Socket } from "phoenix"
import "@babel/polyfill"
import "bootstrap"
import ClipboardJS from "clipboard"
import * as Dashboard from "./dashboard"
import * as Source from "./source"
import * as Logs from "./logs"
import { LogEventsChart } from "./source_log_chart.jsx"
import LiveSocket from "phoenix_live_view"
import LiveReact, { initLiveReact } from "phoenix_live_react"
import sourceLiveViewHooks from "./source_lv_hooks"

let csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content")

const liveReactHooks = { LiveReact }

window.Components = { LogEventsChart }
window.Dashboard = Dashboard
window.Logs = Logs
window.Source = Source
window.ClipboardJS = ClipboardJS

document.addEventListener("DOMContentLoaded", e => {
  initLiveReact()
})

const hooks = Object.assign(liveReactHooks, sourceLiveViewHooks)

let liveSocket = new LiveSocket("/live", Socket, {
    hooks,
    params: { _csrf_token: csrfToken },
})

liveSocket.connect()
