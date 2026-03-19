import Foundation

// MARK: - Localized Strings

enum L {
    /// UserDefaults에서 직접 읽어 actor isolation 불필요
    static var lang: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "language"),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        let preferred = Locale.preferredLanguages.first ?? ""
        return preferred.hasPrefix("ko") ? .korean : .english
    }

    // Header
    static var appTitle: String { "DuckBar" }
    static var refresh: String { lang == .korean ? "새로고침" : "Refresh" }

    // Empty state
    static var noActiveSessions: String { lang == .korean ? "활성 세션 없음" : "No active sessions" }

    // Session states
    static func stateLabel(_ state: SessionState) -> String {
        switch (state, lang) {
        case (.active, .korean): "활성"
        case (.active, .english): "Active"
        case (.waiting, .korean): "대기"
        case (.waiting, .english): "Waiting"
        case (.idle, .korean): "유휴"
        case (.idle, .english): "Idle"
        case (.compacting, .korean): "압축"
        case (.compacting, .english): "Compacting"
        }
    }

    // Time
    static var justNow: String { lang == .korean ? "방금" : "just now" }
    static func secondsAgo(_ s: Int) -> String { lang == .korean ? "\(s)초 전" : "\(s)s ago" }
    static func minutesAgo(_ m: Int) -> String { lang == .korean ? "\(m)분 전" : "\(m)m ago" }
    static func hoursAgo(_ h: Int) -> String { lang == .korean ? "\(h)시간 전" : "\(h)h ago" }

    // Sections
    static var rateLimits: String { lang == .korean ? "사용 한도" : "Rate Limits" }
    static var fiveHourWindow: String { lang == .korean ? "5시간" : "5h Window" }
    static var oneWeekWindow: String { lang == .korean ? "1주일" : "1w Window" }
    static var context: String { lang == .korean ? "컨텍스트" : "Context" }
    static var cacheHit: String { lang == .korean ? "캐시 적중" : "Cache Hit" }
    static var requests: String { lang == .korean ? "요청" : "reqs" }
    static var weekly: String { lang == .korean ? "주간" : "weekly" }

    // Token labels
    static var tokenIn: String { "In" }
    static var tokenOut: String { "Out" }
    static var tokenCacheWrite: String { "C.Wr" }
    static var tokenCacheRead: String { "C.Rd" }

    // Model usage
    static var modelUsage: String { lang == .korean ? "모델별 사용량" : "Model Usage" }
    static var noData: String { "—" }
    static var tools: String { lang == .korean ? "도구" : "Tools" }
    static var popoverSize: String { lang == .korean ? "팝오버 크기" : "Popover Size" }

    // Menu
    static var settings: String { lang == .korean ? "설정" : "Settings" }
    static var quit: String { lang == .korean ? "종료" : "Quit" }

    // Context menu
    static var about: String { lang == .korean ? "앱 정보" : "About" }
    static var help: String { lang == .korean ? "도움말" : "Help" }

    // Settings view
    static var language: String { lang == .korean ? "언어" : "Language" }
    static var statusBarDisplay: String { lang == .korean ? "상태바 표시 항목" : "Status Bar Display" }
    static var done: String { lang == .korean ? "완료" : "Done" }
    static var launchAtLogin: String { lang == .korean ? "시스템 시작 시 실행" : "Launch at Login" }
    static var refreshInterval: String { lang == .korean ? "데이터 갱신 주기" : "Refresh Interval" }
    static var hotkey: String { lang == .korean ? "단축키" : "Hotkey" }
    static var hotkeyRecord: String { lang == .korean ? "키를 누르세요..." : "Press a key..." }

    // Chart
    static var tokenChart: String { lang == .korean ? "토큰 (24시간)" : "Tokens (24h)" }
    static var costChart: String { lang == .korean ? "비용 (24시간)" : "Cost (24h)" }
    static var chart: String { lang == .korean ? "차트" : "Chart" }
}
