import Foundation

// Passive provider boundary, shared by the app and the independent offline harness.
enum PanelAction: Equatable {
    case none, refresh, height(Double), newClaude(String), renewClaude
}

enum PanelPolicy {
    static func accept(_ json: String, exit: Int32) -> [String: Any]? {
        guard exit == 0, let data = json.data(using: .utf8),
              let feed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accounts = feed["accounts"] as? [[String: Any]], feed["fleet"] is [String: Any],
              accounts.allSatisfy({ $0["provider"] == nil || $0["provider"] as? String == "claude" }) else { return nil }
        return feed
    }

    static func codex(_ feed: [String: Any]) -> [String: Any] {
        (feed["providers"] as? [String: Any])?["codex"] as? [String: Any] ?? [:]
    }

    static func codexLive(_ feed: [String: Any]) -> Int {
        let provider = codex(feed)
        var identities = Set<String>()
        for kind in ["sessions", "runs"] {
            for record in provider[kind] as? [[String: Any]] ?? [] {
                guard (record["provider"] as? String ?? "codex") == "codex",
                      record["alive"] as? Bool == true,
                      ["starting", "running", "parked", "busy", "idle", "approval", "limited", "unknown"].contains(record["status"] as? String ?? record["state"] as? String ?? ""),
                      let host = record["host"] as? String, let home = record["home"] as? String else { continue }
                let id = record["thread_id"] as? String ?? record["id"] as? String
                if let id = id { identities.insert(host + "/" + home + "/" + id) }
            }
        }
        return identities.count
    }

    static func title(_ feed: [String: Any]) -> String {
        let accounts = (feed["accounts"] as? [[String: Any]] ?? []).filter { ($0["provider"] as? String ?? "claude") == "claude" }
        let live = accounts.reduce(0) { $0 + max(0, ($1["live"] as? Int) ?? 0) } + codexLive(feed)
        let fleet = feed["fleet"] as? [String: Any] ?? [:]
        func left(_ key: String) -> Int? {
            guard let window = fleet[key] as? [String: Any],
                  let remaining = window["remaining"] as? Double, let of = window["of"] as? Double,
                  remaining.isFinite, of.isFinite, of > 0 else { return nil }
            return Int(max(0, min(100, remaining / of * 100)).rounded())
        }
        let flag = accounts.contains { $0["expiring"] as? Bool == true } ? " ⚠" : ""
        let openai = codexTitle(feed)
        switch (left("fable"), left("week")) {
        case let (f?, w?): return " \(live) · F\(f)% · W\(w)%\(flag)\(openai)"
        case let (nil, w?): return " \(live) · W\(w)%\(flag)\(openai)"
        default: return " \(live)\(openai)"
        }
    }

    // The Codex homes in the title (lane U, continue 2, 2026-10-04; the owner: "there is a question mark next to the O"):
    // the homes' week left as a number he can act on. One figure when the homes agree, "low/high" when they differ; a
    // reading older than the provider's reading_max_age says "stale"; no week reading at all says "unknown". Never a
    // bare glyph for "unknown". Codex quota stays in its own unit (percent of each home's week), never a fleet point.
    static func codexTitle(_ feed: [String: Any]) -> String {
        let provider = codex(feed)
        let accounts = (provider["accounts"] as? [[String: Any]] ?? []).filter { ($0["provider"] as? String ?? "codex") == "codex" }
        if accounts.isEmpty { return "" }
        let maxAge = (provider["reading_max_age"] as? Double) ?? 900
        var lefts: [Int] = []
        var stale = false
        for account in accounts {
            // the account's own quota scope (limit_id "codex" or unnamed); a named model scope is not the home's week
            let scopes = (account["scopes"] as? [[String: Any]] ?? []).filter { ($0["normal_model_slug"] as? String ?? "").isEmpty }
            for scope in scopes {
                for window in scope["windows"] as? [[String: Any]] ?? [] {
                    let isWeek = (window["name"] as? String) == "week" || (window["window_minutes"] as? Double) == 10080
                    guard isWeek, let left = window["left_percent"] as? Double, left.isFinite else { continue }
                    lefts.append(Int(max(0, min(100, left)).rounded()))
                    let age = scope["observed_age"] as? Double
                    if scope["stale"] as? Bool == true || age == nil || age! > maxAge { stale = true }
                }
            }
        }
        guard let low = lefts.min(), let high = lefts.max() else { return " · O unknown" }
        let figure = low == high ? "\(low)%" : "\(low)/\(high)%"
        return " · O\(figure)" + (stale ? " stale" : "")
    }

    static func action(_ body: [String: Any], feed: [String: Any]) -> PanelAction {
        let action = body["action"] as? String ?? ""
        let arg = body["arg"] as? String ?? ""
        if action == "refresh" { return .refresh }
        if action == "height", let value = Double(arg), value.isFinite { return .height(value) }
        // This release has no Codex launch, move, fallback, login or other action adapter.
        guard body["provider"] == nil || body["provider"] as? String == "claude" else { return .none }
        let accounts = (feed["accounts"] as? [[String: Any]] ?? []).filter { ($0["provider"] as? String ?? "claude") == "claude" }
        let known = accounts.contains { $0["email"] as? String == arg }
        switch action {
        case "new_session" where arg.isEmpty || known: return .newClaude(arg)
        case "renew" where arg.isEmpty: return .renewClaude
        default: return .none
        }
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func claudeCommand(_ account: String) -> String {
        account.isEmpty ? "claude" : "claude @" + shellQuote(account)
    }
}
