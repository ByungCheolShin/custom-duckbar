import Foundation
import Observation
import ServiceManagement

// MARK: - Language

enum AppLanguage: String, CaseIterable, Codable {
    case korean = "ko"
    case english = "en"

    var displayName: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

// MARK: - Popover Size

enum PopoverSize: String, CaseIterable, Codable {
    case small
    case medium
    case large

    var displayName: String {
        switch self {
        case .small: L.sizeSmall
        case .medium: L.sizeMedium
        case .large: L.sizeLarge
        }
    }

    var width: CGFloat {
        switch self {
        case .small: 340
        case .medium: 400
        case .large: 460
        }
    }

    var height: CGFloat {
        switch self {
        case .small: 500
        case .medium: 580
        case .large: 660
        }
    }

    var fontScale: CGFloat {
        switch self {
        case .small: 1.0
        case .medium: 1.15
        case .large: 1.3
        }
    }
}

// MARK: - Refresh Interval

enum RefreshInterval: Double, CaseIterable, Codable {
    case one = 1.0
    case three = 3.0
    case five = 5.0
    case ten = 10.0
    case thirty = 30.0
    case sixty = 60.0
    case oneEighty = 180.0
    case threeHundred = 300.0

    var displayName: String {
        switch self {
        case .one: L.interval1s
        case .three: L.interval3s
        case .five: L.interval5s
        case .ten: L.interval10s
        case .thirty: L.interval30s
        case .sixty: L.interval1m
        case .oneEighty: L.interval3m
        case .threeHundred: L.interval5m
        }
    }
}

// MARK: - Status Bar Display Items

enum StatusBarItem: String, CaseIterable, Codable, Identifiable {
    case rateLimit        // 5h 사용률
    case weeklyRateLimit  // 1w 사용률
    case tokens           // 5h 토큰
    case weeklyTokens     // 1w 토큰
    case cost             // 5h 비용
    case weeklyCost       // 1w 비용
    case context          // 컨텍스트 사용률

    var id: String { rawValue }

    func label(_ lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.rateLimit, .korean): "5시간 사용률"
        case (.rateLimit, .english): "5h Rate"
        case (.weeklyRateLimit, .korean): "1주 사용률"
        case (.weeklyRateLimit, .english): "1w Rate"
        case (.tokens, .korean): "5시간 토큰"
        case (.tokens, .english): "5h Tokens"
        case (.weeklyTokens, .korean): "1주 토큰"
        case (.weeklyTokens, .english): "1w Tokens"
        case (.cost, .korean): "5시간 비용"
        case (.cost, .english): "5h Cost"
        case (.weeklyCost, .korean): "1주 비용"
        case (.weeklyCost, .english): "1w Cost"
        case (.context, .korean): "컨텍스트"
        case (.context, .english): "Context"
        }
    }
}

// MARK: - Settings

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet { save() }
    }

    var statusBarItems: Set<StatusBarItem> {
        didSet { save() }
    }

    var popoverSize: PopoverSize {
        didSet { save() }
    }

    var refreshInterval: RefreshInterval {
        didSet { save() }
    }

    var hotkeyCode: UInt16 {
        didSet { save() }
    }

    var hotkeyModifiers: UInt {
        didSet { save() }
    }

    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        if let raw = defaults.string(forKey: "language"),
           let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            let preferred = Locale.preferredLanguages.first ?? ""
            language = preferred.hasPrefix("ko") ? .korean : .english
        }

        if let data = defaults.data(forKey: "statusBarItems"),
           let items = try? JSONDecoder().decode([StatusBarItem].self, from: data) {
            statusBarItems = Set(items)
        } else {
            statusBarItems = []
        }

        if let raw = defaults.string(forKey: "popoverSize"),
           let size = PopoverSize(rawValue: raw) {
            popoverSize = size
        } else {
            popoverSize = .medium
        }

        if let raw = defaults.string(forKey: "refreshInterval"),
           let interval = RefreshInterval(rawValue: Double(raw) ?? 5.0) {
            refreshInterval = interval
        } else {
            refreshInterval = .five
        }

        if let raw = defaults.object(forKey: "hotkeyCode") as? Int {
            hotkeyCode = UInt16(raw)
        } else {
            hotkeyCode = 80  // F19
        }

        if let raw = defaults.object(forKey: "hotkeyModifiers") as? UInt {
            hotkeyModifiers = raw
        } else {
            hotkeyModifiers = 0
        }

        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func save() {
        defaults.set(language.rawValue, forKey: "language")
        if let data = try? JSONEncoder().encode(Array(statusBarItems)) {
            defaults.set(data, forKey: "statusBarItems")
        }
        defaults.set(popoverSize.rawValue, forKey: "popoverSize")
        defaults.set(String(refreshInterval.rawValue), forKey: "refreshInterval")
        defaults.set(Int(hotkeyCode), forKey: "hotkeyCode")
        defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
    }
}
