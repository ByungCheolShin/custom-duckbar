import AppKit
import SwiftUI
import Sparkle
import UserNotifications
@preconcurrency import HotKey

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController!
    private var monitor: SessionMonitor!
    private let settings = AppSettings.shared
    private var updaterController: SPUStandardUpdaterController!
    private var hotKey: HotKey?
    private var recordingMonitor: Any?
    private var weeklyReportWindowController: WeeklyReportWindowController?
    private var pendingWeeklyReport: WeeklyReport?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        applyUpdateSettings()
        monitor = SessionMonitor()

        // 항상 Both 모드 강제
        settings.activeProvider = .both

        // 환경 override 읽기 콜백 연결
        monitor.environmentOverrideProvider = { [weak self] in
            self?.settings.environmentOverrides ?? [:]
        }
        monitor.envGroupProvider = { [weak self] in
            self?.settings.claudeEnvGroups ?? [:]
        }
        monitor.groupAliasProvider = { [weak self] in
            self?.settings.claudeGroupAliases ?? [:]
        }

        // 메인 윈도우 준비
        mainWindowController = MainWindowController(monitor: monitor, settings: settings) {
            NSApplication.shared.terminate(nil)
        }

        // 앱 메뉴 설정 (DuckBar > 설정...)
        setupMainMenu()

        // 앱 실행 시 창을 자동으로 한 번 표시
        mainWindowController.show()

        // 알림 권한 요청 및 설정 연결
        monitor.alertsEnabled = settings.usageAlertsEnabled
        monitor.alertThresholds = [settings.alertThreshold1, settings.alertThreshold2, settings.alertThreshold3]
        if settings.usageAlertsEnabled {
            UsageAlertManager.shared.requestPermissionIfNeeded()
        }

        // 주간 리포트 체크 (앱 시작 시)
        WeeklyReportManager.shared.checkAndSend { [weak self] report in
            self?.showWeeklyReport(report)
        }

        // 알림 탭 핸들러
        UNUserNotificationCenter.current().delegate = self

        // 세션 모니터 시작 (설정된 갱신 주기)
        monitor.start(interval: settings.refreshInterval.rawValue)

        // 글로벌 핫키
        setupHotkey()

        // 핫키 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyChanged),
            name: .hotkeyChanged,
            object: nil
        )

        // 핫키 녹음 시작 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startRecordingHotkey),
            name: .startRecordingHotkey,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopRecordingHotkey),
            name: .stopRecordingHotkey,
            object: nil
        )

        // 자동 업데이트 설정 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyUpdateSettings),
            name: .automaticUpdateCheckChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyUpdateSettings),
            name: .automaticUpdateInstallChanged,
            object: nil
        )

        // Claude 환경 override 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(environmentOverridesChanged),
            name: .environmentOverridesChanged,
            object: nil
        )
    }

    @objc private func environmentOverridesChanged() {
        monitor.rebuildEnvironments()
        Task { await monitor.refreshAsync() }
    }

    @objc private func applyUpdateSettings() {
        updaterController.updater.automaticallyChecksForUpdates = settings.automaticUpdateCheck
        updaterController.updater.automaticallyDownloadsUpdates = settings.automaticUpdateInstall
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotKey = nil
    }

    /// Dock 아이콘 클릭 (창이 모두 닫힌 상태에서) → 메인 창 복구
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindowController?.show()
        }
        return true
    }

    @objc private func hotkeyChanged() {
        setupHotkey()
    }

    @objc private func startRecordingHotkey() {
        hotKey = nil

        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let significantMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            if event.keyCode == 53 && significantMods.isEmpty {
                self.finishRecording(keyCode: nil)
                return nil
            }
            self.finishRecording(keyCode: event.keyCode, modifiers: event.modifierFlags)
            return nil
        }
    }

    @objc private func stopRecordingHotkey() {
        if let monitor = recordingMonitor { NSEvent.removeMonitor(monitor) }
        recordingMonitor = nil
        setupHotkey()
    }

    private func finishRecording(keyCode: UInt16?, modifiers: NSEvent.ModifierFlags = []) {
        if let monitor = recordingMonitor { NSEvent.removeMonitor(monitor) }
        recordingMonitor = nil

        if let keyCode {
            settings.hotkeyCode = keyCode
            settings.hotkeyModifiers = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
        }
        setupHotkey()
        NotificationCenter.default.post(name: .hotkeyRecorded, object: nil)
    }

    private func setupHotkey() {
        hotKey = nil

        let keyCode = settings.hotkeyCode
        guard keyCode != 0 || settings.hotkeyModifiers != 0 else { return }

        let modifiers = NSEvent.ModifierFlags(rawValue: settings.hotkeyModifiers)
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.function)

        let hk = HotKey(carbonKeyCode: UInt32(keyCode), carbonModifiers: modifiers.carbonFlags)
        hk.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.toggleMainWindow()
            }
        }
        hotKey = hk
    }

    // MARK: - 앱 메뉴

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // DuckBar 앱 메뉴
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: L.about, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L.settings + "...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)

        mainMenu.addItem(appMenuItem)

        // Window 메뉴
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsAction() {
        mainWindowController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }

    private func toggleMainWindow() {
        mainWindowController.toggle()

        if mainWindowController.isVisible {
            Task {
                await monitor.refreshAsync()
            }
        }
    }

    // MARK: - 주간 리포트 표시

    func showWeeklyReport(_ report: WeeklyReport) {
        weeklyReportWindowController = WeeklyReportWindowController(report: report)
        weeklyReportWindowController?.show()
    }
}

// MARK: - UNUserNotificationCenterDelegate

@MainActor
extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let type = response.notification.request.content.userInfo["type"] as? String
        if type == "weeklyReport", let report = pendingWeeklyReport {
            showWeeklyReport(report)
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
