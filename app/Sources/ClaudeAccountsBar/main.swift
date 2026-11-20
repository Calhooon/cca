import Cocoa
import WebKit

// Claude Accounts — macOS menu bar app.
// A native status item with hover-to-open popover hosting a WKWebView that
// renders panel.html. Data comes from `cca panel` (one JSON blob). The app
// never talks to Anthropic; cca reads local files and the Keychain.

let HOME = FileManager.default.homeDirectoryForCurrentUser.path
// lane U (2026-10-04): a dev build runs from a worktree beside the installed app. CCA_APP_ROOT names the tree whose
// bin/cca and app/web/panel.html this process uses (the installed app sets nothing and reads the live install);
// CCA_APP_DEV=1 marks the title and the icon so the owner can tell the two apart. app/dev.sh sets both.
let ENV = ProcessInfo.processInfo.environment
let APP_ROOT = ENV["CCA_APP_ROOT"].map { ($0 as NSString).expandingTildeInPath } ?? (Bundle.main.object(forInfoDictionaryKey: "CCAAppRoot") as? String) ?? (HOME + "/cca")
let DEV = ENV["CCA_APP_DEV"] == "1"
let CCA_PATH = APP_ROOT + "/bin/cca"
let PANEL_HTML = URL(fileURLWithPath: APP_ROOT + "/app/web/panel.html")
let PYTHON = "/usr/bin/python3"
let PANEL_WIDTH: CGFloat = 440
let REFRESH_SECONDS: TimeInterval = 12
let LOG_PATH = HOME + "/Library/Logs/ClaudeAccounts.log"

// #59: the build stamp app/install.sh writes into Info.plist, and this process's start. Every `cca panel` call
// carries them (CCA_APP_STAMP), so cca can say which code the running app is against the sources as they are now.
let INFO = Bundle.main.infoDictionary ?? [:]
let BUILD_COMMIT = INFO["CCABuildCommit"] as? String ?? "unknown"
let BUILD_AT = INFO["CCABuildAt"] as? String ?? "unknown"
let SOURCE_HASH = INFO["CCASourceHash"] as? String ?? "unknown"
let STARTED_AT = Date().timeIntervalSince1970
var PANEL_LOADED_AT: Double = 0

func appStamp() -> String {
    let o: [String: Any] = ["pid": Int(ProcessInfo.processInfo.processIdentifier), "commit": BUILD_COMMIT,
                            "built_at": BUILD_AT, "source_hash": SOURCE_HASH, "started_at": STARTED_AT,
                            "panel_loaded_at": PANEL_LOADED_AT]
    if let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) { return s }
    return "{}"
}

func panelModified() -> Date? {
    return (try? FileManager.default.attributesOfItem(atPath: PANEL_HTML.path))?[.modificationDate] as? Date
}

// A failed `cca panel` used to vanish: stderr dropped, title stuck on "…",
// and the web view fell back to its sample data. Now stderr lands in the
// log and the panel is told, so the board says what happened.
func log(_ line: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    let text = "\(stamp) \(line)\n"
    if let h = FileHandle(forWritingAtPath: LOG_PATH) {
        h.seekToEndOfFile(); h.write(text.data(using: .utf8)!); h.closeFile()
    } else {
        try? text.write(toFile: LOG_PATH, atomically: true, encoding: .utf8)
    }
}

func runProcess(_ launch: String, _ args: [String], completion: @escaping (String, String, Int32) -> Void) {
    let stamp = appStamp()   // read on the caller's (main) thread
    DispatchQueue.global(qos: .userInitiated).async {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + HOME + "/.local/bin"
        env["CCA_APP_STAMP"] = stamp
        p.environment = env
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do { try p.run() } catch {
            DispatchQueue.main.async { completion("", "could not start \(launch): \(error.localizedDescription)", -1) }
            return
        }
        // drain both pipes before waiting so a chatty stderr cannot deadlock
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        group.enter(); DispatchQueue.global().async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); DispatchQueue.global().async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.wait()
        p.waitUntilExit()
        let o = String(data: outData, encoding: .utf8) ?? ""
        let e = String(data: errData, encoding: .utf8) ?? ""
        DispatchQueue.main.async { completion(o, e, p.terminationStatus) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSPopoverDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()
    var web: WKWebView!
    var globalMon: Any?
    var localMon: Any?
    var closeWork: DispatchWorkItem?
    var pinned = false
    var lastJSON = "null"
    var lastError: String? = nil
    var everLoaded = false
    var refreshing = false
    var loaded = false
    var qaWindow: NSWindow?
    var panelMtime: Date?
    // lane U (2026-10-04): a changed panel.html is reloaded only while the popover is closed; a reload while the
    // owner reads would put the page back at its top (a reload is the third way the scroll position died)
    var reloadPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let b = statusItem.button {
            if let img = NSImage(systemSymbolName: DEV ? "hammer" : "gauge.medium", accessibilityDescription: DEV ? "Claude accounts (dev)" : "Claude accounts") {
                img.isTemplate = true
                b.image = img
                b.imagePosition = .imageLeading
            }
            b.title = " …"
            b.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            b.target = self
            b.action = #selector(togglePin)
        }

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "cca")
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: PANEL_WIDTH, height: 600), configuration: cfg)
        web.navigationDelegate = self
        if web.responds(to: Selector(("_setDrawsBackground:"))) {
            web.setValue(false, forKey: "drawsBackground")
        }
        loadPanel()

        let qa = ProcessInfo.processInfo.environment["CCA_QA"] == "1"
        if qa {
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: PANEL_WIDTH, height: 700),
                               styleMask: [.titled, .closable], backing: .buffered, defer: false)
            win.title = DEV ? "Claude Accounts (dev, QA)" : "Claude Accounts (QA)"
            win.contentView = web
            win.level = .floating
            win.setFrameTopLeftPoint(NSPoint(x: 60, y: (NSScreen.main?.frame.height ?? 900) - 40))
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            qaWindow = win
        } else {
            let vc = NSViewController()
            vc.view = web
            popover.contentViewController = vc
            popover.contentSize = NSSize(width: PANEL_WIDTH, height: 600)
            popover.behavior = .transient
            popover.animates = false
            popover.delegate = self
        }

        let tick: (NSEvent?) -> Void = { [weak self] _ in self?.hoverTick() }
        globalMon = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { tick($0) }
        localMon = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { tick($0); return $0 }

        refresh()
        Timer.scheduledTimer(withTimeInterval: REFRESH_SECONDS, repeats: true) { [weak self] _ in self?.refresh() }
    }

    // #59: the page is read from the repo; a landing that changes it is shown at the next refresh, no restart needed
    func loadPanel() {
        panelMtime = panelModified()
        loaded = false
        PANEL_LOADED_AT = Date().timeIntervalSince1970
        web.loadFileURL(PANEL_HTML, allowingReadAccessTo: PANEL_HTML.deletingLastPathComponent())
    }

    // MARK: hover

    func buttonScreenFrame() -> NSRect? {
        guard let b = statusItem.button, let w = b.window else { return nil }
        return w.convertToScreen(b.convert(b.bounds, to: nil))
    }
    func popoverScreenFrame() -> NSRect? {
        return popover.contentViewController?.view.window?.frame
    }
    func hoverTick() {
        let p = NSEvent.mouseLocation
        let overBtn = buttonScreenFrame()?.contains(p) ?? false
        let overPop = popover.isShown ? (popoverScreenFrame()?.insetBy(dx: -10, dy: -10).contains(p) ?? false) : false
        if overBtn {
            closeWork?.cancel()
            if !popover.isShown { showPopover() }
        } else if popover.isShown && !pinned {
            if overPop { closeWork?.cancel() } else { scheduleClose() }
        }
    }
    func scheduleClose() {
        closeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let p = NSEvent.mouseLocation
            let overBtn = self.buttonScreenFrame()?.contains(p) ?? false
            let overPop = self.popoverScreenFrame()?.insetBy(dx: -10, dy: -10).contains(p) ?? false
            if !overBtn && !overPop && !self.pinned { self.popover.performClose(nil) }
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: work)
    }
    func showPopover() {
        guard let b = statusItem.button else { return }
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        refresh()
    }
    @objc func togglePin() {
        if popover.isShown && pinned {
            pinned = false
            popover.performClose(nil)
        } else {
            pinned = true
            if !popover.isShown { showPopover() }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: data

    func webViewDidFinishNavigation(_ webView: WKWebView, navigation: WKNavigation!) {}
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        inject()
        if let v = ProcessInfo.processInfo.environment["CCA_QA_VIEW"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.web.evaluateJavaScript("show('\(v)')", completionHandler: nil)
            }
        }
    }

    func refresh() {
        // one at a time: on a slow boot the 12s timer must not pile up python processes
        if refreshing { return }
        if let m = panelModified(), let l = panelMtime, m > l {
            // the QA window is always open, so it takes the new page at once; the popover waits until it is closed
            if popover.isShown && qaWindow == nil { reloadPending = true } else { loadPanel() }
        }
        refreshing = true
        // the board reads real numbers only while someone looks at it: --read lets cca read what is stale (never on the 12s timer alone)
        runProcess(PYTHON, [CCA_PATH, "panel"] + (popover.isShown || qaWindow != nil ? ["--read"] : [])) { [weak self] out, err, rc in
            guard let self = self else { return }
            self.refreshing = false
            let json = out.trimmingCharacters(in: .whitespacesAndNewlines)
            if let feed = PanelPolicy.accept(json, exit: rc) {
                self.lastJSON = json
                self.lastError = nil
                self.everLoaded = true
                self.statusItem.button?.title = (DEV ? " dev" : "") + PanelPolicy.title(feed)
            } else {
                let tail = String(err.suffix(300)).trimmingCharacters(in: .whitespacesAndNewlines)
                let msg = "cca panel exit \(rc)" + (tail.isEmpty ? " with no output" : ": " + tail)
                self.lastError = msg
                log(msg)
                if !self.everLoaded { self.statusItem.button?.title = " ⚠" }
            }
            if self.loaded { self.inject() }
        }
    }
    func statusJSON() -> String {
        var o: [String: Any] = ["ok": lastError == nil, "at": Date().timeIntervalSince1970]
        if let e = lastError { o["error"] = e }
        if let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) { return s }
        return "{\"ok\":false}"
    }
    // the tallest the popover may be on this screen: the visible frame already
    // leaves out the menu bar and the Dock, the rest is the popover's own chrome.
    // The page gets it as window.CCA_MAX so it can scroll its list past that.
    func ceiling() -> Double {
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        return max(360, Double(screen?.visibleFrame.height ?? 920) - 24)
    }
    func inject() {
        let js = "window.CCA = \(lastJSON); window.CCA_STATUS = \(statusJSON()); window.CCA_MAX = \(Int(ceiling())); window.CCA_DEV = \(DEV ? "true" : "false"); if (window.ccaRefresh) window.ccaRefresh();"
        web.evaluateJavaScript(js, completionHandler: nil)
    }
    // MARK: actions from the web UI

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let feed = PanelPolicy.accept(lastJSON, exit: 0) else {
            if (message.body as? [String: Any])?["action"] as? String == "refresh" { refresh() }
            return
        }
        switch PanelPolicy.action(body, feed: feed) {
        case .height(let h):
            let clamped = max(360, min(ceiling(), h))
            if let win = qaWindow {
                // size the content area, not the frame, so the title bar does not eat the bottom
                var f = win.frame
                let top = f.origin.y + f.size.height
                let fr = win.frameRect(forContentRect: NSRect(x: 0, y: 0, width: PANEL_WIDTH, height: clamped))
                f.size.height = fr.size.height
                f.origin.y = top - fr.size.height
                win.setFrame(f, display: true)
            } else {
                popover.contentSize = NSSize(width: PANEL_WIDTH, height: clamped)
            }
        case .newClaude(let account):
            terminal(PanelPolicy.claudeCommand(account))
            closePopover()
        case .renewClaude:
            terminal("cca refresh --all")
            closePopover()
        case .refresh:
            refresh()
        case .none:
            break
        }
    }
    func closePopover() {
        pinned = false
        popover.performClose(nil)
    }
    func popoverDidClose(_ notification: Notification) {
        if reloadPending { reloadPending = false; loadPanel() }
    }
    func terminal(_ cmd: String) {
        let safe = cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(safe)\"\nend tell"
        let osa = Process()
        osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osa.arguments = ["-e", script]
        try? osa.run()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
