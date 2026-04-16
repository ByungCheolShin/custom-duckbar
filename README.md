# DuckBar (Custom Fork)

> **이 레포지토리는 [rofeels/duckbar](https://github.com/rofeels/duckbar)를 fork하여 개인 사용 목적으로 수정한 버전입니다.**
> 원본 프로젝트의 기능을 기반으로 하되, 대시보드 스타일의 독립 창 앱으로 전면 개편하였습니다.

![macOS 14+](https://img.shields.io/badge/macOS-14+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 원본과의 차이점

### 추가된 기능

- **멀티 Claude 환경 지원**: `~/.claude-*` 폴더를 자동 발견하여 여러 Claude Code 환경을 동시 모니터링
- **멀티 Codex 환경 지원**: `~/.codex-*` 폴더를 자동 발견, `auth.json`에서 계정 자동 식별 (이메일 자동 라벨)
- **계정별 Rate Limit 관리**: Claude는 OAuth 토큰 기반, Codex는 `account_id` 기반으로 계정을 식별하고 중복 제거
- **Rate Limit 시계열 차트**: 5시간/1주 사용률을 시간축 라인 차트로 시각화 (선형 예측 포함)
- **Rate Limit 히트맵**: 7일 x 24시간 사용률 패턴을 히트맵으로 표시
- **계정별 대시보드 카드**: Claude/Codex 모두 계정별 고정 크기 카드 (사용한도 + 라인차트 + 히트맵), 가로 스크롤로 탐색

### 변경된 기능

- **독립 창 앱**: 메뉴바 팝오버 방식에서 일반 macOS 윈도우 앱으로 전환
- **Dock 표시**: Cmd+Tab 앱 전환기에 표시, Dock 아이콘 클릭으로 창 복구
- **창 자유 리사이즈**: 고정 크기 제거, 모든 콘텐츠가 창 크기에 반응
- **설정 간소화**: 불필요한 설정 항목 제거 (팝오버 크기, 차트 옵션, 상태바 표시 등)

### 제거된 기능

- 상태표시줄(메뉴바) 아이콘 및 관련 코드
- 세션 목록 UI (활성 세션 표시)
- 토큰 사용량 박스 (In/Out/C.Wr/C.Rd)
- 모델별 사용량 섹션
- 컨텍스트 창 모니터링
- 뱃지/마일스톤/업적 시스템
- 공유 카드 (스냅샷 내보내기)
- 알림 이력 화면 (알림 기능 자체는 유지)

## 요구 사항

- **macOS 14 (Sonoma)** 이상
- **Apple Silicon (arm64)** 및 **Intel (x86_64)** 모두 지원

## 빌드

```bash
git clone https://github.com/ByungCheolShin/custom-duckbar.git
cd custom-duckbar
./build.sh
open .build/app/DuckBar.app
```

## 사용 방법

1. 앱 실행 시 대시보드 창이 자동으로 열림
2. 계정별 카드를 가로 스크롤로 탐색
3. 우상단 🔄 새로고침, ⚙ 설정
4. 글로벌 핫키로 창 토글 (설정에서 지정)
5. Dock 아이콘 클릭으로 창 복구

## 설정 항목

| 설정 | 설명 |
|------|------|
| Provider | Claude / Codex / Both 선택 |
| Claude 환경 | 멀티 환경 별칭 및 활성화 관리 |
| Claude 계정 | 계정별 별칭 지정 |
| 언어 | 한국어 / English |
| 로그인 시 실행 | 시스템 시작 시 자동 실행 |
| 남은 시간 일 단위 | 리셋 시간을 일/시간 형식으로 표시 |
| 사용량 알림 | 임계값(50%/80%/90%) 도달 시 macOS 알림 |
| 자동 업데이트 | 업데이트 확인 및 자동 설치 |
| 핫키 | 글로벌 단축키로 창 토글 |
| 갱신 주기 | 데이터 폴링 간격 (1초 ~ 5분) |

## 라이선스

MIT License — [LICENSE](LICENSE) 참조

## 원본 프로젝트

- **원본**: [rofeels/duckbar](https://github.com/rofeels/duckbar)
- **원작자**: [@rofeels](https://github.com/rofeels)
