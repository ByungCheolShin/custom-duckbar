import Foundation
import Observation

@Observable
@MainActor
final class SessionMonitor {
    /// 전체(모든 환경) 집계된 세션
    var sessions: [ClaudeSession] = []
    /// 전체(모든 환경) 집계 통계. 하위 호환용 alias — 기존 코드는 usageStats만 참조.
    var usageStats = UsageStats()
    /// 활성화된 환경 목록 (표시 순서)
    var environments: [ClaudeEnvironment] = []
    /// 환경별 통계 (env.id → stats)
    var envStats: [String: UsageStats] = [:]
    /// 환경별 세션 목록 (env.id → sessions)
    var envSessions: [String: [ClaudeSession]] = [:]
    /// Claude 계정별 Rate Limit 목록 (계정 단위, 환경 무관)
    var accountRateLimits: [AccountRateLimit] = []
    /// 계정별 합산 통계 (account.id → 그 계정의 모든 환경을 합친 UsageStats)
    var accountStats: [String: UsageStats] = [:]

    var lastRefresh = Date()
    var isLoading = false

    var alertsEnabled: Bool = true
    var alertThresholds: [Double] = [50, 80, 90]

    private var timer: Timer?
    private var heavyTimer: Timer?
    @ObservationIgnored private var discoveries: [String: SessionDiscovery] = [:]
    @ObservationIgnored private var fileWatchers: [String: DispatchSourceFileSystemObject] = [:]
    @ObservationIgnored private var fileDescriptors: [String: Int32] = [:]
    @ObservationIgnored private var debounceWorkItem: DispatchWorkItem?
    private var currentInterval: TimeInterval = 5.0

    /// 환경별 설정을 외부(AppSettings)에서 읽어오기 위한 콜백 주입
    var environmentOverrideProvider: (() -> [String: EnvironmentOverride])?

    var aggregateState: SessionState {
        sessions.map(\.state).max(by: { $0.priority < $1.priority }) ?? .idle
    }

    func start(interval: TimeInterval = 5.0) {
        rebuildEnvironments()
        refreshSync()
        startFileWatchers()
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

        // 토큰/리밋 데이터는 세션 주기의 6배 (최소 300초 = 5분, CPU 최적화)
        let heavyInterval = max(300.0, interval * 6)
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
        stopFileWatchers()
    }

    /// 외부에서 환경 목록 재계산 요청 (설정 변경 시)
    func rebuildEnvironments() {
        let discovered = ClaudeEnvironment.discoverAll()
        let overrides = environmentOverrideProvider?() ?? [:]

        // override 적용 (alias / enabled)
        let merged: [ClaudeEnvironment] = discovered.map { env in
            var e = env
            if let o = overrides[env.id] {
                e.alias = o.alias
                e.enabled = o.enabled
            }
            return e
        }

        environments = merged

        // discoveries 재구성 (enabled만)
        var newDiscoveries: [String: SessionDiscovery] = [:]
        for env in merged where env.enabled {
            if let existing = discoveries[env.id], existing.env.path == env.path {
                newDiscoveries[env.id] = existing
            } else {
                newDiscoveries[env.id] = SessionDiscovery(env: env)
            }
        }
        discoveries = newDiscoveries

        // 사라진 env의 envStats / envSessions 정리
        let activeIds = Set(newDiscoveries.keys)
        for id in envStats.keys where !activeIds.contains(id) {
            envStats.removeValue(forKey: id)
        }
        for id in envSessions.keys where !activeIds.contains(id) {
            envSessions.removeValue(forKey: id)
        }

        // 파일 감시자 재구성
        stopFileWatchers()
        startFileWatchers()
    }

    /// 세션만 빠르게 갱신 (폴링용)
    func refreshSessionsOnly() {
        var allSessions: [ClaudeSession] = []
        for (id, disc) in discoveries {
            let s = disc.discoverSessions()
            envSessions[id] = s
            allSessions.append(contentsOf: s)
        }
        // 상태 우선순위 + 최신 활동 순
        allSessions.sort { s1, s2 in
            if s1.state.priority != s2.state.priority {
                return s1.state.priority > s2.state.priority
            }
            return s1.lastActivity > s2.lastActivity
        }
        sessions = allSessions
        lastRefresh = Date()
    }

    /// 초기 로드 — 세션만 동기, 통계는 백그라운드
    func refreshSync() {
        refreshSessionsOnly()

        // 무거운 통계는 백그라운드
        let discsSnapshot = discoveries
        let envsSnapshot = environments.filter { $0.enabled }
        Task.detached { [weak self] in
            let result = await Self.loadAllStats(discoveries: discsSnapshot, environments: envsSnapshot)
            await MainActor.run { [weak self] in
                self?.applyLoadResult(result)
            }
        }
    }

    /// 비동기 전체 갱신 — 창/팝오버 열 때 호출
    func refreshAsync() async {
        isLoading = true
        refreshSessionsOnly()

        let discsSnapshot = discoveries
        let envsSnapshot = environments.filter { $0.enabled }
        let result = await Task.detached {
            await Self.loadAllStats(discoveries: discsSnapshot, environments: envsSnapshot)
        }.value

        applyLoadResult(result)
        isLoading = false
        if alertsEnabled {
            UsageAlertManager.shared.check(rateLimits: usageStats.rateLimits, thresholds: alertThresholds)
        }
    }

    private func applyLoadResult(_ result: LoadResult) {
        envStats = result.envStats
        usageStats = result.aggregated
        accountRateLimits = result.accountRateLimits
        accountStats = result.accountStats
        // environments에 accountKey 반영 (설정 화면 표시용)
        for i in 0..<environments.count {
            if let key = result.accountKeys[environments[i].id] {
                environments[i].accountKey = key
            }
        }
    }

    // MARK: - Heavy load pipeline (Sendable 영역)

    private struct LoadResult {
        var envStats: [String: UsageStats]
        var aggregated: UsageStats
        var accountKeys: [String: String]  // env.id → accountKey
        var accountRateLimits: [AccountRateLimit]  // 계정별 rate limit
        var accountStats: [String: UsageStats]  // 계정별 합산 stats
    }

    private static func loadAllStats(
        discoveries: [String: SessionDiscovery],
        environments: [ClaudeEnvironment]
    ) async -> LoadResult {
        // 1. 각 환경의 기본 통계(토큰/컨텍스트/모델/AllTime/Codex)는 각자 수집.
        //    Rate limit 단계는 별도로 조율 — 같은 계정이면 1회만 호출 후 공유.
        var envStatsMap: [String: UsageStats] = [:]
        var accountKeyByEnv: [String: String] = [:]

        // 계정 키 → token 매핑 (대표 토큰 기억)
        var tokenByAccountKey: [String: String] = [:]
        var envsByAccountKey: [String: [String]] = [:]

        // 토큰 먼저 계산 (Rate limit API 중복 제거용)
        for env in environments {
            guard let disc = discoveries[env.id] else { continue }
            if let token = disc.readAccessTokenForAccountKey() {
                let key = ClaudeEnvironment.accountKey(fromToken: token)
                accountKeyByEnv[env.id] = key
                tokenByAccountKey[key] = token
                envsByAccountKey[key, default: []].append(env.id)
            }
        }

        // 환경별 기본 stats 집계 (Rate limit은 기본 로직이 OMC/로컬 캐시 → API 순서이므로 여기서 호출)
        // 같은 계정의 환경 중 "첫 번째(대표)"만 API 호출을 트리거하게끔 한다.
        // 대표가 아닌 환경은 rate limit을 skip.
        var representativeEnvIds = Set<String>()
        for (_, envIds) in envsByAccountKey {
            if let first = envIds.sorted().first { representativeEnvIds.insert(first) }
        }

        for env in environments {
            guard let disc = discoveries[env.id] else { continue }
            var stats = disc.loadUsageStats()
            // 대표가 아닌 환경의 rate limit은 대표에서 복사해올 거라 일단 비움
            if let key = accountKeyByEnv[env.id], !representativeEnvIds.contains(env.id) {
                _ = key
                stats.rateLimits = RateLimits()  // 초기화 (대표에서 나중에 복사)
            }
            envStatsMap[env.id] = stats
        }

        // Rate limit을 계정 단위로 그룹 공유 + 계정별 목록 수집
        var accountRateLimitList: [AccountRateLimit] = []
        var accountStatsMap: [String: UsageStats] = [:]
        let envIdToName = Dictionary(uniqueKeysWithValues: environments.map { ($0.id, $0.displayName) })
        let envIdToEnv = Dictionary(uniqueKeysWithValues: environments.map { ($0.id, $0) })

        for (key, envIds) in envsByAccountKey {
            guard let repId = envIds.sorted().first,
                  let repStats = envStatsMap[repId]
            else { continue }
            let rl = repStats.rateLimits
            for id in envIds where id != repId {
                envStatsMap[id]?.rateLimits = rl
            }

            // 이 계정을 쓰는 환경들의 displayName을 모음 (enabled 여부와 무관하게 토큰이 있는 모든 환경)
            let sortedIds = envIds.sorted()
            let names = sortedIds.compactMap { envIdToName[$0] }
            accountRateLimitList.append(AccountRateLimit(
                id: key,
                environmentIDs: sortedIds,
                environmentNames: names,
                rateLimits: rl
            ))

            // 계정별 stats 합산 — 해당 계정의 모든 환경 envStats를 하나로
            let envsForAccount = sortedIds.compactMap { envIdToEnv[$0] }
            var accStats = aggregate(envStatsMap, environments: envsForAccount)
            accStats.rateLimits = rl  // rate limit은 계정 단위
            accountStatsMap[key] = accStats
        }

        // 계정 표시 순서: 환경 개수 많은 계정 먼저 → 알파벳
        accountRateLimitList.sort { a, b in
            if a.environmentNames.count != b.environmentNames.count {
                return a.environmentNames.count > b.environmentNames.count
            }
            return a.environmentNames.joined() < b.environmentNames.joined()
        }

        // 2. 전체 합산 계산
        let aggregated = aggregate(envStatsMap, environments: environments)

        return LoadResult(
            envStats: envStatsMap,
            aggregated: aggregated,
            accountKeys: accountKeyByEnv,
            accountRateLimits: accountRateLimitList,
            accountStats: accountStatsMap
        )
    }

    /// 환경별 stats들을 하나로 합산
    private static func aggregate(
        _ envStats: [String: UsageStats],
        environments: [ClaudeEnvironment]
    ) -> UsageStats {
        var agg = UsageStats()
        var calculatedAccounts = Set<String>()

        for env in environments where env.enabled {
            guard let s = envStats[env.id] else { continue }

            // 토큰/비용/차트/all-time은 단순 합산
            agg.fiveHourTokens.inputTokens += s.fiveHourTokens.inputTokens
            agg.fiveHourTokens.outputTokens += s.fiveHourTokens.outputTokens
            agg.fiveHourTokens.cacheCreationTokens += s.fiveHourTokens.cacheCreationTokens
            agg.fiveHourTokens.cacheReadTokens += s.fiveHourTokens.cacheReadTokens
            agg.fiveHourTokens.requestCount += s.fiveHourTokens.requestCount

            agg.oneWeekTokens.inputTokens += s.oneWeekTokens.inputTokens
            agg.oneWeekTokens.outputTokens += s.oneWeekTokens.outputTokens
            agg.oneWeekTokens.cacheCreationTokens += s.oneWeekTokens.cacheCreationTokens
            agg.oneWeekTokens.cacheReadTokens += s.oneWeekTokens.cacheReadTokens
            agg.oneWeekTokens.requestCount += s.oneWeekTokens.requestCount

            agg.allTimeTokens += s.allTimeTokens
            agg.allTimeCostUSD += s.allTimeCostUSD

            // Codex는 default 환경에서만 집계되므로 그대로 복사
            if env.isDefault {
                agg.codexFiveHourTokens = s.codexFiveHourTokens
                agg.codexOneWeekTokens = s.codexOneWeekTokens
                agg.codexRateLimits = s.codexRateLimits
                agg.codexHourlyData = s.codexHourlyData
                agg.codexWeeklyHourlyData = s.codexWeeklyHourlyData
            }

            // 시간별 차트 데이터 합산 (같은 hour 키로 병합)
            mergeHourly(into: &agg.hourlyData, with: s.hourlyData)
            mergeHourly(into: &agg.weeklyHourlyData, with: s.weeklyHourlyData)

            // 컨텍스트는 가장 최근 값 — 단일 수치이므로 default 환경 우선
            if env.isDefault {
                agg.contextInfo = s.contextInfo
            } else if agg.contextInfo.currentInputTokens == 0 {
                agg.contextInfo = s.contextInfo
            }

            // 모델별 사용량은 shortName으로 재합산
            for mu in s.modelUsages {
                if let idx = agg.modelUsages.firstIndex(where: { $0.shortName == mu.shortName }) {
                    agg.modelUsages[idx].inputTokens += mu.inputTokens
                    agg.modelUsages[idx].outputTokens += mu.outputTokens
                    agg.modelUsages[idx].cacheCreationTokens += mu.cacheCreationTokens
                    agg.modelUsages[idx].cacheReadTokens += mu.cacheReadTokens
                } else {
                    agg.modelUsages.append(mu)
                }
            }

            // Rate limit은 계정별 1회만 반영 (가장 높은 사용률 선택)
            if s.rateLimits.isLoaded {
                let key = env.accountKey ?? env.id
                if !calculatedAccounts.contains(key) {
                    calculatedAccounts.insert(key)
                    // 첫 계정: 그대로 반영
                    if !agg.rateLimits.isLoaded {
                        agg.rateLimits = s.rateLimits
                    } else {
                        // 여러 계정이 있으면 가장 높은 사용률로
                        agg.rateLimits.fiveHourPercent = max(agg.rateLimits.fiveHourPercent, s.rateLimits.fiveHourPercent)
                        agg.rateLimits.weeklyPercent = max(agg.rateLimits.weeklyPercent, s.rateLimits.weeklyPercent)
                    }
                }
            }
        }

        agg.modelUsages.sort { $0.totalTokens > $1.totalTokens }
        return agg
    }

    private static func mergeHourly(into dest: inout [HourlyTokenData], with src: [HourlyTokenData]) {
        var map = Dictionary(uniqueKeysWithValues: dest.map { ($0.hour, $0) })
        for item in src {
            if var existing = map[item.hour] {
                existing.inputTokens += item.inputTokens
                existing.outputTokens += item.outputTokens
                existing.cacheCreationTokens += item.cacheCreationTokens
                existing.cacheReadTokens += item.cacheReadTokens
                existing.requestCount += item.requestCount
                map[item.hour] = existing
            } else {
                map[item.hour] = item
            }
        }
        dest = map.values.sorted { $0.hour < $1.hour }
    }

    // MARK: - File System Watchers (환경별 다중화)

    private func startFileWatchers() {
        for env in environments where env.enabled {
            let sessionsPath = env.path.appendingPathComponent("sessions").path
            let fd = open(sessionsPath, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .delete, .rename],
                queue: .global(qos: .utility)
            )

            source.setEventHandler { [weak self] in
                self?.debounceWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    Task { @MainActor in
                        self?.refreshSessionsOnly()
                    }
                }
                self?.debounceWorkItem = workItem
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0, execute: workItem)
            }

            let capturedFd = fd
            source.setCancelHandler {
                if capturedFd >= 0 { close(capturedFd) }
            }

            fileWatchers[env.id] = source
            fileDescriptors[env.id] = fd
            source.resume()
        }
    }

    private func stopFileWatchers() {
        for (_, source) in fileWatchers {
            source.cancel()
        }
        fileWatchers.removeAll()
        fileDescriptors.removeAll()
    }
}

// MARK: - SessionDiscovery Sendable conformance for Task.detached

extension SessionDiscovery: @unchecked Sendable {}
