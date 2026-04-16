import Foundation

/// 과거 Rate Limit % 스냅샷을 파일에 누적 저장.
/// 저장 경로: ~/Library/Application Support/DuckBar/usage-history.jsonl
/// 각 줄은 UsageSnapshot의 JSON.
final class UsageHistoryStore: @unchecked Sendable {
    static let shared = UsageHistoryStore()

    /// 7일 초과 데이터는 자동 정리
    private let retentionSeconds: TimeInterval = 7 * 24 * 3600

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.duckbar.usage-history", qos: .utility)

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent("Library/Application Support/DuckBar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("usage-history.jsonl")
    }

    // MARK: - Codable

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - 공개 API

    /// 스냅샷 추가 (비동기, 파일 I/O는 백그라운드)
    func append(_ snapshot: UsageSnapshot) {
        queue.async { [fileURL] in
            guard let data = try? Self.encoder.encode(snapshot),
                  let line = String(data: data, encoding: .utf8)
            else { return }
            let lineData = (line + "\n").data(using: .utf8)!

            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fh = try? FileHandle(forWritingTo: fileURL) {
                    fh.seekToEndOfFile()
                    fh.write(lineData)
                    try? fh.close()
                }
            } else {
                try? lineData.write(to: fileURL)
            }
        }
    }

    /// provider + account 기준으로 since 이후의 스냅샷만 반환 (시간순)
    func load(provider: String, account: String, since: Date) -> [UsageSnapshot] {
        queue.sync { [fileURL] in
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
            var result: [UsageSnapshot] = []
            for line in content.components(separatedBy: .newlines) {
                guard !line.isEmpty,
                      let data = line.data(using: .utf8),
                      let snap = try? Self.decoder.decode(UsageSnapshot.self, from: data),
                      snap.provider == provider,
                      snap.account == account,
                      snap.timestamp >= since
                else { continue }
                result.append(snap)
            }
            return result.sorted { $0.timestamp < $1.timestamp }
        }
    }

    /// 오래된 레코드 정리 — 파일 전체 재작성
    func cleanup() {
        queue.async { [fileURL, retentionSeconds] in
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
            let cutoff = Date().addingTimeInterval(-retentionSeconds)
            var kept: [String] = []
            for line in content.components(separatedBy: .newlines) {
                guard !line.isEmpty,
                      let data = line.data(using: .utf8),
                      let snap = try? Self.decoder.decode(UsageSnapshot.self, from: data)
                else { continue }
                if snap.timestamp >= cutoff {
                    kept.append(line)
                }
            }
            let output = kept.joined(separator: "\n") + "\n"
            try? output.data(using: .utf8)?.write(to: fileURL)
        }
    }
}
