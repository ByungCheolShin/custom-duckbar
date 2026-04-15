import AppKit
import SwiftUI

// MARK: - Main Window Controller

/// 메인 콘텐츠(StatusMenuView)를 표시하는 독립 윈도우 컨트롤러.
/// 기존 NSPopover를 대체.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let monitor: SessionMonitor
    private let settings: AppSettings
    private let onQuit: () -> Void

    /// 창이 닫혔음을 AppDelegate에 알리기 위한 콜백
    var onClose: (() -> Void)?

    init(monitor: SessionMonitor, settings: AppSettings, onQuit: @escaping () -> Void) {
        self.monitor = monitor
        self.settings = settings
        self.onQuit = onQuit

        let defaultSize = NSSize(width: settings.popoverSize.width,
                                 height: settings.popoverSize.height)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DuckBar"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.setContentSize(defaultSize)
        window.minSize = NSSize(width: 300, height: 400)
        window.collectionBehavior = [.fullScreenAuxiliary]

        super.init(window: window)

        window.delegate = self

        // 콘텐츠 연결 (SwiftUI 그대로 재사용)
        let rootView = StatusMenuView(monitor: monitor, settings: settings, onQuit: onQuit)
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView

        // 저장된 프레임 복원
        if let frameString = settings.mainWindowFrame {
            window.setFrame(NSRectFromString(frameString), display: true)
        } else {
            window.center()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 창 표시 (없으면 표시, 있으면 최상단으로)
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 창 토글 (표시 중이면 숨기고, 아니면 표시)
    func toggle() {
        guard let window else { return }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    /// 창이 현재 표시 중인지
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        saveFrame()
        onClose?()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        guard let window else { return }
        settings.mainWindowFrame = NSStringFromRect(window.frame)
    }
}
