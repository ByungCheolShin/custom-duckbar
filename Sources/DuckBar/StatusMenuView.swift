import SwiftUI

struct StatusMenuView: View {
    let monitor: SessionMonitor
    let settings: AppSettings
    let onQuit: () -> Void

    private enum ViewMode { case main, settings, help }
    @State private var viewMode: ViewMode = .main
    @State private var showChart = false

    private var s: CGFloat { settings.popoverSize.fontScale }
    private var popoverWidth: CGFloat { settings.popoverSize.width }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch viewMode {
            case .main:
                mainView
            case .settings:
                SettingsView(settings: settings, onHelp: { viewMode = .help }) {
                    viewMode = .main
                }
            case .help:
                HelpView(settings: settings) {
                    viewMode = .main
                }
            }
        }
        .frame(width: popoverWidth)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenSettings"))) { _ in
            viewMode = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenHelp"))) { _ in
            viewMode = .help
        }
        .onChange(of: viewMode) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(name: .init("ResizePopover"), object: nil)
            }
        }
    }

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()

            if monitor.sessions.isEmpty {
                emptyStateView
            } else {
                sessionListView
            }

            Divider()
            rateLimitsView
            Divider()
            tokenUsageView(title: L.fiveHourWindow, tokens: monitor.usageStats.fiveHourTokens)
            Divider()
            tokenUsageView(title: L.oneWeekWindow, tokens: monitor.usageStats.oneWeekTokens)

            Divider()
            chartToggleView

            if !monitor.usageStats.modelUsages.isEmpty {
                Divider()
                modelUsageView
            }

            Divider()
            contextView

            Spacer()
                .frame(height: 10)

            Divider()

            HStack(spacing: 0) {
                MenuButton(title: L.settings, icon: "gearshape") {
                    viewMode = .settings
                }
                MenuButton(title: L.quit, icon: "power") {
                    onQuit()
                }
            }
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 20 * s))
                .foregroundStyle(.tertiary)
            Text(L.noActiveSessions)
                .font(.system(size: 11 * s))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Session List

    private var sessionListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(monitor.sessions) { session in
                SessionRowView(session: session, fontScale: s)
            }
        }
    }

    // MARK: - Rate Limits

    private var rateLimitsView: some View {
        let rl = monitor.usageStats.rateLimits
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
                    color: rl.isLoaded ? progressColor(rl.fiveHourPercent) : .gray
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
                    color: rl.isLoaded ? progressColor(rl.weeklyPercent) : .gray
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Token Usage

    private func tokenUsageView(title: String, tokens: TokenUsage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11 * s, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(tokens.requestCount) \(L.requests)")
                    .font(.system(size: 10 * s))
                    .foregroundStyle(.tertiary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(TokenUsage.formatCost(tokens.estimatedCostUSD))
                    .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
                    .foregroundStyle(costColor(tokens.estimatedCostUSD))
            }

            HStack(spacing: 0) {
                tokenPill(label: L.tokenIn, value: tokens.inputTokens, color: .blue)
                tokenPill(label: L.tokenOut, value: tokens.outputTokens, color: .green)
                tokenPill(label: L.tokenCacheWrite, value: tokens.cacheCreationTokens, color: .orange)
                tokenPill(label: L.tokenCacheRead, value: tokens.cacheReadTokens, color: .purple)
            }

            // 캐시 효율
            let totalInput = tokens.inputTokens + tokens.cacheCreationTokens + tokens.cacheReadTokens
            let cacheRate = totalInput > 0 ? Double(tokens.cacheReadTokens) / Double(totalInput) * 100 : 0
            HStack(spacing: 4) {
                Text(L.cacheHit)
                    .font(.system(size: 9 * s))
                    .foregroundStyle(.tertiary)
                ProgressBarView(
                    value: cacheRate / 100,
                    color: .purple
                )
                .frame(height: 4)
                Text(String(format: "%.1f%%", cacheRate))
                    .font(.system(size: 9 * s, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Chart Toggle

    private var chartToggleView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChart.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NotificationCenter.default.post(name: .init("ResizePopover"), object: nil)
                }
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10 * s))
                        .foregroundStyle(.secondary)
                    Text(L.chart)
                        .font(.system(size: 11 * s, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showChart ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9 * s))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showChart {
                TokenChartView(
                    hourlyData: monitor.usageStats.hourlyData,
                    fontScale: s
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Model Usage

    private var modelUsageView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.modelUsage)
                .font(.system(size: 11 * s, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(monitor.usageStats.modelUsages) { mu in
                HStack(spacing: 6) {
                    Text(mu.shortName)
                        .font(.system(size: 10 * s, weight: .medium))
                        .foregroundStyle(mu.modelName.contains("opus") ? .purple : mu.modelName.contains("sonnet") ? .blue : .green)
                        .frame(width: 44 * s, alignment: .leading)

                    Text(TokenUsage.formatTokens(mu.totalTokens))
                        .font(.system(size: 10 * s, design: .monospaced))
                        .frame(width: 44 * s, alignment: .trailing)

                    // 비율 바
                    let maxTokens = monitor.usageStats.modelUsages.first?.totalTokens ?? 1
                    ProgressBarView(
                        value: Double(mu.totalTokens) / Double(max(maxTokens, 1)),
                        color: mu.modelName.contains("opus") ? .purple : mu.modelName.contains("sonnet") ? .blue : .green
                    )
                    .frame(height: 4)

                    Text(TokenUsage.formatCost(mu.estimatedCostUSD))
                        .font(.system(size: 9 * s, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 44 * s, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Context

    private var contextView: some View {
        let ctx = monitor.usageStats.contextInfo
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L.context)
                    .font(.system(size: 11 * s, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(TokenUsage.formatTokens(ctx.usedTokens)) / \(TokenUsage.formatTokens(ctx.maxContextTokens))")
                    .font(.system(size: 10 * s, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ProgressBarView(
                value: ctx.usagePercent,
                color: contextColor(ctx.usagePercent)
            )
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

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

    private func tokenPill(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(TokenUsage.formatTokens(value))
                .font(.system(size: 10 * s, weight: .medium, design: .monospaced))
            Text(label)
                .font(.system(size: 8 * s))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(4)
        .padding(.horizontal, 1)
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let value: Double
    var color: Color = .blue
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(value, 1.0)))
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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}