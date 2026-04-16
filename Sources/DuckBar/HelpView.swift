import SwiftUI

struct HelpView: View {
    let settings: AppSettings
    let onDone: () -> Void

    private var s: CGFloat { settings.popoverSize.fontScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11 * s, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L.help)
                    .font(.system(size: 13 * s, weight: .semibold))

                Spacer()

                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if L.lang == .korean {
                    helpSection(title: "사용 한도", items: [
                        ("5h", "5시간 내 API 호출 사용률"),
                        ("1w", "1주일 내 API 호출 사용률"),
                        ("Op", "Opus 모델 주간 사용 한도"),
                        ("So", "Sonnet 모델 주간 사용 한도"),
                        ("Ex", "추가 사용량 (한도 초과 시 유료)"),
                        ("↻", "한도 리셋까지 남은 시간"),
                    ])
                    Divider()
                    helpSection(title: "토큰 통계", items: [
                        ("In", "입력 토큰 (프롬프트)"),
                        ("Out", "출력 토큰 (응답)"),
                        ("C.Wr", "캐시 생성 토큰"),
                        ("C.Rd", "캐시 읽기 토큰"),
                        ("캐시 적중", "전체 입력 대비 캐시 활용 비율"),
                    ])
                    Divider()
                    helpSection(title: "아이콘 색상", items: [
                        ("🟢 녹색", "활성 — Claude가 작업 중"),
                        ("🟠 주황", "대기 — 사용자 입력 대기"),
                        ("🔵 파랑", "압축 — 컨텍스트 정리 중"),
                        ("⚪ 회색", "유휴 — 비활성 세션"),
                    ])
                    Divider()
                    helpSection(title: "조작법", items: [
                        ("좌클릭", "상태 팝오버 열기/닫기"),
                        ("우클릭", "빠른 메뉴 (갱신/설정/종료)"),
                        ("ctx", "컨텍스트 창 사용률 (%)"),
                    ])
                } else {
                    helpSection(title: "Rate Limits", items: [
                        ("5h", "5-hour API usage rate"),
                        ("1w", "7-day API usage rate"),
                        ("Op", "Opus weekly limit"),
                        ("So", "Sonnet weekly limit"),
                        ("Ex", "Extra usage (paid beyond limit)"),
                        ("↻", "Time until limit resets"),
                    ])
                    Divider()
                    helpSection(title: "Token Stats", items: [
                        ("In", "Input tokens (prompt)"),
                        ("Out", "Output tokens (response)"),
                        ("C.Wr", "Cache write tokens"),
                        ("C.Rd", "Cache read tokens"),
                        ("Cache Hit", "Cache usage vs total input"),
                    ])
                    Divider()
                    helpSection(title: "Icon Colors", items: [
                        ("🟢 Green", "Active — Claude is working"),
                        ("🟠 Orange", "Waiting — awaiting input"),
                        ("🔵 Blue", "Compacting — context cleanup"),
                        ("⚪ Gray", "Idle — inactive session"),
                    ])
                    Divider()
                    helpSection(title: "Controls", items: [
                        ("Left click", "Show/hide main window"),
                        ("Right click", "Quick menu (refresh/settings/quit)"),
                        ("ctx", "Context window usage (%)"),
                    ])
                }
            }
            } // ScrollView
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 8) {
                Spacer()
                Link(destination: URL(string: "https://www.youtube.com/@ai.lebuilder")!) {
                    Label("YouTube", systemImage: "play.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Text("·")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))

                Link(destination: URL(string: "https://ctee.kr/place/lebuilder")!) {
                    Label(L.lang == .korean ? "후원" : "Support", systemImage: "cup.and.saucer.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }

    private func helpSection(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12 * s, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(items, id: \.0) { label, desc in
                HStack(alignment: .top, spacing: 8) {
                    Text(label)
                        .font(.system(size: 12 * s, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: (L.lang == .korean ? 65 : 85) * s, alignment: .trailing)

                    Text(desc)
                        .font(.system(size: 12 * s))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
