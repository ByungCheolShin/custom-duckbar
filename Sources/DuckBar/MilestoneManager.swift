import Foundation
import UserNotifications

@MainActor
final class MilestoneManager {
    static let shared = MilestoneManager()

    // MARK: - Badge Definitions / 뱃지 정의

    static let allBadges: [Badge] = [
        // Daily peak / 일간 최고 기록
        Badge(id: "daily_1m",   icon: "🌱", name: "워밍업",     nameEn: "Warm Up",      description: "하루 1M 토큰",    descriptionEn: "1M tokens in a day",   category: .dailyPeak),
        Badge(id: "daily_10m",  icon: "🔥", name: "집중모드",   nameEn: "Focus Mode",   description: "하루 10M 토큰",   descriptionEn: "10M tokens in a day",  category: .dailyPeak),
        Badge(id: "daily_50m",  icon: "⚡", name: "올인",       nameEn: "All In",       description: "하루 50M 토큰",   descriptionEn: "50M tokens in a day",  category: .dailyPeak),
        Badge(id: "daily_100m", icon: "💥", name: "미친하루",   nameEn: "Crazy Day",    description: "하루 100M 토큰",  descriptionEn: "100M tokens in a day", category: .dailyPeak),
        Badge(id: "daily_500m", icon: "👑", name: "전설의하루", nameEn: "Legendary",    description: "하루 500M 토큰",  descriptionEn: "500M tokens in a day", category: .dailyPeak),
        // Streak / 연속 사용
        Badge(id: "streak_3",   icon: "🌤", name: "시작",  nameEn: "Starter",   description: "3일 연속 사용",   descriptionEn: "3-day streak",   category: .streak),
        Badge(id: "streak_7",   icon: "📅", name: "습관",  nameEn: "Habit",     description: "7일 연속 사용",   descriptionEn: "7-day streak",   category: .streak),
        Badge(id: "streak_30",  icon: "🗓", name: "루틴",  nameEn: "Routine",   description: "30일 연속 사용",  descriptionEn: "30-day streak",  category: .streak),
        Badge(id: "streak_100", icon: "🏆", name: "중독",  nameEn: "Addicted",  description: "100일 연속 사용", descriptionEn: "100-day streak", category: .streak),
        // Cumulative cost / 누적 비용
        Badge(id: "cost_100",   icon: "💰", name: "첫 투자",  nameEn: "First Investment", description: "누적 $100",    descriptionEn: "Total $100",    category: .totalCost),
        Badge(id: "cost_1000",  icon: "💳", name: "헤비유저", nameEn: "Heavy User",       description: "누적 $1,000",  descriptionEn: "Total $1,000",  category: .totalCost),
        Badge(id: "cost_5000",  icon: "💸", name: "큰손",    nameEn: "Big Spender",      description: "누적 $5,000",  descriptionEn: "Total $5,000",  category: .totalCost),
        Badge(id: "cost_10000", icon: "🤑", name: "VIP",    nameEn: "VIP",               description: "누적 $10,000", descriptionEn: "Total $10,000", category: .totalCost),
    ]

    // MARK: - UserDefaults Keys

    private func achievedKey(_ id: String) -> String { "badge_achieved_\(id)" }
    private func achievedDateKey(_ id: String) -> String { "badge_date_\(id)" }

    // MARK: - Badge State / 뱃지 상태 로드

    func loadBadges() -> [Badge] {
        MilestoneManager.allBadges.map { badge in
            var b = badge
            if UserDefaults.standard.bool(forKey: achievedKey(badge.id)),
               let date = UserDefaults.standard.object(forKey: achievedDateKey(badge.id)) as? Date {
                b.achievedAt = date
            }
            return b
        }
    }

    // MARK: - Check / 뱃지 조건 검사

    func check(stats: UsageStats, dailyPeakTokens: Int, currentStreak: Int) {
        checkDailyPeak(tokens: dailyPeakTokens)
        checkStreak(days: currentStreak)
        checkCost(total: stats.allTimeCostUSD)
    }

    private func checkDailyPeak(tokens: Int) {
        let thresholds: [(Int, String)] = [
            (500_000_000, "daily_500m"),
            (100_000_000, "daily_100m"),
            (50_000_000,  "daily_50m"),
            (10_000_000,  "daily_10m"),
            (1_000_000,   "daily_1m"),
        ]
        // Award all tiers reached, not just the highest / 도달한 모든 등급 달성 처리
        for (threshold, id) in thresholds.reversed() {
            if tokens >= threshold { achieve(id: id) }
        }
    }

    private func checkStreak(days: Int) {
        let thresholds: [(Int, String)] = [
            (3, "streak_3"), (7, "streak_7"), (30, "streak_30"), (100, "streak_100")
        ]
        for (threshold, id) in thresholds {
            if days >= threshold { achieve(id: id) }
        }
    }

    private func checkCost(total: Double) {
        let thresholds: [(Double, String)] = [
            (100, "cost_100"), (1000, "cost_1000"), (5000, "cost_5000"), (10000, "cost_10000")
        ]
        for (threshold, id) in thresholds {
            if total >= threshold { achieve(id: id) }
        }
    }

    private func achieve(id: String) {
        let key = achievedKey(id)
        guard !UserDefaults.standard.bool(forKey: key) else { return }  // Already achieved / 이미 달성됨
        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.set(Date(), forKey: achievedDateKey(id))

        guard let badge = MilestoneManager.allBadges.first(where: { $0.id == id }) else { return }
        let title = "\(badge.icon) 뱃지 달성: \(badge.localizedName)"
        let body = badge.localizedDescription
        sendNotification(title: title, body: body, badgeId: id)
        NotificationHistoryManager.shared.addMilestone(title: title, body: body)
    }

    private func sendNotification(title: String, body: String, badgeId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "milestone"]
        let request = UNNotificationRequest(
            identifier: "duckbar_badge_\(badgeId)",  // Fixed ID prevents duplicate notifications / 고정 ID로 중복 알림 방지
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Streak Tracking / 연속 사용일 추적

    /// Updates streak counter and returns current streak count.
    /// 오늘 사용 여부를 반영해 streak를 갱신하고 현재 일수를 반환한다.
    func updateStreak(hasUsageToday: Bool) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let lastUsedKey = "streak_lastUsed"
        let streakKey = "streak_count"

        let lastUsed = UserDefaults.standard.object(forKey: lastUsedKey) as? Date
        var streak = UserDefaults.standard.integer(forKey: streakKey)

        guard hasUsageToday else { return streak }

        if let lastUsed {
            let lastDay = Calendar.current.startOfDay(for: lastUsed)
            let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 0 {
                // Already updated today / 오늘 이미 업데이트됨
            } else if diff == 1 {
                // Consecutive day / 연속일
                streak += 1
                UserDefaults.standard.set(streak, forKey: streakKey)
                UserDefaults.standard.set(today, forKey: lastUsedKey)
            } else {
                // Streak broken — reset to 1 / 연속 끊김 → 1로 리셋
                streak = 1
                UserDefaults.standard.set(streak, forKey: streakKey)
                UserDefaults.standard.set(today, forKey: lastUsedKey)
            }
        } else {
            // First use ever / 첫 사용
            streak = 1
            UserDefaults.standard.set(streak, forKey: streakKey)
            UserDefaults.standard.set(today, forKey: lastUsedKey)
        }

        return streak
    }

    // For debug use only / 디버그 전용
    func resetAll() {
        for badge in MilestoneManager.allBadges {
            UserDefaults.standard.removeObject(forKey: achievedKey(badge.id))
            UserDefaults.standard.removeObject(forKey: achievedDateKey(badge.id))
        }
        UserDefaults.standard.removeObject(forKey: "streak_lastUsed")
        UserDefaults.standard.removeObject(forKey: "streak_count")
    }
}
