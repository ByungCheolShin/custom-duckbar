import AppKit

@MainActor
@main
struct Main {
    static func main() {
        // 싱글 인스턴스 보장
        guard let bundleID = Bundle.main.bundleIdentifier else {
            // 번들 없이 실행 시 (swift build) 그냥 실행
            launchApp()
            return
        }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            let me = ProcessInfo.processInfo.processIdentifier
            if let other = running.first(where: { $0.processIdentifier != me }) {
                other.activate()
            }
            exit(0)
        }
        launchApp()
    }

    private static func launchApp() {
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // 메뉴바 전용, Dock에 표시 안 함
        app.run()
    }
}
