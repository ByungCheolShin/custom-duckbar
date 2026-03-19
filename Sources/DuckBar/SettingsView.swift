import SwiftUI
import Carbon.HIToolbox
import CoreServices

struct SettingsView: View {
    let settings: AppSettings
    var onHelp: (() -> Void)? = nil
    let onDone: () -> Void
    @State private var isRecordingHotkey = false

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

                    // Hotkey
                    HStack {
                        Label {
                            Text(L.hotkey)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: "keyboard")
                                .font(.system(size: 10))
                        }

                        Spacer()

                        if isRecordingHotkey {
                            Text(L.hotkeyRecord)
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .strokeBorder(Color.orange, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    isRecordingHotkey = false
                                    NotificationCenter.default.post(name: .init("StopRecordingHotkey"), object: nil)
                                }
                        } else if settings.hotkeyCode == 0 && settings.hotkeyModifiers == 0 {
                            // 미설정 상태
                            Text(L.lang == .korean ? "설정" : "Set")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 14)
                                .background(
                                    Capsule()
                                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .onTapGesture {
                                    isRecordingHotkey = true
                                    NotificationCenter.default.post(name: .init("StartRecordingHotkey"), object: nil)
                                }
                        } else {
                            // 설정된 상태
                            HStack(spacing: 4) {
                                Text(hotkeyDisplayString())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .onTapGesture {
                                        isRecordingHotkey = true
                                        NotificationCenter.default.post(name: .init("StartRecordingHotkey"), object: nil)
                                    }

                                Button(action: {
                                    settings.hotkeyCode = 0
                                    settings.hotkeyModifiers = 0
                                    NotificationCenter.default.post(name: .init("HotkeyChanged"), object: nil)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 5)
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .init("HotkeyRecorded"))) { _ in
                        isRecordingHotkey = false
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

    private func hotkeyDisplayString() -> String {
        let code = settings.hotkeyCode
        let mods = NSEvent.ModifierFlags(rawValue: settings.hotkeyModifiers)
        if code == 0 && settings.hotkeyModifiers == 0 { return "—" }

        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        parts.append(keyName(for: code))
        return parts.joined()
    }

    private func keyName(for code: UInt16) -> String {
        // 비인쇄 키만 하드코딩
        let special: [UInt16: String] = [
            // Function keys (UCKeyTranslate가 PUA 문자를 반환하므로 직접 매핑)
            62: "F1", 63: "F2", 64: "F3", 65: "F4", 66: "F5", 67: "F6",
            68: "F7", 69: "F8", 70: "F9", 71: "F10", 72: "F11", 73: "F12",
            74: "F13", 75: "F14", 76: "F15", 77: "F16", 78: "F17", 79: "F18", 80: "F19",
            // 특수 키
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc", 117: "⌦",
            // 방향 키
            123: "←", 124: "→", 125: "↓", 126: "↑",
            // 내비게이션
            115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
        ]
        if let name = special[code] { return name }

        // 나머지: UCKeyTranslate로 현재 키보드 레이아웃에서 자동 변환
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let rawPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(code)"
        }
        let layoutData = unsafeBitCast(rawPtr, to: CFData.self) as Data
        var deadKeyState: UInt32 = 0
        let maxChars = 4
        var chars = [UniChar](repeating: 0, count: maxChars)
        var length = 0

        let error = layoutData.withUnsafeBytes { pointer -> OSStatus in
            guard let baseAddress = pointer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return errSecAllocate
            }
            return CoreServices.UCKeyTranslate(
                baseAddress,
                code,
                UInt16(CoreServices.kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(CoreServices.kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                maxChars,
                &length,
                &chars
            )
        }

        guard error == noErr, length > 0 else { return "Key \(code)" }
        return (NSString(characters: &chars, length: length) as String).uppercased()
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
