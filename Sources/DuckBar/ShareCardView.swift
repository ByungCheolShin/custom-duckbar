import SwiftUI
import Charts

// MARK: - 공유 카드 뷰

struct ShareCardView: View {
    let stats: UsageStats
    var chartTab: String = "heatmap"  // "line" or "heatmap"
    var provider: Provider = .claude

    private let cardWidth: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().background(Color.white.opacity(0.15))
            rateLimitSection
            Divider().background(Color.white.opacity(0.15))
            tokenSection
            if !stats.modelUsages.isEmpty && provider != .codex {
                Divider().background(Color.white.opacity(0.15))
                modelSection
            }
            if provider != .codex {
                Divider().background(Color.white.opacity(0.15))
                contextSection
            }
            Divider().background(Color.white.opacity(0.15))
            if chartTab == "line" {
                lineChartSection
            } else {
                heatmapSection
            }
            footerSection
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Group {
                if let nsImage = Bundle.main.image(forResource: "duck_icon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Text("🦆")
                        .font(.system(size: 22))
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("DuckBar")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Text(currentDateString)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var statusBadge: some View {
        let (pct, label): (Double, String) = {
            switch provider {
            case .codex:
                let rl = stats.codexRateLimits
                let p = rl.isLoaded ? rl.usedPercent : 0
                return (p, rl.isLoaded ? "\(Int(p))%" : "—")
            default:
                let rl = stats.rateLimits
                let p = rl.isLoaded ? rl.fiveHourPercent : 0
                return (p, rl.isLoaded ? "\(Int(p))%" : "—")
            }
        }()
        let color: Color = pct >= 80 ? .red : pct >= 50 ? .orange : .green
        let prefix = provider == .codex ? "1w" : "5h"
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(prefix) \(label)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Rate Limits

    private var rateLimitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RATE LIMITS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            switch provider {
            case .codex:
                let crl = stats.codexRateLimits
                cardProgressRow(
                    label: "1w",
                    value: crl.isLoaded ? crl.usedPercent / 100 : 0,
                    text: crl.isLoaded ? "\(Int(crl.usedPercent))%" : "—",
                    sub: crl.isLoaded ? "↻ \(crl.resetString)" : "",
                    color: progressColor(crl.usedPercent)
                )
            case .both:
                let rl = stats.rateLimits
                let crl = stats.codexRateLimits
                cardProgressRow(label: "C 5h",
                    value: rl.isLoaded ? rl.fiveHourPercent / 100 : 0,
                    text: rl.isLoaded ? "\(Int(rl.fiveHourPercent))%" : "—",
                    sub: rl.isLoaded ? "↻ \(rl.fiveHourResetString)" : "",
                    color: progressColor(rl.fiveHourPercent))
                cardProgressRow(label: "C 1w",
                    value: rl.isLoaded ? rl.weeklyPercent / 100 : 0,
                    text: rl.isLoaded ? "\(Int(rl.weeklyPercent))%" : "—",
                    sub: rl.isLoaded ? "↻ \(rl.weeklyResetString)" : "",
                    color: progressColor(rl.weeklyPercent))
                cardProgressRow(label: "X 1w",
                    value: crl.isLoaded ? crl.usedPercent / 100 : 0,
                    text: crl.isLoaded ? "\(Int(crl.usedPercent))%" : "—",
                    sub: crl.isLoaded ? "↻ \(crl.resetString)" : "",
                    color: progressColor(crl.usedPercent))
            default:
                let rl = stats.rateLimits
                cardProgressRow(label: "5h",
                    value: rl.isLoaded ? rl.fiveHourPercent / 100 : 0,
                    text: rl.isLoaded ? "\(Int(rl.fiveHourPercent))%" : "—",
                    sub: rl.isLoaded ? "↻ \(rl.fiveHourResetString)" : "",
                    color: progressColor(rl.fiveHourPercent))
                cardProgressRow(label: "1w",
                    value: rl.isLoaded ? rl.weeklyPercent / 100 : 0,
                    text: rl.isLoaded ? "\(Int(rl.weeklyPercent))%" : "—",
                    sub: rl.isLoaded ? "↻ \(rl.weeklyResetString)" : "",
                    color: progressColor(rl.weeklyPercent))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Token Usage

    private var tokenSection: some View {
        Group {
            switch provider {
            case .claude:
                HStack(spacing: 0) {
                    tokenBlock(title: "5h TOKENS", tokens: stats.fiveHourTokens)
                    Divider().frame(width: 1).background(Color.white.opacity(0.08))
                    tokenBlock(title: "1w TOKENS", tokens: stats.oneWeekTokens)
                }
            case .codex:
                HStack(spacing: 0) {
                    codexTokenBlock(title: "5h TOKENS", tokens: stats.codexFiveHourTokens)
                    Divider().frame(width: 1).background(Color.white.opacity(0.08))
                    codexTokenBlock(title: "1w TOKENS", tokens: stats.codexOneWeekTokens)
                }
            case .both:
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        tokenBlock(title: "Claude 5h", tokens: stats.fiveHourTokens)
                        Divider().frame(width: 1).background(Color.white.opacity(0.08))
                        tokenBlock(title: "Claude 1w", tokens: stats.oneWeekTokens)
                    }
                    Divider().background(Color.white.opacity(0.15))
                    HStack(spacing: 0) {
                        codexTokenBlock(title: "Codex 5h", tokens: stats.codexFiveHourTokens)
                        Divider().frame(width: 1).background(Color.white.opacity(0.08))
                        codexTokenBlock(title: "Codex 1w", tokens: stats.codexOneWeekTokens)
                    }
                }
            }
        }
    }

    private func tokenBlock(title: String, tokens: TokenUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            Text(TokenUsage.formatTokens(tokens.totalTokens))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                miniStat(label: "In", value: TokenUsage.formatTokens(tokens.inputTokens), color: .blue)
                miniStat(label: "Out", value: TokenUsage.formatTokens(tokens.outputTokens), color: .green)
            }
            HStack(spacing: 8) {
                miniStat(label: "C.Wr", value: TokenUsage.formatTokens(tokens.cacheCreationTokens), color: .orange)
                miniStat(label: "C.Rd", value: TokenUsage.formatTokens(tokens.cacheReadTokens), color: .purple)
            }

            Text(TokenUsage.formatCost(tokens.estimatedCostUSD))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(costColor(tokens.estimatedCostUSD))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func codexTokenBlock(title: String, tokens: CodexTokenUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            Text(TokenUsage.formatTokens(tokens.totalTokens))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                miniStat(label: "In", value: TokenUsage.formatTokens(tokens.inputTokens), color: .blue)
                miniStat(label: "Out", value: TokenUsage.formatTokens(tokens.outputTokens), color: .green)
            }
            HStack(spacing: 8) {
                miniStat(label: "Cache", value: TokenUsage.formatTokens(tokens.cachedInputTokens), color: .purple)
            }

            Text(TokenUsage.formatCost(tokens.estimatedCostUSD))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(costColor(tokens.estimatedCostUSD))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Model Usage

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODEL USAGE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            ForEach(stats.modelUsages.prefix(3)) { mu in
                let maxTokens = stats.modelUsages.first?.totalTokens ?? 1
                let ratio = Double(mu.totalTokens) / Double(max(maxTokens, 1))
                let color: Color = mu.modelName.contains("opus") ? .purple :
                                   mu.modelName.contains("sonnet") ? .blue : .green

                HStack(spacing: 8) {
                    Text(mu.shortName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(color)
                        .frame(width: 48, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.opacity(0.7))
                                .frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(height: 6)

                    Text(TokenUsage.formatTokens(mu.totalTokens))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)

                    Text(TokenUsage.formatCost(mu.estimatedCostUSD))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Context

    private var contextSection: some View {
        let ctx = stats.contextInfo
        return VStack(alignment: .leading, spacing: 8) {
            Text("CONTEXT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            cardProgressRow(
                label: "",
                value: ctx.usagePercent,
                text: "\(Int(ctx.usagePercent * 100))%",
                sub: "\(TokenUsage.formatTokens(ctx.usedTokens)) / \(TokenUsage.formatTokens(ctx.maxContextTokens))",
                color: contextColor(ctx.usagePercent)
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Line Chart

    private var lineChartSection: some View {
        let hourlyData = provider == .codex ? stats.codexHourlyData : stats.hourlyData
        return VStack(alignment: .leading, spacing: 8) {
            Text("TOKENS (24h)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            Chart(hourlyData) { point in
                LineMark(x: .value("시간", point.hour), y: .value("토큰", point.totalTokens))
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("시간", point.hour), y: .value("토큰", point.totalTokens))
                    .foregroundStyle(.blue.opacity(0.15))
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 122)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func formatHour(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        return f.string(from: date)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        let weeklyData = provider == .codex ? stats.codexWeeklyHourlyData : stats.weeklyHourlyData
        return VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVITY (7d)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            HeatmapView(weeklyData: weeklyData, fontScale: 0.85, showDayLabels: false)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Spacer()
            Text("github.com/rofeels/duckbar")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    // MARK: - Sub Components

    private func cardProgressRow(label: String, value: Double, text: String, sub: String, color: Color) -> some View {
        HStack(spacing: 8) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * min(value, 1.0))
                }
            }
            .frame(height: 6)

            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .trailing)

            if !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
        }
        .frame(height: 14)
    }

    private func miniStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var currentDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm 'KST'"
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        return f.string(from: Date())
    }

    private func progressColor(_ pct: Double) -> Color {
        if pct >= 80 { return .red }
        if pct >= 50 { return .orange }
        return .green
    }

    private func costColor(_ cost: Double) -> Color {
        if cost >= 5 { return .red }
        if cost >= 2 { return .orange }
        return .green
    }

    private func contextColor(_ pct: Double) -> Color {
        if pct >= 0.8 { return .red }
        if pct >= 0.5 { return .orange }
        return .blue
    }
}

// MARK: - 카드 렌더링 → NSImage

@MainActor
func renderShareCard(stats: UsageStats, chartTab: String = "heatmap", provider: Provider = .claude) -> NSImage? {
    let view = ShareCardView(stats: stats, chartTab: chartTab, provider: provider)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0  // Retina
    return renderer.nsImage
}

// MARK: - 클립보드에 복사

@MainActor
func copyShareCardToClipboard(stats: UsageStats, chartTab: String = "heatmap", provider: Provider = .claude) {
    guard let image = renderShareCard(stats: stats, chartTab: chartTab, provider: provider) else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([image])
}
