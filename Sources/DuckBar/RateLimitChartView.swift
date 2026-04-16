import SwiftUI
import Charts

/// 시간별 Rate Limit 사용률 라인 차트 (history 기반).
/// - 5시간 % (파랑) + 1주 % (주황) 실선
/// - 예측: 최근 30분 기울기로 선형 외삽 (점선)
/// - 80%, 100% 수평 임계선, "지금" 세로선
struct RateLimitChartView: View {
    let history: [UsageSnapshot]
    let currentFiveH: Double?
    let currentWeekly: Double?
    let fontScale: CGFloat

    private var s: CGFloat { fontScale }

    private struct PlotPoint: Identifiable {
        let id = UUID()
        let time: Date
        let value: Double
        let series: String  // "5h-past" | "5h-future" | "1w-past" | "1w-future"
    }

    var body: some View {
        let now = Date()
        let plotPoints = buildPlotPoints(now: now)

        Chart {
            ForEach(plotPoints) { p in
                LineMark(
                    x: .value("시간", p.time),
                    y: .value("%", p.value),
                    series: .value("series", p.series)
                )
                .foregroundStyle(colorFor(series: p.series))
                .lineStyle(
                    p.series.contains("future")
                    ? StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                    : StrokeStyle(lineWidth: 1.8)
                )
                .interpolationMethod(.linear)
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
        .chartXScale(domain: now.addingTimeInterval(-24 * 3600)...now.addingTimeInterval(2 * 3600))
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

    private func colorFor(series: String) -> Color {
        series.hasPrefix("5h") ? .blue : .orange
    }

    // MARK: - 포인트 빌드

    private func buildPlotPoints(now: Date) -> [PlotPoint] {
        // 과거 24시간 내 history만 사용
        let oneDayAgo = now.addingTimeInterval(-24 * 3600)
        let past = history.filter { $0.timestamp >= oneDayAgo }

        var points: [PlotPoint] = []

        // 5시간 % 과거 실선
        let fiveHPast = past.compactMap { snap -> (Date, Double)? in
            guard let v = snap.fiveH else { return nil }
            return (snap.timestamp, v)
        }
        for (t, v) in fiveHPast {
            points.append(PlotPoint(time: t, value: v, series: "5h-past"))
        }

        // 1주 % 과거 실선
        let weeklyPast = past.compactMap { snap -> (Date, Double)? in
            guard let v = snap.weekly else { return nil }
            return (snap.timestamp, v)
        }
        for (t, v) in weeklyPast {
            points.append(PlotPoint(time: t, value: v, series: "1w-past"))
        }

        // 예측: 최근 30분 구간의 기울기(per hour)로 선형 외삽
        let futureEnd = now.addingTimeInterval(2 * 3600)

        if let currentFiveH {
            let slope = slopePerHour(from: fiveHPast, now: now)
            // 현재 시점에서 과거 라인과 연결 (같은 series로 만들면 과거-미래가 실선으로 연결되니 별도 series)
            points.append(PlotPoint(time: now, value: currentFiveH, series: "5h-future"))
            let predictedEnd = max(0, min(currentFiveH + slope * 2, 110))
            points.append(PlotPoint(time: futureEnd, value: predictedEnd, series: "5h-future"))
        }

        if let currentWeekly {
            let slope = slopePerHour(from: weeklyPast, now: now)
            points.append(PlotPoint(time: now, value: currentWeekly, series: "1w-future"))
            let predictedEnd = max(0, min(currentWeekly + slope * 2, 110))
            points.append(PlotPoint(time: futureEnd, value: predictedEnd, series: "1w-future"))
        }

        return points
    }

    /// 최근 30분 데이터 기준 시간당 증가율 (%/hour)
    private func slopePerHour(from points: [(Date, Double)], now: Date) -> Double {
        let since = now.addingTimeInterval(-30 * 60)
        let recent = points.filter { $0.0 >= since }
        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last
        else { return 0 }
        let dt = last.0.timeIntervalSince(first.0) / 3600.0  // 시간 단위
        guard dt > 0 else { return 0 }
        return (last.1 - first.1) / dt
    }

    private func formatHour(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H시"
        return f.string(from: date)
    }
}

// MARK: - Rate Limit 계산 유틸 (히트맵용 유지)

enum RateLimitMath {
    static func sumTokens(_ data: [HourlyTokenData], from start: Date, to end: Date) -> Int {
        data.filter { $0.hour >= start && $0.hour < end }
            .reduce(0) { $0 + $1.totalTokens }
    }

    static func sumTokens(_ data: [HourlyTokenData], since: Date) -> Int {
        data.filter { $0.hour >= since }
            .reduce(0) { $0 + $1.totalTokens }
    }

    static func ratio(currentPct: Double?, currentTokens: Int) -> Double? {
        guard let pct = currentPct, pct > 0.5, currentTokens > 0 else { return nil }
        return pct / Double(currentTokens)
    }

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
    /// Rate limit % 스냅샷 히스토리 (최근 7일치)
    let history: [UsageSnapshot]
    /// 5h % 사용 여부 (true=5h 기준, false=1w 기준)
    let useFiveH: Bool
    let fontScale: CGFloat
    var tint: Color = .blue
    var showDayLabels: Bool = true

    private var s: CGFloat { fontScale }

    /// 각 시간 버킷별 최대 % 값을 0~1로 정규화.
    /// 1시간 안에 여러 스냅샷이 있을 수 있어 max를 취함 (스파이크 보존).
    private var intensityMap: [Date: Double] {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let sundayEnd = cal.date(byAdding: .day, value: 7, to: monday)!

        // 이번 주 스냅샷만 필터
        let thisWeek = history.filter { $0.timestamp >= monday && $0.timestamp < sundayEnd }

        // 시간 버킷별 max % 집계
        var bucketMax: [Date: Double] = [:]
        for snap in thisWeek {
            guard let pct = useFiveH ? snap.fiveH : snap.weekly, pct > 0 else { continue }
            let hourStart = cal.date(from: cal.dateComponents([.year, .month, .day, .hour], from: snap.timestamp))!
            bucketMax[hourStart] = max(bucketMax[hourStart] ?? 0, pct)
        }

        // 0~1 정규화: 100%를 최대로 하지 말고 실제 max 기준
        // 단, 너무 작은 값들이 안 보이지 않도록 최소 스케일 보장
        guard let maxPct = bucketMax.values.max(), maxPct > 0 else { return [:] }
        let scale = max(maxPct, 20.0)  // 최대가 20% 미만이면 20%를 기준으로

        var map: [Date: Double] = [:]
        for (k, v) in bucketMax {
            map[k] = min(v / scale, 1.0)
        }
        return map
    }

    private var days: [Date] {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
    }

    private var gridHeight: CGFloat { 144 * fontScale }

    var body: some View {
        // history에 rate limit 스냅샷이 하나라도 있으면 표시
        let hasData = !history.isEmpty
        if !hasData {
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
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal.date(byAdding: .hour, value: hour, to: day)!
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
