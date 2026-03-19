import Foundation
import Observation

@Observable
@MainActor
final class SessionMonitor {
    var sessions: [ClaudeSession] = []
    var usageStats = UsageStats()
    var lastRefresh = Date()
    var isLoading = false

    private var timer: Timer?
    private var heavyTimer: Timer?
    private let discovery = SessionDiscovery()
    @ObservationIgnored private var fileWatcher: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var currentInterval: TimeInterval = 5.0

    var aggregateState: SessionState {
        sessions.map(\.state).max(by: { $0.priority < $1.priority }) ?? .idle
    }

    func start(interval: TimeInterval = 5.0) {
        refreshSync()
        startFileWatcher()
        restartTimers(interval: interval)
    }

    func restartTimers(interval: TimeInterval) {
        timer?.invalidate()
        heavyTimer?.invalidate()
        currentInterval = interval

        // 세션 상태 폴링 (설정 주기)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSessionsOnly()
            }
        }

        // 토큰/리밋 데이터는 세션 주기의 6배 (최소 30초)
        let heavyInterval = max(30.0, interval * 6)
        heavyTimer = Timer.scheduledTimer(withTimeInterval: heavyInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAsync()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        heavyTimer?.invalidate()
        heavyTimer = nil
        stopFileWatcher()
    }

    /// 세션만 빠르게 갱신 (폴링용)
    func refreshSessionsOnly() {
        sessions = discovery.discoverSessions()
        lastRefresh = Date()
    }

    /// 동기 전체 갱신 (초기 로드)
    func refreshSync() {
        sessions = discovery.discoverSessions()
        usageStats = discovery.loadUsageStats()
        lastRefresh = Date()
    }

    /// 비동기 전체 갱신 (팝오버 열 때, 무거운 데이터 백그라운드 로드)
    func refreshAsync() async {
        isLoading = true
        // 세션은 즉시 갱신
        sessions = discovery.discoverSessions()
        lastRefresh = Date()

        // 토큰/리밋은 백그라운드에서
        let disc = discovery
        let usage = await Task.detached {
            disc.loadUsageStats()
        }.value

        usageStats = usage
        isLoading = false
    }

    // MARK: - File System Watcher

    private func startFileWatcher() {
        let sessionsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions").path

        fileDescriptor = open(sessionsPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.refreshSessionsOnly()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }

        fileWatcher = source
        source.resume()
    }

    private func stopFileWatcher() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }
}
