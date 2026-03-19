import SwiftUI

struct SessionRowView: View {
    let session: ClaudeSession
    let fontScale: CGFloat

    init(session: ClaudeSession, fontScale: CGFloat = 1.0) {
        self.session = session
        self.fontScale = fontScale
    }

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // 상태 표시 점
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)

                // 프로젝트 이름 + IDE
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(session.projectName)
                            .font(.system(size: 13 * fontScale, weight: .medium))
                            .lineLimit(1)

                        if let model = session.modelName {
                            Text(shortModelName(model))
                                .font(.system(size: 9 * fontScale, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(modelColor(model).opacity(0.8))
                                .cornerRadius(3)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(session.source.label)
                            .font(.system(size: 10 * fontScale))
                            .foregroundStyle(.secondary)

                        if let lastTool = session.lastTool {
                            Text("·")
                                .font(.system(size: 8 * fontScale))
                                .foregroundStyle(.tertiary)
                            Text(lastTool)
                                .font(.system(size: 10 * fontScale))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // 상태 + 시간
                VStack(alignment: .trailing, spacing: 1) {
                    Text(session.state.label)
                        .font(.system(size: 11 * fontScale))
                        .foregroundStyle(stateColor)

                    Text(session.timeSinceActivity)
                        .font(.system(size: 10 * fontScale))
                        .foregroundStyle(.secondary)
                }
            }

            // 도구 분포 미니 바
            if !session.toolCounts.isEmpty && session.toolCallCount > 0 {
                toolDistributionBar
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(session.workingDirectory)
    }

    // MARK: - Tool Distribution Bar

    private var toolDistributionBar: some View {
        let sorted = session.toolCounts.sorted { $0.value > $1.value }
        let total = Double(session.toolCallCount)

        return HStack(spacing: 1) {
            ForEach(sorted.prefix(5), id: \.key) { tool, count in
                let ratio = Double(count) / total
                RoundedRectangle(cornerRadius: 2)
                    .fill(toolColor(tool))
                    .frame(maxWidth: .infinity)
                    .frame(
                        width: max(4, ratio * 200),
                        height: 4
                    )
                    .help("\(tool) \(Int(ratio * 100))%")
            }
            Spacer(minLength: 0)
            Text("\(session.toolCallCount)")
                .font(.system(size: 8 * fontScale, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 6)
        .padding(.leading, 16)
    }

    // MARK: - Helpers

    private func shortModelName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(8))
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }

    private func toolColor(_ tool: String) -> Color {
        switch tool {
        case "Read": .blue
        case "Edit", "Write": .green
        case "Bash": .orange
        case "Grep", "Glob": .purple
        case "Agent": .red
        case "Skill": .pink
        default: .gray
        }
    }

    private var dotColor: Color {
        switch session.state {
        case .active: .green
        case .waiting: .orange
        case .compacting: .blue
        case .idle: .gray
        }
    }

    private var stateColor: Color {
        switch session.state {
        case .active: .green
        case .waiting: .orange
        case .compacting: .blue
        case .idle: .secondary
        }
    }
}
