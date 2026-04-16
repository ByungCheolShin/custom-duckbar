import SwiftUI
import Charts

/// 시간별 Rate Limit 사용률 라인 차트.
/// - 5시간 롤링 %: 파란색 (fiveHourPercent 전달 시에만)
/// - 1주 롤링 %: 주황색 (weeklyPercent 전달 시에만)
/// - 80%, 100% 수평 임계선, "지금" 세로선
/// - 미래 예측: 최근 1시간 기울기로 선형 외삽 (점선)
///
/// 한도 추정: 현재 % / 현재 rolling 토큰합 = 토큰당 %
struct RateLimitChartView: View {
    let hourlyData: [HourlyTokenData]           // 24시간 (5h 롤링용)
    let weeklyHourlyData: [HourlyTokenData]     // 7일 (1w 롤링용)
    let fiveHourPercent: Double?
    let weeklyPercent: Double?
    let fontScale: CGFloat

    private var s: CGFloat { fontScale }

    private struct UsagePoint: Identifiable {
        let id = UUID()
        let time: Date
        let fiveHourPct: Double?
        let weeklyPct: Double?
        let isPrediction: Bool
    }

    var body: some View {
        let points = buildPoints()
        let now = Date()

        Chart {
            if fiveHourPercent != nil {
                ForEach(points.filter { !$0.isPrediction && $0.fiveHourPct != nil }) { p in
                    LineMark(
                        x: .value("시간", p.time),
                        y: .value("5h", p.fiveHourPct ?? 0),
                        series: .value("series", "5h-past")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
                ForEach(points.filter { $0.isPrediction && $0.fiveHourPct != nil }) { p in
                    LineMark(
                        x: .value("시간", p.time),
                        y: .value("5h", p.fiveHourPct ?? 0),
                        series: .value("series", "5h-future")
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
            }
            if weeklyPercent != nil {
                ForEach(points.filter { !$0.isPrediction && $0.weeklyPct != nil }) { p in
                    LineMark(
                        x: .value("시간", p.time),
                        y: .value("1w", p.weeklyPct ?? 0),
                        series: .value("series", "1w-past")
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
                }
                ForEach(points.filter { $0.isPrediction && $0.weeklyPct != nil }) { p in
                    LineMark(
                        x: .value("시간", p.time),
                        y: .value("1w", p.weeklyPct ?? 0),
                        series: .value("series", "1w-future")
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
            }
            RuleMark(y: .value("100%", 100))
                .foregroundStyle(.red.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [4, 3]))
            RuleMark(y: .value("80%", 80))
                .foregroundStyle(.orange.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [4, 3]))
            RuleMark(x: .value("지금", now))
                .foregroundStyle(.primary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 0.8))
        }
        .chartYScale(domain: 0...105)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatHour(date)).font(.system(size: 8 * s))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%").font(.system(size: 8 * s))
                    }
                }
            }
        }
        .frame(minHeight: 120 * s)
    }

    // MARK: - 포인트 빌드

    private func buildPoints() -> [UsagePoint] {
        let now = Date()
        let calendar = Calendar.current
        let startHour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: now.addingTimeInterval(-24 * 3600)))!
        let endHour = calendar.date(byAdding: .hour, value: 2, to: calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: now))!)!

        // 한도 추정 (토큰당 %)
        let currentFiveHourTokens = RateLimitMath.sumTokens(hourlyData, since: now.addingTimeInterval(-5 * 3600))
        let currentWeeklyTokens = RateLimitMath.sumTokens(weeklyHourlyData, since: now.addingTimeInterval(-7 * 24 * 3600))

        let fiveHourRatio: Double? = RateLimitMath.ratio(
            currentPct: fiveHourPercent,
            currentTokens: currentFiveHourTokens
        )
        let weeklyRatio: Double? = RateLimitMath.ratio(
            currentPct: weeklyPercent,
            currentTokens: currentWeeklyTokens
        )

        // 최근 1시간의 시간당 사용률 증가분 (예측용)
        let lastHourTokens5h = RateLimitMath.sumTokens(hourlyData, from: now.addingTimeInterval(-3600), to: now)
        let lastHourTokens1w = RateLimitMath.sumTokens(weeklyHourlyData, from: now.addingTimeInterval(-3600), to: now)

        var points: [UsagePoint] = []
        var cursor = startHour
        while cursor <= endHour {
            let isPrediction = cursor > now

            let fivePct: Double?
            let weeklyPct: Double?

            if isPrediction {
                fivePct = RateLimitMath.predict(
                    cursor: cursor, now: now,
                    currentPct: fiveHourPercent,
                    lastHourTokens: lastHourTokens5h,
                    ratio: fiveHourRatio
                )
                weeklyPct = RateLimitMath.predict(
                    cursor: cursor, now: now,
                    currentPct: weeklyPercent,
                    lastHourTokens: lastHourTokens1w,
                    ratio: weeklyRatio
                )
            } else {
                fivePct = fiveHourRatio.map { ratio in
                    let tokens = RateLimitMath.sumTokens(hourlyData,
                                                         from: cursor.addingTimeInterval(-5 * 3600),
                                                         to: cursor)
                    return min(Double(tokens) * ratio, 110)
                }
                weeklyPct = weeklyRatio.map { ratio in
                    let tokens = RateLimitMath.sumTokens(weeklyHourlyData,
                                                         from: cursor.addingTimeInterval(-7 * 24 * 3600),
                                                         to: cursor)
                    return min(Double(tokens) * ratio, 110)
                }
            }

            points.append(UsagePoint(
                time: cursor,
                fiveHourPct: fivePct,
                weeklyPct: weeklyPct,
                isPrediction: isPrediction
            ))
            cursor = calendar.date(byAdding: .minute, value: 30, to: cursor)!
        }

        return points
    }

    private func formatHour(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H시"
        return f.string(from: date)
    }
}

// MARK: - Rate Limit 계산 유틸 (공용)

enum RateLimitMath {
    /// [start, end) 구간 토큰 합
    static func sumTokens(_ data: [HourlyTokenData], from start: Date, to end: Date) -> Int {
        data.filter { $0.hour >= start && $0.hour < end }
            .reduce(0) { $0 + $1.totalTokens }
    }

    /// [since, ∞) 토큰 합
    static func sumTokens(_ data: [HourlyTokenData], since: Date) -> Int {
        data.filter { $0.hour >= since }
            .reduce(0) { $0 + $1.totalTokens }
    }

    /// 토큰당 % 비율 (nil이면 계산 불가)
    static func ratio(currentPct: Double?, currentTokens: Int) -> Double? {
        guard let pct = currentPct, pct > 0.5, currentTokens > 0 else { return nil }
        return pct / Double(currentTokens)
    }

    /// 예측 %
    static func predict(cursor: Date, now: Date, currentPct: Double?,
                        lastHourTokens: Int, ratio: Double?) -> Double? {
        guard let ratio, let currentPct else { return nil }
        let perHourDelta = Double(lastHourTokens) * ratio
        let elapsed = cursor.timeIntervalSince(now) / 3600.0
        let predicted = currentPct + perHourDelta * elapsed
        return max(0, min(predicted, 110))
    }
}

// MARK: - Rate Limit 기반 히트맵 (7일 × 24시간)

struct RateLimitHeatmapView: View {
    let weeklyHourlyData: [HourlyTokenData]
    /// 기준 rate limit % (현재 시점의 rolling %). nil이면 히트맵 안 그림
    let currentPercent: Double?
    /// 롤링 윈도우 시간 (5시간 또는 168시간)
    let rollingHours: Int
    let fontScale: CGFloat
    /// 색상 톤 (Claude=파랑, Codex=주황 느낌)
    var tint: Color = .blue
    var showDayLabels: Bool = true

    private var s: CGFloat { fontScale }

    private var intensityMap: [Date: Double] {
        guard let currentPercent, currentPercent > 0.5 else { return [:] }
        // 현재 rolling 토큰합
        let now = Date()
        let rollingStart = now.addingTimeInterval(-Double(rollingHours) * 3600)
        let currentRollingTokens = RateLimitMath.sumTokens(weeklyHourlyData, since: rollingStart)
        guard currentRollingTokens > 0 else { return [:] }
        let ratio = currentPercent / Double(currentRollingTokens)

        var map: [Date: Double] = [:]
        for bucket in weeklyHourlyData {
            let cursor = bucket.hour
            // 이 시점의 [cursor-rollingHours, cursor] 토큰합
            let start = cursor.addingTimeInterval(-Double(rollingHours) * 3600)
            let rollingTokens = RateLimitMath.sumTokens(weeklyHourlyData, from: start, to: cursor)
            let pct = min(Double(rollingTokens) * ratio, 100)
            map[cursor] = pct / 100.0   // 0~1
        }
        return map
    }

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }

    private var gridHeight: CGFloat { 144 * fontScale }

    var body: some View {
        if currentPercent == nil {
            VStack {
                Text("—")
                    .font(.system(size: 10 * s))
                    .foregroundStyle(.tertiary)
            }
            .frame(height: gridHeight)
            .frame(maxWidth: .infinity)
        } else {
            GeometryReader { geo in
                RateLimitHeatmapGrid(
                    days: days,
                    intensityMap: intensityMap,
                    fontScale: fontScale,
                    totalWidth: geo.size.width,
                    tint: tint,
                    showDayLabels: showDayLabels
                )
            }
            .frame(height: gridHeight)
        }
    }
}

private struct RateLimitHeatmapGrid: View {
    let days: [Date]
    let intensityMap: [Date: Double]
    let fontScale: CGFloat
    let totalWidth: CGFloat
    let tint: Color
    let showDayLabels: Bool

    private var s: CGFloat { fontScale }
    private var labelWidth: CGFloat { showDayLabels ? 28 : 0 }
    private var cellSize: CGFloat { (totalWidth - labelWidth) / 24 }
    private var rowHeight: CGFloat { cellSize * 0.85 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            hourLabels
            ForEach(days, id: \.self) { day in
                RateLimitHeatmapRow(
                    day: day,
                    intensityMap: intensityMap,
                    fontScale: fontScale,
                    cellSize: cellSize,
                    rowHeight: rowHeight,
                    tint: tint,
                    showDayLabel: showDayLabels
                )
            }
            legendRow
        }
    }

    private var hourLabels: some View {
        HStack(spacing: 0) {
            if showDayLabels {
                Spacer().frame(width: 28)
            }
            ForEach(0..<4, id: \.self) { i in
                Text("\(i * 6)")
                    .font(.system(size: 7 * s))
                    .foregroundStyle(.tertiary)
                    .frame(width: cellSize * 6, alignment: .leading)
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("0%").font(.system(size: 7 * s)).foregroundStyle(.tertiary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { v in
                RoundedRectangle(cornerRadius: 2)
                    .fill(tintColor(intensity: v))
                    .frame(width: 10, height: 10)
            }
            Text("100%").font(.system(size: 7 * s)).foregroundStyle(.tertiary)
        }
        .padding(.top, 2)
    }

    private func tintColor(intensity: Double) -> Color {
        if intensity <= 0 { return Color.gray.opacity(0.15) }
        return tint.opacity(max(0.15, min(intensity, 1.0)))
    }
}

private struct RateLimitHeatmapRow: View {
    let day: Date
    let intensityMap: [Date: Double]
    let fontScale: CGFloat
    let cellSize: CGFloat
    let rowHeight: CGFloat
    let tint: Color
    let showDayLabel: Bool

    private var s: CGFloat { fontScale }

    var body: some View {
        HStack(spacing: 2) {
            if showDayLabel {
                Text(dayLabel)
                    .font(.system(size: 7 * s, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .trailing)
            }
            HStack(spacing: 1) {
                ForEach(0..<24, id: \.self) { hour in
                    let date = hourDate(hour)
                    let intensity = intensityMap[date] ?? 0
                    RateLimitHeatmapCell(
                        intensity: intensity,
                        cellSize: cellSize,
                        rowHeight: rowHeight,
                        tint: tint,
                        label: "\(hourLabel(hour)) · \(Int(intensity * 100))%"
                    )
                }
            }
        }
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EE"
        f.locale = Locale(identifier: L.lang == .korean ? "ko_KR" : "en_US")
        return f.string(from: day)
    }

    private func hourDate(_ hour: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hour, to: day)!
    }

    private func hourLabel(_ hour: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:00"
        return f.string(from: hourDate(hour))
    }
}

private struct RateLimitHeatmapCell: View {
    let intensity: Double
    let cellSize: CGFloat
    let rowHeight: CGFloat
    let tint: Color
    let label: String

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(intensity <= 0
                  ? Color.gray.opacity(0.15)
                  : tint.opacity(max(0.15, min(intensity, 1.0))))
            .frame(width: cellSize - 1, height: rowHeight)
            .help(label)
    }
}
