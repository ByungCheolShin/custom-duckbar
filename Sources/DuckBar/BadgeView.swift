import SwiftUI

struct BadgeView: View {
    let onDone: () -> Void
    let stats: UsageStats
    @State private var badges: [Badge] = []
    @State private var badgeShareWindow: BadgeShareCardWindowController?

    private var dailyPeak: [Badge] { badges.filter { $0.category == .dailyPeak } }
    private var streak: [Badge] { badges.filter { $0.category == .streak } }
    private var totalCost: [Badge] { badges.filter { $0.category == .totalCost } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L.badges)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                // Achievement count + share button / 달성 수 + 공유 버튼
                HStack(spacing: 6) {
                    Text("\(badges.filter(\.isAchieved).count)/\(badges.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button(action: {
                        badgeShareWindow = BadgeShareCardWindowController(badges: badges, stats: stats)
                        badgeShareWindow?.show()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L.badgesShareCard)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    badgeSection(title: L.badgeCategoryDailyPeak, badges: dailyPeak)
                    badgeSection(title: L.badgeCategoryStreak, badges: streak)
                    badgeSection(title: L.badgeCategoryTotalCost, badges: totalCost)
                }
                .padding(14)
            }
            .frame(maxHeight: 400)
        }
        .onAppear {
            badges = MilestoneManager.shared.loadBadges()
        }
    }

    private func badgeSection(title: String, badges: [Badge]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(badges) { badge in
                    badgeCell(badge)
                }
            }
        }
    }

    private func badgeCell(_ badge: Badge) -> some View {
        VStack(spacing: 4) {
            Text(badge.icon)
                .font(.system(size: 32))
                .opacity(badge.isAchieved ? 1.0 : 0.2)

            Text(badge.localizedName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(badge.isAchieved ? .primary : .tertiary)
                .lineLimit(1)

            Text(badge.localizedDescription)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let date = badge.achievedAt {
                Text(shortDate(date))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text(L.badgeNotAchieved)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(badge.isAchieved
                      ? Color.accentColor.opacity(0.08)
                      : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    badge.isAchieved ? Color.accentColor.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}
