import Foundation

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
        let hours = Int(remaining / 3600)
        let minutes = Int(remaining.truncatingRemainder(dividingBy: 3600) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
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

// MARK: - Usage Stats (통합)

struct UsageStats: Equatable {
    var fiveHourTokens = TokenUsage()
    var oneWeekTokens = TokenUsage()
    var rateLimits = RateLimits()
    var contextInfo = ContextInfo()
    var modelUsages: [ModelUsage] = []
    var hourlyData: [HourlyTokenData] = []
}
