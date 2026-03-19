import SwiftUI
import Charts

struct TokenChartView: View {
    let hourlyData: [HourlyTokenData]
    let fontScale: CGFloat

    private var s: CGFloat { fontScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 토큰 차트
            tokenChart

            // 비용 차트
            costChart
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - 토큰 사용량 차트

    private var tokenChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.tokenChart)
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(hourlyData) { point in
                LineMark(
                    x: .value("시간", point.hour),
                    y: .value("토큰", point.totalTokens)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("시간", point.hour),
                    y: .value("토큰", point.totalTokens)
                )
                .foregroundStyle(.blue.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatHour(date))
                                .font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(TokenUsage.formatTokens(v))
                                .font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .frame(height: 80 * s)
        }
    }

    // MARK: - 비용 차트

    private var costChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.costChart)
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(hourlyData) { point in
                LineMark(
                    x: .value("시간", point.hour),
                    y: .value("비용", point.estimatedCostUSD)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("시간", point.hour),
                    y: .value("비용", point.estimatedCostUSD)
                )
                .foregroundStyle(.orange.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatHour(date))
                                .font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(TokenUsage.formatCost(v))
                                .font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .frame(height: 80 * s)
        }
    }

    // MARK: - Helpers

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }
}
