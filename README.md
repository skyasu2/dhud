# DHUD Lite

[DHUD](https://www.curseforge.com/wow/addons/dhud) 애드온을 **WoW 12.0.0(Midnight)**에서 동작하도록 리팩토링한 경량 HUD 애드온.
원본 DHUD의 UI/UX를 유지하면서, deprecated API 제거, Ace3 의존성 탈피, Secret Values 호환을 적용했습니다.

![Interface](https://img.shields.io/badge/Interface-120000-blue)
![Version](https://img.shields.io/badge/Version-1.0.1-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Why DHUD Lite?

원본 DHUD는 다음 이유로 WoW 12.0.0에서 동작하지 않습니다:
- **Ace3 라이브러리 의존** — AceDB, AceGUI, AceConfig 등 외부 라이브러리 필수
- **deprecated WoW API 사용** — `UnitIsTapped()`, `GetComboPoints()`, `table.getn()` 등
- **Secret Values 미지원** — 12.0.0의 보안 정책(체력/마나 값 Secret Value 반환)에 대응 불가

| | DHUD (원본) | DHUD Lite |
|---|---|---|
| 파일 규모 | 54파일, ~21,000줄 | 27파일, ~4,700줄 |
| 외부 의존성 | Ace3, LibStub, LibSharedMedia | 없음 |
| OOP | MCCreateClass (58줄) | CreateClass (12줄) |
| 이벤트 시스템 | MADCATEventDispatcher (860줄) | EventBus (40줄) |
| 설정 저장 | AceDB 기반 복잡한 계층 | 플랫 테이블 + SavedVariables |
| WoW 버전 | 다중 버전 호환 | 12.0.0 전용 |
| Secret Values | 미지원 | StatusBar + C_CurveUtil 렌더링 |
| 자원 색상 | 하드코딩 | WoW API 직접 사용 (새 자원 타입 자동 지원) |

## Features

- **커브드 바** — SetTexCoord + SetHeight로 구현한 곡선형 체력/파워 바
- **체력 레이어** — 쉴드, 흡수, 피해 감소, 힐 예측 레이어 지원
- **캐스트 바** — 플레이어 + 타겟 캐스팅/채널링/임파워 표시
- **클래스 리소스** — 콤보 포인트, DK 룬 등 클래스별 리소스
- **유닛 정보** — 레벨, 분류(엘리트/보스), 이름, 반응 색상
- **알파 페이드** — 전투 > 타겟 > 휴식 > 대기 우선순위로 투명도 자동 전환
- **Secret Values 호환** — StatusBar + C_CurveUtil 기반 렌더링 (IceHUD 패턴)
- **API-first 색상** — `C_PowerBarColor`, `C_ClassColor` 등 WoW API를 직접 사용하여 새 직업/자원 타입 자동 대응
- **옵션 UI** — `/dhudlite options`로 인게임 설정 패널 열기

## Installation

1. [Releases](https://github.com/skyasu2/dhud/releases) 또는 소스를 다운로드
2. `DHUDLITE/` 폴더를 WoW 설치 경로의 `Interface/AddOns/`에 복사
3. 캐릭터 선택 화면에서 애드온 활성화

```
World of Warcraft/
  _retail_/
    Interface/
      AddOns/
        DHUDLITE/    <-- 여기에 복사
```

## Slash Commands

| 명령어 | 설명 |
|--------|------|
| `/dhudlite` 또는 `/dhud` | 사용 가능한 명령어 목록 표시 |
| `/dhudlite options` | 옵션 UI 열기 |
| `/dhudlite visible on\|off` | HUD 강제 표시/숨기기 |
| `/dhudlite move on\|off` | HUD 이동 모드 토글 |
| `/dhudlite reset` | 모든 설정 초기화 후 UI 리로드 |
| `/dhudlite debug` | Secret Values 진단 정보 출력 |

## Project Structure

```
DHUDLITE/
├── Core.lua              -- CreateClass OOP, EventBus, 유틸리티
├── Settings.lua          -- SavedVariables 기반 설정 관리
├── AlphaManager.lua      -- 상태별 투명도 전환 (전투/타겟/휴식/대기)
├── HUDManager.lua        -- 슬롯-트래커 배선 및 활성화
├── Main.lua              -- 부팅 시퀀스, 슬래시 커맨드
├── Options.lua           -- 인게임 옵션 UI
├── Data/
│   ├── TrackerHelper.lua     -- OnUpdate 타이머, 전투/탈것 상태 추적
│   ├── HealthTracker.lua     -- 체력 + 쉴드/흡수/힐예측 추적
│   ├── PowerTracker.lua      -- 마나/분노/기력 등 파워 추적
│   ├── CastTracker.lua       -- 캐스팅/채널링/임파워 추적
│   ├── ComboTracker.lua      -- 콤보 포인트 및 클래스 리소스
│   └── UnitInfoTracker.lua   -- 레벨, 분류, 이름, 반응 색상
├── GUI/
│   ├── Textures.lua          -- 텍스처 경로 및 좌표 테이블
│   ├── FrameFactory.lua      -- 프레임/텍스처/폰트스트링 생성
│   ├── Colorize.lua          -- API 기반 색상 (파워/클래스/그라디언트)
│   ├── TextFormat.lua        -- 숫자/퍼센트 포맷팅
│   ├── BarRenderer.lua       -- 커브드 바 렌더링 (StatusBar 이중 렌더러)
│   ├── CastBarRenderer.lua   -- 캐스트 바 전용 렌더러
│   ├── EllipseMath.lua       -- 타원 좌표 계산
│   └── Layout.lua            -- 프레임 계층 구조 생성
└── Slots/
    ├── SlotBase.lua          -- 슬롯 베이스 클래스
    ├── BarSlot.lua           -- 체력/마나 바 슬롯
    ├── CastBarSlot.lua       -- 캐스트 바 슬롯
    ├── ResourceSlot.lua      -- 콤보/룬 리소스 슬롯
    ├── UnitInfoSlot.lua      -- 유닛 정보 텍스트 슬롯
    └── IconSlot.lua          -- PvP/전투/엘리트/레이드 아이콘 슬롯
```

## Secret Values

WoW 12.0.0에서 `UnitHealth()`, `UnitPower()` 등의 반환값이 **Secret Value**로 변경되어 Lua에서 직접 산술/비교가 불가능합니다.

DHUD Lite는 [IceHUD](https://www.curseforge.com/wow/addons/ice-hud)와 동일한 접근 방식을 사용합니다:
- **바 채우기**: `StatusBar:SetValue(secretValue)` — WoW 엔진이 Secret Value를 네이티브로 처리
- **색상 커브**: `C_CurveUtil.CreateCurve()`로 체력 비율에 따른 색상 그라디언트 구현
- **텍스트 표시**: `string.format("%.0f", secretValue)` — Secret Value의 문자열 변환은 허용됨

## Credits

[DHUD](https://www.curseforge.com/wow/addons/dhud) 원본 저자:
- **MADCAT** (Mingan) — 원본 DHUD 개발
- **Markus Inger** (Drathal/Silberklinge) — DHUD3 리뉴얼
- **Howie** (Caeryn) — 유지보수

## License

[MIT License](LICENSE)
