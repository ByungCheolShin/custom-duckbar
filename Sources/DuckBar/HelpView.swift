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

            VStack(alignment: .leading, spacing: 0) {
                helpSection(title: "사용 한도", items: [
                    ("5h", "5시간 내 API 호출 사용률"),
                    ("1w", "1주일 내 API 호출 사용률"),
                    ("Op", "Opus 모델 주간 사용 한도"),
                    ("So", "Sonnet 모델 주간 사용 한도"),
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
            }
        }
        .frame(width: settings.popoverSize.width)
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
                        .frame(width: 65 * s, alignment: .trailing)

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
