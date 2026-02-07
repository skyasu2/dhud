# DHUD Lite

[DHUD](https://www.curseforge.com/wow/addons/dhud) 애드온을 **WoW 12.0.0(Midnight)**에서 동작하도록 리팩토링한 경량 HUD 애드온.
원본 DHUD의 UI/UX를 유지하면서, deprecated API 제거, Ace3 의존성 탈피, Secret Values 호환을 적용했습니다.

![Interface](https://img.shields.io/badge/Interface-120000-blue)
![Version](https://img.shields.io/badge/Version-1.0.0-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Why DHUD Lite?

원본 DHUD는 다음 이유로 WoW 12.0.0에서 동작하지 않습니다:
- Ace3 라이브러리 의존 (AceDB, AceGUI, AceConfig)
- deprecated WoW API 사용 (`UnitIsTapped()`, `GetComboPoints()` 등)
- Secret Values(12.0.0 보안 정책) 미지원

DHUD Lite는 원본 54파일/21,000줄을 **25파일/3,600줄로 83% 경량화**하면서 동일한 HUD 경험을 제공합니다.

## Features

- **커브드 바** - 커스텀 텍스처 좌표 조작(SetTexCoord + SetHeight)으로 구현한 곡선형 바
- **플레이어/타겟 바** - 체력, 마나/분노/기력 등 파워 바 (쉴드, 흡수, 힐 예측 레이어 포함)
- **캐스트 바** - 플레이어 + 타겟 캐스팅/채널링 표시
- **콤보 포인트 / 클래스 리소스** - DK 룬, 콤보 포인트 등 클래스별 리소스
- **유닛 정보** - 레벨, 분류(엘리트/보스), 이름, 반응 색상
- **알파 페이드 시스템** - 전투/타겟/휴식/대기 상태별 투명도 자동 전환
- **Secret Values(12.0.0) 호환**
- **무의존성** - Ace3 등 외부 라이브러리 없이 25개 Lua 파일, ~3,600줄의 경량 구현

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
| `/dhudlite reset` | 모든 설정 초기화 후 UI 리로드 |
| `/dhudlite show` | HUD 강제 표시 |
| `/dhudlite hide` | HUD 숨기기 |
| `/dhudlite alpha` | 알파 상태 새로고침 |

## Project Structure

```
DHUDLITE/
├── Core.lua              -- CreateClass, EventBus, 유틸리티
├── Settings.lua          -- SavedVariables 기반 설정 관리
├── AlphaManager.lua      -- 상태별 투명도 전환 (전투/타겟/휴식/대기)
├── HUDManager.lua        -- 슬롯-트래커 배선 및 활성화
├── Main.lua              -- 부팅 시퀀스, 슬래시 커맨드
├── Data/
│   ├── TrackerHelper.lua     -- OnUpdate 타이머, 전투/탈것 상태 추적
│   ├── HealthTracker.lua     -- 체력 + 쉴드/흡수/힐예측 추적
│   ├── PowerTracker.lua      -- 마나/분노/기력 등 파워 추적
│   ├── CastTracker.lua       -- 캐스팅/채널링 추적
│   ├── ComboTracker.lua      -- 콤보 포인트 추적
│   └── UnitInfoTracker.lua   -- 레벨, 분류, 이름, 반응 색상
├── GUI/
│   ├── Textures.lua          -- 텍스처 경로 및 좌표 테이블
│   ├── FrameFactory.lua      -- 프레임/텍스처/폰트스트링 생성
│   ├── Colorize.lua          -- 그라디언트 및 반응 색상 계산
│   ├── TextFormat.lua        -- 숫자/퍼센트 포맷팅
│   ├── BarRenderer.lua       -- 커브드 바 텍스처 렌더링
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

## Credits

[DHUD](https://www.curseforge.com/wow/addons/dhud) 원본 저자:
- **MADCAT** (Mingan) - 원본 DHUD 개발
- **Markus Inger** (Drathal/Silberklinge) - DHUD3 리뉴얼
- **Howie** (Caeryn) - 유지보수

## License

[MIT License](LICENSE)
