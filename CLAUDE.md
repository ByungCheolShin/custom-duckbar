# DuckBar 프로젝트 가이드

## 빌드 및 배포

### 개발 중 (debug)

바이너리만 복사하되, Sparkle.framework는 이미 `/Applications/DuckBar.app/Contents/Frameworks/`에 있어야 한다:

```bash
swift build && pkill -x DuckBar; sleep 1; cp ".build/debug/DuckBar" "/Applications/DuckBar.app/Contents/MacOS/DuckBar" && codesign --force --deep --sign - /Applications/DuckBar.app && open /Applications/DuckBar.app
```

### 릴리스 빌드

Sparkle.framework 포함 앱 번들 전체를 생성한다:

```bash
./build.sh
pkill -x DuckBar; sleep 1
cp -R .build/app/DuckBar.app /Applications/
open /Applications/DuckBar.app
```

## 아키텍처

- **UI**: NSPopover (시스템 기본) + SwiftUI (NSHostingController)
- **팝오버 크기**: `sizingOptions = [.preferredContentSize]`로 SwiftUI 콘텐츠에 맞게 자동 조정
- **appearance**: 시스템 라이트/다크 모드 자동 추적 (강제 설정 없음)
