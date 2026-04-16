import SwiftUI

struct StatusMenuView: View {
    let monitor: SessionMonitor
    let settings: AppSettings
    let onQuit: () -> Void

    private enum ViewMode { case main, settings, help }
    @State private var viewMode: ViewMode = .main

    init(monitor: SessionMonitor, settings: AppSettings, onQuit: @escaping () -> Void) {
        self.monitor = monitor
        self.settings = settings
        self.onQuit = onQuit
    }

    /// 활성화된 환경 목록 (설정 화면 등에서 참조)
    private var enabledEnvironments: [ClaudeEnvironment] {
        monitor.environments.filter { $0.enabled }
    }

    private var s: CGFloat { settings.popoverSize.fontScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch viewMode {
            case .main:
                mainView
            case .settings:
                SettingsView(settings: settings, monitor: monitor, onHelp: { viewMode = .help }) {
                    viewMode = .main
                }
            case .help:
                HelpView(settings: settings) {
                    viewMode = .main
                }
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            viewMode = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHelp)) { _ in
            viewMode = .help
        }
    }

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 계정별 카드 — 가로 스크롤, 각 카드 세로 스택
                    let showRL = settings.visibleSections.contains(.rateLimits)
                    let showChart = settings.visibleSections.contains(.chart)
                    if showRL || showChart {
                        switch settings.activeProvider {
                        case .claude:
                            claudePerAccountRows(showRL: showRL, showChart: showChart)
                        case .codex:
                            codexPerAccountRow(showRL: showRL, showChart: showChart)
                        case .both:
                            claudePerAccountRows(showRL: showRL, showChart: showChart)
                            codexPerAccountRow(showRL: showRL, showChart: showChart)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(L.appTitle)
                .font(.system(size: 13 * s, weight: .semibold))
            Spacer()
            Button(action: { Task { await monitor.refreshAsync() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11 * s))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.refresh)
            Button(action: { viewMode = .settings }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11 * s))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.settings)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 각 계정별 고정 컬럼 폭 (가로 스크롤 시)
    private var accountColumnWidth: CGFloat { 420 }

    /// Claude 계정별 레이아웃.
    /// - 계정 ≤ 1개: 전체 폭 세로 스택 (사용한도 → 라인 → 히트맵)
    /// - 계정 ≥ 2개: 가로 ScrollView, 각 계정은 고정 폭 세로 스택
    @ViewBuilder
    private func claudePerAccountRows(showRL: Bool, showChart: Bool) -> some View {
        let accounts = monitor.accountRateLimits
        if accounts.isEmpty {
            accountColumnView(
                label: nil,
                stats: monitor.usageStats,
                fiveH: nil,
                weekly: nil,
                showRL: showRL,
                showChart: showChart,
                fixedWidth: nil
            )
        } else if accounts.count == 1 {
            let acc = accounts[0]
            let stats = monitor.accountStats[acc.id] ?? monitor.usageStats
            accountColumnView(
                label: nil, // 계정 1개면 헤더 생략
                stats: stats,
                fiveH: acc.rateLimits.isLoaded ? acc.rateLimits.fiveHourPercent : nil,
                weekly: acc.rateLimits.isLoaded ? acc.rateLimits.weeklyPercent : nil,
                showRL: showRL,
                showChart: showChart,
                fixedWidth: nil
            )
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in
                        let stats = monitor.accountStats[acc.id] ?? UsageStats()
                        accountColumnView(
                            label: accountLabel(for: acc, index: index + 1),
                            stats: stats,
                            fiveH: acc.rateLimits.isLoaded ? acc.rateLimits.fiveHourPercent : nil,
                            weekly: acc.rateLimits.isLoaded ? acc.rateLimits.weeklyPercent : nil,
                            showRL: showRL,
                            showChart: showChart,
                            fixedWidth: accountColumnWidth
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }

    /// 한 계정 컬럼 (세로: 라벨 → 사용한도 → 라인 → 히트맵)
    @ViewBuilder
    private func accountColumnView(label: String?,
                                    stats: UsageStats,
                                    fiveH: Double?,
                                    weekly: Double?,
                                    showRL: Bool,
                                    showChart: Bool,
                                    fixedWidth: CGFloat?) -> some View {
        let content = VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.system(size: 11 * s, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
            }
            if showRL {
                rateLimitsViewForAccount(fiveH: fiveH, weekly: weekly)
            }
            if showChart {
                lineChartViewForAccount(stats: stats, fiveH: fiveH, weekly: weekly)
                heatmapChartViewForAccount(stats: stats, fiveH: fiveH)
            }
        }

        if let w = fixedWidth {
            content
                .frame(width: w, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 단일 계정용 사용한도 뷰 (RateLimits를 직접 받지 않고 %만 받아서 UsageStats 어댑터 사용)
    private func rateLimitsViewForAccount(fiveH: Double?, weekly: Double?) -> some View {
        var rl = RateLimits()
        if let fiveH { rl.fiveHourPercent = fiveH; rl.isLoaded = true }
        if let weekly { rl.weeklyPercent = weekly; rl.isLoaded = true }
        // 리셋 시간 등 추가 정보는 현재 전체 합산 rateLimits에서 가져옴 (계정 단위 정보는 제공 안 됨)
        rl.fiveHourResetsAt = monitor.usageStats.rateLimits.fiveHourResetsAt
        rl.weeklyResetsAt = monitor.usageStats.rateLimits.weeklyResetsAt
        rl.extraUsageLoaded = monitor.usageStats.rateLimits.extraUsageLoaded
        rl.extraUsageEnabled = monitor.usageStats.rateLimits.extraUsageEnabled
        rl.extraUsageUsed = monitor.usageStats.rateLimits.extraUsageUsed
        rl.extraUsageLimit = monitor.usageStats.rateLimits.extraUsageLimit
        rl.extraUsageUtilization = monitor.usageStats.rateLimits.extraUsageUtilization
        rl.extraUsageResetsAt = monitor.usageStats.rateLimits.extraUsageResetsAt
        rl.opusWeeklyPercent = monitor.usageStats.rateLimits.opusWeeklyPercent
        rl.sonnetWeeklyPercent = monitor.usageStats.rateLimits.sonnetWeeklyPercent
        var stats = UsageStats(); stats.rateLimits = rl
        return rateLimitsView(stats)
    }

    private func lineChartViewForAccount(stats: UsageStats, fiveH: Double?, weekly: Double?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            chartSectionHeader(L.chartTabLine)
            RateLimitChartView(
                hourlyData: stats.hourlyData,
                weeklyHourlyData: stats.weeklyHourlyData,
                fiveHourPercent: fiveH,
                weeklyPercent: weekly,
                fontScale: s
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func heatmapChartViewForAccount(stats: UsageStats, fiveH: Double?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            chartSectionHeader(L.chartTabHeatmap)
            RateLimitHeatmapView(
                weeklyHourlyData: stats.weeklyHourlyData,
                currentPercent: fiveH,
                rollingHours: 5,
                fontScale: s,
                tint: .blue
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    /// Codex 행: Codex 카드를 가로 스크롤로 (현재 1개지만 확장 가능)
    @ViewBuilder
    private func codexPerAccountRow(showRL: Bool, showChart: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                codexAccountColumnView(showRL: showRL, showChart: showChart, fixedWidth: accountColumnWidth)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    /// Codex 계정 카드 — Claude 카드와 동일 사이즈/스타일
    @ViewBuilder
    private func codexAccountColumnView(showRL: Bool, showChart: Bool, fixedWidth: CGFloat?) -> some View {
        let content = VStack(alignment: .leading, spacing: 4) {
            Text("Codex")
                .font(.system(size: 11 * s, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.top, 6)
            if showRL {
                codexRateLimitsView
            }
            if showChart {
                codexLineChartView()
                codexHeatmapChartView()
            }
        }

        if let w = fixedWidth {
            content
                .frame(width: w, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Rate Limits (계정 단위)

    /// Claude Rate Limit 섹션. 탭 선택과 무관하게 계정 단위로 표시.
    /// 계정의 표시 라벨: 사용자가 지정한 별칭 > "계정 #N"
    private func accountLabel(for account: AccountRateLimit, index: Int) -> String {
        if let alias = settings.accountAliases[account.id], !alias.isEmpty {
            return alias
        }
        return L.accountFallback(index)
    }

    private func rateLimitsView(_ stats: UsageStats) -> some View {
        let rl = stats.rateLimits
        return VStack(alignment: .leading, spacing: 6) {
            Text(L.rateLimits)
                .font(.system(size: 11 * s, weight: .semibold))
                .foregroundStyle(.secondary)

            // 5-Hour
            HStack(spacing: 6) {
                Text("5h")
                    .font(.system(size: 10 * s, weight: .medium))
                    .frame(width: 20 * s, alignment: .trailing)
                ProgressBarView(
                    value: rl.isLoaded ? rl.fiveHourPercent / 100 : 0,
                    color: rl.isLoaded ? progressColor(rl.fiveHourPercent) : .gray,
                    tickCount: 5
                )
                Text(rl.isLoaded ? "\(Int(rl.fiveHourPercent))%" : L.noData)
                    .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
                    .foregroundStyle(rl.isLoaded ? progressColor(rl.fiveHourPercent) : .secondary)
                    .frame(width: 32 * s, alignment: .trailing)
                Text("↻ \(rl.fiveHourResetString)")
                    .font(.system(size: 9 * s))
                    .foregroundStyle(.tertiary)
                    .frame(width: 60 * s, alignment: .trailing)
            }

            // Weekly
            HStack(spacing: 6) {
                Text("1w")
                    .font(.system(size: 10 * s, weight: .medium))
                    .frame(width: 20 * s, alignment: .trailing)
                ProgressBarView(
                    value: rl.isLoaded ? rl.weeklyPercent / 100 : 0,
                    color: rl.isLoaded ? progressColor(rl.weeklyPercent) : .gray,
                    tickCount: 7
                )
                Text(rl.isLoaded ? "\(Int(rl.weeklyPercent))%" : L.noData)
                    .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
                    .foregroundStyle(rl.isLoaded ? progressColor(rl.weeklyPercent) : .secondary)
                    .frame(width: 32 * s, alignment: .trailing)
                Text("↻ \(rl.weeklyResetString)")
                    .font(.system(size: 9 * s))
                    .foregroundStyle(.tertiary)
                    .frame(width: 60 * s, alignment: .trailing)
            }

            // Opus weekly (if available)
            if let opusPct = rl.opusWeeklyPercent {
                HStack(spacing: 6) {
                    Text("Op")
                        .font(.system(size: 10 * s, weight: .medium))
                        .frame(width: 20 * s, alignment: .trailing)
                    ProgressBarView(
                        value: opusPct / 100,
                        color: progressColor(opusPct)
                    )
                    Text("\(Int(opusPct))%")
                        .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
                        .foregroundStyle(progressColor(opusPct))
                        .frame(width: 32 * s, alignment: .trailing)
                    Text(L.weekly)
                        .font(.system(size: 9 * s))
                        .foregroundStyle(.tertiary)
                        .frame(width: 60 * s, alignment: .trailing)
                }
            }

            // Sonnet weekly (if available)
            if let sonnetPct = rl.sonnetWeeklyPercent {
                HStack(spacing: 6) {
                    Text("So")
                        .font(.system(size: 10 * s, weight: .medium))
                        .frame(width: 20 * s, alignment: .trailing)
                    ProgressBarView(
                        value: sonnetPct / 100,
                        color: progressColor(sonnetPct)
                    )
                    Text("\(Int(sonnetPct))%")
                        .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
                        .foregroundStyle(progressColor(sonnetPct))
                        .frame(width: 32 * s, alignment: .trailing)
                    Text(L.weekly)
                        .font(.system(size: 9 * s))
                        .foregroundStyle(.tertiary)
                        .frame(width: 60 * s, alignment: .trailing)
                }
            }

            // Extra Usage (API에서 extra_usage 받은 경우만 표시)
            if rl.extraUsageLoaded {
                HStack(spacing: 6) {
                    Text("Ex")
                        .font(.system(size: 10 * s, weight: .medium))
                        .frame(width: 20 * s, alignment: .trailing)
                    if rl.extraUsageEnabled {
                        let util = rl.extraUsageUtilization ?? 0
                        ProgressBarView(
                            value: util / 100,
                            color: progressColor(util)
                        )
                        if let used = rl.extraUsageUsed, let limit = rl.extraUsageLimit {
                            Text("$\(String(format: "%.2f", used))/$\(String(format: "%.0f", limit))")
                                .font(.system(size: 9 * s, weight: .medium, design: .monospaced))
                                .foregroundStyle(progressColor(util))
                                .frame(width: 92 * s, alignment: .trailing)
                        } else if let resetDate = rl.extraUsageResetsAt {
                            Text("↻ \(formatResetDate(resetDate))")
                                .font(.system(size: 9 * s))
                                .foregroundStyle(.tertiary)
                                .frame(width: 92 * s, alignment: .trailing)
                        } else {
                            Text("\(Int(util))%")
                                .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
                                .foregroundStyle(progressColor(util))
                                .frame(width: 32 * s, alignment: .trailing)
                            Text(L.monthly)
                                .font(.system(size: 9 * s))
                                .foregroundStyle(.tertiary)
                                .frame(width: 60 * s, alignment: .trailing)
                        }
                    } else {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 5 * s)
                            .clipShape(Capsule())
                        Text(L.extraUsageDisabled)
                            .font(.system(size: 9 * s))
                            .foregroundStyle(.tertiary)
                            .frame(width: 92 * s, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Codex Rate Limits

    private var codexRateLimitsView: some View {
        let rl = monitor.usageStats.codexRateLimits
        return VStack(alignment: .leading, spacing: 6) {
            Text(L.rateLimits)
                .font(.system(size: 11 * s, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("1w")
                    .font(.system(size: 10 * s, weight: .medium))
                    .frame(width: 20 * s, alignment: .trailing)
                ProgressBarView(
                    value: rl.isLoaded ? rl.usedPercent / 100 : 0,
                    color: rl.isLoaded ? progressColor(rl.usedPercent) : .gray
                )
                Text(rl.isLoaded ? "\(Int(rl.usedPercent))%" : L.noData)
                    .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
                    .foregroundStyle(rl.isLoaded ? progressColor(rl.usedPercent) : .secondary)
                    .frame(width: 32 * s, alignment: .trailing)
                Text("↻ \(rl.resetString)")
                    .font(.system(size: 9 * s))
                    .foregroundStyle(.tertiary)
                    .frame(width: 60 * s, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Codex Chart

    private func codexLineChartView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            chartSectionHeader(L.chartTabLine)
            RateLimitChartView(
                hourlyData: monitor.usageStats.codexHourlyData,
                weeklyHourlyData: monitor.usageStats.codexWeeklyHourlyData,
                fiveHourPercent: nil,
                weeklyPercent: monitor.usageStats.codexRateLimits.isLoaded ? monitor.usageStats.codexRateLimits.usedPercent : nil,
                fontScale: s
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func codexHeatmapChartView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            chartSectionHeader(L.chartTabHeatmap)
            RateLimitHeatmapView(
                weeklyHourlyData: monitor.usageStats.codexWeeklyHourlyData,
                currentPercent: monitor.usageStats.codexRateLimits.isLoaded ? monitor.usageStats.codexRateLimits.usedPercent : nil,
                rollingHours: 168,
                fontScale: s,
                tint: .orange
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func chartSectionHeader(_ title: String) -> some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 10 * s))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11 * s, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func formatResetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func progressColor(_ percent: Double) -> Color {
        if percent >= 80 { return .red }
        if percent >= 50 { return .orange }
        return .green
    }

    private func costColor(_ cost: Double) -> Color {
        if cost >= 5 { return .red }
        if cost >= 2 { return .orange }
        return .secondary
    }

    private func contextColor(_ percent: Double) -> Color {
        if percent >= 0.8 { return .red }
        if percent >= 0.5 { return .orange }
        return .blue
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let value: Double
    var color: Color = .blue
    var height: CGFloat = 6
    var tickCount: Int = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(value, 1.0)))

                if tickCount > 1 {
                    ForEach(1..<tickCount, id: \.self) { i in
                        Rectangle()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: 1, height: height)
                            .offset(x: geo.size.width * CGFloat(i) / CGFloat(tickCount))
                    }
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Menu Button

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}