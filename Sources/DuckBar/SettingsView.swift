import SwiftUI

struct SettingsView: View {
    let settings: AppSettings
    var onHelp: (() -> Void)? = nil
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L.settings)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button(action: { onHelp?() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                // Language
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.language)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                                let isSelected = settings.language == lang
                                Button(action: { settings.language = lang }) {
                                    Text(lang.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isSelected
                                                      ? Color.accentColor
                                                      : Color.primary.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Popover Size
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.popoverSize)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            ForEach(PopoverSize.allCases, id: \.rawValue) { size in
                                let isSelected = settings.popoverSize == size
                                Button(action: { settings.popoverSize = size }) {
                                    Text(size.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isSelected
                                                      ? Color.accentColor
                                                      : Color.primary.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Launch at Login
                    HStack {
                        Label {
                            Text(L.launchAtLogin)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: "power")
                                .font(.system(size: 10))
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.launchAtLogin = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Refresh Interval
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.refreshInterval)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(RefreshInterval.allCases, id: \.rawValue) { interval in
                                let isSelected = settings.refreshInterval == interval
                                Button(action: { settings.refreshInterval = interval }) {
                                    Text(interval.displayName)
                                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isSelected
                                                      ? Color.accentColor
                                                      : Color.primary.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Status bar items
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text(L.statusBarDisplay)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        VStack(spacing: 2) {
                            ForEach(StatusBarItem.allCases) { item in
                                let isOn = settings.statusBarItems.contains(item)
                                Button(action: {
                                    if isOn {
                                        settings.statusBarItems.remove(item)
                                    } else {
                                        settings.statusBarItems.insert(item)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(isOn ? .green : .secondary)

                                        Text(item.label(settings.language))
                                            .font(.system(size: 12))

                                        Spacer()

                                        // 미리보기
                                        Text(previewText(for: item))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isOn ? Color.green.opacity(0.08) : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: settings.popoverSize.width)
    }

    private func previewText(for item: StatusBarItem) -> String {
        switch item {
        case .rateLimit: "5h 42%"
        case .weeklyRateLimit: "1w 68%"
        case .tokens: "12.3K"
        case .weeklyTokens: "1.2M"
        case .cost: "$1.23"
        case .weeklyCost: "$15.40"
        case .context: "ctx 65%"
        }
    }
}
