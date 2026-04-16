import Foundation

// MARK: - Provider

enum Provider: String, CaseIterable, Codable {
    case claude
    case codex
    case both

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .both: "Both"
        }
    }
}

// MARK: - Claude Environment (멀티 홈 디렉토리 지원)

/// 하나의 Claude Code 환경 (예: ~/.claude, ~/.claude-baroitda)을 나타냄
struct ClaudeEnvironment: Identifiable, Equatable, Codable, Hashable {
    let id: String           // 경로 기반 안정 해시
    let folderName: String   // ".claude", ".claude-baroitda"
    let shortName: String    // "default", "baroitda"
    let path: URL            // ~/.claude-baroitda 의 URL
    var alias: String?       // 사용자 별칭 (nil이면 shortName 사용)
    var enabled: Bool = true
    var accountKey: String?  // OAuth 토큰 SHA-256 앞 16자 (계정 중복 제거용)

    var displayName: String { alias?.isEmpty == false ? alias! : shortName }
    var isDefault: Bool { folderName == ".claude" }

    private enum CodingKeys: String, CodingKey { case id, folderName, shortName, path, alias, enabled, accountKey }
}

/// 사용자가 환경별로 재정의한 설정 (UserDefaults에 저장)
struct EnvironmentOverride: Codable, Equatable {
    var alias: String?
    var enabled: Bool

    init(alias: String? = nil, enabled: Bool = true) {
        self.alias = alias
        self.enabled = enabled
    }
}

// MARK: - Menu Bar Environment Mode

enum MenuBarEnvMode: String, CaseIterable, Codable {
    case aggregated     // 전체 합산 한 줄
    case perEnvironment // 환경별 나열 (def 45% · bar 12%)
    case primary        // 특정 환경만 (id 저장은 별도 필드)
}

// MARK: - Account Rate Limit (계정 단위 rate limit)

/// 하나의 Anthropic 계정에 대한 Rate Limit 정보.
/// 여러 환경(`~/.claude-*`)이 같은 계정을 공유할 수 있으므로 환경 목록을 함께 보관.
struct AccountRateLimit: Identifiable, Equatable {
    let id: String                  // accountKey (SHA-256 prefix)
    let environmentIDs: [String]    // 이 계정을 쓰는 환경들의 id (stats 합산용)
    let environmentNames: [String]  // 이 계정을 쓰는 환경들의 displayName (표시용)
    var rateLimits: RateLimits
}

// MARK: - Session State

enum SessionState: String, Codable, CaseIterable {
    case active
    case waiting
    case idle
    case compacting

    var label: String {
        L.stateLabel(self)
    }

    var priority: Int {
        switch self {
        case .active: 3
        case .waiting: 2
        case .compacting: 1
        case .idle: 0
        }
    }

    var emoji: String {
        switch self {
        case .active: "⚡"
        case .waiting: "⏳"
        case .idle: "💤"
        case .compacting: "🧹"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .active: "bolt.circle.fill"
        case .waiting: "clock.circle.fill"
        case .idle: "moon.circle.fill"
        case .compacting: "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}

// MARK: - Session Source (IDE/Terminal)

enum SessionSource: String, Codable {
    case terminal
    case iterm
    case ghostty
    case warp
    case wezterm
    case vscode
    case cursor
    case xcode
    case zed
    case jetbrains
    case unknown

    var label: String {
        switch self {
        case .terminal: "Terminal"
        case .iterm: "iTerm2"
        case .ghostty: "Ghostty"
        case .warp: "Warp"
        case .wezterm: "WezTerm"
        case .vscode: "VS Code"
        case .cursor: "Cursor"
        case .xcode: "Xcode"
        case .zed: "Zed"
        case .jetbrains: "JetBrains"
        case .unknown: "Terminal"
        }
    }
}

// MARK: - Claude Session

struct ClaudeSession: Identifiable, Equatable {
    let id: String
    let pid: Int32
    let workingDirectory: String
    let startedAt: Date
    var state: SessionState
    var source: SessionSource
    var lastActivity: Date
    var toolCallCount: Int
    var lastTool: String?
    var toolCounts: [String: Int] = [:]
    var modelName: String?

    var projectName: String {
        URL(fileURLWithPath: workingDirectory).lastPathComponent
    }

    var timeSinceActivity: String {
        let interval = Date().timeIntervalSince(lastActivity)
        if interval < 10 { return L.justNow }
        if interval < 60 { return L.secondsAgo(Int(interval)) }
        if interval < 3600 { return L.minutesAgo(Int(interval / 60)) }
        return L.hoursAgo(Int(interval / 3600))
    }
}

// MARK: - Token Usage

struct TokenUsage: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var requestCount: Int = 0

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    /// Opus 가격 기준 추정 비용
    var estimatedCostUSD: Double {
        (Double(inputTokens) * 15.0
            + Double(outputTokens) * 75.0
            + Double(cacheCreationTokens) * 18.75
            + Double(cacheReadTokens) * 1.50) / 1_000_000.0
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    static func formatCost(_ usd: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        if usd >= 100 {
            formatter.maximumFractionDigits = 0
        } else if usd >= 1 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        } else {
            formatter.minimumFractionDigits = 3
            formatter.maximumFractionDigits = 3
        }
        return "$" + (formatter.string(from: NSNumber(value: usd)) ?? String(format: "%.2f", usd))
    }
}

// MARK: - Rate Limits (from API)

struct RateLimits: Equatable {
    var isLoaded: Bool = false
    var fiveHourPercent: Double = 0
    var weeklyPercent: Double = 0
    var fiveHourResetsAt: Date?
    var weeklyResetsAt: Date?
    var sonnetWeeklyPercent: Double?
    var sonnetWeeklyResetsAt: Date?
    var opusWeeklyPercent: Double?
    var opusWeeklyResetsAt: Date?
    var extraUsageLoaded: Bool = false  // API에서 extra_usage 필드를 받은 경우만 true
    var extraUsageEnabled: Bool = false
    var extraUsageUsed: Double?      // USD
    var extraUsageLimit: Double?     // USD
    var extraUsageUtilization: Double?  // 0~100
    var extraUsageResetsAt: Date?

    var fiveHourResetString: String {
        guard let date = fiveHourResetsAt else { return "-" }
        return formatTimeRemaining(until: date)
    }

    var weeklyResetString: String {
        guard let date = weeklyResetsAt else { return "-" }
        return formatTimeRemaining(until: date)
    }

    private func formatTimeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSince(Date())
        if remaining <= 0 { return "now" }
        let totalHours = Int(remaining / 3600)
        let minutes = Int(remaining.truncatingRemainder(dividingBy: 3600) / 60)
        if UserDefaults.standard.bool(forKey: "showDaysFormat") && totalHours >= 24 {
            let days = totalHours / 24
            let hours = totalHours % 24
            if hours > 0 { return "\(days)d \(hours)h" }
            return "\(days)d"
        }
        if totalHours > 0 { return "\(totalHours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Context Info

struct ContextInfo: Equatable {
    var currentInputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var maxContextTokens: Int = 1_000_000

    var usedTokens: Int {
        currentInputTokens + cacheReadTokens
    }

    var usagePercent: Double {
        guard maxContextTokens > 0 else { return 0 }
        return min(Double(usedTokens) / Double(maxContextTokens), 1.0)
    }
}

// MARK: - Model Usage (모델별 사용량)

struct ModelUsage: Equatable, Identifiable {
    var id: String { modelName }
    let modelName: String
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
    }

    var estimatedCostUSD: Double {
        let isOpus = modelName.contains("opus")
        let inputPrice: Double = isOpus ? 15.0 : 3.0
        let outputPrice: Double = isOpus ? 75.0 : 15.0
        let cacheWritePrice: Double = isOpus ? 18.75 : 3.75
        let cacheReadPrice: Double = isOpus ? 1.50 : 0.30
        return (Double(inputTokens) * inputPrice
            + Double(outputTokens) * outputPrice
            + Double(cacheCreationTokens) * cacheWritePrice
            + Double(cacheReadTokens) * cacheReadPrice) / 1_000_000.0
    }

    var shortName: String {
        if modelName.contains("opus") { return "Opus" }
        if modelName.contains("sonnet") { return "Sonnet" }
        if modelName.contains("haiku") { return "Haiku" }
        return String(modelName.prefix(12))
    }
}

// MARK: - Hourly Token Data (차트용)

struct HourlyTokenData: Identifiable, Equatable {
    let id: Date
    var hour: Date { id }
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var requestCount: Int = 0

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    var estimatedCostUSD: Double {
        (Double(inputTokens) * 15.0
            + Double(outputTokens) * 75.0
            + Double(cacheCreationTokens) * 18.75
            + Double(cacheReadTokens) * 1.50) / 1_000_000.0
    }
}

// MARK: - Codex Rate Limits

struct CodexRateLimits: Equatable {
    var usedPercent: Double = 0       // 0.0 ~ 100.0
    var windowMinutes: Int = 10080    // 기본 1주일
    var resetsAt: Date? = nil
    var planType: String = ""
    var isLoaded: Bool = false

    var resetString: String {
        guard let resetsAt else { return "—" }
        let diff = resetsAt.timeIntervalSinceNow
        guard diff > 0 else { return "—" }
        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Codex Token Usage (세션 합산)

struct CodexTokenUsage: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cachedInputTokens: Int = 0
    var requestCount: Int = 0

    var totalTokens: Int {
        inputTokens + outputTokens + cachedInputTokens
    }

    /// 모델별 단가 미적용 추정치 (gpt-4.1 기준: input $2/1M, output $8/1M, cached $0.5/1M)
    var estimatedCostUSD: Double {
        (Double(inputTokens) * 2.0
            + Double(outputTokens) * 8.0
            + Double(cachedInputTokens) * 0.5) / 1_000_000.0
    }
}

// MARK: - Usage Stats (통합)

struct UsageStats: Equatable {
    var fiveHourTokens = TokenUsage()
    var oneWeekTokens = TokenUsage()
    var rateLimits = RateLimits()
    var contextInfo = ContextInfo()
    var modelUsages: [ModelUsage] = []
    var hourlyData: [HourlyTokenData] = []         // 24시간 (라인차트)
    var weeklyHourlyData: [HourlyTokenData] = []   // 7일 (히트맵)

    // Codex
    var codexFiveHourTokens = CodexTokenUsage()
    var codexOneWeekTokens = CodexTokenUsage()
    var codexRateLimits = CodexRateLimits()
    var codexHourlyData: [HourlyTokenData] = []         // 24시간 (라인차트)
    var codexWeeklyHourlyData: [HourlyTokenData] = []   // 7일 (히트맵)

    // 전체 누적 (마일스톤용)
    var allTimeTokens: Int = 0
    var allTimeCostUSD: Double = 0
}

// MARK: - Notification History

struct NotificationHistoryItem: Codable, Identifiable, Equatable {
    let id: String
    let type: HistoryItemType
    let title: String
    let body: String
    let date: Date

    enum HistoryItemType: String, Codable {
        case milestone
        case weeklyReport
        case usageAlert
    }
}

// MARK: - Weekly Report

struct WeeklyReport: Equatable {
    var weekStart: Date = Date()       // 지난주 월요일
    var totalTokens: Int = 0
    var totalCostUSD: Double = 0
    var prevWeekTokens: Int = 0
    var prevWeekCostUSD: Double = 0
    var busiestDay: String = ""        // "월", "화" 등
    var busiestDayTokens: Int = 0
    var dailyTokens: [String: Int] = [:] // "월"~"일"

    var tokenDelta: Int { totalTokens - prevWeekTokens }
    var costDelta: Double { totalCostUSD - prevWeekCostUSD }
}
