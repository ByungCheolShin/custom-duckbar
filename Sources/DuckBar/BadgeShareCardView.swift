import SwiftUI
import AppKit

// MARK: - Badge Share Card View / 뱃지 공유 카드 뷰

struct BadgeShareCardView: View {
    let badges: [Badge]
    let stats: UsageStats

    private let cardWidth: CGFloat = 360
    private var achieved: [Badge] { badges.filter(\.isAchieved) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().background(Color.primary.opacity(0.1))
            badgeGridSection
            Divider().background(Color.primary.opacity(0.1))
            statsSection
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

    // MARK: - Header / 헤더

    private var headerSection: some View {
        HStack {
            Group {
                if let nsImage = Bundle.main.image(forResource: "duck_icon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Text("🦆").font(.system(size: 22))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.badgeShareCardTitle)
                    .font(.system(size: 15, weight: .bold))
                Text(currentDateString)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Achievement count badge / 달성 수 뱃지
            Text("\(achieved.count)/\(badges.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor))
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Badge Grid / 뱃지 그리드

    private var badgeGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            badgeRow(category: .dailyPeak, title: L.badgeCategoryDailyPeak)
            badgeRow(category: .streak,    title: L.badgeCategoryStreak)
            badgeRow(category: .totalCost, title: L.badgeCategoryTotalCost)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func badgeRow(category: Badge.BadgeCategory, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(badges.filter { $0.category == category }) { badge in
                    VStack(spacing: 2) {
                        Text(badge.icon)
                            .font(.system(size: 20))
                            .opacity(badge.isAchieved ? 1.0 : 0.15)
                        Text(badge.localizedName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(badge.isAchieved ? .primary : .tertiary)
                            .lineLimit(1)
                        Text(badge.localizedDescription)
                            .font(.system(size: 8))
                            .foregroundStyle(badge.isAchieved ? .secondary : .quaternary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Stats Summary / 통계 요약

    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(label: L.badgeStatTotalTokens, value: TokenUsage.formatTokens(stats.allTimeTokens))
            Divider().frame(height: 32)
            statItem(label: L.badgeStatTotalCost, value: TokenUsage.formatCost(stats.allTimeCostUSD))
            Divider().frame(height: 32)
            statItem(label: L.badgeStatStreak, value: L.badgeStreakDays(UserDefaults.standard.integer(forKey: "streak_count")))
        }
        .padding(.vertical, 12)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer / 푸터

    private var footerSection: some View {
        HStack {
            Spacer()
            Text("DuckBar · Claude Code Monitor")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var currentDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: Date())
    }
}

// MARK: - Render & Copy / 렌더링 및 복사

@MainActor
func renderBadgeShareCard(badges: [Badge], stats: UsageStats) -> NSImage? {
    let view = BadgeShareCardView(badges: badges, stats: stats)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0  // Retina
    return renderer.nsImage
}

@MainActor
func copyBadgeShareCardToClipboard(badges: [Badge], stats: UsageStats) {
    guard let image = renderBadgeShareCard(badges: badges, stats: stats) else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([image])
}

@MainActor
func saveBadgeShareCardAsPNG(badges: [Badge], stats: UsageStats) {
    guard let image = renderBadgeShareCard(badges: badges, stats: stats) else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "duckbar-achievements.png"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
}
